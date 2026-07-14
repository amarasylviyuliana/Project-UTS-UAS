<?php

namespace App\Services;

use App\Models\Order;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class N8nNotificationService
{
    protected ?string $webhookUrl;

    public function __construct()
    {
        $this->webhookUrl = config('services.n8n.webhook_url');
    }

    /**
     * Dipanggil saat pesanan baru berhasil dibuat.
     * Trigger: OrderController::createOrder
     */
    public function notifyNewOrder(Order $order): void
    {
        $order->loadMissing(['store', 'store.owner', 'buyer', 'orderItems.product']);

        $itemNames = $order->orderItems
            ->map(fn ($item) => $item->product->name ?? 'Produk')
            ->implode(', ');

        $groupChatId = config('services.n8n.group_chat_id') ?? env('N8N_TELEGRAM_GROUP_CHAT_ID');

        $this->send([
            'event'        => 'order_created',
            'order_id'     => $order->id,
            'order_number' => $order->order_number,
            'bumdes_nama'  => $order->store->store_name ?? '-',
            'bumdes_wa'    => $order->store->contact_phone ?? '',
            // Prefer recipient_name provided at checkout; fallback to account name
            'pembeli_nama' => $order->recipient_name ?? $order->buyer->name,
            // Prefer recipient phone provided at checkout; fallback to account phone
            'pembeli_wa'   => $order->recipient_phone ?? $order->buyer->phone ?? '',
            'pembeli_telegram_chat_id' => $order->buyer->telegram_chat_id ?? null,
            'buyer_chat_id' => $order->buyer->telegram_chat_id ?? null,
            // Chat id penjual (pemilik toko/BUMDes) agar bisa dikirim notifikasi personal
            'seller_telegram_chat_id' => $order->store->owner->telegram_chat_id ?? null,
            'item'         => $itemNames,
            'status'       => $order->status,
            'total'        => (float) $order->total_price,
            'group_chat_id' => $groupChatId,
            'target_chat_id' => $groupChatId,
        ]);
    }

    /**
     * Dipanggil saat pembayaran sudah terkonfirmasi (baik via Midtrans
     * webhook maupun konfirmasi manual oleh penjual).
     * Trigger: MidtransController::notification, PaymentController::confirmPayment
     */
    public function notifyPaymentConfirmed(Order $order): void
    {
        $order->loadMissing(['store', 'buyer', 'payment']);

        $this->send([
            'event'          => 'payment_confirmed',
            'order_id'       => $order->id,
            'order_number'   => $order->order_number,
            'bumdes_nama'    => $order->store->store_name ?? '-',
            'bumdes_wa'      => $order->store->contact_phone ?? '',
            'pembeli_nama'   => $order->recipient_name ?? $order->buyer->name,
            'pembeli_wa'     => $order->recipient_phone ?? $order->buyer->phone ?? '',
            'pembeli_telegram_chat_id' => $order->buyer->telegram_chat_id ?? null,
            'total'          => (float) $order->total_price,
            'payment_method' => $order->payment->payment_method ?? '-',
            'paid_at'        => optional($order->payment->paid_at)->toDateTimeString(),
        ]);
    }

    /**
     * Kirim payload ke n8n. Dibungkus try-catch supaya kalau n8n
     * down/lambat, proses order/pembayaran utama TIDAK ikut gagal.
     */
    protected function send(array $payload): void
    {
        if (empty($this->webhookUrl)) {
            Log::warning('N8N_WEBHOOK_URL belum diatur di .env, notifikasi dilewati.', $payload);
            return;
        }

        // Sertakan fallback group chat id agar n8n selalu punya target
        // (n8n workflow dapat memilih pembeli/seller/group berdasarkan field ini)
        $payload['group_chat_id'] = config('services.n8n.group_chat_id') ?? env('N8N_TELEGRAM_GROUP_CHAT_ID');

        // Jika target_chat_id sudah diset eksplisit dari payload, jangan timpa.
        if (empty($payload['target_chat_id'])) {
            // Tentukan target_chat_id prioritas: pembeli -> seller -> group
            $payload['target_chat_id'] = $payload['pembeli_telegram_chat_id'] ?? $payload['seller_telegram_chat_id'] ?? $payload['group_chat_id'] ?? null;
        }

        if (empty($payload['target_chat_id'])) {
            Log::warning('Tidak ditemukan target Telegram chat id untuk notifikasi n8n; payload akan dikirim tanpa target spesifik.', $payload);
        }

        try {
            $response = Http::timeout(5)->post($this->webhookUrl, $payload);

            if (!$response->successful()) {
                Log::warning('Gagal mengirim notifikasi ke n8n', [
                    'status'  => $response->status(),
                    'body'    => $response->body(),
                    'payload' => $payload,
                ]);
            }
        } catch (\Throwable $e) {
            Log::error('Error saat memanggil webhook n8n', [
                'message' => $e->getMessage(),
                'payload' => $payload,
            ]);
        }
    }
}
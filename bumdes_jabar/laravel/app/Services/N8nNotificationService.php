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
        $order->loadMissing(['store', 'buyer', 'orderItems.product']);

        $itemNames = $order->orderItems
            ->map(fn ($item) => $item->product->name ?? 'Produk')
            ->implode(', ');

        $this->send([
            'event'        => 'order_created',
            'order_id'     => $order->id,
            'order_number' => $order->order_number,
            'bumdes_nama'  => $order->store->store_name ?? '-',
            'bumdes_wa'    => $order->store->contact_phone ?? '',
            'pembeli_nama' => $order->buyer->name ?? $order->recipient_name,
            'pembeli_wa'   => $order->buyer->phone ?? $order->recipient_phone ?? '',
            'pembeli_telegram_chat_id' => $order->buyer->telegram_chat_id ?? null,
            'item'         => $itemNames,
            'status'       => $order->status,
            'total'        => (float) $order->total_price,
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
            'pembeli_nama'   => $order->buyer->name ?? $order->recipient_name,
            'pembeli_wa'     => $order->buyer->phone ?? $order->recipient_phone ?? '',
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
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
            // Prefer recipient_name provided at checkout; fallback to account name
            'pembeli_nama' => $order->recipient_name ?? $order->buyer->name,
            // Prefer recipient phone provided at checkout; fallback to account phone
            'pembeli_wa'   => $order->recipient_phone ?? $order->buyer->phone ?? '',
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
            'pembeli_nama'   => $order->recipient_name ?? $order->buyer->name,
            'pembeli_wa'     => $order->recipient_phone ?? $order->buyer->phone ?? '',
            'pembeli_telegram_chat_id' => $order->buyer->telegram_chat_id ?? null,
            'seller_telegram_chat_id' => $order->store?->user?->telegram_chat_id ?? null,
            'total'          => (float) $order->total_price,
            'payment_method' => $order->payment->payment_method ?? '-',
            'paid_at'        => optional($order->payment->paid_at)->toDateTimeString(),
        ]);
    }

    public function notifyOrderStatusChanged(Order $order, string $previousStatus): void
    {
        $order->loadMissing(['store', 'buyer', 'payment']);

        $event = match ($order->status) {
            'Dikirim' => 'order_shipped',
            'Selesai' => 'order_completed',
            default => null,
        };

        if ($event === null) {
            return;
        }

        $this->send([
            'event' => $event,
            'order_id' => $order->id,
            'order_number' => $order->order_number,
            'previous_status' => $previousStatus,
            'current_status' => $order->status,
            'bumdes_nama' => $order->store->store_name ?? '-',
            'bumdes_wa' => $order->store->contact_phone ?? '',
            'pembeli_nama' => $order->recipient_name ?? $order->buyer->name,
            'pembeli_wa' => $order->recipient_phone ?? $order->buyer->phone ?? '',
            'pembeli_telegram_chat_id' => $order->buyer->telegram_chat_id ?? null,
            'seller_telegram_chat_id' => $order->store?->user?->telegram_chat_id ?? null,
            'total' => (float) $order->total_price,
            'status' => $order->status,
        ]);
    }

    /**
     * Kirim payload ke n8n. Dibungkus try-catch supaya kalau n8n
     * down/lambat, proses order/pembayaran utama TIDAK ikut gagal.
     */
    protected function send(array $payload): void
    {
        $webhookUrl = $this->resolveWebhookUrl();

        if (empty($webhookUrl)) {
            Log::warning('N8N webhook URL belum diatur di .env, notifikasi dilewati.', $payload);
            return;
        }
        // Sertakan fallback group chat id agar n8n selalu punya target
        // (n8n workflow dapat memilih pembeli/seller/group berdasarkan field ini)
        $payload['group_chat_id'] = config('services.n8n.group_chat_id') ?? env('N8N_TELEGRAM_GROUP_CHAT_ID');

        // Tentukan target_chat_id prioritas: pembeli -> seller -> group
        $payload['target_chat_id'] = $payload['pembeli_telegram_chat_id'] ?? $payload['seller_telegram_chat_id'] ?? $payload['group_chat_id'] ?? null;

        if (empty($payload['target_chat_id'])) {
            Log::warning('Tidak ditemukan target Telegram chat id untuk notifikasi n8n; payload akan dikirim tanpa target spesifik.', $payload);
        }

        try {
            $response = Http::timeout(5)
                ->acceptJson()
                ->asJson()
                ->post($webhookUrl, $payload);

            if (!$response->successful()) {
                Log::warning('Gagal mengirim notifikasi ke n8n', [
                    'status'  => $response->status(),
                    'body'    => $response->body(),
                    'payload' => $payload,
                ]);

                // Coba fallback kirim langsung ke Telegram bila memungkinkan
                $this->attemptDirectTelegramFallback($payload, 'n8n_response_failed');
            }
        } catch (\Throwable $e) {
            Log::error('Error saat memanggil webhook n8n', [
                'message' => $e->getMessage(),
                'payload' => $payload,
            ]);

            // Coba fallback kirim langsung ke Telegram bila terjadi exception
            $this->attemptDirectTelegramFallback($payload, 'n8n_exception');
        }
    }

    /**
     * Public helper untuk mengirim payload uji dari controller debug.
     * Mengembalikan array informasi hasil request untuk inspeksi di API.
     */
    public function debugSend(array $payload): array
    {
        $webhookUrl = $this->resolveWebhookUrl();

        if (empty($webhookUrl)) {
            return ['ok' => false, 'error' => 'N8N webhook URL not configured'];
        }

        // Sertakan fallback dan target_chat_id sama seperti pada send()
        $payload['group_chat_id'] = config('services.n8n.group_chat_id') ?? env('N8N_TELEGRAM_GROUP_CHAT_ID');
        $payload['target_chat_id'] = $payload['pembeli_telegram_chat_id'] ?? $payload['seller_telegram_chat_id'] ?? $payload['group_chat_id'] ?? null;

        try {
            $response = Http::timeout(5)
                ->acceptJson()
                ->asJson()
                ->post($webhookUrl, $payload);

            $result = [
                'ok' => $response->successful(),
                'status' => $response->status(),
                'body' => $response->body(),
            ];

            // If n8n failed, also try direct Telegram fallback so debug shows both
            if (!$response->successful()) {
                $fallback = $this->attemptDirectTelegramFallback($payload, 'debug_n8n_failed');
                $result['telegram_fallback'] = $fallback;
            }

            return $result;
        } catch (\Throwable $e) {
            $fallback = $this->attemptDirectTelegramFallback($payload, 'debug_n8n_exception');
            return ['ok' => false, 'error' => $e->getMessage(), 'telegram_fallback' => $fallback];
        }
    }

    protected function attemptDirectTelegramFallback(array $payload, string $reason): array
    {
        $token = env('TELEGRAM_BOT_TOKEN') ?? env('N8N_TELEGRAM_BOT_TOKEN');
        if (empty($token)) {
            Log::warning('No TELEGRAM_BOT_TOKEN configured; skipping direct Telegram fallback', ['reason' => $reason]);
            return ['ok' => false, 'error' => 'no_token'];
        }

        // Choose target chat id: target_chat_id (already populated), group_chat_id as fallback
        $chatId = $payload['target_chat_id'] ?? $payload['group_chat_id'] ?? null;
        if (empty($chatId)) {
            Log::warning('No chat id available for Telegram fallback', ['reason' => $reason, 'payload' => $payload]);
            return ['ok' => false, 'error' => 'no_chat_id'];
        }

        $text = $this->buildTelegramText($payload);

        try {
            $telegramUrl = "https://api.telegram.org/bot{$token}/sendMessage";
            $resp = Http::timeout(5)
                ->post($telegramUrl, [
                    'chat_id' => $chatId,
                    'text' => $text,
                    'parse_mode' => 'HTML',
                ]);

            if ($resp->successful()) {
                Log::info('Sent Telegram fallback message', ['chat_id' => $chatId, 'reason' => $reason]);
                return ['ok' => true, 'body' => $resp->body()];
            }

            Log::warning('Telegram fallback failed', ['status' => $resp->status(), 'body' => $resp->body(), 'chat_id' => $chatId]);
            return ['ok' => false, 'status' => $resp->status(), 'body' => $resp->body()];
        } catch (\Throwable $e) {
            Log::error('Error sending Telegram fallback', ['message' => $e->getMessage(), 'chat_id' => $chatId]);
            return ['ok' => false, 'error' => $e->getMessage()];
        }
    }

    protected function buildTelegramText(array $payload): string
    {
        $order = $payload['order_number'] ?? $payload['order_id'] ?? '-';
        $item = $payload['item'] ?? '-';
        $total = isset($payload['total']) ? number_format($payload['total'], 0, ',', '.') : '-';
        $status = $payload['status'] ?? $payload['event'] ?? '-';

        $text = "Pesan notifikasi: \nOrder: <b>{$order}</b>\nProduk: {$item}\nTotal: Rp {$total}\nStatus: {$status}";
        return $text;
    }

    protected function resolveWebhookUrl(): ?string
    {
        $candidates = array_filter([
            $this->webhookUrl,
            config('services.n8n.webhook_url'),
            env('N8N_WEBHOOK_URL'),
            env('TELEGRAM_BOT_TOKEN'),
            env('N8N_TELEGRAM_GROUP_CHAT_ID'),
        ]);

        return !empty($candidates)
            ? (string) reset($candidates)
            : null;
    }
}
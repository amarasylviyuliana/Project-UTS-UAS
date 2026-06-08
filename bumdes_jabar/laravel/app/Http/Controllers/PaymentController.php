<?php

namespace App\Http\Controllers;

use App\Models\Payment;
use App\Models\Order;
use App\Services\XenditService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class PaymentController extends Controller
{
    /**
     * Get payment details for an order
     * REQ-26
     */
    public function show(Request $request, $orderId): JsonResponse
    {
        $order = Order::with('store')->find($orderId);

        if (!$order) {
            return response()->json([
                'message' => 'Pesanan tidak ditemukan',
            ], 404);
        }

        $user = $request->user();
        if ($order->buyer_id !== $user->id && $order->store->user_id !== $user->id) {
            return response()->json([
                'message' => 'Anda tidak punya akses',
            ], 403);
        }

        $payment = $order->payment;

        return response()->json([
            'message' => 'Detail pembayaran',
            'data' => [
                'order_number' => $order->order_number,
                'total_amount' => $order->total_price,
                'bank_name' => $order->store->bank_name,
                'bank_account_number' => $order->store->bank_account_number,
                'bank_account_holder' => $order->store->bank_account_holder,
                'payment_status' => $payment->payment_status ?? $payment->status ?? 'Pending',
                'payment_method' => $payment->payment_method,
                'invoice_url' => $payment->invoice_url,
                'invoice_id' => $payment->invoice_id,
                'paid_at' => $payment->paid_at,
            ],
        ]);
    }

    /**
     * Upload payment proof
     * REQ-27, REQ-28
     */
    public function uploadProof(Request $request, $orderId): JsonResponse
    {
        $order = Order::find($orderId);

        if (!$order || $order->buyer_id !== $request->user()->id) {
            return response()->json([
                'message' => 'Pesanan tidak ditemukan atau anda tidak punya akses',
            ], 404);
        }

        if ($order->status !== 'Menunggu Pembayaran') {
            return response()->json([
                'message' => 'Status pesanan harus "Menunggu Pembayaran" untuk mengunggah bukti',
            ], 422);
        }

        $validated = $request->validate([
            'proof_image' => 'required|image|mimes:jpeg,png,jpg|max:5120', // 5MB
        ]);

        try {
            // Store file
            $path = $request->file('proof_image')->store('payment-proofs', 'public');

            // Update payment
            $payment = $order->payment;
            $payment->proof_image_url = $path;
            $payment->status = 'Confirmed';
            $payment->confirmed_at = now();
            $payment->save();

            // Update order status immediately
            $order->status = 'Dikonfirmasi';
            $order->save();

            return response()->json([
                'message' => 'Bukti pembayaran berhasil diunggah dan dikonfirmasi otomatis.',
                'data' => [
                    'payment_id' => $payment->id,
                    'proof_image_url' => Storage::url($path),
                    'status' => $payment->status,
                ],
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Gagal mengunggah bukti pembayaran',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get payment proof (for seller to verify)
     * REQ-29
     */
    public function submitPayment(Request $request, $orderId): JsonResponse
    {
        $order = Order::with('payment', 'store')->find($orderId);

        if (!$order || $order->buyer_id !== $request->user()->id) {
            return response()->json([
                'message' => 'Pesanan tidak ditemukan atau anda tidak punya akses',
            ], 404);
        }
        if (in_array($order->status, ['Dibatalkan', 'Selesai'], true)) {
            return response()->json([
                'message' => 'Order sudah berada dalam status akhir dan tidak dapat diproses ulang.',
                'data' => [
                    'order' => $order,
                    'payment' => $order->payment,
                ],
            ], 200);
        }

        $validated = $request->validate([
            'status' => 'sometimes|in:success,pending',
        ]);

        $payment = $order->payment;
        if (!$payment) {
            $payment = Payment::create([
                'order_id' => $order->id,
                'status' => 'Pending',
            ]);
        }

        if ($order->status === 'Dikonfirmasi' && $payment->status === 'Confirmed') {
            return response()->json([
                'message' => 'Pembayaran sudah dikonfirmasi.',
                'data' => [
                    'order' => $order,
                    'payment' => $payment,
                ],
            ], 200);
        }

        if ($order->status === 'Menunggu Konfirmasi' && ($validated['status'] ?? 'success') === 'pending') {
            return response()->json([
                'message' => 'Pembayaran sedang menunggu konfirmasi penjual.',
                'data' => [
                    'order' => $order,
                    'payment' => $payment,
                ],
            ], 200);
        }

        DB::transaction(function () use ($validated, $payment, $order) {
            if (($validated['status'] ?? 'success') === 'pending') {
                $payment->status = 'Pending';
                $order->status = 'Menunggu Pembayaran';
            } else {
                $payment->status = 'Confirmed';
                $payment->confirmed_at = now();
                $order->status = 'Dikonfirmasi';
            }

            $payment->save();
            $order->save();
        });

        return response()->json([
            'message' => 'Pembayaran berhasil diproses.',
            'data' => [
                'order' => $order,
                'payment' => $payment,
            ],
        ], 200);
    }

    public function getProof(Request $request, $orderId): JsonResponse
    {
        $order = Order::find($orderId);

        if (!$order) {
            return response()->json([
                'message' => 'Pesanan tidak ditemukan',
            ], 404);
        }

        // Check if user is the seller
        if ($order->store->user_id !== $request->user()->id) {
            return response()->json([
                'message' => 'Anda tidak punya akses',
            ], 403);
        }

        $payment = $order->payment;

        if (!$payment || !$payment->proof_image_url) {
            return response()->json([
                'message' => 'Bukti pembayaran belum diunggah',
            ], 404);
        }

        return response()->json([
            'message' => 'Bukti pembayaran',
            'data' => [
                'payment_id' => $payment->id,
                'proof_image_url' => Storage::url($payment->proof_image_url),
                'uploaded_at' => $payment->created_at,
                'order_number' => $order->order_number,
                'total_amount' => $order->total_price,
            ],
        ]);
    }

    /**
     * Confirm payment receipt (seller)
     * REQ-29
     */
    public function confirmPayment(Request $request, $orderId): JsonResponse
    {
        $order = Order::find($orderId);

        if (!$order) {
            return response()->json([
                'message' => 'Pesanan tidak ditemukan',
            ], 404);
        }

        // Check if user is the seller
        if ($order->store->user_id !== $request->user()->id) {
            return response()->json([
                'message' => 'Anda tidak punya akses',
            ], 403);
        }

        if ($order->status !== 'Menunggu Konfirmasi') {
            return response()->json([
                'message' => 'Status pesanan harus "Menunggu Konfirmasi" untuk mengkonfirmasi pembayaran',
            ], 422);
        }

        $payment = $order->payment;
        $payment->status = 'Confirmed';
        $payment->confirmed_at = now();
        $payment->save();

        $order->status = 'Dikonfirmasi';
        $order->save();

        return response()->json([
            'message' => 'Pembayaran dikonfirmasi',
            'data' => $payment,
        ]);
    }

    /**
     * Reject payment (seller)
     * REQ-30
     */
    public function rejectPayment(Request $request, $orderId): JsonResponse
    {
        $order = Order::find($orderId);

        if (!$order) {
            return response()->json([
                'message' => 'Pesanan tidak ditemukan',
            ], 404);
        }

        // Check if user is the seller
        if ($order->store->user_id !== $request->user()->id) {
            return response()->json([
                'message' => 'Anda tidak punya akses',
            ], 403);
        }

        if ($order->status !== 'Menunggu Konfirmasi') {
            return response()->json([
                'message' => 'Status pesanan harus "Menunggu Konfirmasi" untuk menolak pembayaran',
            ], 422);
        }

        $validated = $request->validate([
            'reason' => 'required|string|max:500',
        ]);

        $payment = $order->payment;
        $payment->status = 'Rejected';
        $payment->rejection_reason = $validated['reason'];
        $payment->rejected_at = now();
        $payment->save();

        $order->status = 'Menunggu Pembayaran';
        $order->save();

        return response()->json([
            'message' => 'Pembayaran ditolak',
            'data' => $payment,
        ]);
    }
    /**
     * Create a Xendit invoice for an existing order.
     */
    public function createInvoice(Request $request): JsonResponse
    {
        $user = $request->user();
        if (!$user) {
            return response()->json([
                'message' => 'User tidak terautentikasi',
            ], 401);
        }

        $validated = $request->validate([
            'order_id' => 'required|string|max:255',
            'amount' => 'required|numeric|min:1',
            'customer_name' => 'required|string|max:255',
            'customer_email' => 'sometimes|nullable|email',
            'payment_method' => 'sometimes|string|in:btn_va,dana,gopay,shopeepay',
        ]);

        $order = $this->findOrderByIdentifier($validated['order_id']);

        if (!$order) {
            return response()->json([
                'message' => 'Pesanan tidak ditemukan',
            ], 404);
        }

        if ($order->buyer_id !== $user->id) {
            return response()->json([
                'message' => 'Anda tidak punya akses ke pesanan ini',
            ], 403);
        }

        $secretKey = env('XENDIT_SECRET_KEY');
        $publicKey = env('XENDIT_PUBLIC_KEY');
        $webhookToken = env('XENDIT_WEBHOOK_TOKEN');
        $successRedirectBase = env('XENDIT_SUCCESS_REDIRECT_URL') ?: env('APP_URL') . '/#/order-detail';
        $failureRedirectBase = env('XENDIT_FAILURE_REDIRECT_URL') ?: env('APP_URL') . '/#/order-detail';

        if (!$secretKey || !$publicKey || !$webhookToken) {
            return response()->json([
                'message' => 'Xendit belum dikonfigurasi, silakan isi API Key pada file .env',
            ], 500);
        }

        if (!str_starts_with($secretKey, 'xnd_secret_')
            && !str_starts_with($secretKey, 'xnd_development_')
            && !str_starts_with($secretKey, 'xnd_production_')) {
            return response()->json([
                'message' => 'Xendit secret key tidak valid. Periksa nilai XENDIT_SECRET_KEY di file .env',
            ], 500);
        }

        $paymentMethod = $validated['payment_method'] ?? 'btn_va';
        $paymentMethods = $this->mapXenditPaymentMethods($paymentMethod);
        $externalId = $order->order_number . '-' . uniqid();

        \Log::info('CreateInvoice request received', [
            'user_id' => $user->id,
            'order_id' => $order->id,
            'order_number' => $order->order_number,
            'amount' => $validated['amount'],
            'payment_method' => $paymentMethod,
            'customer_name' => $validated['customer_name'],
            'customer_email' => $validated['customer_email'] ?? $user->email ?? null,
        ]);

        $successRedirectUrl = $this->appendQueryString($successRedirectBase, [
            'orderId' => $order->id,
        ]);
        $failureRedirectUrl = $this->appendQueryString($failureRedirectBase, [
            'orderId' => $order->id,
            'payment' => 'failed',
        ]);

        try {
            $service = new XenditService();
            $invoice = $service->createInvoice(
                $externalId,
                (float) $validated['amount'], 
                $validated['customer_name'], 
                $validated['customer_email'] ?? $user->email ?? 'no-reply@example.com',
                $paymentMethods,
                $successRedirectUrl,
                $failureRedirectUrl,
            );

            \Log::info('Xendit invoice response', [
                'order_id' => $order->id,
                'external_id' => $externalId,
                'invoice' => $invoice,
            ]);
        } catch (\Throwable $e) {
            \Log::error('Xendit createInvoice failed', [
                'order_id' => $order->id ?? null,
                'external_id' => $externalId ?? null,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'message' => 'Gagal membuat invoice Xendit',
            ], 500);
        }

        $payment = $order->payment;
        if (!$payment) {
            $payment = Payment::create([
                'order_id' => $order->id,
                'status' => 'Pending',
                'payment_status' => 'Pending',
            ]);
        }

        $payment->invoice_id = $invoice['id'] ?? null;
        $payment->invoice_url = $invoice['invoice_url'] ?? $invoice['url'] ?? null;
        $payment->payment_method = strtoupper($paymentMethod);
        $payment->payment_status = strtoupper($invoice['status'] ?? 'PENDING');
        $payment->paid_at = strtoupper($invoice['status'] ?? '') === 'PAID' ? now() : null;
        $payment->status = strtoupper($invoice['status'] ?? '') === 'PAID' ? 'Confirmed' : 'Pending';
        $payment->save();

        $order->status = $payment->payment_status === 'PAID' ? 'Dikonfirmasi' : 'Menunggu Pembayaran';
        $order->save();

        return response()->json([
            'success' => true,
            'invoice_id' => $payment->invoice_id,
            'invoice_url' => $payment->invoice_url,
            'status' => $payment->payment_status,
        ], 201);
    }

    public function webhook(Request $request): JsonResponse
    {
        $token = $request->header('X-Callback-Token') ?? $request->input('token');
        $expected = env('XENDIT_WEBHOOK_TOKEN');

        if (!$expected || !$token || hash_equals($expected, $token) === false) {
            return response()->json([
                'message' => 'Token webhook Xendit tidak valid',
            ], 401);
        }

        $payload = $request->all();
        $invoiceId = $payload['id'] ?? null;
        if (!$invoiceId) {
            return response()->json([
                'message' => 'Invoice ID tidak ditemukan di payload webhook',
            ], 400);
        }

        $payment = Payment::where('invoice_id', $invoiceId)->first();
        if (!$payment) {
            return response()->json([
                'message' => 'Payment record tidak ditemukan untuk invoice ini',
            ], 404);
        }

        $status = strtoupper($payload['status'] ?? '');
        $payment->payment_status = $status;
        $payment->paid_at = $status === 'PAID' ? now() : null;
        $payment->status = $status === 'PAID' ? 'Confirmed' : ($status === 'EXPIRED' || $status === 'FAILED' ? 'Pending' : 'Pending');
        $payment->save();

        $order = $payment->order;
        if ($order) {
            if ($status === 'PAID') {
                $order->status = 'Dikonfirmasi';
            } else {
                $order->status = 'Menunggu Pembayaran';
            }
            $order->save();
        }

        return response()->json([
            'message' => 'Webhook Xendit berhasil diproses',
            'status' => $status,
        ]);
    }

    private function appendQueryString(string $url, array $params): string
    {
        if (empty($params)) {
            return $url;
        }

        $separator = str_contains($url, '?') ? '&' : '?';
        return $url . $separator . http_build_query($params);
    }

    private function mapXenditPaymentMethods(string $method): array
    {
        return match (strtolower($method)) {
            'btn_va' => ['VA'],
            'dana' => ['DANA'],
            'gopay' => ['GOPAY'],
            'shopeepay' => ['SHOPEEPAY'],
            default => ['VA', 'DANA', 'GOPAY', 'SHOPEEPAY'],
        };
    }

    private function findOrderByIdentifier(string $orderId)
    {
        if (ctype_digit($orderId)) {
            $order = Order::find((int) $orderId);
            if ($order) {
                return $order;
            }
        }

        return Order::where('order_number', $orderId)->first();
    }}

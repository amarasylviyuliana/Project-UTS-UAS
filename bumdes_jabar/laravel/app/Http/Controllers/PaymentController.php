<?php

namespace App\Http\Controllers;

use App\Models\Payment;
use App\Models\Order;
use App\Services\N8nNotificationService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class PaymentController extends Controller
{
    public function testRoute(): JsonResponse
    {
        return response()->json([
            'message' => 'Payment route test successful',
            'timestamp' => now(),
        ]);
    }

    public function show(Request $request, $orderId): JsonResponse
    {
        $order = Order::with('store')->find($orderId);

        if (!$order) {
            return response()->json(['message' => 'Pesanan tidak ditemukan'], 404);
        }

        $user = $request->user();
        if ($order->buyer_id !== $user->id && $order->store->user_id !== $user->id) {
            return response()->json(['message' => 'Anda tidak punya akses'], 403);
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

    public function uploadProof(Request $request, $orderId): JsonResponse
    {
        $order = Order::find($orderId);

        if (!$order || $order->buyer_id !== $request->user()->id) {
            return response()->json(['message' => 'Pesanan tidak ditemukan atau anda tidak punya akses'], 404);
        }

        if ($order->status !== 'Menunggu Pembayaran') {
            return response()->json(['message' => 'Status pesanan harus "Menunggu Pembayaran" untuk mengunggah bukti'], 422);
        }

        $request->validate([
            'proof_image' => 'required|image|mimes:jpeg,png,jpg|max:5120',
        ]);

        try {
            $path = $request->file('proof_image')->store('payment-proofs', 'public');

            $payment = $order->payment;
            $payment->proof_image_url = $path;
            $payment->status = 'Confirmed';
            $payment->payment_status = 'Confirmed';
            $payment->confirmed_at = now();
            $payment->paid_at = now();
            $payment->save();

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
            return response()->json(['message' => 'Gagal mengunggah bukti pembayaran', 'error' => $e->getMessage()], 500);
        }
    }

    public function submitPayment(Request $request, $orderId): JsonResponse
    {
        $order = Order::with('payment', 'store')->find($orderId);

        if (!$order || $order->buyer_id !== $request->user()->id) {
            return response()->json(['message' => 'Pesanan tidak ditemukan atau anda tidak punya akses'], 404);
        }

        if (in_array($order->status, ['Dibatalkan', 'Selesai'], true)) {
            return response()->json([
                'message' => 'Order sudah berada dalam status akhir.',
                'data' => ['order' => $order, 'payment' => $order->payment],
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
                'payment_status' => 'Pending',
            ]);
        }

        if ($order->status === 'Dikonfirmasi' && $payment->status === 'Confirmed') {
            return response()->json([
                'message' => 'Pembayaran sudah dikonfirmasi.',
                'data' => ['order' => $order, 'payment' => $payment],
            ], 200);
        }

        DB::transaction(function () use ($validated, $payment, $order) {
            if (($validated['status'] ?? 'success') === 'pending') {
                $payment->status = 'Pending';
                $payment->payment_status = 'Pending';
                $order->status = 'Menunggu Pembayaran';
            } else {
                $payment->status = 'Confirmed';
                $payment->payment_status = 'Confirmed';
                $payment->confirmed_at = now();
                $payment->paid_at = now();
                $order->status = 'Dikonfirmasi';
            }
            $payment->save();
            $order->save();
        });

        return response()->json([
            'message' => 'Pembayaran berhasil diproses.',
            'data' => ['order' => $order, 'payment' => $payment],
        ], 200);
    }

    public function getProof(Request $request, $orderId): JsonResponse
    {
        $order = Order::find($orderId);

        if (!$order) {
            return response()->json(['message' => 'Pesanan tidak ditemukan'], 404);
        }

        if ($order->store->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Anda tidak punya akses'], 403);
        }

        $payment = $order->payment;

        if (!$payment || !$payment->proof_image_url) {
            return response()->json(['message' => 'Bukti pembayaran belum diunggah'], 404);
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

    public function confirmPayment(Request $request, $orderId): JsonResponse
    {
        $order = Order::find($orderId);

        if (!$order) {
            return response()->json(['message' => 'Pesanan tidak ditemukan'], 404);
        }

        if ($order->store->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Anda tidak punya akses'], 403);
        }

        if ($order->status !== 'Menunggu Konfirmasi') {
            return response()->json(['message' => 'Status pesanan harus "Menunggu Konfirmasi"'], 422);
        }

        $payment = $order->payment;
        $payment->status = 'Confirmed';
        $payment->payment_status = 'Confirmed';
        $payment->confirmed_at = now();
        $payment->paid_at = now();
        $payment->save();

        $order->status = 'Dikonfirmasi';
        $order->save();
 // Kirim notifikasi konfirmasi pembayaran ke penjual & pembeli lewat n8n
        (new N8nNotificationService())->notifyPaymentConfirmed($order);
        return response()->json(['message' => 'Pembayaran dikonfirmasi', 'data' => $payment]);
    }

    public function rejectPayment(Request $request, $orderId): JsonResponse
    {
        $order = Order::find($orderId);

        if (!$order) {
            return response()->json(['message' => 'Pesanan tidak ditemukan'], 404);
        }

        if ($order->store->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Anda tidak punya akses'], 403);
        }

        if ($order->status !== 'Menunggu Konfirmasi') {
            return response()->json(['message' => 'Status pesanan harus "Menunggu Konfirmasi"'], 422);
        }

        $validated = $request->validate([
            'reason' => 'required|string|max:500',
        ]);

        $payment = $order->payment;
        $payment->status = 'Rejected';
        $payment->payment_status = 'Rejected';
        $payment->rejection_reason = $validated['reason'];
        $payment->rejected_at = now();
        $payment->save();

        $order->status = 'Menunggu Pembayaran';
        $order->save();

        return response()->json(['message' => 'Pembayaran ditolak', 'data' => $payment]);
    }

    public function createMidtransPayment(Request $request): JsonResponse
    {
        try {
            $orderId = $request->input('order_id');

            if (!$orderId) {
                return response()->json(['message' => 'order_id is required'], 400);
            }

            $user = $request->user();
            if (!$user) {
                return response()->json(['message' => 'User tidak terautentikasi'], 401);
            }

            $order = $this->findOrderByIdentifier($orderId);

            if (!$order) {
                return response()->json(['message' => 'Pesanan tidak ditemukan'], 404);
            }

            if ($order->buyer_id !== $user->id) {
                return response()->json(['message' => 'Anda tidak punya akses ke pesanan ini'], 403);
            }

            $serverKey = env('MIDTRANS_SERVER_KEY');
            $clientKey = env('MIDTRANS_CLIENT_KEY');
            $isProduction = filter_var(env('MIDTRANS_IS_PRODUCTION', false), FILTER_VALIDATE_BOOLEAN);

            if (!$serverKey || !$clientKey) {
                return response()->json(['message' => 'Midtrans belum dikonfigurasi, silakan isi API Key pada file .env'], 500);
            }

            \Midtrans\Config::$serverKey = $serverKey;
            \Midtrans\Config::$clientKey = $clientKey;
            \Midtrans\Config::$isProduction = $isProduction;
            \Midtrans\Config::$isSanitized = true;
            \Midtrans\Config::$is3ds = true;

            $grossAmount = (int) $order->total_price;
            $transactionDetails = [
                'order_id' => $order->order_number . '-' . time(),
                'gross_amount' => $grossAmount,
            ];

            $customerDetails = [
                'first_name' => $user->name ?? 'Customer',
                'email' => $user->email,
                'phone' => $user->phone_number ?? '',
            ];

            $itemDetails = [];
            $totalItemAmount = 0;

            if ($order->orderItems && count($order->orderItems) > 0) {
                foreach ($order->orderItems as $item) {
                    $itemPrice = (int) $item->unit_price;
                    $itemQuantity = (int) $item->quantity;
                    $totalItemAmount += $itemPrice * $itemQuantity;
                    $itemDetails[] = [
                        'id' => (string) $item->id,
                        'price' => $itemPrice,
                        'quantity' => $itemQuantity,
                        'name' => substr($item->product->name ?? 'Product', 0, 50),
                    ];
                }
            } else {
                $itemDetails[] = [
                    'id' => 'ORDER-' . $order->id,
                    'price' => $grossAmount,
                    'quantity' => 1,
                    'name' => 'Pesanan ' . $order->order_number,
                ];
            }

            $payload = [
                'transaction_details' => $transactionDetails,
                'customer_details' => $customerDetails,
                'item_details' => $itemDetails,
            ];

            $snapToken = \Midtrans\Snap::getSnapToken($payload);

            $payment = $order->payment ?: Payment::create([
                'order_id' => $order->id,
                'status' => 'Pending',
                'payment_status' => 'Pending',
            ]);

            $payment->invoice_id = $order->order_number;
            $payment->payment_method = 'MIDTRANS';
            $payment->payment_status = 'Pending';
            $payment->status = 'Pending';
            $payment->save();

            return response()->json([
                'success' => true,
                'snap_token' => $snapToken,
                'client_key' => $clientKey,
                'order_id' => $order->id,
                'order_number' => $order->order_number,
                'amount' => $order->total_price,
            ]);
        } catch (\Exception $e) {
            \Log::error('Midtrans payment creation failed', [
                'error' => $e->getMessage(),
                'exception_class' => get_class($e),
            ]);

            return response()->json([
                'message' => 'Gagal membuat payment Midtrans',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    private function findOrderByIdentifier(string $orderId)
    {
        if (ctype_digit($orderId)) {
            $order = Order::with('orderItems.product')->find((int) $orderId);
            if ($order) return $order;
        }
        return Order::with('orderItems.product')->where('order_number', $orderId)->first();
    }
}
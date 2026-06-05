<?php

namespace App\Http\Controllers;

use App\Models\Payment;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
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
                'payment_status' => $payment->status ?? 'Pending',
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
            $payment->status = 'Pending';
            $payment->save();

            // Update order status
            $order->status = 'Menunggu Konfirmasi';
            $order->save();

            return response()->json([
                'message' => 'Bukti pembayaran berhasil diunggah',
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

        if ($order->status !== 'Menunggu Pembayaran') {
            return response()->json([
                'message' => 'Status pesanan harus "Menunggu Pembayaran" untuk menyelesaikan pembayaran QRIS',
            ], 422);
        }

        $payment = $order->payment;
        if (!$payment) {
            $payment = Payment::create([
                'order_id' => $order->id,
                'status' => 'Pending',
            ]);
        } else {
            $payment->status = 'Pending';
            $payment->save();
        }

        $order->status = 'Menunggu Konfirmasi';
        $order->save();

        return response()->json([
            'message' => 'Pembayaran QRIS berhasil dikirim ke penjual. Silakan tunggu konfirmasi.',
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
}

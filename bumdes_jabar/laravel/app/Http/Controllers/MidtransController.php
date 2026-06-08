<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Midtrans\Config as MidtransConfig;
use Midtrans\Notification as MidtransNotification;
use App\Models\Order;
use App\Models\Payment;

class MidtransController extends Controller
{
    public function notification(Request $request): JsonResponse
    {
        MidtransConfig::$serverKey = env('MIDTRANS_SERVER_KEY');
        MidtransConfig::$isProduction = filter_var(env('MIDTRANS_IS_PRODUCTION', false), FILTER_VALIDATE_BOOLEAN);
        MidtransConfig::$isSanitized = true;
        MidtransConfig::$is3ds = true;

        if (!MidtransConfig::$serverKey) {
            \Log::error('Midtrans webhook called without MIDTRANS_SERVER_KEY configured.');
            return response()->json([
                'message' => 'Midtrans server key is not configured.',
            ], 500);
        }

        try {
            $notif = new MidtransNotification();

            \Log::info('Midtrans notification received', [
                'transaction_status' => $notif->transaction_status ?? null,
                'fraud_status' => $notif->fraud_status ?? null,
                'order_id' => $notif->order_id ?? ($notif->transaction_details['order_id'] ?? null),
                'raw_data' => $request->getContent(),
            ]);

            $transactionStatus = $notif->transaction_status ?? null;
            $fraudStatus = $notif->fraud_status ?? null;
            $orderId = $notif->order_id ?? ($notif->transaction_details['order_id'] ?? null);

            if (!$orderId) {
                return response()->json(['message' => 'Order ID not found in notification'], 422);
            }

            $order = Order::where('order_number', $orderId)->first();
            if (!$order) {
                return response()->json(['message' => 'Order not found'], 404);
            }

            DB::transaction(function () use ($order, &$payment) {
                $payment = $order->payment ?: Payment::create([
                    'order_id' => $order->id,
                    'status' => 'Pending',
                ]);
            });

            if ($order->status === 'Dikonfirmasi' && $payment->status === 'Confirmed') {
                return response()->json([
                    'message' => 'Notification already processed',
                ], 200);
            }

            switch ($transactionStatus) {
                case 'capture':
                    if ($fraudStatus === 'challenge') {
                        $order->status = 'Menunggu Konfirmasi';
                        $payment->status = 'Pending';
                    } else if ($fraudStatus === 'accept') {
                        $order->status = 'Dikonfirmasi';
                        $payment->status = 'Confirmed';
                        $payment->confirmed_at = now();
                    }
                    break;
                case 'settlement':
                    $order->status = 'Dikonfirmasi';
                    $payment->status = 'Confirmed';
                    $payment->confirmed_at = now();
                    break;
                case 'pending':
                    $order->status = 'Menunggu Pembayaran';
                    $payment->status = 'Pending';
                    break;
                case 'deny':
                case 'expire':
                case 'cancel':
                    $order->status = 'Dibatalkan';
                    $payment->status = 'Rejected';
                    $payment->rejection_reason = 'Midtrans status: ' . ($transactionStatus ?? 'unknown');
                    $payment->rejected_at = now();
                    break;
                default:
                    // leave status unchanged
                    break;
            }

            DB::transaction(function () use ($payment, $order) {
                $payment->save();
                $order->save();
            });

            return response()->json(['message' => 'Notification processed'], 200);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Error processing notification', 'error' => $e->getMessage()], 500);
        }
    }
}

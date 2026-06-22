<?php

namespace App\Http\Controllers;

use App\Models\Payment;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class PaymentController extends Controller
{
    /**
     * TEST: Simple test method to verify routing works
     */
    public function testRoute(): JsonResponse
    {
        return response()->json([
            'message' => 'Payment route test successful',
            'timestamp' => now(),
        ]);
    }

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
     * Create Midtrans payment token for an order
     */
    public function createMidtransPayment(Request $request): JsonResponse
    {
        try {
            // Get order_id from either JSON or form data
            $orderId = $request->input('order_id');
            
            if (!$orderId) {
                return response()->json([
                    'message' => 'order_id is required',
                ], 400);
            }

            $user = $request->user();
            if (!$user) {
                return response()->json([
                    'message' => 'User tidak terautentikasi',
                ], 401);
            }

            $order = $this->findOrderByIdentifier($orderId);

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

            \Log::info('Creating Midtrans payment', [
                'user_id' => $user->id,
                'order_id' => $order->id,
                'order_number' => $order->order_number,
                'total_price' => $order->total_price,
            ]);

            // Check Midtrans configuration
            $serverKey = env('MIDTRANS_SERVER_KEY');
            $clientKey = env('MIDTRANS_CLIENT_KEY');
            $isProduction = filter_var(env('MIDTRANS_IS_PRODUCTION', false), FILTER_VALIDATE_BOOLEAN);

            if (!$serverKey || !$clientKey) {
                return response()->json([
                    'message' => 'Midtrans belum dikonfigurasi, silakan isi API Key pada file .env',
                ], 500);
            }

            // Configure Midtrans
            \Log::info('MIDTRANS runtime config', [
                'MIDTRANS_IS_PRODUCTION' => $isProduction,
                'serverKey_present' => !empty($serverKey),
                'clientKey_present' => !empty($clientKey),
                'serverKey_length' => strlen($serverKey),
                'clientKey_length' => strlen($clientKey),
            ]);

            \Midtrans\Config::$serverKey = $serverKey;
            \Midtrans\Config::$clientKey = $clientKey;
            \Midtrans\Config::$isProduction = $isProduction;
            \Midtrans\Config::$isSanitized = true;
            \Midtrans\Config::$is3ds = true;

            // Prepare transaction details
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
                    $itemPrice = (int) $item->unit_price;  // Use unit_price, not price
                    $itemQuantity = (int) $item->quantity;
                    $itemTotal = $itemPrice * $itemQuantity;
                    $totalItemAmount += $itemTotal;
                    
                    $itemDetails[] = [
                        'id' => (string) $item->id,
                        'price' => $itemPrice,
                        'quantity' => $itemQuantity,
                        'name' => substr($item->product->name ?? 'Product', 0, 50),
                    ];
                }
            } else {
                // If no items, create a single item entry
                $itemDetails[] = [
                    'id' => 'ORDER-' . $order->id,
                    'price' => $grossAmount,
                    'quantity' => 1,
                    'name' => 'Pesanan ' . $order->order_number,
                ];
            }

            // Validate amount
            if (count($itemDetails) > 1 && $totalItemAmount !== $grossAmount) {
                \Log::warning('Midtrans item amount mismatch', [
                    'order_id' => $order->id,
                    'total_items_amount' => $totalItemAmount,
                    'gross_amount' => $grossAmount,
                    'difference' => $grossAmount - $totalItemAmount,
                ]);
            }

            // Create transaction
            $payload = [
                'transaction_details' => $transactionDetails,
                'customer_details' => $customerDetails,
                'item_details' => $itemDetails,
                'callbacks' => [
    'finish' => env('FRONTEND_URL') . '/#/orders',
    'error' => env('FRONTEND_URL') . '/#/orders',
    'pending' => env('FRONTEND_URL') . '/#/orders',

        
                ],
            ];

            \Log::info('Midtrans payload', [
                'order_id' => $order->id,
                'order_number' => $order->order_number,
                'gross_amount' => $grossAmount,
                'payload' => json_encode($payload, JSON_UNESCAPED_SLASHES),
            ]);

            \Log::info('About to call Midtrans Snap', [
                'server_key_present' => !empty($serverKey),
                'payload_order_id' => $payload['transaction_details']['order_id'] ?? 'NOT SET',
                'payload_gross_amount' => $payload['transaction_details']['gross_amount'] ?? 'NOT SET',
            ]);

            try {
                $snapToken = \Midtrans\Snap::getSnapToken($payload);
            } catch (\Throwable $midtransError) {
                \Log::error('Midtrans API error caught', [
                    'error_class' => get_class($midtransError),
                    'error_message' => $midtransError->getMessage(),
                    'error_code' => $midtransError->getCode(),
                    'file' => $midtransError->getFile(),
                    'line' => $midtransError->getLine(),
                ]);
                throw $midtransError;
            }

            // Create or update payment record
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

            \Log::info('Midtrans snap token generated', [
                'order_id' => $order->id,
                'order_number' => $order->order_number,
            ]);

            return response()->json([
                'success' => true,
                'snap_token' => $snapToken,
                'client_key' => $clientKey,
                'order_id' => $order->id,
                'order_number' => $order->order_number,
                'amount' => $order->total_price,
            ]);
        } catch (\Midtrans\Exceptions\ServerException $e) {
            // Server-side error (HTTP 500+)
            \Log::error('Midtrans Server Error', [
                'order_id' => $order->id ?? null,
                'error' => $e->getMessage(),
                'status_code' => $e->getHttpStatusCode ?? 'unknown',
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'message' => 'Gagal membuat payment Midtrans (Server Error)',
                'error' => $e->getMessage(),
            ], 502);
        } catch (\Midtrans\Exceptions\CurlException $e) {
            // Network/cURL error
            \Log::error('Midtrans cURL Error', [
                'order_id' => $order->id ?? null,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'message' => 'Gagal terhubung ke payment gateway (Network Error)',
                'error' => $e->getMessage(),
            ], 503);
        } catch (\Midtrans\Exceptions\AuthenticationException $e) {
            // Authentication error (likely invalid keys)
            \Log::error('Midtrans Authentication Error', [
                'order_id' => $order->id ?? null,
                'error' => $e->getMessage(),
                'keys_configured' => [
                    'serverKey_length' => strlen($serverKey),
                    'clientKey_length' => strlen($clientKey),
                ],
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'message' => 'Gagal autentikasi dengan payment gateway (Invalid API Keys)',
                'error' => $e->getMessage(),
            ], 401);
        } catch (\Exception $e) {
            \Log::error('Midtrans payment creation failed', [
                'order_id' => $order->id ?? null,
                'error' => $e->getMessage(),
                'exception_class' => get_class($e),
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'message' => 'Gagal membuat payment Midtrans',
                'exception_class' => get_class($e),
                'error' => $e->getMessage(),
                'hint' => 'Cek MIDTRANS_SERVER_KEY/MIDTRANS_CLIENT_KEY dan payload transaction_details/item_details/gross_amount.',
            ], 500);
        }
    }

    private function findOrderByIdentifier(string $orderId)
    {
        if (ctype_digit($orderId)) {
            $order = Order::with('orderItems.product')->find((int) $orderId);
            if ($order) {
                return $order;
            }
        }

        return Order::with('orderItems.product')->where('order_number', $orderId)->first();
    }
}

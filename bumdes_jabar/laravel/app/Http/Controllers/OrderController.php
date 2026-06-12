<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Cart;
use App\Models\Payment;
use App\Models\Product;
use App\Services\XenditService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class OrderController extends Controller
{
    /**
     * Create order from cart or from frontend payload
     * Accepts either cart items stored on server or direct order_items payload
     * REQ-22, REQ-23
     */
    public function createOrder(Request $request): JsonResponse
    {
        $user = $request->user();

        // Log incoming checkout attempts (helpful to see missing token or empty carts)
        Log::debug('Checkout attempt', [
            'auth_header' => $request->header('Authorization'),
            'user_id' => $user?->id ?? null,
            'body' => $request->all(),
        ]);

        if (!$user) {
            return response()->json([
                'message' => 'User tidak terautentikasi',
            ], 401);
        }

        $validated = $request->validate([
            'recipient_name' => 'required|string|max:255',
            'delivery_address' => 'sometimes|nullable|string|max:500',
            'recipient_address' => 'sometimes|nullable|string|max:500',
            'recipient_phone' => 'sometimes|nullable|string|max:50',
            'notes' => 'sometimes|nullable|string|max:500',
            'order_items' => 'sometimes|array',
            'order_items.*.product_id' => 'required_with:order_items|integer|exists:products,id',
            'order_items.*.quantity' => 'required_with:order_items|integer|min:1',
        ]);

        $deliveryAddress = $validated['delivery_address'] ?? $validated['recipient_address'] ?? null;
        if (!$deliveryAddress) {
            return response()->json([
                'message' => 'Field alamat pengiriman diperlukan.',
                'code' => 'DELIVERY_ADDRESS_REQUIRED',
            ], 422);
        }

        // Prefer explicit order_items if provided by frontend, otherwise use cart
        $orderItemsPayload = collect($validated['order_items'] ?? []);
        $cartItems = $user->carts()->with('product.store')->get();

        if ($orderItemsPayload->isNotEmpty()) {
            $productIds = $orderItemsPayload->pluck('product_id')->unique()->toArray();
            $products = Product::whereIn('id', $productIds)->get()->keyBy('id');

            Log::debug('Checkout product lookup', [
                'product_ids' => $productIds,
                'found_ids' => $products->keys()->all(),
            ]);

            $items = $orderItemsPayload->map(function ($item) use ($products) {
                $product = $products->get($item['product_id']);
                return (object) [
                    'product_id' => $product->id,
                    'quantity' => $item['quantity'],
                    'product' => $product,
                ];
            });

            if ($products->count() !== count($productIds)) {
                return response()->json([
                    'message' => 'Beberapa produk tidak ditemukan.',
                    'code' => 'PRODUCT_NOT_FOUND',
                ], 422);
            }
        } else {
            if ($cartItems->isEmpty()) {
                return response()->json([
                    'message' => 'Keranjang kosong. Silakan tambahkan produk terlebih dahulu.',
                    'code' => 'EMPTY_CART',
                ], 422);
            }

            $items = $cartItems;
        }

        foreach ($items as $item) {
            if (!$item->product) {
                return response()->json([
                    'message' => 'Produk dalam pesanan tidak ditemukan',
                    'code' => 'PRODUCT_NOT_FOUND',
                ], 422);
            }

            if (!$item->product->is_active) {
                return response()->json([
                    'message' => "Produk '{$item->product->name}' tidak lagi tersedia",
                    'code' => 'PRODUCT_INACTIVE',
                ], 422);
            }

            if ($item->product->type === 'produk' && $item->product->stock < $item->quantity) {
                return response()->json([
                    'message' => "Stok produk '{$item->product->name}' tidak cukup. Stok tersedia: {$item->product->stock}",
                    'code' => 'INSUFFICIENT_STOCK',
                ], 422);
            }
        }

        // Group by store
        $groupedByStore = $items->groupBy(function ($item) {
            return $item->product->store_id;
        });

        if ($groupedByStore->count() > 1) {
            return response()->json([
                'message' => 'Anda hanya dapat memesan dari satu toko sekaligus. Pesanan Anda berisi produk dari ' . $groupedByStore->count() . ' toko berbeda.',
                'code' => 'MULTIPLE_STORES',
            ], 422);
        }

        $storeId = $groupedByStore->keys()->first();
        $items = $groupedByStore->first();

        if (!$storeId) {
            return response()->json([
                'message' => 'ID toko tidak ditemukan',
                'code' => 'INVALID_STORE',
            ], 422);
        }

        // Calculate total
        $total = 0;
        foreach ($items as $item) {
            $total += $item->product->price * $item->quantity;
        }

        if ($total <= 0) {
            return response()->json([
                'message' => 'Total pesanan harus lebih dari 0',
                'code' => 'INVALID_TOTAL',
            ], 422);
        }

        $useCart = empty($validated['order_items']);

        $result = DB::transaction(function () use ($user, $storeId, $items, $validated, $total, $deliveryAddress, $useCart) {
            $order = new Order([
                'order_number' => 'ORD-' . date('YmdHis') . '-' . Str::random(6),
                'buyer_id' => $user->id,
                'store_id' => $storeId,
                'status' => 'Menunggu Pembayaran',
                'recipient_name' => $validated['recipient_name'],
                'delivery_address' => $deliveryAddress,
                'recipient_phone' => $validated['recipient_phone'] ?? null,
                'notes' => $validated['notes'] ?? null,
                'total_price' => $total,
            ]);

            $order->save();

            foreach ($items as $item) {
                OrderItem::create([
                    'order_id' => $order->id,
                    'product_id' => $item->product_id,
                    'quantity' => $item->quantity,
                    'unit_price' => $item->product->price,
                    'subtotal' => $item->product->price * $item->quantity,
                ]);

                if ($item->product->type === 'produk') {
                    $item->product->decrement('stock', $item->quantity);
                }
            }

            if ($useCart) {
                Cart::where('user_id', $user->id)->delete();
            }

            Payment::create([
                'order_id' => $order->id,
                'status' => 'Pending',
            ]);

            return $order->load('orderItems.product', 'store', 'payment');
        });

        $orderData = $result->toArray();
        $orderData['payment_status'] = 'Pending';

        return response()->json([
            'message' => 'Pesanan berhasil dibuat',
            'order' => $orderData,
            'data' => $orderData,
            'code' => 'ORDER_CREATED',
        ], 201);
    }


    /**
     * Get order details with payment info
     */
    public function show($id): JsonResponse
    {
        $order = Order::with(['orderItems.product', 'store', 'payment', 'buyer'])->find($id);

        if (!$order) {
            return response()->json([
                'message' => 'Pesanan tidak ditemukan',
            ], 404);
        }

        if ($order->payment && $order->payment->invoice_id) {
            try {
                $service = new XenditService();
                $invoice = $service->getInvoice($order->payment->invoice_id);
                $status = strtoupper($invoice['status'] ?? '');

                if ($status !== '') {
                    $payment = $order->payment;
                    $payment->payment_status = $status;
                    $payment->paid_at = $status === 'PAID' ? now() : null;
                    $payment->status = $status === 'PAID' ? 'Confirmed' : ($status === 'EXPIRED' || $status === 'FAILED' ? 'Pending' : 'Pending');
                    $payment->save();

                    if ($status === 'PAID') {
                        $order->status = 'Dikonfirmasi';
                    } else {
                        $order->status = 'Menunggu Pembayaran';
                    }
                    $order->save();
                    $order->refresh();
                    $order->load(['orderItems.product', 'store', 'payment', 'buyer']);
                }
            } catch (\Throwable $e) {
                Log::warning('Gagal memperbarui status order dari Xendit', [
                    'order_id' => $order->id,
                    'invoice_id' => $order->payment->invoice_id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return response()->json([
            'message' => 'Detail pesanan',
            'data' => $order,
        ]);
    }

    /**
     * Get buyer's order history
     * REQ-31
     */
    public function getBuyerOrders(Request $request): JsonResponse
    {
        $orders = $request->user()->orders()
            ->with(['store', 'payment', 'orderItems.product'])
            ->latest()
            ->paginate(10);

        return response()->json([
            'message' => 'Riwayat pesanan pembeli',
            'data' => $orders,
        ]);
    }

    /**
     * Get seller's incoming orders
     * REQ-24
     */
    public function getSellerOrders(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->isSeller()) {
            return response()->json([
                'message' => 'Hanya penjual yang dapat melihat pesanan masuk',
            ], 403);
        }

        $store = $user->store;
        if (!$store) {
            return response()->json([
                'message' => 'Toko tidak ditemukan',
                'data' => [],
            ], 200);
        }

        $orders = $store->orders()
            ->with(['buyer', 'payment', 'orderItems.product'])
            ->latest()
            ->paginate(10);

        return response()->json([
            'message' => 'Pesanan masuk toko',
            'data' => $orders,
        ]);
    }

    /**
     * Update order status
     * REQ-24
     */
    public function updateStatus(Request $request, $id): JsonResponse
    {
        $user = $request->user();

        if (! $user->isSeller()) {
            return response()->json([
                'message' => 'Hanya penjual yang dapat mengubah status pesanan',
            ], 403);
        }

        $order = Order::find($id);

        if (!$order || $order->store->user_id !== $user->id) {
            return response()->json([
                'message' => 'Pesanan tidak ditemukan atau anda tidak punya akses',
            ], 404);
        }

        $validated = $request->validate([
            'status' => 'required|in:Menunggu Pembayaran,Menunggu Konfirmasi,Dikonfirmasi,Diproses,Dikirim,Selesai,Dibatalkan',
        ]);

        if ($validated['status'] === 'Dikirim') {
            $order->delivered_at = now();
        } elseif ($validated['status'] === 'Selesai') {
            $order->completed_at = now();
        }

        $order->status = $validated['status'];
        $order->save();

        return response()->json([
            'message' => 'Status pesanan diperbarui',
            'data' => $order,
        ]);
    }

    /**
     * Buyer confirms receipt
     * REQ-25
     */
    public function confirmReceipt(Request $request, $id): JsonResponse
    {
        $order = Order::find($id);

        if (!$order || $order->buyer_id !== $request->user()->id) {
            return response()->json([
                'message' => 'Pesanan tidak ditemukan atau anda tidak punya akses',
            ], 404);
        }

        if ($order->status !== 'Dikirim') {
            return response()->json([
                'message' => 'Status pesanan harus "Dikirim" untuk mengkonfirmasi penerimaan',
            ], 422);
        }

        $order->update([
            'status' => 'Selesai',
            'completed_at' => now(),
        ]);

        return response()->json([
            'message' => 'Penerimaan dikonfirmasi',
            'data' => $order,
        ]);
    }

    /**
     * Buyer cancels order
     * Business rule: Buyer can cancel order if status is 'Menunggu Pembayaran'
     */
    public function cancelOrder(Request $request, $id): JsonResponse
    {
        $order = Order::with('orderItems.product')->find($id);

        if (!$order || $order->buyer_id !== $request->user()->id) {
            return response()->json([
                'message' => 'Pesanan tidak ditemukan atau anda tidak punya akses',
            ], 404);
        }

        if ($order->status !== 'Menunggu Pembayaran') {
            return response()->json([
                'message' => 'Pesanan tidak dapat dibatalkan karena status sudah berubah',
            ], 422);
        }

        DB::transaction(function () use ($order) {
            foreach ($order->orderItems as $item) {
                if ($item->product->type === 'produk') {
                    $item->product->increment('stock', $item->quantity);
                }
            }

            $order->update(['status' => 'Dibatalkan']);
        });

        return response()->json([
            'message' => 'Pesanan berhasil dibatalkan',
            'data' => $order,
        ]);
    }
}

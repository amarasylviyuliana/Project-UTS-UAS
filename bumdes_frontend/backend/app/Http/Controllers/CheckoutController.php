<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CheckoutController extends Controller
{
    public function checkout(Request $request): JsonResponse
    {
        $request->validate([
            'total' => 'required|numeric|min:0',
            'recipient_name' => 'required|string|max:255',
            'recipient_phone' => 'required|string|max:32',
            'recipient_address' => 'required|string|max:1024',
            'order_items' => 'required|array|min:1',
            'order_items.*.product_id' => 'required|integer|min:1|exists:products,id',
            'order_items.*.quantity' => 'required|integer|min:1',
            'order_items.*.unit_price' => 'required|numeric|min:0',
        ]);

        $user = $request->user();

        $order = DB::transaction(function () use ($request, $user) {
            $order = Order::create([
                'user_id' => $user->id,
                'order_number' => 'ORD-' . now()->format('YmdHis') . '-' . Str::upper(Str::random(6)),
                'status' => 'Menunggu Pembayaran',
                'total' => $request->input('total'),
                'recipient_name' => $request->input('recipient_name'),
                'recipient_phone' => $request->input('recipient_phone'),
                'recipient_address' => $request->input('recipient_address'),
                'payment_proof' => null,
                'bank_account' => null,
                'notes' => $request->input('notes'),
            ]);

            $items = $request->input('order_items', []);
            foreach ($items as $item) {
                OrderItem::create([
                    'order_id' => $order->id,
                    'product_id' => $item['product_id'],
                    'quantity' => $item['quantity'],
                    'unit_price' => $item['unit_price'],
                ]);
            }

            return $order->load('orderItems.product');
        });

        return response()->json([
            'message' => 'Pesanan berhasil dibuat.',
            'order' => [
                'id' => $order->id,
                'order_number' => $order->order_number,
                'status' => $order->status,
                'total' => $order->total,
                'recipient_name' => $order->recipient_name,
                'recipient_phone' => $order->recipient_phone,
                'recipient_address' => $order->recipient_address,
                'created_at' => $order->created_at->toDateTimeString(),
                'items' => $order->orderItems->map(function ($item) {
                    return [
                        'product' => $item->product ? [
                            'id' => $item->product->id,
                            'name' => $item->product->name,
                            'price' => $item->product->price,
                            'stock' => $item->product->stock,
                            'image_url' => $item->product->image_url,
                        ] : [
                            'id' => $item->product_id,
                        ],
                        'quantity' => $item->quantity,
                        'unit_price' => $item->unit_price,
                    ];
                })->toArray(),
            ],
        ], 201)->header('Access-Control-Allow-Origin', '*')->header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    }
}

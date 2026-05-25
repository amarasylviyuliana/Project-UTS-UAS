<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Models\Order;
use Illuminate\Support\Facades\Storage;

class OrderController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $orders = $request->user()
            ->orders()
            ->with('orderItems.product')
            ->latest()
            ->get();

        $payload = $orders->map(function ($order) {
            return [
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
            ];
        });

        return response()->json([
            'message' => 'Riwayat pesanan berhasil diambil.',
            'data' => $payload,
        ])->header('Access-Control-Allow-Origin', '*')->header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    }

    public function uploadPaymentProof(Request $request, Order $order): JsonResponse
    {
        // Ensure authenticated user owns the order
        if ($request->user()->id !== $order->user_id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $validator = \Illuminate\Support\Facades\Validator::make($request->all(), [
            'proof' => 'required|file|image|mimes:jpg,jpeg,png|max:5120',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validasi gagal untuk bukti pembayaran.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $file = $request->file('proof');
        $path = $file->store('payment_proofs', 'public');

        $order->payment_proof = $path;
        $order->status = 'Menunggu Konfirmasi Penjual';
        $order->save();

        $url = Storage::url($path);

        return response()->json([
            'message' => 'Bukti pembayaran berhasil diunggah.',
            'payment_proof' => $path,
            'payment_proof_url' => $url,
        ], 200)->header('Access-Control-Allow-Origin', '*')->header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    }
}

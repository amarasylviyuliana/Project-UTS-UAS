<?php

namespace App\Http\Controllers;

use App\Models\Review;
use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class ReviewController extends Controller
{
    /**
     * Add review for a product
     * REQ-34
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'product_id' => 'required|exists:products,id',
            'order_id' => 'required|exists:orders,id',
            'rating' => 'required|integer|min:1|max:5',
            'comment' => 'sometimes|string|max:1000',
        ]);

        // Verify buyer owns this order
        $order = Order::find($validated['order_id']);
        if ($order->buyer_id !== $request->user()->id) {
            return response()->json([
                'message' => 'Anda tidak punya akses ke pesanan ini',
            ], 403);
        }

        // Verify order is completed
        if ($order->status !== 'Selesai') {
            return response()->json([
                'message' => 'Pesanan harus berstatus "Selesai" untuk memberikan ulasan',
            ], 422);
        }

        // Verify product is in the order
        $hasProduct = OrderItem::where('order_id', $validated['order_id'])
            ->where('product_id', $validated['product_id'])
            ->exists();

        if (!$hasProduct) {
            return response()->json([
                'message' => 'Produk tidak ada dalam pesanan ini',
            ], 422);
        }

        // Check if already reviewed
        $existingReview = Review::where('product_id', $validated['product_id'])
            ->where('buyer_id', $request->user()->id)
            ->where('order_id', $validated['order_id'])
            ->first();

        if ($existingReview) {
            return response()->json([
                'message' => 'Anda sudah memberikan ulasan untuk produk ini',
            ], 422);
        }

        $review = Review::create([
            'product_id' => $validated['product_id'],
            'buyer_id' => $request->user()->id,
            'order_id' => $validated['order_id'],
            'rating' => $validated['rating'],
            'comment' => $validated['comment'] ?? null,
        ]);

        return response()->json([
            'message' => 'Ulasan berhasil ditambahkan',
            'data' => $review->load('buyer'),
        ], 201);
    }

    /**
     * Get reviews for a product
     */
    public function getProductReviews($productId): JsonResponse
    {
        $reviews = Review::where('product_id', $productId)
            ->with('buyer')
            ->latest()
            ->paginate(10);

        $avgRating = Review::where('product_id', $productId)
            ->avg('rating');

        return response()->json([
            'message' => 'Ulasan produk',
            'average_rating' => round($avgRating, 1),
            'data' => $reviews,
        ]);
    }

    /**
     * Get reviews by buyer
     */
    public function getBuyerReviews(Request $request): JsonResponse
    {
        $reviews = Review::where('buyer_id', $request->user()->id)
            ->with(['product', 'order'])
            ->latest()
            ->paginate(10);

        return response()->json([
            'message' => 'Ulasan saya',
            'data' => $reviews,
        ]);
    }

    /**
     * Update review
     */
    public function update(Request $request, $reviewId): JsonResponse
    {
        $review = Review::find($reviewId);

        if (!$review || $review->buyer_id !== $request->user()->id) {
            return response()->json([
                'message' => 'Ulasan tidak ditemukan atau anda tidak punya akses',
            ], 404);
        }

        $validated = $request->validate([
            'rating' => 'sometimes|integer|min:1|max:5',
            'comment' => 'sometimes|string|max:1000',
        ]);

        $review->update($validated);

        return response()->json([
            'message' => 'Ulasan diperbarui',
            'data' => $review,
        ]);
    }

    /**
     * Delete review
     */
    public function destroy(Request $request, $reviewId): JsonResponse
    {
        $review = Review::find($reviewId);

        if (!$review || $review->buyer_id !== $request->user()->id) {
            return response()->json([
                'message' => 'Ulasan tidak ditemukan atau anda tidak punya akses',
            ], 404);
        }

        $review->delete();

        return response()->json([
            'message' => 'Ulasan dihapus',
        ]);
    }
}

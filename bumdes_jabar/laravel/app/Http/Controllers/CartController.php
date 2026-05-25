<?php

namespace App\Http\Controllers;

use App\Models\Cart;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class CartController extends Controller
{
    /**
     * Get user's cart items
     */
    public function index(Request $request): JsonResponse
    {
        $cartItems = $request->user()->carts()
            ->with(['product' => function ($query) {
                $query->select('products.id', 'products.name', 'products.price', 'products.stock', 'products.photo_url', 'products.store_id');
                $query->with('store:id,store_name');
            }])
            ->get();

        $total = $cartItems->sum(function ($item) {
            return $item->product->price * $item->quantity;
        });

        // Log cart index calls for debugging missing cart issues
        \Log::debug('Cart index called', [
            'auth_header' => $request->header('Authorization'),
            'user_id' => $request->user()?->id ?? null,
            'cart_count' => $cartItems->count(),
            'total' => $total,
        ]);

        return response()->json([
            'message' => 'Keranjang belanja',
            'items' => $cartItems,
            'total' => $total,
        ]);
    }

    /**
     * Add product to cart
     * REQ-21
     */
    public function add(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'product_id' => 'required|exists:products,id',
            'quantity' => 'required|integer|min:1',
        ]);

        // Log incoming add-to-cart attempts for debugging missing Authorization/token issues
        \Log::debug('Cart add attempt', [
            'auth_header' => $request->header('Authorization'),
            'user_id' => $request->user()?->id ?? null,
            'payload' => $validated,
        ]);

        $product = Product::find($validated['product_id']);

        if (!$product || !$product->is_active) {
            return response()->json([
                'message' => 'Produk tidak ditemukan',
            ], 404);
        }

        // Check stock for physical products
        if ($product->type === 'produk' && $product->stock < $validated['quantity']) {
            return response()->json([
                'message' => 'Stok tidak cukup',
            ], 422);
        }

        $cartItem = Cart::firstOrCreate(
            [
                'user_id' => $request->user()->id,
                'product_id' => $validated['product_id'],
            ],
            ['quantity' => 0]
        );

        $cartItem->quantity += $validated['quantity'];
        $cartItem->save();

        return response()->json([
            'message' => 'Produk ditambahkan ke keranjang',
            'item' => $cartItem->load('product'),
        ], 201);
    }

    /**
     * Update cart item quantity
     * REQ-21
     */
    public function update(Request $request, $cartId): JsonResponse
    {
        $validated = $request->validate([
            'quantity' => 'required|integer|min:0',
        ]);

        $cartItem = Cart::findOrFail($cartId);

        if ($cartItem->user_id !== $request->user()->id) {
            return response()->json([
                'message' => 'Anda tidak punya akses',
            ], 403);
        }

        if ($validated['quantity'] === 0) {
            $cartItem->delete();
            return response()->json([
                'message' => 'Item dihapus dari keranjang',
            ]);
        }

        // Check stock
        if ($cartItem->product->type === 'produk' && $cartItem->product->stock < $validated['quantity']) {
            return response()->json([
                'message' => 'Stok tidak cukup',
            ], 422);
        }

        $cartItem->update(['quantity' => $validated['quantity']]);

        return response()->json([
            'message' => 'Keranjang diperbarui',
            'item' => $cartItem->load('product'),
        ]);
    }

    /**
     * Remove item from cart
     * REQ-21
     */
    public function remove(Request $request, $cartId): JsonResponse
    {
        $cartItem = Cart::findOrFail($cartId);

        if ($cartItem->user_id !== $request->user()->id) {
            return response()->json([
                'message' => 'Anda tidak punya akses',
            ], 403);
        }

        $cartItem->delete();

        return response()->json([
            'message' => 'Item dihapus dari keranjang',
        ]);
    }

    /**
     * Clear cart
     */
    public function clear(Request $request): JsonResponse
    {
        Cart::where('user_id', $request->user()->id)->delete();

        return response()->json([
            'message' => 'Keranjang dikosongkan',
        ]);
    }
}

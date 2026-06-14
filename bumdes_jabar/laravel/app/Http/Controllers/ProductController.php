<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class ProductController extends Controller
{
    /**
     * Get all categories
     * REQ-17
     */
    public function getCategories(): JsonResponse
    {
        $categories = Category::all();
        return response()->json($categories);
    }

    /**
     * Get all products (public list)
     * REQ-20
     */
    public function index(): JsonResponse
    {
        $products = Product::where('is_active', true)
            ->with('store', 'category')
            ->orderByDesc('created_at')
            ->get()
            ->map(function ($product) {
                return [
                    'id' => $product->id,
                    'name' => $product->name,
                    'store_name' => $product->store?->store_name ?? 'Unknown Store',
                    'location' => $product->store?->village ?? '',
                    'category' => $product->category?->name ?? '',
                    'price' => $product->price,
                    'stock' => $product->stock,
                    'description' => $product->description,
                    'image_url' => $product->photo_url,
                    'is_service' => $product->type === 'jasa',
                    'is_active' => $product->is_active,
                ];
            });

        return response()->json($products);
    }

    /**
     * Get featured products for homepage
     * REQ-20
     */
    public function getFeatured(): JsonResponse
    {
        $products = Product::where('is_active', true)
            ->with('store', 'category')
            ->latest()
            ->limit(4)
            ->get();

        return response()->json([
            'message' => 'Produk unggulan',
            'data' => $products,
        ]);
    }

    /**
     * Get popular stores for homepage
     * REQ-20
     */
    public function getPopularStores(): JsonResponse
    {
        // Get stores with most orders
        $stores = DB::table('stores')
            ->leftJoin('orders', 'stores.id', '=', 'orders.store_id')
            ->select('stores.*', DB::raw('count(orders.id) as order_count'))
            ->where('stores.is_active', true)
            ->groupBy('stores.id')
            ->orderByDesc('order_count')
            ->limit(4)
            ->get();

        return response()->json([
            'message' => 'Toko BUMDes terpopuler',
            'data' => $stores,
        ]);
    }

    /**
     * Search products and stores
     * REQ-16
     */
    public function search(Request $request): JsonResponse
    {
        $keyword = $request->query('q', '');
        $category_id = $request->query('category_id');
        $min_price = $request->query('min_price');
        $max_price = $request->query('max_price');

        $query = Product::where('is_active', true)
            ->with('store', 'category');

        if ($keyword) {
            $query->where(function ($q) use ($keyword) {
                $q->where('products.name', 'like', "%$keyword%")
                    ->orWhere('products.description', 'like', "%$keyword%")
                    ->orWhereHas('store', function ($sq) use ($keyword) {
                        $sq->where('store_name', 'like', "%$keyword%")
                            ->orWhere('village', 'like', "%$keyword%");
                    });
            });
        }

        if ($category_id) {
            $query->where('category_id', $category_id);
        }

        if ($min_price) {
            $query->where('price', '>=', $min_price);
        }

        if ($max_price) {
            $query->where('price', '<=', $max_price);
        }

        $products = $query->paginate(12);

        return response()->json([
            'message' => 'Hasil pencarian produk',
            'data' => $products,
        ]);
    }

    /**
     * Get product details
     * REQ-18
     */
    public function show($id): JsonResponse
    {
        $product = Product::with(['store', 'category', 'reviews.buyer'])->find($id);

        if (!$product || !$product->is_active) {
            return response()->json([
                'message' => 'Produk tidak ditemukan',
            ], 404);
        }

        return response()->json([
            'message' => 'Detail produk',
            'data' => $product,
        ]);
    }

    /**
     * Add new product (seller only)
     * REQ-11
     */
    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->isSeller()) {
            return response()->json([
                'message' => 'Hanya penjual yang dapat menambahkan produk',
            ], 403);
        }

        $store = $user->store;
        if (!$store) {
            return response()->json([
                'message' => 'Anda harus mendaftarkan toko terlebih dahulu',
            ], 403);
        }

        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'category_id' => 'required|exists:categories,id',
            'type' => 'required|in:produk,jasa',
            'price' => 'required|numeric|min:0',
            'stock' => 'required_if:type,produk|numeric|min:0',
            'description' => 'sometimes|string',
            'photo' => 'sometimes|image|mimes:jpeg,png,jpg|max:5120', // 5MB
        ]);

        $photoUrl = null;
        if ($request->hasFile('photo')) {
            $photoUrl = $request->file('photo')->store('product-photos', 'public');
        }

        $product = $store->products()->create([
            'name' => $validated['name'],
            'category_id' => $validated['category_id'],
            'type' => $validated['type'],
            'price' => $validated['price'],
            'stock' => $validated['stock'] ?? 0,
            'description' => $validated['description'] ?? null,
            'photo_url' => $photoUrl,
        ]);

        // Load relationships for response
        $product->load(['store', 'category']);

        return response()->json([
            'message' => 'Produk berhasil ditambahkan',
            'data' => [
                'id' => $product->id,
                'name' => $product->name,
                'store_name' => $product->store?->store_name ?? 'Unknown Store',
                'location' => $product->store?->village ?? '',
                'category' => $product->category?->name ?? '',
                'price' => $product->price,
                'stock' => $product->stock,
                'description' => $product->description,
                'image_url' => $product->photo_url,
                'is_service' => $product->type === 'jasa',
                'is_active' => $product->is_active,
            ],
        ], 201);
    }

    /**
     * Update product (seller only)
     * REQ-12
     */
    public function update(Request $request, $id): JsonResponse
    {
        $user = $request->user();

        if (! $user->isSeller()) {
            return response()->json([
                'message' => 'Hanya penjual yang dapat mengubah produk',
            ], 403);
        }

        $product = Product::find($id);

        $storeOwnerId = $product && $product->store ? $product->store->user_id : null;
        Log::debug('Product update permission check', [
            'user_id' => $user->id,
            'user_role' => $user->role,
            'product_id' => $id,
            'product_exists' => $product !== null,
            'product_store_id' => $product?->store?->id,
            'product_store_owner_id' => $storeOwnerId,
            'request_payload' => $request->all(),
        ]);

        if (!$product || $storeOwnerId !== $user->id) {
            return response()->json([
                'message' => 'Produk tidak ditemukan atau anda tidak punya akses',
            ], 404);
        }

        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'category_id' => 'sometimes|exists:categories,id',
            'type' => 'sometimes|in:produk,jasa',
            'price' => 'sometimes|numeric|min:0',
            'stock' => 'sometimes|numeric|min:0',
            'description' => 'sometimes|string',
            'photo' => 'sometimes|image|mimes:jpeg,png,jpg|max:5120', // 5MB
        ]);

        $photoUrl = $product->photo_url;
        if ($request->hasFile('photo')) {
            $photoUrl = $request->file('photo')->store('product-photos', 'public');
        }

        $validated['photo_url'] = $photoUrl;

        $product->update($validated);

        // Load relationships for response
        $product->load(['store', 'category']);

        return response()->json([
            'message' => 'Produk berhasil diperbarui',
            'data' => [
                'id' => $product->id,
                'name' => $product->name,
                'store_name' => $product->store?->store_name ?? 'Unknown Store',
                'location' => $product->store?->village ?? '',
                'category' => $product->category?->name ?? '',
                'price' => $product->price,
                'stock' => $product->stock,
                'description' => $product->description,
                'image_url' => $product->photo_url,
                'is_service' => $product->type === 'jasa',
                'is_active' => $product->is_active,
            ],
        ]);
    }

    /**
     * Delete product (seller only)
     * REQ-13
     */
    public function destroy(Request $request, $id): JsonResponse
    {
        $user = $request->user();

        if (! $user->isSeller()) {
            return response()->json([
                'message' => 'Hanya penjual yang dapat menghapus produk',
            ], 403);
        }

        $product = Product::find($id);

        if (!$product || $product->store->user_id !== $user->id) {
            return response()->json([
                'message' => 'Produk tidak ditemukan atau anda tidak punya akses',
            ], 404);
        }

        $product->delete();

        return response()->json([
            'message' => 'Produk berhasil dihapus',
        ]);
    }

    /**
     * Admin deactivate product
     * REQ-15
     */
    public function deactivate(Request $request, $id): JsonResponse
    {
        $product = Product::find($id);

        if (!$product) {
            return response()->json([
                'message' => 'Produk tidak ditemukan',
            ], 404);
        }

        $product->update(['is_active' => false]);

        return response()->json([
            'message' => 'Produk berhasil dinonaktifkan',
        ]);
    }

    /**
     * Admin delete product
     * REQ-15
     */
    public function adminDelete(Request $request, $id): JsonResponse
    {
        $product = Product::find($id);

        if (!$product) {
            return response()->json([
                'message' => 'Produk tidak ditemukan',
            ], 404);
        }

        $product->delete();

        return response()->json([
            'message' => 'Produk berhasil dihapus oleh admin',
        ]);
    }

    /**
     * Get products by store
     */
    public function getByStore($store_id): JsonResponse
    {
        $products = Product::where('store_id', $store_id)
            ->where('is_active', true)
            ->with('category')
            ->paginate(12);

        return response()->json([
            'message' => 'Produk toko',
            'data' => $products,
        ]);
    }
}

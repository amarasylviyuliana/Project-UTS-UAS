<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class ProductController extends Controller
{
    // FIX CORS: photo_url di database berupa path relatif (mis. "product-photos/abc.jpg").
    // Flutter Web tidak bisa load langsung dari Railway /storage karena CORS tidak terset di nginx.
    // Solusi: gunakan route /api/image/{path} yang di-handle Laravel → CORS header otomatis terset.
    // Kalau URL sudah absolute (http/https) dari sistem lama, biarkan apa adanya (fallback).
    private function resolvePhotoUrl(?string $path): ?string
    {
        if (!$path) {
            return null;
        }
        // Sudah absolute URL (dari sistem lama / upload luar) — proxy juga supaya CORS aman
        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            // Kalau sudah berupa URL railway /storage/..., konvert ke proxy
            if (preg_match('#/storage/(.+)$#', $path, $m)) {
                $baseUrl = rtrim(env('APP_URL', 'https://project-uts-uas-production.up.railway.app'), '/');
                if (str_contains($baseUrl, 'localhost') || str_contains($baseUrl, '127.0.0.1')) {
                    $baseUrl = 'https://project-uts-uas-production.up.railway.app';
                }
                return $baseUrl . '/api/image/' . $m[1];
            }
            return $path;
        }
        // Path relatif (format baru) → pakai proxy
        $baseUrl = rtrim(env('APP_URL', 'https://project-uts-uas-production.up.railway.app'), '/');
        if (str_contains($baseUrl, 'localhost') || str_contains($baseUrl, '127.0.0.1')) {
            $baseUrl = 'https://project-uts-uas-production.up.railway.app';
        }
        // Hapus prefix /storage/ kalau ada (supaya path bersih untuk proxy)
        $cleanPath = preg_replace('#^/?storage/#', '', $path);
        return $baseUrl . '/api/image/' . ltrim($cleanPath, '/');
    }

    private function mapProductForResponse($product): array
    {
        return [
            'id' => $product->id,
            'name' => $product->name,
            'store_name' => $product->store?->store_name ?? 'Unknown Store',
            'location' => $product->store?->village ?? '',
            'category' => $product->category?->name ?? '',
            'price' => $product->price,
            'stock' => $product->stock,
            'description' => $product->description,
            'image_url' => $this->resolvePhotoUrl($product->photo_url),
            'is_service' => $product->type === 'jasa',
            'is_active' => $product->is_active,
        ];
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
            ->limit(3)
            ->get()
            ->map(fn($product) => $this->mapProductForResponse($product));

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
     * Upload product photo and return its full URL.
     * Dipanggil Flutter SEBELUM create/update produk (lihat product_form_screen.dart).
     * FIX: endpoint ini sebelumnya tidak ada sama sekali di backend -> 404 -> foto tidak pernah tersimpan.
     */
    public function uploadImage(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->isSeller()) {
            return response()->json([
                'message' => 'Hanya penjual yang dapat mengupload foto produk',
            ], 403);
        }

        $request->validate([
            'image' => 'required|image|mimes:jpeg,png,jpg|max:5120', // 5MB
        ]);

        $path = $request->file('image')->store('product-photos', 'public');

        return response()->json([
            'message' => 'Foto berhasil diupload',
            'data' => [
                'image_url' => $this->resolvePhotoUrl($path),
            ],
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

        // FIX: tolak tambah produk selama toko belum disetujui admin
        if (!$store->is_active) {
            return response()->json([
                'message' => 'Toko Anda belum disetujui admin. Mohon tunggu persetujuan sebelum menambahkan produk.',
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
            // FIX: dukung image_url string (hasil dari /products/upload-image)
            // selain upload file langsung lewat field 'photo'
            'image_url' => 'sometimes|nullable|string',
        ]);

        $photoUrl = null;
        if ($request->hasFile('photo')) {
            $photoUrl = $request->file('photo')->store('product-photos', 'public');
        } elseif (!empty($validated['image_url'] ?? null)) {
            $photoUrl = $validated['image_url'];
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
                'image_url' => $this->resolvePhotoUrl($product->photo_url),
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
            // FIX: dukung image_url string (hasil dari /products/upload-image)
            // selain upload file langsung lewat field 'photo'
            'image_url' => 'sometimes|nullable|string',
        ]);

        $photoUrl = $product->photo_url;
        if ($request->hasFile('photo')) {
            $photoUrl = $request->file('photo')->store('product-photos', 'public');
        } elseif (!empty($validated['image_url'] ?? null)) {
            $photoUrl = $validated['image_url'];
        }

        unset($validated['image_url']);
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
                'image_url' => $this->resolvePhotoUrl($product->photo_url),
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

        // FIX: dulu langsung akses $product->store->user_id tanpa cek null,
        // kalau relasi store-nya null PHP fatal error -> muncul sebagai "Gagal menghapus produk"
        if (!$product || !$product->store || $product->store->user_id !== $user->id) {
            return response()->json([
                'message' => 'Produk tidak ditemukan atau anda tidak punya akses',
            ], 404);
        }

        try {
            $product->delete();
        } catch (\Illuminate\Database\QueryException $e) {
            Log::warning('Gagal hapus produk (seller) karena masih terkait data lain', [
                'product_id' => $id,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'message' => 'Produk tidak bisa dihapus karena masih memiliki riwayat pesanan. Nonaktifkan produk ini alih-alih menghapusnya.',
            ], 409);
        }

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

        try {
            $product->delete();
        } catch (\Illuminate\Database\QueryException $e) {
            // FIX: sebelumnya exception ini bocor sebagai 500 mentah kalau produk
            // masih direferensikan oleh order_items (riwayat pesanan). Sekarang
            // ditangani dengan pesan yang jelas + saran nonaktifkan saja, alih-alih
            // menampilkan Internal Server Error yang membingungkan ke admin.
            Log::warning('Gagal hapus produk (admin) karena masih terkait data lain', [
                'product_id' => $id,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'message' => 'Produk tidak bisa dihapus permanen karena masih memiliki riwayat pesanan. Gunakan tombol "Nonaktifkan" agar produk tidak tampil ke pembeli tanpa menghapus riwayat transaksi.',
            ], 409);
        }

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
            ->with('store', 'category')
            ->paginate(12);

        $products->getCollection()->transform(fn($product) => $this->mapProductForResponse($product));

        return response()->json([
            'message' => 'Produk toko',
            'data' => $products,
        ]);
    }
}
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
    private function resolvePhotoUrl(?string $path): ?string
    {
        if (!$path) {
            return null;
        }
        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            if (preg_match('#/storage/(.+)$#', $path, $m)) {
                $baseUrl = rtrim(env('APP_URL', 'https://project-uts-uas-production.up.railway.app'), '/');
                if (str_contains($baseUrl, 'localhost') || str_contains($baseUrl, '127.0.0.1')) {
                    $baseUrl = 'https://project-uts-uas-production.up.railway.app';
                }
                return $baseUrl . '/api/image/' . $m[1];
            }
            return $path;
        }
        $baseUrl = rtrim(env('APP_URL', 'https://project-uts-uas-production.up.railway.app'), '/');
        if (str_contains($baseUrl, 'localhost') || str_contains($baseUrl, '127.0.0.1')) {
            $baseUrl = 'https://project-uts-uas-production.up.railway.app';
        }
        $cleanPath = preg_replace('#^/?storage/#', '', $path);
        return $baseUrl . '/api/image/' . ltrim($cleanPath, '/');
    }

    // TAMBAHAN: data toko (id, nama, foto toko, lokasi) dipisah jadi helper
    // sendiri, dipakai baik oleh listing produk maupun detail produk, supaya
    // Flutter bisa menampilkan kartu toko ala Shopee (foto toko + nama +
    // lokasi) di halaman detail produk.
    //
    // FIX: banyak toko belum pernah upload store_photo_url-nya sendiri
    // (field ini terpisah dari foto profil pribadi penjual), sehingga kartu
    // toko di sisi pembeli selalu fallback ke icon generik walau penjualnya
    // sudah punya foto profil. Sekarang: kalau store_photo_url kosong, kita
    // fallback ke foto profil PRIBADI pemilik toko (user->photo_url) supaya
    // pembeli tetap melihat identitas visual tokonya. Kalau seller nanti
    // upload foto toko sendiri lewat menu "Profil Toko", foto itu yang akan
    // dipakai (foto toko selalu diprioritaskan di atas foto pribadi).
    private function mapStoreForResponse($store): ?array
    {
        if (!$store) return null;

        $storePhoto = $this->resolvePhotoUrl($store->store_photo_url);
        if (!$storePhoto) {
            // Fallback: pakai foto profil pribadi pemilik toko, kalau ada.
            $storePhoto = $this->resolvePhotoUrl($store->user?->photo_url);
        }

        return [
            'id'              => $store->id,
            'store_name'      => $store->store_name,
            'village'         => $store->village,
            'district'        => $store->district ?? null,
            'regency'         => $store->regency ?? null,
            'store_photo_url' => $storePhoto,
        ];
    }

    private function mapProductForResponse($product): array
    {
        return [
            'id' => $product->id,
            'name' => $product->name,
            'store_name' => $product->store?->store_name ?? 'Unknown Store',
            'location' => $product->store?->village ?? '',
            // TAMBAHAN: store_id + object store lengkap (termasuk foto toko)
            'store_id' => $product->store?->id,
            'store' => $this->mapStoreForResponse($product->store),
            'category' => $product->category?->name ?? '',
            'price' => $product->price,
            'stock' => $product->stock,
            'description' => $product->description,
            'image_url' => $this->resolvePhotoUrl($product->photo_url),
            'is_service' => $product->type === 'jasa',
            'is_active' => $product->is_active,
        ];
    }

    public function index(): JsonResponse
    {
        // DIUBAH: eager load 'store.user' (bukan cuma 'store'), supaya
        // mapStoreForResponse bisa fallback ke foto profil pemilik toko
        // tanpa memicu query tambahan per produk (N+1).
        $products = Product::where('is_active', true)
            ->with('store.user', 'category')
            ->latest()
            ->get()
            ->map(fn($product) => $this->mapProductForResponse($product));

        return response()->json([
            'message' => 'Daftar produk',
            'data' => $products,
        ]);
    }

    public function getPopularStores(): JsonResponse
    {
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

    public function search(Request $request): JsonResponse
    {
        $keyword = $request->query('q', '');
        $category_id = $request->query('category_id');
        $min_price = $request->query('min_price');
        $max_price = $request->query('max_price');

        // DIUBAH: eager load 'store.user' (bukan cuma 'store').
        $query = Product::where('is_active', true)
            ->with('store.user', 'category');

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
        $products->getCollection()->transform(fn($product) => $this->mapProductForResponse($product));

        return response()->json([
            'message' => 'Hasil pencarian produk',
            'data' => $products,
        ]);
    }

    /**
     * Get product details
     *
     * FIX: sebelumnya method ini return `$product` mentah (hasil Eloquent
     * toArray otomatis), yang berarti `store.store_photo_url` dikirim
     * sebagai PATH RELATIF tanpa lewat resolvePhotoUrl() — persis masalah
     * CORS/gagal-load yang sama seperti foto profil user, hanya saja belum
     * ketahuan karena Flutter belum pernah menampilkan foto toko di halaman
     * ini. Sekarang responsnya dibentuk manual lewat mapProductForResponse()
     * (konsisten dengan index/search/getByStore) + reviews, supaya
     * store_photo_url selalu berupa URL proxy yang valid dan bisa dimuat
     * oleh Image.network() di Flutter.
     *
     * DIUBAH: eager load 'store.user' juga, supaya mapStoreForResponse bisa
     * fallback ke foto profil pribadi pemilik toko kalau store_photo_url
     * kosong.
     */
    public function show($id): JsonResponse
    {
        $product = Product::with(['store.user', 'category', 'reviews.buyer'])->find($id);

        if (!$product || !$product->is_active) {
            return response()->json([
                'message' => 'Produk tidak ditemukan',
            ], 404);
        }

        $data = $this->mapProductForResponse($product);
        $data['reviews'] = $product->reviews->map(function ($review) {
            return [
                'id'      => $review->id,
                'rating'  => $review->rating,
                'comment' => $review->comment,
                'buyer_name' => $review->buyer?->name ?? 'Pembeli',
                'created_at' => $review->created_at,
            ];
        });

        return response()->json([
            'message' => 'Detail produk',
            'data' => $data,
        ]);
    }

    public function uploadImage(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->isSeller()) {
            return response()->json([
                'message' => 'Hanya penjual yang dapat mengupload foto produk',
            ], 403);
        }

        $request->validate([
            'image' => 'required|image|mimes:jpeg,png,jpg|max:5120',
        ]);

        $path = $request->file('image')->store('product-photos', 'public');

        return response()->json([
            'message' => 'Foto berhasil diupload',
            'data' => [
                'image_url' => $this->resolvePhotoUrl($path),
            ],
        ]);
    }

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
            'photo' => 'sometimes|image|mimes:jpeg,png,jpg|max:5120',
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

        $product->load(['store.user', 'category']);

        return response()->json([
            'message' => 'Produk berhasil ditambahkan',
            'data' => $this->mapProductForResponse($product),
        ], 201);
    }

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
            'photo' => 'sometimes|image|mimes:jpeg,png,jpg|max:5120',
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

        $product->load(['store.user', 'category']);

        return response()->json([
            'message' => 'Produk berhasil diperbarui',
            'data' => $this->mapProductForResponse($product),
        ]);
    }

    public function destroy(Request $request, $id): JsonResponse
    {
        $user = $request->user();

        if (! $user->isSeller()) {
            return response()->json([
                'message' => 'Hanya penjual yang dapat menghapus produk',
            ], 403);
        }

        $product = Product::find($id);

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

    public function getByStore($store_id): JsonResponse
    {
        // DIUBAH: eager load 'store.user' (bukan cuma 'store').
        $products = Product::where('store_id', $store_id)
            ->where('is_active', true)
            ->with('store.user', 'category')
            ->paginate(12);

        $products->getCollection()->transform(fn($product) => $this->mapProductForResponse($product));

        return response()->json([
            'message' => 'Produk toko',
            'data' => $products,
        ]);
    }

    public function getCategories(): JsonResponse
    {
        $categories = Category::all();

        return response()->json($categories);
    }

    public function getPlatformFeeInfo(): JsonResponse
    {
        return response()->json([
            'status' => 'success',
            'data' => [
                'tax_percentage' => (float) config('platform.tax_percentage', 5),
            ],
        ]);
    }
}
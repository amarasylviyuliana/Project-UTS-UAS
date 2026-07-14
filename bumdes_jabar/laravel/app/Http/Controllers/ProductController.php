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
                $baseUrl = rtrim(env('APP_URL', 'https://bumdes-api-production.up.railway.app'), '/');
                if (str_contains($baseUrl, 'localhost') || str_contains($baseUrl, '127.0.0.1')) {
                    $baseUrl = 'https://bumdes-api-production.up.railway.app';
                }
                return $baseUrl . '/api/image/' . $m[1];
            }
            return $path;
        }
        $baseUrl = rtrim(env('APP_URL', 'https://bumdes-api-production.up.railway.app'), '/');
        if (str_contains($baseUrl, 'localhost') || str_contains($baseUrl, '127.0.0.1')) {
            $baseUrl = 'https://bumdes-api-production.up.railway.app';
        }
        $cleanPath = preg_replace('#^/?storage/#', '', $path);
        return $baseUrl . '/api/image/' . ltrim($cleanPath, '/');
    }

    private function mapStoreForResponse($store): ?array
    {
        if (!$store) return null;

        $storePhoto = $this->resolvePhotoUrl($store->store_photo_url);
        if (!$storePhoto) {
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

    public function getFeaturedProducts(): JsonResponse
    {
        $products = Product::where('products.is_active', true)
            ->leftJoin('order_items', 'order_items.product_id', '=', 'products.id')
            ->select('products.*', DB::raw('COALESCE(SUM(order_items.quantity), 0) as total_sold'))
            ->groupBy('products.id')
            ->with('store.user', 'category')
            ->orderByDesc('total_sold')
            ->orderByDesc('products.created_at')
            ->limit(6)
            ->get()
            ->map(fn($product) => $this->mapProductForResponse($product));

        return response()->json([
            'message' => 'Produk unggulan',
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

    // TAMBAHAN: daftar SEMUA BUMDes (toko) yang aktif, publik (tanpa
    // login), dengan dukungan pencarian (?q=) dan filter wilayah
    // kabupaten/kota (?region=). Dipakai oleh halaman "BUMDes" di
    // aplikasi Flutter (BumdesListScreen).
    //
    // Setiap BUMDes juga disertai:
    // - product_count : jumlah produk/jasa aktif milik toko itu
    // - categories    : daftar nama kategori unik yang dijual toko itu
    //   (dipakai untuk tag "Kuliner Desa, Pertanian" di kartu BUMDes)
    //
    // FIX FOTO TIDAK MUNCUL: sebelumnya endpoint ini HANYA mengambil
    // store_photo_url langsung dari tabel stores, TANPA fallback ke foto
    // profil pemilik toko (users.photo_url). Padahal
    // ProductController::mapStoreForResponse() (dipakai di halaman detail
    // produk & produk toko) SELALU melakukan fallback itu:
    //   jika store_photo_url kosong -> pakai foto profil user pemilik toko.
    // Karena banyak toko belum upload foto toko khusus dan hanya
    // mengandalkan foto profil akunnya, daftar BUMDes jadi selalu tampil
    // avatar inisial huruf ("B") walau di halaman lain foto (foto profil
    // pemilik) berhasil tampil. Sekarang query di-join ke tabel users
    // supaya foto profil pemilik ikut terbawa dan dipakai sebagai
    // fallback, PERSIS seperti perilaku mapStoreForResponse().
    //
    // CATATAN: belum ada kolom/agregasi rating untuk toko di database,
    // jadi endpoint ini TIDAK mengirim field rating. Kalau nanti mau
    // ditambahkan, sebaiknya dihitung dari rata-rata rating produk milik
    // toko (tabel product_reviews) lalu di-cache, bukan dihitung on the
    // fly di setiap request daftar BUMDes (berat).
    public function getStores(Request $request): JsonResponse
    {
        $keyword = trim((string) $request->query('q', ''));
        $region = trim((string) $request->query('region', ''));

        // TAMBAHAN: leftJoin ke users supaya kita bisa fallback ke foto
        // profil pemilik toko kalau store_photo_url kosong (lihat catatan
        // FIX di atas). Semua kolom disebut eksplisit dengan prefix
        // 'stores.' untuk menghindari ambiguous column error akibat join.
        $query = DB::table('stores')
            ->leftJoin('users', 'stores.user_id', '=', 'users.id')
            ->where('stores.is_active', true)
            ->select('stores.*', 'users.photo_url as owner_photo_url');

        if ($keyword !== '') {
            $query->where(function ($q) use ($keyword) {
                $q->where('stores.store_name', 'like', "%$keyword%")
                    ->orWhere('stores.village', 'like', "%$keyword%")
                    ->orWhere('stores.district', 'like', "%$keyword%")
                    ->orWhere('stores.regency', 'like', "%$keyword%");
            });
        }

        if ($region !== '' && $region !== 'Semua Wilayah') {
            $query->where(function ($q) use ($region) {
                $q->where('stores.regency', $region)->orWhere('stores.district', $region);
            });
        }

        $stores = $query->orderBy('stores.store_name')->paginate(20);
        $storeIds = collect($stores->items())->pluck('id');

        // Jumlah produk aktif per toko (satu query untuk semua toko di
        // halaman ini, bukan N+1 query per toko).
        $productCounts = DB::table('products')
            ->whereIn('store_id', $storeIds)
            ->where('is_active', true)
            ->select('store_id', DB::raw('count(*) as total'))
            ->groupBy('store_id')
            ->pluck('total', 'store_id');

        // Kategori unik yang dijual tiap toko.
        $categoriesByStore = DB::table('products')
            ->join('categories', 'products.category_id', '=', 'categories.id')
            ->whereIn('products.store_id', $storeIds)
            ->where('products.is_active', true)
            ->select('products.store_id', 'categories.name')
            ->distinct()
            ->get()
            ->groupBy('store_id')
            ->map(fn($rows) => $rows->pluck('name')->values());

        $data = collect($stores->items())->map(function ($store) use (
            $productCounts,
            $categoriesByStore
        ) {
            // FIX: fallback ke foto profil pemilik toko kalau toko belum
            // punya foto khusus, sama seperti mapStoreForResponse().
            $storePhoto = $this->resolvePhotoUrl($store->store_photo_url ?? null);
            if (!$storePhoto) {
                $storePhoto = $this->resolvePhotoUrl($store->owner_photo_url ?? null);
            }

            return [
                'id' => $store->id,
                'store_name' => $store->store_name,
                'village' => $store->village,
                'district' => $store->district ?? null,
                'regency' => $store->regency ?? null,
                'store_photo_url' => $storePhoto,
                'product_count' => $productCounts[$store->id] ?? 0,
                'categories' => ($categoriesByStore[$store->id] ?? collect())->values(),
            ];
        });

        return response()->json([
            'message' => 'Daftar BUMDes',
            'data' => $data,
            'meta' => [
                'current_page' => $stores->currentPage(),
                'last_page' => $stores->lastPage(),
                'total' => $stores->total(),
            ],
        ]);
    }

    public function search(Request $request): JsonResponse
    {
        $keyword = $request->query('q', '');
        $category_id = $request->query('category_id');
        $min_price = $request->query('min_price');
        $max_price = $request->query('max_price');

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
            // Seller boleh set status aktif produk/jasa saat membuat.
            // Dipakai untuk toggle Tersedia/Tidak Tersedia pada Jasa.
            // Kalau tidak dikirim, default aktif (true).
            'is_active' => 'sometimes|boolean',
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
            'is_active' => $validated['is_active'] ?? true,
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
            // Sebelumnya seller HANYA bisa nonaktifkan produk lewat
            // endpoint /deactivate (khusus admin). Sekarang seller bisa
            // toggle is_active sendiri lewat form edit — dipakai untuk
            // toggle Tersedia/Tidak Tersedia pada Jasa.
            'is_active' => 'sometimes|boolean',
        ]);

        $photoUrl = $product->photo_url;
        if ($request->hasFile('photo')) {
            $photoUrl = $request->file('photo')->store('product-photos', 'public');
        } elseif (!empty($validated['image_url'] ?? null)) {
            $photoUrl = $validated['image_url'];
        }

        // 'photo' berisi objek UploadedFile dan 'image_url' cuma dipakai
        // untuk menentukan $photoUrl di atas — keduanya harus dibuang
        // supaya tidak ikut terbawa ke $product->update().
        unset($validated['image_url'], $validated['photo']);
        $validated['photo_url'] = $photoUrl;

        // Kalau field is_active tidak dikirim (mis. request lama / klien
        // belum update), pertahankan status aktif yang sudah ada supaya
        // tidak diam-diam berubah jadi default true.
        if (!array_key_exists('is_active', $validated)) {
            $validated['is_active'] = $product->is_active;
        }

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
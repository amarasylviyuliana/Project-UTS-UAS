<?php

namespace App\Http\Controllers\Admin;

use App\Models\Admin;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Storage;

class AdminController extends Controller
{
    /**
     * FIX: sebelumnya method ini pakai Storage::disk('public')->url($path),
     * yang menghasilkan URL "/storage/..." langsung. Pola ini SUDAH TERBUKTI
     * gagal dimuat oleh Image.network() di Flutter (lihat catatan di
     * ProductController@resolvePhotoUrl — kemungkinan besar karena CORS atau
     * symlink storage tidak aktif di hosting Railway).
     *
     * Sekarang disamakan persis dengan ProductController@resolvePhotoUrl:
     * semua path (relatif maupun URL /storage/ lama) diarahkan lewat proxy
     * "/api/image/{path}", supaya konsisten dan benar-benar bisa dimuat.
     */
    private function formatPhotoUrl(?string $path): ?string
    {
        if (empty($path)) {
            return null;
        }

        $baseUrl = rtrim(env('APP_URL', 'https://bumdes-api-production.up.railway.app'), '/');
        if (str_contains($baseUrl, 'localhost') || str_contains($baseUrl, '127.0.0.1')) {
            $baseUrl = 'https://bumdes-api-production.up.railway.app';
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            // Kalau sudah berupa URL lengkap tapi masih mengandung "/storage/...",
            // ambil bagian setelah "/storage/" dan arahkan lewat proxy /api/image/.
            if (preg_match('#/storage/(.+)$#', $path, $m)) {
                return $baseUrl . '/api/image/' . $m[1];
            }
            // Sudah berupa URL lengkap non-storage (mis. sudah proxy /api/image/),
            // biarkan apa adanya.
            return $path;
        }

        // Path relatif mentah (mis. "profile-photos/xxx.jpg" atau "store-photos/xxx.jpg")
        $cleanPath = preg_replace('#^/?storage/#', '', $path);
        return $baseUrl . '/api/image/' . ltrim($cleanPath, '/');
    }

    /**
     * Get all admins
     */
    public function getAllAdmins()
    {
        $admins = Admin::with('user')
            ->orderBy('created_at', 'desc')
            ->paginate(15);

        return response()->json([
            'status' => 'success',
            'data' => $admins
        ]);
    }

    /**
     * Get admin detail
     */
    public function getAdminDetail($id)
    {
        $admin = Admin::with('user')->find($id);

        if (!$admin) {
            return response()->json([
                'status' => 'error',
                'message' => 'Admin tidak ditemukan'
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'data' => $admin
        ]);
    }

    /**
     * Create new admin
     */
    public function createAdmin(Request $request)
    {
        $request->validate([
            'user_id' => 'required|exists:users,id|unique:admins',
            'department' => 'required|string',
            'job_title' => 'required|string',
            'phone_internal' => 'nullable|string',
            'is_super_admin' => 'boolean',
            'permissions' => 'nullable|json',
        ]);

        try {
            $user = \App\Models\User::find($request->user_id);
            if ($user->role !== 'Admin') {
                return response()->json([
                    'status' => 'error',
                    'message' => 'User harus memiliki role Admin'
                ], 422);
            }

            $admin = Admin::create($request->all());

            return response()->json([
                'status' => 'success',
                'message' => 'Admin berhasil dibuat',
                'data' => $admin->load('user')
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal membuat admin: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Update admin
     */
    public function updateAdmin(Request $request, $id)
    {
        $admin = Admin::find($id);

        if (!$admin) {
            return response()->json([
                'status' => 'error',
                'message' => 'Admin tidak ditemukan'
            ], 404);
        }

        $request->validate([
            'department' => 'string',
            'job_title' => 'string',
            'phone_internal' => 'nullable|string',
            'is_super_admin' => 'boolean',
            'permissions' => 'nullable|json',
            'is_active' => 'boolean',
        ]);

        try {
            $admin->update($request->all());

            return response()->json([
                'status' => 'success',
                'message' => 'Admin berhasil diupdate',
                'data' => $admin->fresh()->load('user')
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal mengupdate admin: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get audit logs for admin
     */
    public function getAdminAuditLogs($adminId)
    {
        $logs = AuditLog::where('admin_id', $adminId)
            ->orderBy('created_at', 'desc')
            ->paginate(50);

        return response()->json([
            'status' => 'success',
            'data' => $logs
        ]);
    }

    /**
     * Get all audit logs (super admin only)
     */
    public function getAllAuditLogs(Request $request)
    {
        $query = AuditLog::with('admin.user');

        if ($request->admin_id) {
            $query->where('admin_id', $request->admin_id);
        }
        if ($request->action) {
            $query->where('action', $request->action);
        }
        if ($request->model_type) {
            $query->where('model_type', $request->model_type);
        }
        if ($request->start_date) {
            $query->whereDate('created_at', '>=', $request->start_date);
        }
        if ($request->end_date) {
            $query->whereDate('created_at', '<=', $request->end_date);
        }

        $logs = $query->orderBy('created_at', 'desc')->paginate(50);

        return response()->json([
            'status' => 'success',
            'data' => $logs
        ]);
    }

    /**
     * Get admin dashboard stats
     */
    public function getDashboardStats()
    {
        if (auth()->user()->role !== 'Admin') {
            return response()->json([
                'status' => 'error',
                'message' => 'Anda bukan admin'
            ], 403);
        }

        $stats = [
            'total_users'    => \App\Models\User::count(),
            'total_sellers'  => \App\Models\User::where('role', 'Penjual')->count(),
            'total_buyers'   => \App\Models\User::where('role', 'Pembeli')->count(),
            'total_stores'   => \App\Models\Store::count(),
            'total_active_stores' => \App\Models\Store::where('is_active', true)->count(),
            'total_orders'   => \App\Models\Order::count(),
            'total_revenue'  => (float) \App\Models\Order::where('status', 'Selesai')->sum('total_price'),
            'pending_product_approvals' => \App\Models\ProductApproval::where('status', 'Menunggu Persetujuan')->count(),
            'total_approved_products'   => \App\Models\ProductApproval::where('status', 'Disetujui')->count(),
        ];

        return response()->json([
            'status' => 'success',
            'data' => $stats
        ]);
    }

    /**
     * Get all orders (admin)
     */
    public function getAllOrders(Request $request)
    {
        $query = \App\Models\Order::with(['buyer', 'store', 'payment']);

        if ($request->status) {
            $query->where('status', $request->status);
        }

        $orders = $query->orderBy('created_at', 'desc')
            ->paginate(15)
            ->through(function ($order) {
                return [
                    'id'               => $order->id,
                    'order_number'     => $order->order_number,
                    'status'           => $order->status,
                    'recipient_name'   => $order->recipient_name,
                    'recipient_phone'  => $order->recipient_phone,
                    'total'            => $order->total_price,
                    'total_price'      => $order->total_price,
                    'created_at'       => $order->created_at,
                    'user'  => $order->buyer ? [
                        'id'    => $order->buyer->id,
                        'name'  => $order->buyer->name,
                        'email' => $order->buyer->email,
                    ] : null,
                    'store' => $order->store ? [
                        'id'         => $order->store->id,
                        'store_name' => $order->store->store_name,
                    ] : null,
                    'payment_status' => $order->payment?->payment_status,
                ];
            });

        return response()->json([
            'status' => 'success',
            'data'   => $orders,
        ]);
    }

    /**
     * Get all users (admin)
     *
     * TAMBAHAN: sekarang menyertakan `photo_url` (foto profil Penjual) dan
     * `store.store_photo_url` sudah dalam bentuk URL LENGKAP (bukan path
     * relatif mentah), supaya Image.network() di Flutter berhasil memuatnya
     * — konsisten dengan ProfileController@formatUser.
     */
    public function getAllUsers(Request $request)
    {
        $query = \App\Models\User::with(['store'])->where('role', 'Penjual');

        $users = $query->orderBy('created_at', 'desc')
            ->paginate(15)
            ->through(function ($user) {
                return [
                    'id'         => $user->id,
                    'name'       => $user->name,
                    'email'      => $user->email,
                    'role'       => $user->role,
                    'phone'      => $user->phone,
                    'photo_url'  => $this->formatPhotoUrl($user->photo_url),
                    'created_at' => $user->created_at,
                    'store' => $user->store ? [
                        'id'                  => $user->store->id,
                        'store_name'          => $user->store->store_name,
                        'description'         => $user->store->description,
                        'address'             => $user->store->address,
                        'contact_phone'       => $user->store->contact_phone,
                        'village'             => $user->store->village,
                        'district'            => $user->store->district,
                        'regency'             => $user->store->regency,
                        'store_photo_url'     => $this->formatPhotoUrl($user->store->store_photo_url),
                        'is_active'           => $user->store->is_active,
                        'bank_name'           => $user->store->bank_name,
                        'bank_account_number' => $user->store->bank_account_number,
                        'bank_account_holder' => $user->store->bank_account_holder,
                    ] : null,
                ];
            });

        return response()->json([
            'status' => 'success',
            'data'   => $users,
        ]);
    }

    /**
     * Get all buyers (admin) — read-only + hapus saja.
     *
     * TAMBAHAN: sekarang menyertakan `photo_url` (foto profil Pembeli)
     * dalam bentuk URL lengkap, supaya avatar Pembeli di dashboard Admin
     * ikut menampilkan foto asli, bukan selalu fallback ke inisial huruf.
     */
    public function getAllBuyers(Request $request)
    {
        $query = \App\Models\User::where('role', 'Pembeli');

        if ($request->search) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%");
            });
        }

        $buyers = $query->orderBy('created_at', 'desc')
            ->paginate(15)
            ->through(function ($user) {
                return [
                    'id'           => $user->id,
                    'name'         => $user->name,
                    'email'        => $user->email,
                    'role'         => $user->role,
                    'phone'        => $user->phone,
                    'photo_url'    => $this->formatPhotoUrl($user->photo_url),
                    'created_at'   => $user->created_at,
                    'total_orders' => \App\Models\Order::where('buyer_id', $user->id)->count(),
                ];
            });

        return response()->json([
            'status' => 'success',
            'data'   => $buyers,
        ]);
    }

    /**
     * Get all stores (admin)
     *
     * TAMBAHAN: menyertakan `store_photo_url` dalam bentuk URL lengkap,
     * supaya kartu Toko/BUMDes di dashboard Admin ikut menampilkan foto
     * toko asli, bukan selalu fallback ke icon generik.
     */
    public function getAllStores(Request $request)
    {
        $stores = \App\Models\Store::with(['user'])
            ->orderBy('created_at', 'desc')
            ->paginate(15)
            ->through(function ($store) {
                $revenue = \App\Models\Order::where('store_id', $store->id)
                    ->where('status', 'Selesai')
                    ->sum('total_price');

                return [
                    'id'              => $store->id,
                    'store_name'      => $store->store_name,
                    'village'         => $store->village,
                    'district'        => $store->district,
                    'regency'         => $store->regency,
                    'is_active'       => $store->is_active,
                    'status'          => $store->is_active ? 'Aktif' : 'Nonaktif',
                    'owner_name'      => $store->user?->name,
                    'store_photo_url' => $this->formatPhotoUrl($store->store_photo_url),
                    'user' => $store->user ? [
                        'id'        => $store->user->id,
                        'name'      => $store->user->name,
                        'email'     => $store->user->email,
                        'photo_url' => $this->formatPhotoUrl($store->user->photo_url),
                    ] : null,
                    'total_revenue' => (float) $revenue,
                    'revenue'       => (float) $revenue,
                ];
            });

        return response()->json([
            'status' => 'success',
            'data'   => $stores,
        ]);
    }

    /**
     * Get all products (admin)
     *
     * TAMBAHAN: sekarang eager-load 'store.user' dan menyertakan
     * `store.user.name` + `store.user.photo_url` (foto profil PENJUAL
     * pemilik toko, URL LENGKAP lewat formatPhotoUrl) di setiap produk.
     * Sebelumnya field ini tidak dikirim sama sekali, jadi Manajemen
     * Produk di Admin tidak pernah bisa menampilkan foto penjualnya.
     */
    public function getAllProducts(Request $request)
    {
        $products = \App\Models\Product::with(['store.user', 'category', 'productApproval'])
            ->orderBy('created_at', 'desc')
            ->paginate(15)
            ->through(function ($product) {
                return [
                    'id'              => $product->id,
                    'name'            => $product->name,
                    'price'           => $product->price,
                    'stock'           => $product->stock,
                    'is_active'       => $product->is_active,
                    'status'          => $product->is_active ? 'Aktif' : 'Nonaktif',
                    'approval_status' => $product->productApproval?->status,
                    'store' => $product->store ? [
                        'id'         => $product->store->id,
                        'store_name' => $product->store->store_name,
                        'user' => $product->store->user ? [
                            'id'        => $product->store->user->id,
                            'name'      => $product->store->user->name,
                            'photo_url' => $this->formatPhotoUrl($product->store->user->photo_url),
                        ] : null,
                    ] : null,
                    'category' => $product->category?->name,
                ];
            });

        return response()->json([
            'status' => 'success',
            'data'   => $products,
        ]);
    }

    /**
     * Delete user (admin)
     */
    public function deleteUser($id)
    {
        $user = \App\Models\User::find($id);
        if (!$user) {
            return response()->json(['status' => 'error', 'message' => 'User tidak ditemukan'], 404);
        }

        $finalOrderStatuses = ['Selesai', 'Dibatalkan', 'Ditolak'];

        if ($user->role === 'Pembeli') {
            $activeOrdersCount = \App\Models\Order::where('buyer_id', $user->id)
                ->whereNotIn('status', $finalOrderStatuses)
                ->count();

            if ($activeOrdersCount > 0) {
                return response()->json([
                    'status'  => 'error',
                    'code'    => 'has_active_orders',
                    'message' => "Pengguna ini masih memiliki {$activeOrdersCount} pesanan yang sedang berjalan (belum selesai, belum dibatalkan, atau belum ditolak). Tunggu sampai semua pesanannya selesai atau dibatalkan terlebih dahulu sebelum menghapus akun ini.",
                ], 409);
            }

            \App\Models\Order::where('buyer_id', $user->id)
                ->whereIn('status', $finalOrderStatuses)
                ->update(['buyer_id' => null]);
        }

        try {
            $user->delete();
            return response()->json(['status' => 'success', 'message' => 'User berhasil dihapus']);
        } catch (\Illuminate\Database\QueryException $e) {
            if ($e->getCode() === '23000') {
                return response()->json([
                    'status'  => 'error',
                    'code'    => 'has_related_data',
                    'message' => 'Pengguna ini tidak bisa dihapus karena masih memiliki data terkait (mis. toko atau produk) yang tersimpan di sistem. Data itu perlu diselesaikan/dihapus dulu sebelum akun ini bisa dihapus permanen.',
                ], 409);
            }

            return response()->json([
                'status'  => 'error',
                'message' => 'Gagal menghapus pengguna: ' . $e->getMessage(),
            ], 500);
        } catch (\Exception $e) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Gagal menghapus pengguna: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Update store is_active status (admin)
     */
    public function updateStore(Request $request, $id)
    {
        $store = \App\Models\Store::find($id);
        if (!$store) {
            return response()->json(['status' => 'error', 'message' => 'Toko tidak ditemukan'], 404);
        }

        if (auth()->user()->role !== 'Admin') {
            return response()->json(['status' => 'error', 'message' => 'Bukan admin'], 403);
        }

        if ($request->has('is_active')) {
            $store->update(['is_active' => $request->is_active]);
        }

        return response()->json([
            'status'  => 'success',
            'message' => 'Status toko berhasil diperbarui',
            'data'    => $store->fresh(),
        ]);
    }

    /**
     * Delete store (admin)
     */
    public function deleteStore($id)
    {
        $store = \App\Models\Store::find($id);
        if (!$store) {
            return response()->json(['status' => 'error', 'message' => 'Toko tidak ditemukan'], 404);
        }

        try {
            $store->delete();
            return response()->json(['status' => 'success', 'message' => 'Toko berhasil dihapus']);
        } catch (\Illuminate\Database\QueryException $e) {
            if ($e->getCode() === '23000') {
                return response()->json([
                    'status'  => 'error',
                    'message' => 'Toko ini tidak bisa dihapus karena masih memiliki produk atau pesanan terkait. Hapus/nonaktifkan produknya dulu, atau nonaktifkan saja tokonya lewat tombol "Nonaktifkan".',
                ], 409);
            }

            return response()->json([
                'status'  => 'error',
                'message' => 'Gagal menghapus toko: ' . $e->getMessage(),
            ], 500);
        } catch (\Exception $e) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Gagal menghapus toko: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Delete product (admin)
     */
    public function deleteProduct($id)
    {
        $product = \App\Models\Product::find($id);
        if (!$product) {
            return response()->json(['status' => 'error', 'message' => 'Produk tidak ditemukan'], 404);
        }

        try {
            $product->delete();
            return response()->json(['status' => 'success', 'message' => 'Produk berhasil dihapus']);
        } catch (\Illuminate\Database\QueryException $e) {
            if ($e->getCode() === '23000') {
                return response()->json([
                    'status'  => 'error',
                    'message' => 'Produk ini tidak bisa dihapus karena masih ada di dalam riwayat pesanan. Nonaktifkan saja produknya kalau tidak ingin ditampilkan lagi.',
                ], 409);
            }

            return response()->json([
                'status'  => 'error',
                'message' => 'Gagal menghapus produk: ' . $e->getMessage(),
            ], 500);
        } catch (\Exception $e) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Gagal menghapus produk: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Create user (admin)
     */
    public function createUser(Request $request)
    {
        $rules = [
            'name'     => 'required|string|max:255',
            'email'    => 'required|email|unique:users',
            'password' => 'nullable|string|min:8',
            'phone'    => 'required|string|max:20',

            'store_name'          => 'required|string|max:255',
            'description'         => 'nullable|string',
            'contact_phone'       => 'required|string|max:20',
            'store_address'       => 'nullable|string|max:500',
            'village'             => 'required|string|max:100',
            'district'            => 'required|string|max:100',
            'regency'             => 'required|string|max:100',
            'bank_account_number' => 'nullable|string|max:50',
            'bank_name'           => 'nullable|string|max:100',
            'bank_account_holder' => 'nullable|string|max:255',
            'store_photo'         => 'nullable|image|mimes:jpeg,png,jpg|max:5120',
        ];

        $validated = $request->validate($rules);

        try {
            $result = \Illuminate\Support\Facades\DB::transaction(function () use ($request, $validated) {
                $user = \App\Models\User::create([
                    'name'     => $validated['name'],
                    'email'    => $validated['email'],
                    'role'     => 'Penjual',
                    'phone'    => $validated['phone'],
                    'password' => bcrypt($validated['password'] ?? 'password123'),
                    'email_verified_at' => now(),
                ]);

                $storePhotoUrl = null;
                if ($request->hasFile('store_photo')) {
                    $storePhotoUrl = $request->file('store_photo')->store('store-photos', 'public');
                }

                $store = \App\Models\Store::create([
                    'user_id'             => $user->id,
                    'store_name'          => $validated['store_name'],
                    'description'         => $validated['description'] ?? null,
                    'address'             => $validated['store_address'] ?? null,
                    'village'             => $validated['village'],
                    'district'            => $validated['district'],
                    'regency'             => $validated['regency'],
                    'contact_phone'       => $validated['contact_phone'],
                    'bank_account_number' => $validated['bank_account_number'] ?? null,
                    'bank_name'           => $validated['bank_name'] ?? null,
                    'bank_account_holder' => $validated['bank_account_holder'] ?? $validated['name'],
                    'store_photo_url'     => $storePhotoUrl,
                    'is_active'           => true,
                ]);

                return [$user, $store];
            });

            [$user, $store] = $result;

            return response()->json([
                'status'  => 'success',
                'message' => 'Akun Penjual dan Toko/BUMDes berhasil dibuat dan langsung aktif',
                'data' => array_merge($user->toArray(), ['store' => $store]),
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Gagal membuat pengguna: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Update user (admin)
     */
    public function updateUser(Request $request, $id)
    {
        $user = \App\Models\User::find($id);
        if (!$user) {
            return response()->json(['status' => 'error', 'message' => 'User tidak ditemukan'], 404);
        }

        $user->update($request->only(['name', 'email', 'phone']));

        $storeFields = $request->only([
            'store_name', 'description', 'village', 'district', 'regency',
            'contact_phone', 'bank_account_number', 'bank_name', 'bank_account_holder',
        ]);
        if ($request->has('store_address')) {
            $storeFields['address'] = $request->input('store_address');
        }

        if ($user->isSeller() && !empty($storeFields)) {
            $store = $user->store ?: new \App\Models\Store(['user_id' => $user->id, 'is_active' => true]);
            $store->fill($storeFields);

            if ($request->hasFile('store_photo')) {
                $store->store_photo_url = $request->file('store_photo')->store('store-photos', 'public');
            }

            $store->save();
        }

        return response()->json(['status' => 'success', 'data' => $user->fresh()->load('store')]);
    }
}
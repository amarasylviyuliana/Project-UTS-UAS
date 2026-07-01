<?php

namespace App\Http\Controllers\Admin;

use App\Models\Admin;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;

class AdminController extends Controller
{
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
     * FIX: cukup cek role, tidak perlu record di tabel admins
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
            'total_stores'   => \App\Models\Store::count(),
            'total_orders'   => \App\Models\Order::count(),
            'total_revenue'  => (float) \App\Models\Order::where('status', 'Selesai')->sum('total_price'),
            'pending_store_approvals'   => \App\Models\StoreApproval::where('status', 'Menunggu Persetujuan')->count(),
            'pending_product_approvals' => \App\Models\ProductApproval::where('status', 'Menunggu Persetujuan')->count(),
            'pending_verifications'     => \App\Models\SellerVerification::where('status', 'Menunggu Verifikasi')->count(),
            'total_verified_sellers'    => \App\Models\SellerVerification::where('status', 'Terverifikasi')->count(),
            'total_approved_stores'     => \App\Models\StoreApproval::where('status', 'Disetujui')->count(),
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
     * FIX: eager-load store + storeApproval supaya data toko penjual
     * (nama toko, status persetujuan) ikut muncul di tab Pengguna admin.
     * Sebelumnya endpoint ini cuma return field user biasa, jadi FE
     * tidak pernah punya data toko untuk ditampilkan.
     */
    public function getAllUsers(Request $request)
    {
        $query = \App\Models\User::with(['store.storeApproval']);

        if ($request->role) {
            $query->where('role', $request->role);
        }

        $users = $query->orderBy('created_at', 'desc')
            ->paginate(15)
            ->through(function ($user) {
                return [
                    'id'         => $user->id,
                    'name'       => $user->name,
                    'email'      => $user->email,
                    'role'       => $user->role,
                    'phone'      => $user->phone,
                    'created_at' => $user->created_at,
                    // FIX: data toko penjual, null kalau user belum punya toko
                    'store' => $user->store ? [
                        'id'             => $user->store->id,
                        'store_name'     => $user->store->store_name,
                        'is_active'      => $user->store->is_active,
                        'store_approval' => $user->store->storeApproval ? [
                            'status'          => $user->store->storeApproval->status,
                            'rejected_reason' => $user->store->storeApproval->rejected_reason,
                        ] : null,
                    ] : null,
                ];
            });

        return response()->json([
            'status' => 'success',
            'data'   => $users,
        ]);
    }

    /**
     * Get all stores (admin)
     */
    public function getAllStores(Request $request)
    {
        $stores = \App\Models\Store::with(['user', 'storeApproval'])
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
                    'approval_status' => $store->storeApproval?->status,
                    'owner_name'      => $store->user?->name,
                    'user' => $store->user ? [
                        'id'    => $store->user->id,
                        'name'  => $store->user->name,
                        'email' => $store->user->email,
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
     */
    public function getAllProducts(Request $request)
    {
        $products = \App\Models\Product::with(['store', 'category', 'productApproval'])
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
        $user->delete();
        return response()->json(['status' => 'success', 'message' => 'User berhasil dihapus']);
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

            // Sync store_approval status juga
            if ($store->storeApproval) {
                $store->storeApproval->update([
                    'status' => $request->is_active ? 'Disetujui' : 'Ditolak',
                    'approved_at' => $request->is_active ? now() : null,
                ]);
            }
        }

        return response()->json([
            'status'  => 'success',
            'message' => 'Status toko berhasil diperbarui',
            'data'    => $store->fresh()->load('storeApproval'),
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
        $store->delete();
        return response()->json(['status' => 'success', 'message' => 'Toko berhasil dihapus']);
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
        $product->delete();
        return response()->json(['status' => 'success', 'message' => 'Produk berhasil dihapus']);
    }

    /**
     * Update order status (admin)
     */
    public function updateOrderStatus(Request $request, $id)
    {
        $order = \App\Models\Order::find($id);
        if (!$order) {
            return response()->json(['status' => 'error', 'message' => 'Pesanan tidak ditemukan'], 404);
        }
        $request->validate(['status' => 'required|string']);
        $order->update(['status' => $request->status]);
        return response()->json(['status' => 'success', 'message' => 'Status pesanan diperbarui']);
    }

    /**
     * Create user (admin)
     */
    public function createUser(Request $request)
    {
        $request->validate([
            'name'  => 'required|string',
            'email' => 'required|email|unique:users',
            'role'  => 'required|string',
        ]);

        $user = \App\Models\User::create([
            'name'     => $request->name,
            'email'    => $request->email,
            'role'     => $request->role,
            'password' => bcrypt('password123'),
        ]);

        return response()->json(['status' => 'success', 'data' => $user], 201);
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
        $user->update($request->only(['name', 'email', 'role']));
        return response()->json(['status' => 'success', 'data' => $user]);
    }
}
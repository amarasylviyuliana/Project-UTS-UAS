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
            // Check if user has correct role
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

        // Filter by admin
        if ($request->admin_id) {
            $query->where('admin_id', $request->admin_id);
        }

        // Filter by action
        if ($request->action) {
            $query->where('action', $request->action);
        }

        // Filter by model type
        if ($request->model_type) {
            $query->where('model_type', $request->model_type);
        }

        // Filter by date range
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
        $admin = auth()->user()->admin;

        if (!$admin) {
            return response()->json([
                'status' => 'error',
                'message' => 'Anda bukan admin'
            ], 403);
        }

        $stats = [
            'pending_store_approvals' => \App\Models\StoreApproval::where('status', 'Menunggu Persetujuan')->count(),
            'pending_product_approvals' => \App\Models\ProductApproval::where('status', 'Menunggu Persetujuan')->count(),
            'pending_verifications' => \App\Models\SellerVerification::where('status', 'Menunggu Verifikasi')->count(),
            'total_verified_sellers' => \App\Models\SellerVerification::where('status', 'Terverifikasi')->count(),
            'total_approved_stores' => \App\Models\StoreApproval::where('status', 'Disetujui')->count(),
            'total_approved_products' => \App\Models\ProductApproval::where('status', 'Disetujui')->count(),
            'admin_actions_today' => AuditLog::where('admin_id', $admin->id)
                ->whereDate('created_at', today())
                ->count(),
        ];

        return response()->json([
            'status' => 'success',
            'data' => $stats
        ]);
    }
}

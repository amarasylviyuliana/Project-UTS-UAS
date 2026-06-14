<?php

namespace App\Http\Controllers\Admin;

use App\Models\Admin;
use App\Models\Store;
use App\Models\StoreApproval;
use App\Models\ProductApproval;
use App\Models\Product;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;

class ApprovalController extends Controller
{
    /**
     * Get all pending store approvals
     */
    public function getPendingStoreApprovals()
    {
        $pending = StoreApproval::where('status', 'Menunggu Persetujuan')
            ->with(['store.user', 'admin'])
            ->orderBy('created_at', 'asc')
            ->paginate(15);

        return response()->json([
            'status' => 'success',
            'data' => $pending
        ]);
    }

    /**
     * Get store approval detail
     */
    public function getStoreApprovalDetail($id)
    {
        $approval = StoreApproval::with(['store.user', 'admin'])->find($id);

        if (!$approval) {
            return response()->json([
                'status' => 'error',
                'message' => 'Persetujuan toko tidak ditemukan'
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'data' => $approval
        ]);
    }

    /**
     * Approve or reject store
     */
    public function approveStore(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:Disetujui,Ditolak,Perlu Revisi',
            'rejected_reason' => 'required_if:status,Ditolak|nullable|string',
            'notes' => 'nullable|string',
        ]);

        $approval = StoreApproval::find($id);

        if (!$approval) {
            return response()->json([
                'status' => 'error',
                'message' => 'Persetujuan toko tidak ditemukan'
            ], 404);
        }

        // Check authorization
        $admin = auth()->user()->admin;
        if (!$admin) {
            return response()->json([
                'status' => 'error',
                'message' => 'Anda bukan admin'
            ], 403);
        }

        try {
            DB::beginTransaction();

            $oldValues = $approval->toArray();

            // Update approval status
            $approval->update([
                'status' => $request->status,
                'admin_id' => $admin->id,
                'rejected_reason' => $request->rejected_reason,
                'notes' => $request->notes,
                'approved_at' => $request->status === 'Disetujui' ? now() : null,
            ]);

            // Update store is_active status if approved
            if ($request->status === 'Disetujui') {
                $approval->store->update(['is_active' => true]);
            } elseif ($request->status === 'Ditolak') {
                $approval->store->update(['is_active' => false]);
            }

            // Log audit
            $this->logAuditTrail($admin, 'approve_store', 'StoreApproval', $approval->id, $oldValues, $approval);

            DB::commit();

            return response()->json([
                'status' => 'success',
                'message' => 'Persetujuan toko berhasil diupdate',
                'data' => $approval->fresh()->load(['store.user', 'admin'])
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal mengupdate persetujuan: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get all pending product approvals
     */
    public function getPendingProductApprovals()
    {
        $pending = ProductApproval::where('status', 'Menunggu Persetujuan')
            ->with(['product.store', 'admin'])
            ->orderBy('created_at', 'asc')
            ->paginate(15);

        return response()->json([
            'status' => 'success',
            'data' => $pending
        ]);
    }

    /**
     * Get product approval detail
     */
    public function getProductApprovalDetail($id)
    {
        $approval = ProductApproval::with(['product.store', 'admin'])->find($id);

        if (!$approval) {
            return response()->json([
                'status' => 'error',
                'message' => 'Persetujuan produk tidak ditemukan'
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'data' => $approval
        ]);
    }

    /**
     * Approve or reject product
     */
    public function approveProduct(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:Disetujui,Ditolak',
            'rejected_reason' => 'required_if:status,Ditolak|nullable|string',
            'notes' => 'nullable|string',
        ]);

        $approval = ProductApproval::find($id);

        if (!$approval) {
            return response()->json([
                'status' => 'error',
                'message' => 'Persetujuan produk tidak ditemukan'
            ], 404);
        }

        // Check authorization
        $admin = auth()->user()->admin;
        if (!$admin) {
            return response()->json([
                'status' => 'error',
                'message' => 'Anda bukan admin'
            ], 403);
        }

        try {
            DB::beginTransaction();

            $oldValues = $approval->toArray();

            // Update approval status
            $approval->update([
                'status' => $request->status,
                'admin_id' => $admin->id,
                'rejected_reason' => $request->rejected_reason,
                'notes' => $request->notes,
                'approved_at' => $request->status === 'Disetujui' ? now() : null,
            ]);

            // Update product is_active status if approved
            if ($request->status === 'Disetujui') {
                $approval->product->update(['is_active' => true]);
            } elseif ($request->status === 'Ditolak') {
                $approval->product->update(['is_active' => false]);
            }

            // Log audit
            $this->logAuditTrail($admin, 'approve_product', 'ProductApproval', $approval->id, $oldValues, $approval);

            DB::commit();

            return response()->json([
                'status' => 'success',
                'message' => 'Persetujuan produk berhasil diupdate',
                'data' => $approval->fresh()->load(['product.store', 'admin'])
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal mengupdate persetujuan: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get approval statistics
     */
    public function getApprovalStats()
    {
        $storeStats = [
            'pending' => StoreApproval::where('status', 'Menunggu Persetujuan')->count(),
            'approved' => StoreApproval::where('status', 'Disetujui')->count(),
            'rejected' => StoreApproval::where('status', 'Ditolak')->count(),
            'revision_needed' => StoreApproval::where('status', 'Perlu Revisi')->count(),
        ];

        $productStats = [
            'pending' => ProductApproval::where('status', 'Menunggu Persetujuan')->count(),
            'approved' => ProductApproval::where('status', 'Disetujui')->count(),
            'rejected' => ProductApproval::where('status', 'Ditolak')->count(),
        ];

        return response()->json([
            'status' => 'success',
            'data' => [
                'store_approvals' => $storeStats,
                'product_approvals' => $productStats,
            ]
        ]);
    }

    /**
     * Log audit trail
     */
    private function logAuditTrail($admin, $action, $modelType, $modelId, $oldValues, $newValues)
    {
        \App\Models\AuditLog::create([
            'admin_id' => $admin->id,
            'action' => $action,
            'model_type' => $modelType,
            'model_id' => $modelId,
            'old_values' => $oldValues,
            'new_values' => $newValues->toArray(),
            'ip_address' => request()->ip(),
            'user_agent' => request()->header('User-Agent'),
        ]);
    }
}

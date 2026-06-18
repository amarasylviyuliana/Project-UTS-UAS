<?php

namespace App\Http\Controllers\Admin;

use App\Models\Admin;
use App\Models\Store;
use App\Models\StoreApproval;
use App\Models\SellerVerification;
use App\Models\User;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;

class VerificationController extends Controller
{
    /**
     * Get all pending seller verifications
     */
    public function getPendingVerifications()
    {
        $pending = SellerVerification::where('status', 'Menunggu Verifikasi')
            ->with(['user', 'store', 'verifiedBy'])
            ->orderBy('created_at', 'asc')
            ->paginate(15);

        return response()->json([
            'status' => 'success',
            'data' => $pending
        ]);
    }

    /**
     * Get verification details
     */
    public function getVerificationDetail($id)
    {
        $verification = SellerVerification::with(['user', 'store', 'verifiedBy'])->find($id);

        if (!$verification) {
            return response()->json([
                'status' => 'error',
                'message' => 'Verifikasi tidak ditemukan'
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'data' => $verification
        ]);
    }

    /**
     * Verify seller identity
     */
    public function verifySeller(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:Terverifikasi,Ditolak,Direvisi',
            'rejection_reason' => 'required_if:status,Ditolak|nullable|string',
            'notes' => 'nullable|string',
        ]);

        $verification = SellerVerification::find($id);

        if (!$verification) {
            return response()->json([
                'status' => 'error',
                'message' => 'Verifikasi tidak ditemukan'
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

            // Update verification status
            $verification->update([
                'status' => $request->status,
                'verified_by' => $admin->id,
                'verification_date' => now(),
                'rejection_reason' => $request->rejection_reason,
                'notes' => $request->notes,
            ]);

            // Log audit
            $this->logAuditTrail($admin, 'verify_seller', 'SellerVerification', $verification->id, $verification);

            DB::commit();

            return response()->json([
                'status' => 'success',
                'message' => 'Verifikasi penjual berhasil diupdate',
                'data' => $verification->fresh()->load(['user', 'store'])
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal mengupdate verifikasi: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get verification history for a seller
     */
    public function getSellerVerificationHistory($userId)
    {
        $history = SellerVerification::where('user_id', $userId)
            ->with(['verifiedBy', 'store'])
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $history
        ]);
    }

    /**
     * Log audit trail
     */
    private function logAuditTrail($admin, $action, $modelType, $modelId, $data)
    {
        \App\Models\AuditLog::create([
            'admin_id' => $admin->id,
            'action' => $action,
            'model_type' => $modelType,
            'model_id' => $modelId,
            'new_values' => $data->toArray(),
            'ip_address' => request()->ip(),
            'user_agent' => request()->header('User-Agent'),
        ]);
    }
}

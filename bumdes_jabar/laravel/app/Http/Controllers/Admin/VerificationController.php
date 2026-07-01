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
     * FIX BUG: tidak pakai auth()->user()->admin karena akan error
     * jika user tidak punya record di tabel admins.
     * Sekarang cukup cek role di tabel users.
     */
    public function verifySeller(Request $request, $id)
    {
        $request->validate([
            'status'           => 'required|in:Terverifikasi,Ditolak,Direvisi',
            'rejection_reason' => 'required_if:status,Ditolak|nullable|string',
            'notes'            => 'nullable|string',
        ]);

        // FIX: cek role langsung dari user, tidak perlu tabel admins
        if (auth()->user()->role !== 'Admin') {
            return response()->json([
                'status'  => 'error',
                'message' => 'Anda bukan admin'
            ], 403);
        }

        $verification = SellerVerification::find($id);

        if (!$verification) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Verifikasi tidak ditemukan'
            ], 404);
        }

        try {
            DB::beginTransaction();

            $verification->update([
                'status'            => $request->status,
                'verified_by'       => auth()->id(), // FIX: pakai user_id langsung
                'verification_date' => now(),
                'rejection_reason'  => $request->rejection_reason,
                'notes'             => $request->notes,
            ]);

            // Audit log tetap dipertahankan, pakai auth()->id()
            $this->logAuditTrail(auth()->user(), 'verify_seller', 'SellerVerification', $verification->id, $verification);

            DB::commit();

            return response()->json([
                'status'  => 'success',
                'message' => 'Verifikasi penjual berhasil diupdate',
                'data'    => $verification->fresh()->load(['user', 'store'])
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'status'  => 'error',
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
            'data'   => $history
        ]);
    }

    /**
     * Log audit trail
     * FIX: parameter pertama sekarang $user (objek User), bukan $admin
     */
    private function logAuditTrail($user, $action, $modelType, $modelId, $data)
    {
        \App\Models\AuditLog::create([
            'admin_id'   => $user->id,
            'action'     => $action,
            'model_type' => $modelType,
            'model_id'   => $modelId,
            'new_values' => $data->toArray(),
            'ip_address' => request()->ip(),
            'user_agent' => request()->header('User-Agent'),
        ]);
    }
}
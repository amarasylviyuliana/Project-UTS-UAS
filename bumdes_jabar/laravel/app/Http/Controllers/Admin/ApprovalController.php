<?php

namespace App\Http\Controllers\Admin;

use App\Models\ProductApproval;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;

/**
 * CATATAN PERUBAHAN ALUR BISNIS:
 * Approval Toko (StoreApproval) sudah dihapus total dari sistem karena
 * akun Penjual + Toko/BUMDes sekarang dibuat langsung oleh Admin lewat
 * menu Pengguna dan otomatis aktif (lihat AdminController@createUser).
 * Controller ini sekarang hanya menangani Product Approval.
 */
class ApprovalController extends Controller
{
    public function getPendingProductApprovals()
    {
        $pending = ProductApproval::where('status', 'Menunggu Persetujuan')
            ->with(['product.store'])
            ->orderBy('created_at', 'asc')
            ->paginate(15);
        return response()->json(['status' => 'success', 'data' => $pending]);
    }

    public function getProductApprovalDetail($id)
    {
        $approval = ProductApproval::with(['product.store'])->find($id);
        if (!$approval) {
            return response()->json(['status' => 'error', 'message' => 'Tidak ditemukan'], 404);
        }
        return response()->json(['status' => 'success', 'data' => $approval]);
    }

    public function approveProduct(Request $request, $id)
    {
        $request->validate([
            'status'          => 'required|in:Disetujui,Ditolak',
            'rejected_reason' => 'required_if:status,Ditolak|nullable|string',
        ]);

        if (auth()->user()->role !== 'Admin') {
            return response()->json(['status' => 'error', 'message' => 'Bukan admin'], 403);
        }

        $approval = ProductApproval::find($id);
        if (!$approval) {
            return response()->json(['status' => 'error', 'message' => 'Tidak ditemukan'], 404);
        }

        try {
            DB::beginTransaction();
            $approval->update([
                'status'          => $request->status,
                'rejected_reason' => $request->rejected_reason,
                'approved_at'     => $request->status === 'Disetujui' ? now() : null,
            ]);
            if ($approval->product_id) {
                \App\Models\Product::where('id', $approval->product_id)->update([
                    'is_active' => $request->status === 'Disetujui',
                ]);
            }
            DB::commit();
            return response()->json(['status' => 'success', 'message' => 'Berhasil diupdate']);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['status' => 'error', 'message' => 'Gagal: ' . $e->getMessage()], 500);
        }
    }

    public function getApprovalStats()
    {
        return response()->json(['status' => 'success', 'data' => [
            'product_approvals' => [
                'pending'  => ProductApproval::where('status', 'Menunggu Persetujuan')->count(),
                'approved' => ProductApproval::where('status', 'Disetujui')->count(),
                'rejected' => ProductApproval::where('status', 'Ditolak')->count(),
            ],
        ]]);
    }
}

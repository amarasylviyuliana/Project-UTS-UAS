<?php

namespace App\Http\Controllers\Admin;

use App\Models\Store;
use App\Models\StoreApproval;
use App\Models\ProductApproval;
use App\Models\Admin;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;

class ApprovalController extends Controller
{
    public function getPendingStoreApprovals()
    {
        // FIX: Load store.user dan semua field store yang dibutuhkan frontend
        $approvals = StoreApproval::with(['store.user'])
            ->orderBy('created_at', 'desc')
            ->paginate(100);

        // FIX: Kalau store_id ada tapi relasi store null (orphan), coba ambil manual
        // Ini terjadi kalau toko didaftarkan sebelum sistem approval atau ada bug store_id
        $items = $approvals->map(function ($approval) {
            $data = $approval->toArray();

            // Kalau store sudah ada dan punya store_name, langsung return
            if (!empty($data['store']['store_name'])) {
                return $data;
            }

            // Coba cari store via store_id jika relasi kosong
            if ($approval->store_id) {
                $store = \App\Models\Store::with('user')->find($approval->store_id);
                if ($store) {
                    $data['store'] = array_merge($store->toArray(), [
                        'user' => $store->user?->toArray(),
                    ]);
                }
            }

            return $data;
        });

        return response()->json([
            'status' => 'success',
            'data'   => [
                'data'  => $items,
                'total' => $approvals->total(),
            ],
        ]);
    }

    public function getStoreApprovalDetail($id)
    {
        $approval = StoreApproval::with(['store.user'])->find($id);
        if (!$approval) {
            return response()->json(['status' => 'error', 'message' => 'Tidak ditemukan'], 404);
        }
        return response()->json(['status' => 'success', 'data' => $approval]);
    }

    public function approveStore(Request $request, $id)
    {
        $request->validate([
            'status'          => 'required|in:Disetujui,Ditolak,Perlu Revisi',
            'rejected_reason' => 'required_if:status,Ditolak|nullable|string',
            'notes'           => 'nullable|string',
        ]);

        if (auth()->user()->role !== 'Admin') {
            return response()->json(['status' => 'error', 'message' => 'Bukan admin'], 403);
        }

        $approval = StoreApproval::with('store')->find($id);
        if (!$approval) {
            return response()->json(['status' => 'error', 'message' => 'Tidak ditemukan'], 404);
        }

        try {
            DB::beginTransaction();

            // FIX: sebelumnya admin_id dipaksa null. Sekarang dicoba isi
            // dengan record Admin milik user yang sedang login (kalau ada).
            // Tetap aman walau tidak ketemu, karena admin_id sudah nullable.
            $adminId = Admin::where('user_id', auth()->id())->value('id');

            $approval->update([
                'status'          => $request->status,
                'admin_id'        => $adminId,
                'rejected_reason' => $request->rejected_reason,
                'notes'           => $request->notes,
                'approved_at'     => $request->status === 'Disetujui' ? now() : null,
            ]);

            if ($approval->store_id) {
                Store::where('id', $approval->store_id)->update([
                    'is_active' => $request->status === 'Disetujui',
                ]);
            }

            DB::commit();

            return response()->json([
                'status'  => 'success',
                'message' => 'Persetujuan toko berhasil diupdate',
                'data'    => $approval->fresh()->load('store.user'),
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'status'  => 'error',
                'message' => 'Gagal: ' . $e->getMessage(),
            ], 500);
        }
    }

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
            'store_approvals' => [
                'pending'  => StoreApproval::where('status', 'Menunggu Persetujuan')->count(),
                'approved' => StoreApproval::where('status', 'Disetujui')->count(),
                'rejected' => StoreApproval::where('status', 'Ditolak')->count(),
            ],
            'product_approvals' => [
                'pending'  => ProductApproval::where('status', 'Menunggu Persetujuan')->count(),
                'approved' => ProductApproval::where('status', 'Disetujui')->count(),
                'rejected' => ProductApproval::where('status', 'Ditolak')->count(),
            ],
        ]]);
    }
}

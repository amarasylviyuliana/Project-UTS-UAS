<?php

namespace App\Http\Controllers;

use App\Models\StoreWallet;
use App\Models\WalletTransaction;
use App\Models\Withdrawal;
use App\Services\WalletService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class WalletController extends Controller
{
    public function __construct(private WalletService $walletService)
    {
    }

    private function storeOrFail(Request $request)
    {
        $store = $request->user()->store;
        abort_if(!$store, 404, 'Anda belum memiliki toko.');
        return $store;
    }

    /** Saldo saat ini milik Penjual yang sedang login. */
    public function balance(Request $request): JsonResponse
    {
        $store = $this->storeOrFail($request);

        return response()->json([
            'status' => 'success',
            'data' => [
                'balance' => $this->walletService->getBalance($store->id),
            ],
        ]);
    }

    /** Riwayat mutasi saldo (pemasukan penjualan & penarikan). */
    public function transactions(Request $request): JsonResponse
    {
        $store = $this->storeOrFail($request);

        $transactions = WalletTransaction::where('store_id', $store->id)
            ->orderByDesc('created_at')
            ->paginate($request->query('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => $transactions,
        ]);
    }

    /** Riwayat penarikan saldo milik toko ini. */
    public function withdrawals(Request $request): JsonResponse
    {
        $store = $this->storeOrFail($request);

        $withdrawals = Withdrawal::where('store_id', $store->id)
            ->orderByDesc('created_at')
            ->paginate($request->query('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => $withdrawals,
        ]);
    }

    /** Ajukan penarikan saldo — langsung diproses (auto-approve). */
    public function requestWithdrawal(Request $request): JsonResponse
    {
        $store = $this->storeOrFail($request);

        $validated = $request->validate([
            'amount' => 'required|numeric|min:1',
            'bank_name' => 'required|string|max:100',
            'bank_account_number' => 'required|string|max:50',
            'bank_account_name' => 'required|string|max:150',
        ]);

        try {
            $withdrawal = $this->walletService->requestWithdrawal(
                $store,
                (float) $validated['amount'],
                $validated,
            );
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json([
            'message' => 'Penarikan saldo berhasil diproses',
            'data' => $withdrawal,
        ]);
    }
}
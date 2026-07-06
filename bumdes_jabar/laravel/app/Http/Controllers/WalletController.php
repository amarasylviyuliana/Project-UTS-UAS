<?php

namespace App\Http\Controllers;

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

    /** Ambil store milik user yang sedang login, atau null kalau bukan penjual / belum punya toko. */
    private function getAuthenticatedStore(Request $request)
    {
        $user = $request->user();

        if (!$user->isSeller()) {
            return null;
        }

        return $user->store;
    }

    /** Saldo toko milik Penjual yang sedang login. */
    public function balance(Request $request): JsonResponse
    {
        $store = $this->getAuthenticatedStore($request);

        if (!$store) {
            return response()->json(['message' => 'Anda tidak memiliki toko'], 403);
        }

        return response()->json([
            'status' => 'success',
            'data' => [
                'balance' => $this->walletService->getBalance($store->id),
            ],
        ]);
    }

    /** Riwayat mutasi saldo (transaksi) milik toko Penjual yang sedang login. */
    public function transactions(Request $request): JsonResponse
    {
        $store = $this->getAuthenticatedStore($request);

        if (!$store) {
            return response()->json(['message' => 'Anda tidak memiliki toko'], 403);
        }

        $transactions = WalletTransaction::where('store_id', $store->id)
            ->orderByDesc('created_at')
            ->paginate($request->query('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => $transactions,
        ]);
    }

    /** Riwayat penarikan saldo milik toko Penjual yang sedang login. */
    public function withdrawals(Request $request): JsonResponse
    {
        $store = $this->getAuthenticatedStore($request);

        if (!$store) {
            return response()->json(['message' => 'Anda tidak memiliki toko'], 403);
        }

        $withdrawals = Withdrawal::where('store_id', $store->id)
            ->orderByDesc('created_at')
            ->paginate($request->query('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => $withdrawals,
        ]);
    }

    /** Ajukan penarikan saldo toko Penjual yang sedang login. */
    public function requestWithdrawal(Request $request): JsonResponse
    {
        $store = $this->getAuthenticatedStore($request);

        if (!$store) {
            return response()->json(['message' => 'Anda tidak memiliki toko'], 403);
        }

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
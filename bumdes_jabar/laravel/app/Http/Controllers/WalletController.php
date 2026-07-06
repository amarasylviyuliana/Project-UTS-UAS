<?php

namespace App\Http\Controllers;

use App\Services\WalletService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class WalletController extends Controller
{
    public function __construct(private WalletService $walletService)
    {
    }

    /** Saldo toko milik Penjual yang sedang login. */
    public function balance(Request $request): JsonResponse
    {
        $store = $request->user()->store;

        if (!$store) {
            return response()->json([
                'message' => 'Anda belum memiliki toko',
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'data' => [
                'balance' => $this->walletService->getBalance($store->id),
            ],
        ]);
    }

    /** Riwayat mutasi saldo (pemasukan & penarikan) toko Penjual yang sedang login. */
    public function transactions(Request $request): JsonResponse
    {
        $store = $request->user()->store;

        if (!$store) {
            return response()->json([
                'message' => 'Anda belum memiliki toko',
            ], 404);
        }

        $transactions = \App\Models\WalletTransaction::where('store_id', $store->id)
            ->orderByDesc('created_at')
            ->paginate($request->query('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => $transactions,
        ]);
    }

    /** Riwayat penarikan saldo toko Penjual yang sedang login. */
    public function withdrawals(Request $request): JsonResponse
    {
        $store = $request->user()->store;

        if (!$store) {
            return response()->json([
                'message' => 'Anda belum memiliki toko',
            ], 404);
        }

        $withdrawals = \App\Models\Withdrawal::where('store_id', $store->id)
            ->orderByDesc('created_at')
            ->paginate($request->query('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => $withdrawals,
        ]);
    }

    /** Ajukan penarikan saldo (Penjual). */
    public function requestWithdrawal(Request $request): JsonResponse
    {
        $store = $request->user()->store;

        if (!$store) {
            return response()->json([
                'message' => 'Anda belum memiliki toko',
            ], 404);
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
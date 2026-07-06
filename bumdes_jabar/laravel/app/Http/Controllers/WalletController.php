<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
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

    /** Ringkasan pemasukan Admin dari biaya admin/pajak seluruh transaksi. */
    public function summary(): JsonResponse
    {
        return response()->json([
            'status' => 'success',
            'data' => [
                // Total pemasukan pajak sepanjang waktu (statistik, tidak berkurang saat ditarik).
                'platform_income' => $this->walletService->getPlatformIncome(),
                // Saldo yang benar-benar bisa ditarik saat ini (income - sudah ditarik).
                'platform_balance' => $this->walletService->getPlatformBalance(),
                'tax_percentage' => (float) config('platform.tax_percentage', 5),
            ],
        ]);
    }

    /** Ajukan penarikan saldo Admin/platform (dari kumpulan biaya admin/pajak). */
    public function requestWithdrawal(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'amount' => 'required|numeric|min:1',
            'bank_name' => 'required|string|max:100',
            'bank_account_number' => 'required|string|max:50',
            'bank_account_name' => 'required|string|max:150',
        ]);

        try {
            $withdrawal = $this->walletService->requestPlatformWithdrawal(
                (float) $validated['amount'],
                $validated,
            );
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json([
            'message' => 'Penarikan saldo platform berhasil diproses',
            'data' => $withdrawal,
        ]);
    }

    /** Seluruh mutasi saldo pajak (pemasukan Admin) atau semua toko sekaligus. */
    public function transactions(Request $request): JsonResponse
    {
        $query = WalletTransaction::with('store')->orderByDesc('created_at');

        if ($request->query('scope') === 'platform') {
            $query->whereNull('store_id')->where('category', 'tax');
        } elseif ($request->store_id) {
            $query->where('store_id', $request->store_id);
        }

        $transactions = $query->paginate($request->query('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => $transactions,
        ]);
    }

    /** Seluruh penarikan saldo dari semua Penjual. */
    public function withdrawals(Request $request): JsonResponse
    {
        $withdrawals = Withdrawal::with('store')
            ->orderByDesc('created_at')
            ->paginate($request->query('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => $withdrawals,
        ]);
    }

    /** Saldo seluruh toko (untuk tabel "Saldo" di dashboard Admin). */
    public function storeWallets(Request $request): JsonResponse
    {
        $wallets = StoreWallet::with('store')
            ->orderByDesc('balance')
            ->paginate($request->query('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => $wallets,
        ]);
    }
}
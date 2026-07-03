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
                'platform_income' => $this->walletService->getPlatformIncome(),
                'tax_percentage' => (float) config('platform.tax_percentage', 5),
            ],
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
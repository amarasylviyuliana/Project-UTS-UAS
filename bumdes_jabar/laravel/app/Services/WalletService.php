<?php

namespace App\Services;

use App\Models\Order;
use App\Models\Store;
use App\Models\StoreWallet;
use App\Models\WalletTransaction;
use App\Models\Withdrawal;
use Illuminate\Support\Facades\DB;

class WalletService
{
    /**
     * Dipanggil saat sebuah order berubah status jadi "Selesai".
     * Memotong biaya admin (pajak) dari total transaksi, sisanya
     * masuk ke saldo Penjual, dan bagian pajaknya dicatat sebagai
     * pemasukan Admin/platform.
     *
     * Aman dipanggil berkali-kali untuk order yang sama (idempotent) —
     * tidak akan mengkredit dua kali.
     */
    public function creditFromCompletedOrder(Order $order): void
    {
        $alreadyCredited = WalletTransaction::where('order_id', $order->id)
            ->where('category', 'sale')
            ->exists();

        if ($alreadyCredited) {
            return;
        }

        $taxPercentage = (float) config('platform.tax_percentage', 5);
        $total = (float) $order->total_price;
        $tax = round($total * $taxPercentage / 100, 2);
        $net = round($total - $tax, 2);

        DB::transaction(function () use ($order, $net, $tax) {
            $wallet = StoreWallet::firstOrCreate(
                ['store_id' => $order->store_id],
                ['balance' => 0],
            );
            $wallet->increment('balance', $net);

            WalletTransaction::create([
                'store_id' => $order->store_id,
                'type' => 'credit',
                'category' => 'sale',
                'amount' => $net,
                'order_id' => $order->id,
                'description' => "Pendapatan pesanan #{$order->order_number} (setelah potongan biaya admin)",
            ]);

            // store_id null = masuk sebagai pemasukan Admin/platform
            WalletTransaction::create([
                'store_id' => null,
                'type' => 'credit',
                'category' => 'tax',
                'amount' => $tax,
                'order_id' => $order->id,
                'description' => "Biaya admin dari pesanan #{$order->order_number} (toko: {$order->store?->store_name})",
            ]);
        });
    }

    /**
     * Ajukan penarikan saldo. Auto-processed: langsung dipotong dari
     * saldo dan berstatus "Selesai" (tidak perlu approval Admin).
     *
     * @throws \InvalidArgumentException kalau nominal tidak valid / saldo kurang
     */
    public function requestWithdrawal(Store $store, float $amount, array $bankDetails): Withdrawal
    {
        if ($amount <= 0) {
            throw new \InvalidArgumentException('Nominal penarikan tidak valid.');
        }

        return DB::transaction(function () use ($store, $amount, $bankDetails) {
            $wallet = StoreWallet::lockForUpdate()->firstOrCreate(
                ['store_id' => $store->id],
                ['balance' => 0],
            );

            if ($amount > (float) $wallet->balance) {
                throw new \InvalidArgumentException('Saldo tidak mencukupi untuk penarikan ini.');
            }

            $wallet->decrement('balance', $amount);

            $withdrawal = Withdrawal::create([
                'store_id' => $store->id,
                'amount' => $amount,
                'bank_name' => $bankDetails['bank_name'],
                'bank_account_number' => $bankDetails['bank_account_number'],
                'bank_account_name' => $bankDetails['bank_account_name'],
                'status' => 'Selesai',
            ]);

            WalletTransaction::create([
                'store_id' => $store->id,
                'type' => 'debit',
                'category' => 'withdrawal',
                'amount' => $amount,
                'withdrawal_id' => $withdrawal->id,
                'description' => "Penarikan saldo ke {$bankDetails['bank_name']} a.n. {$bankDetails['bank_account_name']}",
            ]);

            return $withdrawal;
        });
    }

    public function getBalance(int $storeId): float
    {
        return (float) (StoreWallet::where('store_id', $storeId)->value('balance') ?? 0);
    }

    /** Total pemasukan Admin/platform dari seluruh pajak (untuk dashboard Admin). */
    public function getPlatformIncome(): float
    {
        return (float) WalletTransaction::whereNull('store_id')
            ->where('category', 'tax')
            ->sum('amount');
    }
}
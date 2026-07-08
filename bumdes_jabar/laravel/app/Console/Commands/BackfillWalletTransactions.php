<?php

namespace App\Console\Commands;

use App\Models\Order;
use App\Services\WalletService;
use Illuminate\Console\Command;

class BackfillWalletTransactions extends Command
{
    /**
     * php artisan wallet:backfill
     *
     * Dipakai SEKALI SAJA setelah bug "Class not found" pada model
     * StoreWallet/WalletTransaction/Withdrawal diperbaiki. Sebelum perbaikan,
     * setiap order yang berubah status jadi "Selesai" GAGAL dikreditkan ke
     * wallet (exception dari class yang hilang), padahal order-nya sendiri
     * tetap tersimpan normal di database dan muncul di Laporan Keuangan.
     *
     * Command ini menyisir ulang seluruh order berstatus "Selesai" dan
     * mengkreditkan yang belum pernah tercatat di wallet_transactions.
     * Aman dijalankan berkali-kali (idempotent) karena
     * WalletService::creditFromCompletedOrder() sendiri sudah mengecek
     * duplikasi berdasarkan order_id.
     */
    protected $signature = 'wallet:backfill';

    protected $description = 'Kreditkan ulang saldo untuk order Selesai yang belum tercatat di wallet (perbaikan bug lama)';

    public function handle(WalletService $walletService): int
    {
        $orders = Order::where('status', 'Selesai')->get();

        $this->info("Ditemukan {$orders->count()} order berstatus Selesai. Memproses...");

        $credited = 0;
        $skipped = 0;

        foreach ($orders as $order) {
            $alreadyCredited = \App\Models\WalletTransaction::where('order_id', $order->id)
                ->where('category', 'sale')
                ->exists();

            if ($alreadyCredited) {
                $skipped++;
                continue;
            }

            $walletService->creditFromCompletedOrder($order);
            $credited++;
            $this->line("  - Order #{$order->order_number} (ID {$order->id}) dikreditkan.");
        }

        $this->info("Selesai. Dikreditkan: {$credited}. Dilewati (sudah pernah): {$skipped}.");

        return self::SUCCESS;
    }
}
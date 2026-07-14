<?php

namespace App\Console\Commands;

use App\Models\Product;
use App\Services\AlgoliaService;
use Illuminate\Console\Command;

/**
 * php artisan algolia:reindex
 *
 * Jalankan sekali di awal (setelah isi ALGOLIA_APP_ID/ALGOLIA_ADMIN_API_KEY
 * di .env), atau kapan pun perlu "menyamakan" ulang seluruh data produk
 * dengan index Algolia. Untuk operasional sehari-hari, sinkronisasi
 * per-produk sudah otomatis lewat model event di Product::booted().
 */
class AlgoliaReindexCommand extends Command
{
    protected $signature = 'algolia:reindex';

    protected $description = 'Konfigurasi settings index Algolia lalu kirim ulang semua produk (untuk fitur pencarian AI)';

    public function handle(AlgoliaService $algolia): int
    {
        if (!$algolia->isConfigured()) {
            $this->error('Algolia belum dikonfigurasi. Isi ALGOLIA_APP_ID dan ALGOLIA_ADMIN_API_KEY di .env terlebih dahulu.');
            return self::FAILURE;
        }

        $this->info('Mengirim konfigurasi index (searchable attributes, facets, ranking)...');
        if (!$algolia->pushSettings()) {
            $this->error('Gagal mengirim settings ke Algolia. Cek log untuk detail.');
            return self::FAILURE;
        }
        $this->info('Settings index berhasil diperbarui.');

        $totalProducts = Product::count();
        if ($totalProducts === 0) {
            $this->warn('Tidak ada produk di database, tidak ada yang di-index.');
            return self::SUCCESS;
        }

        $this->info("Meng-index {$totalProducts} produk ke Algolia...");
        $bar = $this->output->createProgressBar($totalProducts);

        $indexed = 0;
        Product::with(['category', 'store'])->chunk(200, function ($products) use ($algolia, $bar, &$indexed) {
            $indexed += $algolia->saveProducts($products);
            $bar->advance($products->count());
        });

        $bar->finish();
        $this->newLine(2);
        $this->info("Selesai. {$indexed} produk berhasil dikirim ke index '" . config('services.algolia.products_index') . "'.");

        return self::SUCCESS;
    }
}

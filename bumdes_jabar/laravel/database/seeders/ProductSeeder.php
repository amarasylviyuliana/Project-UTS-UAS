<?php

namespace Database\Seeders;

use App\Models\Product;
use App\Models\Store;
use Illuminate\Database\Seeder;

class ProductSeeder extends Seeder
{
    public function run(): void
    {
        $stores = Store::all();

        if ($stores->isEmpty()) {
            $this->command->error('[ProductSeeder] Tabel stores kosong. ProductSeeder DIBATALKAN. Pastikan StoreSeeder berjalan sukses sebelum ini (cek urutan di DatabaseSeeder.php).');
            return;
        }

        $products = [
            ['store_name' => 'BUMDes Garut', 'category_id' => 3, 'name' => 'Kerupuk Kulit dari BUMDes Garut', 'type' => 'produk', 'price' => 25000, 'stock' => 15, 'description' => 'Kerupuk kulit khas Garut dengan cita rasa gurih, renyah, dan siap dipasarkan.', 'photo_url' => 'https://picsum.photos/seed/kerupuk/400/300', 'tags' => ['gurih', 'renyah', 'khas garut']],
            ['store_name' => 'BUMDes Ciwidey', 'category_id' => 1, 'name' => 'Sayuran Segar dari BUMDes Ciwidey', 'type' => 'produk', 'price' => 18000, 'stock' => 25, 'description' => 'Sayuran segar hasil panen lokal dari BUMDes Ciwidey untuk kebutuhan harian.', 'photo_url' => 'https://picsum.photos/seed/sayur/400/300', 'tags' => ['segar', 'organik']],
            ['store_name' => 'BUMDes Pangalengan', 'category_id' => 3, 'name' => 'Sus Lezat dari BUMDes Pangalengan', 'type' => 'produk', 'price' => 30000, 'stock' => 12, 'description' => 'Sus lembut dan nikmat khas Pangalengan, cocok untuk camilan keluarga.', 'photo_url' => 'https://picsum.photos/seed/sus/400/300', 'tags' => ['manis', 'lembut']],
            // Contoh kasus utama fitur Algolia AI Search: kata "pedas" SENGAJA
            // tidak ditulis di judul maupun deskripsi. Produk ini hanya bisa
            // ditemukan lewat query "pedas" karena atributnya ada di kolom
            // `tags`, yang didaftarkan sebagai searchable attribute di Algolia.
            ['store_name' => 'BUMDes Garut', 'category_id' => 3, 'name' => 'Sambal Oncom Bakar Cibiuk', 'type' => 'produk', 'price' => 22000, 'stock' => 20, 'description' => 'Sambal khas Cibiuk, Garut, dibuat dari oncom bakar dan racikan bumbu tradisional turun-temurun.', 'photo_url' => 'https://picsum.photos/seed/sambal/400/300', 'tags' => ['pedas', 'khas garut', 'tradisional']],
        ];

        $createdCount = 0;

        foreach ($products as $productData) {
            $store = $stores->firstWhere('store_name', $productData['store_name']);
            if (! $store) {
                $this->command->warn("[ProductSeeder] Store '{$productData['store_name']}' tidak ditemukan. Produk '{$productData['name']}' DILEWATI.");
                continue;
            }

            Product::updateOrCreate(
                ['name' => $productData['name'], 'store_id' => $store->id],
                [
                    'store_id' => $store->id,
                    'category_id' => $productData['category_id'],
                    'name' => $productData['name'],
                    'type' => $productData['type'],
                    'price' => $productData['price'],
                    'stock' => $productData['stock'],
                    'description' => $productData['description'],
                    'photo_url' => $productData['photo_url'],
                    'is_active' => true,
                    'tags' => $productData['tags'] ?? [],
                ]
            );

            $createdCount++;
        }

        if ($createdCount === 0) {
            $this->command->error('[ProductSeeder] Tidak ada satupun produk yang dibuat.');
        } else {
            $this->command->info("[ProductSeeder] {$createdCount} produk berhasil dibuat/diupdate.");
        }
    }
}
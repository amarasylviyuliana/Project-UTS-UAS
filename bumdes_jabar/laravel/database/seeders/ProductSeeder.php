<?php

namespace Database\Seeders;

use App\Models\Product;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class ProductSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $products = [
            [
                'store_id' => 1,
                'category_id' => 3, // Kuliner Desa
                'name' => 'Kerupuk Kulit Garut',
                'type' => 'produk',
                'price' => 25000,
                'stock' => 15,
                'description' => 'Kerupuk kulit khas Garut dengan cita rasa gurih dan renyah.',
                'photo_url' => 'https://picsum.photos/seed/kerupuk/400/300',
                'is_active' => true,
            ],
            [
                'store_id' => 1,
                'category_id' => 4, // Jasa Lokal
                'name' => 'Sewa Alat Pertanian',
                'type' => 'jasa',
                'price' => 80000,
                'stock' => 0,
                'description' => 'Layanan penyewaan cangkul dan sprayer untuk musim panen.',
                'photo_url' => 'https://picsum.photos/seed/alat/400/300',
                'is_active' => true,
            ],
            [
                'store_id' => 1,
                'category_id' => 2, // Kerajinan Tangan
                'name' => 'Anyaman Bambu',
                'type' => 'produk',
                'price' => 75000,
                'stock' => 10,
                'description' => 'Kerajinan bambu khas desa, cocok untuk dekorasi dan hadiah.',
                'photo_url' => 'https://picsum.photos/seed/bambu/400/300',
                'is_active' => true,
            ],
            [
                'store_id' => 1,
                'category_id' => 6, // Pariwisata
                'name' => 'Paket Wisata Desa',
                'type' => 'jasa',
                'price' => 150000,
                'stock' => 99,
                'description' => 'Wisata edukasi ke desa, pertanian, dan kerajinan lokal.',
                'photo_url' => 'https://picsum.photos/seed/wisata/400/300',
                'is_active' => true,
            ],
            [
                'store_id' => 1,
                'category_id' => 1, // Pertanian & Perkebunan
                'name' => 'Beras Organik Premium',
                'type' => 'produk',
                'price' => 55000,
                'stock' => 50,
                'description' => 'Beras organik premium hasil panen langsung dari petani lokal desa.',
                'photo_url' => 'https://picsum.photos/seed/beras/400/300',
                'is_active' => true,
            ],
            [
                'store_id' => 1,
                'category_id' => 5, // Peternakan
                'name' => 'Telur Ayam Kampung',
                'type' => 'produk',
                'price' => 32000,
                'stock' => 100,
                'description' => 'Telur ayam kampung segar langsung dari peternakan lokal.',
                'photo_url' => 'https://picsum.photos/seed/telur/400/300',
                'is_active' => true,
            ],
        ];

        foreach ($products as $product) {
            Product::firstOrCreate(
                ['name' => $product['name'], 'store_id' => $product['store_id']],
                $product
            );
        }
    }
}

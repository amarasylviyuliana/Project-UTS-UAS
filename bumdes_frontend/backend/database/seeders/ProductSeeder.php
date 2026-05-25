<?php

namespace Database\Seeders;

use App\Models\Product;
use Illuminate\Database\Seeder;

class ProductSeeder extends Seeder
{
    public function run(): void
    {
        $products = [
            [
                'name' => 'Kerupuk Kulit Garut',
                'price' => 25000,
                'stock' => 15,
                'image_url' => 'https://picsum.photos/seed/kerupuk/400/300',
                'description' => 'Kerupuk kulit khas Garut dengan cita rasa gurih dan renyah.',
            ],
            [
                'name' => 'Sewa Alat Pertanian',
                'price' => 80000,
                'stock' => 10,
                'image_url' => 'https://picsum.photos/seed/alat/400/300',
                'description' => 'Layanan penyewaan cangkul dan sprayer untuk musim panen.',
            ],
            [
                'name' => 'Anyaman Bambu',
                'price' => 75000,
                'stock' => 10,
                'image_url' => 'https://picsum.photos/seed/bambu/400/300',
                'description' => 'Kerajinan bambu khas desa, cocok untuk dekorasi dan hadiah.',
            ],
            [
                'name' => 'Paket Wisata Desa',
                'price' => 150000,
                'stock' => 99,
                'image_url' => 'https://picsum.photos/seed/wisata/400/300',
                'description' => 'Wisata edukasi ke desa, pertanian, dan kerajinan lokal.',
            ],
        ];

        foreach ($products as $product) {
            Product::create($product);
        }
    }
}

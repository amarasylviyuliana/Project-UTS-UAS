<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class CategorySeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $categories = [
            [
                'name' => 'Pertanian & Perkebunan',
                'description' => 'Produk hasil pertanian dan perkebunan lokal',
            ],
            [
                'name' => 'Kerajinan Tangan',
                'description' => 'Produk kerajinan tangan tradisional dan modern',
            ],
            [
                'name' => 'Kuliner Desa',
                'description' => 'Produk makanan dan minuman khas desa',
            ],
            [
                'name' => 'Jasa Lokal',
                'description' => 'Jasa-jasa yang ditawarkan oleh BUMDes setempat',
            ],
            [
                'name' => 'Peternakan',
                'description' => 'Produk hasil peternakan dan ternak hidup',
            ],
            [
                'name' => 'Pariwisata',
                'description' => 'Paket wisata dan layanan pariwisata lokal',
            ],
        ];

        foreach ($categories as $category) {
            Category::firstOrCreate(
                ['name' => $category['name']],
                ['description' => $category['description']]
            );
        }
    }
}

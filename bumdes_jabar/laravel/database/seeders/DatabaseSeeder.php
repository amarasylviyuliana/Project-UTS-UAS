<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // FIX: ResetDemoDataSeeder SENGAJA tidak dipanggil otomatis di sini.
        // Seeder itu men-TRUNCATE users, orders, stores, products, dkk —
        // kalau ikut jalan tiap deploy, SELURUH DATA PRODUCTION akan
        // terhapus setiap kali ada push baru.
        //
        // Seeder di bawah aman dijalankan berulang kali (idempotent).
        //
        // Kalau memang butuh reset total data demo secara SENGAJA, jalankan
        // manual: php artisan db:seed --class=ResetDemoDataSeeder
        $this->call([
            CategorySeeder::class,
            \Database\Seeders\UserSeeder::class,
            \Database\Seeders\StoreSeeder::class,
            ProductSeeder::class,
        ]);
    }
}
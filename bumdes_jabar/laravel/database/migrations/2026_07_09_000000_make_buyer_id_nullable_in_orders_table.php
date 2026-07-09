<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * PENTING: migration ini WAJIB dijalankan sebelum fitur "hapus Pembeli"
 * yang baru dipakai.
 *
 * AdminController@deleteUser sekarang men-set `buyer_id` pesanan lama
 * menjadi NULL (bukan menghapus baris pesanannya) sebelum menghapus akun
 * Pembeli yang semua pesanannya sudah final (Selesai/Dibatalkan/Ditolak).
 * Supaya itu bisa berjalan, kolom `buyer_id` di tabel `orders` harus
 * nullable. Kalau sebelumnya kolom itu NOT NULL, migration ini akan
 * mengubahnya jadi nullable.
 *
 * Jalankan dengan: php artisan migrate
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->foreignId('buyer_id')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->foreignId('buyer_id')->nullable(false)->change();
        });
    }
};
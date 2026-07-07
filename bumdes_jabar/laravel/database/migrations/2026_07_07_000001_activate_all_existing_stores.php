<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * PERUBAHAN ALUR BISNIS PENJUAL:
 * Karena alur pendaftaran & approval toko dihapus (toko sekarang selalu
 * aktif sejak dibuat oleh Admin), semua data toko LAMA yang sebelumnya ada
 * (baik sudah disetujui, masih menunggu, atau ditolak) diaktifkan otomatis
 * di sini supaya tidak ada toko yang "hilang" / tidak bisa dipakai setelah
 * fitur approval dihapus pada migration berikutnya.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('stores')) {
            DB::table('stores')->update(['is_active' => true]);
        }
    }

    public function down(): void
    {
        // Sengaja tidak dikembalikan (tidak ada cara mengetahui status lama
        // per toko setelah tabel approval dihapus).
    }
};

<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

/**
 * PERUBAHAN ALUR BISNIS PENJUAL:
 * Alur pendaftaran & approval toko, serta verifikasi identitas penjual,
 * sudah tidak digunakan lagi karena akun Penjual + Toko/BUMDes sekarang
 * dibuat langsung oleh Admin dan otomatis aktif. Jalankan migration
 * 2026_07_07_000001_activate_all_existing_stores terlebih dahulu supaya
 * data toko lama tetap aktif sebelum tabel ini dihapus.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('seller_verifications');
        Schema::dropIfExists('store_approvals');
    }

    public function down(): void
    {
        Schema::create('store_approvals', function ($table) {
            $table->id();
            $table->foreignId('store_id')->unique()->constrained()->onDelete('cascade');
            $table->foreignId('admin_id')->constrained()->onDelete('restrict');
            $table->enum('status', ['Menunggu Persetujuan', 'Disetujui', 'Ditolak', 'Perlu Revisi'])->default('Menunggu Persetujuan');
            $table->text('notes')->nullable();
            $table->text('rejected_reason')->nullable();
            $table->timestamp('approved_at')->nullable();
            $table->timestamps();
        });

        Schema::create('seller_verifications', function ($table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->foreignId('store_id')->constrained()->onDelete('cascade');
            $table->enum('status', ['Menunggu Verifikasi', 'Terverifikasi', 'Ditolak', 'Direvisi'])->default('Menunggu Verifikasi');
            $table->foreignId('verified_by')->nullable()->constrained('admins')->onDelete('set null');
            $table->timestamp('verification_date')->nullable();
            $table->text('rejection_reason')->nullable();
            $table->string('document_url')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }
};

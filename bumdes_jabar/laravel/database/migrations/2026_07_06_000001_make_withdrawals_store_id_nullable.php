<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * store_id NULL pada tabel withdrawals = penarikan saldo Admin/platform
     * (dari kumpulan biaya admin/pajak), bukan penarikan milik toko tertentu.
     *
     * Pakai raw SQL (bukan ->change()) supaya tidak perlu dependency
     * doctrine/dbal yang tidak ter-install di project ini.
     */
    public function up(): void
    {
        Schema::table('withdrawals', function ($table) {
            $table->dropForeign(['store_id']);
        });

        DB::statement('ALTER TABLE withdrawals MODIFY store_id BIGINT UNSIGNED NULL');

        Schema::table('withdrawals', function ($table) {
            $table->foreign('store_id')->references('id')->on('stores')->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::table('withdrawals', function ($table) {
            $table->dropForeign(['store_id']);
        });

        DB::statement('ALTER TABLE withdrawals MODIFY store_id BIGINT UNSIGNED NOT NULL');

        Schema::table('withdrawals', function ($table) {
            $table->foreign('store_id')->references('id')->on('stores')->onDelete('cascade');
        });
    }
};
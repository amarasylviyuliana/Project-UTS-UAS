<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Kolom 'tags' menyimpan atribut produk yang TIDAK selalu tertulis di
     * nama/judul produk, misalnya ["pedas", "gurih", "khas garut"] untuk
     * sebuah sambal yang judulnya cuma "Sambal Oncom Bakar Cibiuk".
     *
     * Kolom ini yang membuat Algolia AI Search bisa menemukan produk lewat
     * atribut rasa/karakteristik, bukan cuma exact match ke judul —
     * karena 'tags' didaftarkan sebagai searchable attribute + facet di
     * index Algolia (lihat AlgoliaReindexCommand).
     */
    public function up(): void
    {
        if (! Schema::hasColumn('products', 'tags')) {
            Schema::table('products', function (Blueprint $table) {
                $table->json('tags')->nullable()->after('description');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('products', 'tags')) {
            Schema::table('products', function (Blueprint $table) {
                $table->dropColumn('tags');
            });
        }
    }
};
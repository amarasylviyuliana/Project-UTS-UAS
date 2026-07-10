<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Fitur Peta Pelacakan Kurir (Real-time simulated tracking)
 *
 * Kita TIDAK menyimpan lokasi kurir yang di-update manual terus-menerus
 * (butuh app kurir terpisah / GPS live yang mahal & kompleks). Sebagai
 * gantinya, posisi kurir "saat ini" dihitung otomatis di backend dengan
 * interpolasi antara titik asal (toko) dan titik tujuan (alamat pembeli)
 * berdasarkan waktu yang sudah berlalu sejak status 'Dikirim' dibanding
 * estimasi durasi pengiriman. Jadi marker di peta akan terlihat bergerak
 * setiap kali frontend refresh, tanpa perlu input manual.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->decimal('origin_lat', 10, 7)->nullable()->after('delivery_address');
            $table->decimal('origin_lng', 10, 7)->nullable()->after('origin_lat');
            $table->decimal('dest_lat', 10, 7)->nullable()->after('origin_lng');
            $table->decimal('dest_lng', 10, 7)->nullable()->after('dest_lat');
            // Estimasi total durasi perjalanan (menit) dipakai untuk simulasi
            // pergerakan kurir. Default 180 menit (3 jam) supaya progres
            // masih enak dilihat bergerak saat demo/testing, tapi tetap
            // realistis untuk pengiriman lokal antar desa.
            $table->unsignedInteger('estimated_delivery_minutes')->default(180)->after('dest_lng');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn([
                'origin_lat',
                'origin_lng',
                'dest_lat',
                'dest_lng',
                'estimated_delivery_minutes',
            ]);
        });
    }
};
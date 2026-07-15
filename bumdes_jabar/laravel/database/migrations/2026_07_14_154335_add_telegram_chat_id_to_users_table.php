<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // FIX: cek dulu kolomnya sudah ada atau belum sebelum nambah.
        // Sebelumnya migration ini langsung ALTER TABLE tanpa cek, jadi kalau
        // kolom `telegram_chat_id` sudah pernah ditambahkan manual/dari
        // percobaan deploy sebelumnya, migration ini SELALU gagal dengan
        // error "Duplicate column name" setiap kali `php artisan migrate`
        // dijalankan (baik lokal maupun di server/Railway) -> itu yang
        // sebelumnya bikin proses start server gagal total.
        if (! Schema::hasColumn('users', 'telegram_chat_id')) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('telegram_chat_id')->nullable()->after('email');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasColumn('users', 'telegram_chat_id')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('telegram_chat_id');
            });
        }
    }
};
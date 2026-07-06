<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("ALTER TABLE payments MODIFY status ENUM('Pending','Confirmed','Rejected','Cancelled') DEFAULT 'Pending'");
    }

    public function down(): void
    {
        DB::statement("ALTER TABLE payments MODIFY status ENUM('Pending','Confirmed','Rejected') DEFAULT 'Pending'");
    }
};
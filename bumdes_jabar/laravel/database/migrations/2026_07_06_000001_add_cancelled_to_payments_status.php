<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // MySQL: modify enum to include 'Cancelled'
        DB::statement("ALTER TABLE `payments` MODIFY `status` ENUM('Pending','Confirmed','Rejected','Cancelled') NOT NULL DEFAULT 'Pending'");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // revert to previous enum (without 'Cancelled')
        DB::statement("ALTER TABLE `payments` MODIFY `status` ENUM('Pending','Confirmed','Rejected') NOT NULL DEFAULT 'Pending'");
    }
};

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
        Schema::create('admins', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->onDelete('cascade');
            $table->string('department')->nullable(); // Divisi/Departemen
            $table->string('job_title')->nullable(); // Jabatan
            $table->string('phone_internal')->nullable(); // Nomor internal
            $table->boolean('is_super_admin')->default(false); // Super admin flag
            $table->json('permissions')->nullable(); // Custom permissions as JSON
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('admins');
    }
};

<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wallet_transactions', function (Blueprint $table) {
            $table->id();
            // store_id NULL = ini pemasukan Admin/platform (dari potongan pajak)
            $table->foreignId('store_id')->nullable()->constrained()->onDelete('cascade');
            $table->enum('type', ['credit', 'debit']);
            $table->enum('category', ['sale', 'tax', 'withdrawal']);
            $table->decimal('amount', 15, 2);
            $table->foreignId('order_id')->nullable()->constrained()->onDelete('set null');
            $table->foreignId('withdrawal_id')->nullable()->constrained('withdrawals')->onDelete('set null');
            $table->string('description')->nullable();
            $table->timestamps();

            $table->index(['store_id', 'created_at']);
            $table->index(['category', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallet_transactions');
    }
};
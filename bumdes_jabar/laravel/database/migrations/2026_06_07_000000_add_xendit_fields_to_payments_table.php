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
        Schema::table('payments', function (Blueprint $table) {
            $table->string('invoice_id')->nullable()->unique()->after('order_id');
            $table->text('invoice_url')->nullable()->after('invoice_id');
            $table->string('payment_method')->nullable()->after('invoice_url');
            $table->string('payment_status')->default('Pending')->after('status');
            $table->timestamp('paid_at')->nullable()->after('payment_status');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->dropColumn(['invoice_id', 'invoice_url', 'payment_method', 'payment_status', 'paid_at']);
        });
    }
};

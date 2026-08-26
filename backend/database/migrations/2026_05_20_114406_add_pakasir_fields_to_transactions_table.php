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
        Schema::table('transactions', function (Blueprint $table) {
            $table->string('provider_name', 50)->nullable()->after('provider_reference');
            $table->text('payment_number')->nullable()->after('provider_name');
            $table->decimal('fee', 12, 2)->nullable()->after('payment_number');
            $table->decimal('total_payment', 12, 2)->nullable()->after('fee');
            $table->timestamp('expired_at')->nullable()->after('total_payment');
            $table->json('provider_payload')->nullable()->after('expired_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->dropColumn([
                'provider_name',
                'payment_number',
                'fee',
                'total_payment',
                'expired_at',
                'provider_payload',
            ]);
        });
    }
};

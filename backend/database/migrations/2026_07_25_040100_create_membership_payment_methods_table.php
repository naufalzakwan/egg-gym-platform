<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('membership_payment_methods', function (Blueprint $table) {
            $table->id();
            $table->string('provider', 30)->default('pakasir');
            $table->string('provider_code', 50);
            $table->string('display_name', 100);
            $table->string('description', 180)->nullable();
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('display_order')->default(0);
            $table->timestamps();
            $table->unique(['provider', 'provider_code']);
            $table->index(['provider', 'is_active', 'display_order'], 'membership_payment_method_active_order');
        });

        $methods = [
            ['qris', 'QRIS', 'Pembayaran QRIS', 10],
            ['bni_va', 'VA BNI', 'Virtual Account BNI', 20],
            ['bri_va', 'VA BRI', 'Virtual Account BRI', 30],
            ['permata_va', 'VA Permata', 'Virtual Account Permata', 40],
            ['cimb_niaga_va', 'VA CIMB Niaga', 'Virtual Account CIMB Niaga', 50],
            ['atm_bersama_va', 'VA ATM Bersama', 'Virtual Account ATM Bersama', 60],
            ['maybank_va', 'VA Maybank', 'Virtual Account Maybank', 70],
            ['sampoerna_va', 'VA Bank Sampoerna', 'Virtual Account Bank Sampoerna', 80],
            ['bnc_va', 'VA Bank Neo Commerce', 'Virtual Account Bank Neo Commerce', 90],
            ['artha_graha_va', 'VA Bank Artha Graha', 'Virtual Account Bank Artha Graha', 100],
        ];

        DB::table('membership_payment_methods')->insert(array_map(fn (array $method) => [
            'provider' => 'pakasir',
            'provider_code' => $method[0],
            'display_name' => $method[1],
            'description' => $method[2],
            'is_active' => in_array($method[0], ['qris', 'bni_va', 'bri_va'], true),
            'display_order' => $method[3],
            'created_at' => now(),
            'updated_at' => now(),
        ], $methods));
    }

    public function down(): void
    {
        Schema::dropIfExists('membership_payment_methods');
    }
};

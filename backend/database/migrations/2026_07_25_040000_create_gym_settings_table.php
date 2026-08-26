<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('gym_settings', function (Blueprint $table) {
            $table->id();
            $table->string('gym_name', 150);
            $table->string('brand_name', 100);
            $table->string('tagline', 180)->nullable();
            $table->text('address')->nullable();
            $table->string('city', 100)->nullable();
            $table->string('province', 100)->nullable();
            $table->string('postal_code', 12)->nullable();
            $table->string('maps_url', 2048)->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('phone', 30)->nullable();
            $table->string('whatsapp', 30)->nullable();
            $table->string('email')->nullable();
            $table->string('instagram', 100)->nullable();
            $table->string('logo_path')->nullable();
            $table->unsignedBigInteger('logo_version')->default(1);
            $table->timestamps();
        });

        DB::table('gym_settings')->insert([
            'id' => 1,
            'gym_name' => 'Egg Gym',
            'brand_name' => 'EGGGYM',
            'tagline' => 'Your Gym, Smarter',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('gym_settings');
    }
};

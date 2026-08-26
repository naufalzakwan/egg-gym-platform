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
        Schema::create('bookings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('member_profile_id')->constrained('member_profiles')->cascadeOnDelete();
            $table->foreignId('trainer_profile_id')->constrained('trainer_profiles')->cascadeOnDelete();
            $table->string('session_title');
            $table->date('session_date');
            $table->time('start_time');
            $table->time('end_time');
            $table->string('location');
            $table->string('status', 30)->default('pending');
            $table->text('member_note')->nullable();
            $table->text('trainer_note')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('bookings');
    }
};

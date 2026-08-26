<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('trainer_ratings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('member_profile_id')->constrained('member_profiles')->cascadeOnDelete();
            $table->foreignId('trainer_profile_id')->constrained('trainer_profiles')->cascadeOnDelete();
            $table->foreignId('booking_id')->nullable()->constrained('bookings')->nullOnDelete();
            $table->unsignedTinyInteger('rating');
            $table->text('testimonial')->nullable();
            $table->timestamps();

            $table->unique(['member_profile_id', 'trainer_profile_id', 'booking_id'], 'tr_member_trainer_booking_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trainer_ratings');
    }
};

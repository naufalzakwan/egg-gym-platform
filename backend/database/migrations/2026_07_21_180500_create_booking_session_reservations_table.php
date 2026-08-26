<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('booking_session_reservations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('booking_id')->constrained('bookings')->cascadeOnDelete();
            $table->unsignedInteger('sequence_order');
            $table->foreignId('trainer_profile_id')->constrained('trainer_profiles')->cascadeOnDelete();
            $table->foreignId('member_profile_id')->constrained('member_profiles')->cascadeOnDelete();
            $table->foreignId('trainer_schedule_date_id')
                ->constrained('trainer_schedule_dates')
                ->restrictOnDelete();
            $table->date('session_date');
            $table->time('start_time');
            $table->time('end_time');
            $table->unsignedSmallInteger('session_duration_minutes');
            $table->string('status', 30)->default('reserved');
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('released_at')->nullable();
            $table->string('release_reason', 500)->nullable();
            $table->timestamps();

            $table->unique(['booking_id', 'sequence_order'], 'booking_reservation_sequence_unique');
            $table->index(
                ['trainer_profile_id', 'session_date', 'status', 'start_time', 'end_time'],
                'booking_reservation_collision_idx'
            );
            $table->index(['booking_id', 'status'], 'booking_reservation_status_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('booking_session_reservations');
    }
};

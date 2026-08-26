<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('booking_reschedule_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('booking_id')->constrained('bookings')->cascadeOnDelete();
            $table->foreignId('booking_session_reservation_id');
            $table->foreign('booking_session_reservation_id', 'reschedule_reservation_fk')
                ->references('id')->on('booking_session_reservations')->cascadeOnDelete();
            $table->foreignId('active_reservation_id')->nullable()->unique();
            $table->foreign('active_reservation_id', 'reschedule_active_reservation_fk')
                ->references('id')->on('booking_session_reservations')->nullOnDelete();
            $table->foreignId('trainer_profile_id')->constrained('trainer_profiles')->cascadeOnDelete();
            $table->foreignId('requested_by_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('requested_by_role', 20);
            $table->foreignId('original_trainer_schedule_date_id');
            $table->foreign('original_trainer_schedule_date_id', 'reschedule_original_date_fk')
                ->references('id')->on('trainer_schedule_dates')->restrictOnDelete();
            $table->date('original_session_date');
            $table->time('original_start_time');
            $table->time('original_end_time');
            $table->foreignId('proposed_trainer_schedule_date_id');
            $table->foreign('proposed_trainer_schedule_date_id', 'reschedule_proposed_date_fk')
                ->references('id')->on('trainer_schedule_dates')->restrictOnDelete();
            $table->date('proposed_session_date');
            $table->time('proposed_start_time');
            $table->time('proposed_end_time');
            $table->unsignedSmallInteger('proposed_duration_minutes');
            $table->string('reason_type', 60);
            $table->text('reason_note')->nullable();
            $table->string('status', 20)->default('pending');
            $table->timestamp('expired_at');
            $table->foreignId('responded_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('responded_at')->nullable();
            $table->string('rejected_reason_type', 60)->nullable();
            $table->text('rejected_reason_note')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'expired_at'], 'reschedule_requests_expiry_idx');
            $table->index(
                ['trainer_profile_id', 'proposed_session_date', 'status', 'proposed_start_time', 'proposed_end_time'],
                'reschedule_requests_hold_idx'
            );
            $table->index(['booking_id', 'status'], 'reschedule_requests_booking_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('booking_reschedule_requests');
    }
};

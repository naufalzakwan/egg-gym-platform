<?php

use App\Models\Booking;
use App\Models\MemberProfile;
use App\Models\TrainingProgram;
use Illuminate\Database\Migrations\Migration;

return new class extends Migration
{
    /**
     * Backfill: tandai booking menjadi 'completed' untuk semua program yang
     * seluruh sesinya sudah selesai 100% — TANPA mensyaratkan member sudah
     * memberi rating. Ini merapikan data lama (mis. program yang selesai
     * sebelum fitur rating ada) agar tidak lagi terhitung sebagai kuota aktif.
     */
    public function up(): void
    {
        $programs = TrainingProgram::query()
            ->withCount([
                'sessions',
                'sessions as completed_sessions_count' => function ($query) {
                    $query->where('status', 'completed');
                },
            ])
            ->get();

        foreach ($programs as $program) {
            $programCompleted = $program->sessions_count > 0
                && $program->completed_sessions_count === $program->sessions_count;

            if (! $programCompleted) {
                continue;
            }

            Booking::query()
                ->where('member_profile_id', $program->member_profile_id)
                ->where('trainer_profile_id', $program->trainer_profile_id)
                ->whereIn('status', MemberProfile::ACTIVE_BOOKING_STATUSES)
                ->update(['status' => 'completed']);
        }
    }

    /**
     * Tidak dapat di-rollback secara akurat karena status asal booking
     * (payment_verified/confirmed) tidak disimpan. Sengaja dibiarkan no-op.
     */
    public function down(): void
    {
        // no-op
    }
};

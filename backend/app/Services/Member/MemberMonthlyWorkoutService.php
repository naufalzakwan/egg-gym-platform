<?php

namespace App\Services\Member;

use App\Models\SelfTrainingSession;
use App\Models\TrainingProgramSession;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;

class MemberMonthlyWorkoutService
{
    public function countForMember(int $memberProfileId, ?CarbonImmutable $now = null): int
    {
        $now ??= CarbonImmutable::now(config('app.timezone'));
        $start = $now->startOfMonth();
        $end = $start->addMonth();
        $startTimestamp = $start->toDateTimeString();
        $endTimestamp = $end->toDateTimeString();

        $ptSessions = TrainingProgramSession::query()
            ->where('status', 'completed')
            ->whereHas('trainingProgram', fn (Builder $query) => $query
                ->where('member_profile_id', $memberProfileId))
            ->whereHas('bookingSessionReservation', function (Builder $query) use ($start, $end) {
                $query->where(function (Builder $completion) use ($start, $end) {
                    $completion
                        ->where(function (Builder $actual) use ($start, $end) {
                            $actual->whereNotNull('completed_at')
                                ->where('completed_at', '>=', $start)
                                ->where('completed_at', '<', $end);
                        })
                        ->orWhere(function (Builder $fallback) use ($start, $end) {
                            $fallback->whereNull('completed_at')
                                ->whereDate('session_date', '>=', $start->toDateString())
                                ->whereDate('session_date', '<', $end->toDateString());
                        });
                });
            })
            ->count();

        $selfTrainingSessions = SelfTrainingSession::query()
            ->whereHas('program', fn (Builder $query) => $query
                ->where('member_profile_id', $memberProfileId))
            ->whereHas('exercises')
            ->whereDoesntHave('exercises', fn (Builder $query) => $query
                ->where('is_completed', false))
            ->whereHas('exercises', fn (Builder $query) => $query
                ->whereNotNull('completed_at'))
            ->whereRaw(
                '(SELECT MAX(ste.completed_at) FROM self_training_exercises ste '
                .'WHERE ste.self_training_session_id = self_training_sessions.id) >= ?',
                [$startTimestamp]
            )
            ->whereRaw(
                '(SELECT MAX(ste.completed_at) FROM self_training_exercises ste '
                .'WHERE ste.self_training_session_id = self_training_sessions.id) < ?',
                [$endTimestamp]
            )
            ->count();

        return $ptSessions + $selfTrainingSessions;
    }
}

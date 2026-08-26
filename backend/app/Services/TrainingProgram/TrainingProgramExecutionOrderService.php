<?php

namespace App\Services\TrainingProgram;

use App\Models\BookingSessionReservation;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class TrainingProgramExecutionOrderService
{
    public function reconcile(int $programId): ?TrainingProgramSession
    {
        return DB::transaction(function () use ($programId): ?TrainingProgramSession {
            $program = TrainingProgram::query()->lockForUpdate()->findOrFail($programId);
            if (in_array($program->status, ['archived', 'closed_early'], true)) {
                return null;
            }

            $sessions = TrainingProgramSession::query()
                ->with('bookingSessionReservation')
                ->where('training_program_id', $program->id)
                ->lockForUpdate()
                ->get();
            $current = $this->orderedCandidates($sessions)->first();

            foreach ($sessions as $session) {
                if (in_array($session->status, ['completed', 'cancelled'], true)) {
                    continue;
                }
                $nextStatus = $current?->id === $session->id ? 'active' : 'locked';
                if ($session->status === $nextStatus) {
                    continue;
                }
                $session->update([
                    'status' => $nextStatus,
                    'member_ready' => false,
                    'member_ready_at' => null,
                ]);
            }

            return $current?->refresh();
        }, 3);
    }

    public function current(int $programId): ?TrainingProgramSession
    {
        $sessions = TrainingProgramSession::query()
            ->with('bookingSessionReservation')
            ->where('training_program_id', $programId)
            ->get();

        return $this->orderedCandidates($sessions)->first();
    }

    private function orderedCandidates(Collection $sessions): Collection
    {
        return $sessions
            ->filter(function (TrainingProgramSession $session): bool {
                if (in_array($session->status, ['completed', 'cancelled'], true)) {
                    return false;
                }
                $reservation = $session->bookingSessionReservation;

                return $reservation === null
                    || $reservation->status === BookingSessionReservation::STATUS_RESERVED;
            })
            ->sortBy(function (TrainingProgramSession $session): string {
                $reservation = $session->bookingSessionReservation;
                if ($reservation) {
                    return implode('|', [
                        '0',
                        $reservation->session_date->toDateString(),
                        substr((string) $reservation->start_time, 0, 8),
                        substr((string) $reservation->end_time, 0, 8),
                        str_pad((string) $session->sequence_order, 10, '0', STR_PAD_LEFT),
                        str_pad((string) $session->id, 20, '0', STR_PAD_LEFT),
                    ]);
                }

                return implode('|', [
                    '1',
                    str_pad((string) $session->sequence_order, 10, '0', STR_PAD_LEFT),
                    str_pad((string) $session->id, 20, '0', STR_PAD_LEFT),
                ]);
            })
            ->values();
    }
}

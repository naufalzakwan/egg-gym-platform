<?php

namespace App\Http\Resources\Api\V1\Trainer;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TrainerClientDetailResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $bookings = $this->bookings ?? collect();
        $trainingPrograms = $this->trainingPrograms ?? collect();

        $nextSession = $bookings->first(function ($booking) {
            return $booking->session_date
                && $booking->session_date->greaterThanOrEqualTo(now()->startOfDay());
        });

        $activeProgram = $trainingPrograms->first(function ($program) {
            return in_array($program->status, ['active', 'draft'], true)
                && $program->sessions?->contains(fn ($session) => ! in_array(
                    $session->status,
                    ['completed', 'cancelled'],
                    true
                ));
        });

        $activeProgramSession = $activeProgram?->sessions?->first(function ($session) {
            return in_array($session->status, ['active', 'upcoming'], true);
        })
            ?? $activeProgram?->sessions?->firstWhere('status', 'locked')
            ?? $activeProgram?->sessions?->sortBy('sequence_order')?->first();

        // Hitung progres program berbasis sesi yang benar-benar selesai
        // (status 'completed'), konsisten dengan Session Timeline / menu Program.
        $programSessions = $activeProgram?->sessions ?? collect();
        $programTotalSessions = $programSessions->count();
        $programCompletedSessions = $programSessions
            ->where('status', 'completed')
            ->count();
        $programProgressPercent = $programTotalSessions > 0
            ? (int) round($programCompletedSessions / $programTotalSessions * 100)
            : 0;

        $activeMembership = $this->memberships
            ?->filter(fn ($membership) => $membership->isCurrentlyActive())
            ?->sortByDesc(fn ($membership) => $membership->end_date?->timestamp ?? 0)
            ?->first();

        return [
            'id' => $this->id,
            'member_code' => $this->member_code,
            'name' => $this->user?->name,
            'email' => $this->user?->email,
            'phone' => $this->user?->phone,
            'avatar_url' => $this->user?->avatar_url,
            'status' => $this->user?->status,
            'goal' => $this->fitness_goal,
            'gender' => $this->gender,
            'birth_date' => $this->birth_date?->toDateString(),
            'height_cm' => $this->height_cm !== null ? (float) $this->height_cm : null,
            'weight_kg' => $this->weight_kg !== null ? (float) $this->weight_kg : null,
            'medical_note' => $this->medical_note,
            'joined_at' => $this->joined_at?->toIso8601String(),
            'summary' => [
                'total_sessions' => $bookings->count(),
                'confirmed_sessions' => $bookings->where('status', 'confirmed')->count(),
                'pending_sessions' => $bookings->where('status', 'pending')->count(),
                'rescheduled_sessions' => $bookings->where('status', 'rescheduled')->count(),
            ],
            'active_membership' => $activeMembership ? [
                'plan_name' => $activeMembership->membershipPlan?->name,
                'start_date' => $activeMembership->start_date?->toDateString(),
                'end_date' => $activeMembership->end_date?->toDateString(),
                'status' => $activeMembership->status,
                'payment_status' => $activeMembership->payment_status,
            ] : null,
            'next_session_label' => $this->buildNextSessionLabel($nextSession),
            'next_session' => $this->transformBooking($nextSession),
            'active_program' => $activeProgram ? [
                'id' => $activeProgram->id,
                'title' => $activeProgram->title,
                'status' => $activeProgram->status,
                'goal' => $activeProgram->goal,
                'total_sessions' => $programTotalSessions,
                'completed_sessions' => $programCompletedSessions,
                'progress_percent' => $programProgressPercent,
                'training_program_session_id' => $activeProgramSession?->id,
                'active_session' => $activeProgramSession ? [
                    'id' => $activeProgramSession->id,
                    'sequence_order' => $activeProgramSession->sequence_order,
                    'title' => $activeProgramSession->title,
                    'status' => $activeProgramSession->status,
                    'member_ready' => (bool) $activeProgramSession->member_ready,
                    'member_ready_at' => $activeProgramSession->member_ready_at?->toIso8601String(),
                ] : null,
            ] : null,
            'recent_sessions' => $bookings
                ->take(3)
                ->map(fn ($booking) => $this->transformBooking($booking))
                ->values(),
            'coach_notes' => [],
        ];
    }

    private function buildNextSessionLabel($booking): ?string
    {
        if (! $booking || ! $booking->session_date) {
            return null;
        }

        $dateLabel = $booking->session_date->locale('id')->translatedFormat('d F Y');
        $startTime = substr((string) $booking->start_time, 0, 5);
        $endTime = substr((string) $booking->end_time, 0, 5);

        return $dateLabel.' | '.$startTime.' - '.$endTime;
    }

    private function transformBooking($booking): ?array
    {
        if (! $booking) {
            return null;
        }

        return [
            'id' => $booking->id,
            'session_title' => $booking->session_title,
            'session_date' => $booking->session_date?->toDateString(),
            'start_time' => $booking->start_time,
            'end_time' => $booking->end_time,
            'location' => $booking->location,
            'status' => $booking->status,
            'member_note' => $booking->member_note,
            'trainer_note' => $booking->trainer_note,
        ];
    }
}

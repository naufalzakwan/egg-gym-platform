<?php

namespace App\Http\Resources\Api\V1\Trainer;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TrainerProgramSessionResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'training_program_id' => $this->training_program_id,
            'booking_session_reservation_id' => $this->booking_session_reservation_id,
            'reservation' => $this->whenLoaded('bookingSessionReservation', fn () => [
                'id' => $this->bookingSessionReservation?->id,
                'sequence_order' => $this->bookingSessionReservation?->sequence_order,
                'session_date' => $this->bookingSessionReservation?->session_date?->toDateString(),
                'start_time' => $this->bookingSessionReservation?->start_time,
                'end_time' => $this->bookingSessionReservation?->end_time,
                'status' => $this->bookingSessionReservation?->status,
                'has_pending_reschedule' => $this->bookingSessionReservation
                    ?->pendingRescheduleRequest?->status === 'pending'
                    && $this->bookingSessionReservation
                        ?->pendingRescheduleRequest?->expired_at?->isFuture(),
            ]),
            'sequence_order' => $this->sequence_order,
            'title' => $this->title,
            'focus' => $this->focus,
            'duration_minutes' => $this->duration_minutes,
            'status' => $this->status,
            'unlock_rule' => $this->unlock_rule,
            'coach_note' => $this->coach_note,
            'member_ready' => (bool) $this->member_ready,
            'member_ready_at' => $this->member_ready_at?->toIso8601String(),
            'exercises' => TrainerProgramSessionExerciseResource::collection(
                $this->whenLoaded('exercises')
            ),
        ];
    }
}

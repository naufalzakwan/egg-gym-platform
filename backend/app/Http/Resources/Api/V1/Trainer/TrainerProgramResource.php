<?php

namespace App\Http\Resources\Api\V1\Trainer;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TrainerProgramResource extends JsonResource
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
            'title' => $this->title,
            'description' => $this->description,
            'goal' => $this->goal,
            'status' => $this->status,
            'started_at' => $this->started_at?->toDateString(),
            'ended_at' => $this->ended_at?->toDateString(),
            'trainer' => [
                'id' => $this->trainerProfile?->id,
                'name' => $this->trainerProfile?->user?->name,
            ],
            'member' => [
                'id' => $this->memberProfile?->id,
                'name' => $this->memberProfile?->user?->name,
                'member_code' => $this->memberProfile?->member_code,
            ],
            'booking' => $this->booking ? [
                'id' => $this->booking->id,
                'session_title' => $this->booking->session_title,
                'session_date' => $this->booking->session_date?->toDateString(),
            ] : null,
            'sessions' => TrainerProgramSessionResource::collection(
                $this->whenLoaded('sessions')
            ),
            'summary' => $this->whenLoaded('sessions', function () {
                return [
                    'total_sessions' => $this->sessions->count(),
                    'total_duration_minutes' => $this->sessions->sum(
                        fn ($session) => (int) ($session->duration_minutes ?? 0)
                    ),
                ];
            }),
        ];
    }
}

<?php

namespace App\Http\Resources\Api\V1\Trainer;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TrainerClientResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $bookings = $this->bookings ?? collect();

        $upcomingBooking = $bookings->first(function ($booking) {
            return $booking->session_date
                && $booking->session_date->greaterThanOrEqualTo(now()->startOfDay());
        });

        $activeCount = $bookings
            ->whereIn('status', ['payment_verified', 'confirmed', 'rescheduled'])
            ->count();

        return [
            'id' => $this->id,
            'member_code' => $this->member_code,
            'name' => $this->user?->name,
            'avatar_url' => $this->user?->avatar_url,
            'goal' => $this->fitness_goal ?? 'General fitness',
            'height_cm' => $this->height_cm !== null ? (float) $this->height_cm : null,
            'weight_kg' => $this->weight_kg !== null ? (float) $this->weight_kg : null,
            'medical_note' => $this->medical_note,
            'progress_label' => $this->buildProgressLabel($activeCount, $bookings->count()),
            'next_session' => $this->buildNextSessionLabel($upcomingBooking),
            'next_session_status' => $upcomingBooking?->status,
            'next_session_title' => $upcomingBooking?->session_title,
            'total_sessions' => $bookings->count(),
        ];
    }

    private function buildProgressLabel(int $activeCount, int $totalCount): string
    {
        if ($activeCount > 0) {
            return $activeCount.' sesi aktif bersama trainer';
        }

        return $totalCount.' histori sesi bersama trainer';
    }

    private function buildNextSessionLabel($booking): string
    {
        if (! $booking || ! $booking->session_date) {
            return 'Belum ada sesi berikutnya';
        }

        $dateLabel = $booking->session_date->locale('id')->translatedFormat('d F Y');
        $startTime = substr((string) $booking->start_time, 0, 5);
        $endTime = substr((string) $booking->end_time, 0, 5);

        return $dateLabel.' | '.$startTime.' - '.$endTime;
    }
}

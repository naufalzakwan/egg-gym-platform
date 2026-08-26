<?php

namespace App\Http\Resources\Api\V1\Booking;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BookingRescheduleRequestResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $userId = $request->user()?->id;
        $isRequester = (int) $this->requested_by_user_id === (int) $userId;

        return [
            'id' => $this->id,
            'booking_id' => $this->booking_id,
            'reservation_id' => $this->booking_session_reservation_id,
            'sequence_order' => $this->reservation?->sequence_order,
            'requested_by_role' => $this->requested_by_role,
            'requested_by_name' => $this->requestedBy?->name,
            'status' => $this->status,
            'old_schedule' => [
                'date' => $this->original_session_date?->toDateString(),
                'start_time' => $this->original_start_time,
                'end_time' => $this->original_end_time,
            ],
            'proposed_schedule' => [
                'date' => $this->proposed_session_date?->toDateString(),
                'start_time' => $this->proposed_start_time,
                'end_time' => $this->proposed_end_time,
            ],
            'reason_type' => $this->reason_type,
            'reason_note' => $this->reason_note,
            'expired_at' => $this->expired_at?->toIso8601String(),
            'remaining_seconds' => $this->status === 'pending'
                ? max(0, (int) now()->diffInSeconds($this->expired_at, false)) : 0,
            'is_incoming' => ! $isRequester,
            'can_accept' => $this->status === 'pending' && ! $isRequester,
            'can_reject' => $this->status === 'pending' && ! $isRequester,
            'can_cancel' => $this->status === 'pending' && $isRequester,
            'rejection' => $this->rejected_reason_type ? [
                'reason_type' => $this->rejected_reason_type,
                'reason_note' => $this->rejected_reason_note,
            ] : null,
            'responded_at' => $this->responded_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}

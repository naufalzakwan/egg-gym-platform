<?php

namespace App\Http\Resources\Api\V1\Trainer;

use App\Http\Resources\Api\V1\Member\BookingResource;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TrainerBookingDetailResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $data = (new BookingResource($this->resource))->toArray($request);
        $activeMembership = $this->memberProfile?->memberships
            ?->filter(fn ($membership) => $membership->isCurrentlyActive())
            ->sortByDesc(fn ($membership) => $membership->end_date?->timestamp ?? 0)
            ->first();

        $data['booking_number'] = 'EGG-PT-'.str_pad((string) $this->id, 6, '0', STR_PAD_LEFT);
        $data['created_at'] = $this->created_at?->toIso8601String();
        $data['member'] = array_merge($data['member'] ?? [], [
            'email' => $this->memberProfile?->user?->email,
            'phone' => $this->memberProfile?->user?->phone,
            'member_code' => $this->memberProfile?->member_code,
            'avatar_url' => $this->memberProfile?->user?->avatar_url,
        ]);
        $data['active_membership'] = $activeMembership ? [
            'plan_name' => $activeMembership->membershipPlan?->name,
            'plan_slug' => $activeMembership->membershipPlan?->slug,
            'status' => $activeMembership->status,
            'payment_status' => $activeMembership->payment_status,
            'start_date' => $activeMembership->start_date?->toDateString(),
            'end_date' => $activeMembership->end_date?->toDateString(),
            'is_active' => $activeMembership->isCurrentlyActive(),
        ] : null;

        return $data;
    }
}

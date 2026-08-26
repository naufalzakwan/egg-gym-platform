<?php

namespace App\Http\Resources\Api\V1\Member;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MemberProfileResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $memberProfile = $this->memberProfile;
        $activeMembership = $this->active_membership;

        return [
            'id' => $this->id,
            'member_code' => $memberProfile?->member_code,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'avatar_url' => $this->avatar_url,
            'status' => $this->status,
            'gender' => $memberProfile?->gender,
            'birth_date' => $memberProfile?->birth_date?->toDateString(),
            'height_cm' => $memberProfile?->height_cm !== null ? (float) $memberProfile->height_cm : null,
            'weight_kg' => $memberProfile?->weight_kg !== null ? (float) $memberProfile->weight_kg : null,
            'fitness_goal' => $memberProfile?->fitness_goal,
            'medical_note' => $memberProfile?->medical_note,
            'joined_at' => $memberProfile?->joined_at?->toIso8601String(),
            'current_tier' => $this->resolveCurrentTier($activeMembership?->membershipPlan?->slug),
            'workouts_this_month' => (int) ($this->workouts_this_month ?? 0),
            'active_membership' => $activeMembership ? [
                'plan_name' => $activeMembership->membershipPlan?->name,
                'start_date' => $activeMembership->start_date?->toDateString(),
                'end_date' => $activeMembership->end_date?->toDateString(),
                'status' => $activeMembership->status,
                'payment_status' => $activeMembership->payment_status,
            ] : null,
        ];
    }

    private function resolveCurrentTier(?string $slug): string
    {
        return match ($slug) {
            'elite-member' => 'Elite Status',
            'annual-pro' => 'Pro Annual Status',
            'starter-pack' => 'Starter Status',
            default => 'Member Status',
        };
    }
}

<?php

namespace App\Http\Resources\Api\V1\Member;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MemberMembershipResource extends JsonResource
{
    /**
     * Override sisa hari & tanggal akhir agar mengikuti RANTAI membership
     * kontigu (bukan hanya row ini). Diisi HANYA untuk active_membership;
     * untuk baris history dibiarkan null -> tampil per-row seperti biasa.
     */
    public ?int $chainRemainingDaysOverride = null;

    public ?\Carbon\Carbon $chainEndDateOverride = null;

    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $isCurrentlyActive = $this->isCurrentlyActive();

        // Untuk row aktif: pakai override rantai bila tersedia (mencakup
        // pembelian yang di-stack ke depan), agar konsisten dgn dashboard.
        $remainingDays = $this->chainRemainingDaysOverride
            ?? ($isCurrentlyActive && $this->end_date
                ? max(0, now()->startOfDay()->diffInDays($this->end_date, false))
                : 0);

        $endDate = ($this->chainEndDateOverride ?? $this->end_date)?->toDateString();

        return [
            'id' => $this->id,
            'plan' => [
                'id' => $this->membershipPlan?->id,
                'name' => $this->membershipPlan?->name,
                'slug' => $this->membershipPlan?->slug,
                'price' => $this->membershipPlan?->price !== null
                    ? (float) $this->membershipPlan->price
                    : null,
                'billing_period' => $this->membershipPlan?->billing_period,
                'features' => $this->membershipPlan?->features_json ?? [],
            ],
            'start_date' => $this->start_date?->toDateString(),
            'end_date' => $endDate,
            'status' => $this->status,
            'payment_status' => $this->payment_status,
            'remaining_days' => $remainingDays,
            'is_active' => $isCurrentlyActive,
        ];
    }
}

<?php

namespace App\Http\Resources\Api\V1\Public;

use App\Models\MembershipPlan;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MembershipPlanResource extends JsonResource
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
            'name' => $this->name,
            'slug' => $this->slug,
            'price' => (float) $this->price,
            'billing_period' => $this->billing_period,
            'duration_days' => (int) $this->duration_days,
            'features' => collect($this->features_json ?? [])
                ->map(fn ($benefit) => MembershipPlan::benefitDisplayLabel((string) $benefit))
                ->values()
                ->all(),
            'is_highlighted' => $this->slug === 'elite-member',
            'is_best_seller' => (bool) ($this->is_best_seller ?? false),
            'is_active' => $this->is_active,
        ];
    }
}

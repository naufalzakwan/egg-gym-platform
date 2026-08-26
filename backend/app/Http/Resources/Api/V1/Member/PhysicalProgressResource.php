<?php

namespace App\Http\Resources\Api\V1\Member;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PhysicalProgressResource extends JsonResource
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
            'recorded_at' => $this->recorded_at?->toDateString(),
            'weight_kg' => $this->weight_kg !== null ? (float) $this->weight_kg : null,
            'height_cm' => $this->height_cm !== null ? (float) $this->height_cm : null,
            'note' => $this->note,
            'is_milestone' => (bool) $this->is_milestone,
            // photo_url = RELATIVE PATH (mis. "member-progress/x.jpg"). Flutter
            // merangkai baseUrl aktif + /storage/ + path saat render.
            'photos' => $this->photos->map(function ($photo) {
                return [
                    'id' => $photo->id,
                    'photo_type' => $photo->photo_type,
                    'photo_url' => $photo->photo_url,
                ];
            })->values(),
        ];
    }
}

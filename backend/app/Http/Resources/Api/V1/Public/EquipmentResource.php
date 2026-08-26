<?php

namespace App\Http\Resources\Api\V1\Public;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class EquipmentResource extends JsonResource
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
            'code' => $this->code,
            'name' => $this->name,
            'slug' => $this->slug,
            'category' => $this->category,
            'status' => $this->status,
            'status_label' => $this->status_meta['label'],
            'description' => $this->description,
            // Relative path: Flutter merangkai baseUrl aktif + /storage/ + path.
            'image_path' => $this->image_path,
            'focus' => $this->focus,
            'stage_label' => $this->stage_label,
            'usage_window' => $this->usage_window,
            'best_for' => $this->best_for,
            'difficulty' => $this->difficulty,
            'key_benefits' => $this->key_benefits_json ?? [],
            'usage_flow' => $this->usage_flow_json ?? [],
            'safety_notes' => $this->safety_notes_json ?? [],
            'suggested_movements' => $this->suggested_moves_json ?? [],
            'movements' => $this->movements->map(fn ($movement) => [
                'id' => $movement->id,
                'movement_name' => $movement->movement_name,
                'target_area' => $movement->target_area,
                'sort_order' => $movement->sort_order,
            ])->values(),
            'is_active' => $this->is_active,
        ];
    }
}

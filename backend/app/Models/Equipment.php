<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Storage;

class Equipment extends Model
{
    use HasFactory;

    protected $table = 'equipments';

    protected $fillable = [
        'code',
        'name',
        'slug',
        'category',
        'description',
        'image_path',
        'status',
        'focus',
        'stage_label',
        'usage_window',
        'best_for',
        'difficulty',
        'key_benefits_json',
        'usage_flow_json',
        'safety_notes_json',
        'suggested_moves_json',
        'is_active',
    ];

    /** Status operasional alat yang valid (3-state). */
    public const STATUSES = ['available', 'maintenance', 'broken'];

    protected $casts = [
        'key_benefits_json' => 'array',
        'usage_flow_json' => 'array',
        'safety_notes_json' => 'array',
        'suggested_moves_json' => 'array',
        'is_active' => 'boolean',
    ];

    public function movements(): HasMany
    {
        return $this->hasMany(GymEquipmentMovement::class, 'gym_equipment_id')
            ->orderBy('sort_order')
            ->orderBy('id');
    }

    /**
     * URL publik foto alat (untuk admin + guest/member/trainer). Null bila
     * belum ada foto yang diupload.
     */
    public function getImageUrlAttribute(): ?string
    {
        if (empty($this->image_path)) {
            return null;
        }

        return Storage::disk('public')->url($this->image_path);
    }

    /**
     * Metadata status untuk badge: label ID + warna hex.
     */
    public function getStatusMetaAttribute(): array
    {
        return match ($this->status) {
            'maintenance' => ['label' => 'Maintenance', 'color' => '#F5C300'],
            'broken' => ['label' => 'Rusak', 'color' => '#EF4444'],
            default => ['label' => 'Tersedia', 'color' => '#4CAF50'],
        };
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class GymEquipmentMovement extends Model
{
    use HasFactory;

    protected $fillable = [
        'gym_equipment_id',
        'movement_name',
        'target_area',
        'sort_order',
    ];

    public function equipment(): BelongsTo
    {
        return $this->belongsTo(Equipment::class, 'gym_equipment_id');
    }
}

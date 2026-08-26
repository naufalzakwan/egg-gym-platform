<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SelfTrainingExercise extends Model
{
    use HasFactory;

    protected $fillable = [
        'self_training_session_id',
        'equipment_id',
        'gym_equipment_movement_id',
        'equipment_name',
        'sequence_order',
        'name',
        'target_muscle',
        'sets',
        'reps',
        'rest_seconds',
        'load',
        'notes',
        'is_completed',
        'completed_at',
    ];

    protected $casts = [
        'sequence_order' => 'integer',
        'sets' => 'integer',
        'reps' => 'integer',
        'rest_seconds' => 'integer',
        'is_completed' => 'boolean',
        'completed_at' => 'datetime',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(SelfTrainingSession::class, 'self_training_session_id');
    }

    public function equipment(): BelongsTo
    {
        return $this->belongsTo(Equipment::class);
    }

    public function equipmentMovement(): BelongsTo
    {
        return $this->belongsTo(GymEquipmentMovement::class, 'gym_equipment_movement_id');
    }
}

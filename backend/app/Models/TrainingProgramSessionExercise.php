<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TrainingProgramSessionExercise extends Model
{
    use HasFactory;

    protected $fillable = [
        'training_program_session_id',
        'exercise_library_id',
        'equipment_id',
        'gym_equipment_movement_id',
        'equipment_name',
        'sequence_order',
        'custom_name',
        'custom_target_muscle',
        'sets',
        'reps',
        'rest_seconds',
        'cue_text',
        'status',
    ];

    protected $casts = [
        'sequence_order' => 'integer',
        'sets' => 'integer',
        'reps' => 'integer',
        'rest_seconds' => 'integer',
    ];

    public function trainingProgramSession(): BelongsTo
    {
        return $this->belongsTo(TrainingProgramSession::class);
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

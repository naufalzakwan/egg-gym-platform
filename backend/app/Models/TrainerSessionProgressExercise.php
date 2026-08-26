<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TrainerSessionProgressExercise extends Model
{
    use HasFactory;

    protected $fillable = [
        'trainer_session_progress_id',
        'training_program_session_exercise_id',
        'completed_sets',
        'total_sets',
        'status',
        'last_marked_at',
    ];

    protected $casts = [
        'completed_sets' => 'integer',
        'total_sets' => 'integer',
        'last_marked_at' => 'datetime',
    ];

    public function trainerSessionProgress(): BelongsTo
    {
        return $this->belongsTo(TrainerSessionProgress::class);
    }

    public function trainingProgramSessionExercise(): BelongsTo
    {
        return $this->belongsTo(TrainingProgramSessionExercise::class);
    }
}

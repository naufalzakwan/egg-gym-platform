<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TrainerSessionProgress extends Model
{
    use HasFactory;

    protected $table = 'trainer_session_progresses';

    protected $fillable = [
        'training_program_id',
        'training_program_session_id',
        'trainer_profile_id',
        'member_profile_id',
        'progress_percent',
        'current_exercise_order',
        'status',
        'synced_at',
        'trainer_note',
    ];

    protected $casts = [
        'progress_percent' => 'float',
        'current_exercise_order' => 'integer',
        'synced_at' => 'datetime',
    ];

    public function trainingProgram(): BelongsTo
    {
        return $this->belongsTo(TrainingProgram::class);
    }

    public function trainingProgramSession(): BelongsTo
    {
        return $this->belongsTo(TrainingProgramSession::class);
    }

    public function trainerProfile(): BelongsTo
    {
        return $this->belongsTo(TrainerProfile::class);
    }

    public function memberProfile(): BelongsTo
    {
        return $this->belongsTo(MemberProfile::class);
    }

    public function exercises(): HasMany
    {
        return $this->hasMany(TrainerSessionProgressExercise::class);
    }
}

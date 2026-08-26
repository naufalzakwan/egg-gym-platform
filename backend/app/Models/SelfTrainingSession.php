<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SelfTrainingSession extends Model
{
    use HasFactory;

    protected $fillable = [
        'self_training_program_id',
        'sequence_order',
        'title',
        'focus',
        'duration_minutes',
        'status',
    ];

    protected $casts = [
        'sequence_order' => 'integer',
        'duration_minutes' => 'integer',
    ];

    public function program(): BelongsTo
    {
        return $this->belongsTo(SelfTrainingProgram::class, 'self_training_program_id');
    }

    public function exercises(): HasMany
    {
        return $this->hasMany(SelfTrainingExercise::class)
            ->orderBy('sequence_order');
    }
}

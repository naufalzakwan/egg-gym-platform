<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class TrainingProgramSession extends Model
{
    use HasFactory;

    protected $fillable = [
        'training_program_id',
        'booking_session_reservation_id',
        'sequence_order',
        'title',
        'focus',
        'duration_minutes',
        'status',
        'unlock_rule',
        'coach_note',
        'member_ready',
        'member_ready_at',
    ];

    protected $casts = [
        'sequence_order' => 'integer',
        'duration_minutes' => 'integer',
        'member_ready' => 'boolean',
        'member_ready_at' => 'datetime',
    ];

    public function trainingProgram(): BelongsTo
    {
        return $this->belongsTo(TrainingProgram::class);
    }

    public function bookingSessionReservation(): BelongsTo
    {
        return $this->belongsTo(BookingSessionReservation::class);
    }

    public function trainerSessionProgress(): HasOne
    {
        return $this->hasOne(TrainerSessionProgress::class);
    }

    public function exercises(): HasMany
    {
        return $this->hasMany(TrainingProgramSessionExercise::class)
            ->orderBy('sequence_order');
    }
}

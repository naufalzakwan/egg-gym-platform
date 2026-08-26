<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TrainerRating extends Model
{
    use HasFactory;

    protected $fillable = [
        'member_profile_id',
        'trainer_profile_id',
        'booking_id',
        'training_program_id',
        'rating',
        'testimonial',
    ];

    protected $casts = [
        'rating' => 'integer',
    ];

    public function scopeValid(Builder $query): Builder
    {
        return $query->whereBetween('rating', [1, 5]);
    }

    public function memberProfile(): BelongsTo
    {
        return $this->belongsTo(MemberProfile::class);
    }

    public function trainerProfile(): BelongsTo
    {
        return $this->belongsTo(TrainerProfile::class);
    }

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function trainingProgram(): BelongsTo
    {
        return $this->belongsTo(TrainingProgram::class);
    }
}

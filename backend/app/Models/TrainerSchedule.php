<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class TrainerSchedule extends Model
{
    use HasFactory;

    protected $fillable = [
        'trainer_profile_id',
        'template_key',
        'day_of_week',
        'start_time',
        'end_time',
        'session_duration_minutes',
    ];

    protected $casts = [
        'day_of_week' => 'integer',
        'session_duration_minutes' => 'integer',
    ];

    protected static function booted(): void
    {
        static::creating(function (TrainerSchedule $schedule): void {
            $schedule->template_key ??= (string) Str::uuid();
        });
    }

    public function trainerProfile(): BelongsTo
    {
        return $this->belongsTo(TrainerProfile::class);
    }
}

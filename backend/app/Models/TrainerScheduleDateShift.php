<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TrainerScheduleDateShift extends Model
{
    use HasFactory;

    protected $fillable = [
        'trainer_schedule_date_id',
        'source_trainer_schedule_id',
        'source_template_key',
        'start_time',
        'end_time',
        'session_duration_minutes',
    ];

    protected $casts = [
        'session_duration_minutes' => 'integer',
    ];

    public function scheduleDate(): BelongsTo
    {
        return $this->belongsTo(TrainerScheduleDate::class, 'trainer_schedule_date_id');
    }

    public function sourceTemplate(): BelongsTo
    {
        return $this->belongsTo(TrainerSchedule::class, 'source_trainer_schedule_id');
    }
}

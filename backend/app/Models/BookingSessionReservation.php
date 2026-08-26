<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\HasMany;

class BookingSessionReservation extends Model
{
    use HasFactory;

    public const STATUS_RESERVED = 'reserved';

    public const STATUS_COMPLETED = 'completed';

    public const STATUS_RELEASED = 'released';

    public const STATUS_CANCELLED = 'cancelled';

    public const SCHEDULE_BLOCKING_STATUSES = [self::STATUS_RESERVED];

    protected $fillable = [
        'booking_id',
        'sequence_order',
        'trainer_profile_id',
        'member_profile_id',
        'trainer_schedule_date_id',
        'session_date',
        'start_time',
        'end_time',
        'session_duration_minutes',
        'status',
        'completed_at',
        'released_at',
        'release_reason',
    ];

    protected $casts = [
        'sequence_order' => 'integer',
        'session_date' => 'date',
        'session_duration_minutes' => 'integer',
        'completed_at' => 'datetime',
        'released_at' => 'datetime',
    ];

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function trainerProfile(): BelongsTo
    {
        return $this->belongsTo(TrainerProfile::class);
    }

    public function memberProfile(): BelongsTo
    {
        return $this->belongsTo(MemberProfile::class);
    }

    public function trainerScheduleDate(): BelongsTo
    {
        return $this->belongsTo(TrainerScheduleDate::class);
    }

    public function trainingProgramSession(): HasOne
    {
        return $this->hasOne(TrainingProgramSession::class);
    }

    public function rescheduleRequests(): HasMany
    {
        return $this->hasMany(BookingRescheduleRequest::class);
    }

    public function pendingRescheduleRequest(): HasOne
    {
        return $this->hasOne(BookingRescheduleRequest::class, 'active_reservation_id');
    }
}

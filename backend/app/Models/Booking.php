<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Booking extends Model
{
    use HasFactory;

    public const SCHEDULE_BLOCKING_STATUSES = [
        'pending',
        'waiting_payment',
        'payment_uploaded',
        'payment_rejected',
        'payment_verified',
        'confirmed',
        'rescheduled',
    ];

    public static function blocksSchedule(?string $status): bool
    {
        return in_array($status, self::SCHEDULE_BLOCKING_STATUSES, true);
    }

    protected $fillable = [
        'member_profile_id',
        'trainer_profile_id',
        'trainer_schedule_date_id',
        'session_title',
        'session_date',
        'start_time',
        'end_time',
        'session_duration_minutes',
        'location',
        'session_count',
        'price_per_session_snapshot',
        'total_amount_snapshot',
        'status',
        'expired_at',
        'member_note',
        'trainer_note',
        'payment_proof_path',
        'payment_proof_uploaded_at',
        'payment_verified_at',
        'verification_overdue_notified_at',
    ];

    protected $casts = [
        'session_date' => 'date',
        'session_count' => 'integer',
        'session_duration_minutes' => 'integer',
        'price_per_session_snapshot' => 'decimal:2',
        'total_amount_snapshot' => 'decimal:2',
        'expired_at' => 'datetime',
        'payment_proof_uploaded_at' => 'datetime',
        'payment_verified_at' => 'datetime',
        'verification_overdue_notified_at' => 'datetime',
    ];

    public function memberProfile(): BelongsTo
    {
        return $this->belongsTo(MemberProfile::class);
    }

    public function trainerProfile(): BelongsTo
    {
        return $this->belongsTo(TrainerProfile::class);
    }

    public function trainerScheduleDate(): BelongsTo
    {
        return $this->belongsTo(TrainerScheduleDate::class);
    }

    public function sessionReservations(): HasMany
    {
        return $this->hasMany(BookingSessionReservation::class)
            ->orderBy('sequence_order');
    }

    public function rescheduleRequests(): HasMany
    {
        return $this->hasMany(BookingRescheduleRequest::class);
    }
}

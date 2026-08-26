<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class BookingRescheduleRequest extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'pending';

    public const STATUS_ACCEPTED = 'accepted';

    public const STATUS_REJECTED = 'rejected';

    public const STATUS_CANCELLED = 'cancelled';

    public const STATUS_EXPIRED = 'expired';

    protected $fillable = [
        'booking_id', 'booking_session_reservation_id', 'active_reservation_id',
        'trainer_profile_id', 'requested_by_user_id', 'requested_by_role',
        'original_trainer_schedule_date_id', 'original_session_date',
        'original_start_time', 'original_end_time',
        'proposed_trainer_schedule_date_id', 'proposed_session_date',
        'proposed_start_time', 'proposed_end_time', 'proposed_duration_minutes',
        'reason_type', 'reason_note', 'status', 'expired_at',
        'responded_by_user_id', 'responded_at', 'rejected_reason_type',
        'rejected_reason_note', 'cancelled_at',
    ];

    protected $casts = [
        'original_session_date' => 'date',
        'proposed_session_date' => 'date',
        'proposed_duration_minutes' => 'integer',
        'expired_at' => 'datetime',
        'responded_at' => 'datetime',
        'cancelled_at' => 'datetime',
    ];

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function reservation(): BelongsTo
    {
        return $this->belongsTo(BookingSessionReservation::class, 'booking_session_reservation_id');
    }

    public function requestedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requested_by_user_id');
    }

    public function respondedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'responded_by_user_id');
    }

    public function proposedScheduleDate(): BelongsTo
    {
        return $this->belongsTo(TrainerScheduleDate::class, 'proposed_trainer_schedule_date_id');
    }
}

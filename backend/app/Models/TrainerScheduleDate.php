<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TrainerScheduleDate extends Model
{
    use HasFactory;

    protected $fillable = [
        'trainer_profile_id',
        'schedule_date',
        'state',
        'source',
        'template_version',
        'template_fingerprint',
        'operation_fingerprint',
        'generated_at',
        'overridden_at',
        'overridden_by_user_id',
        'override_reason',
        'lock_version',
    ];

    protected $casts = [
        'schedule_date' => 'date',
        'template_version' => 'integer',
        'generated_at' => 'datetime',
        'overridden_at' => 'datetime',
        'lock_version' => 'integer',
    ];

    public function trainerProfile(): BelongsTo
    {
        return $this->belongsTo(TrainerProfile::class);
    }

    public function shifts(): HasMany
    {
        return $this->hasMany(TrainerScheduleDateShift::class);
    }

    public function overriddenBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'overridden_by_user_id');
    }

    public function bookings(): HasMany
    {
        return $this->hasMany(Booking::class);
    }

    public function bookingSessionReservations(): HasMany
    {
        return $this->hasMany(BookingSessionReservation::class);
    }
}

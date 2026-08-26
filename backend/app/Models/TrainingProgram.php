<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TrainingProgram extends Model
{
    use HasFactory;

    public const TERMINAL_STATUSES = [
        'completed',
        'closed_early',
        'cancelled',
        'archived',
        'closed',
    ];

    public const MUTABLE_STATUSES = ['draft', 'published', 'active'];

    public const TERMINAL_SESSION_STATUSES = ['completed', 'cancelled'];

    protected $fillable = [
        'trainer_profile_id',
        'member_profile_id',
        'booking_id',
        'title',
        'description',
        'goal',
        'status',
        'started_at',
        'ended_at',
    ];

    protected $casts = [
        'started_at' => 'date',
        'ended_at' => 'date',
    ];

    public function trainerProfile(): BelongsTo
    {
        return $this->belongsTo(TrainerProfile::class);
    }

    public function memberProfile(): BelongsTo
    {
        return $this->belongsTo(MemberProfile::class);
    }

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(TrainingProgramSession::class)
            ->orderBy('sequence_order');
    }

    public function scopeRuntimeActive(Builder $query): Builder
    {
        return $query
            ->whereIn('status', self::MUTABLE_STATUSES)
            ->whereHas('sessions', function (Builder $sessions): void {
                $sessions->whereNotIn('status', self::TERMINAL_SESSION_STATUSES);
            });
    }

    public function hasUnfinishedSessions(): bool
    {
        return $this->sessions()
            ->whereNotIn('status', self::TERMINAL_SESSION_STATUSES)
            ->exists();
    }
}

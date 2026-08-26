<?php

namespace App\Models;

use App\Support\TrainerSpecialty;
use App\Support\TrainerTier;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TrainerProfile extends Model
{
    use HasFactory;

    /**
     * Kuota dasar (gelombang pertama) member aktif per trainer.
     * Cap sebenarnya bersifat dinamis per gelombang pemerataan, lihat
     * currentQuotaCap().
     */
    public const BASE_QUOTA = 2;

    protected $fillable = [
        'user_id',
        'specialty',
        'specialties',
        'tier',
        'max_clients',
        'verification_status',
        'admin_notes',
        'bio',
        'rating',
        'experience_years',
        'certifications',
        'availability_note',
        'display_photo_path',
        'bank_name',
        'bank_account_number',
        'bank_account_name',
        'dana_number',
        'dana_account_name',
        'other_payment_method',
        'other_payment_number',
        'other_payment_account_name',
        'price_per_session',
    ];

    protected $casts = [
        'rating' => 'decimal:2',
        'experience_years' => 'integer',
        'max_clients' => 'integer',
        'price_per_session' => 'decimal:2',
        'specialties' => 'array',
    ];

    public function getCertificationListAttribute(): array
    {
        return collect(explode(',', (string) $this->certifications))
            ->map(fn ($value) => trim($value))
            ->filter()
            ->unique(fn ($value) => mb_strtolower($value))
            ->values()
            ->all();
    }

    public function getSpecialtyLabelAttribute(): ?string
    {
        return TrainerSpecialty::label($this->attributes['specialty'] ?? null);
    }

    public function getSpecialtyLabelsAttribute(): array
    {
        $allowed = TrainerSpecialty::labels();
        $values = collect($this->specialties ?? [])
            ->map(fn ($value) => TrainerSpecialty::label(is_string($value) ? $value : null))
            ->filter(fn ($value) => in_array($value, $allowed, true))
            ->unique()
            ->values()
            ->all();

        if ($values !== []) {
            return $values;
        }

        $fallback = TrainerSpecialty::label($this->attributes['specialty'] ?? null);

        return $fallback === null ? [] : [$fallback];
    }

    public function getTierValueAttribute(): ?string
    {
        return TrainerTier::normalize($this->attributes['tier'] ?? null);
    }

    public function getTierLabelAttribute(): ?string
    {
        return TrainerTier::label($this->attributes['tier'] ?? null);
    }

    /**
     * Get the owning user of this trainer profile.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function bookings(): HasMany
    {
        return $this->hasMany(Booking::class);
    }

    public function schedules(): HasMany
    {
        return $this->hasMany(TrainerSchedule::class);
    }

    public function scopeWithActiveSchedule(Builder $query): Builder
    {
        return $query->withExists([
            'schedules as has_active_schedule' => fn (Builder $schedule) => $schedule
                ->whereBetween('day_of_week', [1, 7])
                ->whereColumn('start_time', '<', 'end_time'),
        ]);
    }

    public function scheduleDates(): HasMany
    {
        return $this->hasMany(TrainerScheduleDate::class);
    }

    public function trainingPrograms(): HasMany
    {
        return $this->hasMany(TrainingProgram::class);
    }

    public function ratings(): HasMany
    {
        return $this->hasMany(TrainerRating::class);
    }

    public function scopeWithRatingStats(Builder $query): Builder
    {
        return $query
            ->withAvg([
                'ratings as rating_average' => fn (Builder $ratings) => $ratings->valid(),
            ], 'rating')
            ->withCount([
                'ratings as reviews_count' => fn (Builder $ratings) => $ratings->valid(),
            ]);
    }

    public function activeMembersCount(): int
    {
        return $this->trainingPrograms()
            ->where('status', 'active')
            ->distinct('member_profile_id')
            ->count('member_profile_id');
    }

    /**
     * Jumlah member UNIK yang sudah/sedang dilayani trainer ini.
     * Definisi (disepakati owner): DISTINCT member_profile_id dari gabungan:
     *  - booking berstatus 'completed' (sudah dilayani) ATAU 'confirmed'
     *    (sedang berlangsung/terjadwal), DAN
     *  - member yang sudah memberi rating ke trainer ini (trainer_ratings).
     * Berbeda dari kuota (activeQuotaMembers) — ini metrik historis "served".
     */
    public function servedClientsCount(): int
    {
        $fromBookings = $this->bookings()
            ->whereIn('status', ['completed', 'confirmed'])
            ->pluck('member_profile_id');

        $fromRatings = $this->relationLoaded('ratings')
            ? $this->ratings->pluck('member_profile_id')
            : $this->ratings()->valid()->pluck('member_profile_id');

        return $fromBookings
            ->merge($fromRatings)
            ->filter(fn ($id) => $id !== null)
            ->unique()
            ->count();
    }

    /**
     * Jumlah member aktif yang sedang ditangani trainer ini untuk perhitungan
     * kuota. Dihitung dari booking berstatus aktif (pending s/d payment_verified/
     * confirmed), lalu dikurangi member yang program latihannya sudah SELESAI
     * 100% (seluruh sesi completed). Member dengan program tuntas dibebaskan
     * dari kuota sehingga slotnya kembali tersedia untuk member baru.
     */
    public function activeQuotaMembers(): int
    {
        $memberIds = $this->bookings()
            ->whereIn('status', MemberProfile::ACTIVE_BOOKING_STATUSES)
            ->pluck('member_profile_id')
            ->unique();

        $count = 0;
        foreach ($memberIds as $memberProfileId) {
            if ($this->memberEngagementActive((int) $memberProfileId)) {
                $count++;
            }
        }

        return $count;
    }

    /**
     * Apakah engagement seorang member dengan trainer ini masih menahan kuota
     * (belum tuntas). Tuntas = program latihan sudah SELESAI 100% (semua sesi
     * berstatus completed). Begitu program selesai, member tidak lagi dihitung
     * sebagai member aktif sehingga slot kuota trainer kembali tersedia.
     */
    protected function memberEngagementActive(int $memberProfileId): bool
    {
        $booking = $this->bookings()
            ->where('member_profile_id', $memberProfileId)
            ->whereIn('status', MemberProfile::ACTIVE_BOOKING_STATUSES)
            ->latest('id')
            ->first();

        if (! $booking) {
            return false;
        }

        $program = TrainingProgram::query()
            ->withCount([
                'sessions',
                'sessions as completed_sessions_count' => function ($query) {
                    $query->where('status', 'completed');
                },
            ])
            ->where(function ($query) use ($booking) {
                $query->where('booking_id', $booking->id)
                    ->orWhere(function ($legacy) use ($booking) {
                        $legacy->whereNull('booking_id')
                            ->whereHas('sessions.bookingSessionReservation', function ($reservation) use ($booking) {
                                $reservation->where('booking_id', $booking->id);
                            });
                    });
            })
            ->latest('id')
            ->first();

        // Belum ada program (masih pending/pembayaran/penyusunan program) → aktif.
        if (! $program) {
            return true;
        }

        $programCompleted = $program->sessions_count > 0
            && $program->completed_sessions_count === $program->sessions_count;

        // Program sudah selesai 100% → slot dibebaskan (tidak lagi dihitung aktif).
        // Program belum selesai → masih menahan kuota.
        return ! $programCompleted;
    }

    /**
     * Cap kuota dinamis berbasis "gelombang" pemerataan.
     *
     * Cap = max(BASE_QUOTA, minimum member aktif di antara SEMUA trainer + 1).
     * Artinya: cap baru naik satu tingkat hanya ketika trainer dengan member
     * paling sedikit pun sudah mencapai cap gelombang saat ini — sehingga
     * trainer yang masih di bawah harus "dikejar" dulu sebelum semua naik level.
     *
     * Contoh (2 trainer):
     *  - [2,2] -> min 2 -> cap 3 (gelombang naik, semua boleh sampai 3)
     *  - [2,0] -> min 0 -> cap 2 (yang 0 masih boleh, yang 2 diblokir)
     *  - [3,2] -> min 2 -> cap 3 (yang 3 diblokir, yang 2 masih boleh)
     */
    public function currentQuotaCap(): int
    {
        $counts = static::query()
            ->get()
            ->map(fn (TrainerProfile $trainer) => $trainer->activeQuotaMembers());

        // Tidak ada trainer lain untuk dibandingkan → pakai kuota dasar.
        if ($counts->isEmpty()) {
            return self::BASE_QUOTA;
        }

        $minActive = (int) $counts->min();

        return max(self::BASE_QUOTA, $minActive + 1);
    }

    /**
     * Apakah trainer masih punya kuota untuk menerima member baru,
     * berdasarkan cap gelombang saat ini.
     */
    public function hasAvailableQuota(): bool
    {
        return $this->activeQuotaMembers() < $this->currentQuotaCap();
    }

    public function averageRating(): float
    {
        return (float) ($this->ratings()->valid()->avg('rating') ?? 0);
    }

    public function totalRatings(): int
    {
        return $this->ratings()->valid()->count();
    }
}

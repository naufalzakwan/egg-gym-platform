<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class MemberProfile extends Model
{
    use HasFactory;

    /**
     * Status booking yang dianggap "engagement PT aktif" (belum tuntas).
     * cancelled/completed/payment_rejected TIDAK termasuk.
     */
    // Satu sumber status yang menahan engagement sekaligus slot trainer.
    public const ACTIVE_BOOKING_STATUSES = Booking::SCHEDULE_BLOCKING_STATUSES;

    protected $fillable = [
        'user_id',
        'member_code',
        'gender',
        'birth_date',
        'height_cm',
        'weight_kg',
        'fitness_goal',
        'medical_note',
        'joined_at',
    ];

    protected $casts = [
        'birth_date' => 'date',
        'joined_at' => 'datetime',
        'height_cm' => 'decimal:1',
        'weight_kg' => 'decimal:1',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function memberships(): HasMany
    {
        return $this->hasMany(MemberMembership::class);
    }

    public function bookings(): HasMany
    {
        return $this->hasMany(Booking::class);
    }

    public function trainingPrograms(): HasMany
    {
        return $this->hasMany(TrainingProgram::class);
    }

    public function progressRecords(): HasMany
    {
        return $this->hasMany(MemberProgress::class);
    }

    public function ratings(): HasMany
    {
        return $this->hasMany(TrainerRating::class);
    }

    /**
     * Booking PT aktif yang masih "menahan" member (belum tuntas), atau null.
     *
     * Member dianggap masih terikat bila:
     * - Ada booking di status awal (pending / waiting_payment / payment_uploaded
     *   / rescheduled), ATAU
     * - Ada booking (payment_verified / confirmed / completed) yang programnya
     *   BELUM selesai 100%, ATAU sudah selesai tapi BELUM diberi rating.
     *
     * Catatan: status 'completed' ikut dipindai. Sejak booking otomatis jadi
     * 'completed' saat program 100% (agar kuota trainer bebas tanpa menunggu
     * rating), gate rating sisi member TETAP harus melihat booking completed —
     * supaya rating tetap WAJIB sebelum member bisa booking PT baru.
     */
    public function activePtBooking(): ?Booking
    {
        $statuses = array_merge(self::ACTIVE_BOOKING_STATUSES, ['completed']);

        $bookings = $this->bookings()
            ->whereIn('status', $statuses)
            ->latest('id')
            ->get();

        foreach ($bookings as $booking) {
            // Status awal (belum bayar/verifikasi): selalu menahan member.
            if (! in_array($booking->status, ['payment_verified', 'confirmed', 'completed'], true)) {
                return $booking;
            }

            // payment_verified / confirmed / completed: cek program & rating.
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

            if (! $program) {
                // Booking completed tanpa program = anomali data lama; jangan
                // jebak member. Selain itu (mis. payment_verified belum ada
                // program) → trainer sedang menyusun → tetap menahan.
                if ($booking->status === 'completed') {
                    continue;
                }

                return $booking;
            }

            if (in_array($program->status, ['closed_early', 'cancelled', 'archived', 'closed'], true)) {
                continue;
            }

            $programCompleted = $program->sessions_count > 0
                && $program->completed_sessions_count === $program->sessions_count;

            // Program belum 100% selesai → tetap menahan.
            if (! $programCompleted) {
                return $booking;
            }

            // Program selesai tapi belum dirating → tetap menahan (rating wajib).
            if (! $this->hasRatedProgram($program)) {
                return $booking;
            }

            // Program selesai + sudah dirating → booking ini tidak menahan;
            // lanjut cek booking lain.
        }

        return null;
    }

    /**
     * Apakah member sudah memberi rating untuk program (trainer) ini.
     *
     * Menangani dua skema rating: baru (keyed training_program_id) dan lama
     * (training_program_id NULL, hanya keyed booking_id/trainer) — agar data
     * lama tidak salah dianggap "belum rating" selamanya.
     */
    protected function hasRatedProgram(TrainingProgram $program): bool
    {
        return TrainerRating::query()
            ->where('member_profile_id', $this->id)
            ->where(function ($query) use ($program) {
                $query
                    ->where('training_program_id', $program->id)
                    ->orWhere(function ($legacy) use ($program) {
                        $legacy
                            ->whereNull('training_program_id')
                            ->where('trainer_profile_id', $program->trainer_profile_id);
                    });
            })
            ->exists();
    }

    /**
     * Apakah member sedang terikat sesi PT aktif (tidak boleh booking PT lain).
     */
    public function hasActivePtEngagement(): bool
    {
        return $this->activePtBooking() !== null;
    }

    /**
     * Apakah data profil fisik member sudah lengkap sebagai syarat booking:
     * tinggi badan, berat badan, dan target/goal latihan wajib terisi.
     */
    public function hasCompleteProfile(): bool
    {
        return $this->height_cm !== null
            && (float) $this->height_cm > 0
            && $this->weight_kg !== null
            && (float) $this->weight_kg > 0
            && $this->fitness_goal !== null
            && trim((string) $this->fitness_goal) !== '';
    }
}

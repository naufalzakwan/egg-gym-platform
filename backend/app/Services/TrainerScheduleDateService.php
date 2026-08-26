<?php

namespace App\Services;

use App\Exceptions\BookingScheduleException;
use App\Models\Booking;
use App\Models\BookingRescheduleRequest;
use App\Models\BookingSessionReservation;
use App\Models\GymOperationHour;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class TrainerScheduleDateService
{
    private const DAY_NAMES = [
        1 => 'Monday',
        2 => 'Tuesday',
        3 => 'Wednesday',
        4 => 'Thursday',
        5 => 'Friday',
        6 => 'Saturday',
        7 => 'Sunday',
    ];

    public function __construct(private readonly TrainerScheduleMaterializer $materializer) {}

    public function month(TrainerProfile $trainer, ?string $month = null): array
    {
        $today = CarbonImmutable::now(TrainerScheduleMaterializer::TIMEZONE)->startOfDay();
        $start = $month === null
            ? $today->startOfMonth()
            : CarbonImmutable::createFromFormat('!Y-m', $month, TrainerScheduleMaterializer::TIMEZONE)
                ->startOfMonth();
        $end = $start->endOfMonth()->startOfDay();
        $displayStart = $start->isSameMonth($today) ? $today : $start;

        // Tanggal lampau hanya histori dan tidak boleh diregenerasi saat membuka
        // editor bulan berjalan; booking historis tidak boleh memblokir GET halaman.
        $this->materializer->materializeTrainer($trainer, $displayStart, $end);

        $dates = $trainer->scheduleDates()
            ->with(['shifts' => fn ($query) => $query->orderBy('start_time')])
            ->whereBetween('schedule_date', [$displayStart->toDateString(), $end->toDateString()])
            ->orderBy('schedule_date')
            ->get();
        $templates = $trainer->schedules()
            ->orderBy('day_of_week')
            ->orderBy('start_time')
            ->get()
            ->groupBy('day_of_week');

        return [
            'timezone' => TrainerScheduleMaterializer::TIMEZONE,
            'month' => $start->format('Y-m'),
            'editable_from' => $today->toDateString(),
            'editable_until' => $today->addMonthNoOverflow()->endOfMonth()->toDateString(),
            'dates' => $dates->map(fn (TrainerScheduleDate $date) => $this->normalize(
                $date,
                $templates->get($date->schedule_date->dayOfWeekIso, collect())
            ))->values(),
        ];
    }

    public function update(
        TrainerProfile $trainer,
        int $userId,
        string $dateValue,
        string $mode,
        int $expectedLockVersion,
        array $shifts
    ): array {
        $date = $this->editableDate($dateValue);
        $normalizedShifts = $this->validateShifts($date, $mode, $shifts);

        $this->materializer->materializeTrainer($trainer, $date, $date);

        $parent = DB::transaction(function () use (
            $trainer,
            $userId,
            $date,
            $mode,
            $expectedLockVersion,
            $normalizedShifts
        ): TrainerScheduleDate {
            $lockedTrainer = TrainerProfile::query()->lockForUpdate()->findOrFail($trainer->id);
            $parent = TrainerScheduleDate::query()
                ->where('trainer_profile_id', $lockedTrainer->id)
                ->whereDate('schedule_date', $date->toDateString())
                ->lockForUpdate()
                ->firstOrFail();

            $this->assertLockVersion($parent, $expectedLockVersion);
            $this->assertBlockingBookingsStillFit($lockedTrainer->id, $date, $normalizedShifts);

            $parent->update([
                'state' => $mode === 'closed' ? 'closed' : 'open',
                'source' => 'manual',
                'template_version' => null,
                'template_fingerprint' => null,
                'operation_fingerprint' => null,
                'generated_at' => null,
                'overridden_at' => now(),
                'overridden_by_user_id' => $userId,
                'override_reason' => $mode,
                'lock_version' => $parent->lock_version + 1,
            ]);
            $parent->shifts()->delete();
            if ($normalizedShifts !== []) {
                $parent->shifts()->createMany($normalizedShifts);
            }

            return $parent->load(['shifts' => fn ($query) => $query->orderBy('start_time')]);
        }, 3);

        return $this->normalize($parent, $this->templatesForDate($trainer, $date));
    }

    public function reset(TrainerProfile $trainer, string $dateValue, int $expectedLockVersion): array
    {
        $date = $this->editableDate($dateValue);
        $this->materializer->materializeTrainer($trainer, $date, $date);
        $parent = $this->materializer->resetDateToTemplate($trainer, $date, $expectedLockVersion);

        return $this->normalize($parent, $this->templatesForDate($trainer, $date));
    }

    private function editableDate(string $value): CarbonImmutable
    {
        try {
            $date = CarbonImmutable::createFromFormat('!Y-m-d', $value, TrainerScheduleMaterializer::TIMEZONE);
        } catch (\Throwable) {
            throw new BookingScheduleException('Tanggal jadwal tidak valid.');
        }

        if ($date->format('Y-m-d') !== $value) {
            throw new BookingScheduleException('Tanggal jadwal tidak valid.');
        }

        $today = CarbonImmutable::now(TrainerScheduleMaterializer::TIMEZONE)->startOfDay();
        $editableUntil = $today->addMonthNoOverflow()->endOfMonth()->startOfDay();
        if ($date->lessThan($today) || $date->greaterThan($editableUntil)) {
            throw new BookingScheduleException(
                "Tanggal jadwal harus antara {$today->toDateString()} dan {$editableUntil->toDateString()}."
            );
        }

        return $date;
    }

    private function validateShifts(CarbonImmutable $date, string $mode, array $shifts): array
    {
        if ($mode === 'closed') {
            if ($shifts !== []) {
                throw new BookingScheduleException('Jadwal closed tidak boleh memiliki shift.');
            }

            return [];
        }
        if ($shifts === []) {
            throw new BookingScheduleException('Jadwal override harus memiliki minimal satu shift.');
        }

        $operation = GymOperationHour::query()->where('day_order', $date->dayOfWeekIso)->first();
        if (! $operation || $operation->is_closed || ! $operation->open_time || ! $operation->close_time) {
            throw new BookingScheduleException('Jadwal tidak dapat dibuka saat gym tutup atau jam operasional belum tersedia.');
        }

        $normalized = [];
        foreach ($shifts as $shift) {
            [$startHour, $startMinute] = array_map('intval', explode(':', $shift['start_time']));
            [$endHour, $endMinute] = array_map('intval', explode(':', $shift['end_time']));
            $start = $startHour * 60 + $startMinute;
            $end = $endHour * 60 + $endMinute;

            if ($startMinute % 30 !== 0 || $endMinute % 30 !== 0) {
                throw new BookingScheduleException('Jam shift harus berada pada batas 30 menit.');
            }
            if ($end <= $start) {
                throw new BookingScheduleException('Jam selesai shift harus setelah jam mulai.');
            }
            if ($operation->open_time > $shift['start_time'].':00'
                || $operation->close_time < $shift['end_time'].':00') {
                throw new BookingScheduleException('Shift harus berada dalam jam operasional gym.');
            }

            $normalized[] = [
                'source_trainer_schedule_id' => null,
                'source_template_key' => null,
                'start_time' => $shift['start_time'].':00',
                'end_time' => $shift['end_time'].':00',
                'session_duration_minutes' => $end - $start,
                '_start_minutes' => $start,
                '_end_minutes' => $end,
            ];
        }

        usort($normalized, fn (array $left, array $right) => $left['_start_minutes'] <=> $right['_start_minutes']);
        for ($index = 1; $index < count($normalized); $index++) {
            if ($normalized[$index]['_start_minutes'] < $normalized[$index - 1]['_end_minutes']) {
                throw new BookingScheduleException('Shift pada tanggal yang sama tidak boleh tumpang tindih.');
            }
        }

        return array_map(function (array $shift): array {
            unset($shift['_start_minutes'], $shift['_end_minutes']);

            return $shift;
        }, $normalized);
    }

    private function assertLockVersion(TrainerScheduleDate $parent, int $expected): void
    {
        if ($parent->lock_version !== $expected) {
            throw new BookingScheduleException('Jadwal telah diperbarui. Muat ulang data sebelum mencoba lagi.', 409);
        }
    }

    private function assertBlockingBookingsStillFit(int $trainerId, CarbonImmutable $date, array $shifts): void
    {
        foreach ($this->blockingIntervals($trainerId, $date, true) as $blocker) {
            $fits = collect($shifts)->contains(fn (array $shift) => $this->shiftContains(
                $shift['start_time'],
                $shift['end_time'],
                $blocker['start_time'],
                $blocker['end_time']
            ));
            if (! $fits) {
                throw new BookingScheduleException(
                    "Shift {$blocker['start_time']}-{$blocker['end_time']} tidak dapat diubah karena sudah memiliki {$blocker['label']}.",
                    409
                );
            }
        }
    }

    private function templatesForDate(TrainerProfile $trainer, CarbonImmutable $date): Collection
    {
        return $trainer->schedules()
            ->where('day_of_week', $date->dayOfWeekIso)
            ->orderBy('start_time')
            ->get();
    }

    private function normalize(TrainerScheduleDate $date, Collection $templates): array
    {
        $day = $date->schedule_date->dayOfWeekIso;
        $blockers = $this->blockingIntervals(
            (int) $date->trainer_profile_id,
            CarbonImmutable::parse(
                $date->schedule_date->toDateString(),
                TrainerScheduleMaterializer::TIMEZONE
            ),
            false
        );
        $templateIntervals = $templates->map(fn ($shift) => [
            'start_time' => substr((string) $shift->start_time, 0, 8),
            'end_time' => substr((string) $shift->end_time, 0, 8),
        ]);

        return [
            'date' => $date->schedule_date->toDateString(),
            'day_of_week' => $day,
            'day_name' => self::DAY_NAMES[$day],
            'state' => $date->state,
            'source' => $date->source,
            'lock_version' => $date->lock_version,
            'has_blockers' => $blockers->isNotEmpty(),
            'can_close' => $blockers->isEmpty(),
            'can_reset' => $blockers->every(fn (array $blocker) => $templateIntervals
                ->contains(fn (array $shift) => $this->shiftContains(
                    $shift['start_time'], $shift['end_time'],
                    $blocker['start_time'], $blocker['end_time']
                ))),
            'shifts' => $date->shifts->map(function ($shift) use ($blockers): array {
                $protected = $blockers->filter(fn (array $blocker) => $this->shiftContains(
                    (string) $shift->start_time,
                    (string) $shift->end_time,
                    $blocker['start_time'],
                    $blocker['end_time']
                ));

                return [
                    'start_time' => substr((string) $shift->start_time, 0, 5),
                    'end_time' => substr((string) $shift->end_time, 0, 5),
                    'session_duration_minutes' => $this->durationMinutes($shift->start_time, $shift->end_time),
                    'is_locked' => $protected->isNotEmpty(),
                    'blocking_count' => $protected->count(),
                    'blocking_types' => $protected->pluck('type')->unique()->values(),
                ];
            })->values(),
            'template_shifts' => $templates->map(fn ($shift) => [
                'start_time' => substr((string) $shift->start_time, 0, 5),
                'end_time' => substr((string) $shift->end_time, 0, 5),
                'session_duration_minutes' => $this->durationMinutes($shift->start_time, $shift->end_time),
            ])->values(),
        ];
    }

    private function blockingIntervals(
        int $trainerId,
        CarbonImmutable $date,
        bool $lockForUpdate
    ): Collection {
        $bookings = Booking::query()
            ->where('trainer_profile_id', $trainerId)
            ->whereDate('session_date', $date->toDateString())
            ->whereIn('status', Booking::SCHEDULE_BLOCKING_STATUSES)
            ->whereDoesntHave('sessionReservations');
        $reservations = BookingSessionReservation::query()
            ->where('trainer_profile_id', $trainerId)
            ->whereDate('session_date', $date->toDateString())
            ->whereIn('status', BookingSessionReservation::SCHEDULE_BLOCKING_STATUSES)
            ->whereHas('booking', fn ($query) => $query
                ->whereIn('status', Booking::SCHEDULE_BLOCKING_STATUSES));
        $holds = BookingRescheduleRequest::query()
            ->where('trainer_profile_id', $trainerId)
            ->whereDate('proposed_session_date', $date->toDateString())
            ->where('status', BookingRescheduleRequest::STATUS_PENDING)
            ->where('expired_at', '>', now());
        if ($lockForUpdate) {
            $bookings->lockForUpdate();
            $reservations->lockForUpdate();
            $holds->lockForUpdate();
        }

        return $bookings->get()->map(fn (Booking $booking) => [
            'type' => 'legacy_booking',
            'label' => 'booking aktif',
            'start_time' => substr((string) $booking->start_time, 0, 8),
            'end_time' => substr((string) $booking->end_time, 0, 8),
        ])->concat($reservations->get()->map(fn (BookingSessionReservation $reservation) => [
            'type' => 'reservation',
            'label' => 'reservation aktif',
            'start_time' => substr((string) $reservation->start_time, 0, 8),
            'end_time' => substr((string) $reservation->end_time, 0, 8),
        ]))->concat($holds->get()->map(fn (BookingRescheduleRequest $hold) => [
            'type' => 'reschedule_hold',
            'label' => 'hold reschedule aktif',
            'start_time' => substr((string) $hold->proposed_start_time, 0, 8),
            'end_time' => substr((string) $hold->proposed_end_time, 0, 8),
        ]))->values();
    }

    private function shiftContains(
        string $shiftStart,
        string $shiftEnd,
        string $blockedStart,
        string $blockedEnd
    ): bool {
        return substr($shiftStart, 0, 8) <= substr($blockedStart, 0, 8)
            && substr($shiftEnd, 0, 8) >= substr($blockedEnd, 0, 8);
    }

    private function durationMinutes(string $start, string $end): int
    {
        $startParts = array_map('intval', explode(':', $start));
        $endParts = array_map('intval', explode(':', $end));

        return ($endParts[0] * 60 + $endParts[1]) - ($startParts[0] * 60 + $startParts[1]);
    }
}

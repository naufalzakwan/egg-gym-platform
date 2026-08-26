<?php

namespace App\Services;

use App\Exceptions\BookingScheduleException;
use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\BookingRescheduleRequest;
use App\Models\GymOperationHour;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use App\Models\TrainerScheduleDateShift;
use App\Services\Booking\BookingRequestExpiryService;
use Carbon\CarbonImmutable;

class TrainerAvailabilityService
{
    public const TIMEZONE = 'Asia/Jakarta';

    public const HORIZON_DAYS = 30;

    public const BUFFER_MINUTES = 15;

    public const LEAD_MINUTES = 120;

    public function __construct(
        private readonly TrainerScheduleMaterializer $materializer,
        private readonly BookingRequestExpiryService $expiryService
    ) {}

    public function availability(
        TrainerProfile $trainer,
        ?int $excludeReservationId = null
    ): array
    {
        $this->expiryService->expirePendingBookings();
        BookingRescheduleRequest::query()->where('status', 'pending')
            ->where('expired_at', '<=', now())
            ->update(['status' => 'expired', 'active_reservation_id' => null]);
        $trainer->loadMissing('user');
        $now = CarbonImmutable::now(self::TIMEZONE);
        $endDate = $now->addDays(self::HORIZON_DAYS - 1)->startOfDay();
        $this->materializer->materializeTrainer($trainer, $now->startOfDay(), $endDate);
        $operations = GymOperationHour::query()->get()->keyBy('day_order');
        $concreteDates = $trainer->scheduleDates()
            ->with(['shifts' => fn ($query) => $query->orderBy('start_time')])
            ->whereBetween('schedule_date', [$now->toDateString(), $endDate->toDateString()])
            ->orderBy('schedule_date')
            ->get()
            ->keyBy(fn (TrainerScheduleDate $date) => $date->schedule_date->toDateString());
        $legacyBookings = Booking::query()
            ->where('trainer_profile_id', $trainer->id)
            ->whereIn('status', Booking::SCHEDULE_BLOCKING_STATUSES)
            ->whereDoesntHave('sessionReservations')
            ->whereBetween('session_date', [
                $now->toDateString(),
                $now->addDays(self::HORIZON_DAYS - 1)->toDateString(),
            ])
            ->get()
            ->groupBy(fn (Booking $booking) => $booking->session_date->toDateString());
        $reservations = BookingSessionReservation::query()
            ->where('trainer_profile_id', $trainer->id)
            ->whereIn('status', BookingSessionReservation::SCHEDULE_BLOCKING_STATUSES)
            ->whereHas('booking', fn ($query) => $query
                ->whereIn('status', Booking::SCHEDULE_BLOCKING_STATUSES))
            ->when($excludeReservationId !== null, fn ($query) => $query
                ->where('id', '!=', $excludeReservationId))
            ->whereBetween('session_date', [
                $now->toDateString(),
                $now->addDays(self::HORIZON_DAYS - 1)->toDateString(),
            ])
            ->get()
            ->groupBy(fn (BookingSessionReservation $reservation) => $reservation->session_date->toDateString());
        $rescheduleHolds = BookingRescheduleRequest::query()
            ->where('trainer_profile_id', $trainer->id)
            ->where('status', 'pending')
            ->where('expired_at', '>', $now)
            ->whereBetween('proposed_session_date', [
                $now->toDateString(), $endDate->toDateString(),
            ])->get()
            ->map(fn ($hold) => (object) [
                'session_date' => $hold->proposed_session_date,
                'start_time' => $hold->proposed_start_time,
                'end_time' => $hold->proposed_end_time,
            ])->groupBy(fn ($hold) => $hold->session_date->toDateString());

        $weekdays = collect(range(1, 7))->mapWithKeys(fn (int $day) => [
            $day => [
                'day_of_week' => $day,
                'day_name' => CarbonImmutable::now(self::TIMEZONE)
                    ->startOfWeek()
                    ->addDays($day - 1)
                    ->format('l'),
                'schedule_enabled' => $concreteDates->contains(
                    fn (TrainerScheduleDate $date) => $date->schedule_date->dayOfWeekIso === $day && $date->state === 'open'
                ),
                'occurrences' => [],
            ],
        ])->all();

        for ($offset = 0; $offset < self::HORIZON_DAYS; $offset++) {
            $date = $now->startOfDay()->addDays($offset);
            $day = $date->dayOfWeekIso;
            $concreteDate = $concreteDates->get($date->toDateString());
            $operation = $operations->get($day);
            if (! $concreteDate || $concreteDate->state !== 'open'
                || ! $operation || $operation->is_closed
                || ! $operation->open_time || ! $operation->close_time) {
                continue;
            }

            $slots = [];
            $effectiveShifts = [];
            foreach ($concreteDate->shifts as $shift) {
                $windowStart = max(
                    substr($shift->start_time, 0, 8),
                    substr($operation->open_time, 0, 8)
                );
                $windowEnd = min(
                    substr($shift->end_time, 0, 8),
                    substr($operation->close_time, 0, 8)
                );
                $candidate = $this->atTime($date, $windowStart);
                $windowEndAt = $this->atTime($date, $windowEnd);
                $duration = $candidate->diffInMinutes($windowEndAt);
                $shiftSlotKeys = [];

                // Past/lead-time shifts remain omitted. A collision is exposed as
                // one disabled shift interval without booking details.
                if ($candidate->greaterThanOrEqualTo($now->addMinutes(self::LEAD_MINUTES))) {
                    $isBooked = $this->isBlocked(
                        $candidate,
                        $windowEndAt,
                        $legacyBookings->get($date->toDateString(), collect())
                            ->concat($reservations->get($date->toDateString(), collect()))
                            ->concat($rescheduleHolds->get($date->toDateString(), collect()))
                    );
                    $slotKey = $date->format('Y-m-d').'_'.$candidate->format('H:i:s');
                    $slots[$candidate->format('H:i:s')] = [
                        'key' => $slotKey,
                        'start_time' => $candidate->format('H:i:s'),
                        'end_time' => $windowEndAt->format('H:i:s'),
                        'shift_start_time' => substr($shift->start_time, 0, 8),
                        'shift_end_time' => substr($shift->end_time, 0, 8),
                        'session_duration_minutes' => $duration,
                        'location' => 'Studio A',
                        'is_available' => ! $isBooked,
                        'unavailable_reason' => $isBooked ? 'booked' : null,
                    ];
                    $shiftSlotKeys[] = $slotKey;
                }

                $effectiveShifts[] = [
                    'start_time' => $windowStart,
                    'end_time' => $windowEnd,
                    'session_duration_minutes' => $duration,
                    'slot_count' => count($shiftSlotKeys),
                    'slot_keys' => $shiftSlotKeys,
                ];
            }

            // Concrete date open selalu diekspos, meskipun seluruh candidate
            // gugur lead-time/shift terlalu pendek atau semuanya booked.
            ksort($slots);
            $weekdays[$day]['occurrences'][] = [
                'date' => $date->toDateString(),
                'effective_shifts' => $effectiveShifts,
                'slots' => array_values($slots),
            ];
        }

        return [
            'trainer_profile_id' => $trainer->id,
            'timezone' => self::TIMEZONE,
            'current_server_date' => $now->toDateString(),
            'month_end_date' => $now->endOfMonth()->toDateString(),
            'horizon_days' => self::HORIZON_DAYS,
            'session_duration_minutes' => null,
            'slot_policy' => 'shift_interval',
            'buffer_minutes' => self::BUFFER_MINUTES,
            'lead_time_minutes' => self::LEAD_MINUTES,
            'weekdays' => array_values($weekdays),
        ];
    }

    public function assertWithinSchedulePolicy(
        TrainerProfile $trainer,
        CarbonImmutable $start,
        CarbonImmutable $end
    ): array {
        return $this->assertWithinConcreteSchedule($trainer, $start, $end, true);
    }

    /**
     * Validate a historical booking against current date/containment policy while
     * preserving the duration captured when the booking was created.
     *
     * @return array{date: TrainerScheduleDate, shift: TrainerScheduleDateShift}
     */
    public function assertWithinGrandfatheredSchedulePolicy(
        TrainerProfile $trainer,
        CarbonImmutable $start,
        CarbonImmutable $end
    ): array {
        return $this->assertWithinConcreteSchedule($trainer, $start, $end, false);
    }

    /** @return array{date: TrainerScheduleDate, shift: TrainerScheduleDateShift} */
    private function assertWithinConcreteSchedule(
        TrainerProfile $trainer,
        CarbonImmutable $start,
        CarbonImmutable $end,
        bool $requireShiftDuration
    ): array {
        if ($start->lessThan(CarbonImmutable::now(self::TIMEZONE)->addMinutes(self::LEAD_MINUTES))) {
            throw new BookingScheduleException('Booking harus dibuat minimal 2 jam sebelum sesi.');
        }
        if ($start->startOfDay()->greaterThan(
            CarbonImmutable::now(self::TIMEZONE)->startOfDay()->addDays(self::HORIZON_DAYS - 1)
        )) {
            throw new BookingScheduleException('Booking hanya dapat dibuat maksimal 30 hari ke depan.');
        }

        $this->materializer->materializeTrainer($trainer, $start->startOfDay(), $start->startOfDay());
        $concreteDate = TrainerScheduleDate::query()
            ->with('shifts')
            ->where('trainer_profile_id', $trainer->id)
            ->whereDate('schedule_date', $start->toDateString())
            ->lockForUpdate()
            ->first();
        if (! $concreteDate || $concreteDate->state !== 'open') {
            throw new BookingScheduleException('Trainer tidak memiliki jadwal aktif pada tanggal tersebut.');
        }

        $operation = GymOperationHour::query()->where('day_order', $start->dayOfWeekIso)->first();
        if (! $operation || $operation->is_closed || ! $operation->open_time || ! $operation->close_time) {
            throw new BookingScheduleException('Gym tutup atau jam operasional belum tersedia pada hari tersebut.');
        }

        $startTime = $start->format('H:i:s');
        $endTime = $end->format('H:i:s');
        $withinOperation = $startTime >= $operation->open_time && $endTime <= $operation->close_time;
        $shift = $concreteDate->shifts->first(fn ($shift) => $requireShiftDuration
            ? $shift->start_time === $startTime && $shift->end_time === $endTime
            : $shift->start_time <= $startTime && $shift->end_time >= $endTime);

        if (! $withinOperation || ! $shift) {
            throw new BookingScheduleException('Jadwal sesi harus berada dalam shift trainer dan jam operasional gym.');
        }

        return ['date' => $concreteDate, 'shift' => $shift];
    }

    private function isBlocked(CarbonImmutable $start, CarbonImmutable $end, iterable $bookings): bool
    {
        foreach ($bookings as $booking) {
            $bookedStart = $this->atTime($start, (string) $booking->start_time);
            $bookedEnd = $this->atTime($start, (string) $booking->end_time);
            if ($bookedStart->lessThan($end->addMinutes(self::BUFFER_MINUTES))
                && $bookedEnd->greaterThan($start->subMinutes(self::BUFFER_MINUTES))) {
                return true;
            }
        }

        return false;
    }

    private function atTime(CarbonImmutable $date, string $time): CarbonImmutable
    {
        return CarbonImmutable::createFromFormat(
            'Y-m-d H:i:s',
            $date->toDateString().' '.substr($time, 0, 8),
            self::TIMEZONE
        );
    }
}

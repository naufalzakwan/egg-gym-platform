<?php

namespace App\Services\Booking;

use App\Exceptions\BookingScheduleException;
use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\BookingRescheduleRequest;
use App\Models\TrainerProfile;
use App\Services\TrainerAvailabilityService;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

class BookingScheduleService
{
    public const TIMEZONE = 'Asia/Jakarta';

    public const BUFFER_MINUTES = 15;

    public function __construct(
        private readonly TrainerAvailabilityService $availabilityService,
        private readonly BookingSessionReservationPlanner $reservationPlanner,
        private readonly BookingRequestExpiryService $expiryService
    ) {}

    public function create(array $attributes): Booking
    {
        $sessionCount = max(1, (int) ($attributes['session_count'] ?? 1));
        $manualReservations = $attributes['reservations'] ?? [];
        if ($manualReservations === [] && $sessionCount === 1
            && isset($attributes['session_date'], $attributes['start_time'], $attributes['end_time'])) {
            $manualReservations = [[
                'session_date' => $attributes['session_date'],
                'start_time' => $attributes['start_time'],
                'end_time' => $attributes['end_time'],
            ]];
        }
        $this->reservationPlanner->assertManualSelectionShape(
            $manualReservations,
            $sessionCount
        );
        $trainer = TrainerProfile::query()->with('user')->find((int) $attributes['trainer_profile_id']);
        if (! $trainer || $trainer->user?->status !== 'active') {
            throw new BookingScheduleException('Trainer tidak aktif atau tidak ditemukan.');
        }
        $this->reservationPlanner->prepareSchedule($trainer);

        return DB::transaction(function () use ($attributes, $manualReservations, $sessionCount) {
            $trainer = $this->lockActiveTrainer((int) $attributes['trainer_profile_id']);
            $pricePerSession = $trainer->price_per_session !== null
                ? (float) $trainer->price_per_session
                : null;
            if ($pricePerSession === null || $pricePerSession <= 0) {
                throw new BookingScheduleException(
                    'Trainer belum mengatur harga per sesi.',
                    422
                );
            }
            $occurrences = [];
            foreach (array_values($manualReservations) as $index => $manual) {
                [$occurrenceStart, $occurrenceEnd] = $this->parseFutureInterval(
                    $manual['session_date'],
                    $manual['start_time'],
                    $manual['end_time']
                );
                $policy = $this->availabilityService->assertWithinSchedulePolicy(
                    $trainer,
                    $occurrenceStart,
                    $occurrenceEnd
                );
                $this->assertNoCollision($trainer->id, $occurrenceStart, $occurrenceEnd);
                $occurrences[] = [
                    'sequence_order' => $index + 1,
                    'trainer_schedule_date_id' => (int) $policy['date']->id,
                    'session_date' => $occurrenceStart->toDateString(),
                    'start_time' => $occurrenceStart->format('H:i:s'),
                    'end_time' => $occurrenceEnd->format('H:i:s'),
                    'session_duration_minutes' => $occurrenceStart->diffInMinutes($occurrenceEnd),
                ];
            }

            $first = $occurrences[0];
            $parentAttributes = $attributes;
            unset($parentAttributes['reservations']);
            $initialStatus = (string) ($parentAttributes['status'] ?? 'pending');
            $booking = Booking::create(array_merge($parentAttributes, [
                'session_count' => $sessionCount,
                'expired_at' => $this->expiryService->resolveExpiryTimestamp(
                    $initialStatus,
                    firstSessionStart: $this->atOccurrence(
                        $first['session_date'],
                        $first['start_time']
                    )
                ),
                'price_per_session_snapshot' => $pricePerSession,
                'total_amount_snapshot' => $pricePerSession * $sessionCount,
                'session_date' => $first['session_date'],
                'start_time' => $first['start_time'],
                'end_time' => $first['end_time'],
                'trainer_schedule_date_id' => $first['trainer_schedule_date_id'],
                'session_duration_minutes' => $first['session_duration_minutes'],
            ]));

            $booking->sessionReservations()->createMany(array_map(
                fn (array $occurrence) => array_merge($occurrence, [
                    'trainer_profile_id' => $trainer->id,
                    'member_profile_id' => (int) $attributes['member_profile_id'],
                    'status' => BookingSessionReservation::STATUS_RESERVED,
                ]),
                $occurrences
            ));

            return $booking->refresh()->load('sessionReservations');
        }, 3);
    }

    public function reschedule(
        Booking $booking,
        array $validated,
        array $allowedStatuses,
        string $noteColumn,
        ?int $expectedMemberProfileId = null,
        ?int $expectedTrainerProfileId = null
    ): Booking {
        [$start, $end] = $this->parseFutureInterval(
            $validated['new_session_date'],
            $validated['new_start_time'],
            $validated['new_end_time']
        );

        return DB::transaction(function () use (
            $booking,
            $validated,
            $allowedStatuses,
            $noteColumn,
            $expectedMemberProfileId,
            $expectedTrainerProfileId,
            $start,
            $end
        ) {
            $locked = Booking::query()->lockForUpdate()->findOrFail($booking->id);
            if ($expectedMemberProfileId !== null
                && (int) $locked->member_profile_id !== $expectedMemberProfileId) {
                throw new BookingScheduleException('Booking tidak ditemukan untuk member ini.', 404);
            }
            if ($expectedTrainerProfileId !== null
                && (int) $locked->trainer_profile_id !== $expectedTrainerProfileId) {
                throw new BookingScheduleException('Sesi tidak ditemukan untuk trainer ini.', 404);
            }
            if (! in_array($locked->status, $allowedStatuses, true)) {
                throw new BookingScheduleException('Booking dengan status ini tidak dapat di-reschedule.');
            }

            $reservationCount = $locked->sessionReservations()->count();
            if ($reservationCount > 1) {
                throw new BookingScheduleException(
                    'Booking multi-sesi harus di-reschedule per occurrence.',
                    422
                );
            }

            $trainer = $this->lockActiveTrainer((int) $locked->trainer_profile_id);
            $policy = $this->availabilityService->assertWithinSchedulePolicy($trainer, $start, $end);
            $this->assertNoCollision($trainer->id, $start, $end, $locked->id);

            $reason = 'Reschedule reason: '.$validated['reason'];
            $locked->update([
                'session_date' => $validated['new_session_date'],
                'start_time' => $validated['new_start_time'],
                'end_time' => $validated['new_end_time'],
                'status' => 'rescheduled',
                'trainer_schedule_date_id' => $policy['date']->id,
                'session_duration_minutes' => $start->diffInMinutes($end),
                $noteColumn => $locked->{$noteColumn}
                    ? $locked->{$noteColumn}.' | '.$reason
                    : $reason,
            ]);

            if ($reservationCount === 1) {
                $locked->sessionReservations()->update([
                    'trainer_schedule_date_id' => $policy['date']->id,
                    'session_date' => $validated['new_session_date'],
                    'start_time' => $validated['new_start_time'],
                    'end_time' => $validated['new_end_time'],
                    'session_duration_minutes' => $start->diffInMinutes($end),
                ]);
            }

            return $locked->refresh();
        }, 3);
    }

    public function reassign(Booking $booking, int $trainerProfileId): Booking
    {
        return DB::transaction(function () use ($booking, $trainerProfileId) {
            $locked = Booking::query()->lockForUpdate()->findOrFail($booking->id);

            if (in_array($locked->status, ['completed', 'cancelled', 'expired'], true)) {
                throw new BookingScheduleException('Booking final tidak bisa dipindah ke PT lain.');
            }
            if ((int) $locked->trainer_profile_id === $trainerProfileId) {
                throw new BookingScheduleException('Booking sudah menggunakan trainer tersebut.');
            }
            $reservationCount = $locked->sessionReservations()->count();
            if ($reservationCount > 1) {
                throw new BookingScheduleException(
                    'Booking multi-sesi harus dipindahkan per occurrence.',
                    422
                );
            }

            $trainer = $this->lockActiveTrainer($trainerProfileId);
            [$start, $end] = $this->parseFutureInterval(
                $locked->session_date?->toDateString(),
                (string) $locked->start_time,
                (string) $locked->end_time
            );

            $policy = $this->availabilityService->assertWithinSchedulePolicy($trainer, $start, $end);
            if (Booking::blocksSchedule($locked->status)) {
                $this->assertNoCollision($trainer->id, $start, $end, $locked->id);
            }

            $locked->update([
                'trainer_profile_id' => $trainer->id,
                'trainer_schedule_date_id' => $policy['date']->id,
            ]);
            if ($reservationCount === 1) {
                $locked->sessionReservations()->update([
                    'trainer_profile_id' => $trainer->id,
                    'trainer_schedule_date_id' => $policy['date']->id,
                ]);
            }

            return $locked->refresh()->load('trainerProfile.user');
        }, 3);
    }

    public function rescheduleReservation(
        Booking $booking,
        BookingSessionReservation $reservation,
        array $validated,
        ?int $expectedMemberProfileId = null,
        ?int $expectedTrainerProfileId = null
    ): Booking {
        [$start, $end] = $this->parseFutureInterval(
            $validated['new_session_date'],
            $validated['new_start_time'],
            $validated['new_end_time']
        );

        return DB::transaction(function () use (
            $booking,
            $reservation,
            $validated,
            $expectedMemberProfileId,
            $expectedTrainerProfileId,
            $start,
            $end
        ) {
            $lockedBooking = Booking::query()->lockForUpdate()->findOrFail($booking->id);
            $lockedReservation = BookingSessionReservation::query()
                ->whereKey($reservation->id)
                ->where('booking_id', $lockedBooking->id)
                ->lockForUpdate()
                ->first();
            if (! $lockedReservation) {
                throw new BookingScheduleException('Reservation tidak ditemukan untuk booking ini.', 404);
            }
            if ($expectedMemberProfileId !== null
                && (int) $lockedBooking->member_profile_id !== $expectedMemberProfileId) {
                throw new BookingScheduleException('Reservation tidak ditemukan untuk member ini.', 404);
            }
            if ($expectedTrainerProfileId !== null
                && (int) $lockedBooking->trainer_profile_id !== $expectedTrainerProfileId) {
                throw new BookingScheduleException('Reservation tidak ditemukan untuk trainer ini.', 404);
            }
            if ($lockedBooking->sessionReservations()->exists()) {
                throw new BookingScheduleException(
                    'Booking baru wajib menggunakan approval reschedule request.', 422
                );
            }
            if ($lockedReservation->status !== BookingSessionReservation::STATUS_RESERVED) {
                throw new BookingScheduleException('Hanya reservation aktif yang dapat di-reschedule.');
            }
            if (! Booking::blocksSchedule($lockedBooking->status)) {
                throw new BookingScheduleException('Booking dengan status ini tidak dapat di-reschedule.');
            }

            $oldStart = $this->atOccurrence(
                $lockedReservation->session_date->toDateString(),
                (string) $lockedReservation->start_time
            );
            if (! $start->greaterThan($oldStart)) {
                throw new BookingScheduleException(
                    'Jadwal baru harus lebih maju dari jadwal sesi saat ini.',
                    422
                );
            }
            if (BookingSessionReservation::query()
                ->where('booking_id', $lockedBooking->id)
                ->where('id', '!=', $lockedReservation->id)
                ->whereDate('session_date', $start->toDateString())
                ->lockForUpdate()
                ->exists()) {
                throw new BookingScheduleException(
                    'Tanggal tersebut sudah dipakai sesi lain dalam booking ini.',
                    422
                );
            }

            $trainer = $this->lockActiveTrainer((int) $lockedBooking->trainer_profile_id);
            $policy = $this->availabilityService->assertWithinSchedulePolicy($trainer, $start, $end);
            $this->assertNoCollision(
                $trainer->id,
                $start,
                $end,
                null,
                $lockedReservation->id
            );

            $lockedReservation->update([
                'trainer_schedule_date_id' => $policy['date']->id,
                'session_date' => $validated['new_session_date'],
                'start_time' => $validated['new_start_time'],
                'end_time' => $validated['new_end_time'],
                'session_duration_minutes' => $start->diffInMinutes($end),
            ]);
            if ((int) $lockedReservation->sequence_order === 1) {
                $lockedBooking->update([
                    'trainer_schedule_date_id' => $policy['date']->id,
                    'session_date' => $validated['new_session_date'],
                    'start_time' => $validated['new_start_time'],
                    'end_time' => $validated['new_end_time'],
                    'session_duration_minutes' => $start->diffInMinutes($end),
                ]);
            }

            return $lockedBooking->refresh()->load('sessionReservations');
        }, 3);
    }

    public function cancelBookingReservations(Booking $booking): Booking
    {
        return DB::transaction(function () use ($booking) {
            $locked = Booking::query()->lockForUpdate()->findOrFail($booking->id);
            $locked->sessionReservations()
                ->where('status', BookingSessionReservation::STATUS_RESERVED)
                ->lockForUpdate()
                ->get()
                ->each->update([
                    'status' => BookingSessionReservation::STATUS_CANCELLED,
                ]);
            $locked->update(['status' => 'cancelled']);
            $locked->update(['expired_at' => null]);

            return $locked->refresh()->load('sessionReservations');
        });
    }

    /**
     * Guard a transition from a non-blocking status back to a blocking status.
     */
    public function transitionToBlocking(
        Booking $booking,
        array $updates,
        array $allowedSourceStatuses
    ): Booking {
        return DB::transaction(function () use ($booking, $updates, $allowedSourceStatuses) {
            $locked = Booking::query()->lockForUpdate()->findOrFail($booking->id);
            if (! in_array($locked->status, $allowedSourceStatuses, true)) {
                throw new BookingScheduleException('Booking tidak dalam status yang dapat diaktifkan kembali.');
            }
            $trainer = $this->lockActiveTrainer((int) $locked->trainer_profile_id);
            $reservations = $locked->sessionReservations()->lockForUpdate()->get();
            if ($reservations->isNotEmpty()) {
                foreach ($reservations as $reservation) {
                    $start = $this->atOccurrence(
                        $reservation->session_date->toDateString(),
                        (string) $reservation->start_time
                    );
                    $end = $this->atOccurrence(
                        $reservation->session_date->toDateString(),
                        (string) $reservation->end_time
                    );
                    $this->availabilityService->assertWithinGrandfatheredSchedulePolicy($trainer, $start, $end);
                    $this->assertNoCollision($trainer->id, $start, $end, $locked->id);
                }
                $locked->update($updates);
            } else {
                [$start, $end] = $this->parseFutureInterval(
                    $locked->session_date?->toDateString(),
                    (string) $locked->start_time,
                    (string) $locked->end_time
                );
                $policy = $this->availabilityService->assertWithinGrandfatheredSchedulePolicy($trainer, $start, $end);
                $this->assertNoCollision($trainer->id, $start, $end, $locked->id);
                $locked->update(array_merge($updates, [
                    'trainer_schedule_date_id' => $policy['date']->id,
                ]));
            }

            return $locked->refresh();
        }, 3);
    }

    private function lockActiveTrainer(int $trainerProfileId): TrainerProfile
    {
        $trainer = TrainerProfile::query()
            ->with('user')
            ->lockForUpdate()
            ->find($trainerProfileId);

        if (! $trainer || $trainer->user?->status !== 'active') {
            throw new BookingScheduleException('Trainer tidak aktif atau tidak ditemukan.');
        }

        return $trainer;
    }

    private function assertNoCollision(
        int $trainerProfileId,
        CarbonImmutable $candidateStart,
        CarbonImmutable $candidateEnd,
        ?int $excludeBookingId = null,
        ?int $excludeReservationId = null
    ): void {
        $bufferedStart = $candidateStart->subMinutes(self::BUFFER_MINUTES);
        $bufferedEnd = $candidateEnd->addMinutes(self::BUFFER_MINUTES);

        $legacyQuery = Booking::query()
            ->where('trainer_profile_id', $trainerProfileId)
            ->whereIn('status', Booking::SCHEDULE_BLOCKING_STATUSES)
            ->whereDoesntHave('sessionReservations')
            ->whereBetween('session_date', [
                $bufferedStart->toDateString(),
                $bufferedEnd->toDateString(),
            ])
            ->whereRaw(
                'TIMESTAMP(session_date, start_time) < ? AND TIMESTAMP(session_date, end_time) > ?',
                [$bufferedEnd->format('Y-m-d H:i:s'), $bufferedStart->format('Y-m-d H:i:s')]
            );

        if ($excludeBookingId !== null) {
            $legacyQuery->where('id', '!=', $excludeBookingId);
        }

        $reservationQuery = BookingSessionReservation::query()
            ->where('trainer_profile_id', $trainerProfileId)
            ->whereIn('status', BookingSessionReservation::SCHEDULE_BLOCKING_STATUSES)
            ->whereHas('booking', function ($query) use ($excludeBookingId) {
                $query->whereIn('status', Booking::SCHEDULE_BLOCKING_STATUSES);
                if ($excludeBookingId !== null) {
                    $query->where('id', '!=', $excludeBookingId);
                }
            })
            ->whereBetween('session_date', [
                $bufferedStart->toDateString(),
                $bufferedEnd->toDateString(),
            ])
            ->whereRaw(
                'TIMESTAMP(session_date, start_time) < ? AND TIMESTAMP(session_date, end_time) > ?',
                [$bufferedEnd->format('Y-m-d H:i:s'), $bufferedStart->format('Y-m-d H:i:s')]
            );
        if ($excludeReservationId !== null) {
            $reservationQuery->where('id', '!=', $excludeReservationId);
        }

        $holdCollision = BookingRescheduleRequest::query()
            ->where('trainer_profile_id', $trainerProfileId)
            ->where('status', 'pending')
            ->where('expired_at', '>', now())
            ->whereBetween('proposed_session_date', [
                $bufferedStart->toDateString(), $bufferedEnd->toDateString(),
            ])->whereRaw(
                'TIMESTAMP(proposed_session_date, proposed_start_time) < ? AND TIMESTAMP(proposed_session_date, proposed_end_time) > ?',
                [$bufferedEnd->format('Y-m-d H:i:s'), $bufferedStart->format('Y-m-d H:i:s')]
            )->lockForUpdate()->exists();

        if ($legacyQuery->lockForUpdate()->value('id') !== null
            || $reservationQuery->lockForUpdate()->value('id') !== null
            || $holdCollision) {
            throw new BookingScheduleException(
                'Jadwal trainer sudah terisi atau terlalu dekat dengan sesi lain. Silakan pilih slot lain.',
                409
            );
        }
    }

    private function atOccurrence(string $date, string $time): CarbonImmutable
    {
        return CarbonImmutable::createFromFormat(
            'Y-m-d H:i:s',
            $date.' '.$time,
            self::TIMEZONE
        );
    }

    /** @return array{CarbonImmutable, CarbonImmutable} */
    private function parseFutureInterval(?string $date, string $startTime, string $endTime): array
    {
        if (! $date) {
            throw new BookingScheduleException('Tanggal sesi tidak valid.');
        }

        try {
            $start = CarbonImmutable::createFromFormat(
                'Y-m-d H:i:s',
                $date.' '.$startTime,
                self::TIMEZONE
            );
            $end = CarbonImmutable::createFromFormat(
                'Y-m-d H:i:s',
                $date.' '.$endTime,
                self::TIMEZONE
            );
        } catch (\Throwable) {
            throw new BookingScheduleException('Tanggal atau jam sesi tidak valid.');
        }

        if ($end->lessThanOrEqualTo($start)) {
            throw new BookingScheduleException('Jam selesai harus setelah jam mulai.');
        }
        if ($start->lessThanOrEqualTo(CarbonImmutable::now(self::TIMEZONE))) {
            throw new BookingScheduleException('Jadwal sesi harus berada di masa mendatang.');
        }

        return [$start, $end];
    }
}

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
use Illuminate\Support\Facades\DB;

class TrainerScheduleMaterializer
{
    public const TIMEZONE = 'Asia/Jakarta';

    /**
     * Materialize every trainer from Jakarta today through the end of next month.
     *
     * @return array{created:int,updated:int,unchanged:int,manual_skipped:int,dates:int}
     */
    public function materializeAll(?CarbonImmutable $now = null): array
    {
        $now ??= CarbonImmutable::now(self::TIMEZONE);
        $start = $now->startOfDay();
        $end = $now->addMonthNoOverflow()->endOfMonth()->startOfDay();
        $totals = $this->emptyResult();

        TrainerProfile::query()->orderBy('id')->chunkById(100, function ($trainers) use (
            $start,
            $end,
            &$totals
        ): void {
            foreach ($trainers as $trainer) {
                $result = $this->materializeTrainer($trainer, $start, $end);
                foreach ($totals as $key => $value) {
                    $totals[$key] = $value + $result[$key];
                }
            }
        });

        return $totals;
    }

    /**
     * @return array{created:int,updated:int,unchanged:int,manual_skipped:int,dates:int}
     */
    public function materializeTrainer(
        TrainerProfile $trainer,
        CarbonImmutable $start,
        CarbonImmutable $end
    ): array {
        if ($end->lessThan($start)) {
            throw new \InvalidArgumentException('Materialization end date must be on or after start date.');
        }

        return DB::transaction(function () use ($trainer, $start, $end): array {
            $lockedTrainer = TrainerProfile::query()->lockForUpdate()->findOrFail($trainer->id);
            $templates = $lockedTrainer->schedules()->orderBy('day_of_week')->orderBy('start_time')->get();
            $operations = GymOperationHour::query()->get()->keyBy('day_order');
            $result = $this->emptyResult();

            for ($date = $start->startOfDay(); $date->lessThanOrEqualTo($end); $date = $date->addDay()) {
                $result['dates']++;
                $parent = TrainerScheduleDate::query()
                    ->where('trainer_profile_id', $lockedTrainer->id)
                    ->whereDate('schedule_date', $date->toDateString())
                    ->lockForUpdate()
                    ->first();

                if ($parent?->source === 'manual') {
                    $result['manual_skipped']++;

                    continue;
                }

                $desired = $this->desiredDate(
                    $date,
                    $templates->where('day_of_week', $date->dayOfWeekIso)->values(),
                    $operations->get($date->dayOfWeekIso),
                    (int) ($lockedTrainer->schedule_template_version ?? 1)
                );

                if ($parent === null) {
                    $this->assertBlockingBookingsStillFit(
                        $lockedTrainer->id,
                        $date,
                        $desired['shifts']
                    );
                    $parent = TrainerScheduleDate::create([
                        'trainer_profile_id' => $lockedTrainer->id,
                        'schedule_date' => $date->toDateString(),
                        'state' => $desired['state'],
                        'source' => 'generated',
                        'template_version' => $desired['template_version'],
                        'template_fingerprint' => $desired['template_fingerprint'],
                        'operation_fingerprint' => $desired['operation_fingerprint'],
                        'generated_at' => now(),
                    ]);
                    $this->syncShifts($parent, $desired['shifts']);
                    $result['created']++;

                    continue;
                }

                $currentShifts = $parent->shifts()
                    ->orderBy('start_time')
                    ->get()
                    ->map(fn ($shift) => [
                        'source_trainer_schedule_id' => $shift->source_trainer_schedule_id,
                        'source_template_key' => $shift->source_template_key,
                        'start_time' => substr((string) $shift->start_time, 0, 8),
                        'end_time' => substr((string) $shift->end_time, 0, 8),
                        'session_duration_minutes' => (int) $shift->session_duration_minutes,
                    ])
                    ->values()
                    ->all();

                $same = $parent->state === $desired['state']
                    && (int) $parent->template_version === $desired['template_version']
                    && $parent->template_fingerprint === $desired['template_fingerprint']
                    && $parent->operation_fingerprint === $desired['operation_fingerprint']
                    && $currentShifts === $desired['shifts'];

                if ($same) {
                    $result['unchanged']++;

                    continue;
                }

                $this->assertBlockingBookingsStillFit($lockedTrainer->id, $date, $desired['shifts']);
                $parent->update([
                    'state' => $desired['state'],
                    'source' => 'generated',
                    'template_version' => $desired['template_version'],
                    'template_fingerprint' => $desired['template_fingerprint'],
                    'operation_fingerprint' => $desired['operation_fingerprint'],
                    'generated_at' => now(),
                    'overridden_at' => null,
                    'overridden_by_user_id' => null,
                    'override_reason' => null,
                ]);
                $this->syncShifts($parent, $desired['shifts']);
                $result['updated']++;
            }

            return $result;
        }, 3);
    }

    public function resetDateToTemplate(
        TrainerProfile $trainer,
        CarbonImmutable $date,
        int $expectedLockVersion
    ): TrainerScheduleDate {
        return DB::transaction(function () use ($trainer, $date, $expectedLockVersion): TrainerScheduleDate {
            $lockedTrainer = TrainerProfile::query()->lockForUpdate()->findOrFail($trainer->id);
            $parent = TrainerScheduleDate::query()
                ->where('trainer_profile_id', $lockedTrainer->id)
                ->whereDate('schedule_date', $date->toDateString())
                ->lockForUpdate()
                ->firstOrFail();

            if ($parent->lock_version !== $expectedLockVersion) {
                throw new BookingScheduleException(
                    'Jadwal telah diperbarui. Muat ulang data sebelum mencoba lagi.',
                    409
                );
            }

            $desired = $this->desiredDate(
                $date,
                $lockedTrainer->schedules()
                    ->where('day_of_week', $date->dayOfWeekIso)
                    ->orderBy('start_time')
                    ->get(),
                GymOperationHour::query()->where('day_order', $date->dayOfWeekIso)->first(),
                (int) ($lockedTrainer->schedule_template_version ?? 1)
            );
            $this->assertBlockingBookingsStillFit($lockedTrainer->id, $date, $desired['shifts']);

            $parent->update([
                'state' => $desired['state'],
                'source' => 'generated',
                'template_version' => $desired['template_version'],
                'template_fingerprint' => $desired['template_fingerprint'],
                'operation_fingerprint' => $desired['operation_fingerprint'],
                'generated_at' => now(),
                'overridden_at' => null,
                'overridden_by_user_id' => null,
                'override_reason' => null,
                'lock_version' => $parent->lock_version + 1,
            ]);
            $this->syncShifts($parent, $desired['shifts']);

            return $parent->load(['shifts' => fn ($query) => $query->orderBy('start_time')]);
        }, 3);
    }

    private function desiredDate(
        CarbonImmutable $date,
        $templates,
        ?GymOperationHour $operation,
        int $templateVersion
    ): array {
        $operationData = $operation ? [
            'day_order' => $operation->day_order,
            'open_time' => $operation->open_time,
            'close_time' => $operation->close_time,
            'is_closed' => (bool) $operation->is_closed,
        ] : ['missing' => true];
        $templateData = $templates->map(fn ($template) => [
            'id' => $template->id,
            'template_key' => $template->template_key,
            'start_time' => substr((string) $template->start_time, 0, 8),
            'end_time' => substr((string) $template->end_time, 0, 8),
            'session_duration_minutes' => $this->durationMinutes(
                (string) $template->start_time,
                (string) $template->end_time
            ),
        ])->values()->all();

        $shifts = [];
        if ($operation && ! $operation->is_closed && $operation->open_time && $operation->close_time) {
            $open = substr((string) $operation->open_time, 0, 8);
            $close = substr((string) $operation->close_time, 0, 8);
            foreach ($templates as $template) {
                $start = max(substr((string) $template->start_time, 0, 8), $open);
                $end = min(substr((string) $template->end_time, 0, 8), $close);
                if ($start < $end) {
                    $shifts[] = [
                        'source_trainer_schedule_id' => $template->id,
                        'source_template_key' => $template->template_key,
                        'start_time' => $start,
                        'end_time' => $end,
                        'session_duration_minutes' => $this->durationMinutes($start, $end),
                    ];
                }
            }
        }

        usort($shifts, fn (array $left, array $right) => $left['start_time'] <=> $right['start_time']);

        return [
            'state' => $shifts === [] ? 'closed' : 'open',
            'template_version' => $templateVersion,
            'template_fingerprint' => hash('sha256', json_encode($templateData, JSON_THROW_ON_ERROR)),
            'operation_fingerprint' => hash('sha256', json_encode($operationData, JSON_THROW_ON_ERROR)),
            'shifts' => $shifts,
        ];
    }

    private function syncShifts(TrainerScheduleDate $parent, array $shifts): void
    {
        $parent->shifts()->delete();
        if ($shifts !== []) {
            $parent->shifts()->createMany($shifts);
        }
    }

    private function assertBlockingBookingsStillFit(
        int $trainerProfileId,
        CarbonImmutable $date,
        array $shifts
    ): void {
        $bookings = Booking::query()
            ->where('trainer_profile_id', $trainerProfileId)
            ->whereDate('session_date', $date->toDateString())
            ->whereIn('status', Booking::SCHEDULE_BLOCKING_STATUSES)
            ->whereDoesntHave('sessionReservations')
            ->lockForUpdate()
            ->get();

        $reservations = BookingSessionReservation::query()
            ->where('trainer_profile_id', $trainerProfileId)
            ->whereDate('session_date', $date->toDateString())
            ->whereIn('status', BookingSessionReservation::SCHEDULE_BLOCKING_STATUSES)
            ->whereHas('booking', fn ($query) => $query
                ->whereIn('status', Booking::SCHEDULE_BLOCKING_STATUSES))
            ->lockForUpdate()
            ->get();

        $holds = BookingRescheduleRequest::query()
            ->where('trainer_profile_id', $trainerProfileId)
            ->whereDate('proposed_session_date', $date->toDateString())
            ->where('status', 'pending')->where('expired_at', '>', now())
            ->lockForUpdate()->get()
            ->map(fn ($hold) => (object) [
                'id' => $hold->id,
                'start_time' => $hold->proposed_start_time,
                'end_time' => $hold->proposed_end_time,
            ]);

        foreach ($bookings->concat($reservations)->concat($holds) as $reservation) {
            $fits = collect($shifts)->contains(fn (array $shift) => $shift['start_time'] <= substr((string) $reservation->start_time, 0, 8)
                && $shift['end_time'] >= substr((string) $reservation->end_time, 0, 8));
            if (! $fits) {
                $reference = $reservation instanceof Booking
                    ? "booking aktif #{$reservation->id}"
                    : "reservasi/hold aktif #{$reservation->id}";
                throw new BookingScheduleException(
                    "Jadwal tanggal {$date->toDateString()} tidak dapat diperbarui karena masih memiliki {$reference}.",
                    409
                );
            }
        }
    }

    private function emptyResult(): array
    {
        return [
            'created' => 0,
            'updated' => 0,
            'unchanged' => 0,
            'manual_skipped' => 0,
            'dates' => 0,
        ];
    }

    private function durationMinutes(string $start, string $end): int
    {
        $startParts = array_map('intval', explode(':', $start));
        $endParts = array_map('intval', explode(':', $end));

        return ($endParts[0] * 60 + $endParts[1]) - ($startParts[0] * 60 + $startParts[1]);
    }
}

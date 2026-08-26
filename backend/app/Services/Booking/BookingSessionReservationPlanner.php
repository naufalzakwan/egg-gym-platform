<?php

namespace App\Services\Booking;

use App\Exceptions\BookingScheduleException;
use App\Models\TrainerProfile;
use App\Services\TrainerAvailabilityService;
use App\Services\TrainerScheduleMaterializer;
use Carbon\CarbonImmutable;

class BookingSessionReservationPlanner
{
    public function __construct(private readonly TrainerScheduleMaterializer $materializer) {}

    public function prepareSchedule(TrainerProfile $trainer): void
    {
        $today = CarbonImmutable::now(BookingScheduleService::TIMEZONE)->startOfDay();
        $this->materializer->materializeTrainer(
            $trainer,
            $today,
            $today->addDays(TrainerAvailabilityService::HORIZON_DAYS - 1)
        );
    }

    /**
     * @return list<array{
     *   sequence_order:int,
     *   trainer_schedule_date_id:int,
     *   session_date:string,
     *   start_time:string,
     *   end_time:string,
     *   session_duration_minutes:int
     * }>
     */
    public function assertManualSelectionShape(array $reservations, int $sessionCount): void
    {
        if (count($reservations) !== $sessionCount) {
            throw new BookingScheduleException(
                'Jumlah jadwal yang dipilih harus sama dengan jumlah sesi.',
                422
            );
        }

        $dates = array_map(
            fn (array $reservation) => $reservation['session_date'],
            $reservations
        );
        if (count(array_unique($dates)) !== count($dates)) {
            throw new BookingScheduleException(
                'Setiap sesi harus menggunakan tanggal yang berbeda.',
                422
            );
        }

        for ($index = 1; $index < count($dates); $index++) {
            if ($dates[$index] <= $dates[$index - 1]) {
                throw new BookingScheduleException(
                    'Tanggal sesi harus berurutan maju sesuai urutan sesi.',
                    422
                );
            }
        }
    }
}

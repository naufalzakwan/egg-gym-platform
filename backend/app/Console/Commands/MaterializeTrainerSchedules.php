<?php

namespace App\Console\Commands;

use App\Models\TrainerProfile;
use App\Services\TrainerScheduleMaterializer;
use Carbon\CarbonImmutable;
use Illuminate\Console\Command;

class MaterializeTrainerSchedules extends Command
{
    protected $signature = 'trainer-schedules:materialize
                            {--trainer= : Trainer profile ID to materialize}
                            {--now= : Jakarta date to use as today (YYYY-MM-DD)}';

    protected $description = 'Materialize trainer schedule dates through the end of next month.';

    public function handle(TrainerScheduleMaterializer $materializer): int
    {
        $now = $this->parseNow();
        if ($now === null) {
            return self::FAILURE;
        }

        $trainerId = $this->option('trainer');
        if ($trainerId === null) {
            $result = $materializer->materializeAll($now);
        } else {
            if (! ctype_digit((string) $trainerId) || (int) $trainerId < 1) {
                $this->error('The --trainer option must be a positive trainer profile ID.');

                return self::FAILURE;
            }

            $trainer = TrainerProfile::query()->find((int) $trainerId);
            if ($trainer === null) {
                $this->error("Trainer profile {$trainerId} was not found.");

                return self::FAILURE;
            }

            $result = $materializer->materializeTrainer(
                $trainer,
                $now->startOfDay(),
                $now->addMonthNoOverflow()->endOfMonth()->startOfDay()
            );
        }

        $this->info(sprintf(
            'created=%d updated=%d unchanged=%d manual_skipped=%d dates=%d',
            $result['created'],
            $result['updated'],
            $result['unchanged'],
            $result['manual_skipped'],
            $result['dates']
        ));

        return self::SUCCESS;
    }

    private function parseNow(): ?CarbonImmutable
    {
        $value = $this->option('now');
        if ($value === null) {
            return CarbonImmutable::now(TrainerScheduleMaterializer::TIMEZONE);
        }

        try {
            $now = CarbonImmutable::createFromFormat(
                '!Y-m-d',
                (string) $value,
                TrainerScheduleMaterializer::TIMEZONE
            );
        } catch (\Throwable) {
            $now = false;
        }

        if ($now === false || $now->format('Y-m-d') !== $value) {
            $this->error('The --now option must be a valid date in YYYY-MM-DD format.');

            return null;
        }

        return $now;
    }
}

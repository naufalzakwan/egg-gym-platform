<?php

namespace App\Http\Controllers\Api\V1\Trainer;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Trainer\UpdateTrainerScheduleRequest;
use App\Models\TrainerProfile;
use App\Services\TrainerScheduleMaterializer;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class TrainerScheduleController extends Controller
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

    public function show(Request $request): JsonResponse
    {
        $trainer = $request->user()->trainerProfile;
        if (! $trainer) {
            return response()->json(['success' => false, 'message' => 'Profil trainer belum tersedia.'], 422);
        }

        return $this->response($trainer->load('schedules'));
    }

    public function update(
        UpdateTrainerScheduleRequest $request,
        TrainerScheduleMaterializer $materializer
    ): JsonResponse {
        $trainerId = $request->user()->trainerProfile?->id;
        if (! $trainerId) {
            return response()->json(['success' => false, 'message' => 'Profil trainer belum tersedia.'], 422);
        }

        try {
            [$trainer, $regeneration] = DB::transaction(function () use ($request, $trainerId, $materializer) {
                $trainer = TrainerProfile::query()->lockForUpdate()->findOrFail($trainerId);
                $trainer->schedules()->delete();

                foreach ($request->validated('days') as $day) {
                    foreach ($day['shifts'] as $shift) {
                        $trainer->schedules()->create([
                            'day_of_week' => $day['day_of_week'],
                            'start_time' => $shift['start_time'].':00',
                            'end_time' => $shift['end_time'].':00',
                            'session_duration_minutes' => $this->durationMinutes(
                                $shift['start_time'],
                                $shift['end_time']
                            ),
                        ]);
                    }
                }

                $trainer->increment('schedule_template_version');
                $trainer->refresh();
                $now = CarbonImmutable::now(TrainerScheduleMaterializer::TIMEZONE);
                $regeneration = $materializer->materializeTrainer(
                    $trainer,
                    $now->startOfDay(),
                    $now->addMonthNoOverflow()->endOfMonth()->startOfDay()
                );

                return [$trainer->load('schedules'), $regeneration];
            }, 3);
        } catch (\App\Exceptions\BookingScheduleException $exception) {
            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
            ], $exception->httpStatus);
        }

        return $this->response(
            $trainer,
            'Jadwal trainer berhasil diperbarui.',
            $regeneration
        );
    }

    private function response(
        TrainerProfile $trainer,
        string $message = 'Jadwal trainer berhasil diambil.',
        ?array $regeneration = null
    ): JsonResponse {
        $grouped = $trainer->schedules->sortBy('start_time')->groupBy('day_of_week');
        $days = collect(range(1, 7))->map(fn (int $day) => [
            'day_of_week' => $day,
            'day_name' => self::DAY_NAMES[$day],
            'enabled' => $grouped->has($day),
            'shifts' => $grouped->get($day, collect())->map(fn ($shift) => [
                'id' => $shift->id,
                'start_time' => substr((string) $shift->start_time, 0, 5),
                'end_time' => substr((string) $shift->end_time, 0, 5),
                'session_duration_minutes' => $this->durationMinutes(
                    (string) $shift->start_time,
                    (string) $shift->end_time
                ),
            ])->values(),
        ])->values();

        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => [
                'timezone' => 'Asia/Jakarta',
                'template_version' => (int) $trainer->schedule_template_version,
                'days' => $days,
                ...($regeneration !== null ? ['regeneration' => $regeneration] : []),
            ],
            'meta' => null,
        ]);
    }

    private function durationMinutes(string $start, string $end): int
    {
        [$startHour, $startMinute] = array_map('intval', explode(':', $start));
        [$endHour, $endMinute] = array_map('intval', explode(':', $end));

        return ($endHour * 60 + $endMinute) - ($startHour * 60 + $startMinute);
    }
}

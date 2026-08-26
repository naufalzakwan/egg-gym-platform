<?php

namespace App\Http\Controllers\Api\V1\Trainer;

use App\Exceptions\BookingScheduleException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Trainer\ListTrainerScheduleDatesRequest;
use App\Http\Requests\Api\V1\Trainer\ResetTrainerScheduleDateRequest;
use App\Http\Requests\Api\V1\Trainer\UpdateTrainerScheduleDateRequest;
use App\Services\TrainerScheduleDateService;
use Illuminate\Http\JsonResponse;

class TrainerScheduleDateController extends Controller
{
    public function index(
        ListTrainerScheduleDatesRequest $request,
        TrainerScheduleDateService $service
    ): JsonResponse {
        $trainer = $request->user()->trainerProfile;
        if (! $trainer) {
            return response()->json(['success' => false, 'message' => 'Profil trainer belum tersedia.'], 422);
        }

        try {
            $data = $service->month($trainer, $request->validated('month'));
        } catch (BookingScheduleException $exception) {
            return $this->failure($exception);
        }

        return $this->success($data);
    }

    public function update(
        UpdateTrainerScheduleDateRequest $request,
        string $date,
        TrainerScheduleDateService $service
    ): JsonResponse {
        $trainer = $request->user()->trainerProfile;
        if (! $trainer) {
            return response()->json(['success' => false, 'message' => 'Profil trainer belum tersedia.'], 422);
        }

        try {
            $data = $service->update(
                $trainer,
                $request->user()->id,
                $date,
                $request->validated('mode'),
                $request->integer('lock_version'),
                $request->validated('shifts')
            );
        } catch (BookingScheduleException $exception) {
            return $this->failure($exception);
        }

        return $this->success($data, 'Jadwal tanggal berhasil diperbarui.');
    }

    public function reset(
        ResetTrainerScheduleDateRequest $request,
        string $date,
        TrainerScheduleDateService $service
    ): JsonResponse {
        $trainer = $request->user()->trainerProfile;
        if (! $trainer) {
            return response()->json(['success' => false, 'message' => 'Profil trainer belum tersedia.'], 422);
        }

        try {
            $data = $service->reset($trainer, $date, $request->integer('lock_version'));
        } catch (BookingScheduleException $exception) {
            return $this->failure($exception);
        }

        return $this->success($data, 'Jadwal tanggal berhasil dikembalikan ke template.');
    }

    private function success(array $data, string $message = 'Jadwal tanggal berhasil diambil.'): JsonResponse
    {
        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => $data,
            'meta' => null,
        ]);
    }

    private function failure(BookingScheduleException $exception): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => $exception->getMessage(),
        ], $exception->httpStatus);
    }
}

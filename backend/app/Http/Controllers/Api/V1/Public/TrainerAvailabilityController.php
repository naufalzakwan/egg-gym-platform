<?php

namespace App\Http\Controllers\Api\V1\Public;

use App\Http\Controllers\Controller;
use App\Models\TrainerProfile;
use App\Services\TrainerAvailabilityService;
use Illuminate\Http\JsonResponse;

class TrainerAvailabilityController extends Controller
{
    public function show(
        TrainerProfile $trainerProfile,
        TrainerAvailabilityService $availabilityService
    ): JsonResponse {
        $trainerProfile->load('user');
        if ($trainerProfile->user?->status !== 'active') {
            return response()->json([
                'success' => false,
                'message' => 'Trainer aktif tidak ditemukan.',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Ketersediaan trainer berhasil diambil.',
            'data' => $availabilityService->availability($trainerProfile),
            'meta' => null,
        ]);
    }
}

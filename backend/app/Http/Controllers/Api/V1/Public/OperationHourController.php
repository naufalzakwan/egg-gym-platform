<?php

namespace App\Http\Controllers\Api\V1\Public;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\Public\OperationHourResource;
use App\Models\GymOperationHour;
use Illuminate\Http\JsonResponse;

class OperationHourController extends Controller
{
    public function index(): JsonResponse
    {
        $hours = GymOperationHour::query()
            ->orderBy('day_order')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Jam operasional gym berhasil diambil.',
            'data' => OperationHourResource::collection($hours),
            'meta' => null,
        ]);
    }
}

<?php

namespace App\Http\Controllers\Api\V1\Public;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\Public\EquipmentResource;
use App\Models\Equipment;
use Illuminate\Http\JsonResponse;

class EquipmentController extends Controller
{
    /**
     * Display a listing of active equipments.
     */
    public function index(): JsonResponse
    {
        $equipments = Equipment::query()
            ->with('movements')
            ->where('is_active', true)
            ->orderBy('name')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Daftar equipment berhasil diambil.',
            'data' => EquipmentResource::collection($equipments),
            'meta' => null,
        ]);
    }

    /**
     * Display one active equipment with its complete educational content.
     */
    public function show(Equipment $equipment): JsonResponse
    {
        abort_unless($equipment->is_active, 404);
        $equipment->load('movements');

        return response()->json([
            'success' => true,
            'message' => 'Detail equipment berhasil diambil.',
            'data' => new EquipmentResource($equipment),
            'meta' => null,
        ]);
    }
}

<?php

namespace App\Http\Controllers\Api\V1\Public;

use App\Http\Controllers\Controller;
use App\Services\PublicSettingsService;
use Illuminate\Http\JsonResponse;

class PublicSettingsController extends Controller
{
    public function show(PublicSettingsService $settings): JsonResponse
    {
        return response()->json([
            'success' => true,
            'message' => 'Pengaturan publik EGGGYM berhasil diambil.',
            'data' => $settings->publicData(),
            'meta' => null,
        ]);
    }
}

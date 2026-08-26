<?php

namespace App\Http\Controllers\Api\V1\Member;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Member\StoreMemberPhysicalProgressRequest;
use App\Http\Resources\Api\V1\Member\PhysicalProgressResource;
use App\Models\MemberProgress;
use App\Models\MemberProgressPhoto;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MemberPhysicalProgressController extends Controller
{
    /**
     * Display the authenticated member physical progress history.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        $history = MemberProgress::query()
            ->with('photos')
            ->where('member_profile_id', $memberProfile->id)
            ->orderByDesc('recorded_at')
            ->orderByDesc('id')
            ->get();

        $latest = $history->first();

        $baseline = MemberProgress::query()
            ->with('photos')
            ->where('member_profile_id', $memberProfile->id)
            ->orderBy('recorded_at')
            ->orderBy('id')
            ->first();

        return response()->json([
            'success' => true,
            'message' => 'Data progres fisik member berhasil diambil.',
            'data' => [
                'latest_progress' => $latest
                    ? (new PhysicalProgressResource($latest))->resolve()
                    : null,
                'baseline_progress' => $baseline
                    ? (new PhysicalProgressResource($baseline))->resolve()
                    : null,
                'history' => PhysicalProgressResource::collection($history)->resolve(),
                'summary' => [
                    'total_records' => $history->count(),
                    'latest_weight_kg' => $latest?->weight_kg !== null ? (float) $latest->weight_kg : null,
                    'latest_height_cm' => $latest?->height_cm !== null ? (float) $latest->height_cm : null,
                    'first_recorded_at' => $baseline?->recorded_at?->toDateString(),
                    'last_recorded_at' => $latest?->recorded_at?->toDateString(),
                ],
            ],
            'meta' => null,
        ]);
    }

    /**
     * Store a newly created member physical progress record.
     */
    public function store(StoreMemberPhysicalProgressRequest $request): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        $validated = $request->validated();

        $progress = MemberProgress::create([
            'member_profile_id' => $memberProfile->id,
            'weight_kg' => $validated['weight_kg'],
            'height_cm' => $validated['height_cm'],
            'note' => $validated['note'] ?? null,
            'recorded_at' => $validated['recorded_at'],
            'is_milestone' => $validated['is_milestone'] ?? false,
        ]);

        $uploadedPhotos = $request->file('photos', []);

        foreach ($uploadedPhotos as $photoType => $photoFile) {
            if (! $photoFile) {
                continue;
            }

            // Simpan RELATIVE PATH (mis. "member-progress/x.jpg"), BUKAN
            // Storage::url() absolut. Flutter merangkai baseUrl aktif + /storage/
            // + path saat render (tahan ganti IP LAN, konsisten dgn avatar).
            $path = $photoFile->store('member-progress', 'public');

            MemberProgressPhoto::create([
                'member_progress_id' => $progress->id,
                'photo_type' => (string) $photoType,
                'photo_url' => $path,
            ]);
        }

        $progress->load('photos');

        return response()->json([
            'success' => true,
            'message' => 'Checkpoint progres fisik member berhasil dibuat.',
            'data' => new PhysicalProgressResource($progress),
            'meta' => null,
        ], 201);
    }
}

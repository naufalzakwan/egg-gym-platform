<?php

namespace App\Http\Controllers\Api\V1\Public;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\Public\TrainerProfileResource;
use App\Models\TrainerProfile;
use App\Models\TrainerRating;
use Illuminate\Http\JsonResponse;

class TrainerController extends Controller
{
    /**
     * Display a listing of trainers.
     */
    public function index(): JsonResponse
    {
        $trainers = TrainerProfile::query()
            ->with([
                'user',
                'ratings' => fn ($query) => $query
                    ->valid()
                    ->select(['id', 'trainer_profile_id', 'member_profile_id']),
            ])
            ->withRatingStats()
            ->withActiveSchedule()
            ->orderByDesc('rating_average')
            ->orderByDesc('reviews_count')
            ->orderBy('trainer_profiles.id')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Daftar trainer berhasil diambil.',
            'data' => TrainerProfileResource::collection($trainers),
            'meta' => null,
        ]);
    }

    /**
     * Display the rating summary + testimonials of a trainer.
     */
    public function ratings(TrainerProfile $trainerProfile): JsonResponse
    {
        $ratings = TrainerRating::query()
            ->valid()
            ->with('memberProfile.user')
            ->where('trainer_profile_id', $trainerProfile->id)
            ->latest()
            ->get();

        $average = $ratings->count() > 0
            ? round((float) $ratings->avg('rating'), 2)
            : 0.0;

        return response()->json([
            'success' => true,
            'message' => 'Ulasan trainer berhasil diambil.',
            'data' => [
                'average_rating' => $average,
                'reviews_count' => $ratings->count(),
                'reviews' => $ratings->map(function (TrainerRating $r) {
                    // Tampilkan nama depan saja untuk menjaga privasi member.
                    $fullName = $r->memberProfile?->user?->name ?? 'Member';
                    $firstName = trim(explode(' ', $fullName)[0]);

                    return [
                        'id' => $r->id,
                        'member_name' => $firstName !== '' ? $firstName : 'Member',
                        'rating' => $r->rating,
                        'testimonial' => $r->testimonial,
                        'created_at' => $r->created_at?->toIso8601String(),
                    ];
                })->values(),
            ],
            'meta' => null,
        ]);
    }
}

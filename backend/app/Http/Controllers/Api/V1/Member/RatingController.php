<?php

namespace App\Http\Controllers\Api\V1\Member;

use App\Http\Controllers\Controller;
use App\Models\TrainerRating;
use App\Models\TrainingProgram;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RatingController extends Controller
{
    /**
     * Submit a rating for a completed booking.
     */
    public function store(Request $request): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        $validated = $request->validate([
            'training_program_id' => ['required', 'exists:training_programs,id'],
            'rating' => ['required', 'integer', 'min:1', 'max:5'],
            'testimonial' => ['nullable', 'string', 'max:1000'],
        ]);

        try {
            $result = DB::transaction(function () use ($memberProfile, $validated) {
                // Serialize submissions for the same program around the database unique key.
                $program = TrainingProgram::query()
                    ->withCount([
                        'sessions',
                        'sessions as completed_sessions_count' => function ($query) {
                            $query->where('status', 'completed');
                        },
                    ])
                    ->where('id', $validated['training_program_id'])
                    ->where('member_profile_id', $memberProfile->id)
                    ->lockForUpdate()
                    ->first();

                if (! $program) {
                    return response()->json([
                        'success' => false,
                        'message' => 'Program tidak ditemukan untuk member ini.',
                    ], 404);
                }

                $existing = TrainerRating::query()
                    ->where('member_profile_id', $memberProfile->id)
                    ->where('training_program_id', $program->id)
                    ->first();

                if ($existing) {
                    return response()->json([
                        'success' => false,
                        'message' => 'Kamu sudah memberikan rating untuk program ini.',
                    ], 422);
                }

                $programCompleted = $program->sessions_count > 0
                    && $program->completed_sessions_count === $program->sessions_count;

                if (! $programCompleted) {
                    return response()->json([
                        'success' => false,
                        'message' => 'Rating hanya bisa diberikan setelah semua sesi program latihan selesai.',
                    ], 422);
                }

                $rating = TrainerRating::create([
                    'member_profile_id' => $memberProfile->id,
                    'trainer_profile_id' => $program->trainer_profile_id,
                    'booking_id' => $program->booking_id,
                    'training_program_id' => $program->id,
                    'rating' => $validated['rating'],
                    'testimonial' => $validated['testimonial'] ?? null,
                ]);

                $stats = TrainerRating::query()
                    ->valid()
                    ->where('trainer_profile_id', $program->trainer_profile_id)
                    ->selectRaw('AVG(rating) as average_rating, COUNT(*) as reviews_count')
                    ->firstOrFail();

                return [
                    'rating' => $rating,
                    'average_rating' => round((float) $stats->average_rating, 2),
                    'reviews_count' => (int) $stats->reviews_count,
                ];
            });
        } catch (QueryException $exception) {
            if ((int) ($exception->errorInfo[1] ?? 0) !== 1062) {
                throw $exception;
            }

            return response()->json([
                'success' => false,
                'message' => 'Kamu sudah memberikan rating untuk program ini.',
            ], 422);
        }

        if ($result instanceof JsonResponse) {
            return $result;
        }

        $rating = $result['rating'];

        return response()->json([
            'success' => true,
            'message' => 'Rating berhasil dikirim.',
            'data' => [
                'id' => $rating->id,
                'rating' => $rating->rating,
                'testimonial' => $rating->testimonial,
                'average_rating' => $result['average_rating'],
                'reviews_count' => $result['reviews_count'],
                'created_at' => $rating->created_at?->toIso8601String(),
            ],
            'meta' => null,
        ], 201);
    }

    /**
     * Get ratings for a trainer.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        $ratings = TrainerRating::query()
            ->with(['memberProfile.user', 'trainerProfile.user'])
            ->where('member_profile_id', $memberProfile->id)
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Daftar rating berhasil diambil.',
            'data' => $ratings->map(fn ($r) => [
                'id' => $r->id,
                'trainer_name' => $r->trainerProfile?->user?->name,
                'rating' => $r->rating,
                'testimonial' => $r->testimonial,
                'created_at' => $r->created_at?->toIso8601String(),
            ]),
            'meta' => null,
        ]);
    }
}

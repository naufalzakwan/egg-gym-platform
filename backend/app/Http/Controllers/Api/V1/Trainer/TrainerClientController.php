<?php

namespace App\Http\Controllers\Api\V1\Trainer;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\Trainer\TrainerClientDetailResource;
use App\Http\Resources\Api\V1\Trainer\TrainerClientResource;
use App\Models\MemberProfile;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TrainerClientController extends Controller
{
    private const CLIENT_BOOKING_STATUSES = [
        'payment_verified',
    ];

    private const CLIENT_PROGRAM_STATUSES = [
        'draft',
        'active',
    ];

    /**
     * Display the authenticated trainer clients.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $clients = MemberProfile::query()
            ->with([
                'user',
                'bookings' => function ($query) use ($trainerProfile) {
                    $query->where('trainer_profile_id', $trainerProfile->id)
                        ->where(function ($statusQuery) {
                            $this->applyEligibleBookingStatus($statusQuery);
                        })
                        ->orderBy('session_date')
                        ->orderBy('start_time');
                },
            ])
            ->where(function ($query) use ($trainerProfile) {
                $query
                    ->whereHas('bookings', function ($bookingQuery) use ($trainerProfile) {
                        $bookingQuery->where('trainer_profile_id', $trainerProfile->id)
                            ->where(function ($statusQuery) {
                                $this->applyEligibleBookingStatus($statusQuery);
                            });
                    })
                    ->orWhereHas('trainingPrograms', function ($programQuery) use ($trainerProfile) {
                        $programQuery->where('trainer_profile_id', $trainerProfile->id)
                            ->whereIn('status', self::CLIENT_PROGRAM_STATUSES)
                            ->whereHas('sessions', fn ($session) => $session
                                ->whereNotIn('status', ['completed', 'cancelled']));
                    });
            })
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = $request->query('search');

                $query->whereHas('user', function ($userQuery) use ($search) {
                    $userQuery->where('name', 'like', '%'.$search.'%');
                });
            })
            ->get()
            ->sortBy(function ($client) {
                return $client->user?->name;
            })
            ->values();

        return response()->json([
            'success' => true,
            'message' => 'Data klien trainer berhasil diambil.',
            'data' => TrainerClientResource::collection($clients),
            'meta' => null,
        ]);
    }

    /**
     * Display a specific trainer client.
     */
    public function show(Request $request, MemberProfile $memberProfile): JsonResponse
    {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $client = MemberProfile::query()
            ->with([
                'user',
                'memberships.membershipPlan',
                'bookings' => function ($query) use ($trainerProfile) {
                    $query->where('trainer_profile_id', $trainerProfile->id)
                        ->where(function ($statusQuery) {
                            $this->applyEligibleBookingStatus($statusQuery);
                        })
                        ->orderBy('session_date')
                        ->orderBy('start_time');
                },
                'trainingPrograms' => function ($query) use ($trainerProfile) {
                    $query->where('trainer_profile_id', $trainerProfile->id)
                        ->with(['sessions.exercises'])
                        ->orderByDesc('started_at')
                        ->orderByDesc('id');
                },
            ])
            ->where('id', $memberProfile->id)
            ->where(function ($query) use ($trainerProfile) {
                $query
                    ->whereHas('bookings', function ($bookingQuery) use ($trainerProfile) {
                        $bookingQuery->where('trainer_profile_id', $trainerProfile->id)
                            ->where(function ($statusQuery) {
                                $this->applyEligibleBookingStatus($statusQuery);
                            });
                    })
                    ->orWhereHas('trainingPrograms', function ($programQuery) use ($trainerProfile) {
                        $programQuery->where('trainer_profile_id', $trainerProfile->id)
                            ->whereIn('status', self::CLIENT_PROGRAM_STATUSES)
                            ->whereHas('sessions', fn ($session) => $session
                                ->whereNotIn('status', ['completed', 'cancelled']));
                    });
            })
            ->first();

        if (! $client) {
            return response()->json([
                'success' => false,
                'message' => 'Klien tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Detail klien trainer berhasil diambil.',
            'data' => new TrainerClientDetailResource($client),
            'meta' => null,
        ]);
    }

    private function applyEligibleBookingStatus($query): void
    {
        $query
            ->whereIn('status', self::CLIENT_BOOKING_STATUSES)
            ->orWhere(function ($confirmedQuery) {
                $confirmedQuery
                    ->where('status', 'confirmed')
                    ->whereNotNull('payment_verified_at');
            })
            ->orWhere(function ($rescheduledQuery) {
                $rescheduledQuery
                    ->where('status', 'rescheduled')
                    ->whereNotNull('payment_verified_at');
            });
    }
}

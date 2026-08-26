<?php

namespace App\Http\Controllers\Api\V1\Trainer;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\Member\BookingResource;
use App\Models\Booking;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TrainerDashboardController extends Controller
{
    /**
     * Display the authenticated trainer dashboard.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user()->load([
            'trainerProfile' => fn ($query) => $query
                ->withActiveSchedule()
                ->withRatingStats(),
        ]);
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $baseQuery = Booking::query()
            ->where('trainer_profile_id', $trainerProfile->id);

        $activeClients = (clone $baseQuery)
            ->distinct('member_profile_id')
            ->count('member_profile_id');

        $today = now()->toDateString();
        $readyStatus = function ($query): void {
            $query
                ->whereIn('status', ['payment_verified', 'confirmed', 'completed'])
                ->orWhere(function ($rescheduled): void {
                    $rescheduled
                        ->where('status', 'rescheduled')
                        ->whereNotNull('payment_verified_at');
                });
        };
        $occursToday = function ($query) use ($today): void {
            $query
                ->whereHas('sessionReservations', function ($reservation) use ($today): void {
                    $reservation
                        ->whereDate('session_date', $today)
                        ->whereIn('status', ['reserved', 'completed']);
                })
                ->orWhere(function ($legacy) use ($today): void {
                    $legacy
                        ->whereDoesntHave('sessionReservations')
                        ->whereDate('session_date', $today);
                });
        };

        $todaySessions = (clone $baseQuery)
            ->where($readyStatus)
            ->where($occursToday)
            ->count();

        $todayAgenda = (clone $baseQuery)
            ->with(['memberProfile.user', 'trainerProfile.user', 'sessionReservations'])
            ->where($readyStatus)
            ->where($occursToday)
            ->orderBy('session_date')
            ->orderBy('start_time')
            ->limit(3)
            ->get();

        $paymentVerificationRequests = (clone $baseQuery)
            ->with(['memberProfile.user', 'trainerProfile.user', 'sessionReservations'])
            ->where('status', 'payment_uploaded')
            ->orderByRaw('payment_proof_uploaded_at IS NULL')
            ->orderBy('payment_proof_uploaded_at')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Dashboard trainer berhasil diambil.',
            'data' => [
                'trainer_name' => $user->name,
                'tier' => $trainerProfile->tier_value,
                'tier_label' => $trainerProfile->tier_label,
                'active_clients' => $activeClients,
                'today_sessions' => $todaySessions,
                'rating' => $trainerProfile->reviews_count > 0
                    ? round((float) $trainerProfile->rating_average, 2)
                    : 0.0,
                'reviews_count' => (int) $trainerProfile->reviews_count,
                'has_active_schedule' => (bool) $trainerProfile->has_active_schedule,
                'today_agenda' => BookingResource::collection($todayAgenda),
                'payment_verification_requests' => BookingResource::collection($paymentVerificationRequests),
            ],
            'meta' => null,
        ]);
    }
}

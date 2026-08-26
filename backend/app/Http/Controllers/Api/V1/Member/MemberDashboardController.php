<?php

namespace App\Http\Controllers\Api\V1\Member;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\MemberMembership;
use App\Models\TrainingProgram;
use App\Services\Booking\BookingRequestExpiryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MemberDashboardController extends Controller
{
    /**
     * Display the member dashboard.
     */
    public function index(
        Request $request,
        BookingRequestExpiryService $expiryService
    ): JsonResponse {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;
        $expiryService->expirePendingBookings();

        // Ambil SEMUA membership member untuk menghitung rantai kontigu
        // (pembelian yang di-stack ke depan ikut terhitung sebagai sisa masa
        // aktif), bukan hanya satu row aktif hari ini.
        $allMemberships = MemberMembership::query()
            ->with('membershipPlan')
            ->whereHas('memberProfile', function ($query) use ($user) {
                $query->where('user_id', $user->id);
            })
            ->get();

        // Paket yang aktif HARI INI (untuk nama paket & tier).
        $activeMembership = $allMemberships
            ->filter(fn ($m) => $m->isCurrentlyActive())
            ->sortByDesc(fn ($m) => $m->end_date->getTimestamp())
            ->first();

        // remaining_days & valid_until dari UJUNG rantai membership kontigu.
        $chainEndDate = MemberMembership::activeChainEndDate($allMemberships);
        $remainingDays = MemberMembership::remainingDaysForMember($allMemberships);

        // Get actual next booking for this member
        $nextBooking = null;
        if ($memberProfile) {
            $nextBooking = Booking::query()
                ->with(['trainerProfile.user', 'sessionReservations.pendingRescheduleRequest.requestedBy'])
                ->where('member_profile_id', $memberProfile->id)
                ->whereIn('status', ['pending', 'waiting_payment', 'payment_uploaded', 'payment_rejected', 'payment_verified', 'confirmed'])
                ->whereDate('session_date', '>=', now()->startOfDay())
                ->orderBy('session_date')
                ->orderBy('start_time')
                ->first();
        }

        // Cek apakah member sedang terikat sesi PT aktif (untuk disable tombol
        // Booking di frontend + info trainer yang sedang aktif).
        $activePtBooking = $memberProfile?->activePtBooking();
        $activePtBooking?->loadMissing('trainerProfile.user');

        // Program next booking harus terhubung ke booking tersebut, bukan hanya
        // ke pasangan member dan trainer yang mungkin punya riwayat lama.
        $nextBookingHasProgram = false;
        $nextBookingProgramCompleted = false;
        if ($nextBooking && $memberProfile) {
            $nextProgram = TrainingProgram::query()
                ->withCount([
                    'sessions',
                    'sessions as completed_sessions_count' => function ($query) {
                        $query->where('status', 'completed');
                    },
                ])
                ->where(function ($query) use ($nextBooking) {
                    $query->where('booking_id', $nextBooking->id)
                        ->orWhere(function ($legacy) use ($nextBooking) {
                            $legacy->whereNull('booking_id')
                                ->whereHas('sessions.bookingSessionReservation', function ($reservation) use ($nextBooking) {
                                    $reservation->where('booking_id', $nextBooking->id);
                                });
                        });
                })
                ->has('sessions')
                ->latest('id')
                ->first();

            $nextBookingHasProgram = $nextProgram !== null;
            $nextBookingProgramCompleted = $nextProgram !== null
                && $nextProgram->sessions_count > 0
                && $nextProgram->completed_sessions_count === $nextProgram->sessions_count;
        }

        return response()->json([
            'success' => true,
            'message' => 'Dashboard member berhasil diambil.',
            'data' => [
                'member_name' => $user->name,
                'current_tier' => $this->resolveCurrentTier($activeMembership?->membershipPlan?->slug),
                'package_name' => $activeMembership?->membershipPlan?->name,
                'valid_until' => $chainEndDate?->toDateString()
                    ?? $activeMembership?->end_date?->toDateString(),
                'remaining_days' => $remainingDays,
                'has_active_pt_engagement' => $activePtBooking !== null,
                'active_pt_trainer_name' => $activePtBooking?->trainerProfile?->user?->name,
                'active_pt_status' => $activePtBooking?->status,
                'profile_complete' => $memberProfile?->hasCompleteProfile() ?? false,
                'next_session' => $nextBooking ? [
                    'id' => $nextBooking->id,
                    'trainer_profile_id' => $nextBooking->trainer_profile_id,
                    'trainer_name' => $nextBooking->trainerProfile?->user?->name ?? '-',
                    'trainer_avatar_url' => $nextBooking->trainerProfile?->user?->avatar_url,
                    'trainer_display_photo_path' => $nextBooking->trainerProfile?->display_photo_path,
                    'session_title' => $nextBooking->session_title,
                    'time_range' => substr((string) $nextBooking->start_time, 0, 5).' - '.substr((string) $nextBooking->end_time, 0, 5),
                    'date' => $nextBooking->session_date?->toDateString(),
                    'location' => $nextBooking->location,
                    'status' => $nextBooking->status,
                    'session_count' => $nextBooking->session_count
                        ?? ($nextBooking->sessionReservations->count() ?: 1),
                    'has_program' => $nextBookingHasProgram,
                    'program_completed' => $nextBookingProgramCompleted,
                    'expired_at' => $nextBooking->expired_at?->toIso8601String(),
                    'remaining_seconds' => $nextBooking->expired_at !== null
                        ? max(0, (int) now()->diffInSeconds($nextBooking->expired_at, false))
                        : 0,
                    'expiry_stage' => $expiryService->expiryStage($nextBooking),
                    'is_payment_verification_overdue' => $expiryService->isPaymentVerificationOverdue($nextBooking),
                    'payment_verification_overdue_seconds' => $expiryService->verificationOverdueSeconds($nextBooking),
                    'note' => $nextBooking->member_note,
                    'session_reservations' => $nextBooking->sessionReservations->map(fn ($reservation) => [
                        'id' => $reservation->id,
                        'sequence_order' => $reservation->sequence_order,
                        'session_date' => $reservation->session_date?->toDateString(),
                        'start_time' => $reservation->start_time,
                        'end_time' => $reservation->end_time,
                        'status' => $reservation->status,
                        'active_reschedule_request' => $reservation->pendingRescheduleRequest
                            ? (new \App\Http\Resources\Api\V1\Booking\BookingRescheduleRequestResource($reservation->pendingRescheduleRequest))->resolve($request)
                            : null,
                    ])->values(),
                ] : null,
                'recent_transactions' => [],
            ],
            'meta' => null,
        ]);
    }

    private function resolveCurrentTier(?string $slug): string
    {
        return match ($slug) {
            'elite-member' => 'Elite Status',
            'annual-pro' => 'Pro Annual Status',
            'starter-pack' => 'Starter Status',
            default => 'Member Status',
        };
    }
}

<?php

namespace App\Http\Controllers\Api\V1\Trainer;

use App\Exceptions\BookingScheduleException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Member\RescheduleBookingRequest;
use App\Http\Resources\Api\V1\Member\BookingResource;
use App\Http\Resources\Api\V1\Trainer\TrainerBookingDetailResource;
use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Services\Booking\BookingRequestExpiryService;
use App\Services\Booking\BookingScheduleService;
use App\Services\Notification\UserNotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TrainerSessionController extends Controller
{
    public function rescheduleReservation(
        \App\Http\Requests\Api\V1\Member\RescheduleBookingRequest $request,
        Booking $booking,
        BookingSessionReservation $reservation,
        BookingScheduleService $scheduleService
    ): JsonResponse {
        $trainerProfile = $request->user()->load('trainerProfile')->trainerProfile;
        if (! $trainerProfile) {
            return response()->json(['success' => false, 'message' => 'Profil trainer belum tersedia.'], 422);
        }
        try {
            $updated = $scheduleService->rescheduleReservation(
                $booking,
                $reservation,
                $request->validated(),
                expectedTrainerProfileId: (int) $trainerProfile->id
            );
        } catch (BookingScheduleException $exception) {
            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
            ], $exception->httpStatus);
        }
        $updated->load(['memberProfile.user', 'trainerProfile.user', 'sessionReservations']);

        return response()->json([
            'success' => true,
            'message' => 'Occurrence booking berhasil dijadwalkan ulang.',
            'data' => new BookingResource($updated),
            'meta' => null,
        ]);
    }

    /**
     * Display the authenticated trainer sessions.
     */
    public function index(
        Request $request,
        BookingRequestExpiryService $expiryService
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $query = Booking::query()
            ->with(['memberProfile.user', 'trainerProfile.user', 'sessionReservations'])
            ->where('trainer_profile_id', $trainerProfile->id)
            ->latest('session_date')
            ->latest('start_time');

        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }

        if ($request->filled('date')) {
            $query->whereDate('session_date', $request->query('date'));
        }

        $sessions = $expiryService->syncCollection($query->get());

        return response()->json([
            'success' => true,
            'message' => 'Data sesi trainer berhasil diambil.',
            'data' => BookingResource::collection($sessions),
            'meta' => null,
        ]);
    }

    public function confirm(
        Request $request,
        Booking $booking,
        UserNotificationService $userNotificationService,
        BookingRequestExpiryService $expiryService
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        if ($booking->trainer_profile_id !== $trainerProfile->id) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        $booking = $expiryService->ensureNotExpired($booking);
        $booking->load(['memberProfile.user', 'trainerProfile.user', 'sessionReservations']);

        if (! in_array($booking->status, ['pending', 'rescheduled'], true)) {
            return response()->json([
                'success' => false,
                'message' => 'Booking dengan status ini tidak dapat dikonfirmasi.',
            ], 422);
        }

        $booking->update([
            'status' => 'waiting_payment',
            'expired_at' => $expiryService->resolveBookingExpiryTimestamp(
                $booking,
                'waiting_payment'
            ),
        ]);

        $booking->refresh()->load(['memberProfile.user', 'trainerProfile.user', 'sessionReservations']);

        $memberUser = $booking->memberProfile?->user;
        $trainerName = $booking->trainerProfile?->user?->name ?? 'trainer kamu';

        if ($memberUser) {
            $userNotificationService->notify(
                $memberUser,
                'Booking PT Dikonfirmasi - Menunggu Pembayaran',
                'Sesi PT kamu dengan '.$trainerName.' pada '
                    .$booking->session_date?->format('d M Y')
                    .' pukul '.substr((string) $booking->start_time, 0, 5)
                    .' sudah dikonfirmasi. Silakan lakukan pembayaran dan upload bukti transfer.',
                'booking',
                'push',
                true,
                [
                    'booking_id' => (string) $booking->id,
                    'status' => 'waiting_payment',
                    'target' => 'booking_payment',
                ],
                "booking:{$booking->id}:confirmed:member"
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Booking berhasil dikonfirmasi. Member diminta melakukan pembayaran.',
            'data' => new BookingResource($booking),
            'meta' => null,
        ]);
    }

    /**
     * Reject a pending booking request.
     */
    public function reject(
        Request $request,
        Booking $booking,
        UserNotificationService $userNotificationService,
        BookingScheduleService $scheduleService,
        BookingRequestExpiryService $expiryService
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        if ($booking->trainer_profile_id !== $trainerProfile->id) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        $booking = $expiryService->ensureNotExpired($booking);
        $booking->load(['memberProfile.user', 'trainerProfile.user']);

        if (! in_array($booking->status, ['pending', 'rescheduled'], true)) {
            return response()->json([
                'success' => false,
                'message' => 'Booking dengan status ini tidak dapat ditolak.',
            ], 422);
        }

        // Ditolak dipetakan ke status 'cancelled' agar konsisten dengan enum
        // status yang sudah ada dan EXCLUDED dari ACTIVE_BOOKING_STATUSES,
        // sehingga member langsung bebas mengajukan booking ke trainer lain.
        $booking = $scheduleService->cancelBookingReservations($booking);
        $booking->load(['memberProfile.user', 'trainerProfile.user', 'sessionReservations']);

        $memberUser = $booking->memberProfile?->user;
        $trainerName = $booking->trainerProfile?->user?->name ?? 'trainer kamu';

        if ($memberUser) {
            $userNotificationService->notify(
                $memberUser,
                'Booking PT Ditolak',
                'Maaf, pengajuan sesi PT kamu dengan '.$trainerName.' pada '
                    .$booking->session_date?->format('d M Y')
                    .' pukul '.substr((string) $booking->start_time, 0, 5)
                    .' ditolak. Kamu bisa mengajukan booking ke trainer lain.',
                'booking',
                'push',
                true,
                [
                    'booking_id' => (string) $booking->id,
                    'status' => 'cancelled',
                    'target' => 'schedule',
                ],
                "booking:{$booking->id}:rejected:member"
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Booking berhasil ditolak.',
            'data' => new BookingResource($booking),
            'meta' => null,
        ]);
    }

    /**
     * Display a specific trainer session.
     */
    public function show(
        Request $request,
        Booking $booking,
        BookingRequestExpiryService $expiryService
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        if ($booking->trainer_profile_id !== $trainerProfile->id) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        $booking = $expiryService->ensureNotExpired($booking);
        $booking->load([
            'memberProfile.user',
            'memberProfile.memberships.membershipPlan',
            'trainerProfile.user',
            'sessionReservations.pendingRescheduleRequest.requestedBy',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Detail sesi trainer berhasil diambil.',
            'data' => new TrainerBookingDetailResource($booking),
            'meta' => null,
        ]);
    }

    /**
     * Reschedule a trainer session.
     */
    public function reschedule(
        RescheduleBookingRequest $request,
        Booking $booking,
        UserNotificationService $userNotificationService,
        BookingScheduleService $scheduleService
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $booking->load(['memberProfile.user', 'trainerProfile.user']);

        if ($booking->trainer_profile_id !== $trainerProfile->id) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        if (! in_array($booking->status, ['pending', 'confirmed', 'rescheduled'], true)) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi dengan status ini tidak dapat dijadwalkan ulang.',
            ], 422);
        }

        $validated = $request->validated();

        try {
            $booking = $scheduleService->reschedule(
                $booking,
                $validated,
                ['pending', 'confirmed', 'rescheduled'],
                'trainer_note',
                expectedTrainerProfileId: (int) $trainerProfile->id
            );
        } catch (BookingScheduleException $exception) {
            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
            ], $exception->httpStatus);
        }

        $booking->refresh()->load(['memberProfile.user', 'trainerProfile.user']);

        $memberUser = $booking->memberProfile?->user;
        $trainerName = $booking->trainerProfile?->user?->name ?? 'trainer kamu';

        if ($memberUser) {
            $userNotificationService->notify(
                $memberUser,
                'Jadwal PT Diperbarui',
                'Sesi PT kamu dengan '.$trainerName.' dijadwalkan ulang ke '
                    .$booking->session_date?->format('d M Y')
                    .' pukul '.substr((string) $booking->start_time, 0, 5).'.',
                'booking',
                'push',
                true,
                [
                    'booking_id' => (string) $booking->id,
                    'status' => 'rescheduled',
                ]
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Sesi trainer berhasil dijadwalkan ulang.',
            'data' => new BookingResource($booking),
            'meta' => null,
        ]);
    }

    /**
     * Verify payment proof uploaded by member.
     */
    public function verifyPayment(
        Request $request,
        Booking $booking,
        UserNotificationService $userNotificationService,
        BookingRequestExpiryService $expiryService
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        if ($booking->trainer_profile_id !== $trainerProfile->id) {
            return response()->json([
                'success' => false,
                'message' => 'Booking tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        $booking = $expiryService->ensureNotExpired($booking);

        if ($booking->status !== 'payment_uploaded') {
            return response()->json([
                'success' => false,
                'message' => 'Booking tidak dalam status menunggu verifikasi pembayaran.',
            ], 422);
        }

        $validated = $request->validate([
            'verified' => ['required', 'boolean'],
            'rejection_note' => ['nullable', 'string', 'max:500'],
        ]);

        $booking->load(['memberProfile.user', 'trainerProfile.user']);
        $memberUser = $booking->memberProfile?->user;

        if ($validated['verified']) {
            $booking->update([
                'status' => 'payment_verified',
                'payment_verified_at' => now(),
                'expired_at' => null,
                'verification_overdue_notified_at' => null,
            ]);

            if ($memberUser) {
                $userNotificationService->notify(
                    $memberUser,
                    'Pembayaran Diverifikasi',
                    'Bukti pembayaran sesi PT kamu sudah diverifikasi oleh trainer. Program latihan akan segera dibuat.',
                    'payment',
                    'push',
                    true,
                    [
                        'booking_id' => (string) $booking->id,
                        'status' => 'payment_verified',
                        'target' => 'program',
                    ],
                    "booking:{$booking->id}:payment_verified:member"
                );
            }
        } else {
            $booking->update([
                'status' => 'payment_rejected',
                'trainer_note' => $validated['rejection_note'] ?? 'Bukti pembayaran tidak valid.',
                'expired_at' => $expiryService->resolveBookingExpiryTimestamp(
                    $booking,
                    'payment_rejected'
                ),
                'verification_overdue_notified_at' => null,
            ]);

            if ($memberUser) {
                $userNotificationService->notify(
                    $memberUser,
                    'Pembayaran Ditolak',
                    'Bukti pembayaran sesi PT kamu ditolak oleh trainer. Silakan upload ulang bukti transfer yang valid.',
                    'payment',
                    'push',
                    true,
                    [
                        'booking_id' => (string) $booking->id,
                        'status' => 'payment_rejected',
                        'target' => 'booking_payment',
                    ],
                    "booking:{$booking->id}:payment_rejected:member:{$booking->expired_at?->timestamp}",
                    'high'
                );
            }
        }

        $booking->refresh()->load(['memberProfile.user', 'trainerProfile.user']);

        return response()->json([
            'success' => true,
            'message' => $validated['verified']
                ? 'Pembayaran berhasil diverifikasi.'
                : 'Pembayaran ditolak.',
            'data' => new BookingResource($booking),
            'meta' => null,
        ]);
    }
}

<?php

namespace App\Http\Controllers\Api\V1\Member;

use App\Exceptions\BookingScheduleException;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\Member\BookingResource;
use App\Models\Booking;
use App\Services\Booking\BookingRequestExpiryService;
use App\Services\Booking\BookingScheduleService;
use App\Services\Notification\UserNotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class MemberBookingPaymentController extends Controller
{
    /**
     * Get trainer payment info for a booking.
     */
    public function getPaymentInfo(
        Request $request,
        Booking $booking,
        BookingRequestExpiryService $expiryService
    ): JsonResponse {
        $user = $request->user()->load('memberProfile');

        $booking = $expiryService->ensureNotExpired($booking);

        if ($booking->member_profile_id !== $user->memberProfile?->id) {
            return response()->json([
                'success' => false,
                'message' => 'Booking tidak ditemukan.',
            ], 404);
        }

        if (! in_array($booking->status, ['waiting_payment', 'payment_uploaded', 'payment_rejected', 'expired'], true)) {
            return response()->json([
                'success' => false,
                'message' => 'Booking tidak dalam status menunggu pembayaran.',
            ], 422);
        }

        $booking->load(['trainerProfile', 'sessionReservations']);

        $pricePerSession = $booking->price_per_session_snapshot !== null
            ? (float) $booking->price_per_session_snapshot
            : ($booking->trainerProfile?->price_per_session !== null
                ? (float) $booking->trainerProfile->price_per_session
                : null);
        $sessionCount = $booking->session_count ?? 1;
        $totalAmount = $booking->total_amount_snapshot !== null
            ? (float) $booking->total_amount_snapshot
            : ($pricePerSession !== null ? $pricePerSession * $sessionCount : null);

        return response()->json([
            'success' => true,
            'message' => 'Info pembayaran berhasil diambil.',
            'data' => [
                'booking_id' => $booking->id,
                'status' => $booking->status,
                'expired_at' => $booking->expired_at?->toIso8601String(),
                'remaining_seconds' => $expiryService->remainingSeconds($booking),
                'expiry_stage' => $expiryService->expiryStage($booking),
                'is_expired' => $booking->status === 'expired',
                'is_payment_verification_overdue' => $expiryService->isPaymentVerificationOverdue($booking),
                'payment_verification_overdue_seconds' => $expiryService->verificationOverdueSeconds($booking),
                'payment_proof_uploaded_at' => $booking->payment_proof_uploaded_at?->toIso8601String(),
                'session_count' => $sessionCount,
                'price_per_session' => $pricePerSession,
                'total_amount' => $totalAmount,
                'trainer' => [
                    'name' => $booking->trainerProfile?->user?->name,
                    'bank_name' => $booking->trainerProfile?->bank_name,
                    'bank_account_number' => $booking->trainerProfile?->bank_account_number,
                    'bank_account_name' => $booking->trainerProfile?->bank_account_name,
                    'dana_number' => $booking->trainerProfile?->dana_number,
                    'dana_account_name' => $booking->trainerProfile?->dana_account_name,
                    'other_payment_method' => $booking->trainerProfile?->other_payment_method,
                    'other_payment_number' => $booking->trainerProfile?->other_payment_number,
                    'other_payment_account_name' => $booking->trainerProfile?->other_payment_account_name,
                    'price_per_session' => $pricePerSession,
                ],
                'payment_proof_path' => $booking->payment_proof_path,
                'session_reservations' => $booking->sessionReservations->map(fn ($reservation) => [
                    'id' => $reservation->id,
                    'sequence_order' => $reservation->sequence_order,
                    'session_date' => $reservation->session_date?->toDateString(),
                    'start_time' => $reservation->start_time,
                    'end_time' => $reservation->end_time,
                    'status' => $reservation->status,
                ])->values(),
            ],
            'meta' => null,
        ]);
    }

    /**
     * Upload payment proof for a booking.
     */
    public function uploadProof(
        Request $request,
        Booking $booking,
        BookingScheduleService $scheduleService,
        BookingRequestExpiryService $expiryService,
        UserNotificationService $notificationService
    ): JsonResponse {
        $user = $request->user()->load('memberProfile');

        $booking = $expiryService->ensureNotExpired($booking);

        if ($booking->member_profile_id !== $user->memberProfile?->id) {
            return response()->json([
                'success' => false,
                'message' => 'Booking tidak ditemukan.',
            ], 404);
        }

        if (! in_array($booking->status, ['waiting_payment', 'payment_rejected'], true)) {
            return response()->json([
                'success' => false,
                'message' => 'Booking tidak dalam status menunggu pembayaran.',
            ], 422);
        }

        $request->validate([
            'payment_proof' => ['required', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],
        ]);

        $file = $request->file('payment_proof');
        $path = $file->store('payment-proofs', 'public');

        $updates = [
            'payment_proof_path' => $path,
            'payment_proof_uploaded_at' => now(),
            'verification_overdue_notified_at' => null,
            'status' => 'payment_uploaded',
            'expired_at' => $expiryService->resolveBookingExpiryTimestamp(
                $booking,
                'payment_uploaded'
            ),
        ];

        try {
            if ($booking->status === 'payment_rejected') {
                $booking = $scheduleService->transitionToBlocking(
                    $booking,
                    $updates,
                    ['payment_rejected']
                );
            } else {
                // waiting_payment sudah berstatus blocking sejak awal; perubahan
                // ke payment_uploaded tidak mengubah reservasi interval.
                $booking->update($updates);
            }
        } catch (BookingScheduleException $exception) {
            Storage::disk('public')->delete($path);

            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
            ], $exception->httpStatus);
        }

        $booking->refresh()->load(['memberProfile.user', 'trainerProfile.user']);

        if ($booking->trainerProfile?->user) {
            $notificationService->notify(
                $booking->trainerProfile->user,
                'Bukti Pembayaran Diunggah',
                'Member telah mengunggah bukti pembayaran. Mohon segera tekan Valid atau Tolak.',
                'payment',
                'push',
                true,
                ['booking_id' => (string) $booking->id, 'status' => 'payment_uploaded', 'target' => 'trainer_schedule'],
                "booking:{$booking->id}:proof_uploaded:trainer:{$booking->payment_proof_uploaded_at?->timestamp}",
                'high'
            );
        }
        if ($booking->memberProfile?->user) {
            $notificationService->notify(
                $booking->memberProfile->user,
                'Bukti pembayaran terkirim',
                'Bukti pembayaran Anda sedang menunggu verifikasi trainer.',
                'payment', 'push', true,
                ['booking_id' => (string) $booking->id, 'status' => 'payment_uploaded', 'target' => 'booking_payment'],
                "booking:{$booking->id}:proof_uploaded:member:{$booking->payment_proof_uploaded_at?->timestamp}"
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Bukti pembayaran berhasil diupload. Menunggu verifikasi dari trainer.',
            'data' => new BookingResource($booking),
            'meta' => null,
        ]);
    }
}

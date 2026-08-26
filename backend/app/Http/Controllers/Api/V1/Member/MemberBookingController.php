<?php

namespace App\Http\Controllers\Api\V1\Member;

use App\Exceptions\BookingScheduleException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Member\RescheduleBookingRequest;
use App\Http\Requests\Api\V1\Member\StoreBookingRequest;
use App\Http\Resources\Api\V1\Member\BookingResource;
use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\MemberMembership;
use App\Models\TrainerProfile;
use App\Services\Booking\BookingRequestExpiryService;
use App\Services\Booking\BookingScheduleService;
use App\Services\Notification\NotificationAutomationService;
use App\Services\Notification\UserNotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MemberBookingController extends Controller
{
    /**
     * Display the authenticated member bookings.
     */
    public function index(
        Request $request,
        BookingRequestExpiryService $expiryService
    ): JsonResponse {
        $user = $request->user();
        $status = $request->query('status');

        $query = Booking::query()
            ->with(['memberProfile.user', 'trainerProfile.user', 'sessionReservations'])
            ->whereHas('memberProfile', function ($builder) use ($user) {
                $builder->where('user_id', $user->id);
            })
            ->latest('session_date')
            ->latest('start_time');

        if ($status) {
            $query->where('status', $status);
        }

        $bookings = $expiryService->syncCollection($query->get());

        return response()->json([
            'success' => true,
            'message' => 'Data booking member berhasil diambil.',
            'data' => BookingResource::collection($bookings),
            'meta' => null,
        ]);
    }

    /**
     * Store a newly created booking request.
     */
    public function store(
        StoreBookingRequest $request,
        BookingScheduleService $scheduleService,
        BookingRequestExpiryService $expiryService,
        UserNotificationService $notifications,
        NotificationAutomationService $automation,
    ): JsonResponse {
        $user = $request->user()->load('memberProfile');
        $validated = $request->validated();

        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        // Validasi: data profil fisik (TB, BB, target) wajib lengkap sebelum booking,
        // supaya data yang jadi bahan pertimbangan trainer benar-benar terisi.
        if (! $memberProfile->hasCompleteProfile()) {
            return response()->json([
                'success' => false,
                'message' => 'Lengkapi data profil (tinggi badan, berat badan, dan target) terlebih dahulu sebelum booking.',
            ], 422);
        }

        // Validasi: member tidak boleh booking PT lain bila masih ada engagement
        // PT aktif (booking belum tuntas / program belum selesai 100% & belum dirating).
        $expiryService->expirePendingBookings();
        $activeBooking = $memberProfile->activePtBooking();
        if ($activeBooking) {
            $activeBooking->loadMissing('trainerProfile.user');
            $activeTrainerName = $activeBooking->trainerProfile?->user?->name;

            return response()->json([
                'success' => false,
                'message' => $activeTrainerName
                    ? 'Kamu masih dalam sesi PT aktif bersama '.$activeTrainerName
                        .'. Selesaikan program latihan dan beri rating dulu sebelum booking PT lain.'
                    : 'Kamu masih dalam sesi PT aktif. Selesaikan program latihan dan beri rating dulu sebelum booking PT lain.',
            ], 422);
        }

        $hasActiveMembership = MemberMembership::query()
            ->where('member_profile_id', $memberProfile->id)
            ->currentlyActive()
            ->exists();

        if (! $hasActiveMembership) {
            return response()->json([
                'success' => false,
                'message' => 'Anda harus memiliki membership aktif sebelum memesan sesi personal trainer.',
            ], 422);
        }

        $trainerProfile = TrainerProfile::query()
            ->with('user')
            ->where('id', $validated['trainer_profile_id'])
            ->whereHas('user', function ($query) {
                $query->where('status', 'active');
            })
            ->first();

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Trainer tidak aktif atau tidak ditemukan.',
            ], 422);
        }

        // Validasi kuota: batas kuota bersifat dinamis per "gelombang" pemerataan.
        // Trainer hanya diblokir bila sudah mencapai cap gelombang saat ini, dan
        // cap baru naik ketika SEMUA trainer sudah merata mencapai cap tersebut.
        if (! $trainerProfile->hasAvailableQuota()) {
            return response()->json([
                'success' => false,
                'message' => 'Kuota trainer ini sedang penuh. Silakan pilih trainer lain terlebih dahulu.',
            ], 422);
        }

        try {
            $booking = $scheduleService->create([
                'member_profile_id' => $memberProfile->id,
                'trainer_profile_id' => $trainerProfile->id,
                'session_title' => $validated['session_title'],
                'reservations' => $validated['reservations'],
                'location' => $validated['location'],
                'session_count' => (int) $validated['session_count'],
                'status' => 'pending',
                'member_note' => $validated['member_note'] ?? null,
                'trainer_note' => null,
            ]);
        } catch (BookingScheduleException $exception) {
            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
            ], $exception->httpStatus);
        }

        $booking->load(['memberProfile.user', 'trainerProfile.user', 'sessionReservations']);
        $data = ['booking_id' => (string) $booking->id, 'status' => 'pending'];
        if ($booking->memberProfile?->user) {
            $notifications->notify($booking->memberProfile->user, 'Booking berhasil diajukan', 'Permintaan booking Anda sudah dikirim ke trainer. Tunggu konfirmasi trainer.', 'booking', 'push', true, $data + ['target' => 'schedule'], "booking:{$booking->id}:submitted:member");
        }
        if ($booking->trainerProfile?->user) {
            $notifications->notify($booking->trainerProfile->user, 'Permintaan booking baru', 'Ada member yang mengajukan booking. Segera konfirmasi atau tolak sebelum batas waktu.', 'booking', 'push', true, $data + ['target' => 'trainer_schedule'], "booking:{$booking->id}:submitted:trainer", 'high');
        }
        $automation->notifyAdmins('Booking PT baru', 'Ada member yang mengajukan booking personal trainer.', 'booking', $data + ['target' => 'booking_admin'], "booking:{$booking->id}:submitted:admin");

        return response()->json([
            'success' => true,
            'message' => 'Request booking berhasil dibuat.',
            'data' => new BookingResource($booking),
            'meta' => null,
        ], 201);
    }

    /**
     * Reschedule an existing member booking.
     */
    public function reschedule(
        RescheduleBookingRequest $request,
        Booking $booking,
        BookingScheduleService $scheduleService
    ): JsonResponse {
        $user = $request->user();

        $booking->load(['memberProfile.user', 'trainerProfile.user']);

        if ($booking->memberProfile?->user_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'Booking tidak ditemukan untuk member ini.',
            ], 404);
        }

        if (! in_array($booking->status, ['pending', 'confirmed'], true)) {
            return response()->json([
                'success' => false,
                'message' => 'Booking dengan status ini tidak dapat di-reschedule.',
            ], 422);
        }

        $validated = $request->validated();

        try {
            $booking = $scheduleService->reschedule(
                $booking,
                $validated,
                ['pending', 'confirmed'],
                'member_note',
                expectedMemberProfileId: (int) $user->memberProfile->id
            );
        } catch (BookingScheduleException $exception) {
            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
            ], $exception->httpStatus);
        }

        $booking->refresh()->load(['memberProfile.user', 'trainerProfile.user', 'sessionReservations']);

        return response()->json([
            'success' => true,
            'message' => 'Booking berhasil dijadwalkan ulang.',
            'data' => new BookingResource($booking),
            'meta' => null,
        ]);
    }

    public function rescheduleReservation(
        RescheduleBookingRequest $request,
        Booking $booking,
        BookingSessionReservation $reservation,
        BookingScheduleService $scheduleService
    ): JsonResponse {
        try {
            $updated = $scheduleService->rescheduleReservation(
                $booking,
                $reservation,
                $request->validated(),
                expectedMemberProfileId: (int) $request->user()->memberProfile->id
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
}

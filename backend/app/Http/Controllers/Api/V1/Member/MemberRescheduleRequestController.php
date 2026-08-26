<?php

namespace App\Http\Controllers\Api\V1\Member;

use App\Exceptions\BookingScheduleException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Booking\RejectRescheduleRequest;
use App\Http\Requests\Api\V1\Booking\StoreRescheduleRequest;
use App\Http\Resources\Api\V1\Booking\BookingRescheduleRequestResource;
use App\Models\Booking;
use App\Models\BookingRescheduleRequest;
use App\Models\BookingSessionReservation;
use App\Services\Booking\BookingRescheduleRequestService;
use App\Services\TrainerAvailabilityService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MemberRescheduleRequestController extends Controller
{
    public function index(Request $request, BookingRescheduleRequestService $service): JsonResponse
    {
        $service->expirePending();
        $memberId = $request->user()->memberProfile?->id;
        $items = BookingRescheduleRequest::query()->with(['reservation', 'requestedBy'])
            ->whereHas('booking', fn ($query) => $query->where('member_profile_id', $memberId))
            ->latest()->get();

        return response()->json(['success' => true, 'data' => BookingRescheduleRequestResource::collection($items), 'meta' => null]);
    }

    public function store(StoreRescheduleRequest $request, Booking $booking, BookingSessionReservation $reservation, BookingRescheduleRequestService $service): JsonResponse
    {
        return $this->run(fn () => $service->create($booking, $reservation, $request->user(), 'member', $request->validated()), 201);
    }

    public function availability(
        Request $request,
        Booking $booking,
        BookingSessionReservation $reservation,
        TrainerAvailabilityService $service
    ): JsonResponse {
        $memberId = $request->user()->memberProfile?->id;
        if ((int) $booking->member_profile_id !== (int) $memberId
            || (int) $reservation->booking_id !== (int) $booking->id) {
            return response()->json(['success' => false, 'message' => 'Booking tidak ditemukan.'], 404);
        }
        $trainer = $booking->trainerProfile()->with('user')->firstOrFail();

        return response()->json([
            'success' => true,
            'message' => 'Ketersediaan reschedule berhasil diambil.',
            'data' => $service->availability($trainer, $reservation->id),
            'meta' => null,
        ]);
    }

    public function accept(Request $request, BookingRescheduleRequest $rescheduleRequest, BookingRescheduleRequestService $service): JsonResponse
    {
        return $this->run(fn () => $service->accept($rescheduleRequest, $request->user(), 'member'));
    }

    public function reject(RejectRescheduleRequest $request, BookingRescheduleRequest $rescheduleRequest, BookingRescheduleRequestService $service): JsonResponse
    {
        return $this->run(fn () => $service->reject($rescheduleRequest, $request->user(), 'member', $request->validated()));
    }

    public function cancel(Request $request, BookingRescheduleRequest $rescheduleRequest, BookingRescheduleRequestService $service): JsonResponse
    {
        return $this->run(fn () => $service->cancel($rescheduleRequest, $request->user()));
    }

    private function run(callable $action, int $code = 200): JsonResponse
    {
        try {
            $item = $action();
        } catch (BookingScheduleException $exception) {
            return response()->json(['success' => false, 'message' => $exception->getMessage()], $exception->httpStatus);
        }
        $item->load(['reservation', 'requestedBy']);

        return response()->json(['success' => true, 'data' => new BookingRescheduleRequestResource($item), 'meta' => null], $code);
    }
}

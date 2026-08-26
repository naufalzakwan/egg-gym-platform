<?php

namespace App\Services\Booking;

use App\Exceptions\BookingScheduleException;
use App\Models\Booking;
use App\Models\BookingRescheduleRequest;
use App\Models\BookingSessionReservation;
use App\Models\TrainerProfile;
use App\Models\User;
use App\Services\Notification\UserNotificationService;
use App\Services\TrainerAvailabilityService;
use App\Services\TrainingProgram\TrainingProgramExecutionOrderService;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

class BookingRescheduleRequestService
{
    public const TIMEZONE = 'Asia/Jakarta';

    public const RESPONSE_HOURS = 1;

    public const ALLOWED_BOOKING_STATUSES = ['payment_verified', 'confirmed'];

    public function __construct(
        private readonly TrainerAvailabilityService $availabilityService,
        private readonly UserNotificationService $notificationService,
        private readonly TrainingProgramExecutionOrderService $executionOrderService
    ) {}

    public function create(
        Booking $booking,
        BookingSessionReservation $reservation,
        User $requester,
        string $requesterRole,
        array $data
    ): BookingRescheduleRequest {
        [$start, $end] = $this->parseInterval(
            $data['proposed_session_date'],
            $data['proposed_start_time'],
            $data['proposed_end_time']
        );

        $request = DB::transaction(function () use (
            $booking, $reservation, $requester, $requesterRole, $data, $start, $end
        ) {
            $trainer = TrainerProfile::query()->with('user')->lockForUpdate()
                ->findOrFail($booking->trainer_profile_id);
            $lockedBooking = Booking::query()->lockForUpdate()->findOrFail($booking->id);
            $lockedReservation = BookingSessionReservation::query()
                ->whereKey($reservation->id)->where('booking_id', $lockedBooking->id)
                ->lockForUpdate()->first();
            $this->assertRequesterOwns($lockedBooking, $requester, $requesterRole);
            $this->assertCanRequest($lockedBooking, $lockedReservation);
            if ($lockedReservation->session_date->toDateString() === $start->toDateString()
                && substr((string) $lockedReservation->start_time, 0, 8) === $start->format('H:i:s')
                && substr((string) $lockedReservation->end_time, 0, 8) === $end->format('H:i:s')) {
                throw new BookingScheduleException('Jadwal baru harus berbeda dari jadwal lama.', 422);
            }
            $this->assertSeriesDateRules($lockedBooking, $lockedReservation, $start);
            $policy = $this->availabilityService->assertWithinSchedulePolicy($trainer, $start, $end);
            $this->assertTargetAvailable($trainer->id, $start, $end, $lockedReservation->id);
            $oldStart = $this->at(
                $lockedReservation->session_date->toDateString(),
                (string) $lockedReservation->start_time
            );
            $expiry = collect([now()->addHour(), $oldStart, $start])->min();
            if ($expiry->lessThanOrEqualTo(now())) {
                throw new BookingScheduleException('Waktu untuk mengajukan reschedule sudah habis.', 422);
            }

            return BookingRescheduleRequest::create([
                'booking_id' => $lockedBooking->id,
                'booking_session_reservation_id' => $lockedReservation->id,
                'active_reservation_id' => $lockedReservation->id,
                'trainer_profile_id' => $trainer->id,
                'requested_by_user_id' => $requester->id,
                'requested_by_role' => $requesterRole,
                'original_trainer_schedule_date_id' => $lockedReservation->trainer_schedule_date_id,
                'original_session_date' => $lockedReservation->session_date,
                'original_start_time' => $lockedReservation->start_time,
                'original_end_time' => $lockedReservation->end_time,
                'proposed_trainer_schedule_date_id' => $policy['date']->id,
                'proposed_session_date' => $start->toDateString(),
                'proposed_start_time' => $start->format('H:i:s'),
                'proposed_end_time' => $end->format('H:i:s'),
                'proposed_duration_minutes' => $start->diffInMinutes($end),
                'reason_type' => $data['reason_type'],
                'reason_note' => $data['reason_note'] ?? null,
                'status' => BookingRescheduleRequest::STATUS_PENDING,
                'expired_at' => $expiry,
            ]);
        }, 3);

        $this->notifyCounterparty($request->load('booking.memberProfile.user', 'booking.trainerProfile.user'));

        return $request->refresh();
    }

    public function accept(BookingRescheduleRequest $request, User $responder, string $role): BookingRescheduleRequest
    {
        return DB::transaction(function () use ($request, $responder, $role) {
            $locked = $this->lockPending($request);
            $this->assertCounterparty($locked, $responder, $role);
            $booking = Booking::query()->lockForUpdate()->findOrFail($locked->booking_id);
            $reservation = BookingSessionReservation::query()->lockForUpdate()
                ->findOrFail($locked->booking_session_reservation_id);
            [$start, $end] = $this->parseInterval(
                $locked->proposed_session_date->toDateString(),
                (string) $locked->proposed_start_time,
                (string) $locked->proposed_end_time
            );
            $trainer = TrainerProfile::query()->with('user')->lockForUpdate()
                ->findOrFail($booking->trainer_profile_id);
            $this->assertSeriesDateRules($booking, $reservation, $start, $locked->id);
            $policy = $this->availabilityService->assertWithinSchedulePolicy($trainer, $start, $end);
            $this->assertTargetAvailable($trainer->id, $start, $end, $reservation->id, $locked->id);
            $reservation->update([
                'trainer_schedule_date_id' => $policy['date']->id,
                'session_date' => $start->toDateString(),
                'start_time' => $start->format('H:i:s'),
                'end_time' => $end->format('H:i:s'),
                'session_duration_minutes' => $start->diffInMinutes($end),
            ]);
            if ((int) $reservation->sequence_order === 1) {
                $booking->update([
                    'trainer_schedule_date_id' => $policy['date']->id,
                    'session_date' => $start->toDateString(),
                    'start_time' => $start->format('H:i:s'),
                    'end_time' => $end->format('H:i:s'),
                    'session_duration_minutes' => $start->diffInMinutes($end),
                ]);
            }
            $locked->update([
                'status' => BookingRescheduleRequest::STATUS_ACCEPTED,
                'active_reservation_id' => null,
                'responded_by_user_id' => $responder->id,
                'responded_at' => now(),
            ]);
            $programSession = $reservation->trainingProgramSession()->first();
            if ($programSession) {
                $this->executionOrderService->reconcile($programSession->training_program_id);
            }

            return $locked->refresh();
        }, 3);
    }

    public function reject(BookingRescheduleRequest $request, User $responder, string $role, array $data): BookingRescheduleRequest
    {
        return DB::transaction(function () use ($request, $responder, $role, $data) {
            $locked = $this->lockPending($request);
            $this->assertCounterparty($locked, $responder, $role);
            $locked->update([
                'status' => BookingRescheduleRequest::STATUS_REJECTED,
                'active_reservation_id' => null,
                'responded_by_user_id' => $responder->id,
                'responded_at' => now(),
                'rejected_reason_type' => $data['rejected_reason_type'],
                'rejected_reason_note' => $data['rejected_reason_note'] ?? null,
            ]);

            return $locked->refresh();
        });
    }

    public function cancel(BookingRescheduleRequest $request, User $requester): BookingRescheduleRequest
    {
        return DB::transaction(function () use ($request, $requester) {
            $locked = $this->lockPending($request);
            if ((int) $locked->requested_by_user_id !== (int) $requester->id) {
                throw new BookingScheduleException('Hanya pengaju yang dapat membatalkan request.', 403);
            }
            $locked->update([
                'status' => BookingRescheduleRequest::STATUS_CANCELLED,
                'active_reservation_id' => null,
                'cancelled_at' => now(),
            ]);

            return $locked->refresh();
        });
    }

    public function expirePending(): int
    {
        $ids = BookingRescheduleRequest::query()->where('status', 'pending')
            ->where('expired_at', '<=', now())->pluck('id');
        foreach ($ids as $id) {
            DB::transaction(function () use ($id) {
                $request = BookingRescheduleRequest::query()->lockForUpdate()->find($id);
                if ($request && $request->status === 'pending' && $request->expired_at->lessThanOrEqualTo(now())) {
                    $request->update(['status' => 'expired', 'active_reservation_id' => null]);
                }
            });
        }

        return $ids->count();
    }

    private function lockPending(BookingRescheduleRequest $request): BookingRescheduleRequest
    {
        $locked = BookingRescheduleRequest::query()->lockForUpdate()->findOrFail($request->id);
        if ($locked->status === 'pending' && $locked->expired_at->lessThanOrEqualTo(now())) {
            $locked->update(['status' => 'expired', 'active_reservation_id' => null]);
        }
        if ($locked->status !== 'pending') {
            throw new BookingScheduleException('Request reschedule sudah tidak aktif.', 422);
        }

        return $locked;
    }

    private function assertCanRequest(Booking $booking, ?BookingSessionReservation $reservation): void
    {
        if (! in_array($booking->status, self::ALLOWED_BOOKING_STATUSES, true)) {
            throw new BookingScheduleException('Reschedule hanya tersedia setelah pembayaran terverifikasi.', 422);
        }
        if (! $reservation || $reservation->status !== 'reserved') {
            throw new BookingScheduleException('Hanya reservation aktif yang dapat di-reschedule.', 422);
        }
        if ($this->at($reservation->session_date->toDateString(), (string) $reservation->start_time)->lessThanOrEqualTo(now())) {
            throw new BookingScheduleException('Sesi yang sudah dimulai tidak dapat di-reschedule.', 422);
        }
        if ($reservation->pendingRescheduleRequest()->exists()) {
            throw new BookingScheduleException('Reservation ini sudah memiliki request reschedule aktif.', 409);
        }
    }

    private function assertRequesterOwns(Booking $booking, User $user, string $role): void
    {
        $valid = $role === 'member'
            ? (int) $booking->memberProfile?->user_id === (int) $user->id
            : (int) $booking->trainerProfile?->user_id === (int) $user->id;
        if (! $valid) {
            throw new BookingScheduleException('Booking tidak ditemukan.', 404);
        }
    }

    private function assertCounterparty(BookingRescheduleRequest $request, User $user, string $role): void
    {
        if ($request->requested_by_role === $role) {
            throw new BookingScheduleException('Pengaju tidak dapat merespons request sendiri.', 403);
        }
        $request->loadMissing('booking.memberProfile.user', 'booking.trainerProfile.user');
        $this->assertRequesterOwns($request->booking, $user, $role);
    }

    private function assertTargetAvailable(int $trainerId, CarbonImmutable $start, CarbonImmutable $end, int $excludeReservationId, ?int $excludeRequestId = null): void
    {
        $bufferStart = $start->subMinutes(15);
        $bufferEnd = $end->addMinutes(15);
        $reservationCollision = BookingSessionReservation::query()
            ->where('trainer_profile_id', $trainerId)->where('status', 'reserved')
            ->where('id', '!=', $excludeReservationId)
            ->whereDate('session_date', $start->toDateString())
            ->whereRaw('TIMESTAMP(session_date,start_time) < ? AND TIMESTAMP(session_date,end_time) > ?', [
                $bufferEnd->format('Y-m-d H:i:s'), $bufferStart->format('Y-m-d H:i:s'),
            ])->lockForUpdate()->exists();
        $holdQuery = BookingRescheduleRequest::query()
            ->where('trainer_profile_id', $trainerId)->where('status', 'pending')
            ->where('expired_at', '>', now())->whereDate('proposed_session_date', $start->toDateString())
            ->whereRaw('TIMESTAMP(proposed_session_date,proposed_start_time) < ? AND TIMESTAMP(proposed_session_date,proposed_end_time) > ?', [
                $bufferEnd->format('Y-m-d H:i:s'), $bufferStart->format('Y-m-d H:i:s'),
            ]);
        if ($excludeRequestId) {
            $holdQuery->where('id', '!=', $excludeRequestId);
        }
        if ($reservationCollision || $holdQuery->lockForUpdate()->exists()) {
            throw new BookingScheduleException('Slot usulan sudah terisi atau sedang di-hold.', 409);
        }
    }

    private function assertSeriesDateRules(
        Booking $booking,
        BookingSessionReservation $reservation,
        CarbonImmutable $proposedStart,
        ?int $excludeRequestId = null
    ): void {
        $oldStart = $this->at(
            $reservation->session_date->toDateString(),
            (string) $reservation->start_time
        );
        if (! $proposedStart->greaterThan($oldStart)) {
            throw new BookingScheduleException(
                'Jadwal baru harus lebih maju dari jadwal sesi saat ini.',
                422
            );
        }

        $siblingDateUsed = BookingSessionReservation::query()
            ->where('booking_id', $booking->id)
            ->where('id', '!=', $reservation->id)
            ->whereDate('session_date', $proposedStart->toDateString())
            ->lockForUpdate()
            ->exists();
        if ($siblingDateUsed) {
            throw new BookingScheduleException(
                'Tanggal tersebut sudah dipakai sesi lain dalam booking ini.',
                422
            );
        }

        $siblingHold = BookingRescheduleRequest::query()
            ->where('booking_id', $booking->id)
            ->where('booking_session_reservation_id', '!=', $reservation->id)
            ->where('status', BookingRescheduleRequest::STATUS_PENDING)
            ->where('expired_at', '>', now())
            ->whereDate('proposed_session_date', $proposedStart->toDateString());
        if ($excludeRequestId !== null) {
            $siblingHold->where('id', '!=', $excludeRequestId);
        }
        if ($siblingHold->lockForUpdate()->exists()) {
            throw new BookingScheduleException(
                'Tanggal tersebut sedang di-hold untuk sesi lain dalam booking ini.',
                409
            );
        }
    }

    private function notifyCounterparty(BookingRescheduleRequest $request): void
    {
        $booking = $request->booking;
        $target = $request->requested_by_role === 'member'
            ? $booking->trainerProfile?->user : $booking->memberProfile?->user;
        if ($target) {
            $this->notificationService->notify($target, 'Permintaan Reschedule',
                'Ada permintaan perubahan jadwal sesi PT yang perlu diputuskan.', 'booking', 'push', true,
                ['reschedule_request_id' => (string) $request->id, 'booking_id' => (string) $booking->id]);
        }
    }

    private function parseInterval(string $date, string $start, string $end): array
    {
        return [$this->at($date, $start), $this->at($date, $end)];
    }

    private function at(string $date, string $time): CarbonImmutable
    {
        return CarbonImmutable::createFromFormat('Y-m-d H:i:s', $date.' '.substr($time, 0, 8), self::TIMEZONE);
    }
}

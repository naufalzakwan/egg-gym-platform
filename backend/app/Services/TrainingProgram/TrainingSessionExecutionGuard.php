<?php

namespace App\Services\TrainingProgram;

use App\Exceptions\BookingScheduleException;
use App\Models\BookingRescheduleRequest;
use App\Models\BookingSessionReservation;
use App\Models\TrainingProgramSession;
use Illuminate\Support\Facades\DB;

class TrainingSessionExecutionGuard
{
    public function __construct(
        private readonly TrainingProgramExecutionOrderService $executionOrderService
    ) {}

    public function assertCanExecute(TrainingProgramSession $session): void
    {
        $current = $this->executionOrderService->reconcile($session->training_program_id);
        $session->refresh();
        if (! $current || $current->id !== $session->id || $session->status !== 'active') {
            throw new BookingScheduleException(
                'Sesi belum dapat dimulai karena ada sesi terjadwal lebih awal yang harus diselesaikan.',
                409
            );
        }
        $reservationId = $session->booking_session_reservation_id;
        if (! $reservationId) {
            return;
        }

        DB::transaction(function () use ($reservationId): void {
            BookingSessionReservation::query()->lockForUpdate()->findOrFail($reservationId);
            $request = BookingRescheduleRequest::query()
                ->where('active_reservation_id', $reservationId)
                ->lockForUpdate()
                ->first();
            if (! $request) {
                return;
            }
            if ($request->status === BookingRescheduleRequest::STATUS_PENDING
                && $request->expired_at->lessThanOrEqualTo(now())) {
                $request->update([
                    'status' => BookingRescheduleRequest::STATUS_EXPIRED,
                    'active_reservation_id' => null,
                ]);

                return;
            }
            if ($request->status === BookingRescheduleRequest::STATUS_PENDING) {
                throw new BookingScheduleException(
                    'Sesi tidak dapat dimulai atau diperbarui selama permintaan reschedule masih menunggu keputusan.',
                    409
                );
            }
        }, 3);
    }
}

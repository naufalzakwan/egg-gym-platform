<?php

namespace App\Services\TrainingProgram;

use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\TrainingProgram;
use Illuminate\Support\Facades\DB;

class CloseTrainingProgramEarlyService
{
    public function close(
        TrainingProgram $program,
        int $trainerProfileId,
        string $reason
    ): TrainingProgram {
        return DB::transaction(function () use ($program, $trainerProfileId, $reason) {
            $locked = TrainingProgram::query()
                ->lockForUpdate()
                ->findOrFail($program->id);
            if ((int) $locked->trainer_profile_id !== $trainerProfileId) {
                throw new \DomainException('Program tidak ditemukan untuk trainer ini.');
            }
            if (in_array($locked->status, ['closed_early', 'archived'], true)) {
                throw new \DomainException('Program sudah berada pada status final.');
            }

            $locked->sessions()
                ->whereNotIn('status', ['completed', 'cancelled'])
                ->lockForUpdate()
                ->get()
                ->each->update(['status' => 'cancelled']);

            if ($locked->booking_id !== null) {
                $booking = Booking::query()->lockForUpdate()->find($locked->booking_id);
                if ($booking) {
                    BookingSessionReservation::query()
                        ->where('booking_id', $booking->id)
                        ->where('status', BookingSessionReservation::STATUS_RESERVED)
                        ->lockForUpdate()
                        ->get()
                        ->each(function (BookingSessionReservation $reservation) use ($reason): void {
                            $reservation->update([
                                'status' => BookingSessionReservation::STATUS_RELEASED,
                                'released_at' => now(),
                                'release_reason' => $reason,
                            ]);
                        });
                    $booking->update(['status' => 'completed']);
                }
            }

            $locked->update([
                'status' => 'closed_early',
                'ended_at' => now()->toDateString(),
            ]);

            return $locked->refresh()->load([
                'sessions.bookingSessionReservation',
                'booking.sessionReservations',
            ]);
        });
    }
}

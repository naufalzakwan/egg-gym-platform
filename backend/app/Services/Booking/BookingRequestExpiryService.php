<?php

namespace App\Services\Booking;

use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Services\Notification\NotificationAutomationService;
use App\Services\Notification\UserNotificationService;
use Carbon\CarbonInterface;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class BookingRequestExpiryService
{
    public const CONFIRMATION_EXPIRY_HOURS = 1;

    public const PAYMENT_EXPIRY_HOURS = 1;

    public const PROOF_VERIFICATION_EXPIRY_HOURS = 1;

    public const EXPIRABLE_STATUSES = [
        'pending',
        'rescheduled',
        'waiting_payment',
        'payment_rejected',
    ];

    public function __construct(
        private readonly UserNotificationService $notificationService,
        private readonly NotificationAutomationService $notificationAutomation,
    ) {}

    public function ensureNotExpired(Booking $booking): Booking
    {
        return DB::transaction(function () use ($booking) {
            $locked = Booking::query()->lockForUpdate()->findOrFail($booking->id);
            if ($this->shouldExpire($locked)) {
                $this->expireLocked($locked);
            }

            return $locked->refresh()->loadMissing('sessionReservations');
        });
    }

    public function expirePendingBookings(): int
    {
        $ids = Booking::query()
            ->whereIn('status', self::EXPIRABLE_STATUSES)
            ->whereNotNull('expired_at')
            ->where('expired_at', '<=', now())
            ->pluck('id');

        $expired = 0;
        foreach ($ids as $id) {
            $booking = Booking::query()->with(['memberProfile.user', 'trainerProfile.user'])->find($id);
            $stage = $booking ? $this->expiryStage($booking) : null;
            if ($booking && $this->ensureNotExpired($booking)->status === 'expired') {
                $expired++;
                $data = ['booking_id' => (string) $booking->id, 'stage' => $stage, 'target' => 'schedule'];
                if ($booking->memberProfile?->user) {
                    $this->notificationService->notify(
                        $booking->memberProfile->user,
                        'Booking kedaluwarsa',
                        $stage === 'member_payment'
                            ? 'Booking dibatalkan karena bukti pembayaran tidak diunggah sebelum batas waktu.'
                            : 'Booking kedaluwarsa karena tidak dikonfirmasi sebelum batas waktu.',
                        'booking', 'push', true, $data,
                        "booking:{$booking->id}:expired:{$stage}", 'high'
                    );
                }
                if ($stage === 'trainer_confirmation' && $booking->trainerProfile?->user) {
                    $this->notificationService->notify($booking->trainerProfile->user, 'Booking kedaluwarsa', 'Booking kedaluwarsa karena tidak dikonfirmasi sebelum batas waktu.', 'booking', 'push', true, $data + ['target' => 'trainer_schedule'], "booking:{$booking->id}:expired:trainer", 'high');
                }
                $this->notificationAutomation->notifyAdmins('Booking kedaluwarsa', 'Booking PT kedaluwarsa sesuai aturan deadline.', 'booking', $data + ['target' => 'booking_admin'], "booking:{$booking->id}:expired:admin", 'high');
            }
        }

        $this->notifyOverduePaymentVerifications();

        return $expired;
    }

    public function notifyOverduePaymentVerifications(): int
    {
        $ids = Booking::query()
            ->where('status', 'payment_uploaded')
            ->whereNotNull('expired_at')
            ->where('expired_at', '<=', now())
            ->whereNull('verification_overdue_notified_at')
            ->pluck('id');
        $notified = 0;

        foreach ($ids as $id) {
            $booking = DB::transaction(function () use ($id) {
                $locked = Booking::query()->with('trainerProfile.user')->lockForUpdate()->find($id);
                if (! $locked || ! $this->isPaymentVerificationOverdue($locked)
                    || $locked->verification_overdue_notified_at !== null) {
                    return null;
                }
                $locked->update(['verification_overdue_notified_at' => now()]);

                return $locked;
            });
            $trainerUser = $booking?->trainerProfile?->user;
            if (! $booking || ! $trainerUser) {
                continue;
            }

            $this->notificationService->notify(
                $trainerUser,
                'Verifikasi Pembayaran Terlambat',
                'Pembayaran member belum Anda verifikasi. Segera tekan Valid atau Tolak.',
                'payment',
                'push',
                true,
                [
                    'booking_id' => (string) $booking->id,
                    'status' => 'payment_uploaded',
                    'is_payment_verification_overdue' => 'true',
                    'target' => 'trainer_schedule',
                ],
                "booking:{$booking->id}:payment_verification_overdue:trainer:{$booking->expired_at?->timestamp}",
                'high'
            );
            if ($booking->memberProfile?->user) {
                $this->notificationService->notify(
                    $booking->memberProfile->user,
                    'Verifikasi pembayaran terlambat',
                    'Bukti pembayaran Anda masih menunggu trainer. Admin telah diberitahu untuk follow-up.',
                    'payment', 'push', true,
                    ['booking_id' => (string) $booking->id, 'target' => 'booking_payment'],
                    "booking:{$booking->id}:payment_verification_overdue:member:{$booking->expired_at?->timestamp}", 'high'
                );
            }
            $this->notificationAutomation->notifyAdmins(
                'PT belum verifikasi pembayaran',
                'Trainer belum memverifikasi bukti pembayaran member. Silakan follow-up trainer.',
                'payment',
                [
                    'booking_id' => (string) $booking->id,
                    'member_name' => $booking->memberProfile?->user?->name,
                    'trainer_name' => $booking->trainerProfile?->user?->name,
                    'trainer_phone' => $booking->trainerProfile?->user?->phone,
                    'trainer_email' => $booking->trainerProfile?->user?->email,
                    'proof_path' => $booking->payment_proof_path,
                    'target' => 'booking_admin',
                ],
                "booking:{$booking->id}:payment_verification_overdue:admin:{$booking->expired_at?->timestamp}", 'high'
            );
            $notified++;
        }

        return $notified;
    }

    public function syncCollection(Collection $bookings): Collection
    {
        return $bookings->map(fn (Booking $booking) => $this->ensureNotExpired($booking));
    }

    public function resolveExpiryTimestamp(
        string $status,
        ?CarbonInterface $from = null,
        ?CarbonInterface $firstSessionStart = null
    ): ?CarbonInterface {
        $base = ($from ?? now())->copy();

        $deadline = match ($status) {
            'pending', 'rescheduled' => $base->addHours(self::CONFIRMATION_EXPIRY_HOURS),
            'waiting_payment', 'payment_rejected' => $base->addHours(self::PAYMENT_EXPIRY_HOURS),
            'payment_uploaded' => $base->addHours(self::PROOF_VERIFICATION_EXPIRY_HOURS),
            default => null,
        };

        if ($deadline !== null && $firstSessionStart !== null
            && $firstSessionStart->lessThan($deadline)) {
            return $firstSessionStart->copy();
        }

        return $deadline;
    }

    public function resolveBookingExpiryTimestamp(
        Booking $booking,
        string $status,
        ?CarbonInterface $from = null
    ): ?CarbonInterface {
        return $this->resolveExpiryTimestamp(
            $status,
            $from,
            $this->firstSessionStart($booking)
        );
    }

    public function shouldExpire(Booking $booking): bool
    {
        if (! in_array($booking->status, self::EXPIRABLE_STATUSES, true)) {
            return false;
        }

        if (! $booking->expired_at) {
            return false;
        }

        return $booking->expired_at->lessThanOrEqualTo(now());
    }

    public function isPaymentVerificationOverdue(Booking $booking): bool
    {
        return $booking->status === 'payment_uploaded'
            && $booking->expired_at !== null
            && $booking->expired_at->lessThanOrEqualTo(now());
    }

    public function verificationOverdueSeconds(Booking $booking): int
    {
        if (! $this->isPaymentVerificationOverdue($booking)) {
            return 0;
        }

        return max(0, $booking->expired_at->diffInSeconds(now()));
    }

    public function remainingSeconds(Booking $booking): int
    {
        $booking = $this->ensureNotExpired($booking);

        if (! $booking->expired_at) {
            return 0;
        }

        return max(0, now()->diffInSeconds($booking->expired_at, false));
    }

    public function expiryStage(Booking $booking): ?string
    {
        return match ($booking->status) {
            'pending', 'rescheduled' => 'trainer_confirmation',
            'waiting_payment', 'payment_rejected' => 'member_payment',
            'payment_uploaded' => 'trainer_verification',
            'expired' => $this->inferExpiredStage($booking),
            default => null,
        };
    }

    private function expireLocked(Booking $booking): void
    {
        $stage = $this->expiryStage($booking);
        $reason = match ($stage) {
            'trainer_confirmation' => 'Waktu konfirmasi trainer telah habis.',
            'member_payment' => 'Waktu pembayaran telah habis.',
            'trainer_verification' => 'Waktu verifikasi pembayaran telah habis.',
            default => 'Batas waktu booking telah habis.',
        };

        $booking->sessionReservations()
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

        $booking->update([
            'status' => 'expired',
            'trainer_note' => $booking->trainer_note
                ? $booking->trainer_note.' | '.$reason
                : $reason,
        ]);
    }

    private function inferExpiredStage(Booking $booking): ?string
    {
        $note = strtolower((string) $booking->trainer_note);
        if (str_contains($note, 'konfirmasi trainer')) {
            return 'trainer_confirmation';
        }
        if (str_contains($note, 'verifikasi pembayaran')) {
            return 'trainer_verification';
        }
        if (str_contains($note, 'pembayaran telah')) {
            return 'member_payment';
        }

        return null;
    }

    private function firstSessionStart(Booking $booking): ?CarbonInterface
    {
        $reservation = $booking->sessionReservations()
            ->orderBy('sequence_order')
            ->first();
        $date = $reservation?->session_date?->toDateString()
            ?? $booking->session_date?->toDateString();
        $time = $reservation?->start_time ?? $booking->start_time;
        if ($date === null || $time === null) {
            return null;
        }

        return \Carbon\CarbonImmutable::createFromFormat(
            'Y-m-d H:i:s',
            $date.' '.substr((string) $time, 0, 8),
            config('app.timezone')
        );
    }
}

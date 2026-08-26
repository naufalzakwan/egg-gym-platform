<?php

namespace App\Services\Notification;

use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\TrainingProgram;
use App\Models\User;
use Illuminate\Support\Carbon;

class NotificationAutomationService
{
    public function __construct(private readonly UserNotificationService $notifications) {}

    public function notifyAdmins(
        string $title,
        string $message,
        string $type,
        array $data,
        string $eventKey,
        string $priority = 'normal',
    ): int {
        $admins = User::query()
            ->where('status', 'active')
            ->whereHas('role', fn ($role) => $role->where('name', 'admin'))
            ->get();
        foreach ($admins as $admin) {
            $this->notifications->notify($admin, $title, $message, $type, 'in_app', false, $data, $eventKey, $priority);
        }

        return $admins->count();
    }

    public function processMinuteReminders(): int
    {
        return $this->deadlineReminders() + $this->sessionReminders();
    }

    public function processDailyReminders(): int
    {
        return $this->todaySessionReminders() + $this->membershipReminders();
    }

    private function deadlineReminders(): int
    {
        $bookings = Booking::query()
            ->with(['memberProfile.user', 'trainerProfile.user'])
            ->whereIn('status', ['pending', 'rescheduled', 'waiting_payment', 'payment_rejected', 'payment_uploaded'])
            ->whereBetween('expired_at', [now()->addMinutes(19), now()->addMinutes(21)])
            ->get();
        $count = 0;

        foreach ($bookings as $booking) {
            $deadline = $booking->expired_at?->timestamp ?? 0;
            $data = ['booking_id' => (string) $booking->id, 'deadline' => $booking->expired_at?->toIso8601String()];
            if (in_array($booking->status, ['pending', 'rescheduled'], true) && $booking->trainerProfile?->user) {
                $this->notifications->notify(
                    $booking->trainerProfile->user,
                    'Konfirmasi booking hampir habis',
                    'Segera konfirmasi atau tolak booking agar slot tidak kedaluwarsa otomatis.',
                    'booking', 'push', true,
                    $data + ['target' => 'trainer_schedule'],
                    "booking:{$booking->id}:trainer_confirm_20m:{$deadline}", 'high'
                );
                $count++;
            } elseif (in_array($booking->status, ['waiting_payment', 'payment_rejected'], true) && $booking->memberProfile?->user) {
                $rejected = $booking->status === 'payment_rejected';
                $this->notifications->notify(
                    $booking->memberProfile->user,
                    $rejected ? 'Batas upload ulang hampir habis' : 'Batas pembayaran hampir habis',
                    $rejected
                        ? 'Segera upload ulang bukti pembayaran agar booking tidak kedaluwarsa.'
                        : 'Segera lakukan pembayaran dan upload bukti agar booking tidak kedaluwarsa.',
                    'payment', 'push', true,
                    $data + ['target' => 'booking_payment'],
                    "booking:{$booking->id}:member_payment_20m:{$deadline}", 'high'
                );
                $count++;
            } elseif ($booking->status === 'payment_uploaded' && $booking->trainerProfile?->user) {
                $this->notifications->notify(
                    $booking->trainerProfile->user,
                    'Verifikasi pembayaran hampir terlambat',
                    'Bukti pembayaran member belum Anda verifikasi. Segera tekan Valid atau Tolak.',
                    'payment', 'push', true,
                    $data + ['target' => 'trainer_schedule'],
                    "booking:{$booking->id}:payment_verification_20m:{$deadline}", 'high'
                );
                $this->notifyAdmins(
                    'Verifikasi pembayaran hampir terlambat',
                    'Trainer belum memverifikasi bukti pembayaran member dan batas waktu hampir habis.',
                    'payment', $data + ['target' => 'booking_admin'],
                    "booking:{$booking->id}:admin_payment_verification_20m:{$deadline}", 'high'
                );
                $count++;
            }
        }

        return $count;
    }

    private function sessionReminders(): int
    {
        $reservations = BookingSessionReservation::query()
            ->with(['booking.memberProfile.user', 'booking.trainerProfile.user'])
            ->where('status', BookingSessionReservation::STATUS_RESERVED)
            ->whereDate('session_date', now()->toDateString())
            ->get()
            ->filter(fn ($reservation) => $this->sessionStart($reservation)?->betweenIncluded(now()->addMinutes(19), now()->addMinutes(21)));
        $count = 0;

        foreach ($reservations as $reservation) {
            $booking = $reservation->booking;
            if (! $booking || ! in_array($booking->status, ['payment_verified', 'confirmed', 'rescheduled', 'completed'], true)) {
                continue;
            }
            $start = $this->sessionStart($reservation);
            $key = "reservation:{$reservation->id}:session_20m:{$start?->timestamp}";
            $data = ['booking_id' => (string) $booking->id, 'reservation_id' => (string) $reservation->id, 'target' => 'schedule'];
            if ($booking->memberProfile?->user) {
                $this->notifications->notify($booking->memberProfile->user, 'Sesi dimulai sebentar lagi', 'Sesi latihan Anda akan dimulai dalam 20 menit.', 'schedule', 'push', true, $data, $key.':member');
            }
            if ($booking->trainerProfile?->user) {
                $this->notifications->notify($booking->trainerProfile->user, 'Sesi dimulai sebentar lagi', 'Sesi dengan member akan dimulai dalam 20 menit.', 'schedule', 'push', true, $data + ['target' => 'trainer_schedule'], $key.':trainer');
            }
            if (! TrainingProgram::query()->where('booking_id', $booking->id)->exists()) {
                if ($booking->trainerProfile?->user) {
                    $this->notifications->notify($booking->trainerProfile->user, 'Program belum dibuat untuk sesi segera', 'Sesi member akan dimulai dalam 20 menit, tetapi program latihan belum dibuat.', 'program', 'push', true, ['booking_id' => (string) $booking->id, 'target' => 'trainer_program'], "booking:{$booking->id}:program_missing_20m:{$start?->timestamp}", 'high');
                }
                $this->notifyAdmins('PT belum membuat program latihan', 'Trainer belum membuat program untuk member yang sesinya akan segera dimulai.', 'program', ['booking_id' => (string) $booking->id, 'target' => 'booking_admin'], "booking:{$booking->id}:admin_program_missing_20m:{$start?->timestamp}", 'high');
            }
            $count++;
        }

        return $count;
    }

    private function todaySessionReminders(): int
    {
        $reservations = BookingSessionReservation::query()
            ->with(['booking.memberProfile.user', 'booking.trainerProfile.user'])
            ->where('status', BookingSessionReservation::STATUS_RESERVED)
            ->whereDate('session_date', now()->toDateString())
            ->get();
        foreach ($reservations as $reservation) {
            $booking = $reservation->booking;
            if (! $booking || ! in_array($booking->status, ['payment_verified', 'confirmed', 'rescheduled', 'completed'], true)) {
                continue;
            }
            $key = "reservation:{$reservation->id}:session_today:".now()->toDateString();
            if ($booking->memberProfile?->user) {
                $this->notifications->notify($booking->memberProfile->user, 'Sesi latihan hari ini', 'Anda memiliki sesi latihan dengan trainer hari ini.', 'schedule', 'push', true, ['booking_id' => (string) $booking->id, 'target' => 'schedule'], $key.':member');
            }
            if ($booking->trainerProfile?->user) {
                $this->notifications->notify($booking->trainerProfile->user, 'Sesi latihan hari ini', 'Anda memiliki sesi latihan dengan member hari ini.', 'schedule', 'push', true, ['booking_id' => (string) $booking->id, 'target' => 'trainer_schedule'], $key.':trainer');
            }
        }

        return $reservations->count();
    }

    private function membershipReminders(): int
    {
        $count = 0;
        MemberProfile::query()->with(['user', 'memberships.membershipPlan'])->chunkById(100, function ($members) use (&$count) {
            foreach ($members as $member) {
                if (! $member->user) {
                    continue;
                }
                $end = MemberMembership::activeChainEndDate($member->memberships);
                if (! $end) {
                    continue;
                }
                $days = now()->startOfDay()->diffInDays($end->copy()->startOfDay(), false);
                if (in_array($days, [3, 1], true)) {
                    $this->notifications->notify($member->user, 'Membership hampir berakhir', 'Membership Anda akan segera berakhir. Perpanjang agar akses tetap aktif.', 'membership', 'push', true, ['target' => 'membership', 'end_date' => $end->toDateString()], "member:{$member->id}:membership_expiring:{$days}d:{$end->toDateString()}");
                    $count++;
                } elseif ($days === -1) {
                    $this->notifications->notify($member->user, 'Membership berakhir', 'Membership Anda sudah berakhir. Silakan pilih paket untuk mengaktifkan kembali akses.', 'membership', 'push', true, ['target' => 'membership', 'end_date' => $end->toDateString()], "member:{$member->id}:membership_expired:{$end->toDateString()}");
                    $count++;
                }
            }
        });

        return $count;
    }

    private function sessionStart(BookingSessionReservation $reservation): ?Carbon
    {
        if (! $reservation->session_date || ! $reservation->start_time) {
            return null;
        }

        return Carbon::parse($reservation->session_date->toDateString().' '.$reservation->start_time, config('app.timezone'));
    }
}

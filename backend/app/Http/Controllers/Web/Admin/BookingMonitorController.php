<?php

namespace App\Http\Controllers\Web\Admin;

use App\Exceptions\BookingScheduleException;
use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\TrainerProfile;
use App\Models\TrainerSessionProgress;
use App\Services\ActivityLogger;
use App\Services\Booking\BookingRequestExpiryService;
use App\Services\Booking\BookingScheduleService;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\View\View;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class BookingMonitorController extends Controller
{
    /**
     * Pemetaan 4 tab UI (MD) ke status booking nyata di DB.
     */
    private const TAB_STATUS_MAP = [
        'menunggu' => ['pending', 'rescheduled'],
        'dikonfirmasi' => ['confirmed', 'waiting_payment', 'payment_uploaded', 'payment_rejected', 'payment_verified'],
        'selesai' => ['completed'],
        'ditolak' => ['cancelled', 'expired', 'rejected'],
    ];

    public function index(Request $request, BookingRequestExpiryService $expiryService): View
    {
        $tab = $request->query('status', 'menunggu');
        if (! array_key_exists($tab, self::TAB_STATUS_MAP)) {
            $tab = 'menunggu';
        }
        $search = trim((string) $request->query('search', ''));

        $bookings = Booking::query()
            ->with([
                'memberProfile.user',
                'trainerProfile.user',
                'sessionReservations' => fn ($query) => $query
                    ->orderBy('session_date')
                    ->orderBy('start_time')
                    ->orderBy('sequence_order'),
            ])
            ->whereHas('memberProfile.user')
            ->whereHas('trainerProfile.user')
            ->whereIn('status', self::TAB_STATUS_MAP[$tab])
            ->when($search !== '', function ($query) use ($search) {
                $query->where(function ($inner) use ($search) {
                    $inner->where('session_title', 'like', '%'.$search.'%')
                        ->orWhere('location', 'like', '%'.$search.'%')
                        ->orWhere('status', 'like', '%'.$search.'%')
                        ->orWhere('id', 'like', '%'.ltrim($search, '#').'%')
                        ->orWhere('session_date', 'like', '%'.$search.'%')
                        ->orWhereHas('sessionReservations', fn ($reservation) => $reservation
                            ->where('session_date', 'like', '%'.$search.'%'))
                        ->orWhereHas('memberProfile.user', fn ($u) => $u->where('name', 'like', '%'.$search.'%')->orWhere('email', 'like', '%'.$search.'%'))
                        ->orWhereHas('trainerProfile.user', fn ($u) => $u->where('name', 'like', '%'.$search.'%')->orWhere('email', 'like', '%'.$search.'%'));
                });
            })
            ->orderBy('session_date')
            ->orderBy('start_time')
            ->paginate(5)
            ->withQueryString();

        return view('admin.bookings.index', [
            'bookings' => $bookings,
            'tab' => $tab,
            'search' => $search,
            'counts' => $this->tabCounts(),
            'liveSessions' => $this->buildLiveSessions(),
            'availableTrainers' => TrainerProfile::query()
                ->with('user')
                ->whereHas('user', fn ($q) => $q->where('status', 'active'))
                ->get()
                ->map(fn ($t) => ['id' => $t->id, 'name' => $t->user?->name ?? 'Nama PT tidak tersedia']),
            'liveProgressUrl' => route('admin.bookings.live-progress'),
            'overdueVerifications' => Booking::query()
                ->with(['memberProfile.user', 'trainerProfile.user'])
                ->where('status', 'payment_uploaded')
                ->whereNotNull('expired_at')
                ->where('expired_at', '<=', now())
                ->orderBy('expired_at')
                ->get()
                ->map(fn (Booking $booking) => [
                    'id' => $booking->id,
                    'member_name' => $booking->memberProfile?->user?->name ?? '-',
                    'trainer_name' => $booking->trainerProfile?->user?->name ?? '-',
                    'trainer_phone' => $booking->trainerProfile?->user?->phone ?: '-',
                    'trainer_email' => $booking->trainerProfile?->user?->email ?: '-',
                    'uploaded_at' => $booking->payment_proof_uploaded_at,
                    'overdue_label' => $this->durationLabel($expiryService->verificationOverdueSeconds($booking)),
                    'status' => $booking->status,
                    'proof_url' => $booking->payment_proof_path
                        ? Storage::disk('public')->url($booking->payment_proof_path)
                        : null,
                ]),
        ]);
    }

    private function durationLabel(int $seconds): string
    {
        $hours = intdiv($seconds, 3600);
        $minutes = intdiv($seconds % 3600, 60);

        return $hours > 0 ? "{$hours} jam {$minutes} menit" : max(1, $minutes).' menit';
    }

    public function liveProgress(): JsonResponse
    {
        return response()->json([
            'data' => $this->buildLiveSessions(),
            'refreshed_at' => CarbonImmutable::now('Asia/Jakarta')->toIso8601String(),
        ]);
    }

    /**
     * Konfirmasi booking (admin) — mirror alur trainer: pending/rescheduled →
     * waiting_payment (member diminta membayar), agar alur pembayaran tetap utuh.
     */
    public function confirm(Booking $booking): RedirectResponse
    {
        if (! in_array($booking->status, ['pending', 'rescheduled'], true)) {
            return back()->with('error', 'Booking ini tidak dalam status menunggu konfirmasi.');
        }

        $booking->update(['status' => 'waiting_payment']);
        ActivityLogger::logUpdated($booking, [], "Booking dikonfirmasi admin: #{$booking->id}");

        return redirect()
            ->route('admin.bookings.index', ['status' => 'dikonfirmasi'])
            ->with('success', 'Booking berhasil dikonfirmasi. Member diminta melakukan pembayaran.');
    }

    /**
     * Tolak booking (admin) → cancelled.
     */
    public function reject(Booking $booking): RedirectResponse
    {
        if (in_array($booking->status, ['completed', 'cancelled'], true)) {
            return back()->with('error', 'Booking ini sudah final dan tidak bisa ditolak.');
        }

        $booking->update(['status' => 'cancelled']);
        ActivityLogger::logUpdated($booking, [], "Booking ditolak admin: #{$booking->id}");

        return redirect()
            ->route('admin.bookings.index', ['status' => 'ditolak'])
            ->with('success', 'Booking berhasil ditolak.');
    }

    /**
     * Ganti Personal Trainer untuk sebuah booking (reassign).
     */
    public function reassignTrainer(
        Request $request,
        Booking $booking,
        BookingScheduleService $scheduleService
    ): RedirectResponse {
        $validated = $request->validate([
            'trainer_profile_id' => ['required', 'exists:trainer_profiles,id'],
        ]);

        $oldData = ['trainer_profile_id' => $booking->trainer_profile_id];

        try {
            $booking = $scheduleService->reassign(
                $booking,
                (int) $validated['trainer_profile_id']
            );
        } catch (BookingScheduleException $exception) {
            return back()->with('error', $exception->getMessage());
        }

        ActivityLogger::logUpdated(
            $booking,
            $oldData,
            "PT booking #{$booking->id} diubah ke {$booking->trainerProfile?->user?->name}"
        );

        return back()->with('success', 'Personal Trainer berhasil diubah ke '.($booking->trainerProfile?->user?->name ?? 'Coach').'.');
    }

    /**
     * Jumlah booking per tab (untuk badge counter).
     */
    private function tabCounts(): array
    {
        $counts = [];
        foreach (self::TAB_STATUS_MAP as $tab => $statuses) {
            $counts[$tab] = Booking::query()->whereIn('status', $statuses)->count();
        }

        return $counts;
    }

    /**
     * Progress dianggap live sepanjang tanggal reservation selama sesi valid
     * sudah dimulai atau member sudah menyatakan siap. Batas jam tidak dipakai
     * agar checklist yang sudah tersimpan tetap dapat dipantau sepanjang hari.
     */
    private function buildLiveSessions(): array
    {
        $now = CarbonImmutable::now('Asia/Jakarta');

        return TrainerSessionProgress::query()
            ->where('status', 'active')
            ->where(function ($query) {
                $query->where('progress_percent', '>', 0)
                    ->orWhereHas('exercises', fn ($exercise) => $exercise
                        ->where('completed_sets', '>', 0))
                    ->orWhereHas('trainingProgramSession', fn ($session) => $session
                        ->where('member_ready', true));
            })
            ->whereHas('memberProfile.user')
            ->whereHas('trainerProfile.user')
            ->whereHas('trainingProgram', fn ($program) => $program
                ->where('status', 'active'))
            ->whereHas('trainingProgramSession', fn ($session) => $session
                ->where('status', 'active'))
            ->whereHas('trainingProgramSession.bookingSessionReservation', function ($query) use ($now) {
                $query
                    ->where('status', 'reserved')
                    ->whereDate('session_date', $now->toDateString())
                    ->whereHas('booking', function ($booking) {
                        $booking->where(function ($status) {
                            $status
                                ->whereIn('status', ['payment_verified', 'confirmed'])
                                ->orWhere(function ($rescheduled) {
                                    $rescheduled
                                        ->where('status', 'rescheduled')
                                        ->whereNotNull('payment_verified_at');
                                });
                        });
                    });
            })
            ->with([
                'memberProfile.user',
                'trainerProfile.user',
                'trainingProgram',
                'trainingProgramSession.bookingSessionReservation.booking',
                'exercises',
            ])
            ->orderByDesc('progress_percent')
            ->limit(6)
            ->get()
            ->map(function (TrainerSessionProgress $p) {
                $session = $p->trainingProgramSession;
                $reservation = $session?->bookingSessionReservation;
                $booking = $reservation?->booking;
                $totalSets = $p->exercises->sum(fn ($exercise) => (int) $exercise->total_sets);
                $completedSets = $p->exercises->sum(fn ($exercise) => min(
                    (int) $exercise->completed_sets,
                    (int) $exercise->total_sets
                ));
                $progress = $totalSets > 0
                    ? (int) round(($completedSets / $totalSets) * 100)
                    : (int) round($p->progress_percent);
                $totalExercises = $p->exercises->count();
                $completedExercises = $p->exercises->filter(fn ($exercise) => (int) $exercise->total_sets > 0
                    && (int) $exercise->completed_sets >= (int) $exercise->total_sets)->count();

                return [
                    'id' => $p->id,
                    'member_name' => $p->memberProfile->user->name,
                    'member_avatar_url' => $p->memberProfile?->user?->avatar_url,
                    'member_avatar_public_url' => $this->publicAvatarUrl($p->memberProfile?->user?->avatar_url),
                    'coach_name' => $p->trainerProfile->user->name,
                    'progress' => max(0, min(100, $progress)),
                    'program_name' => $p->trainingProgram?->title,
                    'session_name' => $session?->title,
                    'focus' => $session?->focus,
                    'session_number' => $session?->sequence_order,
                    'completed_exercises' => $completedExercises,
                    'total_exercises' => $totalExercises,
                    'completed_sets' => $completedSets,
                    'total_sets' => $totalSets,
                    'booking_id' => $booking?->id,
                    'program_id' => $p->training_program_id,
                    'session_id' => $p->training_program_session_id,
                    'schedule_date' => $reservation?->session_date?->toDateString(),
                    'start_time' => $reservation?->start_time,
                    'end_time' => $reservation?->end_time,
                    'status' => 'active',
                ];
            })
            ->all();
    }

    private function publicAvatarUrl(?string $path): ?string
    {
        if ($path === null || $path === '') {
            return null;
        }
        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }

        return Storage::disk('public')->url($path);
    }
}

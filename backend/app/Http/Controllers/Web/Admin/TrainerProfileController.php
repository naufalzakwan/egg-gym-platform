<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\BookingRescheduleRequest;
use App\Models\BookingSessionReservation;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerRating;
use App\Models\User;
use App\Services\ActivityLogger;
use App\Services\Admin\TrainerRevenueService;
use App\Services\TrainerAvailabilityService;
use App\Services\TrainerScheduleMaterializer;
use App\Support\TrainerSpecialty;
use App\Support\TrainerTier;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\View\View;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Throwable;

class TrainerProfileController extends Controller
{
    public function index(Request $request): View
    {
        $validatedQuery = $request->validate([
            'search' => ['nullable', 'string', 'max:150'],
            'specialty' => ['nullable', Rule::in(TrainerSpecialty::labels())],
        ]);
        $search = trim((string) ($validatedQuery['search'] ?? ''));
        $specialty = trim((string) ($validatedQuery['specialty'] ?? ''));

        $trainers = TrainerProfile::query()
            ->with('user')
            ->withRatingStats()
            ->when($search !== '', function ($query) use ($search) {
                $query->where(function ($innerQuery) use ($search) {
                    $innerQuery->where('specialty', 'like', '%'.$search.'%')
                        ->orWhere('specialties', 'like', '%'.$search.'%')
                        ->orWhere('bio', 'like', '%'.$search.'%')
                        ->orWhere('tier', 'like', '%'.$search.'%')
                        ->orWhereHas('user', function ($userQuery) use ($search) {
                            $userQuery->where('name', 'like', '%'.$search.'%')
                                ->orWhere('email', 'like', '%'.$search.'%')
                                ->orWhere('phone', 'like', '%'.$search.'%')
                                ->orWhere('status', 'like', '%'.$search.'%');
                        });
                });
            })
            ->when($specialty !== '', function ($query) use ($specialty) {
                $values = TrainerSpecialty::databaseValuesFor($specialty);
                $query->where(function ($innerQuery) use ($values, $specialty) {
                    $innerQuery->whereJsonContains('specialties', $specialty);
                    foreach ($values as $value) {
                        $innerQuery->orWhereRaw('LOWER(specialty) = ?', [strtolower($value)]);
                    }
                });
            })
            ->orderByDesc('rating_average')
            ->orderByDesc('reviews_count')
            ->orderBy('trainer_profiles.id')
            ->get();

        // Data tampilan per coach (jumlah klien aktif = data nyata dari booking).
        $coaches = $trainers->map(function (TrainerProfile $t) {
            $activeClients = $t->activeQuotaMembers();
            $isActive = ($t->user?->status ?? 'active') === 'active';

            return [
                'model' => $t,
                'id' => $t->id,
                'name' => $t->user?->name ?? 'Coach',
                'specialty' => TrainerSpecialty::label($t->specialty),
                'specialties' => $t->specialty_labels,
                'tier' => $t->tier_label,
                'rating' => $t->reviews_count > 0
                    ? round((float) $t->rating_average, 2)
                    : null,
                'reviews_count' => (int) $t->reviews_count,
                'active_clients' => $activeClients,
                'max_clients' => (int) ($t->max_clients ?? 30),
                'is_active' => $isActive,
                'joined' => $t->created_at?->locale('id')->translatedFormat('M Y') ?? '-',
                'avatar_url' => $t->user?->avatar_url,
            ];
        })->values();

        // 2 coach unggulan (rating tertinggi) sebagai featured card, sisanya queue.
        $featured = $coaches->take(2)->values();
        $queue = $coaches->slice(2)->values();

        // Daftar spesialisasi unik untuk filter tabs.
        $specialties = collect(TrainerSpecialty::labels());

        $ratingStats = TrainerRating::query()
            ->valid()
            ->selectRaw('AVG(rating) as average_rating, COUNT(*) as reviews_count')
            ->first();

        return view('admin.trainer-profiles.index', [
            'featured' => $featured,
            'queue' => $queue,
            'totalCoaches' => $coaches->count(),
            'search' => $search,
            'specialty' => $specialty,
            'specialties' => $specialties,
            'specialtyOptions' => TrainerSpecialty::labels(),
            'banner' => [
                'active_coaches' => TrainerProfile::query()
                    ->whereHas('user', fn ($q) => $q->where('status', 'active'))
                    ->count(),
                'avg_satisfaction' => $ratingStats->reviews_count > 0
                    ? round((float) $ratingStats->average_rating, 2)
                    : null,
                'reviews_count' => (int) $ratingStats->reviews_count,
            ],
        ]);
    }

    /**
     * Nonaktifkan / aktifkan akun coach (tanpa menghapus data).
     */
    public function toggleStatus(TrainerProfile $trainerProfile): RedirectResponse
    {
        $user = $trainerProfile->user;
        if (! $user) {
            return back()->with('error', 'Akun coach tidak ditemukan.');
        }

        $newStatus = $user->status === 'active' ? 'inactive' : 'active';
        $oldStatus = $user->status;
        $user->update(['status' => $newStatus]);

        ActivityLogger::log(
            action: 'updated',
            model: $trainerProfile,
            oldData: ['account_status' => $oldStatus],
            newData: ['account_status' => $newStatus],
            description: "Status coach diubah menjadi {$newStatus}: {$user->name}",
        );

        return redirect()
            ->route('admin.trainer-profiles.index')
            ->with('success', 'Status coach berhasil diubah menjadi '.($newStatus === 'active' ? 'aktif' : 'nonaktif').'.');
    }

    public function schedule(
        Request $request,
        TrainerProfile $trainerProfile,
        TrainerScheduleMaterializer $materializer
    ): View {
        $validated = $request->validate([
            'month' => ['nullable', 'date_format:Y-m'],
        ]);
        $now = CarbonImmutable::now(TrainerScheduleMaterializer::TIMEZONE);
        $currentMonth = $now->startOfMonth();
        $month = CarbonImmutable::createFromFormat(
            '!Y-m',
            $validated['month'] ?? $currentMonth->format('Y-m'),
            TrainerScheduleMaterializer::TIMEZONE
        )->startOfMonth();
        $monthEnd = $month->endOfMonth()->startOfDay();

        $trainerProfile->load('user');
        if ($monthEnd->greaterThanOrEqualTo($now->startOfDay())) {
            $materializer->materializeTrainer(
                $trainerProfile,
                $month->greaterThan($now->startOfDay()) ? $month : $now->startOfDay(),
                $monthEnd
            );
        }
        $reservations = BookingSessionReservation::query()
            ->with([
                'memberProfile.user',
                'booking',
                'trainingProgramSession.trainingProgram',
                'rescheduleRequests' => fn ($query) => $query
                    ->where('status', BookingRescheduleRequest::STATUS_PENDING)
                    ->orderByDesc('id'),
            ])
            ->where('trainer_profile_id', $trainerProfile->id)
            ->whereBetween('session_date', [$month->toDateString(), $monthEnd->toDateString()])
            ->orderBy('session_date')
            ->orderBy('start_time')
            ->get();

        $sessions = $reservations->map(function (BookingSessionReservation $reservation): array {
            $booking = $reservation->booking;
            $programSession = $reservation->trainingProgramSession;

            return [
                'key' => 'reservation-'.$reservation->id,
                'date' => $reservation->session_date->toDateString(),
                'start_time' => substr((string) $reservation->start_time, 0, 5),
                'end_time' => substr((string) $reservation->end_time, 0, 5),
                'member_name' => $reservation->memberProfile?->user?->name ?? 'Member tidak tersedia',
                'title' => $programSession?->title ?: ($booking?->session_title ?: 'Sesi Personal Trainer'),
                'program_title' => $programSession?->trainingProgram?->title,
                'sequence_order' => (int) $reservation->sequence_order,
                'status' => (string) $reservation->status,
                'booking_status' => $booking?->status,
                'payment_status' => $this->bookingPaymentStatus($booking),
                'location' => $booking?->location,
                'has_pending_reschedule' => $reservation->rescheduleRequests->isNotEmpty(),
            ];
        });

        $legacySessions = Booking::query()
            ->with('memberProfile.user')
            ->where('trainer_profile_id', $trainerProfile->id)
            ->whereDoesntHave('sessionReservations')
            ->whereBetween('session_date', [$month->toDateString(), $monthEnd->toDateString()])
            ->orderBy('session_date')
            ->orderBy('start_time')
            ->get()
            ->map(fn (Booking $booking): array => [
                'key' => 'booking-'.$booking->id,
                'date' => $booking->session_date->toDateString(),
                'start_time' => substr((string) $booking->start_time, 0, 5),
                'end_time' => substr((string) $booking->end_time, 0, 5),
                'member_name' => $booking->memberProfile?->user?->name ?? 'Member tidak tersedia',
                'title' => $booking->session_title ?: 'Sesi Personal Trainer',
                'program_title' => null,
                'sequence_order' => 1,
                'status' => (string) $booking->status,
                'booking_status' => (string) $booking->status,
                'payment_status' => $this->bookingPaymentStatus($booking),
                'location' => $booking->location,
                'has_pending_reschedule' => $booking->rescheduleRequests()
                    ->where('status', BookingRescheduleRequest::STATUS_PENDING)->exists(),
            ]);

        $sessions = $sessions->concat($legacySessions)
            ->sortBy(fn (array $session) => $session['date'].' '.$session['start_time'])
            ->values();
        $sessionsByDate = $sessions->groupBy(fn (array $session) => $session['date']);
        $cancelledStatuses = [BookingSessionReservation::STATUS_CANCELLED, BookingSessionReservation::STATUS_RELEASED, 'cancelled', 'expired', 'rejected'];
        $activeSessionCount = $sessions->reject(fn (array $session) => in_array($session['status'], $cancelledStatuses, true))->count();
        $cancelledSessionCount = $sessions->count() - $activeSessionCount;

        $concreteDates = $trainerProfile->scheduleDates()
            ->with(['shifts' => fn ($query) => $query->orderBy('start_time')])
            ->whereBetween('schedule_date', [$month->toDateString(), $monthEnd->toDateString()])
            ->get()
            ->keyBy(fn ($date) => $date->schedule_date->toDateString());
        $rescheduleHolds = BookingRescheduleRequest::query()
            ->with(['reservation.memberProfile.user'])
            ->where('trainer_profile_id', $trainerProfile->id)
            ->where('status', BookingRescheduleRequest::STATUS_PENDING)
            ->where('expired_at', '>', $now)
            ->whereBetween('proposed_session_date', [$month->toDateString(), $monthEnd->toDateString()])
            ->get()
            ->groupBy(fn (BookingRescheduleRequest $hold) => $hold->proposed_session_date->toDateString());
        $blockingStatuses = [
            BookingSessionReservation::STATUS_RESERVED,
            BookingSessionReservation::STATUS_COMPLETED,
            ...Booking::SCHEDULE_BLOCKING_STATUSES,
            'completed',
        ];
        $slotsByDate = collect();
        $dayStates = collect();

        for ($date = $month; $date->lessThanOrEqualTo($monthEnd); $date = $date->addDay()) {
            $dateKey = $date->toDateString();
            $concreteDate = $concreteDates->get($dateKey);
            if (! $concreteDate || $concreteDate->state !== 'open' || $concreteDate->shifts->isEmpty()) {
                $slotsByDate->put($dateKey, collect());
                $dayStates->put($dateKey, 'off');

                continue;
            }

            $dateSessions = $sessionsByDate->get($dateKey, collect());
            $dateHolds = $rescheduleHolds->get($dateKey, collect());
            $slots = $concreteDate->shifts->map(function ($shift) use (
                $date,
                $dateSessions,
                $dateHolds,
                $blockingStatuses,
                $cancelledStatuses,
                $now
            ): array {
                $startTime = substr((string) $shift->start_time, 0, 5);
                $endTime = substr((string) $shift->end_time, 0, 5);
                $blockingSession = $dateSessions->first(fn (array $session) => ! in_array($session['status'], $cancelledStatuses, true)
                    && in_array($session['status'], $blockingStatuses, true)
                    && $this->timeRangesOverlap(
                        $startTime,
                        $endTime,
                        $session['start_time'],
                        $session['end_time'],
                        TrainerAvailabilityService::BUFFER_MINUTES
                    )
                );
                $hold = $dateHolds->first(fn (BookingRescheduleRequest $request) => $this->timeRangesOverlap(
                    $startTime,
                    $endTime,
                    substr((string) $request->proposed_start_time, 0, 5),
                    substr((string) $request->proposed_end_time, 0, 5)
                ));
                $slotStart = $date->setTimeFromTimeString($startTime.':00');
                $isPastLeadTime = $slotStart->lessThan($now->addMinutes(TrainerAvailabilityService::LEAD_MINUTES));

                if ($blockingSession) {
                    return [
                        ...$blockingSession,
                        'slot_start_time' => $startTime,
                        'slot_end_time' => $endTime,
                        'slot_state' => 'booked',
                    ];
                }
                if ($hold) {
                    return [
                        'key' => 'hold-'.$hold->id,
                        'date' => $date->toDateString(),
                        'start_time' => $startTime,
                        'end_time' => $endTime,
                        'slot_start_time' => $startTime,
                        'slot_end_time' => $endTime,
                        'member_name' => $hold->reservation?->memberProfile?->user?->name ?? 'Member tidak tersedia',
                        'title' => 'Hold Reschedule',
                        'program_title' => null,
                        'sequence_order' => $hold->reservation?->sequence_order,
                        'status' => BookingRescheduleRequest::STATUS_PENDING,
                        'booking_status' => null,
                        'payment_status' => null,
                        'location' => null,
                        'has_pending_reschedule' => true,
                        'slot_state' => 'reschedule_pending',
                    ];
                }

                return [
                    'key' => 'shift-'.$shift->id,
                    'date' => $date->toDateString(),
                    'start_time' => $startTime,
                    'end_time' => $endTime,
                    'slot_start_time' => $startTime,
                    'slot_end_time' => $endTime,
                    'member_name' => null,
                    'title' => $isPastLeadTime ? 'Tidak tersedia' : 'Kosong',
                    'program_title' => null,
                    'sequence_order' => null,
                    'status' => $isPastLeadTime ? 'unavailable' : 'available',
                    'booking_status' => null,
                    'payment_status' => null,
                    'location' => null,
                    'has_pending_reschedule' => false,
                    'slot_state' => $isPastLeadTime ? 'unavailable' : 'available',
                ];
            })->values();

            $slotsByDate->put($dateKey, $slots);
            $dayStates->put($dateKey, 'active');
        }

        $calendarStart = $month->startOfWeek(CarbonImmutable::MONDAY);
        $calendarEnd = $monthEnd->endOfWeek(CarbonImmutable::SUNDAY);
        $calendarDates = collect();
        for ($date = $calendarStart; $date->lessThanOrEqualTo($calendarEnd); $date = $date->addDay()) {
            $calendarDates->push($date);
        }

        $monthNames = [
            1 => 'Januari',
            2 => 'Februari',
            3 => 'Maret',
            4 => 'April',
            5 => 'Mei',
            6 => 'Juni',
            7 => 'Juli',
            8 => 'Agustus',
            9 => 'September',
            10 => 'Oktober',
            11 => 'November',
            12 => 'Desember',
        ];

        return view('admin.trainer-profiles.schedule', [
            'trainer' => $trainerProfile,
            'user' => $trainerProfile->user,
            'sessions' => $sessions,
            'sessionsByDate' => $sessionsByDate,
            'calendarDates' => $calendarDates,
            'slotsByDate' => $slotsByDate,
            'dayStates' => $dayStates,
            'month' => $month,
            'timezone' => TrainerScheduleMaterializer::TIMEZONE,
            'monthLabel' => $monthNames[$month->month].' '.$month->year,
            'previousMonth' => $month->subMonth()->format('Y-m'),
            'nextMonth' => $month->addMonth()->format('Y-m'),
            'currentMonth' => $currentMonth->format('Y-m'),
            'activeSessionCount' => $activeSessionCount,
            'cancelledSessionCount' => $cancelledSessionCount,
            'statusLabels' => [
                'reserved' => 'Dijadwalkan',
                'completed' => 'Selesai',
                'released' => 'Dilepas',
                'cancelled' => 'Dibatalkan',
                'pending' => 'Pending',
                'waiting_payment' => 'Menunggu Pembayaran',
                'payment_uploaded' => 'Bukti Diunggah',
                'payment_rejected' => 'Pembayaran Ditolak',
                'payment_verified' => 'Pembayaran Terverifikasi',
                'confirmed' => 'Dikonfirmasi',
                'rescheduled' => 'Dijadwalkan Ulang',
                'expired' => 'Kedaluwarsa',
                'rejected' => 'Ditolak',
                'available' => 'Tersedia',
                'unavailable' => 'Tidak Tersedia',
            ],
        ]);
    }

    public function create(): View
    {
        return view('admin.trainer-profiles.form', [
            'trainer' => null,
            'user' => new User,
            'pageTitle' => 'Tambah Trainer',
            'submitLabel' => 'Simpan Trainer',
            'action' => route('admin.trainer-profiles.store'),
            'method' => 'POST',
            'specialtyOptions' => TrainerSpecialty::labels(),
            'specialtyDisplay' => null,
            'specialtyDisplays' => [],
            'tierOptions' => TrainerTier::labels(),
        ]);
    }

    public function store(Request $request): RedirectResponse|JsonResponse
    {
        $validated = $this->validateTrainer($request);
        $trainerRole = Role::query()->where('name', 'trainer')->firstOrFail();

        $trainerProfile = null;
        $avatarPath = $request->hasFile('avatar')
            ? $request->file('avatar')->store('avatars', 'public')
            : null;

        try {
            DB::transaction(function () use ($validated, $trainerRole, $avatarPath, &$trainerProfile) {
                $user = User::create([
                    'role_id' => $trainerRole->id,
                    'name' => trim((string) $validated['name']),
                    'email' => trim((string) $validated['email']),
                    'phone' => trim((string) $validated['phone']),
                    'password' => Hash::make((string) $validated['password']),
                    'status' => (string) $validated['status'],
                    'avatar_url' => $avatarPath,
                ]);

                $trainerProfile = TrainerProfile::create([
                    'user_id' => $user->id,
                    'specialty' => $validated['specialties'][0],
                    'specialties' => array_values($validated['specialties']),
                    'tier' => (string) ($validated['tier'] ?? 'pro'),
                    'max_clients' => (int) ($validated['max_clients'] ?? 30),
                    'verification_status' => (string) ($validated['verification_status'] ?? 'pending'),
                    'admin_notes' => $this->nullableTrim($validated['admin_notes'] ?? null),
                    'bio' => $this->nullableTrim($validated['bio'] ?? null),
                    'experience_years' => $validated['experience_years'] ?? null,
                    'certifications' => $this->nullableTrim($validated['certifications'] ?? null),
                    'availability_note' => $this->nullableTrim($validated['availability_note'] ?? null),
                ]);
            });
        } catch (Throwable $exception) {
            if ($avatarPath !== null) {
                Storage::disk('public')->delete($avatarPath);
            }

            throw $exception;
        }

        if ($trainerProfile) {
            ActivityLogger::logCreated($trainerProfile, "Trainer baru ditambahkan: {$trainerProfile->user->name}");
        }

        if ($request->expectsJson()) {
            $request->session()->flash('success', 'Trainer berhasil ditambahkan.');

            return response()->json([
                'message' => 'Trainer berhasil ditambahkan.',
                'redirect_url' => route('admin.trainer-profiles.index'),
                'avatar_url' => $avatarPath !== null
                    ? Storage::disk('public')->url($avatarPath)
                    : null,
            ], 201);
        }

        return redirect()->route('admin.trainer-profiles.index')
            ->with('success', 'Trainer berhasil ditambahkan.');
    }

    public function edit(TrainerProfile $trainerProfile): View
    {
        $trainerProfile->load('user');

        return view('admin.trainer-profiles.form', [
            'trainer' => $trainerProfile,
            'user' => $trainerProfile->user,
            'pageTitle' => 'Edit Profil Trainer',
            'submitLabel' => 'Simpan Perubahan',
            'action' => route('admin.trainer-profiles.update', $trainerProfile),
            'method' => 'PUT',
            'specialtyOptions' => TrainerSpecialty::labels(),
            'specialtyDisplay' => $trainerProfile->specialty_label,
            'specialtyDisplays' => $trainerProfile->specialty_labels,
            'tierOptions' => TrainerTier::labels(),
        ]);
    }

    public function show(
        TrainerProfile $trainerProfile,
        TrainerRevenueService $trainerRevenue
    ): View {
        $trainerProfile = TrainerProfile::query()
            ->with('user')
            ->withRatingStats()
            ->findOrFail($trainerProfile->id);

        return view('admin.trainer-profiles.show', [
            'trainer' => $trainerProfile,
            'user' => $trainerProfile->user,
            'activeClients' => $trainerProfile->activeQuotaMembers(),
            'specialties' => $trainerProfile->specialty_labels,
            'revenueSummary' => $trainerRevenue->sixMonthSummary($trainerProfile),
        ]);
    }

    public function update(Request $request, TrainerProfile $trainerProfile): RedirectResponse
    {
        $validated = $request->validate([
            'tier' => ['required', Rule::in(TrainerTier::values())],
            'max_clients' => ['required', 'integer', 'min:1', 'max:500'],
            'verification_status' => ['required', Rule::in(['pending', 'verified', 'unverified'])],
            'admin_notes' => ['nullable', 'string', 'max:5000'],
        ]);

        $oldValues = $trainerProfile->only([
            'tier',
            'max_clients',
            'verification_status',
            'admin_notes',
        ]);
        $trainerProfile->update([
            'tier' => $validated['tier'],
            'max_clients' => (int) $validated['max_clients'],
            'verification_status' => $validated['verification_status'],
            'admin_notes' => $this->nullableTrim($validated['admin_notes'] ?? null),
        ]);

        ActivityLogger::logUpdated(
            $trainerProfile,
            $oldValues,
            'Kontrol administratif trainer diperbarui: '.($trainerProfile->user?->name ?? 'Trainer')
        );

        return redirect()
            ->route('admin.trainer-profiles.index')
            ->with('success', 'Profil administratif trainer berhasil diperbarui.');
    }

    public function destroy(TrainerProfile $trainerProfile): RedirectResponse
    {
        $trainerProfile->load('user');
        $name = $trainerProfile->user?->name ?? 'Unknown';
        ActivityLogger::logDeleted($trainerProfile, "Trainer dihapus: {$name}");

        DB::transaction(function () use ($trainerProfile) {
            $trainerProfile->delete();
            $trainerProfile->user?->delete();
        });

        return redirect()
            ->route('admin.trainer-profiles.index')
            ->with('success', 'Trainer berhasil dihapus.');
    }

    private function validateTrainer(
        Request $request,
        ?int $trainerProfileId = null,
        ?int $userId = null
    ): array {
        return $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email', 'max:150', 'unique:users,email,'.$userId],
            'phone' => ['required', 'string', 'max:30'],
            'password' => [
                $trainerProfileId === null ? 'required' : 'nullable',
                'string',
                'min:8',
            ],
            'status' => ['required', 'in:active,inactive'],
            'avatar_url' => ['nullable', 'string', 'max:255'],
            'avatar' => ['nullable', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:2048'],
            'specialties' => ['required', 'array', 'min:1'],
            'specialties.*' => [
                'required',
                'string',
                'distinct',
                Rule::in(TrainerSpecialty::labels()),
            ],
            'tier' => ['nullable', Rule::in(TrainerTier::values())],
            'max_clients' => ['nullable', 'integer', 'min:1', 'max:500'],
            'verification_status' => ['nullable', Rule::in(['pending', 'verified', 'unverified'])],
            'admin_notes' => ['nullable', 'string', 'max:5000'],
            'bio' => ['nullable', 'string'],
            'experience_years' => ['nullable', 'integer', 'min:0', 'max:100'],
            'certifications' => ['nullable', 'string'],
            'availability_note' => ['nullable', 'string'],
        ]);
    }

    private function nullableTrim(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function bookingPaymentStatus(?Booking $booking): ?string
    {
        if (! $booking) {
            return null;
        }
        if ($booking->payment_verified_at !== null || in_array($booking->status, ['payment_verified', 'confirmed', 'rescheduled'], true)) {
            return 'Terverifikasi';
        }
        if ($booking->status === 'payment_rejected') {
            return 'Ditolak';
        }
        if ($booking->payment_proof_path !== null || $booking->status === 'payment_uploaded') {
            return 'Menunggu Verifikasi';
        }
        if (in_array($booking->status, ['waiting_payment', 'pending'], true)) {
            return 'Belum Dibayar';
        }

        return null;
    }

    private function timeRangesOverlap(
        string $leftStart,
        string $leftEnd,
        string $rightStart,
        string $rightEnd,
        int $bufferMinutes = 0
    ): bool {
        $toMinutes = static function (string $time): int {
            [$hours, $minutes] = array_map('intval', explode(':', $time));

            return $hours * 60 + $minutes;
        };

        return $toMinutes($leftStart) < $toMinutes($rightEnd) + $bufferMinutes
            && $toMinutes($leftEnd) > $toMinutes($rightStart) - $bufferMinutes;
    }
}

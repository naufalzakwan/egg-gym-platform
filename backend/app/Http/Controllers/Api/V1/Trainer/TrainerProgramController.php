<?php

namespace App\Http\Controllers\Api\V1\Trainer;

use App\Exceptions\BookingScheduleException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Trainer\CloseTrainingProgramEarlyRequest;
use App\Http\Requests\Api\V1\Trainer\StoreTrainingProgramRequest;
use App\Http\Requests\Api\V1\Trainer\StoreTrainingProgramSessionExerciseRequest;
use App\Http\Requests\Api\V1\Trainer\StoreTrainingProgramSessionRequest;
use App\Http\Requests\Api\V1\Trainer\UpdateTrainerSessionProgressRequest;
use App\Http\Requests\Api\V1\Trainer\UpdateTrainingProgramSessionExerciseRequest;
use App\Http\Requests\Api\V1\Trainer\UpdateTrainingProgramSessionRequest;
use App\Http\Resources\Api\V1\Trainer\TrainerProgramResource;
use App\Http\Resources\Api\V1\Trainer\TrainerProgramSessionExerciseResource;
use App\Http\Resources\Api\V1\Trainer\TrainerProgramSessionResource;
use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\GymEquipmentMovement;
use App\Models\MemberProfile;
use App\Models\TrainerSessionProgress;
use App\Models\TrainerSessionProgressExercise;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use App\Models\TrainingProgramSessionExercise;
use App\Services\Notification\UserNotificationService;
use App\Services\TrainingProgram\CloseTrainingProgramEarlyService;
use App\Services\TrainingProgram\TrainingProgramExecutionOrderService;
use App\Services\TrainingProgram\TrainingSessionExecutionGuard;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

class TrainerProgramController extends Controller
{
    public function __construct(
        private readonly TrainingProgramExecutionOrderService $executionOrderService
    ) {}

    public function closeEarly(
        CloseTrainingProgramEarlyRequest $request,
        TrainingProgram $trainingProgram,
        CloseTrainingProgramEarlyService $service
    ): JsonResponse {
        $trainerProfile = $request->user()->load('trainerProfile')->trainerProfile;
        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        try {
            $program = $service->close(
                $trainingProgram,
                (int) $trainerProfile->id,
                $request->validated('reason')
            );
        } catch (\DomainException $exception) {
            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
            ], str_contains($exception->getMessage(), 'tidak ditemukan') ? 404 : 422);
        }

        return response()->json([
            'success' => true,
            'message' => 'Program ditutup lebih awal dan slot tersisa sudah dilepas.',
            'data' => new TrainerProgramResource($program),
            'meta' => null,
        ]);
    }

    /**
     * Display the authenticated trainer programs.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $programs = TrainingProgram::query()
            ->with([
                'memberProfile.user',
                'booking',
                'sessions.bookingSessionReservation',
                'sessions.exercises',
            ])
            ->where('trainer_profile_id', $trainerProfile->id)
            ->latest('id')
            ->get()
            ->map(function (TrainingProgram $program) {
                $totalSessions = $program->sessions->count();
                $completedSessions = $program->sessions
                    ->where('status', 'completed')
                    ->count();
                $progressPercent = $totalSessions > 0
                    ? (int) round($completedSessions / $totalSessions * 100)
                    : 0;
                $remainingSessions = $program->sessions->filter(
                    fn (TrainingProgramSession $session) => ! in_array(
                        strtolower(trim((string) $session->status)),
                        ['completed', 'cancelled'],
                        true
                    )
                );
                $actionableSessions = $remainingSessions->filter(function (TrainingProgramSession $session) {
                    $reservation = $session->bookingSessionReservation;

                    return ! $reservation
                        || $reservation->status === BookingSessionReservation::STATUS_RESERVED;
                });
                $nextSession = $actionableSessions
                    ->sortBy(function (TrainingProgramSession $session) use ($program) {
                        $date = $session->bookingSessionReservation?->session_date
                            ?->toDateString()
                            ?? $program->booking?->session_date?->toDateString()
                            ?? '9999-12-31';

                        return $date.'-'.str_pad((string) $session->sequence_order, 10, '0', STR_PAD_LEFT);
                    })
                    ->first();
                $nextReservation = $nextSession?->bookingSessionReservation;
                $booking = $program->booking;
                $programStatus = strtolower(trim((string) $program->status));
                $bookingStatus = strtolower(trim((string) $booking?->status));
                $isBookingEligible = $booking && (
                    $booking->payment_verified_at !== null
                    && ! in_array(
                        $bookingStatus,
                        ['completed', 'expired', 'cancelled', 'rejected'],
                        true
                    )
                );
                $isActiveControl = $totalSessions > 0
                    && ! in_array(
                        $programStatus,
                        ['archived', 'closed_early', 'cancelled', 'closed', 'completed'],
                        true
                    )
                    && $remainingSessions->isNotEmpty()
                    && $isBookingEligible
                    && $nextSession !== null;

                return [
                    'id' => $program->id,
                    'title' => $program->title,
                    'member_profile_id' => $program->member_profile_id,
                    'member_name' => $program->memberProfile?->user?->name,
                    'status' => $program->status,
                    'sessions_count' => $totalSessions,
                    'completed_sessions_count' => $completedSessions,
                    'progress_percent' => $progressPercent,
                    'is_active_control' => $isActiveControl,
                    'total_duration_minutes' => $program->sessions->sum(
                        fn (TrainingProgramSession $session) => (int) ($session->duration_minutes ?? 0)
                    ),
                    'exercises_count' => $program->sessions->sum(
                        fn (TrainingProgramSession $session) => $session->exercises->count()
                    ),
                    'next_session' => $nextSession ? [
                        'session_date' => $nextReservation?->session_date?->toDateString()
                            ?? $booking?->session_date?->toDateString(),
                        'start' => $nextReservation?->start_time ?? $booking?->start_time,
                        'end' => $nextReservation?->end_time ?? $booking?->end_time,
                        'status' => $nextReservation?->status ?? $nextSession->status,
                    ] : null,
                ];
            });

        return response()->json([
            'success' => true,
            'message' => 'Daftar program trainer berhasil diambil.',
            'data' => $programs,
            'meta' => null,
        ]);
    }

    /**
     * Store a newly created training program.
     */
    public function store(
        StoreTrainingProgramRequest $request,
        UserNotificationService $userNotificationService
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $validated = $request->validated();

        $memberProfile = MemberProfile::query()
            ->where('id', $validated['member_profile_id'])
            ->whereHas('bookings', function ($query) use ($trainerProfile) {
                $query->where('trainer_profile_id', $trainerProfile->id);
            })
            ->first();

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Klien tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        $booking = null;

        if (! empty($validated['booking_id'])) {
            $booking = Booking::query()
                ->where('id', $validated['booking_id'])
                ->where('trainer_profile_id', $trainerProfile->id)
                ->where('member_profile_id', $memberProfile->id)
                ->first();

            if (! $booking) {
                return response()->json([
                    'success' => false,
                    'message' => 'Booking tidak valid untuk pasangan trainer dan klien ini.',
                ], 422);
            }
            if (! in_array($booking->status, ['payment_verified', 'confirmed'], true)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Program hanya dapat dibuat setelah pembayaran booking terverifikasi.',
                ], 422);
            }

            if (TrainingProgram::query()->where('booking_id', $booking->id)->exists()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Program untuk booking ini sudah dibuat.',
                ], 422);
            }
        }

        $existingProgram = TrainingProgram::query()
            ->where('trainer_profile_id', $trainerProfile->id)
            ->where('member_profile_id', $memberProfile->id)
            ->runtimeActive()
            ->first();

        if ($existingProgram) {
            return response()->json([
                'success' => false,
                'message' => 'Sudah ada program aktif untuk klien ini. Selesaikan atau arsipkan program sebelumnya terlebih dahulu.',
            ], 422);
        }

        try {
            $program = TrainingProgram::create([
                'trainer_profile_id' => $trainerProfile->id,
                'member_profile_id' => $memberProfile->id,
                'booking_id' => $booking?->id,
                'title' => $validated['title'],
                'description' => $validated['description'] ?? null,
                'goal' => $validated['goal'] ?? null,
                'status' => $validated['status'] ?? 'draft',
                'started_at' => $validated['started_at'] ?? null,
                'ended_at' => $validated['ended_at'] ?? null,
            ]);
        } catch (QueryException $exception) {
            if ($booking && TrainingProgram::query()->where('booking_id', $booking->id)->exists()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Program untuk booking ini sudah dibuat.',
                ], 422);
            }

            throw $exception;
        }

        $program->load([
            'trainerProfile.user',
            'memberProfile.user',
            'booking',
        ]);

        $memberUser = $program->memberProfile?->user;
        $trainerName = $program->trainerProfile?->user?->name ?? 'trainer kamu';

        if ($memberUser) {
            $userNotificationService->notify(
                $memberUser,
                'Program Baru Siap',
                $trainerName.' sudah menyiapkan program baru "'.$program->title.'" untuk kamu.',
                'program',
                'push',
                true,
                [
                    'program_id' => (string) $program->id,
                    'status' => (string) $program->status,
                    'target' => 'program',
                ],
                "program:{$program->id}:created:member"
            );
        }
        $userNotificationService->notify(
            $request->user(),
            'Program berhasil dibuat',
            'Program latihan member sudah tersimpan.',
            'program', 'in_app', false,
            ['program_id' => (string) $program->id, 'target' => 'trainer_program'],
            "program:{$program->id}:created:trainer"
        );

        return response()->json([
            'success' => true,
            'message' => 'Program trainer berhasil dibuat.',
            'data' => new TrainerProgramResource($program),
            'meta' => null,
        ], 201);
    }

    /**
     * Store a newly created session inside a trainer program.
     */
    public function storeSession(
        StoreTrainingProgramSessionRequest $request,
        TrainingProgram $trainingProgram
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        if ($trainingProgram->trainer_profile_id !== $trainerProfile->id) {
            return response()->json([
                'success' => false,
                'message' => 'Program tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        if (in_array($trainingProgram->status, TrainingProgram::TERMINAL_STATUSES, true)) {
            return response()->json([
                'success' => false,
                'message' => 'Program yang sudah final tidak dapat ditambah sesi baru.',
            ], 422);
        }

        $validated = $request->validated();

        $duplicateSequence = TrainingProgramSession::query()
            ->where('training_program_id', $trainingProgram->id)
            ->where('sequence_order', $validated['sequence_order'])
            ->exists();

        if ($duplicateSequence) {
            return response()->json([
                'success' => false,
                'message' => 'Urutan sesi sudah dipakai pada program ini.',
            ], 422);
        }

        // Determine session status based on sequence order
        // First session (sequence_order = 1) should be 'active', rest should be 'locked'
        $isFirstSession = $validated['sequence_order'] === 1;
        $hasOtherSessions = TrainingProgramSession::query()
            ->where('training_program_id', $trainingProgram->id)
            ->exists();

        $sessionStatus = $validated['status'] ?? 'locked';
        if (! $hasOtherSessions && $isFirstSession) {
            $sessionStatus = 'active';
        }

        try {
            $session = DB::transaction(function () use (
                $trainingProgram,
                $validated,
                $sessionStatus
            ) {
                $reservationId = null;
                if ($trainingProgram->booking_id !== null) {
                    $booking = Booking::query()
                        ->whereKey($trainingProgram->booking_id)
                        ->where('trainer_profile_id', $trainingProgram->trainer_profile_id)
                        ->where('member_profile_id', $trainingProgram->member_profile_id)
                        ->lockForUpdate()
                        ->first();
                    if (! $booking) {
                        throw new \DomainException('Booking program tidak valid.');
                    }
                    $reservation = BookingSessionReservation::query()
                        ->where('booking_id', $booking->id)
                        ->where('sequence_order', $validated['sequence_order'])
                        ->lockForUpdate()
                        ->first();
                    if ($booking->sessionReservations()->exists() && ! $reservation) {
                        throw new \DomainException('Reservation untuk urutan sesi ini tidak tersedia.');
                    }
                    $reservationId = $reservation?->id;
                }

                return TrainingProgramSession::create([
                    'training_program_id' => $trainingProgram->id,
                    'booking_session_reservation_id' => $reservationId,
                    'sequence_order' => $validated['sequence_order'],
                    'title' => $validated['title'],
                    'focus' => $validated['focus'] ?? null,
                    'duration_minutes' => $validated['duration_minutes'] ?? null,
                    'status' => $sessionStatus,
                    'unlock_rule' => $validated['unlock_rule'] ?? 'after_previous_complete',
                    'coach_note' => $validated['coach_note'] ?? null,
                ]);
            });
        } catch (\DomainException $exception) {
            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
            ], 422);
        }

        $session->load('bookingSessionReservation');

        return response()->json([
            'success' => true,
            'message' => 'Sesi program trainer berhasil ditambahkan.',
            'data' => new TrainerProgramSessionResource($session),
            'meta' => null,
        ], 201);
    }

    /**
     * Display a specific trainer program.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $trainingProgram = TrainingProgram::query()
            ->with([
                'trainerProfile.user',
                'memberProfile.user',
                'booking',
                'sessions.exercises',
                'sessions.bookingSessionReservation.pendingRescheduleRequest',
            ])
            ->where('id', $id)
            ->where('trainer_profile_id', $trainerProfile->id)
            ->first();

        if (! $trainingProgram) {
            return response()->json([
                'success' => false,
                'message' => 'Program tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        $this->executionOrderService->reconcile($trainingProgram->id);
        $trainingProgram->load([
            'sessions.exercises',
            'sessions.bookingSessionReservation.pendingRescheduleRequest',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Detail program trainer berhasil diambil.',
            'data' => new TrainerProgramResource($trainingProgram),
            'meta' => null,
        ]);
    }

    /**
     * Update a specific trainer program session.
     */
    public function updateSession(
        UpdateTrainingProgramSessionRequest $request,
        int $id
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $session = TrainingProgramSession::query()
            ->with('trainingProgram')
            ->where('id', $id)
            ->first();

        if (! $session || $session->trainingProgram?->trainer_profile_id !== $trainerProfile->id) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi program tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        if ($session->trainingProgram->status === 'archived') {
            return response()->json([
                'success' => false,
                'message' => 'Program yang sudah diarsipkan tidak dapat diubah.',
            ], 422);
        }

        $validated = $request->validated();

        $duplicateSequence = TrainingProgramSession::query()
            ->where('training_program_id', $session->training_program_id)
            ->where('sequence_order', $validated['sequence_order'])
            ->where('id', '!=', $session->id)
            ->exists();

        if ($duplicateSequence) {
            return response()->json([
                'success' => false,
                'message' => 'Urutan sesi sudah dipakai pada program ini.',
            ], 422);
        }

        $session->update([
            'sequence_order' => $validated['sequence_order'],
            'title' => $validated['title'],
            'focus' => $validated['focus'] ?? null,
            'duration_minutes' => $validated['duration_minutes'] ?? null,
            'status' => $validated['status'] ?? $session->status,
            'unlock_rule' => $validated['unlock_rule'] ?? $session->unlock_rule,
            'coach_note' => $validated['coach_note'] ?? null,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Sesi program trainer berhasil diperbarui.',
            'data' => new TrainerProgramSessionResource($session->fresh()),
            'meta' => null,
        ]);
    }

    /**
     * Store a newly created exercise inside a trainer program session.
     */
    public function storeSessionExercise(
        StoreTrainingProgramSessionExerciseRequest $request,
        int $id
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $session = TrainingProgramSession::query()
            ->with('trainingProgram')
            ->where('id', $id)
            ->first();

        if (! $session || $session->trainingProgram?->trainer_profile_id !== $trainerProfile->id) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi program tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        if ($session->trainingProgram->status === 'archived') {
            return response()->json([
                'success' => false,
                'message' => 'Program yang sudah diarsipkan tidak dapat ditambah latihan baru.',
            ], 422);
        }

        $validated = $request->validated();
        $source = $this->validatedEquipmentSource($validated);

        $duplicateSequence = TrainingProgramSessionExercise::query()
            ->where('training_program_session_id', $session->id)
            ->where('sequence_order', $validated['sequence_order'])
            ->exists();

        if ($duplicateSequence) {
            return response()->json([
                'success' => false,
                'message' => 'Urutan latihan sudah dipakai pada sesi ini.',
            ], 422);
        }

        $exercise = TrainingProgramSessionExercise::create([
            'training_program_session_id' => $session->id,
            'exercise_library_id' => $validated['exercise_library_id'] ?? null,
            'equipment_id' => $source['equipment_id'],
            'gym_equipment_movement_id' => $source['gym_equipment_movement_id'],
            'equipment_name' => $source['equipment_name'],
            'sequence_order' => $validated['sequence_order'],
            'custom_name' => $source['movement_name'] ?? ($validated['custom_name'] ?? null),
            'custom_target_muscle' => $source['target_area'] ?? ($validated['custom_target_muscle'] ?? null),
            'sets' => $validated['sets'],
            'reps' => $validated['reps'],
            'rest_seconds' => $validated['rest_seconds'] ?? null,
            'cue_text' => $validated['cue_text'] ?? null,
            'status' => $validated['status'] ?? 'locked',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Latihan berhasil ditambahkan ke sesi program.',
            'data' => new TrainerProgramSessionExerciseResource($exercise),
            'meta' => null,
        ], 201);
    }

    /**
     * Update a specific exercise inside a trainer program session.
     */
    public function updateSessionExercise(
        UpdateTrainingProgramSessionExerciseRequest $request,
        int $id
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $exercise = TrainingProgramSessionExercise::query()
            ->with('trainingProgramSession.trainingProgram')
            ->where('id', $id)
            ->first();

        if (
            ! $exercise ||
            $exercise->trainingProgramSession?->trainingProgram?->trainer_profile_id !== $trainerProfile->id
        ) {
            return response()->json([
                'success' => false,
                'message' => 'Latihan tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        if ($exercise->trainingProgramSession->trainingProgram->status === 'archived') {
            return response()->json([
                'success' => false,
                'message' => 'Program yang sudah diarsipkan tidak dapat mengubah latihan.',
            ], 422);
        }

        $validated = $request->validated();
        $source = $this->validatedEquipmentSource($validated);

        $duplicateSequence = TrainingProgramSessionExercise::query()
            ->where('training_program_session_id', $exercise->training_program_session_id)
            ->where('sequence_order', $validated['sequence_order'])
            ->where('id', '!=', $exercise->id)
            ->exists();

        if ($duplicateSequence) {
            return response()->json([
                'success' => false,
                'message' => 'Urutan latihan sudah dipakai pada sesi ini.',
            ], 422);
        }

        $exercise->update([
            'exercise_library_id' => $validated['exercise_library_id'] ?? null,
            'equipment_id' => $source['equipment_id'],
            'gym_equipment_movement_id' => $source['gym_equipment_movement_id'],
            'equipment_name' => $source['equipment_name'],
            'sequence_order' => $validated['sequence_order'],
            'custom_name' => $source['movement_name'] ?? ($validated['custom_name'] ?? null),
            'custom_target_muscle' => $source['target_area'] ?? ($validated['custom_target_muscle'] ?? null),
            'sets' => $validated['sets'],
            'reps' => $validated['reps'],
            'rest_seconds' => $validated['rest_seconds'] ?? null,
            'cue_text' => $validated['cue_text'] ?? null,
            'status' => $validated['status'] ?? $exercise->status,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Latihan pada sesi program berhasil diperbarui.',
            'data' => new TrainerProgramSessionExerciseResource($exercise->fresh()),
            'meta' => null,
        ]);
    }

    /**
     * Remove a specific exercise from a trainer program session.
     */
    public function destroySessionExercise(Request $request, int $id): JsonResponse
    {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $exercise = TrainingProgramSessionExercise::query()
            ->with('trainingProgramSession.trainingProgram')
            ->where('id', $id)
            ->first();

        if (
            ! $exercise ||
            $exercise->trainingProgramSession?->trainingProgram?->trainer_profile_id !== $trainerProfile->id
        ) {
            return response()->json([
                'success' => false,
                'message' => 'Latihan tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        if ($exercise->trainingProgramSession->trainingProgram->status === 'archived') {
            return response()->json([
                'success' => false,
                'message' => 'Program yang sudah diarsipkan tidak dapat menghapus latihan.',
            ], 422);
        }

        $exercise->delete();

        return response()->json([
            'success' => true,
            'message' => 'Latihan berhasil dihapus dari sesi program.',
            'data' => null,
            'meta' => null,
        ]);
    }

    /**
     * Display trainer-side progress for a specific program session.
     */
    public function showSessionProgress(
        Request $request,
        int $id,
        TrainingSessionExecutionGuard $executionGuard
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $session = TrainingProgramSession::query()
            ->with(['trainingProgram.memberProfile', 'exercises'])
            ->where('id', $id)
            ->first();

        if (! $session || $session->trainingProgram?->trainer_profile_id !== $trainerProfile->id) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi program tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        try {
            $executionGuard->assertCanExecute($session);
        } catch (BookingScheduleException $exception) {
            return response()->json(['success' => false, 'message' => $exception->getMessage()], $exception->httpStatus);
        }

        $orderedExercises = $session->exercises
            ->sortBy('sequence_order')
            ->values();

        $progress = TrainerSessionProgress::query()
            ->firstOrCreate(
                ['training_program_session_id' => $session->id],
                [
                    'training_program_id' => $session->training_program_id,
                    'trainer_profile_id' => $trainerProfile->id,
                    'member_profile_id' => $session->trainingProgram->member_profile_id,
                    'progress_percent' => 0,
                    'current_exercise_order' => $orderedExercises->first()?->sequence_order,
                    'status' => 'active',
                    'trainer_note' => null,
                ]
            );

        $existingExerciseIds = TrainerSessionProgressExercise::query()
            ->where('trainer_session_progress_id', $progress->id)
            ->pluck('training_program_session_exercise_id')
            ->all();

        $firstOrder = $orderedExercises->first()?->sequence_order;

        foreach ($orderedExercises as $exercise) {
            if (! in_array($exercise->id, $existingExerciseIds, true)) {
                TrainerSessionProgressExercise::create([
                    'trainer_session_progress_id' => $progress->id,
                    'training_program_session_exercise_id' => $exercise->id,
                    'completed_sets' => 0,
                    'total_sets' => $exercise->sets,
                    'status' => $firstOrder !== null && $exercise->sequence_order === $firstOrder
                        ? 'active'
                        : 'locked',
                    'last_marked_at' => null,
                ]);
            }
        }

        $progress->load(['exercises.trainingProgramSessionExercise']);

        $orderedProgressExercises = $progress->exercises
            ->sortBy(fn ($item) => $item->trainingProgramSessionExercise?->sequence_order ?? PHP_INT_MAX)
            ->values();

        $firstIncomplete = $orderedProgressExercises->first(function ($item) {
            return (int) $item->completed_sets < (int) $item->total_sets;
        });

        $currentExerciseOrder = $firstIncomplete?->trainingProgramSessionExercise?->sequence_order;

        foreach ($orderedProgressExercises as $item) {
            $exerciseOrder = $item->trainingProgramSessionExercise?->sequence_order;

            $nextStatus = (int) $item->completed_sets >= (int) $item->total_sets
                ? 'complete'
                : ($exerciseOrder !== null && $exerciseOrder === $currentExerciseOrder ? 'active' : 'locked');

            if ($item->status !== $nextStatus) {
                $item->update([
                    'status' => $nextStatus,
                ]);

                $item->status = $nextStatus;
            }
        }
        $this->syncProgramSessionExerciseStatuses($progress);
        $totalSets = $orderedProgressExercises->sum(fn ($item) => (int) $item->total_sets);
        $completedSets = $orderedProgressExercises->sum(
            fn ($item) => min((int) $item->completed_sets, (int) $item->total_sets)
        );

        $progressPercent = $totalSets > 0
            ? round(($completedSets / $totalSets) * 100, 2)
            : 0;

        $sessionStatus = $totalSets > 0 && $completedSets >= $totalSets
            ? 'completed'
            : 'active';

        $progress->update([
            'progress_percent' => $progressPercent,
            'current_exercise_order' => $currentExerciseOrder,
            'status' => $sessionStatus,
        ]);

        $progress->refresh();

        return response()->json([
            'success' => true,
            'message' => 'Progres sesi trainer berhasil diambil.',
            'data' => [
                'session_progress' => [
                    'id' => $progress->id,
                    'progress_percent' => (float) $progress->progress_percent,
                    'status' => $progress->status,
                    'current_exercise_order' => $progress->current_exercise_order,
                    'trainer_note' => $progress->trainer_note,
                ],
                'exercises' => $orderedProgressExercises->map(function ($item) {
                    $exercise = $item->trainingProgramSessionExercise;

                    return [
                        'id' => $exercise?->id,
                        'order' => $exercise?->sequence_order,
                        'title' => $exercise?->custom_name ?? 'Exercise',
                        'target_muscle' => $exercise?->custom_target_muscle,
                        'equipment_id' => $exercise?->equipment_id,
                        'equipment_name' => $exercise?->equipment_name,
                        'gym_equipment_movement_id' => $exercise?->gym_equipment_movement_id,
                        'subtitle' => $item->total_sets.' set x '.($exercise?->reps ?? 0).' reps',
                        'cue' => $exercise?->cue_text,
                        'total_sets' => (int) $item->total_sets,
                        'completed_sets' => (int) $item->completed_sets,
                        'status' => $item->status,
                    ];
                })->values(),
            ],
            'meta' => null,
        ]);
    }

    /**
     * Update trainer-side progress for a specific program session.
     */
    public function updateSessionProgress(
        UpdateTrainerSessionProgressRequest $request,
        int $id,
        TrainingSessionExecutionGuard $executionGuard
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $session = TrainingProgramSession::query()
            ->with(['trainingProgram.memberProfile', 'exercises'])
            ->where('id', $id)
            ->first();

        if (! $session || $session->trainingProgram?->trainer_profile_id !== $trainerProfile->id) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi program tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        try {
            $executionGuard->assertCanExecute($session);
        } catch (BookingScheduleException $exception) {
            return response()->json(['success' => false, 'message' => $exception->getMessage()], $exception->httpStatus);
        }

        // Guard: trainer tidak boleh mencentang exercise sebelum member menekan
        // "Start Session" (member_ready) untuk sesi INI. Approval bersifat per-sesi.
        if (! $session->member_ready) {
            return response()->json([
                'success' => false,
                'message' => 'Member belum menekan "Start Session" untuk sesi ini. Tunggu member menyiapkan sesi sebelum mencentang latihan.',
            ], 422);
        }

        $orderedExercises = $session->exercises
            ->sortBy('sequence_order')
            ->values();

        $progress = TrainerSessionProgress::query()
            ->firstOrCreate(
                ['training_program_session_id' => $session->id],
                [
                    'training_program_id' => $session->training_program_id,
                    'trainer_profile_id' => $trainerProfile->id,
                    'member_profile_id' => $session->trainingProgram->member_profile_id,
                    'progress_percent' => 0,
                    'current_exercise_order' => $orderedExercises->first()?->sequence_order,
                    'status' => 'active',
                    'trainer_note' => null,
                ]
            );

        $existingExerciseIds = TrainerSessionProgressExercise::query()
            ->where('trainer_session_progress_id', $progress->id)
            ->pluck('training_program_session_exercise_id')
            ->all();

        $firstOrder = $orderedExercises->first()?->sequence_order;

        foreach ($orderedExercises as $exercise) {
            if (! in_array($exercise->id, $existingExerciseIds, true)) {
                TrainerSessionProgressExercise::create([
                    'trainer_session_progress_id' => $progress->id,
                    'training_program_session_exercise_id' => $exercise->id,
                    'completed_sets' => 0,
                    'total_sets' => $exercise->sets,
                    'status' => $firstOrder !== null && $exercise->sequence_order === $firstOrder
                        ? 'active'
                        : 'locked',
                    'last_marked_at' => null,
                ]);
            }
        }

        $validated = $request->validated();

        $progressExercise = TrainerSessionProgressExercise::query()
            ->with('trainingProgramSessionExercise')
            ->where('trainer_session_progress_id', $progress->id)
            ->where('training_program_session_exercise_id', $validated['exercise_id'])
            ->first();

        if (! $progressExercise) {
            return response()->json([
                'success' => false,
                'message' => 'Exercise tidak ditemukan pada sesi program ini.',
            ], 404);
        }

        if ((int) $validated['completed_sets'] > (int) $progressExercise->total_sets) {
            return response()->json([
                'success' => false,
                'message' => 'Completed sets tidak boleh melebihi total sets exercise ini.',
            ], 422);
        }

        $progressExercise->update([
            'completed_sets' => $validated['completed_sets'],
            'status' => (int) $validated['completed_sets'] >= (int) $progressExercise->total_sets
                ? 'complete'
                : 'active',
            'last_marked_at' => now(),
        ]);

        $progress->load(['exercises.trainingProgramSessionExercise']);

        $orderedProgressExercises = $progress->exercises
            ->sortBy(fn ($item) => $item->trainingProgramSessionExercise?->sequence_order ?? PHP_INT_MAX)
            ->values();

        $firstIncomplete = $orderedProgressExercises->first(function ($item) {
            return (int) $item->completed_sets < (int) $item->total_sets;
        });

        $currentExerciseOrder = $firstIncomplete?->trainingProgramSessionExercise?->sequence_order;

        foreach ($orderedProgressExercises as $item) {
            $exerciseOrder = $item->trainingProgramSessionExercise?->sequence_order;

            $nextStatus = (int) $item->completed_sets >= (int) $item->total_sets
                ? 'complete'
                : ($exerciseOrder !== null && $exerciseOrder === $currentExerciseOrder ? 'active' : 'locked');

            if ($item->status !== $nextStatus) {
                $item->update([
                    'status' => $nextStatus,
                ]);

                $item->status = $nextStatus;
            }
        }
        $this->syncProgramSessionExerciseStatuses($progress);
        $totalSets = $orderedProgressExercises->sum(fn ($item) => (int) $item->total_sets);
        $completedSets = $orderedProgressExercises->sum(
            fn ($item) => min((int) $item->completed_sets, (int) $item->total_sets)
        );

        $progressPercent = $totalSets > 0
            ? round(($completedSets / $totalSets) * 100, 2)
            : 0;

        $requestedStatus = $validated['status'] ?? 'active';

        $sessionProgressStatus = $totalSets > 0 && $completedSets >= $totalSets
            ? 'completed'
            : ($requestedStatus === 'paused' ? 'paused' : 'active');

        $progress->update([
            'progress_percent' => $progressPercent,
            'current_exercise_order' => $currentExerciseOrder,
            'status' => $sessionProgressStatus,
            'synced_at' => now(),
            'trainer_note' => array_key_exists('trainer_note', $validated)
                ? $validated['trainer_note']
                : $progress->trainer_note,
        ]);

        // Jika semua exercise selesai, gunakan fungsi terpusat untuk complete + unlock
        if ($sessionProgressStatus === 'completed') {
            $this->completeSessionAndUnlockNext($session, $progress);
        }

        $progress->refresh()->load(['exercises.trainingProgramSessionExercise']);

        $orderedProgressExercises = $progress->exercises
            ->sortBy(fn ($item) => $item->trainingProgramSessionExercise?->sequence_order ?? PHP_INT_MAX)
            ->values();

        return response()->json([
            'success' => true,
            'message' => 'Progres sesi trainer berhasil diperbarui.',
            'data' => [
                'session_progress' => [
                    'id' => $progress->id,
                    'progress_percent' => (float) $progress->progress_percent,
                    'status' => $progress->status,
                    'current_exercise_order' => $progress->current_exercise_order,
                    'trainer_note' => $progress->trainer_note,
                ],
                'exercises' => $orderedProgressExercises->map(function ($item) {
                    $exercise = $item->trainingProgramSessionExercise;

                    return [
                        'id' => $exercise?->id,
                        'order' => $exercise?->sequence_order,
                        'title' => $exercise?->custom_name ?? 'Exercise',
                        'target_muscle' => $exercise?->custom_target_muscle,
                        'equipment_id' => $exercise?->equipment_id,
                        'equipment_name' => $exercise?->equipment_name,
                        'gym_equipment_movement_id' => $exercise?->gym_equipment_movement_id,
                        'subtitle' => $item->total_sets.' set x '.($exercise?->reps ?? 0).' reps',
                        'cue' => $exercise?->cue_text,
                        'total_sets' => (int) $item->total_sets,
                        'completed_sets' => (int) $item->completed_sets,
                        'status' => $item->status,
                    ];
                })->values(),
            ],
            'meta' => null,
        ]);
    }

    /**
     * Complete trainer-side progress for a specific program session.
     */
    public function completeSessionProgress(
        Request $request,
        int $id,
        UserNotificationService $userNotificationService,
        TrainingSessionExecutionGuard $executionGuard
    ): JsonResponse {
        $user = $request->user()->load('trainerProfile');
        $trainerProfile = $user->trainerProfile;

        if (! $trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $session = TrainingProgramSession::query()
            ->with(['trainingProgram.memberProfile.user', 'trainingProgram.trainerProfile.user', 'exercises'])
            ->where('id', $id)
            ->first();

        if (! $session || $session->trainingProgram?->trainer_profile_id !== $trainerProfile->id) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi program tidak ditemukan untuk trainer ini.',
            ], 404);
        }

        try {
            $executionGuard->assertCanExecute($session);
        } catch (BookingScheduleException $exception) {
            return response()->json(['success' => false, 'message' => $exception->getMessage()], $exception->httpStatus);
        }

        // Guard: trainer tidak boleh menyelesaikan sesi sebelum member menekan
        // "Start Session" (member_ready) untuk sesi INI. Approval bersifat per-sesi.
        if (! $session->member_ready) {
            return response()->json([
                'success' => false,
                'message' => 'Member belum menekan "Start Session" untuk sesi ini. Tunggu member menyiapkan sesi sebelum menyelesaikan latihan.',
            ], 422);
        }

        $orderedExercises = $session->exercises
            ->sortBy('sequence_order')
            ->values();

        $progress = TrainerSessionProgress::query()
            ->firstOrCreate(
                ['training_program_session_id' => $session->id],
                [
                    'training_program_id' => $session->training_program_id,
                    'trainer_profile_id' => $trainerProfile->id,
                    'member_profile_id' => $session->trainingProgram->member_profile_id,
                    'progress_percent' => 0,
                    'current_exercise_order' => $orderedExercises->first()?->sequence_order,
                    'status' => 'active',
                    'trainer_note' => null,
                ]
            );

        $existingExerciseIds = TrainerSessionProgressExercise::query()
            ->where('trainer_session_progress_id', $progress->id)
            ->pluck('training_program_session_exercise_id')
            ->all();

        $firstOrder = $orderedExercises->first()?->sequence_order;

        foreach ($orderedExercises as $exercise) {
            if (! in_array($exercise->id, $existingExerciseIds, true)) {
                TrainerSessionProgressExercise::create([
                    'trainer_session_progress_id' => $progress->id,
                    'training_program_session_exercise_id' => $exercise->id,
                    'completed_sets' => 0,
                    'total_sets' => $exercise->sets,
                    'status' => $firstOrder !== null && $exercise->sequence_order === $firstOrder
                        ? 'active'
                        : 'locked',
                    'last_marked_at' => null,
                ]);
            }
        }

        $progress->load(['exercises.trainingProgramSessionExercise']);

        // Hitung progress berdasarkan exercise yang sudah selesai
        $totalSets = $progress->exercises->sum(fn ($item) => (int) $item->total_sets);
        $completedSets = $progress->exercises->sum(
            fn ($item) => min((int) $item->completed_sets, (int) $item->total_sets)
        );

        $progressPercent = $totalSets > 0
            ? round(($completedSets / $totalSets) * 100, 2)
            : 0;

        // Gunakan fungsi terpusat untuk complete + unlock + notifikasi
        DB::transaction(function () use ($session, $progress, $userNotificationService): void {
            $lockedSession = TrainingProgramSession::query()
                ->with(['exercises', 'bookingSessionReservation'])
                ->lockForUpdate()
                ->findOrFail($session->id);
            $lockedProgress = TrainerSessionProgress::query()
                ->lockForUpdate()
                ->findOrFail($progress->id);
            $this->completeSessionAndUnlockNext(
                $lockedSession,
                $lockedProgress,
                $userNotificationService
            );
        });

        $progress->refresh()->load(['exercises.trainingProgramSessionExercise']);

        $orderedProgressExercises = $progress->exercises
            ->sortBy(fn ($item) => $item->trainingProgramSessionExercise?->sequence_order ?? PHP_INT_MAX)
            ->values();

        return response()->json([
            'success' => true,
            'message' => 'Sesi trainer berhasil diselesaikan.',
            'data' => [
                'session_progress' => [
                    'id' => $progress->id,
                    'progress_percent' => (float) $progress->progress_percent,
                    'status' => $progress->status,
                    'current_exercise_order' => $progress->current_exercise_order,
                    'trainer_note' => $progress->trainer_note,
                ],
                'exercises' => $orderedProgressExercises->map(function ($item) {
                    $exercise = $item->trainingProgramSessionExercise;

                    return [
                        'id' => $exercise?->id,
                        'order' => $exercise?->sequence_order,
                        'title' => $exercise?->custom_name ?? 'Exercise',
                        'target_muscle' => $exercise?->custom_target_muscle,
                        'equipment_id' => $exercise?->equipment_id,
                        'equipment_name' => $exercise?->equipment_name,
                        'gym_equipment_movement_id' => $exercise?->gym_equipment_movement_id,
                        'subtitle' => $item->total_sets.' set x '.($exercise?->reps ?? 0).' reps',
                        'cue' => $exercise?->cue_text,
                        'total_sets' => (int) $item->total_sets,
                        'completed_sets' => (int) $item->completed_sets,
                        'status' => $item->status,
                    ];
                })->values(),
            ],
            'meta' => null,
        ]);
    }

    private function syncProgramSessionExerciseStatuses(TrainerSessionProgress $progress): void
    {
        $progress->loadMissing(['exercises.trainingProgramSessionExercise']);

        foreach ($progress->exercises as $item) {
            $exercise = $item->trainingProgramSessionExercise;

            if (! $exercise) {
                continue;
            }

            $mappedStatus = $item->status === 'complete'
                ? 'completed'
                : $item->status;

            if ($exercise->status !== $mappedStatus) {
                $exercise->update([
                    'status' => $mappedStatus,
                ]);

                $exercise->status = $mappedStatus;
            }
        }
    }

    /**
     * Fungsi terpusat untuk menyelesaikan sesi dan unlock sesi berikutnya.
     * Dipanggil oleh kedua jalur: checkbox auto-complete dan tombol "Selesaikan Sesi".
     */
    private function completeSessionAndUnlockNext(
        TrainingProgramSession $session,
        TrainerSessionProgress $progress,
        ?UserNotificationService $userNotificationService = null
    ): void {
        // Paksa semua exercise jadi completed untuk konsistensi data
        $progress->load(['exercises.trainingProgramSessionExercise']);

        foreach ($progress->exercises as $item) {
            if ((int) $item->completed_sets < (int) $item->total_sets) {
                $item->update([
                    'completed_sets' => (int) $item->total_sets,
                    'status' => 'complete',
                    'last_marked_at' => now(),
                ]);
            }
        }

        // Update progress status ke completed
        $progress->update([
            'progress_percent' => 100,
            'status' => 'completed',
            'current_exercise_order' => null,
            'synced_at' => now(),
            'trainer_note' => $progress->trainer_note ?: 'Sesi selesai oleh trainer.',
        ]);

        // Update session status ke completed
        $session->update([
            'status' => 'completed',
        ]);
        $reservation = $session->bookingSessionReservation;
        if ($reservation && $reservation->status === BookingSessionReservation::STATUS_RESERVED) {
            $reservation->update([
                'status' => BookingSessionReservation::STATUS_COMPLETED,
                'completed_at' => now(),
            ]);
        }

        // Sinkronisasi status exercise di tabel training_program_session_exercises
        foreach ($session->exercises as $exercise) {
            if ($exercise->status !== 'completed') {
                $exercise->update(['status' => 'completed']);
            }
        }

        // Cari sesi berikutnya dan unlock
        $nextSession = $this->executionOrderService->reconcile($session->training_program_id);

        // Jika SELURUH sesi program sudah selesai, tandai booking terkait sebagai
        // completed agar slot kuota trainer langsung dibebaskan — TANPA menunggu
        // member memberi rating (rating tetap opsional setelah program selesai).
        $this->syncBookingCompletionForProgram($session->training_program_id);

        // Kirim notifikasi ke member
        if ($userNotificationService) {
            $session->load(['trainingProgram.memberProfile.user', 'trainingProgram.trainerProfile.user']);
            $memberUser = $session->trainingProgram?->memberProfile?->user;
            $nextSessionTitle = $nextSession?->title;
            $trainerName = $session->trainingProgram?->trainerProfile?->user?->name ?? 'trainer kamu';

            if ($memberUser) {
                $message = 'Sesi "'.$session->title.'" pada program "'
                    .$session->trainingProgram->title.'" sudah diselesaikan oleh '.$trainerName.'.';

                if ($nextSessionTitle) {
                    $message .= ' Sesi berikutnya "'.$nextSessionTitle.'" sekarang aktif.';
                }

                $userNotificationService->notify(
                    $memberUser,
                    'Sesi PT Selesai',
                    $message,
                    'progress',
                    'push',
                    true,
                    [
                        'program_id' => (string) $session->training_program_id,
                        'session_id' => (string) $session->id,
                        'next_session_id' => $nextSession ? (string) $nextSession->id : null,
                    ]
                );
            }
        }
    }

    /**
     * Tandai booking sebagai 'completed' bila SELURUH sesi program sudah selesai
     * (100%). Trigger ini dipicu oleh kondisi program selesai, BUKAN oleh submit
     * rating — sehingga slot kuota trainer langsung bebas begitu program tuntas.
     *
     * booking_id pada program sering NULL (dibuat via Program Builder), jadi
     * booking di-resolve via member_profile_id + trainer_profile_id.
     */
    private function syncBookingCompletionForProgram(int $trainingProgramId): void
    {
        $program = TrainingProgram::query()
            ->withCount([
                'sessions',
                'sessions as completed_sessions_count' => function ($query) {
                    $query->where('status', 'completed');
                },
            ])
            ->where('id', $trainingProgramId)
            ->first();

        if (! $program) {
            return;
        }

        $programCompleted = $program->sessions_count > 0
            && $program->completed_sessions_count === $program->sessions_count;

        if (! $programCompleted) {
            return;
        }

        $program->update([
            'status' => 'completed',
            'ended_at' => $program->ended_at ?? now()->toDateString(),
        ]);

        if ($program->booking_id !== null) {
            Booking::query()
                ->whereKey($program->booking_id)
                ->whereIn('status', MemberProfile::ACTIVE_BOOKING_STATUSES)
                ->update(['status' => 'completed']);

            return;
        }

        // Program legacy tanpa booking_id tidak boleh menyelesaikan booking baru
        // hanya karena pasangan member dan trainer sama.
    }

    private function validatedEquipmentSource(array $validated): array
    {
        $equipmentId = $validated['equipment_id'] ?? null;
        $movementId = $validated['gym_equipment_movement_id'] ?? null;
        if ($equipmentId === null || $movementId === null) {
            return [
                'equipment_id' => null,
                'gym_equipment_movement_id' => null,
                'equipment_name' => null,
                'movement_name' => null,
                'target_area' => null,
            ];
        }

        $movement = GymEquipmentMovement::query()
            ->with('equipment:id,name')
            ->whereKey($movementId)
            ->where('gym_equipment_id', $equipmentId)
            ->first();
        abort_if($movement === null, 422, 'Gerakan tidak tersedia pada alat gym yang dipilih.');

        return [
            'equipment_id' => $movement->gym_equipment_id,
            'gym_equipment_movement_id' => $movement->id,
            'equipment_name' => $movement->equipment->name,
            'movement_name' => $movement->movement_name,
            'target_area' => $movement->target_area,
        ];
    }
}

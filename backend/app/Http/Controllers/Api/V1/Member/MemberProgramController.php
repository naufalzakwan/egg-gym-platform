<?php

namespace App\Http\Controllers\Api\V1\Member;

use App\Exceptions\BookingScheduleException;
use App\Http\Controllers\Controller;
use App\Models\BookingSessionReservation;
use App\Models\TrainerRating;
use App\Models\TrainerSessionProgress;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use App\Services\TrainingProgram\TrainingProgramExecutionOrderService;
use App\Services\TrainingProgram\TrainingSessionExecutionGuard;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;

class MemberProgramController extends Controller
{
    /**
     * Display the authenticated member programs.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        $type = $request->query('type');

        if ($type === 'self_training') {
            return response()->json([
                'success' => true,
                'message' => 'Daftar program member berhasil diambil.',
                'data' => [],
                'meta' => null,
            ]);
        }

        $programs = TrainingProgram::query()
            ->with([
                'trainerProfile.user',
                'memberProfile.user',
                'sessions.bookingSessionReservation:id,session_date,start_time,end_time,session_duration_minutes,completed_at',
                'sessions.trainerSessionProgress:id,training_program_session_id,progress_percent',
            ])
            ->where('member_profile_id', $memberProfile->id)
            ->whereIn('status', ['active', 'completed'])
            ->latest('id')
            ->get()
            ->map(function (TrainingProgram $program) {
                return $this->buildProgramSummary($program);
            })
            ->values();

        return response()->json([
            'success' => true,
            'message' => 'Daftar program member berhasil diambil.',
            'data' => $programs,
            'meta' => null,
        ]);
    }

    /**
     * Display a specific member program summary.
     */
    public function show(
        Request $request,
        int $id,
        TrainingProgramExecutionOrderService $executionOrderService
    ): JsonResponse {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        $program = TrainingProgram::query()
            ->with([
                'trainerProfile.user',
                'memberProfile.user',
                'sessions.exercises',
                'sessions.bookingSessionReservation.pendingRescheduleRequest.requestedBy',
            ])
            ->where('id', $id)
            ->where('member_profile_id', $memberProfile->id)
            ->first();

        if (! $program) {
            return response()->json([
                'success' => false,
                'message' => 'Program tidak ditemukan untuk member ini.',
            ], 404);
        }

        $executionOrderService->reconcile($program->id);
        $program->load([
            'sessions.exercises',
            'sessions.bookingSessionReservation.pendingRescheduleRequest.requestedBy',
        ]);

        $sessions = $program->sessions
            ->sortBy('sequence_order')
            ->values();

        $activeSession = $sessions->firstWhere('status', 'active');

        $currentProgress = null;

        if ($activeSession) {
            $currentProgress = TrainerSessionProgress::query()
                ->with(['exercises.trainingProgramSessionExercise'])
                ->where('training_program_session_id', $activeSession->id)
                ->first();
        }

        return response()->json([
            'success' => true,
            'message' => 'Detail program member berhasil diambil.',
            'data' => [
                'id' => $program->id,
                'title' => $program->title,
                'description' => $program->description,
                'goal' => $program->goal,
                'status' => $this->resolveProgramStatus($program, $sessions),
                'trainer_name' => $program->trainerProfile?->user?->name,
                'member_name' => $program->memberProfile?->user?->name,
                'progress_percent' => $this->calculateProgramProgressPercent(
                    $sessions,
                    $activeSession,
                    $currentProgress
                ),
                'active_session_title' => $activeSession?->title,
                'started_at' => $program->started_at?->toDateString(),
                'ended_at' => $program->ended_at?->toDateString(),
                'summary' => [
                    'total_sessions' => $sessions->count(),
                    'completed_sessions' => $sessions->where('status', 'completed')->count(),
                    'active_sessions' => $sessions->where('status', 'active')->count(),
                    'locked_sessions' => $sessions->filter(function ($session) {
                        return in_array($session->status, ['locked', 'upcoming'], true);
                    })->count(),
                ],
                'sessions' => $sessions->map(function ($session) {
                    return [
                        'id' => $session->id,
                        'booking_session_reservation_id' => $session->booking_session_reservation_id,
                        'reservation' => $session->bookingSessionReservation ? [
                            'id' => $session->bookingSessionReservation->id,
                            'sequence_order' => $session->bookingSessionReservation->sequence_order,
                            'session_date' => $session->bookingSessionReservation->session_date?->toDateString(),
                            'start_time' => $session->bookingSessionReservation->start_time,
                            'end_time' => $session->bookingSessionReservation->end_time,
                            'status' => $session->bookingSessionReservation->status,
                            'has_pending_reschedule' => $session->bookingSessionReservation
                                ->pendingRescheduleRequest?->status === 'pending'
                                && $session->bookingSessionReservation
                                    ->pendingRescheduleRequest?->expired_at?->isFuture(),
                        ] : null,
                        'sequence_order' => $session->sequence_order,
                        'title' => $session->title,
                        'focus' => $session->focus,
                        'duration_minutes' => $session->duration_minutes,
                        'status' => $session->status,
                        'coach_note' => $session->coach_note,
                        'member_ready' => (bool) $session->member_ready,
                        'member_ready_at' => $session->member_ready_at?->toIso8601String(),
                        'exercise_count' => $session->exercises->count(),
                        'exercises' => $session->exercises->sortBy('sequence_order')->map(function ($exercise) use ($session) {
                            // Ambil progress aktual dari trainer_session_progress_exercises
                            $sessionProgress = \App\Models\TrainerSessionProgress::query()
                                ->where('training_program_session_id', $session->id)
                                ->first();

                            $progressExercise = null;
                            if ($sessionProgress) {
                                $progressExercise = \App\Models\TrainerSessionProgressExercise::query()
                                    ->where('trainer_session_progress_id', $sessionProgress->id)
                                    ->where('training_program_session_exercise_id', $exercise->id)
                                    ->first();
                            }

                            return [
                                'id' => $exercise->id,
                                'order' => $exercise->sequence_order,
                                'title' => $exercise->custom_name ?? 'Exercise',
                                'subtitle' => $exercise->sets.' set x '.$exercise->reps.' reps',
                                'target_muscle' => $exercise->custom_target_muscle,
                                'total_sets' => $progressExercise ? (int) $progressExercise->total_sets : (int) $exercise->sets,
                                'completed_sets' => $progressExercise ? (int) $progressExercise->completed_sets : 0,
                                'status' => $progressExercise?->status ?? 'pending',
                            ];
                        })->values(),
                    ];
                })->values(),
            ],
            'meta' => null,
        ]);
    }

    /**
     * Display a read-only tracker for a member training program.
     */
    public function showTracker(Request $request, int $id): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        $program = TrainingProgram::query()
            ->with([
                'trainerProfile.user',
                'sessions.exercises',
            ])
            ->where('id', $id)
            ->where('member_profile_id', $memberProfile->id)
            ->first();

        if (! $program) {
            return response()->json([
                'success' => false,
                'message' => 'Program tidak ditemukan untuk member ini.',
            ], 404);
        }

        $sessions = $program->sessions
            ->sortBy('sequence_order')
            ->values();

        $activeSession = $sessions->firstWhere('status', 'active');

        $currentProgress = null;

        if ($activeSession) {
            $currentProgress = TrainerSessionProgress::query()
                ->with(['exercises.trainingProgramSessionExercise'])
                ->where('training_program_session_id', $activeSession->id)
                ->first();
        }

        $hasTrainerSync = TrainerSessionProgress::query()
            ->where('training_program_id', $program->id)
            ->exists();

        $trainerName = $program->trainerProfile?->user?->name;

        return response()->json([
            'success' => true,
            'message' => 'Tracker program member berhasil diambil.',
            'data' => [
                'program' => [
                    'id' => $program->id,
                    'title' => $program->title,
                    'status' => $this->resolveProgramStatus($program, $sessions),
                    'progress_percent' => $this->calculateProgramProgressPercent(
                        $sessions,
                        $activeSession,
                        $currentProgress
                    ),
                ],
                'sequence_summary' => [
                    'completed_count' => $sessions->where('status', 'completed')->count(),
                    'active_count' => $sessions->where('status', 'active')->count(),
                    'locked_count' => $sessions->filter(function ($session) {
                        return in_array($session->status, ['locked', 'upcoming'], true);
                    })->count(),
                ],
                'active_session' => $activeSession ? [
                    'id' => $activeSession->id,
                    'title' => $activeSession->title,
                    'focus' => $activeSession->focus,
                    'status' => $activeSession->status,
                    'coach_note' => $activeSession->coach_note,
                ] : null,
                'synced_by_trainer' => $hasTrainerSync,
                'sync_source_label' => $hasTrainerSync && $trainerName
                    ? $trainerName.' terverifikasi'
                    : null,
                'exercises' => $this->buildTrackerExercises($activeSession, $currentProgress),
            ],
            'meta' => null,
        ]);
    }

    private function buildProgramSummary(TrainingProgram $program): array
    {
        $sessions = $program->sessions
            ->sortBy('sequence_order')
            ->values();

        $activeSession = $sessions->firstWhere('status', 'active');

        $currentProgress = $activeSession?->trainerSessionProgress;

        // Deteksi program 100% selesai (semua sesi completed).
        $totalSessions = $sessions->count();
        $completedSessions = $sessions->where('status', 'completed')->count();
        $programCompleted = $totalSessions > 0 && $completedSessions === $totalSessions;

        // Cek apakah member sudah pernah memberi rating untuk PROGRAM ini.
        // Dikunci ke training_program_id (bukan booking_id yang bisa NULL).
        $rating = TrainerRating::query()
            ->where('member_profile_id', $program->member_profile_id)
            ->where('training_program_id', $program->id)
            ->latest('id')
            ->first();
        $alreadyRated = $rating !== null;
        $lastCompletedSession = $sessions
            ->where('status', 'completed')
            ->filter(fn (TrainingProgramSession $session) => $session->bookingSessionReservation !== null)
            ->sort(function (TrainingProgramSession $left, TrainingProgramSession $right): int {
                $leftReservation = $left->bookingSessionReservation;
                $rightReservation = $right->bookingSessionReservation;
                $leftCompletedAt = $leftReservation?->completed_at;
                $rightCompletedAt = $rightReservation?->completed_at;

                if ($leftCompletedAt && $rightCompletedAt) {
                    $completedAtComparison = $rightCompletedAt->getTimestamp() <=> $leftCompletedAt->getTimestamp();

                    if ($completedAtComparison !== 0) {
                        return $completedAtComparison;
                    }
                }

                if ($leftCompletedAt || $rightCompletedAt) {
                    return $leftCompletedAt ? -1 : 1;
                }

                $leftChronology = $this->reservationChronology($left);
                $rightChronology = $this->reservationChronology($right);

                return $rightChronology <=> $leftChronology;
            })
            ->first();
        $lastReservation = $lastCompletedSession?->bookingSessionReservation;

        return [
            'id' => $program->id,
            'booking_id' => $program->booking_id,
            'title' => $program->title,
            'description' => $program->description,
            'goal' => $program->goal,
            'status' => $this->resolveProgramStatus($program, $sessions),
            'trainer_profile_id' => $program->trainer_profile_id,
            'trainer_name' => $program->trainerProfile?->user?->name,
            'trainer_avatar_url' => $program->trainerProfile?->user?->avatar_url,
            'trainer_display_photo_path' => $program->trainerProfile?->display_photo_path,
            'member_name' => $program->memberProfile?->user?->name,
            'progress_percent' => $this->calculateProgramProgressPercent(
                $sessions,
                $activeSession,
                $currentProgress
            ),
            'active_session_title' => $activeSession?->title,
            'total_sessions' => $totalSessions,
            'completed_sessions' => $completedSessions,
            'started_at' => $program->started_at?->toDateString(),
            'ended_at' => $program->ended_at?->toDateString(),
            'last_session_date' => $lastReservation?->session_date?->toDateString(),
            'completed_at' => $lastReservation?->completed_at?->toIso8601String(),
            'last_session_duration_minutes' => $lastReservation
                ? $this->reservationDurationMinutes($lastReservation)
                : null,
            'program_completed' => $programCompleted,
            'already_rated' => $alreadyRated,
            'rating' => $rating?->rating,
            'rated_at' => $rating?->created_at?->toIso8601String(),
            // Boleh memberi rating bila program selesai dan belum pernah rating.
            'can_rate' => $programCompleted && ! $alreadyRated,
        ];
    }

    private function reservationChronology(TrainingProgramSession $session): int
    {
        $reservation = $session->bookingSessionReservation;

        if (! $reservation?->session_date) {
            return PHP_INT_MIN;
        }

        try {
            return CarbonImmutable::parse(
                $reservation->session_date->toDateString().' '.($reservation->end_time ?: '00:00:00'),
                config('app.timezone')
            )->getTimestamp();
        } catch (\Throwable) {
            return $reservation->session_date->getTimestamp();
        }
    }

    private function reservationDurationMinutes(BookingSessionReservation $reservation): ?int
    {
        if ($reservation->start_time && $reservation->end_time) {
            try {
                $start = CarbonImmutable::parse($reservation->start_time, config('app.timezone'));
                $end = CarbonImmutable::parse($reservation->end_time, config('app.timezone'));

                if ($end->greaterThan($start)) {
                    return $start->diffInMinutes($end);
                }
            } catch (\Throwable) {
                // Fall back to the reservation's persisted duration below.
            }
        }

        $duration = $reservation->session_duration_minutes;

        return $duration === null ? null : (int) $duration;
    }

    private function resolveProgramStatus(
        TrainingProgram $program,
        Collection $sessions
    ): string {
        $totalSessions = $sessions->count();

        if ($totalSessions === 0) {
            return $program->status;
        }

        $completedCount = $sessions->where('status', 'completed')->count();
        $activeCount = $sessions->where('status', 'active')->count();

        if ($completedCount === $totalSessions) {
            return 'completed';
        }

        if ($activeCount > 0 || $completedCount > 0) {
            return 'active';
        }

        return $program->status;
    }

    private function calculateProgramProgressPercent(
        Collection $sessions,
        $activeSession,
        ?TrainerSessionProgress $currentProgress
    ): float {
        $totalSessions = $sessions->count();

        if ($totalSessions === 0) {
            return 0;
        }

        $completedCount = $sessions->where('status', 'completed')->count();
        $progressUnits = (float) $completedCount;

        if ($activeSession && $activeSession->status === 'active' && $currentProgress) {
            $progressUnits += ((float) $currentProgress->progress_percent / 100);
        }

        return round(min(($progressUnits / $totalSessions) * 100, 100), 2);
    }

    private function buildTrackerExercises(
        $activeSession,
        ?TrainerSessionProgress $currentProgress
    ): array {
        if (! $activeSession) {
            return [];
        }

        if ($currentProgress) {
            return $currentProgress->exercises
                ->sortBy(function ($item) {
                    return $item->trainingProgramSessionExercise?->sequence_order ?? PHP_INT_MAX;
                })
                ->map(function ($item) {
                    $exercise = $item->trainingProgramSessionExercise;

                    return [
                        'id' => $exercise?->id,
                        'order' => $exercise?->sequence_order,
                        'title' => $exercise?->custom_name ?? 'Exercise',
                        'subtitle' => $item->total_sets.' set x '.($exercise?->reps ?? 0).' reps',
                        'cue' => $exercise?->cue_text,
                        'total_sets' => (int) $item->total_sets,
                        'completed_sets' => (int) $item->completed_sets,
                        'status' => $item->status,
                    ];
                })
                ->values()
                ->all();
        }

        return $activeSession->exercises
            ->sortBy('sequence_order')
            ->map(function ($exercise) {
                return [
                    'id' => $exercise->id,
                    'order' => $exercise->sequence_order,
                    'title' => $exercise->custom_name ?? 'Exercise',
                    'subtitle' => $exercise->sets.' set x '.$exercise->reps.' reps',
                    'cue' => $exercise->cue_text,
                    'total_sets' => (int) $exercise->sets,
                    'completed_sets' => 0,
                    'status' => $exercise->status === 'completed'
                        ? 'complete'
                        : $exercise->status,
                ];
            })
            ->values()
            ->all();
    }

    /**
     * Mark a session as ready by member (member is at gym and ready to start).
     */
    public function markSessionReady(
        Request $request,
        int $programId,
        int $sessionId,
        TrainingSessionExecutionGuard $executionGuard
    ): JsonResponse {
        \Log::info('markSessionReady called', [
            'programId' => $programId,
            'sessionId' => $sessionId,
            'user_id' => $request->user()?->id,
        ]);

        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            \Log::warning('markSessionReady: memberProfile not found');

            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        \Log::info('markSessionReady: memberProfile found', ['id' => $memberProfile->id]);

        $program = TrainingProgram::query()
            ->where('id', $programId)
            ->where('member_profile_id', $memberProfile->id)
            ->first();

        if (! $program) {
            \Log::warning('markSessionReady: program not found', [
                'programId' => $programId,
                'member_profile_id' => $memberProfile->id,
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Program tidak ditemukan untuk member ini.',
            ], 404);
        }

        \Log::info('markSessionReady: program found', ['id' => $program->id, 'title' => $program->title]);

        $session = TrainingProgramSession::query()
            ->where('id', $sessionId)
            ->where('training_program_id', $program->id)
            ->first();

        if (! $session) {
            \Log::warning('markSessionReady: session not found', [
                'sessionId' => $sessionId,
                'training_program_id' => $program->id,
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Sesi tidak ditemukan dalam program ini.',
            ], 404);
        }

        \Log::info('markSessionReady: session found', [
            'id' => $session->id,
            'status' => $session->status,
            'member_ready' => $session->member_ready,
        ]);

        try {
            $executionGuard->assertCanExecute($session);
        } catch (BookingScheduleException $exception) {
            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
            ], $exception->httpStatus);
        }

        // Toggle kunci/buka izin centang trainer:
        // - member_ready = true  -> "Sesi Siap" (PT boleh mencentang exercise)
        // - member_ready = false -> "Start Session" (PT terkunci, tidak bisa
        //   mencentang) tapi exercise yang sudah tercentang TETAP tersimpan.
        // Toggle ini murni gembok izin, BUKAN pembatalan progres, jadi boleh
        // ditekan kapan saja berapapun progress-nya.
        $willBeReady = ! $session->member_ready;

        $session->update([
            'member_ready' => $willBeReady,
            'member_ready_at' => $willBeReady ? now() : null,
        ]);

        \Log::info('markSessionReady: session updated', [
            'member_ready' => $session->fresh()->member_ready,
            'member_ready_at' => $session->fresh()->member_ready_at,
        ]);

        return response()->json([
            'success' => true,
            'message' => $willBeReady
                ? 'Sesi siap. Trainer bisa mencentang latihan.'
                : 'Sesi dikunci. Trainer tidak bisa mencentang sampai kamu menekan "Start Session" lagi. Progres yang sudah tercentang tetap tersimpan.',
            'data' => [
                'session_id' => $session->id,
                'member_ready' => $willBeReady,
                'member_ready_at' => $session->member_ready_at?->toIso8601String(),
            ],
            'meta' => null,
        ]);
    }
}

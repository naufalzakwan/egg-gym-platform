<?php

namespace App\Http\Resources\Api\V1\Member;

use App\Http\Resources\Api\V1\Booking\BookingRescheduleRequestResource;
use App\Models\TrainingProgram;
use App\Services\Booking\BookingRequestExpiryService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class BookingResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $expiryService = app(BookingRequestExpiryService::class);
        $this->resource->loadMissing('sessionReservations.pendingRescheduleRequest.requestedBy');
        // Program harus berasal dari booking ini. Fallback legacy hanya berlaku
        // bila sesi program sudah terhubung ke reservation booking yang sama.
        $program = TrainingProgram::query()
            ->where(function ($query) {
                $query->where('booking_id', $this->id)
                    ->orWhere(function ($legacy) {
                        $legacy->whereNull('booking_id')
                            ->whereHas('sessions.bookingSessionReservation', function ($reservation) {
                                $reservation->where('booking_id', $this->id);
                            });
                    });
            })
            ->has('sessions')
            ->latest('id')
            ->first();
        $activeProgramSession = $program?->sessions()
            ->where('status', 'active')
            ->with('bookingSessionReservation.pendingRescheduleRequest')
            ->orderBy('sequence_order')
            ->first();
        $activeRequest = $activeProgramSession?->bookingSessionReservation
            ?->pendingRescheduleRequest;

        // Tier membership member yang sedang aktif (untuk badge di detail booking).
        $activeMembership = $this->memberProfile
            ?->memberships()
            ->with('membershipPlan')
            ->currentlyActive()
            ->latest('end_date')
            ->first();
        $memberTier = $this->resolveMemberTier(
            $activeMembership?->membershipPlan?->slug
        );

        return [
            'id' => $this->id,
            'session_title' => $this->session_title,
            'session_date' => $this->session_date?->toDateString(),
            'start_time' => $this->start_time,
            'end_time' => $this->end_time,
            'session_duration_minutes' => $this->session_duration_minutes,
            'location' => $this->location,
            'session_count' => $this->session_count ?? 1,
            'status' => $this->status,
            'expired_at' => $this->expired_at?->toIso8601String(),
            'remaining_seconds' => $this->expired_at !== null
                ? max(0, (int) now()->diffInSeconds($this->expired_at, false))
                : 0,
            'expiry_stage' => $expiryService->expiryStage($this->resource),
            'is_expired' => $this->status === 'expired',
            'is_payment_verification_overdue' => $expiryService->isPaymentVerificationOverdue($this->resource),
            'payment_verification_overdue_seconds' => $expiryService->verificationOverdueSeconds($this->resource),
            'payment_proof_uploaded_at' => $this->payment_proof_uploaded_at?->toIso8601String(),
            'payment_verified_at' => $this->payment_verified_at?->toIso8601String(),
            'has_program' => $program !== null,
            'training_program_id' => $program?->id,
            'active_program_session_id' => $activeProgramSession?->id,
            'active_program_session_title' => $activeProgramSession?->title,
            'active_program_session_member_ready' => (bool) ($activeProgramSession?->member_ready ?? false),
            'active_program_session_reservation_id' => $activeProgramSession?->booking_session_reservation_id,
            'execution_blocked_by_pending_reschedule' => $activeRequest?->status === 'pending'
                && $activeRequest?->expired_at?->isFuture(),
            'member_note' => $this->member_note,
            'trainer_note' => $this->trainer_note,
            'member_profile_id' => $this->member_profile_id,
            'payment_proof_path' => $this->payment_proof_path,
            'payment_proof_url' => $this->payment_proof_path
                ? Storage::disk('public')->url($this->payment_proof_path)
                : null,
            'price_per_session' => $this->price_per_session_snapshot !== null
                ? (float) $this->price_per_session_snapshot
                : ($this->trainerProfile?->price_per_session !== null
                    ? (float) $this->trainerProfile->price_per_session
                    : null),
            'total_amount' => $this->total_amount_snapshot !== null
                ? (float) $this->total_amount_snapshot
                : ($this->trainerProfile?->price_per_session !== null
                    ? (float) $this->trainerProfile->price_per_session * ($this->session_count ?? 1)
                    : null),
            'has_reservations' => $this->sessionReservations->isNotEmpty(),
            'session_reservations' => $this->sessionReservations->map(fn ($reservation) => [
                'id' => $reservation->id,
                'sequence_order' => $reservation->sequence_order,
                'session_date' => $reservation->session_date?->toDateString(),
                'start_time' => $reservation->start_time,
                'end_time' => $reservation->end_time,
                'session_duration_minutes' => $reservation->session_duration_minutes,
                'status' => $reservation->status,
                'active_reschedule_request' => $reservation->pendingRescheduleRequest
                    ? new BookingRescheduleRequestResource($reservation->pendingRescheduleRequest)
                    : null,
            ])->values(),
            'member' => [
                'id' => $this->memberProfile?->id,
                'user_id' => $this->memberProfile?->user?->id,
                'name' => $this->memberProfile?->user?->name,
                // Data fisik & profil member sebagai bahan pertimbangan trainer
                // sebelum konfirmasi/tolak booking.
                'gender' => $this->memberProfile?->gender,
                'birth_date' => $this->memberProfile?->birth_date?->toDateString(),
                'height_cm' => $this->memberProfile?->height_cm !== null
                    ? (float) $this->memberProfile->height_cm
                    : null,
                'weight_kg' => $this->memberProfile?->weight_kg !== null
                    ? (float) $this->memberProfile->weight_kg
                    : null,
                'fitness_goal' => $this->memberProfile?->fitness_goal,
                'medical_note' => $this->memberProfile?->medical_note,
                'tier' => $memberTier,
            ],
            'trainer' => [
                'id' => $this->trainerProfile?->id,
                'name' => $this->trainerProfile?->user?->name,
                'avatar_url' => $this->trainerProfile?->user?->avatar_url,
                'display_photo_path' => $this->trainerProfile?->display_photo_path,
            ],
        ];
    }

    private function resolveMemberTier(?string $slug): string
    {
        return match ($slug) {
            'elite-member' => 'Elite Member',
            'annual-pro' => 'Pro Annual',
            'starter-pack' => 'Starter',
            default => 'Basic Member',
        };
    }
}

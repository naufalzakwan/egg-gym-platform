<?php

namespace App\Http\Resources\Api\V1\Public;

use App\Support\TrainerSpecialty;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TrainerProfileResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $reviewsCount = (int) ($this->reviews_count ?? 0);
        $rating = $reviewsCount > 0
            ? round((float) $this->rating_average, 2)
            : 0.0;
        // Hitung kuota dari booking aktif (konsisten dengan validasi di
        // MemberBookingController::store), bukan dari program aktif saja.
        $activeMembers = $this->activeQuotaMembers();
        // Cap dinamis berbasis gelombang pemerataan (bukan konstanta statis).
        $quotaCap = $this->currentQuotaCap();

        return [
            'id' => $this->id,
            'name' => $this->user?->name,
            'email' => $this->user?->email,
            'phone' => $this->user?->phone,
            'specialty' => TrainerSpecialty::label($this->specialty),
            'specialty_slug' => TrainerSpecialty::slug($this->specialty),
            'specialties' => $this->specialty_labels,
            'bio' => $this->bio,
            'rating' => $rating,
            'reviews_count' => $reviewsCount,
            'experience_years' => $this->experience_years,
            'certifications' => $this->certifications,
            'certifications_list' => $this->certification_list,
            'availability_note' => $this->availability_note,
            'tier' => $this->tier_value,
            'badge' => $this->tier_label,
            'avatar_url' => $this->user?->avatar_url,
            'display_photo_path' => $this->display_photo_path,
            'active_members' => $activeMembers,
            'max_members' => $quotaCap,
            'is_available' => $activeMembers < $quotaCap,
            'has_active_schedule' => (bool) $this->has_active_schedule,
            // Metrik "served" untuk stat ACTIVE CLIENTS di Trainer Detail:
            // DISTINCT member dari booking completed/confirmed UNION member
            // yang sudah memberi rating (beda dari kuota active_members).
            'served_clients_count' => $this->servedClientsCount(),
            'price_per_session' => $this->price_per_session !== null
                ? (float) $this->price_per_session
                : null,
            'bank_name' => $this->bank_name,
            'bank_account_number' => $this->bank_account_number,
            'bank_account_name' => $this->bank_account_name,
            'dana_number' => $this->dana_number,
        ];
    }
}

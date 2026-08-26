<?php

namespace App\Http\Resources\Api\V1\Member;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TransactionResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $data = [
            'id' => $this->id,
            'reference_code' => $this->reference_code,
            'title' => $this->membershipPlan?->name ?? $this->title,
            'type' => $this->membershipPlan ? 'membership' : null,
            'payment_method' => $this->payment_method,
            'amount' => (float) $this->amount,
            'status' => $this->status,
            'paid_at' => $this->paid_at?->toIso8601String(),
            // created_at dipakai untuk urutan & tampilan tanggal/waktu semua
            // status (termasuk pending/cancelled/expired yang tak punya paid_at).
            'created_at' => $this->created_at?->toIso8601String(),
            'provider_reference' => $this->provider_reference,
            'membership_plan' => $this->membershipPlan ? [
                'id' => $this->membershipPlan->id,
                'name' => $this->membershipPlan->name,
                'slug' => $this->membershipPlan->slug,
            ] : null,
        ];

        // Untuk transaksi PENDING: kirim data pembayaran (QR/VA) + info expired
        // supaya Flutter bisa "lanjutkan pembayaran" (reuse QR bila belum expired,
        // atau tawarkan buat baru bila sudah). is_expired & remaining_seconds
        // DIHITUNG DI SERVER (now()), bukan di device. SUCCESS tidak butuh ini
        // (payload tetap ringkas).
        if ($this->status === 'pending') {
            $isExpired = $this->expired_at !== null
                && $this->expired_at->lessThanOrEqualTo(now());

            $data['payment_number'] = $this->payment_number;
            // qr_string hanya untuk metode qris (di-render sebagai QR di app).
            $data['qr_string'] =
                $this->payment_method === 'qris' ? $this->payment_number : null;
            $data['expired_at'] = $this->expired_at?->toIso8601String();
            $data['is_expired'] = $isExpired;
            $data['remaining_seconds'] = $this->expired_at !== null
                ? max(0, (int) now()->diffInSeconds($this->expired_at, false))
                : 0;
            $data['fee'] = $this->fee !== null ? (float) $this->fee : null;
            $data['total_payment'] = $this->total_payment !== null
                ? (float) $this->total_payment
                : null;
        }

        return $data;
    }
}

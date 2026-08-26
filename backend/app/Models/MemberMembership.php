<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MemberMembership extends Model
{
    use HasFactory;

    protected $fillable = [
        'member_profile_id',
        'membership_plan_id',
        'start_date',
        'end_date',
        'status',
        'payment_status',
    ];

    protected $casts = [
        'start_date' => 'date',
        'end_date' => 'date',
    ];

    public function memberProfile(): BelongsTo
    {
        return $this->belongsTo(MemberProfile::class);
    }

    public function membershipPlan(): BelongsTo
    {
        return $this->belongsTo(MembershipPlan::class)->withTrashed();
    }

    public function scopeCurrentlyActive(Builder $query): Builder
    {
        return $query
            ->where('status', 'active')
            ->where('payment_status', 'paid')
            ->whereDate('start_date', '<=', now()->toDateString())
            ->whereDate('end_date', '>=', now()->toDateString());
    }

    public function isCurrentlyActive(): bool
    {
        return $this->status === 'active'
            && $this->payment_status === 'paid'
            && $this->start_date
            && $this->start_date->lessThanOrEqualTo(now()->startOfDay())
            && $this->end_date
            && $this->end_date->greaterThanOrEqualTo(now()->startOfDay());
    }

    /**
     * Ujung (end_date terjauh) dari RANTAI membership berbayar yang bersambung
     * mulai dari periode yang aktif hari ini.
     *
     * Definisi "kontigu": mulai dari row yang aktif hari ini (start<=today,
     * end>=today), lalu row berikutnya dianggap TERSAMBUNG bila start_date-nya
     * <= (end_date rantai saat ini + 1 hari). Begitu ada gap (start_date lebih
     * dari sehari setelah ujung rantai), penyambungan berhenti.
     *
     * Ini yang membuat pembelian yang di-stack ke depan (mis. 1 Agu–31 Agu
     * setelah periode aktif 1–31 Jul) ikut terhitung sebagai sisa masa aktif,
     * BUKAN hanya membaca satu row aktif hari ini.
     *
     * Mengembalikan null bila member tidak punya membership aktif hari ini.
     *
     * @param  \Illuminate\Support\Collection<int, MemberMembership>|array  $memberships
     *                                                                                    Seluruh membership milik member (row apa pun; akan difilter paid/active).
     */
    public static function activeChainEndDate($memberships): ?Carbon
    {
        $today = now()->startOfDay();

        // Hanya membership berbayar & berstatus active, urut menaik by start_date.
        $paid = collect($memberships)
            ->filter(fn (self $m) => $m->status === 'active'
                && $m->payment_status === 'paid'
                && $m->start_date
                && $m->end_date)
            ->sortBy(fn (self $m) => $m->start_date->getTimestamp())
            ->values();

        // Cari row yang aktif hari ini sebagai titik awal rantai.
        $chainEnd = null;
        foreach ($paid as $m) {
            if (
                $m->start_date->lessThanOrEqualTo($today)
                && $m->end_date->greaterThanOrEqualTo($today)
            ) {
                $chainEnd = $m->end_date->copy();
                break;
            }
        }

        if ($chainEnd === null) {
            return null; // tidak ada periode aktif hari ini
        }

        // Sambungkan row-row berikutnya selama kontigu (start <= chainEnd + 1 hari).
        foreach ($paid as $m) {
            if ($m->start_date->lessThanOrEqualTo($chainEnd->copy()->addDay())
                && $m->end_date->greaterThan($chainEnd)) {
                $chainEnd = $m->end_date->copy();
            }
        }

        return $chainEnd;
    }

    /**
     * Sisa hari dari hari ini sampai ujung rantai membership kontigu.
     * 0 bila tidak ada membership aktif hari ini.
     *
     * @param  \Illuminate\Support\Collection<int, MemberMembership>|array  $memberships
     */
    public static function remainingDaysForMember($memberships): int
    {
        $chainEnd = static::activeChainEndDate($memberships);
        if ($chainEnd === null) {
            return 0;
        }

        return max(0, (int) now()->startOfDay()->diffInDays($chainEnd, false));
    }

    /**
     * Row membership yang SEDANG berjalan di ujung rantai kontigu — yaitu row
     * yang end_date-nya = ujung rantai (paket yang paling akhir berlaku dalam
     * rangkaian yang tersambung dari hari ini). Dipakai untuk menampilkan
     * "paket aktif" & tanggal berakhir yang konsisten dengan remainingDays.
     *
     * Mengembalikan null bila tidak ada membership aktif hari ini.
     *
     * @param  \Illuminate\Support\Collection<int, MemberMembership>|array  $memberships
     */
    public static function activeChainMembership($memberships): ?self
    {
        $chainEnd = static::activeChainEndDate($memberships);
        if ($chainEnd === null) {
            return null;
        }

        // Ambil row berbayar & aktif yang end_date-nya = ujung rantai. Bila ada
        // lebih dari satu (harusnya tidak), pilih yang start_date paling akhir.
        return collect($memberships)
            ->filter(fn (self $m) => $m->status === 'active'
                && $m->payment_status === 'paid'
                && $m->end_date
                && $m->end_date->toDateString() === $chainEnd->toDateString())
            ->sortByDesc(fn (self $m) => $m->start_date?->getTimestamp() ?? 0)
            ->first();
    }
}

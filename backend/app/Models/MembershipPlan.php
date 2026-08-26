<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class MembershipPlan extends Model
{
    use HasFactory, SoftDeletes;

    private const BENEFIT_LABELS_ID = [
        'Gym access' => 'Akses gym',
        'Locker access' => 'Akses loker',
        'Basic trainer guidance' => 'Panduan trainer dasar',
        'Full gym access' => 'Akses gym penuh',
        'Sauna access' => 'Akses sauna',
        'Smoothie bar' => 'Akses smoothie bar',
        'Priority private class' => 'Prioritas kelas privat',
        'Premium facility access' => 'Akses fasilitas premium',
        'Annual savings package' => 'Paket hemat tahunan',
    ];

    protected $fillable = [
        'name',
        'slug',
        'description',
        'price',
        'billing_period',
        'duration_days',
        'release_date',
        'features_json',
        'is_active',
    ];

    protected $casts = [
        'features_json' => 'array',
        'is_active' => 'boolean',
        'price' => 'decimal:2',
        'duration_days' => 'integer',
        'release_date' => 'date',
    ];

    public function scopeAvailableForPurchase(Builder $query): Builder
    {
        return $query
            ->where('is_active', true)
            ->where(function (Builder $releaseQuery) {
                $releaseQuery->whereNull('release_date')
                    ->orWhereDate('release_date', '<=', now()->toDateString());
            });
    }

    public function getEffectiveStatusAttribute(): string
    {
        if (! $this->is_active) {
            return 'inactive';
        }

        if ($this->release_date?->isAfter(now()->startOfDay())) {
            return 'upcoming';
        }

        return 'active';
    }

    public function isAvailableForPurchase(): bool
    {
        return $this->effective_status === 'active' && ! $this->trashed();
    }

    public static function benefitDisplayLabel(string $benefit): string
    {
        return self::BENEFIT_LABELS_ID[$benefit] ?? $benefit;
    }

    public static function benefitDisplayLabels(): array
    {
        return self::BENEFIT_LABELS_ID;
    }

    public function memberships(): HasMany
    {
        return $this->hasMany(MemberMembership::class);
    }
}

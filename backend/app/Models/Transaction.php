<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Transaction extends Model
{
    use HasFactory;

    protected $fillable = [
        'member_profile_id',
        'membership_plan_id',
        'reference_code',
        'title',
        'payment_method',
        'amount',
        'status',
        'paid_at',
        'provider_reference',
        'provider_name',
        'payment_number',
        'fee',
        'total_payment',
        'expired_at',
        'provider_payload',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'fee' => 'decimal:2',
        'total_payment' => 'decimal:2',
        'paid_at' => 'datetime',
        'expired_at' => 'datetime',
        'provider_payload' => 'array',
    ];

    public function memberProfile(): BelongsTo
    {
        return $this->belongsTo(MemberProfile::class);
    }

    public function membershipPlan(): BelongsTo
    {
        return $this->belongsTo(MembershipPlan::class)->withTrashed();
    }
}

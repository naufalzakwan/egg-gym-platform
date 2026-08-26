<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class MemberProgress extends Model
{
    use HasFactory;

    protected $table = 'member_progress';

    protected $fillable = [
        'member_profile_id',
        'weight_kg',
        'height_cm',
        'note',
        'recorded_at',
        'is_milestone',
    ];

    protected $casts = [
        'weight_kg' => 'float',
        'height_cm' => 'float',
        'recorded_at' => 'date',
        'is_milestone' => 'boolean',
    ];

    public function memberProfile(): BelongsTo
    {
        return $this->belongsTo(MemberProfile::class);
    }

    public function photos(): HasMany
    {
        return $this->hasMany(MemberProgressPhoto::class);
    }
}

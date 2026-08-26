<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SelfTrainingProgram extends Model
{
    use HasFactory;

    protected $fillable = [
        'member_profile_id',
        'title',
        'description',
        'status',
    ];

    public function memberProfile(): BelongsTo
    {
        return $this->belongsTo(MemberProfile::class);
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(SelfTrainingSession::class)
            ->orderBy('sequence_order');
    }
}

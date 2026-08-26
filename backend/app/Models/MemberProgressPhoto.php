<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MemberProgressPhoto extends Model
{
    use HasFactory;

    protected $fillable = [
        'member_progress_id',
        'photo_type',
        'photo_url',
    ];

    public function memberProgress(): BelongsTo
    {
        return $this->belongsTo(MemberProgress::class);
    }
}

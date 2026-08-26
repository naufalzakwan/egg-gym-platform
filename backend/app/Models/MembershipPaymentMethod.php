<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MembershipPaymentMethod extends Model
{
    protected $fillable = [
        'provider', 'provider_code', 'display_name', 'description', 'is_active', 'display_order',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'display_order' => 'integer',
    ];
}

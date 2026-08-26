<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class GymSetting extends Model
{
    protected $fillable = [
        'gym_name', 'brand_name', 'tagline', 'address', 'city', 'province',
        'postal_code', 'maps_url', 'latitude', 'longitude', 'phone', 'whatsapp',
        'email', 'instagram', 'logo_path', 'logo_version',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'logo_version' => 'integer',
    ];

    public static function current(): self
    {
        return static::query()->firstOrCreate(['id' => 1], [
            'gym_name' => 'Egg Gym',
            'brand_name' => 'EGGGYM',
            'tagline' => 'Your Gym, Smarter',
            'logo_version' => 1,
        ]);
    }
}

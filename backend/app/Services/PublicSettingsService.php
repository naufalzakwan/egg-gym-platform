<?php

namespace App\Services;

use App\Models\GymOperationHour;
use App\Models\GymSetting;
use App\Models\MembershipPaymentMethod;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;

class PublicSettingsService
{
    private const CACHE_KEY = 'public_settings.v1';

    public function publicData(): array
    {
        return Cache::remember(self::CACHE_KEY, now()->addMinutes(10), function () {
            $settings = GymSetting::current();

            return [
                'gym' => [
                    'name' => $settings->gym_name,
                    'brand_name' => $settings->brand_name,
                    'tagline' => $settings->tagline,
                    'address' => $settings->address,
                    'city' => $settings->city,
                    'province' => $settings->province,
                    'postal_code' => $settings->postal_code,
                    'maps_url' => $settings->maps_url,
                    'latitude' => $settings->latitude !== null ? (float) $settings->latitude : null,
                    'longitude' => $settings->longitude !== null ? (float) $settings->longitude : null,
                    'phone' => $settings->phone,
                    'whatsapp' => $settings->whatsapp,
                    'email' => $settings->email,
                    'instagram' => $settings->instagram,
                    'logo_path' => $settings->logo_path,
                    'logo_url' => $settings->logo_path ? Storage::disk('public')->url($settings->logo_path) : null,
                    'logo_version' => $settings->logo_version,
                ],
                'operation_hours' => GymOperationHour::query()->orderBy('day_order')->get()->map(fn ($hour) => [
                    'day_name' => $hour->day_name,
                    'day_order' => $hour->day_order,
                    'open_time' => $hour->open_time ? substr((string) $hour->open_time, 0, 5) : null,
                    'close_time' => $hour->close_time ? substr((string) $hour->close_time, 0, 5) : null,
                    'is_closed' => (bool) $hour->is_closed,
                ])->all(),
                'membership_payment_methods' => MembershipPaymentMethod::query()
                    ->where('provider', 'pakasir')->where('is_active', true)
                    ->orderBy('display_order')->orderBy('id')->get()
                    ->map(fn ($method) => [
                        'code' => $method->provider_code,
                        'label' => $method->display_name,
                        'description' => $method->description,
                        'display_order' => $method->display_order,
                    ])->all(),
                'version' => $settings->updated_at?->toIso8601String(),
            ];
        });
    }

    public function forget(): void
    {
        Cache::forget(self::CACHE_KEY);
    }
}

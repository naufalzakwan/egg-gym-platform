<?php

namespace App\Support;

class TrainerTier
{
    private const LABELS = [
        'standard' => 'Basic',
        'pro' => 'Pro',
        'elite' => 'Elite',
    ];

    public static function values(): array
    {
        return array_keys(self::LABELS);
    }

    public static function labels(): array
    {
        return self::LABELS;
    }

    public static function normalize(mixed $tier): ?string
    {
        if (! is_string($tier)) {
            return null;
        }

        $normalized = strtolower(trim($tier));

        return array_key_exists($normalized, self::LABELS) ? $normalized : null;
    }

    public static function label(mixed $tier): ?string
    {
        $normalized = self::normalize($tier);

        return $normalized === null ? null : self::LABELS[$normalized];
    }
}

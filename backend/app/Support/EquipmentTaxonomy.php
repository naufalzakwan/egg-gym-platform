<?php

namespace App\Support;

class EquipmentTaxonomy
{
    public const OTHER = '__other__';

    public const CATEGORIES = [
        'Cardio',
        'Strength',
        'Functional',
        'Free Weight',
        'Machine',
        'Mobility',
        'Recovery',
        'Accessories',
    ];

    public const DIFFICULTIES = [
        'Beginner',
        'Intermediate',
        'Advanced',
        'All Levels',
    ];

    public static function resolve(string $selection, ?string $custom): string
    {
        return $selection === self::OTHER ? trim((string) $custom) : trim($selection);
    }
}

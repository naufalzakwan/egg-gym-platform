<?php

namespace App\Support;

final class TrainerSpecialty
{
    public const OPTIONS = [
        'bodybuilding' => 'Bodybuilding',
        'muscle_gain' => 'Muscle Gain',
        'weight_loss' => 'Weight Loss',
        'strength_training' => 'Strength Training',
        'powerlifting' => 'Powerlifting',
        'functional_training' => 'Functional Training',
        'mobility_flexibility' => 'Mobility & Flexibility',
        'yoga' => 'Yoga',
        'cardio_endurance' => 'Cardio & Endurance',
        'fat_loss' => 'Fat Loss',
        'general_fitness' => 'General Fitness',
        'rehabilitation' => 'Rehabilitation',
        'sports_performance' => 'Sports Performance',
        'nutrition_coaching' => 'Nutrition Coaching',
    ];

    private const LEGACY_ALIASES = [
        'bodybuilding - nutrition' => 'Bodybuilding',
        'yoga - flexibility' => 'Yoga',
        'muscle gain specialist' => 'Muscle Gain',
    ];

    public static function labels(): array
    {
        return array_values(self::OPTIONS);
    }

    public static function label(?string $value): ?string
    {
        $trimmed = trim((string) $value);
        if ($trimmed === '') {
            return null;
        }

        foreach (self::OPTIONS as $label) {
            if (strcasecmp($trimmed, $label) === 0) {
                return $label;
            }
        }

        return self::LEGACY_ALIASES[strtolower($trimmed)] ?? $trimmed;
    }

    public static function slug(?string $value): ?string
    {
        $label = self::label($value);
        if ($label === null) {
            return null;
        }

        return array_search($label, self::OPTIONS, true) ?: null;
    }

    public static function databaseValuesFor(string $label): array
    {
        $canonical = self::label($label);
        if ($canonical === null || ! in_array($canonical, self::OPTIONS, true)) {
            return [];
        }

        $values = [$canonical];
        foreach (self::LEGACY_ALIASES as $legacy => $mappedLabel) {
            if ($mappedLabel === $canonical) {
                $values[] = $legacy;
            }
        }

        return $values;
    }
}

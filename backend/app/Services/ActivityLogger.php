<?php

namespace App\Services;

use App\Models\ActivityLog;
use Illuminate\Database\Eloquent\Model;

class ActivityLogger
{
    private const TECHNICAL_KEYS = [
        'id', 'created_at', 'updated_at', 'deleted_at',
    ];

    public static function log(
        string $action,
        ?Model $model = null,
        ?array $oldData = null,
        ?array $newData = null,
        ?string $description = null,
        ?int $userId = null,
    ): ActivityLog {
        $request = request();

        return ActivityLog::create([
            'user_id' => $userId ?? auth('sanctum')->id() ?? session('admin_user_id'),
            'action' => $action,
            'model_type' => $model ? get_class($model) : null,
            'model_id' => $model?->id,
            'old_data' => $oldData,
            'new_data' => $newData,
            'description' => $description,
            'ip_address' => $request?->ip(),
            'user_agent' => $request?->userAgent(),
        ]);
    }

    public static function logCreated(Model $model, ?string $description = null): ActivityLog
    {
        return static::log(
            action: 'created',
            model: $model,
            newData: $model->toArray(),
            description: $description ?? 'Data baru dibuat',
        );
    }

    public static function logUpdated(Model $model, array $oldData, ?string $description = null): ActivityLog
    {
        $changes = collect($model->getChanges())
            ->except(self::TECHNICAL_KEYS)
            ->all();
        $candidateKeys = collect(array_keys($oldData))
            ->merge(array_keys($changes))
            ->unique()
            ->reject(fn (string $key) => in_array($key, self::TECHNICAL_KEYS, true));
        $old = [];
        $new = [];
        foreach ($candidateKeys as $key) {
            $oldValue = array_key_exists($key, $oldData)
                ? $oldData[$key]
                : $model->getRawOriginal($key);
            $newValue = $model->getAttribute($key);
            if (static::comparable($oldValue) === static::comparable($newValue)) {
                continue;
            }
            $old[$key] = $oldValue;
            $new[$key] = $newValue;
        }

        return static::log(
            action: 'updated',
            model: $model,
            oldData: $old ?: null,
            newData: $new ?: null,
            description: $description ?? 'Data diperbarui',
        );
    }

    public static function logDeleted(Model $model, ?string $description = null): ActivityLog
    {
        return static::log(
            action: 'deleted',
            model: $model,
            oldData: $model->toArray(),
            description: $description ?? 'Data dihapus',
        );
    }

    public static function logAction(string $action, ?string $description = null, ?int $userId = null): ActivityLog
    {
        return static::log(
            action: $action,
            description: $description,
            userId: $userId,
        );
    }

    private static function comparable(mixed $value): string
    {
        if ($value instanceof \DateTimeInterface) {
            return $value->format('Y-m-d H:i:s');
        }

        return json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?: '';
    }
}

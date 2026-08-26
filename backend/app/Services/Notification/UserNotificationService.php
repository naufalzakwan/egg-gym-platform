<?php

namespace App\Services\Notification;

use App\Models\User;
use App\Models\UserNotification;
use Illuminate\Support\Facades\Log;

class UserNotificationService
{
    public function __construct(
        private readonly FcmNotificationService $fcmNotificationService
    ) {}

    public function notify(
        User $user,
        string $title,
        string $message,
        string $type = 'general',
        string $channel = 'push',
        bool $push = true,
        array $data = [],
        ?string $eventKey = null,
        string $priority = 'normal',
    ): UserNotification {
        $attributes = [
            'user_id' => $user->id,
            'title' => $title,
            'message' => $message,
            'type' => $type,
            'channel' => $channel,
            'data_json' => $data ?: null,
            'event_key' => $eventKey,
            'priority' => $priority,
            'is_read' => false,
            'sent_at' => now(),
        ];
        $notification = $eventKey
            ? UserNotification::firstOrCreate(
                ['user_id' => $user->id, 'event_key' => $eventKey],
                $attributes,
            )
            : UserNotification::create($attributes);

        if ($push && $notification->wasRecentlyCreated) {
            $dispatch = $this->fcmNotificationService->sendNotification(
                $notification,
                array_merge($data, [
                    'user_id' => (string) $user->id,
                ])
            );

            if ($dispatch['status'] === 'failed') {
                Log::warning('Automatic notification push failed.', [
                    'notification_id' => $notification->id,
                    'user_id' => $user->id,
                    'dispatch' => $dispatch,
                ]);
            }
        }

        return $notification->fresh();
    }
}

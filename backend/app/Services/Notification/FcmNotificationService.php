<?php

namespace App\Services\Notification;

use App\Models\UserDeviceToken;
use App\Models\UserNotification;
use Google\Auth\Credentials\ServiceAccountCredentials;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

class FcmNotificationService
{
    private const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    /**
     * @return array<string, mixed>
     */
    public function sendNotification(UserNotification $notification, array $extraData = []): array
    {
        if (! $this->isConfigured()) {
            return [
                'status' => 'skipped',
                'message' => 'FCM belum dikonfigurasi.',
                'success_count' => 0,
                'failure_count' => 0,
                'results' => [],
            ];
        }

        $tokens = UserDeviceToken::query()
            ->where('user_id', $notification->user_id)
            ->where('is_active', true)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values();

        if ($tokens->isEmpty()) {
            return [
                'status' => 'skipped',
                'message' => 'Tidak ada device token aktif untuk user ini.',
                'success_count' => 0,
                'failure_count' => 0,
                'results' => [],
            ];
        }

        $accessToken = $this->getAccessToken();

        if (! $accessToken) {
            return [
                'status' => 'failed',
                'message' => 'Access token FCM gagal dibuat.',
                'success_count' => 0,
                'failure_count' => $tokens->count(),
                'results' => [],
            ];
        }

        $projectId = config('services.fcm.project_id');
        $endpoint = 'https://fcm.googleapis.com/v1/projects/'.$projectId.'/messages:send';

        $successCount = 0;
        $failureCount = 0;
        $results = [];

        foreach ($tokens as $token) {
            $response = Http::timeout((int) config('services.fcm.timeout', 15))
                ->withToken($accessToken)
                ->acceptJson()
                ->post($endpoint, [
                    'message' => [
                        'token' => $token,
                        'notification' => [
                            'title' => $notification->title,
                            'body' => $notification->message,
                        ],
                        'data' => $this->normalizeData(array_merge($extraData, [
                            'notification_id' => (string) $notification->id,
                            'type' => (string) $notification->type,
                            'channel' => (string) $notification->channel,
                        ])),
                        'android' => [
                            'priority' => 'high',
                        ],
                        'apns' => [
                            'headers' => [
                                'apns-priority' => '10',
                            ],
                        ],
                    ],
                ]);

            if ($response->successful()) {
                $successCount++;
            } else {
                $failureCount++;
                $this->deactivateInvalidToken($token, $response->json());

                Log::warning('FCM push failed.', [
                    'notification_id' => $notification->id,
                    'user_id' => $notification->user_id,
                    'status_code' => $response->status(),
                    'response' => $response->json() ?: $response->body(),
                ]);
            }

            $results[] = [
                'token_preview' => substr($token, 0, 16).'...',
                'success' => $response->successful(),
                'status_code' => $response->status(),
                'response' => $response->json() ?: $response->body(),
            ];
        }

        return [
            'status' => $failureCount === 0
                ? 'sent'
                : ($successCount > 0 ? 'partial' : 'failed'),
            'message' => $failureCount === 0
                ? 'Push notification berhasil dikirim.'
                : ($successCount > 0
                    ? 'Sebagian push notification berhasil dikirim.'
                    : 'Push notification gagal dikirim.'),
            'success_count' => $successCount,
            'failure_count' => $failureCount,
            'results' => $results,
        ];
    }

    private function isConfigured(): bool
    {
        return filled(config('services.fcm.project_id'))
            && filled(config('services.fcm.service_account_path'));
    }

    private function getAccessToken(): ?string
    {
        $path = $this->resolveServiceAccountPath();

        if (! $path || ! file_exists($path)) {
            Log::warning('FCM service account file not found.', [
                'path' => $path,
            ]);

            return null;
        }

        try {
            $serviceAccount = json_decode(
                file_get_contents($path),
                true,
                512,
                JSON_THROW_ON_ERROR
            );

            $credentials = new ServiceAccountCredentials(
                [self::FCM_SCOPE],
                $serviceAccount
            );

            $token = $credentials->fetchAuthToken();

            return $token['access_token'] ?? null;
        } catch (Throwable $throwable) {
            Log::warning('FCM access token generation failed.', [
                'message' => $throwable->getMessage(),
            ]);

            return null;
        }
    }

    private function resolveServiceAccountPath(): ?string
    {
        $configuredPath = config('services.fcm.service_account_path');

        if (! is_string($configuredPath) || $configuredPath === '') {
            return null;
        }

        if (
            preg_match('/^[A-Za-z]:\\\\/', $configuredPath) === 1 ||
            str_starts_with($configuredPath, '/') ||
            str_starts_with($configuredPath, '\\')
        ) {
            return $configuredPath;
        }

        return base_path($configuredPath);
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, string>
     */
    private function normalizeData(array $data): array
    {
        $normalized = [];

        foreach ($data as $key => $value) {
            if (is_bool($value)) {
                $normalized[$key] = $value ? 'true' : 'false';

                continue;
            }

            if (is_scalar($value) || $value === null) {
                $normalized[$key] = (string) $value;

                continue;
            }

            $normalized[$key] = json_encode($value);
        }

        return $normalized;
    }

    /**
     * @param  array<string, mixed>|null  $responseBody
     */
    private function deactivateInvalidToken(string $token, ?array $responseBody): void
    {
        $errorCode = data_get($responseBody, 'error.details.0.errorCode');

        if (! in_array($errorCode, ['UNREGISTERED', 'INVALID_ARGUMENT'], true)) {
            return;
        }

        UserDeviceToken::query()
            ->where('fcm_token', $token)
            ->update([
                'is_active' => false,
            ]);
    }
}

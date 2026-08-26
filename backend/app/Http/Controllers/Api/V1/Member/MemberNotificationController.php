<?php

namespace App\Http\Controllers\Api\V1\Member;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\Member\NotificationResource;
use App\Models\UserNotification;
use App\Services\Notification\FcmNotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MemberNotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $base = UserNotification::query()->where('user_id', $request->user()->id);
        $unreadCount = (clone $base)->where('is_read', false)->count();
        $notifications = $base
            ->orderBy('is_read')
            ->orderByDesc('sent_at')
            ->orderByDesc('id')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Data notifikasi pengguna berhasil diambil.',
            'data' => NotificationResource::collection($notifications),
            'meta' => ['unread_count' => $unreadCount],
        ]);
    }

    public function markAsRead(Request $request, int $id): JsonResponse
    {
        $notification = UserNotification::query()
            ->where('id', $id)
            ->where('user_id', $request->user()->id)
            ->first();

        if (! $notification) {
            return response()->json([
                'success' => false,
                'message' => 'Notifikasi tidak ditemukan untuk pengguna ini.',
            ], 404);
        }

        if (! $notification->is_read) {
            $notification->update([
                'is_read' => true,
                'read_at' => now(),
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Notifikasi berhasil ditandai sudah dibaca.',
            'data' => new NotificationResource($notification->fresh()),
            'meta' => null,
        ]);
    }

    public function markAllAsRead(Request $request): JsonResponse
    {
        $count = UserNotification::query()
            ->where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->update(['is_read' => true, 'read_at' => now()]);

        return response()->json([
            'success' => true,
            'message' => 'Semua notifikasi berhasil ditandai dibaca.',
            'data' => ['updated_count' => $count, 'unread_count' => 0],
            'meta' => null,
        ]);
    }

    public function push(
        Request $request,
        int $id,
        FcmNotificationService $fcmNotificationService
    ): JsonResponse {
        $notification = UserNotification::query()
            ->where('id', $id)
            ->where('user_id', $request->user()->id)
            ->first();

        if (! $notification) {
            return response()->json([
                'success' => false,
                'message' => 'Notifikasi tidak ditemukan untuk pengguna ini.',
            ], 404);
        }

        $dispatch = $fcmNotificationService->sendNotification($notification, [
            'user_id' => (string) $request->user()->id,
        ]);

        $success = in_array($dispatch['status'], ['sent', 'partial', 'skipped'], true);

        return response()->json([
            'success' => $success,
            'message' => $this->resolvePushMessage($dispatch['status']),
            'data' => [
                'notification' => (new NotificationResource($notification->fresh()))->resolve(),
                'dispatch' => $dispatch,
            ],
            'meta' => null,
        ], $success ? 200 : 422);
    }

    private function resolvePushMessage(string $status): string
    {
        return match ($status) {
            'sent' => 'Push notification berhasil dikirim.',
            'partial' => 'Sebagian push notification berhasil dikirim.',
            'skipped' => 'Push notification dilewati karena konfigurasi atau token belum siap.',
            default => 'Push notification gagal dikirim.',
        };
    }
}

<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\User;
use App\Models\UserNotification;
use App\Services\ActivityLogger;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function inbox(Request $request): View
    {
        $notifications = UserNotification::query()
            ->where('user_id', $request->session()->get('admin_user_id'))
            ->orderBy('is_read')
            ->orderByDesc('sent_at')
            ->paginate(10);

        return view('admin.notifications.inbox', [
            'notifications' => $notifications,
            'unreadCount' => UserNotification::query()
                ->where('user_id', $request->session()->get('admin_user_id'))
                ->where('is_read', false)
                ->count(),
        ]);
    }

    public function markAsRead(Request $request, int $id): RedirectResponse
    {
        UserNotification::query()
            ->whereKey($id)
            ->where('user_id', $request->session()->get('admin_user_id'))
            ->where('is_read', false)
            ->update(['is_read' => true, 'read_at' => now()]);

        return $this->notificationRedirect($request, $id);
    }

    public function markAllAsRead(Request $request): RedirectResponse
    {
        UserNotification::query()
            ->where('user_id', $request->session()->get('admin_user_id'))
            ->where('is_read', false)
            ->update(['is_read' => true, 'read_at' => now()]);

        return back()->with('success', 'Semua notifikasi berhasil ditandai dibaca.');
    }

    public function index(Request $request): View
    {
        $notifications = UserNotification::query()
            ->with('user')
            ->when($request->filled('type'), function ($query) use ($request) {
                $query->where('type', trim((string) $request->query('type')));
            })
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = trim((string) $request->query('search'));

                $query->where(function ($innerQuery) use ($search) {
                    $innerQuery->where('title', 'like', '%'.$search.'%')
                        ->orWhere('message', 'like', '%'.$search.'%')
                        ->orWhereHas('user', function ($userQuery) use ($search) {
                            $userQuery->where('name', 'like', '%'.$search.'%')
                                ->orWhere('email', 'like', '%'.$search.'%');
                        });
                });
            })
            ->latest()
            ->paginate(15)
            ->withQueryString();

        $types = UserNotification::query()
            ->select('type')
            ->distinct()
            ->orderBy('type')
            ->pluck('type');

        return view('admin.notifications.index', [
            'notifications' => $notifications,
            'search' => $request->query('search'),
            'type' => $request->query('type'),
            'types' => $types,
        ]);
    }

    public function create(): View
    {
        $members = User::query()
            ->whereHas('role', function ($query) {
                $query->where('name', 'member');
            })
            ->orderBy('name')
            ->get();

        return view('admin.notifications.form', [
            'pageTitle' => 'Kirim Notifikasi',
            'submitLabel' => 'Kirim Notifikasi',
            'action' => route('admin.notifications.store'),
            'members' => $members,
        ]);
    }

    public function broadcastForm(): View
    {
        return view('admin.notifications.broadcast');
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'user_id' => ['required', 'exists:users,id'],
            'title' => ['required', 'string', 'max:150'],
            'message' => ['required', 'string'],
            'type' => ['required', 'string', 'max:50'],
        ]);

        $notification = UserNotification::create([
            'user_id' => $validated['user_id'],
            'title' => trim((string) $validated['title']),
            'message' => trim((string) $validated['message']),
            'type' => trim((string) $validated['type']),
            'channel' => 'in_app',
            'is_read' => false,
            'sent_at' => now(),
        ]);

        ActivityLogger::logCreated($notification, "Notifikasi dikirim: {$notification->title}");

        return redirect()
            ->route('admin.notifications.index')
            ->with('success', 'Notifikasi berhasil dikirim.');
    }

    public function broadcast(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:150'],
            'message' => ['required', 'string'],
            'type' => ['required', 'string', 'max:50'],
        ]);

        $memberIds = User::query()
            ->whereHas('role', function ($query) {
                $query->where('name', 'member');
            })
            ->pluck('id');

        $count = 0;
        foreach ($memberIds as $memberId) {
            UserNotification::create([
                'user_id' => $memberId,
                'title' => trim((string) $validated['title']),
                'message' => trim((string) $validated['message']),
                'type' => trim((string) $validated['type']),
                'channel' => 'in_app',
                'is_read' => false,
                'sent_at' => now(),
            ]);
            $count++;
        }

        ActivityLogger::logAction(
            'broadcast_notification',
            "Notifikasi broadcast dikirim ke {$count} member: {$validated['title']}",
        );

        return redirect()
            ->route('admin.notifications.index')
            ->with('success', "Notifikasi berhasil dikirim ke {$count} member.");
    }

    public function destroy(UserNotification $notification): RedirectResponse
    {
        $title = $notification->title;
        ActivityLogger::logDeleted($notification, "Notifikasi dihapus: {$title}");
        $notification->delete();

        return redirect()
            ->route('admin.notifications.index')
            ->with('success', 'Notifikasi berhasil dihapus.');
    }

    private function notificationRedirect(Request $request, int $id): RedirectResponse
    {
        $notification = UserNotification::query()
            ->whereKey($id)
            ->where('user_id', $request->session()->get('admin_user_id'))
            ->first();
        $data = $notification?->data_json ?? [];

        if (($data['target'] ?? null) === 'booking_admin') {
            $status = isset($data['booking_id'])
                ? Booking::query()->whereKey($data['booking_id'])->value('status')
                : null;

            return redirect()->route('admin.bookings.index', array_filter([
                'status' => match (true) {
                    in_array($status, ['confirmed', 'waiting_payment', 'payment_uploaded', 'payment_rejected', 'payment_verified'], true) => 'dikonfirmasi',
                    $status === 'completed' => 'selesai',
                    in_array($status, ['cancelled', 'expired', 'rejected'], true) => 'ditolak',
                    default => 'menunggu',
                },
                'search' => isset($data['booking_id']) ? '#'.$data['booking_id'] : null,
            ]));
        }
        if (($data['target'] ?? null) === 'payments_admin') {
            return redirect()->route('admin.transactions.index');
        }

        return redirect()->route('admin.notifications.inbox');
    }
}

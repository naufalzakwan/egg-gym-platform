<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use App\Models\UserNotification;
use App\Services\Notification\UserNotificationService;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminNotificationFeatureTest extends TestCase
{
    use DatabaseTransactions;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::create([
            'role_id' => Role::firstOrCreate(['name' => 'admin'])->id,
            'name' => 'Notification Admin',
            'email' => uniqid('notification_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
    }

    public function test_event_key_is_idempotent_per_recipient(): void
    {
        $service = app(UserNotificationService::class);

        $first = $service->notify($this->admin, 'Judul pertama', 'Pesan pertama', 'booking', 'in_app', false, [], 'booking:99:submitted:admin');
        $second = $service->notify($this->admin, 'Judul duplikat', 'Pesan duplikat', 'booking', 'in_app', false, [], 'booking:99:submitted:admin');

        $this->assertTrue($first->is($second));
        $this->assertSame(1, UserNotification::query()->where('user_id', $this->admin->id)->where('event_key', 'booking:99:submitted:admin')->count());
        $this->assertSame('Judul pertama', $second->title);
    }

    public function test_bell_shows_only_latest_five_for_signed_in_admin_with_warning_style(): void
    {
        $otherAdmin = User::create([
            'role_id' => $this->admin->role_id,
            'name' => 'Other Admin',
            'email' => uniqid('other_notification_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        foreach (range(1, 6) as $number) {
            UserNotification::create([
                'user_id' => $this->admin->id,
                'title' => "Admin notification {$number}",
                'message' => "Message {$number}",
                'type' => 'booking',
                'channel' => 'in_app',
                'priority' => $number === 6 ? 'high' : 'normal',
                'is_read' => false,
                'sent_at' => now()->addSeconds($number),
            ]);
        }
        UserNotification::create([
            'user_id' => $otherAdmin->id,
            'title' => 'Private other admin notification',
            'message' => 'Must not leak',
            'type' => 'booking',
            'channel' => 'in_app',
            'is_read' => false,
            'sent_at' => now()->addMinute(),
        ]);

        $response = $this->withSession(['admin_user_id' => $this->admin->id])->get(route('admin.dashboard'));

        $response->assertOk()
            ->assertSeeText('Admin notification 6')
            ->assertDontSeeText('Admin notification 1')
            ->assertDontSeeText('Private other admin notification')
            ->assertSee('topbar__notification-item is-unread is-warning', false)
            ->assertSeeText('Baca semua');
    }

    public function test_read_actions_are_scoped_to_signed_in_admin(): void
    {
        $own = $this->notification($this->admin, 'Own notification');
        $other = User::create([
            'role_id' => $this->admin->role_id,
            'name' => 'Read Scope Admin',
            'email' => uniqid('read_scope_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $foreign = $this->notification($other, 'Foreign notification');

        $this->withSession(['admin_user_id' => $this->admin->id])->post(route('admin.notifications.read', $foreign))->assertRedirect(route('admin.notifications.inbox'));
        $this->assertFalse($foreign->fresh()->is_read);

        $this->withSession(['admin_user_id' => $this->admin->id])->post(route('admin.notifications.read-all'))->assertRedirect();
        $this->assertTrue($own->fresh()->is_read);
        $this->assertFalse($foreign->fresh()->is_read);
    }

    public function test_broadcast_get_displays_form_without_post_validation(): void
    {
        $this->withSession(['admin_user_id' => $this->admin->id])
            ->get(route('admin.notifications.broadcast'))
            ->assertOk()
            ->assertSeeText('Broadcast Notifikasi');
    }

    private function notification(User $user, string $title): UserNotification
    {
        return UserNotification::create([
            'user_id' => $user->id,
            'title' => $title,
            'message' => 'Notification body',
            'type' => 'general',
            'channel' => 'in_app',
            'is_read' => false,
            'sent_at' => now(),
        ]);
    }
}

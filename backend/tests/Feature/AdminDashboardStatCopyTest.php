<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminDashboardStatCopyTest extends TestCase
{
    use DatabaseTransactions;

    public function test_dashboard_uses_indonesian_trainer_and_dynamic_booking_copy(): void
    {
        $role = Role::firstOrCreate(['name' => 'admin']);
        $admin = User::create([
            'role_id' => $role->id,
            'name' => 'Dashboard Copy Admin',
            'email' => uniqid('dashboard_copy_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);

        $response = $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.dashboard'));

        $response->assertOk()
            ->assertSeeText('Trainer aktif tersedia')
            ->assertSeeText('Belum ada booking hari ini')
            ->assertDontSeeText('capacity used')
            ->assertDontSeeText('Tidak ada sesi berikutnya');

        $source = file_get_contents(resource_path('views/admin/dashboard.blade.php'));
        $this->assertStringContainsString('Booking terjadwal hari ini', $source);
        $this->assertStringContainsString("\$stats['booking_today']['value'] > 0", $source);
    }
}

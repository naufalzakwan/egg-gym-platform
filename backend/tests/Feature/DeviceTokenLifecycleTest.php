<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use App\Models\UserDeviceToken;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DeviceTokenLifecycleTest extends TestCase
{
    use DatabaseTransactions;

    public function test_register_refresh_account_switch_and_logout_are_device_scoped(): void
    {
        $role = Role::firstOrCreate(['name' => 'member']);
        $first = $this->user($role, 'first');
        $second = $this->user($role, 'second');

        Sanctum::actingAs($first, [], 'sanctum');
        $this->postJson('/api/v1/auth/device-token', [
            'device_id' => 'android-device-1',
            'fcm_token' => 'fcm-token-1',
            'platform' => 'android',
            'device_name' => 'Egg Gym Android',
        ])->assertOk()
            ->assertJsonPath('data.is_active', true);

        $this->postJson('/api/v1/auth/device-token', [
            'device_id' => 'android-device-1',
            'fcm_token' => 'fcm-token-2',
            'platform' => 'android',
        ])->assertOk();
        $this->assertDatabaseMissing('user_device_tokens', [
            'user_id' => $first->id,
            'fcm_token' => 'fcm-token-1',
        ]);

        Sanctum::actingAs($second, [], 'sanctum');
        $this->postJson('/api/v1/auth/device-token', [
            'device_id' => 'android-device-1',
            'fcm_token' => 'fcm-token-2',
            'platform' => 'android',
        ])->assertOk();
        $this->assertDatabaseHas('user_device_tokens', [
            'user_id' => $first->id,
            'fcm_token' => 'fcm-token-2',
            'is_active' => false,
        ]);
        $this->assertDatabaseHas('user_device_tokens', [
            'user_id' => $second->id,
            'fcm_token' => 'fcm-token-2',
            'is_active' => true,
        ]);

        $this->deleteJson('/api/v1/auth/device-token', [
            'device_id' => 'android-device-1',
        ])->assertOk();
        $this->assertSame(0, UserDeviceToken::query()
            ->where('user_id', $second->id)
            ->where('is_active', true)
            ->count());
    }

    private function user(Role $role, string $prefix): User
    {
        return User::create([
            'role_id' => $role->id,
            'name' => ucfirst($prefix).' Token User',
            'email' => uniqid($prefix.'_token_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
    }
}

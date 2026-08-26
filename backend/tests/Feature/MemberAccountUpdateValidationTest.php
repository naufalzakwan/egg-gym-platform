<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MemberAccountUpdateValidationTest extends TestCase
{
    use DatabaseTransactions;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $role = Role::firstOrCreate(['name' => 'member']);
        $this->user = User::create([
            'role_id' => $role->id,
            'name' => 'Existing Member',
            'email' => 'member.update@example.test',
            'phone' => '081234567890',
            'password' => 'legacy-password',
            'status' => 'active',
        ]);
        MemberProfile::create([
            'user_id' => $this->user->id,
            'member_code' => 'MEM-UPDATE-1',
        ]);
        Sanctum::actingAs($this->user, [], 'sanctum');
    }

    public function test_invalid_new_identity_or_password_does_not_mutate_existing_account(): void
    {
        $originalHash = $this->user->password;

        foreach ([
            ['name' => 'Member123', 'phone' => '081234567890'],
            ['name' => 'Member Baru', 'phone' => '+628123456789'],
            [
                'name' => 'Member Baru',
                'phone' => '081234567890',
                'current_password' => 'legacy-password',
                'new_password' => 'Password1',
                'new_password_confirmation' => 'Password1',
            ],
        ] as $payload) {
            $this->putJson('/api/v1/member/profile', $payload)
                ->assertUnprocessable();
        }

        $fresh = $this->user->fresh();
        $this->assertSame('Existing Member', $fresh->name);
        $this->assertSame('081234567890', $fresh->phone);
        $this->assertSame($originalHash, $fresh->password);
        $this->assertTrue(Hash::check('legacy-password', $fresh->password));
    }

    public function test_valid_new_identity_and_strong_password_are_saved(): void
    {
        $this->putJson('/api/v1/member/profile', [
            'name' => 'Naufal Zakwan',
            'phone' => '6281234567890',
            'current_password' => 'legacy-password',
            'new_password' => 'Member!123A',
            'new_password_confirmation' => 'Member!123A',
        ])->assertOk()
            ->assertJsonPath('data.name', 'Naufal Zakwan')
            ->assertJsonPath('data.phone', '6281234567890');

        $fresh = $this->user->fresh();
        $this->assertTrue(Hash::check('Member!123A', $fresh->password));
    }
}

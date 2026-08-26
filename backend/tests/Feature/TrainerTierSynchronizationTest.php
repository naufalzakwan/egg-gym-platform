<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerRating;
use App\Models\User;
use App\Support\AuditTrailFormatter;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrainerTierSynchronizationTest extends TestCase
{
    use DatabaseTransactions;

    public function test_admin_tier_updates_are_immediately_shared_by_public_and_trainer_payloads(): void
    {
        $admin = $this->user('admin', 'Tier Admin');
        $trainerUser = $this->user('trainer', 'Synchronized Trainer');
        $trainer = TrainerProfile::create([
            'user_id' => $trainerUser->id,
            'specialty' => 'Strength Training',
            'specialties' => ['Strength Training'],
            'tier' => 'standard',
            'max_clients' => 30,
            'verification_status' => 'verified',
        ]);

        foreach ([
            'pro' => 'Pro',
            'elite' => 'Elite',
            'standard' => 'Basic',
        ] as $tier => $label) {
            $this->withSession(['admin_user_id' => $admin->id])
                ->put(route('admin.trainer-profiles.update', $trainer), [
                    'tier' => $tier,
                    'max_clients' => 30,
                    'verification_status' => 'verified',
                    'admin_notes' => null,
                ])
                ->assertRedirect(route('admin.trainer-profiles.index'));

            $public = collect($this->getJson('/api/v1/public/trainers')->assertOk()->json('data'))
                ->firstWhere('id', $trainer->id);
            $this->assertSame($tier, $public['tier']);
            $this->assertSame($label, $public['badge']);

            Sanctum::actingAs($trainerUser, [], 'sanctum');
            $this->getJson('/api/v1/trainer/dashboard')
                ->assertOk()
                ->assertJsonPath('data.tier', $tier)
                ->assertJsonPath('data.tier_label', $label);
            $this->getJson('/api/v1/trainer/profile')
                ->assertOk()
                ->assertJsonPath('data.tier', $tier)
                ->assertJsonPath('data.tier_label', $label);
        }

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.trainer-profiles.index'))
            ->assertOk()
            ->assertSeeText('Basic');
        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.trainer-profiles.show', $trainer))
            ->assertOk()
            ->assertSeeText('Basic');
        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.trainer-profiles.edit', $trainer))
            ->assertOk()
            ->assertSee('<option value="standard" selected>Basic</option>', false);
        $this->assertSame('Basic', AuditTrailFormatter::formatValue('standard', 'tier'));
    }

    public function test_rating_changes_do_not_change_tier_and_invalid_values_are_returned_safely(): void
    {
        $trainerUser = $this->user('trainer', 'Tier Independent Trainer');
        $trainer = TrainerProfile::create([
            'user_id' => $trainerUser->id,
            'specialty' => 'Strength Training',
            'specialties' => ['Strength Training'],
            'tier' => 'pro',
        ]);
        $member = MemberProfile::create([
            'user_id' => $this->user('member', 'Tier Rating Member')->id,
            'member_code' => uniqid('TIER-'),
        ]);

        TrainerRating::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $trainer->id,
            'rating' => 1,
        ]);

        $public = collect($this->getJson('/api/v1/public/trainers')->assertOk()->json('data'))
            ->firstWhere('id', $trainer->id);
        $this->assertSame(1, $public['rating']);
        $this->assertSame('pro', $public['tier']);
        $this->assertSame('Pro', $public['badge']);

        TrainerRating::query()->where('trainer_profile_id', $trainer->id)->update(['rating' => 5]);
        $public = collect($this->getJson('/api/v1/public/trainers')->assertOk()->json('data'))
            ->firstWhere('id', $trainer->id);
        $this->assertSame(5, $public['rating']);
        $this->assertSame('pro', $public['tier']);
        $this->assertSame('Pro', $public['badge']);

        DB::table('trainer_profiles')->where('id', $trainer->id)->update(['tier' => 'malformed']);
        $public = collect($this->getJson('/api/v1/public/trainers')->assertOk()->json('data'))
            ->firstWhere('id', $trainer->id);
        $this->assertNull($public['tier']);
        $this->assertNull($public['badge']);

        Sanctum::actingAs($trainerUser, [], 'sanctum');
        $this->getJson('/api/v1/trainer/profile')
            ->assertOk()
            ->assertJsonPath('data.tier', null)
            ->assertJsonPath('data.tier_label', null);
    }

    private function user(string $role, string $name): User
    {
        return User::create([
            'role_id' => Role::firstOrCreate(['name' => $role])->id,
            'name' => $name,
            'email' => uniqid('tier_sync_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
    }
}

<?php

namespace Tests\Feature;

use App\Models\MembershipPlan;
use Carbon\Carbon;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class PublicMembershipDescriptionContractTest extends TestCase
{
    use DatabaseTransactions;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_public_package_omits_legacy_description_even_when_database_has_one(): void
    {
        MembershipPlan::query()->create([
            'name' => 'Legacy Description Plan',
            'slug' => 'legacy-description-plan',
            'description' => 'This legacy text must never reach mobile.',
            'price' => 100000,
            'billing_period' => 'monthly',
            'duration_days' => 30,
            'features_json' => ['Gym access'],
            'is_active' => true,
        ]);

        $response = $this->getJson('/api/v1/public/membership-plans')->assertOk();
        $plan = collect($response->json('data'))->firstWhere('slug', 'legacy-description-plan');

        $this->assertNotNull($plan);
        $this->assertArrayNotHasKey('description', $plan);
        $this->assertSame(30, $plan['duration_days']);
        $this->assertSame(['Akses gym'], $plan['features']);
    }

    public function test_public_packages_are_dynamic_and_obey_release_and_deletion_status(): void
    {
        $now = CarbonImmutable::parse('2026-07-26 12:00:00', 'Asia/Jakarta');
        Carbon::setTestNow($now);
        CarbonImmutable::setTestNow($now);

        $eligible = collect([
            $this->createPlan('Starter Drop', 'starter-drop', 110000, null),
            $this->createPlan('Weekend Pass', 'weekend-pass', 120000, '2026-07-26'),
            $this->createPlan('Archive Special', 'archive-special', 130000, '2026-07-20'),
            $this->createPlan('Flash Sale', 'flash-sale', 140000, null, true, 14, [
                'Gym access',
                'Flash class access',
            ]),
        ]);
        $inactive = $this->createPlan('Inactive Drop', 'inactive-drop', 150000, null, false);
        $future = $this->createPlan('Future Drop', 'future-drop', 160000, '2026-07-27');
        $deleted = $this->createPlan('Deleted Drop', 'deleted-drop', 170000, null);
        $deleted->delete();

        $data = collect($this->getJson('/api/v1/public/membership-plans')
            ->assertOk()
            ->json('data'));
        $returnedEligible = $data->whereIn('id', $eligible->pluck('id'))->values();

        $this->assertCount(4, $returnedEligible);
        $this->assertSame($eligible->pluck('id')->all(), $returnedEligible->pluck('id')->all());
        $this->assertSame('Flash Sale', $returnedEligible->last()['name']);
        $this->assertSame(14, $returnedEligible->last()['duration_days']);
        $this->assertSame(
            ['Akses gym', 'Flash class access'],
            $returnedEligible->last()['features']
        );
        $this->assertFalse($data->pluck('id')->contains($inactive->id));
        $this->assertFalse($data->pluck('id')->contains($future->id));
        $this->assertFalse($data->pluck('id')->contains($deleted->id));
    }

    public function test_admin_store_ignores_unadvertised_description_input(): void
    {
        $admin = $this->createAdminSessionUser();

        $this->withSession(['admin_user_id' => $admin->id])
            ->post('/admin/membership-plans', [
                'name' => 'No Description Input Plan',
                'description' => 'Injected hidden description',
                'price' => 200000,
                'duration_days' => 30,
                'billing_period' => 'monthly',
                'features_text' => "Gym access\nLocker access",
                'is_active' => '1',
            ])->assertRedirect('/admin/membership-plans');

        $this->assertDatabaseHas('membership_plans', [
            'name' => 'No Description Input Plan',
            'description' => null,
        ]);
    }

    private function createAdminSessionUser(): \App\Models\User
    {
        $role = \App\Models\Role::query()->firstOrCreate(['name' => 'admin']);

        return \App\Models\User::query()->create([
            'role_id' => $role->id,
            'name' => 'Description Contract Admin',
            'email' => uniqid('description_admin_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
    }

    private function createPlan(
        string $name,
        string $slug,
        int $price,
        ?string $releaseDate,
        bool $active = true,
        int $durationDays = 30,
        array $features = ['Gym access'],
    ): MembershipPlan {
        return MembershipPlan::query()->create([
            'name' => $name,
            'slug' => $slug,
            'price' => $price,
            'billing_period' => 'monthly',
            'duration_days' => $durationDays,
            'release_date' => $releaseDate,
            'features_json' => $features,
            'is_active' => $active,
        ]);
    }
}

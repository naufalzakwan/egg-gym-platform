<?php

namespace Tests\Feature;

use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MemberProgress;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminContextualSearchTest extends TestCase
{
    use DatabaseTransactions;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutExceptionHandling();

        $role = Role::firstOrCreate(['name' => 'admin']);
        $this->admin = User::create([
            'role_id' => $role->id,
            'name' => 'Search Test Admin',
            'email' => uniqid('search_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
    }

    public function test_topbar_is_a_contextual_get_search_and_preserves_active_filter(): void
    {
        $this->withSession(['admin_user_id' => $this->admin->id])
            ->get(route('admin.bookings.index', ['status' => 'selesai', 'search' => 'andi']))
            ->assertOk()
            ->assertSee('class="topbar__search" method="GET"', false)
            ->assertSee('name="search" value="andi"', false)
            ->assertSee('name="status" value="selesai"', false);
    }

    public function test_pages_without_contextual_search_do_not_render_disabled_search(): void
    {
        foreach (['admin.dashboard', 'admin.audit-trail.index', 'admin.settings.index'] as $route) {
            $this->withSession(['admin_user_id' => $this->admin->id])
                ->get(route($route))
                ->assertOk()
                ->assertDontSee('class="topbar__search', false)
                ->assertDontSee('Pilih menu data untuk menggunakan pencarian.')
                ->assertDontSee('Pencarian tidak tersedia di halaman ini', false);
        }
    }

    public function test_membership_plan_topbar_search_filters_real_records_by_partial_name(): void
    {
        MembershipPlan::create([
            'name' => 'Paket Search Alpha',
            'slug' => uniqid('search-alpha-'),
            'description' => 'Paket khusus pengujian pencarian',
            'price' => 150000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['Akses gym'],
            'is_active' => true,
        ]);
        MembershipPlan::create([
            'name' => 'Paket Search Beta',
            'slug' => uniqid('search-beta-'),
            'description' => 'Paket lain',
            'price' => 250000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['Akses gym'],
            'is_active' => true,
        ]);

        $this->withSession(['admin_user_id' => $this->admin->id])
            ->get(route('admin.membership-plans.index', ['search' => 'alpha']))
            ->assertOk()
            ->assertSeeText('Paket Search Alpha')
            ->assertDontSeeText('Paket Search Beta');
    }

    public function test_physical_progress_uses_one_topbar_search_and_title_value_hint_cards(): void
    {
        $response = $this->withSession(['admin_user_id' => $this->admin->id])
            ->get(route('admin.member-progress.index'));

        $response->assertOk()
            ->assertSee('class="topbar__search" method="GET"', false)
            ->assertDontSee('class="pp-toolbar"', false)
            ->assertDontSee('class="pp-tier', false)
            ->assertDontSee('Cari nama, kode member, atau goal...')
            ->assertSeeInOrder(['Member Dipantau', 'Punya minimal 1 checkpoint'])
            ->assertSeeInOrder(['Rata-rata Perubahan BB', 'Baseline &rarr; terkini'], false)
            ->assertSeeInOrder(['Perlu Perhatian', 'Member aktif tanpa checkpoint']);

        $this->assertSame(1, substr_count($response->getContent(), 'class="topbar__search"'));
    }

    public function test_physical_progress_prioritizes_checkpoints_filters_real_data_and_paginates_five(): void
    {
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $prefix = 'PPFILTER'.strtoupper(substr(uniqid(), -6));
        $plan = MembershipPlan::create([
            'name' => $prefix.' Active Plan',
            'slug' => strtolower($prefix).'-active-plan',
            'description' => 'Physical progress filter fixture',
            'price' => 100000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => [],
            'is_active' => true,
        ]);
        $profiles = collect();

        foreach (range(1, 7) as $index) {
            $user = User::create([
                'role_id' => $memberRole->id,
                'name' => $prefix.' Member '.$index,
                'email' => strtolower($prefix).$index.'@example.test',
                'password' => 'password123',
                'status' => 'active',
            ]);
            $profile = MemberProfile::create([
                'user_id' => $user->id,
                'member_code' => $prefix.'-'.$index,
                'fitness_goal' => $index <= 3 ? 'Turun berat badan' : 'Menjaga kebugaran',
                'joined_at' => now(),
            ]);
            $profiles->push($profile);

            if ($index <= 3) {
                foreach (range(1, 4 - $index) as $checkpoint) {
                    MemberProgress::create([
                        'member_profile_id' => $profile->id,
                        'weight_kg' => 70 - $checkpoint,
                        'height_cm' => 170,
                        'recorded_at' => now()->subDays(10 - $checkpoint)->toDateString(),
                    ]);
                }
            }

            if (in_array($index, [1, 4], true)) {
                MemberMembership::create([
                    'member_profile_id' => $profile->id,
                    'membership_plan_id' => $plan->id,
                    'start_date' => now()->subDay()->toDateString(),
                    'end_date' => now()->addMonth()->toDateString(),
                    'status' => 'active',
                    'payment_status' => 'paid',
                ]);
            }
        }

        $pageOne = $this->withSession(['admin_user_id' => $this->admin->id])
            ->get(route('admin.member-progress.index', ['search' => $prefix]));
        $pageOne->assertOk()
            ->assertViewHas('members', fn ($members) => $members->perPage() === 5
                && $members->count() === 5
                && $members->total() === 7
                && $members->pluck('progress_records_count')->all() === [3, 2, 1, 0, 0])
            ->assertSee('Menampilkan 1&ndash;5 dari 7 member', false)
            ->assertSee('search='.$prefix, false);

        $tracked = $this->withSession(['admin_user_id' => $this->admin->id])
            ->get(route('admin.member-progress.index', [
                'search' => $prefix,
                'checkpoint' => 'tracked',
            ]));
        $tracked->assertOk()
            ->assertViewHas('members', fn ($members) => $members->total() === 3
                && $members->pluck('progress_records_count')->all() === [3, 2, 1])
            ->assertSee('value="tracked" selected', false)
            ->assertSeeText('Reset Filter');

        $activeWithoutCheckpoint = $this->withSession(['admin_user_id' => $this->admin->id])
            ->get(route('admin.member-progress.index', [
                'search' => $prefix,
                'checkpoint' => 'untracked',
                'membership' => 'active',
            ]));
        $activeWithoutCheckpoint->assertOk()
            ->assertViewHas('members', fn ($members) => $members->total() === 1)
            ->assertSeeText($prefix.' Member 4')
            ->assertDontSeeText($prefix.' Member 1')
            ->assertDontSeeText('Belum ada checkpoint')
            ->assertDontSeeText('Belum ada')
            ->assertDontSeeText('Tidak aktif')
            ->assertDontSee('class="pp-tier', false);
    }
}

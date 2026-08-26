<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminTrainerRevenueTest extends TestCase
{
    use DatabaseTransactions;

    private User $admin;

    private MemberProfile $member;

    private TrainerProfile $trainer;

    private TrainerProfile $otherTrainer;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-07-27 12:00:00', 'Asia/Jakarta'));

        $this->admin = $this->user('admin', 'Revenue Admin');
        $memberUser = $this->user('member', 'Revenue Member');
        $this->member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => uniqid('REV-'),
        ]);
        $this->trainer = $this->trainer('Revenue Trainer', 999999);
        $this->otherTrainer = $this->trainer('Other Revenue Trainer', 750000);
    }

    public function test_detail_aggregates_six_months_by_verified_date_and_snapshot_precedence(): void
    {
        $this->booking($this->trainer, 'payment_verified', '2026-07-01 08:00:00', 2, 70000, 200000);
        $this->booking($this->trainer, 'completed', '2026-07-05 08:00:00', 3, 80000, null);
        $this->booking($this->trainer, 'confirmed', null, 1, null, null);
        $createdInJune = $this->booking($this->trainer, 'payment_verified', '2026-07-02 08:00:00', 4, 90000, 360000);
        $createdInJune->timestamps = false;
        $createdInJune->forceFill(['created_at' => '2026-06-30 23:00:00'])->save();

        $this->booking($this->trainer, 'payment_verified', '2026-06-15 08:00:00', 2, 90000, 180000);
        $this->booking($this->otherTrainer, 'payment_verified', '2026-07-10 08:00:00', 9, null, 9000000);

        $response = $this->adminGet(route('admin.trainer-profiles.show', $this->trainer));
        $response->assertOk()
            ->assertSeeText('Pendapatan Bulanan PT')
            ->assertSeeText('Pendapatan Bulan Ini')
            ->assertSeeText('Booking Valid')
            ->assertSeeText('Sesi Terjual')
            ->assertSeeText('Juli 2026')
            ->assertSeeText('Juni 2026')
            ->assertSeeText('Mei 2026')
            ->assertSeeText('Rp 1.799.999')
            ->assertSeeText('Rp 180.000')
            ->assertDontSeeText('Rp 9.000.000')
            ->assertViewHas('revenueSummary', function (array $summary) {
                return $summary['current']['revenue_value'] === 1799999.0
                    && $summary['current']['valid_bookings'] === 4
                    && $summary['current']['sold_sessions'] === 10
                    && $summary['months'][1]['revenue_value'] === 180000.0
                    && $summary['months'][1]['valid_bookings'] === 1
                    && $summary['months'][1]['sold_sessions'] === 2
                    && count($summary['months']) === 6;
            });
    }

    public function test_unverified_and_terminal_statuses_never_enter_trainer_revenue(): void
    {
        foreach (['pending', 'waiting_payment', 'payment_uploaded', 'payment_rejected', 'expired', 'cancelled', 'rejected'] as $status) {
            $this->booking($this->trainer, $status, '2026-07-10 08:00:00', 2, 100000, 200000);
        }
        $this->booking($this->trainer, 'rescheduled', null, 2, 100000, 200000);

        $this->adminGet(route('admin.trainer-profiles.show', $this->trainer))
            ->assertOk()
            ->assertSeeText('Belum ada pendapatan valid dari booking PT.')
            ->assertViewHas('revenueSummary', fn (array $summary) => $summary['has_revenue'] === false
                && $summary['current']['revenue_value'] === 0.0
                && $summary['current']['valid_bookings'] === 0
                && $summary['current']['sold_sessions'] === 0);
    }

    private function booking(
        TrainerProfile $trainer,
        string $status,
        ?string $verifiedAt,
        int $sessions,
        ?int $priceSnapshot,
        ?int $totalSnapshot
    ): Booking {
        $booking = Booking::create([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $trainer->id,
            'session_title' => 'Revenue '.$status.' '.uniqid(),
            'session_date' => '2026-07-30',
            'start_time' => '10:00:00',
            'end_time' => '11:00:00',
            'session_duration_minutes' => 60,
            'location' => 'Egg Gym',
            'session_count' => $sessions,
            'price_per_session_snapshot' => $priceSnapshot,
            'total_amount_snapshot' => $totalSnapshot,
            'status' => $status,
            'payment_verified_at' => $verifiedAt,
        ]);

        if ($verifiedAt === null && in_array($status, ['payment_verified', 'confirmed', 'completed'], true)) {
            $booking->timestamps = false;
            $booking->forceFill(['updated_at' => '2026-07-20 08:00:00'])->save();
        }

        return $booking;
    }

    private function trainer(string $name, int $price): TrainerProfile
    {
        $user = $this->user('trainer', $name);

        return TrainerProfile::create([
            'user_id' => $user->id,
            'specialty' => 'Strength Training',
            'price_per_session' => $price,
            'max_clients' => 20,
        ]);
    }

    private function user(string $roleName, string $name): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);

        return User::create([
            'role_id' => $role->id,
            'name' => $name,
            'email' => uniqid(strtolower($roleName).'_revenue_', true).'@example.test',
            'phone' => '08'.random_int(100000000, 999999999),
            'password' => 'password123',
            'status' => 'active',
        ]);
    }

    private function adminGet(string $url)
    {
        return $this->withSession(['admin_user_id' => $this->admin->id])->get($url);
    }
}

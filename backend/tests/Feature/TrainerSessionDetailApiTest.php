<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use App\Models\User;
use Carbon\Carbon;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrainerSessionDetailApiTest extends TestCase
{
    use DatabaseTransactions;

    private CarbonImmutable $now;

    private User $trainerUser;

    private TrainerProfile $trainer;

    private User $otherTrainerUser;

    private TrainerProfile $otherTrainer;

    private User $memberUser;

    private MemberProfile $member;

    private TrainerScheduleDate $scheduleDate;

    protected function setUp(): void
    {
        parent::setUp();

        $this->now = CarbonImmutable::parse('2026-07-27T08:00:00+07:00');
        Carbon::setTestNow($this->now);
        CarbonImmutable::setTestNow($this->now);

        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);

        $this->trainerUser = User::create([
            'role_id' => $trainerRole->id,
            'name' => 'Trainer Detail Owner',
            'email' => uniqid('trainer_detail_owner_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $this->trainerUser->id,
            'specialty' => 'Strength',
            'price_per_session' => 175000,
        ]);

        $this->otherTrainerUser = User::create([
            'role_id' => $trainerRole->id,
            'name' => 'Other Trainer',
            'email' => uniqid('trainer_detail_other_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->otherTrainer = TrainerProfile::create([
            'user_id' => $this->otherTrainerUser->id,
            'specialty' => 'Mobility',
            'price_per_session' => 150000,
        ]);

        $this->memberUser = User::create([
            'role_id' => $memberRole->id,
            'name' => 'Member Full Profile',
            'email' => uniqid('trainer_detail_member_', true).'@example.test',
            'phone' => '081234567890',
            'avatar_url' => 'avatars/member-detail.jpg',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->member = MemberProfile::create([
            'user_id' => $this->memberUser->id,
            'member_code' => uniqid('DETAIL-'),
            'gender' => 'female',
            'birth_date' => '1997-04-12',
            'height_cm' => 165,
            'weight_kg' => 58,
            'fitness_goal' => 'Build strength',
            'medical_note' => 'Previous left knee injury.',
        ]);

        $this->scheduleDate = TrainerScheduleDate::create([
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => '2026-07-30',
            'state' => 'open',
            'source' => 'manual',
            'overridden_at' => now(),
        ]);
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_owned_pending_detail_contains_full_profile_booking_and_membership_data(): void
    {
        $plan = MembershipPlan::create([
            'name' => 'Detail Elite Plan',
            'slug' => uniqid('detail-elite-'),
            'price' => 750000,
            'billing_period' => 'monthly',
            'is_active' => true,
        ]);
        MemberMembership::create([
            'member_profile_id' => $this->member->id,
            'membership_plan_id' => $plan->id,
            'start_date' => $this->now->subDays(5)->toDateString(),
            'end_date' => $this->now->addMonth()->toDateString(),
            'status' => 'active',
            'payment_status' => 'paid',
        ]);

        $booking = $this->createBooking([
            'session_title' => 'Three Session Strength Plan',
            'session_count' => 3,
            'price_per_session_snapshot' => 175000,
            'total_amount_snapshot' => 525000,
            'member_note' => 'Focus on safe squat technique.',
            'trainer_note' => 'Review knee mobility first.',
        ]);
        $second = $this->createReservation($booking, 2, '2026-08-01', '10:00:00');
        $first = $this->createReservation($booking, 1, '2026-07-30', '09:00:00');
        $third = $this->createReservation($booking, 3, '2026-08-03', '11:00:00');

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $response = $this->getJson("/api/v1/trainer/sessions/{$booking->id}")
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.booking_number', 'EGG-PT-'.str_pad((string) $booking->id, 6, '0', STR_PAD_LEFT))
            ->assertJsonPath('data.created_at', $booking->created_at->toIso8601String())
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.session_count', 3)
            ->assertJsonPath('data.price_per_session', 175000)
            ->assertJsonPath('data.total_amount', 525000)
            ->assertJsonPath('data.member_note', 'Focus on safe squat technique.')
            ->assertJsonPath('data.trainer_note', 'Review knee mobility first.')
            ->assertJsonPath('data.member.name', 'Member Full Profile')
            ->assertJsonPath('data.member.email', $this->memberUser->email)
            ->assertJsonPath('data.member.phone', '081234567890')
            ->assertJsonPath('data.member.member_code', $this->member->member_code)
            ->assertJsonPath('data.member.avatar_url', 'avatars/member-detail.jpg')
            ->assertJsonPath('data.member.fitness_goal', 'Build strength')
            ->assertJsonPath('data.member.medical_note', 'Previous left knee injury.')
            ->assertJsonPath('data.active_membership.plan_name', 'Detail Elite Plan')
            ->assertJsonPath('data.active_membership.plan_slug', $plan->slug)
            ->assertJsonPath('data.active_membership.status', 'active')
            ->assertJsonPath('data.active_membership.payment_status', 'paid')
            ->assertJsonPath('data.active_membership.start_date', $this->now->subDays(5)->toDateString())
            ->assertJsonPath('data.active_membership.end_date', $this->now->addMonth()->toDateString())
            ->assertJsonPath('data.active_membership.is_active', true)
            ->assertJsonCount(3, 'data.session_reservations');

        $this->assertSame(
            [$first->id, $second->id, $third->id],
            collect($response->json('data.session_reservations'))->pluck('id')->all()
        );
    }

    public function test_other_trainer_cannot_expire_or_release_booking_through_trainer_actions(): void
    {
        Sanctum::actingAs($this->otherTrainerUser, [], 'sanctum');

        $actions = [
            ['method' => 'get', 'suffix' => '', 'payload' => []],
            ['method' => 'post', 'suffix' => '/confirm', 'payload' => []],
            ['method' => 'post', 'suffix' => '/reject', 'payload' => []],
            ['method' => 'post', 'suffix' => '/verify-payment', 'payload' => ['verified' => true]],
        ];

        foreach ($actions as $index => $action) {
            $booking = $this->createBooking([
                'session_title' => 'Unauthorized overdue '.$index,
                'expired_at' => $this->now->subSecond(),
            ]);
            $reservation = $this->createReservation(
                $booking,
                1,
                '2026-07-30',
                sprintf('%02d:00:00', 9 + $index)
            );
            $uri = "/api/v1/trainer/sessions/{$booking->id}{$action['suffix']}";

            if ($action['method'] === 'get') {
                $this->getJson($uri)->assertNotFound();
            } else {
                $this->postJson($uri, $action['payload'])->assertNotFound();
            }

            $this->assertSame('pending', $booking->fresh()->status);
            $this->assertSame(BookingSessionReservation::STATUS_RESERVED, $reservation->fresh()->status);
            $this->assertNull($reservation->fresh()->released_at);
        }
    }

    public function test_member_role_cannot_access_trainer_session_detail(): void
    {
        $booking = $this->createBooking();
        $this->createReservation($booking, 1, '2026-07-30', '09:00:00');

        Sanctum::actingAs($this->memberUser, [], 'sanctum');
        $this->getJson("/api/v1/trainer/sessions/{$booking->id}")
            ->assertForbidden();

        $this->assertSame('pending', $booking->fresh()->status);
    }

    public function test_owned_overdue_detail_synchronizes_expiry_and_reservation_release(): void
    {
        $booking = $this->createBooking(['expired_at' => $this->now->subSecond()]);
        $reservation = $this->createReservation($booking, 1, '2026-07-30', '09:00:00');

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->getJson("/api/v1/trainer/sessions/{$booking->id}")
            ->assertOk()
            ->assertJsonPath('data.status', 'expired')
            ->assertJsonPath('data.is_expired', true)
            ->assertJsonPath('data.session_reservations.0.status', 'released');

        $this->assertSame('expired', $booking->fresh()->status);
        $this->assertSame(BookingSessionReservation::STATUS_RELEASED, $reservation->fresh()->status);
        $this->assertNotNull($reservation->fresh()->released_at);
    }

    public function test_confirm_and_reject_keep_existing_status_and_reservation_behavior(): void
    {
        $confirmed = $this->createBooking(['session_title' => 'Confirm behavior']);
        $confirmedReservation = $this->createReservation($confirmed, 1, '2026-07-30', '09:00:00');
        $rejected = $this->createBooking(['session_title' => 'Reject behavior']);
        $rejectedReservation = $this->createReservation($rejected, 1, '2026-07-30', '11:00:00');

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/sessions/{$confirmed->id}/confirm")
            ->assertOk()
            ->assertJsonPath('data.status', 'waiting_payment');
        $this->assertSame('waiting_payment', $confirmed->fresh()->status);
        $this->assertSame(BookingSessionReservation::STATUS_RESERVED, $confirmedReservation->fresh()->status);

        $this->postJson("/api/v1/trainer/sessions/{$rejected->id}/reject")
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled')
            ->assertJsonPath('data.session_reservations.0.status', 'cancelled');
        $this->assertSame('cancelled', $rejected->fresh()->status);
        $this->assertSame(BookingSessionReservation::STATUS_CANCELLED, $rejectedReservation->fresh()->status);
        $this->assertNull($rejected->fresh()->expired_at);
    }

    private function createBooking(array $overrides = []): Booking
    {
        return Booking::create(array_merge([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'trainer_schedule_date_id' => $this->scheduleDate->id,
            'session_title' => 'Trainer Detail Booking',
            'session_date' => '2026-07-30',
            'start_time' => '09:00:00',
            'end_time' => '10:00:00',
            'session_duration_minutes' => 60,
            'location' => 'Studio Detail',
            'session_count' => 1,
            'price_per_session_snapshot' => 175000,
            'total_amount_snapshot' => 175000,
            'status' => 'pending',
            'expired_at' => $this->now->addHour(),
            'member_note' => 'Member detail note.',
            'trainer_note' => 'Trainer detail note.',
        ], $overrides));
    }

    private function createReservation(
        Booking $booking,
        int $sequence,
        string $date,
        string $startTime
    ): BookingSessionReservation {
        $endTime = CarbonImmutable::parse("{$date} {$startTime}")->addHour()->format('H:i:s');

        return $booking->sessionReservations()->create([
            'sequence_order' => $sequence,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'trainer_schedule_date_id' => $this->scheduleDate->id,
            'session_date' => $date,
            'start_time' => $startTime,
            'end_time' => $endTime,
            'session_duration_minutes' => 60,
            'status' => BookingSessionReservation::STATUS_RESERVED,
        ]);
    }
}

<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerRating;
use App\Models\TrainerScheduleDate;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MemberProgramRatingTest extends TestCase
{
    use DatabaseTransactions;

    private TrainerProfile $trainer;

    private User $memberUser;

    private MemberProfile $member;

    protected function setUp(): void
    {
        parent::setUp();

        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);

        $trainerUser = User::create([
            'role_id' => $trainerRole->id,
            'name' => 'Rating Trainer',
            'email' => uniqid('rating_trainer_', true).'@example.test',
            'password' => 'password',
            'avatar_url' => 'avatars/trainers/rating-trainer.jpg',
            'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $trainerUser->id,
            'specialty' => 'Rating testing',
            'display_photo_path' => 'trainer-display-photos/rating-trainer.jpg',
        ]);

        $this->memberUser = User::create([
            'role_id' => $memberRole->id,
            'name' => 'Rating Member',
            'email' => uniqid('rating_member_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->member = MemberProfile::create([
            'user_id' => $this->memberUser->id,
            'member_code' => uniqid('RATING-'),
        ]);

        Sanctum::actingAs($this->memberUser, [], 'sanctum');
    }

    public function test_completed_unrated_program_emits_rating_eligibility_and_real_latest_session_metadata(): void
    {
        $program = $this->program($this->member, 'Completed with reservation metadata');
        $booking = $this->booking($this->member);
        $sessionOne = $this->programSession($program, 1, 'completed', 240);
        $sessionTwo = $this->programSession($program, 2, 'completed', 240);

        $this->reservation(
            $booking,
            $sessionOne,
            1,
            '2026-07-25',
            '08:00:00',
            '09:00:00',
            60,
            '2026-07-20 09:01:00'
        );
        $this->reservation(
            $booking,
            $sessionTwo,
            2,
            '2026-07-19',
            '14:10:00',
            '15:25:00',
            90,
            '2026-07-21 15:30:00'
        );

        $this->getJson('/api/v1/member/programs')
            ->assertOk()
            ->assertJsonPath('data.0.id', $program->id)
            ->assertJsonPath('data.0.trainer_avatar_url', 'avatars/trainers/rating-trainer.jpg')
            ->assertJsonPath('data.0.trainer_display_photo_path', 'trainer-display-photos/rating-trainer.jpg')
            ->assertJsonPath('data.0.last_session_date', '2026-07-19')
            ->assertJsonPath('data.0.completed_at', '2026-07-21T15:30:00+07:00')
            ->assertJsonPath('data.0.last_session_duration_minutes', 75)
            ->assertJsonPath('data.0.program_completed', true)
            ->assertJsonPath('data.0.already_rated', false)
            ->assertJsonPath('data.0.can_rate', true);
    }

    public function test_completed_program_with_unavailable_metadata_returns_nulls_safely(): void
    {
        $this->trainer->user->update(['avatar_url' => null]);
        $this->trainer->update(['display_photo_path' => null]);
        $program = $this->program($this->member, 'Completed without metadata');
        $this->programSession($program, 1, 'completed');

        $this->getJson('/api/v1/member/programs')
            ->assertOk()
            ->assertJsonPath('data.0.id', $program->id)
            ->assertJsonPath('data.0.trainer_avatar_url', null)
            ->assertJsonPath('data.0.trainer_display_photo_path', null)
            ->assertJsonPath('data.0.last_session_date', null)
            ->assertJsonPath('data.0.completed_at', null)
            ->assertJsonPath('data.0.last_session_duration_minutes', null)
            ->assertJsonPath('data.0.can_rate', true);
    }

    public function test_latest_session_falls_back_to_reservation_chronology_and_persisted_duration(): void
    {
        $program = $this->program($this->member, 'Reservation chronology fallback');
        $booking = $this->booking($this->member);
        $olderSession = $this->programSession($program, 2, 'completed', 240);
        $latestSession = $this->programSession($program, 1, 'completed', 240);

        $this->reservation(
            $booking,
            $olderSession,
            1,
            '2026-07-18',
            '10:00:00',
            '11:00:00',
            60
        );
        $this->reservation(
            $booking,
            $latestSession,
            2,
            '2026-07-24',
            '14:00:00',
            '14:00:00',
            90
        );

        $this->getJson('/api/v1/member/programs')
            ->assertOk()
            ->assertJsonPath('data.0.id', $program->id)
            ->assertJsonPath('data.0.last_session_date', '2026-07-24')
            ->assertJsonPath('data.0.completed_at', null)
            ->assertJsonPath('data.0.last_session_duration_minutes', 90);
    }

    public function test_post_rating_flips_summary_state_stores_testimonial_and_updates_aggregate(): void
    {
        $program = $this->program($this->member, 'Rate this program');
        $this->programSession($program, 1, 'completed');
        $otherMember = $this->member('Aggregate Member');
        TrainerRating::create([
            'member_profile_id' => $otherMember->id,
            'trainer_profile_id' => $this->trainer->id,
            'rating' => 5,
        ]);

        $this->getJson('/api/v1/member/programs')
            ->assertOk()
            ->assertJsonPath('data.0.can_rate', true)
            ->assertJsonPath('data.0.already_rated', false);

        $this->postJson('/api/v1/member/ratings', [
            'training_program_id' => $program->id,
            'rating' => 3,
            'testimonial' => 'Latihannya terarah dan jelas.',
        ])
            ->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.rating', 3)
            ->assertJsonPath('data.average_rating', 4)
            ->assertJsonPath('data.reviews_count', 2)
            ->assertJsonPath('data.testimonial', 'Latihannya terarah dan jelas.');

        $this->assertDatabaseHas('trainer_ratings', [
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'training_program_id' => $program->id,
            'rating' => 3,
            'testimonial' => 'Latihannya terarah dan jelas.',
        ]);
        $this->assertSame('0.00', $this->trainer->refresh()->rating);

        $this->getJson('/api/v1/member/programs')
            ->assertOk()
            ->assertJsonPath('data.0.can_rate', false)
            ->assertJsonPath('data.0.already_rated', true)
            ->assertJsonPath('data.0.rating', 3);
    }

    public function test_duplicate_rating_is_rejected_with_canonical_error(): void
    {
        $program = $this->program($this->member, 'Already rated program');
        $this->programSession($program, 1, 'completed');
        TrainerRating::create([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'training_program_id' => $program->id,
            'rating' => 4,
        ]);

        $this->postJson('/api/v1/member/ratings', [
            'training_program_id' => $program->id,
            'rating' => 5,
        ])
            ->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Kamu sudah memberikan rating untuk program ini.');

        $this->assertSame(1, TrainerRating::where('training_program_id', $program->id)->count());
    }

    public function test_incomplete_program_rating_is_rejected_with_canonical_error(): void
    {
        $program = $this->program($this->member, 'Incomplete program');
        $this->programSession($program, 1, 'completed');
        $this->programSession($program, 2, 'active');

        $this->postJson('/api/v1/member/ratings', [
            'training_program_id' => $program->id,
            'rating' => 5,
        ])
            ->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Rating hanya bisa diberikan setelah semua sesi program latihan selesai.');

        $this->assertDatabaseMissing('trainer_ratings', [
            'training_program_id' => $program->id,
        ]);
    }

    public function test_rating_program_owned_by_another_member_is_rejected_with_canonical_error(): void
    {
        $otherMember = $this->member('Program Owner');
        $program = $this->program($otherMember, 'Another member program');
        $this->programSession($program, 1, 'completed');

        $this->postJson('/api/v1/member/ratings', [
            'training_program_id' => $program->id,
            'rating' => 5,
        ])
            ->assertNotFound()
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Program tidak ditemukan untuk member ini.');

        $this->assertDatabaseMissing('trainer_ratings', [
            'training_program_id' => $program->id,
        ]);
    }

    private function member(string $name): MemberProfile
    {
        $role = Role::firstOrCreate(['name' => 'member']);
        $user = User::create([
            'role_id' => $role->id,
            'name' => $name,
            'email' => uniqid('rating_member_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);

        return MemberProfile::create([
            'user_id' => $user->id,
            'member_code' => uniqid('RATING-'),
        ]);
    }

    private function program(MemberProfile $member, string $title): TrainingProgram
    {
        return TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $member->id,
            'title' => $title,
            'status' => 'active',
        ]);
    }

    private function programSession(
        TrainingProgram $program,
        int $sequence,
        string $status,
        int $duration = 60
    ): TrainingProgramSession {
        return TrainingProgramSession::create([
            'training_program_id' => $program->id,
            'sequence_order' => $sequence,
            'title' => 'Session '.$sequence,
            'duration_minutes' => $duration,
            'status' => $status,
        ]);
    }

    private function booking(MemberProfile $member): Booking
    {
        return Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Rating metadata booking',
            'session_date' => '2026-07-19',
            'start_time' => '14:10:00',
            'end_time' => '15:25:00',
            'session_duration_minutes' => 75,
            'location' => 'EggGym Studio',
            'session_count' => 2,
            'status' => 'completed',
        ]);
    }

    private function reservation(
        Booking $booking,
        TrainingProgramSession $session,
        int $sequence,
        string $date,
        string $start,
        string $end,
        int $persistedDuration,
        ?string $completedAt = null
    ): BookingSessionReservation {
        $scheduleDate = TrainerScheduleDate::firstOrCreate([
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => $date,
        ], [
            'state' => 'open',
            'source' => 'manual',
            'lock_version' => 1,
        ]);
        $reservation = BookingSessionReservation::create([
            'booking_id' => $booking->id,
            'sequence_order' => $sequence,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'trainer_schedule_date_id' => $scheduleDate->id,
            'session_date' => $date,
            'start_time' => $start,
            'end_time' => $end,
            'session_duration_minutes' => $persistedDuration,
            'status' => BookingSessionReservation::STATUS_COMPLETED,
            'completed_at' => $completedAt === null
                ? null
                : CarbonImmutable::parse($completedAt, config('app.timezone')),
        ]);
        $session->update(['booking_session_reservation_id' => $reservation->id]);

        return $reservation;
    }
}

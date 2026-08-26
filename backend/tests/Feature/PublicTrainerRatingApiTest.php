<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerRating;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PublicTrainerRatingApiTest extends TestCase
{
    use DatabaseTransactions;

    public function test_public_list_and_detail_use_only_live_valid_rating_rows_without_rating_n_plus_one(): void
    {
        $unrated = $this->trainer('Cached Five Unrated', 5);
        $five = $this->trainer('One Five Star', 1);
        $fourPointFive = $this->trainer('Two Review Average', 5);
        $fourPointSixSeven = $this->trainer('Three Review Average', 1);

        $this->rate($five, 5);
        $this->rate($fourPointFive, 5);
        $this->rate($fourPointFive, 4, 'Helpful coaching.');
        $this->rate($fourPointFive, 0);
        $this->rate($fourPointFive, 6);
        $this->rate($fourPointSixSeven, 5);
        $this->rate($fourPointSixSeven, 5);
        $this->rate($fourPointSixSeven, 4);

        $this->assertSame(0, $unrated->ratings()->count());

        DB::flushQueryLog();
        DB::enableQueryLog();
        $response = $this->getJson('/api/v1/public/trainers')->assertOk();
        $ratingQueries = collect(DB::getQueryLog())
            ->filter(fn (array $query) => str_contains(strtolower($query['query']), 'trainer_ratings'));
        DB::disableQueryLog();

        $this->assertCount(2, $ratingQueries);
        $rows = collect($response->json('data'))->keyBy('id');

        $this->assertSame(0, $rows[$unrated->id]['reviews_count']);
        $this->assertSame(0, $rows[$unrated->id]['rating']);
        $this->assertSame('pro', $rows[$unrated->id]['tier']);
        $this->assertSame('Pro', $rows[$unrated->id]['badge']);
        $this->assertSame(1, $rows[$five->id]['reviews_count']);
        $this->assertEquals(5.0, $rows[$five->id]['rating']);
        $this->assertSame('pro', $rows[$five->id]['tier']);
        $this->assertSame('Pro', $rows[$five->id]['badge']);
        $this->assertSame(2, $rows[$fourPointFive->id]['reviews_count']);
        $this->assertEquals(4.5, $rows[$fourPointFive->id]['rating']);
        $this->assertSame(3, $rows[$fourPointSixSeven->id]['reviews_count']);
        $this->assertEquals(4.67, $rows[$fourPointSixSeven->id]['rating']);

        $fixtureOrder = collect($response->json('data'))
            ->whereIn('id', [$unrated->id, $five->id, $fourPointFive->id, $fourPointSixSeven->id])
            ->pluck('id')
            ->all();
        $this->assertSame([
            $five->id,
            $fourPointSixSeven->id,
            $fourPointFive->id,
            $unrated->id,
        ], $fixtureOrder);

        $this->getJson("/api/v1/public/trainers/{$fourPointFive->id}/ratings")
            ->assertOk()
            ->assertJsonPath('data.average_rating', 4.5)
            ->assertJsonPath('data.reviews_count', 2)
            ->assertJsonCount(2, 'data.reviews');

        $this->getJson("/api/v1/public/trainers/{$unrated->id}/ratings")
            ->assertOk()
            ->assertJsonPath('data.average_rating', 0)
            ->assertJsonPath('data.reviews_count', 0)
            ->assertJsonCount(0, 'data.reviews');

        Sanctum::actingAs($fourPointSixSeven->user, [], 'sanctum');
        $this->getJson('/api/v1/trainer/dashboard')
            ->assertOk()
            ->assertJsonPath('data.rating', 4.67)
            ->assertJsonPath('data.reviews_count', 3);
        $this->getJson('/api/v1/trainer/profile')
            ->assertOk()
            ->assertJsonPath('data.rating', 4.67)
            ->assertJsonPath('data.reviews_count', 3);
    }

    public function test_rating_submit_immediately_updates_public_aggregate_without_writing_profile_cache(): void
    {
        $trainer = $this->trainer('Submit Aggregate Trainer', 1);
        $member = $this->member('Submit Rating Member');
        $program = TrainingProgram::create([
            'trainer_profile_id' => $trainer->id,
            'member_profile_id' => $member->id,
            'title' => 'Completed rating program',
            'status' => 'active',
        ]);
        TrainingProgramSession::create([
            'training_program_id' => $program->id,
            'sequence_order' => 1,
            'title' => 'Completed session',
            'duration_minutes' => 60,
            'status' => 'completed',
        ]);

        // "Nanti Saja" is a frontend-only dismissal: without a POST there is no row.
        $this->assertSame(0, TrainerRating::query()->where('trainer_profile_id', $trainer->id)->count());
        $before = collect($this->getJson('/api/v1/public/trainers')->assertOk()->json('data'))
            ->firstWhere('id', $trainer->id);
        $this->assertSame(0, $before['rating']);
        $this->assertSame(0, $before['reviews_count']);
        $this->assertSame('pro', $before['tier']);
        $this->assertSame('Pro', $before['badge']);

        Sanctum::actingAs($member->user, [], 'sanctum');
        $this->postJson('/api/v1/member/ratings', [
            'training_program_id' => $program->id,
            'rating' => 5,
        ])
            ->assertCreated()
            ->assertJsonPath('data.average_rating', 5)
            ->assertJsonPath('data.reviews_count', 1);

        $this->assertSame('1.00', $trainer->fresh()->rating);
        $after = collect($this->getJson('/api/v1/public/trainers')->assertOk()->json('data'))
            ->firstWhere('id', $trainer->id);
        $this->assertEquals(5.0, $after['rating']);
        $this->assertSame(1, $after['reviews_count']);
        $this->assertSame('pro', $after['tier']);
        $this->assertSame('Pro', $after['badge']);

        $this->getJson("/api/v1/public/trainers/{$trainer->id}/ratings")
            ->assertOk()
            ->assertJsonPath('data.average_rating', 5)
            ->assertJsonPath('data.reviews_count', 1)
            ->assertJsonCount(1, 'data.reviews');
    }

    private function trainer(string $name, float $cachedRating): TrainerProfile
    {
        $role = Role::firstOrCreate(['name' => 'trainer']);
        $user = User::create([
            'role_id' => $role->id,
            'name' => $name,
            'email' => uniqid('rating_trainer_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);

        return TrainerProfile::create([
            'user_id' => $user->id,
            'specialty' => 'Strength Training',
            'specialties' => ['Strength Training'],
            'tier' => 'pro',
            'rating' => $cachedRating,
        ]);
    }

    private function member(string $name): MemberProfile
    {
        $role = Role::firstOrCreate(['name' => 'member']);
        $user = User::create([
            'role_id' => $role->id,
            'name' => $name,
            'email' => uniqid('rating_member_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);

        return MemberProfile::create([
            'user_id' => $user->id,
            'member_code' => strtoupper(uniqid('RATE-')),
        ]);
    }

    private function rate(TrainerProfile $trainer, int $rating, ?string $testimonial = null): TrainerRating
    {
        return TrainerRating::create([
            'member_profile_id' => $this->member('Rating Author')->id,
            'trainer_profile_id' => $trainer->id,
            'rating' => $rating,
            'testimonial' => $testimonial,
        ]);
    }
}

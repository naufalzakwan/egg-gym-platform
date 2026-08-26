<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerRating;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminTrainerRatingPresentationTest extends TestCase
{
    use DatabaseTransactions;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = $this->user('admin', 'Rating Presentation Admin');
    }

    public function test_admin_index_and_detail_show_live_rating_counts_and_explicit_unrated_state(): void
    {
        $unrated = $this->trainer('Admin Cached Five Unrated', 5);
        $rated = $this->trainer('Admin Live Rated', 1);
        $this->rate($rated, 5);
        $this->rate($rated, 5);
        $this->rate($rated, 4);

        $response = $this->adminGet(route('admin.trainer-profiles.index'))->assertOk();
        $coaches = $response->viewData('featured')->concat($response->viewData('queue'))->keyBy('id');

        $this->assertNull($coaches[$unrated->id]['rating']);
        $this->assertSame(0, $coaches[$unrated->id]['reviews_count']);
        $this->assertEquals(4.67, $coaches[$rated->id]['rating']);
        $this->assertSame(3, $coaches[$rated->id]['reviews_count']);
        $response->assertSeeText('Belum ada rating')
            ->assertSeeText('0 ulasan')
            ->assertSeeText('4.7')
            ->assertSeeText('3 ulasan');

        $this->adminGet(route('admin.trainer-profiles.show', $unrated))
            ->assertOk()
            ->assertSeeText('Belum ada rating')
            ->assertSeeText('0 ulasan')
            ->assertDontSeeText('5.0 / 5');
        $this->adminGet(route('admin.trainer-profiles.show', $rated))
            ->assertOk()
            ->assertSeeText('4.7 / 5')
            ->assertSeeText('3 ulasan');
    }

    public function test_global_client_satisfaction_is_weighted_by_valid_reviews(): void
    {
        $oneReview = $this->trainer('Weighted One Review', 1);
        $threeReviews = $this->trainer('Weighted Three Reviews', 5);
        $this->rate($oneReview, 5);
        $this->rate($threeReviews, 1);
        $this->rate($threeReviews, 1);
        $this->rate($threeReviews, 1);
        $this->rate($threeReviews, 0);
        $this->rate($threeReviews, 6);

        $response = $this->adminGet(route('admin.trainer-profiles.index'))->assertOk();
        $expectedAverage = round((float) TrainerRating::query()->valid()->avg('rating'), 2);
        $expectedCount = TrainerRating::query()->valid()->count();

        $this->assertEquals($expectedAverage, $response->viewData('banner')['avg_satisfaction']);
        $this->assertSame($expectedCount, $response->viewData('banner')['reviews_count']);
        $response->assertSeeText(number_format($expectedAverage, 2).' / 5')
            ->assertSeeText($expectedCount.' ulasan');

        $fixtureRatings = TrainerRating::query()
            ->valid()
            ->whereIn('trainer_profile_id', [$oneReview->id, $threeReviews->id]);
        $this->assertSame(4, $fixtureRatings->count());
        $this->assertEquals(2.0, (float) $fixtureRatings->avg('rating'));
    }

    public function test_admin_create_has_no_rating_input_validation_or_persistence(): void
    {
        Role::firstOrCreate(['name' => 'trainer']);

        $this->adminGet(route('admin.trainer-profiles.create'))
            ->assertOk()
            ->assertDontSee('name="rating"', false)
            ->assertDontSeeText('Rating Awal');

        $email = uniqid('admin_no_rating_', true).'@example.test';
        $this->withSession(['admin_user_id' => $this->admin->id])
            ->post(route('admin.trainer-profiles.store'), [
                'name' => 'No Admin Rating Trainer',
                'email' => $email,
                'phone' => '081234567890',
                'password' => 'password123',
                'status' => 'active',
                'specialties' => ['Strength Training'],
                'rating' => 5,
            ])
            ->assertRedirect(route('admin.trainer-profiles.index'));

        $profile = User::query()->where('email', $email)->firstOrFail()->trainerProfile;
        $this->assertSame('0.00', $profile->rating);
        $this->assertSame(0, $profile->ratings()->count());
    }

    private function adminGet(string $url)
    {
        return $this->withSession(['admin_user_id' => $this->admin->id])->get($url);
    }

    private function user(string $roleName, string $name): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);

        return User::create([
            'role_id' => $role->id,
            'name' => $name,
            'email' => uniqid('admin_rating_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
    }

    private function trainer(string $name, float $cachedRating): TrainerProfile
    {
        return TrainerProfile::create([
            'user_id' => $this->user('trainer', $name)->id,
            'specialty' => 'Strength Training',
            'specialties' => ['Strength Training'],
            'rating' => $cachedRating,
        ]);
    }

    private function rate(TrainerProfile $trainer, int $rating): TrainerRating
    {
        $member = MemberProfile::create([
            'user_id' => $this->user('member', 'Admin Rating Member')->id,
            'member_code' => strtoupper(uniqid('ADMIN-RATE-')),
        ]);

        return TrainerRating::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $trainer->id,
            'rating' => $rating,
        ]);
    }
}

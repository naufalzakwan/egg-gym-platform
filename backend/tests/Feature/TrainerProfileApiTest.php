<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrainerProfileApiTest extends TestCase
{
    use DatabaseTransactions;

    private User $trainerUser;

    private TrainerProfile $trainerProfile;

    protected function setUp(): void
    {
        parent::setUp();

        $role = Role::firstOrCreate(['name' => 'trainer']);
        $this->trainerUser = User::create([
            'role_id' => $role->id,
            'name' => 'Trainer Account',
            'email' => uniqid('trainer_profile_', true).'@example.test',
            'phone' => '081111111111',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $this->trainerProfile = TrainerProfile::create([
            'user_id' => $this->trainerUser->id,
            'specialty' => 'Strength',
            'tier' => 'pro',
            'rating' => 4.8,
            'max_clients' => 30,
        ]);

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
    }

    public function test_trainer_can_update_identity_professional_and_payment_fields(): void
    {
        $response = $this->putJson('/api/v1/trainer/profile', [
            'name' => 'Updated Trainer',
            'email' => uniqid('updated_trainer_', true).'@example.test',
            'phone' => '082222222222',
            'specialties' => ['Bodybuilding', 'Weight Loss', 'Powerlifting'],
            'bio' => 'Bio terbaru.',
            'experience_years' => 6,
            'certifications' => 'Certified Coach',
            'availability_note' => 'Hubungi sebelum sesi.',
            'bank_name' => 'BCA',
            'bank_account_number' => '1234567890',
            'bank_account_name' => 'Updated Trainer',
            'dana_number' => '082222222222',
            'dana_account_name' => 'DANA Trainer',
            'other_payment_method' => 'GoPay',
            'other_payment_number' => '083333333333',
            'other_payment_account_name' => 'GoPay Trainer',
            'price_per_session' => 175000,
        ])->assertOk();

        $response->assertJsonPath('data.name', 'Updated Trainer')
            ->assertJsonPath('data.phone', '082222222222')
            ->assertJsonPath('data.specialty', 'Bodybuilding')
            ->assertJsonPath('data.specialty_label', 'Bodybuilding')
            ->assertJsonPath('data.specialty_slug', 'bodybuilding')
            ->assertJsonPath('data.specialties.0', 'Bodybuilding')
            ->assertJsonPath('data.specialties.1', 'Weight Loss')
            ->assertJsonPath('data.specialties.2', 'Powerlifting')
            ->assertJsonPath('data.tier', 'pro')
            ->assertJsonPath('data.status', 'active');

        $this->assertDatabaseHas('users', [
            'id' => $this->trainerUser->id,
            'name' => 'Updated Trainer',
            'phone' => '082222222222',
            'status' => 'active',
        ]);
        $this->assertDatabaseHas('trainer_profiles', [
            'id' => $this->trainerProfile->id,
            'specialty' => 'Bodybuilding',
            'tier' => 'pro',
            'max_clients' => 30,
        ]);
        $this->assertSame(
            ['Bodybuilding', 'Weight Loss', 'Powerlifting'],
            $this->trainerProfile->fresh()->specialties
        );

        $this->getJson('/api/v1/trainer/profile')
            ->assertOk()
            ->assertJsonPath('data.name', 'Updated Trainer')
            ->assertJsonPath('data.phone', '082222222222')
            ->assertJsonPath('data.specialty', 'Bodybuilding')
            ->assertJsonPath('data.specialty_label', 'Bodybuilding')
            ->assertJsonCount(3, 'data.specialties')
            ->assertJsonPath('data.bio', 'Bio terbaru.')
            ->assertJsonPath('data.experience_years', 6)
            ->assertJsonPath('data.certifications', 'Certified Coach')
            ->assertJsonPath('data.certifications_list.0', 'Certified Coach')
            ->assertJsonPath('data.availability_note', 'Hubungi sebelum sesi.')
            ->assertJsonPath('data.bank_name', 'BCA')
            ->assertJsonPath('data.bank_account_number', '1234567890')
            ->assertJsonPath('data.bank_account_name', 'Updated Trainer')
            ->assertJsonPath('data.dana_number', '082222222222')
            ->assertJsonPath('data.dana_account_name', 'DANA Trainer')
            ->assertJsonPath('data.other_payment_method', 'GoPay')
            ->assertJsonPath('data.other_payment_number', '083333333333')
            ->assertJsonPath('data.other_payment_account_name', 'GoPay Trainer')
            ->assertJsonPath('data.price_per_session', 175000);
    }

    public function test_certifications_accept_repeatable_array_and_normalize_empty_duplicates(): void
    {
        $this->putJson('/api/v1/trainer/profile', [
            'certifications' => [
                ' NASM CPT ',
                '',
                'Sports Nutrition Coach',
                'nasm cpt',
            ],
            'bio' => null,
            'experience_years' => null,
            'availability_note' => null,
        ])->assertOk()
            ->assertJsonPath('data.certifications', 'NASM CPT, Sports Nutrition Coach')
            ->assertJsonPath('data.certifications_list.0', 'NASM CPT')
            ->assertJsonPath('data.certifications_list.1', 'Sports Nutrition Coach')
            ->assertJsonCount(2, 'data.certifications_list')
            ->assertJsonPath('data.bio', null)
            ->assertJsonPath('data.experience_years', null)
            ->assertJsonPath('data.availability_note', null);

        $profile = $this->trainerProfile->fresh();
        $this->assertSame('NASM CPT, Sports Nutrition Coach', $profile->certifications);
        $this->assertSame(['NASM CPT', 'Sports Nutrition Coach'], $profile->certification_list);

        $this->putJson('/api/v1/trainer/profile', [
            'certifications' => [],
        ])->assertOk()
            ->assertJsonPath('data.certifications', null)
            ->assertJsonCount(0, 'data.certifications_list');
    }

    public function test_certifications_reject_more_than_twenty_items(): void
    {
        $this->putJson('/api/v1/trainer/profile', [
            'certifications' => collect(range(1, 21))
                ->map(fn ($index) => "Certification {$index}")
                ->all(),
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('certifications');

        $this->assertNull($this->trainerProfile->fresh()->certifications);
    }

    public function test_email_must_be_unique_except_for_current_user(): void
    {
        $other = User::factory()->create();

        $this->putJson('/api/v1/trainer/profile', [
            'email' => $other->email,
        ])->assertUnprocessable()->assertJsonValidationErrors('email');

        $this->putJson('/api/v1/trainer/profile', [
            'email' => $this->trainerUser->email,
        ])->assertOk();
    }

    public function test_display_photo_upload_replace_delete_is_separate_from_avatar(): void
    {
        Storage::fake('public');
        $this->trainerUser->update(['avatar_url' => 'avatars/account-avatar.jpg']);

        $firstResponse = $this->postJson('/api/v1/trainer/profile/display-photo', [
            'display_photo' => UploadedFile::fake()->image('trainer-one.jpg', 800, 1000),
        ])->assertOk();
        $firstPath = $firstResponse->json('data.display_photo_path');

        $this->assertStringStartsWith('trainer-display-photos/', $firstPath);
        Storage::disk('public')->assertExists($firstPath);
        $this->assertSame($firstPath, $this->trainerProfile->fresh()->display_photo_path);
        $this->assertSame('avatars/account-avatar.jpg', $this->trainerUser->fresh()->avatar_url);
        $this->getJson('/api/v1/trainer/profile')
            ->assertOk()
            ->assertJsonPath('data.display_photo_path', $firstPath);

        $publicPayload = collect($this->getJson('/api/v1/public/trainers')
            ->assertOk()
            ->json('data'))->firstWhere('id', $this->trainerProfile->id);
        $this->assertSame($firstPath, $publicPayload['display_photo_path'] ?? null);
        $this->assertSame('avatars/account-avatar.jpg', $publicPayload['avatar_url'] ?? null);

        $secondResponse = $this->postJson('/api/v1/trainer/profile/display-photo', [
            'display_photo' => UploadedFile::fake()->image('trainer-two.png', 800, 1000),
        ])->assertOk();
        $secondPath = $secondResponse->json('data.display_photo_path');
        $this->assertNotSame($firstPath, $secondPath);
        Storage::disk('public')->assertMissing($firstPath);
        Storage::disk('public')->assertExists($secondPath);

        $this->deleteJson('/api/v1/trainer/profile/display-photo')
            ->assertOk()
            ->assertJsonPath('data.display_photo_path', null);
        Storage::disk('public')->assertMissing($secondPath);
        $this->assertNull($this->trainerProfile->fresh()->display_photo_path);
        $this->assertSame('avatars/account-avatar.jpg', $this->trainerUser->fresh()->avatar_url);
    }

    public function test_specialty_rejects_unknown_new_value_but_preserves_existing_legacy_value(): void
    {
        $this->putJson('/api/v1/trainer/profile', [
            'specialty' => 'Custom Specialty',
        ])->assertUnprocessable()->assertJsonValidationErrors('specialty');

        $this->trainerProfile->update(['specialty' => 'Yoga - Flexibility']);

        $this->putJson('/api/v1/trainer/profile', [
            'specialty' => 'Yoga - Flexibility',
            'bio' => 'Legacy profile tetap dapat diperbarui.',
        ])->assertOk()
            ->assertJsonPath('data.specialty', 'Yoga - Flexibility')
            ->assertJsonPath('data.specialty_label', 'Yoga')
            ->assertJsonPath('data.specialty_slug', 'yoga')
            ->assertJsonPath('data.specialties.0', 'Yoga - Flexibility')
            ->assertJsonPath('data.specialty_labels.0', 'Yoga');

        $this->assertSame('Yoga - Flexibility', $this->trainerProfile->fresh()->specialty);
    }

    public function test_specialties_require_at_least_one_canonical_value_and_sync_primary(): void
    {
        $this->putJson('/api/v1/trainer/profile', [
            'specialties' => [],
        ])->assertUnprocessable()->assertJsonValidationErrors('specialties');

        $this->putJson('/api/v1/trainer/profile', [
            'specialties' => ['Bodybuilding', 'Custom Specialty'],
        ])->assertUnprocessable()->assertJsonValidationErrors('specialties.1');

        $this->putJson('/api/v1/trainer/profile', [
            'specialties' => ['Yoga', 'Mobility & Flexibility'],
        ])->assertOk()
            ->assertJsonPath('data.specialty', 'Yoga')
            ->assertJsonPath('data.specialties.0', 'Yoga')
            ->assertJsonPath('data.specialties.1', 'Mobility & Flexibility');

        $profile = $this->trainerProfile->fresh();
        $this->assertSame('Yoga', $profile->specialty);
        $this->assertSame(['Yoga', 'Mobility & Flexibility'], $profile->specialties);
    }

    public function test_other_payment_fields_must_be_complete_when_used(): void
    {
        $this->putJson('/api/v1/trainer/profile', [
            'other_payment_method' => 'OVO',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors([
                'other_payment_number',
                'other_payment_account_name',
            ]);

        $this->assertNull($this->trainerProfile->fresh()->other_payment_method);
    }

    public function test_password_change_requires_matching_current_password_and_confirmation(): void
    {
        $oldHash = $this->trainerUser->password;

        $this->putJson('/api/v1/trainer/profile', [
            'current_password' => 'wrong-password',
            'new_password' => 'New-password@123',
            'new_password_confirmation' => 'New-password@123',
        ])->assertUnprocessable()->assertJsonValidationErrors('current_password');
        $this->assertSame($oldHash, $this->trainerUser->fresh()->password);

        $this->putJson('/api/v1/trainer/profile', [
            'current_password' => 'password123',
            'new_password' => 'New-password@123',
            'new_password_confirmation' => 'different-password',
        ])->assertUnprocessable()->assertJsonValidationErrors('new_password');

        $this->putJson('/api/v1/trainer/profile', [
            'current_password' => 'password123',
            'new_password' => 'New-password@123',
            'new_password_confirmation' => 'New-password@123',
        ])->assertOk();
        $this->assertTrue(Hash::check('New-password@123', $this->trainerUser->fresh()->password));
    }

    public function test_blank_password_does_not_change_hash_and_admin_fields_are_ignored(): void
    {
        $oldHash = $this->trainerUser->password;

        $this->putJson('/api/v1/trainer/profile', [
            'bio' => 'Only bio changes.',
            'current_password' => '',
            'new_password' => '',
            'new_password_confirmation' => '',
            'tier' => 'elite',
            'status' => 'inactive',
            'rating' => 1,
            'max_clients' => 1,
            'avatar_url' => 'manual/avatar.jpg',
        ])->assertOk();

        $user = $this->trainerUser->fresh();
        $profile = $this->trainerProfile->fresh();
        $this->assertSame($oldHash, $user->password);
        $this->assertSame('active', $user->status);
        $this->assertNull($user->avatar_url);
        $this->assertSame('pro', $profile->tier);
        $this->assertSame(4.8, (float) $profile->rating);
        $this->assertSame(30, $profile->max_clients);
    }
}

<?php

namespace Tests\Feature;

use App\Models\GymSetting;
use App\Models\MembershipPaymentMethod;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AdminGeneralSettingsTest extends TestCase
{
    use DatabaseTransactions;

    protected function tearDown(): void
    {
        Cache::flush();
        parent::tearDown();
    }

    public function test_owner_can_update_location_and_public_endpoint_refreshes_without_secrets(): void
    {
        $owner = $this->createAdmin(true);
        GymSetting::current()->update(['city' => null]);
        Cache::flush();
        $this->getJson('/api/v1/public/settings')->assertOk()->assertJsonPath('data.gym.city', null);

        $this->withSession(['admin_user_id' => $owner->id])
            ->put(route('admin.settings.identity.update'), [
                'gym_name' => 'Egg Gym Pontianak',
                'tagline' => 'Lebih Kuat Setiap Hari',
                'address' => 'Jl. Merdeka No. 10',
                'city' => 'Pontianak',
                'province' => 'Kalimantan Barat',
                'postal_code' => '78111',
                'maps_url' => 'https://maps.google.com/?q=Pontianak',
                'latitude' => -0.0263,
                'longitude' => 109.3425,
            ])->assertRedirect()->assertSessionHas('success');

        $response = $this->getJson('/api/v1/public/settings')->assertOk()
            ->assertJsonPath('data.gym.name', 'Egg Gym Pontianak')
            ->assertJsonPath('data.gym.city', 'Pontianak')
            ->assertJsonPath('data.gym.latitude', -0.0263)
            ->assertJsonMissingPath('data.api_key')
            ->assertJsonMissingPath('data.secret')
            ->assertJsonMissingPath('data.admin');
        $this->assertStringNotContainsString((string) config('services.pakasir.api_key'), $response->getContent());
    }

    public function test_regular_admin_can_view_but_cannot_mutate_sensitive_settings_or_hours(): void
    {
        $admin = $this->createAdmin(false);

        $this->withSession(['admin_user_id' => $admin->id])->get(route('admin.settings.index'))
            ->assertOk()->assertSee('Identitas & Lokasi Gym', false)->assertDontSee('Simpan Lokasi');
        $this->withSession(['admin_user_id' => $admin->id])
            ->put(route('admin.settings.contact.update'), [])->assertForbidden();

        $hour = \App\Models\GymOperationHour::query()->firstOrFail();
        $this->withSession(['admin_user_id' => $admin->id])
            ->put(route('admin.operation-hours.update', $hour), [])->assertForbidden();
    }

    public function test_logo_upload_validation_storage_replacement_and_fallback_are_safe(): void
    {
        Storage::fake('public');
        $owner = $this->createAdmin(true);

        $this->withSession(['admin_user_id' => $owner->id])
            ->put(route('admin.settings.branding.update'), [
                'brand_name' => 'EGGGYM',
                'tagline' => 'Train Better',
                'logo' => UploadedFile::fake()->image('logo.webp', 400, 400)->size(500),
            ])->assertRedirect()->assertSessionHas('success');

        $settings = GymSetting::current()->fresh();
        $this->assertNotNull($settings->logo_path);
        Storage::disk('public')->assertExists($settings->logo_path);
        $firstPath = $settings->logo_path;

        $this->withSession(['admin_user_id' => $owner->id])
            ->put(route('admin.settings.branding.update'), [
                'brand_name' => 'EGGGYM',
                'logo' => UploadedFile::fake()->create('script.txt', 10, 'text/plain'),
            ])->assertSessionHasErrors('logo');
        Storage::disk('public')->assertExists($firstPath);

        $this->withSession(['admin_user_id' => $owner->id])
            ->put(route('admin.settings.branding.update'), [
                'brand_name' => 'EGGGYM',
                'logo' => UploadedFile::fake()->image('huge.jpg')->size(4100),
            ])->assertSessionHasErrors('logo');

        $this->withSession(['admin_user_id' => $owner->id])
            ->delete(route('admin.settings.branding.logo.destroy'))->assertRedirect();
        Storage::disk('public')->assertMissing($firstPath);
        $this->assertNull(GymSetting::current()->fresh()->logo_path);
        $this->getJson('/api/v1/public/settings')->assertOk()->assertJsonPath('data.gym.logo_url', null);
    }

    public function test_owner_can_only_update_provider_capabilities_and_public_order(): void
    {
        $owner = $this->createAdmin(true);
        $methods = MembershipPaymentMethod::query()->orderBy('id')->get();
        $payload = $methods->map(fn ($method, $index) => [
            'id' => $method->id,
            'display_name' => $method->provider_code === 'bri_va' ? 'BRI Pilihan Utama' : $method->display_name,
            'display_order' => $method->provider_code === 'bri_va' ? 1 : 100 + $index,
            'is_active' => $method->provider_code === 'bri_va' ? 1 : 0,
        ])->all();

        $this->withSession(['admin_user_id' => $owner->id])
            ->put(route('admin.settings.payment-methods.update'), ['methods' => $payload])
            ->assertRedirect()->assertSessionHas('success');

        $this->getJson('/api/v1/public/settings')->assertOk()
            ->assertJsonCount(1, 'data.membership_payment_methods')
            ->assertJsonPath('data.membership_payment_methods.0.code', 'bri_va')
            ->assertJsonPath('data.membership_payment_methods.0.label', 'BRI Pilihan Utama');
    }

    private function createAdmin(bool $owner): User
    {
        $role = Role::firstOrCreate(['name' => 'admin']);

        return User::create([
            'role_id' => $role->id,
            'name' => $owner ? 'Settings Owner' : 'Settings Staff',
            'email' => uniqid('settings_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
            'is_admin_owner' => $owner,
        ]);
    }
}

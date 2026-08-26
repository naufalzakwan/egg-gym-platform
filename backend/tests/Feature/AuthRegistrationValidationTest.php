<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthRegistrationValidationTest extends TestCase
{
    use DatabaseTransactions;

    protected function setUp(): void
    {
        parent::setUp();
        Role::query()->firstOrCreate(['name' => 'member']);
    }

    public function test_new_registration_accepts_valid_names_phones_and_strong_passwords(): void
    {
        $this->postJson('/api/v1/auth/register', $this->validPayload())
            ->assertCreated()
            ->assertJsonPath('data.user.name', 'Naufal Zakwan');

        $this->postJson('/api/v1/auth/register', $this->validPayload([
            'name' => 'Elena Rodriguez',
            'email' => 'elena.new@example.com',
            'phone' => '6281234567890',
            'password' => 'Member!123A',
            'password_confirmation' => 'Member!123A',
        ]))->assertCreated();
    }

    /**
     * @dataProvider invalidRegistrationProvider
     */
    public function test_new_registration_rejects_invalid_identity_and_password(
        string $field,
        mixed $value,
        string $errorKey,
        string $expectedMessage
    ): void {
        $before = User::query()->count();
        $payload = $this->validPayload([
            'email' => uniqid('invalid_register_', true).'@example.com',
            $field => $value,
        ]);
        if ($field === 'password') {
            $payload['password_confirmation'] = $value;
        }
        if ($field === 'password_confirmation') {
            $payload['password'] = 'EggGym@123';
        }

        $this->postJson('/api/v1/auth/register', $payload)
            ->assertUnprocessable()
            ->assertJsonValidationErrors($errorKey)
            ->assertJsonFragment([$expectedMessage]);
        $this->assertSame($before, User::query()->count());
    }

    public static function invalidRegistrationProvider(): array
    {
        $nameMessage = 'Nama hanya boleh huruf dan spasi.';
        $phoneMessage = 'Nomor HP 10–15 digit, awali 08/628.';
        $passwordMessage = 'Password harus 8+ karakter, Aa, angka & simbol.';

        return [
            'name contains numbers' => ['name', 'dsds123', 'name', $nameMessage],
            'name contains symbols' => ['name', 'Naufal!!!', 'name', $nameMessage],
            'phone too short' => ['phone', '08123', 'phone', $phoneMessage],
            'phone too long' => ['phone', '0812345678901234', 'phone', $phoneMessage],
            'phone contains letters' => ['phone', '08abc12345', 'phone', $phoneMessage],
            'phone wrong prefix' => ['phone', '071234567890', 'phone', $phoneMessage],
            'password no uppercase' => ['password', 'password@1', 'password', $passwordMessage],
            'password no lowercase' => ['password', 'PASSWORD@1', 'password', $passwordMessage],
            'password no number' => ['password', 'Password@x', 'password', $passwordMessage],
            'password no symbol' => ['password', 'Password1', 'password', $passwordMessage],
            'password too short' => ['password', 'Pa@1abc', 'password', $passwordMessage],
            'confirmation differs' => [
                'password_confirmation',
                'EggGym@124',
                'password',
                'Konfirmasi password tidak sama.',
            ],
        ];
    }

    public function test_existing_legacy_password_and_identity_can_still_login(): void
    {
        $role = Role::query()->where('name', 'member')->firstOrFail();
        $legacy = User::query()->create([
            'role_id' => $role->id,
            'name' => 'Legacy Member 01',
            'email' => 'legacy@example.com',
            'phone' => '+62-812',
            'password' => Hash::make('password'),
            'status' => 'active',
        ]);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'legacy@example.com',
            'password' => 'password',
        ])->assertOk()
            ->assertJsonPath('data.user.email', 'legacy@example.com');

        $this->assertSame('Legacy Member 01', $legacy->fresh()->name);
        $this->assertSame('+62-812', $legacy->fresh()->phone);
        $this->assertTrue(Hash::check('password', $legacy->fresh()->password));
    }

    private function validPayload(array $overrides = []): array
    {
        return array_replace([
            'name' => 'Naufal Zakwan',
            'email' => 'member@example.com',
            'phone' => '081234567890',
            'password' => 'EggGym@123',
            'password_confirmation' => 'EggGym@123',
        ], $overrides);
    }
}

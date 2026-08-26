<?php

namespace Tests\Feature;

use App\Models\ActivityLog;
use App\Models\Booking;
use App\Models\Equipment;
use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\Transaction;
use App\Models\User;
use App\Services\ActivityLogger;
use App\Support\AuditTrailFormatter;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use PhpOffice\PhpSpreadsheet\Cell\DataType;
use PhpOffice\PhpSpreadsheet\IOFactory;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use Tests\TestCase;

class AdminAuditTrailScopeTest extends TestCase
{
    use DatabaseTransactions;

    private User $admin;

    private MemberProfile $member;

    private MembershipPlan $plan;

    protected function setUp(): void
    {
        parent::setUp();
        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $this->admin = $this->createUser($adminRole, 'Audit Admin', 'audit.admin@example.test');
        $memberUser = $this->createUser($memberRole, 'Audit Member', 'audit.member@example.test');
        $this->member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => 'AUDIT-MEMBER',
            'joined_at' => now(),
        ]);
        $this->plan = MembershipPlan::create([
            'name' => 'Audit Membership Plan',
            'slug' => 'audit-plan-'.uniqid(),
            'description' => 'Audit fixture',
            'price' => 299000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['Gym access'],
            'is_active' => true,
        ]);
    }

    public function test_main_page_only_includes_four_approved_scopes_with_five_row_pagination(): void
    {
        foreach (range(1, 2) as $index) {
            $this->log('admin_login', null, $this->admin->id, "SCOPE-FINAL approved admin login {$index}");
        }
        $this->log('admin_account_updated', User::class, $this->admin->id, 'SCOPE-FINAL approved admin account');
        $transaction = $this->createTransaction('AUDIT-TRX-001');
        $this->log('transaction_created', Transaction::class, $transaction->id, 'SCOPE-FINAL approved finance');
        $membership = $this->createMembership();
        $this->log('membership_created', MemberMembership::class, $membership->id, 'SCOPE-FINAL approved membership');
        $trainer = $this->createTrainer();
        $this->log('updated', TrainerProfile::class, $trainer->id, 'SCOPE-FINAL approved trainer');

        $equipment = Equipment::create([
            'code' => 'EQ-AUD', 'name' => 'Excluded Equipment', 'slug' => 'excluded-equipment',
            'category' => 'Machine', 'description' => 'Excluded', 'status' => 'available',
            'focus' => 'Excluded', 'is_active' => true,
        ]);
        $this->log('updated', Equipment::class, $equipment->id, 'SCOPE-FINAL EXCLUDED EQUIPMENT LOG');
        $this->log('updated', Booking::class, 999999, 'SCOPE-FINAL EXCLUDED BOOKING LOG');
        $ptTransaction = Transaction::create([
            'member_profile_id' => $this->member->id,
            'membership_plan_id' => null,
            'reference_code' => 'SCOPE-FINAL-PT-TRANSACTION',
            'title' => 'PT payment',
            'payment_method' => 'transfer',
            'amount' => 500000,
            'status' => 'completed',
            'paid_at' => now(),
        ]);
        $this->log('transaction_created', Transaction::class, $ptTransaction->id, 'SCOPE-FINAL EXCLUDED PT PAYMENT');
        $this->log('login', null, $this->member->user_id, 'SCOPE-FINAL EXCLUDED MEMBER LOGIN');
        $this->log('export_audit', null, $this->admin->id, 'SCOPE-FINAL EXCLUDED VIEW EXPORT');

        $response = $this->adminGet(route('admin.audit-trail.index', ['search' => 'SCOPE-FINAL']));
        $response->assertOk()
            ->assertViewHas('logs', fn ($logs) => $logs->perPage() === 5
                && $logs->total() === 6
                && $logs->count() === 5)
            ->assertSeeText('ARSIP AKTIVITAS')
            ->assertSeeText('Autentikasi Admin')
            ->assertSeeText('Akun Admin')
            ->assertSeeText('Keuangan')
            ->assertSeeText('Keanggotaan')
            ->assertSeeText('Personal Trainer')
            ->assertSeeText('Export Excel')
            ->assertSee('Menampilkan 1&ndash;5 dari 6 aktivitas', false)
            ->assertDontSeeText('EXCLUDED EQUIPMENT LOG')
            ->assertDontSeeText('EXCLUDED BOOKING LOG')
            ->assertDontSeeText('EXCLUDED PT PAYMENT')
            ->assertDontSeeText('EXCLUDED MEMBER LOGIN')
            ->assertDontSeeText('EXCLUDED VIEW EXPORT')
            ->assertDontSeeText('Editorial Athletics')
            ->assertDontSeeText('Activity Archive');

        $export = $this->withSession(['admin_user_id' => $this->admin->id])
            ->get(route('admin.audit-trail.export', ['search' => 'SCOPE-FINAL']));
        $workbook = $this->loadWorkbook($export->streamedContent());
        $this->assertSame(7, $workbook->getSheetByName('Audit Trail')->getHighestDataRow());
        $this->assertSame(6, $workbook->getSheetByName('Ringkasan')->getCell('B7')->getValue());
        $workbook->disconnectWorksheets();
    }

    public function test_category_actor_date_search_target_and_safe_change_details_work_together(): void
    {
        $transaction = $this->createTransaction('SEARCH-TRX-991');
        $log = $this->log(
            'transaction_status_changed',
            Transaction::class,
            $transaction->id,
            'Pembayaran Audit Member berhasil diperbarui',
            [
                'reference_code' => $transaction->reference_code,
                'status' => 'pending',
                'password' => 'never-show-this',
                'provider_payload' => ['secret' => 'never-show-provider'],
                'bank_account_name' => 'never-show-bank',
            ],
            [
                'reference_code' => $transaction->reference_code,
                'status' => 'completed',
                'source' => 'Webhook Pakasir',
                'token' => 'never-show-token',
            ]
        );
        $log->update(['ip_address' => '203.0.113.55', 'user_agent' => 'Audit Scope Browser']);
        $this->log('updated', Equipment::class, 12345, 'SEARCH-TRX-991 excluded equipment');

        $response = $this->adminGet(route('admin.audit-trail.index', [
            'category' => 'finance',
            'actor' => 'admin',
            'date' => 'today',
            'search' => 'SEARCH-TRX-991',
        ]));
        $response->assertOk()
            ->assertViewHas('logs', fn ($logs) => $logs->total() === 1 && $logs->first()->id === $log->id)
            ->assertSeeText('Pembayaran Audit Member berhasil diperbarui')
            ->assertSeeText('SEARCH-TRX-991')
            ->assertSeeText('Audit Member')
            ->assertSeeText('Audit Membership Plan')
            ->assertSeeText('Webhook Pakasir')
            ->assertSeeText('Lihat Perubahan')
            ->assertSeeText('Status Pembayaran')
            ->assertSeeText('Pending')
            ->assertSeeText('Sukses')
            ->assertDontSeeText('IP 203.0.113.55')
            ->assertDontSeeText('Audit Scope Browser')
            ->assertDontSeeText('never-show-this')
            ->assertDontSeeText('never-show-provider')
            ->assertDontSeeText('never-show-bank')
            ->assertDontSeeText('never-show-token');
    }

    public function test_export_uses_same_scope_and_active_filters(): void
    {
        $trainer = $this->createTrainer();
        $this->log(
            'updated',
            TrainerProfile::class,
            $trainer->id,
            'EXPORT INCLUDED TRAINER',
            ['tier' => 'pro', 'max_clients' => 30, 'verification_status' => 'pending'],
            [
                'tier' => 'elite',
                'max_clients' => 40,
                'verification_status' => 'verified',
                'bio' => 'EXPORT SENSITIVE NOISE',
                'user' => ['password' => 'EXPORT SECRET'],
            ]
        );
        $this->log('updated', Equipment::class, 991, 'EXPORT EXCLUDED EQUIPMENT');
        $this->log('admin_login', null, $this->admin->id, 'EXPORT EXCLUDED LOGIN');

        $response = $this->withSession(['admin_user_id' => $this->admin->id])
            ->get(route('admin.audit-trail.export', [
                'category' => 'trainer',
                'actor' => 'admin',
                'date' => 'today',
                'search' => 'EXPORT',
            ]));
        $response->assertOk()
            ->assertHeader('content-type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
            ->assertHeader('content-disposition', 'attachment; filename=audit-trail-egggym-'.now()->format('Y-m-d-Hi').'.xlsx');
        $content = $response->streamedContent();
        $this->assertStringStartsWith('PK', $content);
        $workbook = $this->loadWorkbook($content);
        $this->assertSame(['Audit Trail', 'Ringkasan'], $workbook->getSheetNames());
        $this->assertSame('Audit Trail', $workbook->getActiveSheet()->getTitle());

        $summary = $workbook->getSheetByName('Ringkasan');
        $this->assertSame(DataType::TYPE_NUMERIC, $summary->getCell('B2')->getDataType());
        $this->assertSame('dd mmmm yyyy hh:mm:ss', $summary->getStyle('B2')->getNumberFormat()->getFormatCode());
        $this->assertSame(now()->locale('id')->translatedFormat('d F Y'), $summary->getCell('B3')->getValue());
        $this->assertSame('Personal Trainer', $summary->getCell('B4')->getValue());
        $this->assertSame('Admin', $summary->getCell('B5')->getValue());
        $this->assertSame('EXPORT', $summary->getCell('B6')->getValue());
        $this->assertSame(1, $summary->getCell('B7')->getValue());
        $this->assertSame(0, $summary->getCell('B8')->getValue());
        $this->assertSame(0, $summary->getCell('B9')->getValue());
        $this->assertSame(0, $summary->getCell('B10')->getValue());
        $this->assertSame(0, $summary->getCell('B11')->getValue());
        $this->assertSame(1, $summary->getCell('B12')->getValue());

        $sheet = $workbook->getSheetByName('Audit Trail');
        $this->assertSame([
            'Waktu', 'Pelaku', 'Role', 'Jenis Aktivitas', 'Aktivitas',
            'Objek Terdampak', 'Hasil', 'Sumber', 'Ringkasan Perubahan',
        ], $sheet->rangeToArray('A1:I1')[0]);
        $this->assertSame(DataType::TYPE_NUMERIC, $sheet->getCell('A2')->getDataType());
        $this->assertSame('dd mmmm yyyy hh:mm:ss', $sheet->getStyle('A2')->getNumberFormat()->getFormatCode());
        $this->assertSame('A2', $sheet->getFreezePane());
        $this->assertSame('A1:I2', $sheet->getAutoFilter()->getRange());
        $this->assertTrue($sheet->getStyle('I2')->getAlignment()->getWrapText());
        $this->assertSame('EXPORT INCLUDED TRAINER', $sheet->getCell('E2')->getValue());
        $this->assertSame('Personal Trainer', $sheet->getCell('D2')->getValue());
        $this->assertSame(
            "Tier: Pro → Elite\nKapasitas Klien Maksimal: 30 → 40\nStatus Verifikasi PT: Pending → Terverifikasi",
            $sheet->getCell('I2')->getValue()
        );
        $serialized = json_encode($sheet->toArray(), JSON_THROW_ON_ERROR);
        $this->assertStringNotContainsString('EXPORT EXCLUDED EQUIPMENT', $serialized);
        $this->assertStringNotContainsString('EXPORT EXCLUDED LOGIN', $serialized);
        $this->assertStringNotContainsString('EXPORT SENSITIVE NOISE', $serialized);
        $this->assertStringNotContainsString('EXPORT SECRET', $serialized);
        $this->assertStringNotContainsString('IP', json_encode($sheet->rangeToArray('A1:I1'), JSON_THROW_ON_ERROR));
        $this->assertStringNotContainsString('Browser/Perangkat', $serialized);
        $workbook->disconnectWorksheets();
    }

    public function test_updated_logger_and_legacy_renderer_only_expose_balanced_changed_trainer_fields(): void
    {
        $trainer = $this->createTrainer();
        $old = $trainer->only(['tier', 'max_clients', 'verification_status', 'admin_notes']);
        $trainer->update([
            'tier' => 'elite',
            'max_clients' => 40,
            'verification_status' => 'verified',
            'admin_notes' => 'Performa trainer baik',
        ]);
        $newLog = ActivityLogger::logUpdated($trainer, $old, 'Kontrol administratif trainer diperbarui');

        $this->assertSame(
            ['tier', 'max_clients', 'admin_notes'],
            array_keys($newLog->old_data)
        );
        $this->assertSame(array_keys($newLog->old_data), array_keys($newLog->new_data));
        $this->assertArrayNotHasKey('verification_status', $newLog->new_data);
        $this->assertArrayNotHasKey('updated_at', $newLog->new_data);
        $this->assertArrayNotHasKey('user', $newLog->new_data);

        $legacy = $this->log(
            'updated',
            TrainerProfile::class,
            $trainer->id,
            'Legacy trainer full model',
            [
                'tier' => 'pro',
                'max_clients' => 30,
                'verification_status' => 'pending',
                'admin_notes' => null,
            ],
            [
                'id' => $trainer->id,
                'tier' => 'elite',
                'max_clients' => 40,
                'verification_status' => 'verified',
                'admin_notes' => 'Performa trainer baik',
                'bio' => 'Tidak boleh tampil',
                'rating' => '4.50',
                'specialties' => ['Strength Training'],
                'created_at' => now()->toISOString(),
                'updated_at' => now()->toISOString(),
                'user' => ['email' => 'nested@example.test', 'role_id' => 3],
            ]
        );
        $details = AuditTrailFormatter::details($legacy);
        $this->assertSame('Lihat Perubahan', $details['title']);
        $this->assertSame(
            ['tier', 'max_clients', 'verification_status', 'admin_notes'],
            array_column($details['rows'], 'field')
        );
        $serialized = json_encode($details, JSON_THROW_ON_ERROR);
        $this->assertStringNotContainsString('bio', $serialized);
        $this->assertStringNotContainsString('rating', $serialized);
        $this->assertStringNotContainsString('specialties', $serialized);
        $this->assertStringNotContainsString('nested@example.test', $serialized);

        $response = $this->adminGet(route('admin.audit-trail.index', ['search' => 'Legacy trainer full model']));
        $response->assertOk()
            ->assertSeeText('Tier')
            ->assertSeeText('Pro')
            ->assertSeeText('Elite')
            ->assertSeeText('Kapasitas Klien Maksimal')
            ->assertSeeText('Status Verifikasi PT')
            ->assertSeeText('Terverifikasi')
            ->assertSeeText('Catatan Admin Internal')
            ->assertSeeText('Belum ada')
            ->assertDontSeeText('Tidak boleh tampil')
            ->assertDontSeeText('nested@example.test');
    }

    public function test_login_logout_have_no_change_detail(): void
    {
        $this->log('admin_login', User::class, $this->admin->id, 'NO-DETAIL login');
        $this->log('admin_logout', User::class, $this->admin->id, 'NO-DETAIL logout');

        $response = $this->adminGet(route('admin.audit-trail.index', [
            'category' => 'admin_auth',
            'search' => 'NO-DETAIL',
        ]));
        $response->assertOk()
            ->assertViewHas('logs', fn ($logs) => $logs->total() === 2)
            ->assertDontSeeText('Lihat Perubahan')
            ->assertDontSeeText('Lihat Data Dibuat')
            ->assertDontSeeText('Lihat Data Sebelumnya');
    }

    public function test_create_and_deactivate_details_use_whitelist_and_friendly_empty_boolean_values(): void
    {
        $created = $this->log(
            'admin_account_created',
            User::class,
            $this->admin->id,
            'DETAIL-MODE created',
            [],
            [
                'name' => 'Petugas Audit',
                'email' => 'petugas.audit@example.test',
                'status' => 'active',
                'is_admin_owner' => false,
                'password' => 'hidden',
                'created_at' => now()->toISOString(),
            ]
        );
        $createDetails = AuditTrailFormatter::details($created);
        $this->assertSame('Lihat Data Dibuat', $createDetails['title']);
        $this->assertSame(['name', 'email', 'status', 'is_admin_owner'], array_column($createDetails['rows'], 'field'));
        $this->assertSame('Tidak', collect($createDetails['rows'])->firstWhere('field', 'is_admin_owner')['new']);

        $deleted = $this->log(
            'admin_account_deactivated',
            User::class,
            $this->admin->id,
            'DETAIL-MODE deactivated',
            [
                'name' => 'Petugas Audit',
                'email' => 'petugas.audit@example.test',
                'status' => 'active',
                'is_admin_owner' => false,
            ],
            ['status' => 'inactive']
        );
        $deleteDetails = AuditTrailFormatter::details($deleted);
        $this->assertSame('Lihat Data Sebelumnya', $deleteDetails['title']);

        $legacyTrainer = $this->log(
            'updated',
            TrainerProfile::class,
            $this->createTrainer()->id,
            'DETAIL-MODE empty value',
            ['admin_notes' => null],
            ['admin_notes' => 'Catatan baru']
        );
        $emptyDetails = AuditTrailFormatter::details($legacyTrainer);
        $this->assertSame('Belum ada', $emptyDetails['rows'][0]['old']);
        $this->assertSame('Catatan baru', $emptyDetails['rows'][0]['new']);
    }

    private function log(
        string $action,
        ?string $modelType,
        ?int $modelId,
        string $description,
        array $oldData = [],
        array $newData = []
    ): ActivityLog {
        return ActivityLog::create([
            'user_id' => $this->admin->id,
            'action' => $action,
            'model_type' => $modelType,
            'model_id' => $modelId,
            'description' => $description,
            'old_data' => $oldData ?: null,
            'new_data' => $newData ?: null,
            'ip_address' => '127.0.0.1',
            'user_agent' => 'Audit Test Browser',
        ]);
    }

    private function createTransaction(string $reference): Transaction
    {
        return Transaction::create([
            'member_profile_id' => $this->member->id,
            'membership_plan_id' => $this->plan->id,
            'reference_code' => $reference,
            'title' => 'Audit payment',
            'payment_method' => 'qris',
            'amount' => 299000,
            'fee' => 5000,
            'total_payment' => 304000,
            'status' => 'completed',
            'paid_at' => now(),
        ]);
    }

    private function createMembership(): MemberMembership
    {
        return MemberMembership::create([
            'member_profile_id' => $this->member->id,
            'membership_plan_id' => $this->plan->id,
            'start_date' => now(),
            'end_date' => now()->addMonth(),
            'status' => 'active',
            'payment_status' => 'paid',
        ]);
    }

    private function createTrainer(): TrainerProfile
    {
        $role = Role::firstOrCreate(['name' => 'trainer']);
        $user = $this->createUser($role, 'Audit Trainer', 'audit.trainer@example.test');

        return TrainerProfile::create([
            'user_id' => $user->id,
            'specialty' => 'Strength Training',
            'tier' => 'pro',
            'max_clients' => 30,
            'verification_status' => 'verified',
            'rating' => 4.5,
        ]);
    }

    private function createUser(Role $role, string $name, string $email): User
    {
        return User::create([
            'role_id' => $role->id,
            'name' => $name,
            'email' => $email,
            'password' => 'password123',
            'status' => 'active',
        ]);
    }

    private function adminGet(string $url)
    {
        return $this->withSession(['admin_user_id' => $this->admin->id])->get($url);
    }

    private function loadWorkbook(string $content): Spreadsheet
    {
        $path = tempnam(sys_get_temp_dir(), 'egggym-audit-xlsx-');
        file_put_contents($path, $content);

        try {
            return IOFactory::load($path);
        } finally {
            unlink($path);
        }
    }
}

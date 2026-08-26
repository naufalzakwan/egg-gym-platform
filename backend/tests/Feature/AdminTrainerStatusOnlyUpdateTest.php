<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\BookingRescheduleRequest;
use App\Models\BookingSessionReservation;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerSchedule;
use App\Models\TrainerScheduleDate;
use App\Models\TrainerScheduleDateShift;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AdminTrainerStatusOnlyUpdateTest extends TestCase
{
    use DatabaseTransactions;

    private User $trainerUser;

    private TrainerProfile $trainerProfile;

    private User $adminUser;

    protected function setUp(): void
    {
        parent::setUp();

        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $this->adminUser = User::create([
            'role_id' => $adminRole->id,
            'name' => 'Permission Test Admin',
            'email' => uniqid('permission_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $role = Role::firstOrCreate(['name' => 'trainer']);
        $this->trainerUser = User::create([
            'role_id' => $role->id,
            'name' => 'Protected Trainer',
            'email' => uniqid('protected_trainer_', true).'@example.test',
            'phone' => '081111111111',
            'password' => 'password123',
            'avatar_url' => 'avatars/original.jpg',
            'status' => 'active',
        ]);
        $this->trainerProfile = TrainerProfile::create([
            'user_id' => $this->trainerUser->id,
            'specialty' => 'Strength',
            'specialties' => ['Strength'],
            'tier' => 'pro',
            'max_clients' => 30,
            'bio' => 'Original bio',
            'rating' => 4.8,
            'experience_years' => 5,
            'certifications' => 'Original certificate',
            'availability_note' => 'Original availability',
            'bank_name' => 'BCA',
            'bank_account_number' => '1234567890',
            'bank_account_name' => 'Protected Trainer',
            'dana_number' => '081111111111',
            'dana_account_name' => 'Original DANA',
            'other_payment_method' => 'GoPay',
            'other_payment_number' => '082222222222',
            'other_payment_account_name' => 'Original GoPay',
            'price_per_session' => 150000,
            'display_photo_path' => 'trainer-display-photos/original.jpg',
        ]);
    }

    public function test_edit_form_only_submits_administrative_profile_fields(): void
    {
        $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->get(route('admin.trainer-profiles.edit', $this->trainerProfile))
            ->assertOk()
            ->assertSeeText('Edit Profil Trainer')
            ->assertSeeText('Kontrol Admin')
            ->assertSeeText('Status akun active/inactive dikelola terpisah melalui tombol nonaktifkan coach')
            ->assertDontSee('name="status"', false)
            ->assertSee('name="tier"', false)
            ->assertSee('name="max_clients"', false)
            ->assertSee('name="verification_status"', false)
            ->assertSee('name="admin_notes"', false)
            ->assertDontSee('name="name"', false)
            ->assertDontSee('name="email"', false)
            ->assertDontSee('name="password"', false)
            ->assertDontSee('name="avatar_url"', false)
            ->assertDontSee('name="specialty"', false)
            ->assertDontSee('name="bio"', false)
            ->assertDontSee('name="rating"', false)
            ->assertDontSee('name="experience_years"', false)
            ->assertDontSee('name="certifications"', false)
            ->assertDontSee('name="availability_note"', false)
            ->assertSeeText('Simpan Perubahan');
    }

    public function test_create_form_uses_standardized_specialty_dropdown_and_rejects_manual_value(): void
    {
        $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->get(route('admin.trainer-profiles.create'))
            ->assertOk()
            ->assertSeeText('TAMBAH TRAINER')
            ->assertSeeText('Personal Trainer / Tambah Trainer')
            ->assertSeeText('Informasi Akun')
            ->assertSeeText('Profil Profesional')
            ->assertSeeText('Pengaturan Administratif')
            ->assertDontSee('class="topbar__title">Tambah Trainer', false)
            ->assertSee('enctype="multipart/form-data"', false)
            ->assertSee('name="status" value="active"', false)
            ->assertDontSee('name="rating"', false)
            ->assertDontSee('<select id="status"', false)
            ->assertDontSee('<input id="rating"', false)
            ->assertSee('id="passwordToggle"', false)
            ->assertSee('id="avatarPreview"', false)
            ->assertSee('name="avatar" accept="image/jpeg,image/png,image/webp"', false)
            ->assertDontSee('name="avatar_url"', false)
            ->assertSee('new FormData(form)', false)
            ->assertSee('URL.createObjectURL(file)', false)
            ->assertSeeText('Maksimal 2 MB')
            ->assertSee('class="tc-specialty-grid"', false)
            ->assertSee('id="specialtySelectedCount"', false)
            ->assertSee('class="tc-bio"', false)
            ->assertSee('class="tc-certifications"', false)
            ->assertSee('class="tc-availability"', false)
            ->assertSee('name="verification_status"', false)
            ->assertSee('name="admin_notes"', false)
            ->assertDontSeeText('Rating Awal')
            ->assertSee('name="specialties[]"', false)
            ->assertSee('value="Bodybuilding"', false)
            ->assertSee('value="Nutrition Coaching"', false)
            ->assertDontSee('type="text" name="specialty"', false);

        $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->from(route('admin.trainer-profiles.create'))
            ->post(route('admin.trainer-profiles.store'), [
                'name' => 'Invalid Specialty Trainer',
                'email' => uniqid('invalid_specialty_', true).'@example.test',
                'phone' => '08123456789',
                'password' => 'password123',
                'status' => 'active',
                'specialties' => ['Custom Specialty'],
            ])
            ->assertRedirect(route('admin.trainer-profiles.create'))
            ->assertSessionHasErrors('specialties.0');

        $this->assertDatabaseMissing('users', ['name' => 'Invalid Specialty Trainer']);

        $validEmail = uniqid('multi_specialty_', true).'@example.test';
        $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->post(route('admin.trainer-profiles.store'), [
                'name' => 'Multi Specialty Trainer',
                'email' => $validEmail,
                'phone' => '08123456780',
                'password' => 'password123',
                'status' => 'active',
                'specialties' => ['Bodybuilding', 'Weight Loss', 'Powerlifting'],
                'tier' => 'elite',
                'max_clients' => 45,
                'verification_status' => 'verified',
                'admin_notes' => 'Trainer registration reviewed.',
                'rating' => 0,
                'experience_years' => 4,
            ])
            ->assertRedirect(route('admin.trainer-profiles.index'));

        $createdUser = User::query()->where('email', $validEmail)->firstOrFail();
        $createdProfile = $createdUser->trainerProfile;
        $this->assertSame('Bodybuilding', $createdProfile->specialty);
        $this->assertSame(
            ['Bodybuilding', 'Weight Loss', 'Powerlifting'],
            $createdProfile->specialties
        );
        $this->assertSame('active', $createdUser->status);
        $this->assertSame('elite', $createdProfile->tier);
        $this->assertSame(45, $createdProfile->max_clients);
        $this->assertSame('verified', $createdProfile->verification_status);
        $this->assertSame('Trainer registration reviewed.', $createdProfile->admin_notes);
        $this->assertSame(0.0, (float) $createdProfile->rating);
        $this->assertSame(4, $createdProfile->experience_years);
    }

    public function test_create_trainer_stores_optional_avatar_file_as_public_relative_path(): void
    {
        Storage::fake('public');
        $email = uniqid('avatar_upload_trainer_', true).'@example.test';

        $response = $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->postJson(route('admin.trainer-profiles.store'), [
                'name' => 'Avatar Upload Trainer',
                'email' => $email,
                'phone' => '08123450000',
                'password' => 'password123',
                'status' => 'active',
                'rating' => 0,
                'specialties' => ['Strength Training'],
                'tier' => 'pro',
                'max_clients' => 30,
                'verification_status' => 'pending',
                'avatar' => UploadedFile::fake()->image('trainer.webp', 600, 600)->size(500),
            ]);

        $response->assertCreated()
            ->assertJsonPath('message', 'Trainer berhasil ditambahkan.')
            ->assertJsonPath('redirect_url', route('admin.trainer-profiles.index'));

        $user = User::query()->where('email', $email)->firstOrFail();
        $this->assertNotNull($user->avatar_url);
        $this->assertStringStartsWith('avatars/', $user->avatar_url);
        Storage::disk('public')->assertExists($user->avatar_url);
        $response->assertJsonPath('avatar_url', Storage::disk('public')->url($user->avatar_url));
    }

    public function test_create_trainer_rejects_invalid_avatar_without_creating_user(): void
    {
        Storage::fake('public');
        $email = uniqid('invalid_avatar_trainer_', true).'@example.test';

        $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->postJson(route('admin.trainer-profiles.store'), [
                'name' => 'Invalid Avatar Trainer',
                'email' => $email,
                'phone' => '08123450001',
                'password' => 'password123',
                'status' => 'active',
                'rating' => 0,
                'specialties' => ['Strength Training'],
                'avatar' => UploadedFile::fake()->create('avatar.pdf', 100, 'application/pdf'),
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('avatar');

        $this->assertDatabaseMissing('users', ['email' => $email]);
        $this->assertSame([], Storage::disk('public')->allFiles('avatars'));
    }

    public function test_specialty_filters_are_compact_and_extra_selection_stays_visible(): void
    {
        $this->trainerProfile->update([
            'specialty' => 'Bodybuilding',
            'specialties' => ['Bodybuilding', 'Yoga'],
        ]);
        $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->get(route('admin.trainer-profiles.index'))
            ->assertOk()
            ->assertSeeText('All Specialists')
            ->assertSeeText('Bodybuilding')
            ->assertSeeText('Muscle Gain')
            ->assertSeeText('Weight Loss')
            ->assertSeeText('Strength Training')
            ->assertSeeText('Lainnya')
            ->assertSee('aria-expanded="false"', false)
            ->assertSee('class="tr-tabs tr-tabs--extra "', false);

        $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->get(route('admin.trainer-profiles.index', ['specialty' => 'Yoga']))
            ->assertOk()
            ->assertSeeText('Protected Trainer')
            ->assertSeeText('Tutup')
            ->assertSee('aria-expanded="true"', false)
            ->assertSee('class="tr-tabs tr-tabs--extra is-open"', false)
            ->assertSee('class="tr-tab active">Yoga</a>', false);
    }

    public function test_queue_trainer_can_rotate_into_two_preview_slots_without_backend_mutation(): void
    {
        $role = Role::query()->where('name', 'trainer')->firstOrFail();
        $trainerCountBefore = TrainerProfile::query()->count();
        foreach ([4.7, 4.6] as $index => $rating) {
            $user = User::create([
                'role_id' => $role->id,
                'name' => 'Queue Rotation Trainer '.($index + 1),
                'email' => uniqid('queue_rotation_', true).'@example.test',
                'password' => 'password123',
                'status' => 'active',
            ]);
            TrainerProfile::create([
                'user_id' => $user->id,
                'specialty' => 'Strength',
                'specialties' => ['Strength'],
                'tier' => 'pro',
                'max_clients' => 30,
                'rating' => $rating,
            ]);
        }

        $response = $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->get(route('admin.trainer-profiles.index'));

        $response->assertOk()
            ->assertDontSee('placeholder="Search coach..."', false)
            ->assertDontSee('class="tr-advanced"', false)
            ->assertSeeText('Belum ada rating')
            ->assertSeeText('0 ulasan')
            ->assertSee("const trainerFeaturedStorageKey = 'admin_trainer_featured_order';", false)
            ->assertSee('const backendTrainerIds =', false)
            ->assertSee('const activeTrainerIds =', false)
            ->assertSee('function trReadStoredFeaturedIds()', false)
            ->assertSee('function trWriteStoredFeaturedIds(ids = topTrainerIds)', false)
            ->assertSee('function trRestorePreviewSlots()', false)
            ->assertSee('window.localStorage.getItem(trainerFeaturedStorageKey)', false)
            ->assertSee('window.localStorage.setItem(trainerFeaturedStorageKey, JSON.stringify(normalized));', false)
            ->assertSee('let topTrainerIds = [];', false)
            ->assertSee('let queueTrainerIds = [];', false)
            ->assertSee('const trainerQueuePageSize = 2;', false)
            ->assertSee('const visibleQueueIds = queueTrainerIds.slice(', false)
            ->assertSee('`Viewing ${visibleQueueIds.length} of ${queueTrainerIds.length} Coaches`', false)
            ->assertSee('id="trainerQueuePrevious"', false)
            ->assertSee('id="trainerQueueNext"', false)
            ->assertSee('function trChangeQueuePage(direction)', false)
            ->assertSee('const outgoingId = topTrainerIds.length >= 2 ? topTrainerIds.shift() : null;', false)
            ->assertSee('topTrainerIds.push(trainerId);', false)
            ->assertSee('queueTrainerIds = queueTrainerIds.filter(id => id !== trainerId);', false)
            ->assertSee('queueTrainerIds.unshift(outgoingId);', false)
            ->assertSee('trWriteStoredFeaturedIds();', false)
            ->assertSee('if (!trainerResultIsFiltered) trWriteStoredFeaturedIds();', false)
            ->assertSee('trRestorePreviewSlots();', false)
            ->assertSee("if (event.target.closest('a, button, form, [data-kebab]')) return;", false)
            ->assertSee('id="trainerQueueEmpty"', false)
            ->assertSee('data-active="true"', false)
            ->assertSee('data-trainer-id="'.$this->trainerProfile->id.'"', false);

        $this->assertSame($trainerCountBefore + 2, TrainerProfile::query()->count());
    }

    public function test_trainer_detail_is_read_only_and_separate_from_edit_flow(): void
    {
        TrainerSchedule::create([
            'trainer_profile_id' => $this->trainerProfile->id,
            'day_of_week' => 1,
            'start_time' => '08:00:00',
            'end_time' => '10:00:00',
            'session_duration_minutes' => 120,
        ]);

        $index = $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->get(route('admin.trainer-profiles.index'));
        $index->assertOk()
            ->assertSee('href="'.route('admin.trainer-profiles.show', $this->trainerProfile).'" class="tr-btn-text">Lihat Detail', false)
            ->assertSee('href="'.route('admin.trainer-profiles.edit', $this->trainerProfile).'" class="tr-btn-text">Edit Profil', false);

        $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->get(route('admin.trainer-profiles.show', $this->trainerProfile))
            ->assertOk()
            ->assertSeeText('Detail Trainer')
            ->assertSeeText('Protected Trainer')
            ->assertSeeText('Original bio')
            ->assertSeeText('Original certificate')
            ->assertSeeText('Informasi Pembayaran')
            ->assertSeeText('Rp 150.000')
            ->assertDontSeeText('Jadwal Mingguan')
            ->assertDontSeeText('08:00 - 10:00')
            ->assertSee('href="'.route('admin.trainer-profiles.edit', $this->trainerProfile).'" class="btn btn-primary">Edit Profil', false)
            ->assertDontSee('action="'.route('admin.trainer-profiles.update', $this->trainerProfile).'"', false)
            ->assertDontSee('name="status"', false)
            ->assertDontSeeText('Simpan Perubahan');
    }

    public function test_calendar_route_shows_monthly_actual_sessions_and_pending_reschedule_keeps_original_date(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-07-01 08:00:00', 'Asia/Jakarta'));
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $memberUser = User::create([
            'role_id' => $memberRole->id,
            'name' => 'Calendar Actual Member',
            'email' => uniqid('calendar_member_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => strtoupper(uniqid('CAL-')),
            'joined_at' => '2026-07-01',
        ]);
        $scheduleDate = TrainerScheduleDate::create([
            'trainer_profile_id' => $this->trainerProfile->id,
            'schedule_date' => '2026-07-13',
            'state' => 'open',
            'source' => 'manual',
            'template_version' => 1,
            'lock_version' => 1,
        ]);
        $proposedDate = TrainerScheduleDate::create([
            'trainer_profile_id' => $this->trainerProfile->id,
            'schedule_date' => '2026-07-20',
            'state' => 'open',
            'source' => 'manual',
            'template_version' => 1,
            'lock_version' => 1,
        ]);
        TrainerScheduleDateShift::create([
            'trainer_schedule_date_id' => $scheduleDate->id,
            'start_time' => '10:00:00',
            'end_time' => '11:00:00',
            'session_duration_minutes' => 60,
        ]);
        TrainerScheduleDateShift::create([
            'trainer_schedule_date_id' => $scheduleDate->id,
            'start_time' => '12:00:00',
            'end_time' => '13:00:00',
            'session_duration_minutes' => 60,
        ]);
        TrainerScheduleDateShift::create([
            'trainer_schedule_date_id' => $proposedDate->id,
            'start_time' => '14:00:00',
            'end_time' => '15:00:00',
            'session_duration_minutes' => 60,
        ]);
        $booking = Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $this->trainerProfile->id,
            'trainer_schedule_date_id' => $scheduleDate->id,
            'session_title' => 'Strength Training Aktual',
            'session_date' => '2026-07-13',
            'start_time' => '10:00:00',
            'end_time' => '11:00:00',
            'session_duration_minutes' => 60,
            'location' => 'EggGym Lantai 2',
            'session_count' => 1,
            'status' => 'confirmed',
            'payment_verified_at' => now(),
        ]);
        $reservation = BookingSessionReservation::create([
            'booking_id' => $booking->id,
            'sequence_order' => 1,
            'trainer_profile_id' => $this->trainerProfile->id,
            'member_profile_id' => $member->id,
            'trainer_schedule_date_id' => $scheduleDate->id,
            'session_date' => '2026-07-13',
            'start_time' => '10:00:00',
            'end_time' => '11:00:00',
            'session_duration_minutes' => 60,
            'status' => BookingSessionReservation::STATUS_RESERVED,
        ]);
        $reschedule = BookingRescheduleRequest::create([
            'booking_id' => $booking->id,
            'booking_session_reservation_id' => $reservation->id,
            'active_reservation_id' => $reservation->id,
            'trainer_profile_id' => $this->trainerProfile->id,
            'requested_by_user_id' => $memberUser->id,
            'requested_by_role' => 'member',
            'original_trainer_schedule_date_id' => $scheduleDate->id,
            'original_session_date' => '2026-07-13',
            'original_start_time' => '10:00:00',
            'original_end_time' => '11:00:00',
            'proposed_trainer_schedule_date_id' => $proposedDate->id,
            'proposed_session_date' => '2026-07-20',
            'proposed_start_time' => '14:00:00',
            'proposed_end_time' => '15:00:00',
            'proposed_duration_minutes' => 60,
            'reason_type' => 'member_request',
            'status' => BookingRescheduleRequest::STATUS_PENDING,
            'expired_at' => now()->addDay(),
        ]);
        Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $this->trainerProfile->id,
            'trainer_schedule_date_id' => $scheduleDate->id,
            'session_title' => 'Legacy Session Aktual',
            'session_date' => '2026-07-25',
            'start_time' => '09:00:00',
            'end_time' => '10:00:00',
            'session_duration_minutes' => 60,
            'location' => 'EggGym Studio',
            'session_count' => 1,
            'status' => 'completed',
        ]);
        Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $this->trainerProfile->id,
            'trainer_schedule_date_id' => $proposedDate->id,
            'session_title' => 'Outside Month Session',
            'session_date' => '2026-08-02',
            'start_time' => '09:00:00',
            'end_time' => '10:00:00',
            'session_duration_minutes' => 60,
            'location' => 'EggGym Outside Month',
            'session_count' => 1,
            'status' => 'confirmed',
        ]);

        $response = $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->get(route('admin.trainer-profiles.schedule', [
                'trainerProfile' => $this->trainerProfile,
                'month' => '2026-07',
            ]));

        $response->assertOk()
            ->assertSeeText('Kalender Sesi Aktual')
            ->assertSeeText('Tersedia / Kosong')
            ->assertSeeText('Sudah Dibooking')
            ->assertSeeText('Tidak Aktif / Tidak Tersedia')
            ->assertSeeText('Agenda Juli 2026')
            ->assertSeeText('Calendar Actual Member')
            ->assertSeeText('Strength Training Aktual')
            ->assertSeeText('Legacy Session Aktual')
            ->assertSeeText('10:00–11:00')
            ->assertSeeText('12:00–13:00')
            ->assertSeeText('Kosong')
            ->assertSeeText('Reschedule Pending')
            ->assertSee('EggGym Lantai 2', false)
            ->assertSee('Terverifikasi', false)
            ->assertSeeText('14:00–15:00')
            ->assertDontSeeText('Generated / Open')
            ->assertDontSeeText('Outside Month Session')
            ->assertSee('month=2026-06', false)
            ->assertSee('month=2026-08', false);

        $sessions = $response->viewData('sessions');
        $slotsByDate = $response->viewData('slotsByDate');
        $this->assertCount(2, $sessions);
        $this->assertSame('booked', $slotsByDate->get('2026-07-13')->first()['slot_state']);
        $this->assertSame('available', $slotsByDate->get('2026-07-13')->last()['slot_state']);
        $this->assertSame('reschedule_pending', $slotsByDate->get('2026-07-20')->first()['slot_state']);
        $this->assertSame('off', $response->viewData('dayStates')->get('2026-07-14'));
        $this->assertFalse($sessions->contains(fn (array $session) => $session['date'] === '2026-07-20'));
        $this->assertSame('2026-07-13', $sessions->first()['date']);
        $this->assertTrue($sessions->first()['has_pending_reschedule']);

        $reservation->update([
            'trainer_schedule_date_id' => $proposedDate->id,
            'session_date' => '2026-07-20',
            'start_time' => '14:00:00',
            'end_time' => '15:00:00',
        ]);
        $reschedule->update([
            'status' => BookingRescheduleRequest::STATUS_ACCEPTED,
            'active_reservation_id' => null,
            'responded_by_user_id' => $this->trainerUser->id,
            'responded_at' => now(),
        ]);

        $acceptedResponse = $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->get(route('admin.trainer-profiles.schedule', [
                'trainerProfile' => $this->trainerProfile,
                'month' => '2026-07',
            ]));
        $acceptedSessions = $acceptedResponse->viewData('sessions');
        $acceptedSlotsByDate = $acceptedResponse->viewData('slotsByDate');
        $acceptedResponse->assertOk()
            ->assertSeeText('14:00–15:00')
            ->assertSeeText('10:00–11:00');
        $acceptedReservationSession = $acceptedSessions->firstWhere('key', 'reservation-'.$reservation->id);
        $this->assertSame('2026-07-20', $acceptedReservationSession['date']);
        $this->assertFalse($acceptedReservationSession['has_pending_reschedule']);
        $this->assertSame('available', $acceptedSlotsByDate->get('2026-07-13')->first()['slot_state']);
        $this->assertSame('booked', $acceptedSlotsByDate->get('2026-07-20')->first()['slot_state']);
        $this->assertFalse($acceptedSlotsByDate->flatten(1)->contains(
            fn (array $slot) => $slot['slot_state'] === 'reschedule_pending'
        ));
    }

    public function test_manual_payload_only_changes_admin_owned_profile_fields(): void
    {
        $originalPassword = $this->trainerUser->password;

        $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->put(route('admin.trainer-profiles.update', $this->trainerProfile), [
                'status' => 'inactive',
                'name' => 'Hacked Name',
                'email' => 'hacked@example.test',
                'phone' => '089999999999',
                'password' => 'hacked-password',
                'avatar_url' => 'avatars/hacked.jpg',
                'display_photo_path' => 'trainer-display-photos/hacked.jpg',
                'specialty' => 'Hacked Specialty',
                'specialties' => ['Powerlifting', 'Yoga'],
                'tier' => 'elite',
                'max_clients' => 40,
                'verification_status' => 'verified',
                'admin_notes' => 'Internal verified coach.',
                'bio' => 'Hacked bio',
                'rating' => 1,
                'experience_years' => 99,
                'certifications' => 'Hacked certificate',
                'availability_note' => 'Hacked availability',
                'bank_name' => 'HACK BANK',
                'bank_account_number' => '999',
                'bank_account_name' => 'Hacker',
                'dana_number' => '089999999999',
                'dana_account_name' => 'Hacked DANA',
                'other_payment_method' => 'OVO',
                'other_payment_number' => '089999999999',
                'other_payment_account_name' => 'Hacked OVO',
                'price_per_session' => 1,
            ])
            ->assertRedirect(route('admin.trainer-profiles.index'))
            ->assertSessionHas('success', 'Profil administratif trainer berhasil diperbarui.');

        $user = $this->trainerUser->fresh();
        $profile = $this->trainerProfile->fresh();

        $this->assertSame('active', $user->status);
        $this->assertSame('Protected Trainer', $user->name);
        $this->assertNotSame('hacked@example.test', $user->email);
        $this->assertSame('081111111111', $user->phone);
        $this->assertSame($originalPassword, $user->password);
        $this->assertSame('avatars/original.jpg', $user->avatar_url);
        $this->assertSame('trainer-display-photos/original.jpg', $profile->display_photo_path);
        $this->assertSame('Strength', $profile->specialty);
        $this->assertSame(['Strength'], $profile->specialties);
        $this->assertSame('elite', $profile->tier);
        $this->assertSame(40, $profile->max_clients);
        $this->assertSame('verified', $profile->verification_status);
        $this->assertSame('Internal verified coach.', $profile->admin_notes);
        $this->assertSame('Original bio', $profile->bio);
        $this->assertSame(4.8, (float) $profile->rating);
        $this->assertSame(5, $profile->experience_years);
        $this->assertSame('Original certificate', $profile->certifications);
        $this->assertSame('Original availability', $profile->availability_note);
        $this->assertSame('BCA', $profile->bank_name);
        $this->assertSame('1234567890', $profile->bank_account_number);
        $this->assertSame('Protected Trainer', $profile->bank_account_name);
        $this->assertSame('081111111111', $profile->dana_number);
        $this->assertSame('Original DANA', $profile->dana_account_name);
        $this->assertSame('GoPay', $profile->other_payment_method);
        $this->assertSame('082222222222', $profile->other_payment_number);
        $this->assertSame('Original GoPay', $profile->other_payment_account_name);
        $this->assertSame(150000.0, (float) $profile->price_per_session);
    }

    public function test_admin_profile_validation_rejects_unknown_values_without_mutation(): void
    {
        $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->from(route('admin.trainer-profiles.edit', $this->trainerProfile))
            ->put(route('admin.trainer-profiles.update', $this->trainerProfile), [
                'tier' => 'super-elite',
                'max_clients' => 0,
                'verification_status' => 'suspended',
                'admin_notes' => 'Ignored note',
                'name' => 'Ignored Name',
            ])
            ->assertRedirect(route('admin.trainer-profiles.edit', $this->trainerProfile))
            ->assertSessionHasErrors(['tier', 'max_clients', 'verification_status']);

        $this->assertSame('active', $this->trainerUser->fresh()->status);
        $this->assertSame('Protected Trainer', $this->trainerUser->fresh()->name);
        $this->assertSame('pro', $this->trainerProfile->fresh()->tier);
        $this->assertSame(30, $this->trainerProfile->fresh()->max_clients);
        $this->assertSame('pending', $this->trainerProfile->fresh()->verification_status);
        $this->assertNull($this->trainerProfile->fresh()->admin_notes);
    }

    public function test_account_status_is_changed_only_through_separate_toggle_action(): void
    {
        $this->withSession(['admin_user_id' => $this->adminUser->id])
            ->patch(route('admin.trainer-profiles.toggle-status', $this->trainerProfile))
            ->assertRedirect(route('admin.trainer-profiles.index'))
            ->assertSessionHas('success');

        $this->assertSame('inactive', $this->trainerUser->fresh()->status);
        $this->assertSame('pro', $this->trainerProfile->fresh()->tier);
        $this->assertSame(30, $this->trainerProfile->fresh()->max_clients);
    }
}

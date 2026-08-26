import 'package:egg_gym/domain/entities/demo_models.dart';

class LocalDemoDataSourceClean {
  GuestShowcaseData getGuestShowcase() {
    return GuestShowcaseData(
      plans: getMembershipPlans(),
      trainers: getTrainers(),
      equipments: getEquipments(),
      operationHours: const [
        OperationHour(day: 'Senin - Jumat', hours: '06.00 - 22.00'),
        OperationHour(day: 'Sabtu', hours: '07.00 - 20.00'),
        OperationHour(day: 'Minggu & Libur', hours: '08.00 - 18.00'),
      ],
    );
  }

  List<EquipmentInfo> getEquipments() {
    return const [
      EquipmentInfo(
        name: 'Hi-Performance Treadmill',
        category: 'Cardio',
        description:
            'Treadmill untuk endurance, incline walk, dan progressive cardio.',
        focus: 'Calves, quads, stamina',
      ),
      EquipmentInfo(
        name: 'Olympic Power Rack',
        category: 'Strength',
        description:
            'Rack utama untuk squat, overhead press, dan bench safety setup.',
        focus: 'Full body compound',
      ),
      EquipmentInfo(
        name: 'Cable Station',
        category: 'Functional',
        description:
            'Latihan pull, push, dan isolation movement dengan resistance stabil.',
        focus: 'Back, chest, arms',
      ),
    ];
  }

  List<MembershipPlan> getMembershipPlans() {
    return const [
      MembershipPlan(
        title: 'Starter Pack',
        subtitle: '',
        priceLabel: 'Rp 299.000',
        periodLabel: ' / Bulan',
      ),
      MembershipPlan(
        title: 'Elite Member',
        subtitle: '',
        priceLabel: 'Rp 549.000',
        periodLabel: ' / Bulan',
        badge: 'Best Deal',
        isHighlighted: true,
      ),
      MembershipPlan(
        title: 'Annual Pro',
        subtitle: '',
        priceLabel: 'Rp 1.900.000',
        periodLabel: ' / Tahun',
      ),
    ];
  }

  List<TrainerProfile> getTrainers() {
    return const [
      TrainerProfile(
        name: 'Marcus Thorne',
        specialty: 'Bodybuilding',
        bio:
            'Konsisten jadi kunci. Saya akan membimbing Anda melalui batas fisik yang Anda bayangkan.',
        rating: 4.9,
        reviewsCount: 870,
        tier: 'pro',
      ),
      TrainerProfile(
        name: 'Elena Rodriguez',
        specialty: 'Yoga',
        bio:
            'Menemukan harmoni antara kekuatan dan ketenangan jiwa melalui gerakan yang presisi.',
        rating: 5.0,
        reviewsCount: 540,
        tier: 'elite',
      ),
      TrainerProfile(
        name: 'Julian Vane',
        specialty: 'Muscle Gain',
        bio:
            'Former olympic conditioning coach dengan spesialis strength dan metabolic training.',
        rating: 4.95,
        reviewsCount: 1200,
        tier: 'basic',
      ),
    ];
  }

  MemberDashboardData getMemberDashboard() {
    return MemberDashboardData(
      memberName: 'Naufal',
      currentTier: 'Elite Status',
      packageName: 'Platinum Club',
      validUntil: 'Dec 20, 2024',
      remainingDays: 142,
      nextSession: const ScheduleSession(
        clientName: 'Coach Adrian Putra',
        timeRange: '17.00 - 18.30',
        location: 'Studio A',
        status: 'Aktif',
        note: 'Upper body hypertrophy focus',
      ),
      programSessions: const [
        WorkoutSession(
          title: 'Push Day: Focus Chest',
          focus: 'Monday, Oct 23 - 45 mins completed',
          progressText: 'Past session done',
          statusLabel: 'Past',
          isComplete: true,
        ),
        WorkoutSession(
          title: 'Pull Day: Lat Thickness',
          focus: 'Scheduled for today - 6 exercises',
          progressText: 'Start session and open details',
          statusLabel: 'Active',
        ),
        WorkoutSession(
          title: 'Leg Day: Quad Power',
          focus: 'Next Friday, Oct 27',
          progressText: 'Unlock after current session complete',
          statusLabel: 'Locked',
          isLocked: true,
        ),
      ],
      recentTransactions: const [
        TransactionItem(
          title: 'Elite Membership - Sep',
          amount: 'Rp 850,000',
          dateLabel: 'Sep 24, 2025 - 14.20',
          status: 'Success',
        ),
      ],
    );
  }

  List<PhysicalProgressEntry> getMemberPhysicalProgressEntries() {
    return const [
      PhysicalProgressEntry(
        id: 4,
        recordedDateLabel: '28 Mar 2026',
        weightKg: 79.8,
        heightCm: 175.0,
        note:
            'Shoulder line lebih terbuka, upper back lebih penuh, dan waist tetap terjaga selama lean bulk phase.',
        photoLabel: 'Front checkpoint pose',
        stageLabel: 'WEEK 12',
        isMilestone: true,
      ),
      PhysicalProgressEntry(
        id: 3,
        recordedDateLabel: '14 Feb 2026',
        weightKg: 77.4,
        heightCm: 175.0,
        note:
            'Volume latihan naik stabil. Dada dan lengan mulai terlihat lebih padat saat weekly check.',
        photoLabel: 'Side checkpoint pose',
        stageLabel: 'WEEK 7',
      ),
      PhysicalProgressEntry(
        id: 2,
        recordedDateLabel: '05 Jan 2026',
        weightKg: 75.8,
        heightCm: 175.0,
        note:
            'Checkpoint awal phase build muscle. Fokus perbaikan postur dan ritme makan harian.',
        photoLabel: 'Front relaxed pose',
        stageLabel: 'WEEK 2',
      ),
      PhysicalProgressEntry(
        id: 1,
        recordedDateLabel: '20 Nov 2025',
        weightKg: 74.0,
        heightCm: 175.0,
        note:
            'Baseline pertama sebelum masuk program hypertrophy. Foto dipakai sebagai pembanding before utama.',
        photoLabel: 'Initial assessment pose',
        stageLabel: 'BASELINE',
        isMilestone: true,
      ),
    ];
  }

  TrainerDashboardData getTrainerDashboard() {
    return TrainerDashboardData(
      trainerName: 'Coach Adrian',
      activeClients: 12,
      todaySessions: 8,
      rating: 4.9,
      todayAgenda: const [
        ScheduleSession(
          clientName: 'Naufal',
          timeRange: '08.00 - 09.30',
          location: 'Studio A',
          status: 'Dikonfirmasi',
          note: 'Chest day - 6 exercises',
        ),
        ScheduleSession(
          clientName: 'Budi Santoso',
          timeRange: '16.00 - 17.30',
          location: 'Studio B',
          status: 'Dikonfirmasi',
          note: 'Strength base and mobility',
        ),
        ScheduleSession(
          clientName: 'Siska Amelia',
          timeRange: 'Besok, 07.00',
          location: 'Power Yoga',
          status: 'Menunggu',
          note: 'Need confirmation before booking locks',
        ),
      ],
      clients: const [
        ClientSummary(
          name: 'Naufal Raharjo',
          goal: 'Hypertrophy Focus',
          progressLabel: '6-week mass builder - 65% completed',
          nextSession: 'Tomorrow, 08.00',
        ),
        ClientSummary(
          name: 'Rian Pratama',
          goal: 'Chest Day',
          progressLabel: 'Next booking on 15 Jan, 19.00',
          nextSession: 'Waiting confirmation',
        ),
        ClientSummary(
          name: 'Siska Amelia',
          goal: 'Power Yoga',
          progressLabel: 'Booking request needs approval',
          nextSession: 'Besok, 07.00',
        ),
      ],
      programSessions: const [
        WorkoutSession(
          title: 'Hypertrophy I',
          focus: 'Current phase - 12 of 20 sessions',
          progressText: '65 percent completed',
          statusLabel: 'Tracking',
        ),
        WorkoutSession(
          title: 'Morning Stretch',
          focus: '12 exercises - 20 mins',
          progressText: 'Self training module',
          statusLabel: 'Self',
        ),
        WorkoutSession(
          title: 'HIIT Cardio Burn',
          focus: '5 rounds - 30 mins',
          progressText: 'Ready for publish',
          statusLabel: 'Draft',
        ),
      ],
    );
  }

  List<ProjectTask> getProjectTasks() {
    return const [
      ProjectTask(
        title: 'Fondasi Clean Architecture',
        description:
            'Struktur core/data/domain/presentation, routing GetX, dan provider global sudah dipasang.',
        status: TaskStatus.done,
        scope: 'UI Foundation',
      ),
      ProjectTask(
        title: 'Splash & Login Demo',
        description:
            'Splash screen, form login, guest entry, dan shortcut role demo untuk presentasi mobile.',
        status: TaskStatus.done,
        scope: 'Auth UI',
      ),
      ProjectTask(
        title: 'Guest Public Explorer',
        description:
            'Halaman publik berisi paket, trainer, alat gym, dan jam operasional tanpa login.',
        status: TaskStatus.done,
        scope: 'Guest UI',
      ),
      ProjectTask(
        title: 'Member Dashboard UI',
        description:
            'Home member, timer interaktif, next PT session, program, membership, dan profile tab.',
        status: TaskStatus.done,
        scope: 'Member UI',
      ),
      ProjectTask(
        title: 'Trainer Dashboard UI',
        description:
            'Home PT, jadwal, klien, program, dan profile tab untuk role personal trainer.',
        status: TaskStatus.done,
        scope: 'Trainer UI',
      ),
      ProjectTask(
        title: 'Program Detail Tracker UI',
        description:
            'Halaman detail progress program member sudah dibuat dengan checklist exercise dan catatan coach dummy.',
        status: TaskStatus.done,
        scope: 'Program Detail',
      ),
      ProjectTask(
        title: 'Membership Packages UI',
        description:
            'Halaman daftar paket membership untuk preview pilihan paket mobile demo sudah tersedia.',
        status: TaskStatus.done,
        scope: 'Membership Detail',
      ),
      ProjectTask(
        title: 'PT Session & Client Detail UI',
        description:
            'Halaman detail sesi PT dan detail klien trainer sudah bisa dibuka dari dashboard demo.',
        status: TaskStatus.done,
        scope: 'Trainer Detail',
      ),
      ProjectTask(
        title: 'Build Validation',
        description:
            'Validasi dasar proyek sudah lolos lewat flutter analyze dan flutter test sehingga fondasi demo lebih aman.',
        status: TaskStatus.done,
        scope: 'Project Health',
      ),
      ProjectTask(
        title: 'Guest Visual Alignment Pass 1',
        description:
            'Tampilan guest untuk home, program locked, trainer, membership, dan profile sudah dipoles agar lebih dekat ke ZIP referensi.',
        status: TaskStatus.done,
        scope: 'Guest Polish',
      ),
      ProjectTask(
        title: 'Member Visual Alignment Pass 1',
        description:
            'Tampilan member untuk home, trainer, membership, dan profile sudah dipoles agar lebih dekat ke ZIP referensi.',
        status: TaskStatus.done,
        scope: 'Member Polish',
      ),
      ProjectTask(
        title: 'Trainer Visual Alignment Pass 1',
        description:
            'Tampilan trainer untuk home, jadwal, klien, program, dan profile sudah dipoles agar lebih dekat ke ZIP referensi.',
        status: TaskStatus.done,
        scope: 'Trainer Polish',
      ),
      ProjectTask(
        title: 'UI Alignment Pass 1',
        description:
            'Penyelarasan guest, member, dan trainer untuk kebutuhan demo pass 1 sudah selesai dan aman dijalankan.',
        status: TaskStatus.done,
        scope: 'UI Alignment',
      ),
      ProjectTask(
        title: 'UI Pixel Polish Pass 2',
        description:
            'Polish komponen umum, hero card, button, dan beberapa screen guest/member/trainer sudah selesai agar hasil demo makin dekat ke ZIP/Figma.',
        status: TaskStatus.done,
        scope: 'Visual Polish',
      ),
      ProjectTask(
        title: 'Payment Flow UI',
        description:
            'Flow payment demo sekarang sudah tersambung dari membership packages ke checkout dan success screen dengan metode bayar dummy.',
        status: TaskStatus.done,
        scope: 'Transaction UI',
      ),
      ProjectTask(
        title: 'Booking Confirmation & Reschedule UI',
        description:
            'Flow konfirmasi booking dan penjadwalan ulang sekarang sudah tersambung dari jadwal trainer ke detail sesi untuk kebutuhan demo.',
        status: TaskStatus.done,
        scope: 'Schedule UI',
      ),
      ProjectTask(
        title: 'Trainer Profile Detail UI',
        description:
            'Halaman profil trainer yang lebih lengkap sekarang sudah tersedia dengan section pencapaian, coaching style, dan availability untuk guest/member/trainer.',
        status: TaskStatus.done,
        scope: 'Trainer Detail',
      ),
      ProjectTask(
        title: 'Live Training Session UI',
        description:
            'Halaman live training sekarang sudah tersedia untuk flow member dan trainer dengan live metrics, current exercise, cue coach, dan kontrol demo.',
        status: TaskStatus.done,
        scope: 'Workout UI',
      ),
      ProjectTask(
        title: 'Interactive Exercise Checklist UI',
        description:
            'Checklist exercise sekarang sudah lebih interaktif dengan progres set, unlock exercise berikutnya, dan reset demo di tracker program member.',
        status: TaskStatus.done,
        scope: 'Workout UI',
      ),
      ProjectTask(
        title: 'Legacy Cleanup Pass 1',
        description:
            'File guest lama dan datasource duplikat yang sudah tidak dipakai dibersihkan agar fondasi project lebih aman untuk evolusi ke production.',
        status: TaskStatus.done,
        scope: 'Code Health',
      ),
      ProjectTask(
        title: 'Critical CTA Connection Pass 1',
        description:
            'CTA penting seperti booking demo, update progress klien, dan penyelesaian live session sekarang sudah tersambung ke flow halaman yang relevan.',
        status: TaskStatus.done,
        scope: 'Flow Polish',
      ),
      ProjectTask(
        title: 'Member Physical Progress UI',
        description:
            'Member sekarang punya layar progress fisik dengan compare before-after dari checkpoint berbeda, histori berat badan dan tinggi badan, serta form checkpoint demo.',
        status: TaskStatus.done,
        scope: 'Member Progress',
      ),
      ProjectTask(
        title: 'Equipment Detail Screen',
        description:
            'Halaman detail alat gym sekarang sudah tersedia untuk guest dan member, lengkap dengan fokus alat, cara pakai, safety note, dan CTA ke flow latihan atau login.',
        status: TaskStatus.done,
        scope: 'Equipment UI',
      ),
      ProjectTask(
        title: 'Placeholder Screen Cleanup Pass 1',
        description:
            'Placeholder penting seperti data pribadi member, pengaturan akun trainer, dan self-profile trainer sekarang sudah diganti menjadi screen yang lebih proper dan konsisten dengan flow aplikasi.',
        status: TaskStatus.done,
        scope: 'UI Cleanup',
      ),
      ProjectTask(
        title: 'Placeholder Screen Cleanup Pass 2',
        description:
            'Flow aktif trainer untuk membuat program baru sekarang sudah punya screen builder sendiri, dan route screen baru yang kemarin sempat tertahan sudah disinkronkan kembali.',
        status: TaskStatus.done,
        scope: 'UI Cleanup',
      ),
      ProjectTask(
        title: 'Create Program Form',
        description:
            'Trainer sekarang punya layar form draft program untuk memilih klien, mengisi nama dan deskripsi program, serta menambah, mengubah, dan menghapus struktur sesi secara lokal untuk demo flow utama.',
        status: TaskStatus.done,
        scope: 'Program Builder',
      ),
      ProjectTask(
        title: 'Edit Training Session',
        description:
            'Trainer sekarang punya layar khusus untuk mengubah nama sesi, menambah latihan dari database atau manual, serta menyimpan isi sesi kembali ke draft program.',
        status: TaskStatus.done,
        scope: 'Program Builder',
      ),
      ProjectTask(
        title: 'Progressive Unlock Timeline',
        description:
            'Trainer sekarang punya layar timeline unlock untuk melihat sesi selesai, sesi aktif, sesi terkunci, serta membuka tracker sesi aktif atau override sequence untuk demo.',
        status: TaskStatus.done,
        scope: 'Program Builder',
      ),
      ProjectTask(
        title: 'Polish Program Detail Tracker',
        description:
            'Layar tracker program sekarang lebih jelas membedakan mode program PT yang read-only dengan latihan mandiri, lengkap dengan banner sinkronisasi, validator trainer, dan ringkasan sequence status.',
        status: TaskStatus.done,
        scope: 'Program Detail',
      ),
      ProjectTask(
        title: 'Polish Live Training Session',
        description:
            'Layar sesi live sekarang lebih jelas menampilkan progress sesi, queue latihan, status sinkron trainer-member, dan validator trainer untuk kebutuhan demo yang lebih matang.',
        status: TaskStatus.done,
        scope: 'Workout UI',
      ),
      ProjectTask(
        title: 'Active Session Terminology Alignment',
        description:
            'Istilah di layar sesi sekarang dibedakan lebih jelas antara Sesi PT Aktif dan Sesi Latihan Aktif agar flow trainer-guided dan self-guided lebih mudah dipahami saat demo.',
        status: TaskStatus.done,
        scope: 'Workout UI',
      ),
      ProjectTask(
        title: 'Trainer-Side Progress Control',
        description:
            'Trainer sekarang punya layar kontrol progres untuk menandai set per set dan mempreview hasil sinkronnya langsung ke tracker member sebagai program PT read-only.',
        status: TaskStatus.done,
        scope: 'Workout UI',
      ),
      ProjectTask(
        title: 'Workout/PT Copy Consistency Pass',
        description:
            'Istilah, label tombol, section title, dan status pada flow workout serta personal trainer sudah dirapikan agar lebih seragam dan lebih mudah dipahami saat demo.',
        status: TaskStatus.done,
        scope: 'Workout UI',
      ),
      ProjectTask(
        title: 'Roadmap Backend + Admin Web',
        description:
            'Dokumen roadmap transisi dari mobile demo ke production sudah tersedia, lengkap dengan fase implementasi, modul backend, modul admin web, serta urutan kerja yang realistis.',
        status: TaskStatus.done,
        scope: 'Production Planning',
      ),
      ProjectTask(
        title: 'Finalisasi ERD Inti Backend',
        description:
            'Struktur tabel inti backend untuk auth, booking, program trainer-member, progres latihan, progres fisik, transaksi, dan notifikasi sudah difinalkan sebagai acuan implementasi Laravel.',
        status: TaskStatus.done,
        scope: 'Production Planning',
      ),
      ProjectTask(
        title: 'Kontrak Endpoint API Mobile',
        description:
            'Dokumen endpoint API utama untuk guest, member, trainer, payment, dan notifikasi dasar sudah disusun lengkap dengan request, response, dan mapping screen mobile ke backend.',
        status: TaskStatus.done,
        scope: 'Production Planning',
      ),
      ProjectTask(
        title: 'Checklist Setup Backend Laravel',
        description:
            'Checklist teknis setup Laravel backend, Sanctum, role permission, migration inti, dan struktur awal API sudah disusun agar implementasi backend bisa dimulai dengan urutan yang jelas.',
        status: TaskStatus.done,
        scope: 'Production Planning',
      ),
      ProjectTask(
        title: 'Struktur Repo Backend Laravel',
        description:
            'Dokumen struktur repo dan folder backend Laravel sudah disusun, lengkap dengan rekomendasi pemisahan repo mobile dan backend serta penempatan folder API, service, action, request, resource, dan admin web.',
        status: TaskStatus.done,
        scope: 'Production Planning',
      ),
      ProjectTask(
        title: 'Breakdown Migration Laravel',
        description:
            'Urutan migration Laravel per batch sudah disusun berdasarkan dependensi tabel dan foreign key agar implementasi backend lebih aman dan tidak salah urut.',
        status: TaskStatus.done,
        scope: 'Production Planning',
      ),
      ProjectTask(
        title: 'Panduan Bootstrap Backend Laravel',
        description:
            'Langkah eksekusi inisialisasi repo backend Laravel sudah disusun lengkap dengan urutan command, setup Sanctum, role dasar, struktur folder, dan langkah awal Batch 1 migration.',
        status: TaskStatus.done,
        scope: 'Production Planning',
      ),
      ProjectTask(
        title: 'Bootstrap Backend Laravel',
        description:
            'Repo backend Laravel terpisah sudah berhasil dibuat, migration bawaan sudah jalan, personal access tokens sudah tersedia, dan server backend dasar sudah berhasil dijalankan.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Implementasi Batch 1 Backend',
        description:
            'Migration `roles`, penyesuaian tabel `users`, model `Role`, `RoleSeeder`, `AdminUserSeeder`, dan seeding awal admin berhasil dijalankan di repo backend Laravel.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Implementasi Batch 2 Backend',
        description:
            'Migration `member_profiles`, `trainer_profiles`, `membership_plans`, dan `member_memberships` berhasil dijalankan sehingga fondasi profile dan membership backend sudah siap untuk dipakai modul berikutnya.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Auth Endpoint Dasar Backend',
        description:
            'Endpoint `login`, `me`, dan `logout` berbasis Sanctum serta alias middleware `role` sudah berhasil diuji end-to-end di repo backend Laravel.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Seeder Awal Membership Plan',
        description:
            'Seeder `membership_plans` sudah berhasil dijalankan sehingga backend punya data paket dasar untuk kebutuhan API publik dan member.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Publik Membership Plans',
        description:
            'Endpoint `GET /api/v1/public/membership-plans` sudah berhasil mengambil data paket membership aktif dari database dan mengembalikannya dalam format JSON sesuai kontrak API mobile.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Publik Trainers',
        description:
            'Endpoint `GET /api/v1/public/trainers` sudah berhasil mengambil data trainer dari database dan mengembalikannya dalam format resource yang sesuai kontrak API mobile.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Publik Equipment',
        description:
            'Endpoint `GET /api/v1/public/equipment` sudah berhasil mengambil data alat gym dari database dan mengembalikannya dalam format detail yang siap dipakai guest dan member.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Member Dashboard',
        description:
            'Endpoint `GET /api/v1/member/dashboard` sudah berhasil mengembalikan ringkasan member aktif, membership berjalan, dan sesi berikutnya untuk kebutuhan home member.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Member Profile',
        description:
            'Endpoint `GET /api/v1/member/profile` sudah berhasil mengembalikan data pribadi, body snapshot dasar, dan membership aktif untuk kebutuhan layar Data Pribadi member.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Update Member Profile',
        description:
            'Endpoint `PUT /api/v1/member/profile` sudah berhasil memperbarui data pribadi member dan perubahan langsung tervalidasi kembali lewat endpoint profile.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Member Memberships',
        description:
            'Endpoint `GET /api/v1/member/memberships` sudah berhasil mengembalikan membership aktif, histori membership, dan ringkasan status untuk kebutuhan tab membership member.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Member Transactions',
        description:
            'Endpoint `GET /api/v1/member/transactions` sudah berhasil mengembalikan histori transaksi member lengkap dengan nominal, metode bayar, dan referensi provider.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Checkout Membership Payment',
        description:
            'Endpoint `POST /api/v1/member/payments/checkout` sudah berhasil membuat transaksi checkout membership berstatus pending dan langsung menambahkannya ke histori transaksi member.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Member Bookings',
        description:
            'Endpoint `GET /api/v1/member/bookings` sudah berhasil mengembalikan daftar booking PT member lengkap dengan status, jadwal, trainer, dan catatan sesi.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Create Member Booking',
        description:
            'Endpoint `POST /api/v1/member/bookings` sudah berhasil membuat request booking PT baru dan langsung menambahkannya ke daftar booking member.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Reschedule Member Booking',
        description:
            'Endpoint `POST /api/v1/member/bookings/{id}/reschedule` sudah berhasil menjadwalkan ulang booking PT dan perubahan langsung tercermin di daftar booking member.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Booking Membership Rule Validation',
        description:
            'Rule bisnis booking PT sudah tervalidasi: member tanpa membership aktif gagal membuat booking dan menerima pesan error yang sesuai.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Trainer Sessions',
        description:
            'Endpoint `GET /api/v1/trainer/sessions` sudah berhasil mengembalikan daftar sesi trainer lengkap dengan filter status dan relasi member untuk kebutuhan tab jadwal trainer.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Trainer Session Detail',
        description:
            'Endpoint `GET /api/v1/trainer/sessions/{id}` sudah berhasil mengembalikan detail sesi trainer yang sesuai untuk flow detail session di mobile.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Confirm Trainer Session',
        description:
            'Endpoint `POST /api/v1/trainer/sessions/{id}/confirm` sudah berhasil mengonfirmasi booking PT dari sisi trainer dan perubahan status langsung tervalidasi di daftar sesi.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Trainer Dashboard',
        description:
            'Endpoint `GET /api/v1/trainer/dashboard` sudah berhasil mengembalikan ringkasan home trainer lengkap dengan client aktif, sesi hari ini, rating, dan agenda terdekat.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Trainer Clients',
        description:
            'Endpoint `GET /api/v1/trainer/clients` sudah berhasil mengembalikan daftar klien trainer lengkap dengan goal, progress ringkas, sesi berikutnya, dan dukungan query `search`.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Trainer Client Detail',
        description:
            'Endpoint `GET /api/v1/trainer/clients/{id}` sudah berhasil mengembalikan detail klien trainer lengkap dengan profil member, membership aktif, ringkasan sesi, dan proteksi akses owner trainer.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Trainer Session Reschedule',
        description:
            'Endpoint `POST /api/v1/trainer/sessions/{id}/reschedule` sudah berhasil menjadwalkan ulang sesi PT dari sisi trainer dan perubahan langsung tervalidasi di detail serta daftar sesi.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Create Trainer Program',
        description:
            'Endpoint `POST /api/v1/trainer/programs` sudah berhasil membuat draft program trainer untuk klien yang valid dan opsional terkait ke booking sesi.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Add Trainer Program Session',
        description:
            'Endpoint `POST /api/v1/trainer/programs/{id}/sessions` sudah berhasil menambahkan sesi ke draft program trainer lengkap dengan urutan, fokus, durasi, dan status awal.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Trainer Program Detail',
        description:
            'Endpoint `GET /api/v1/trainer/programs/{id}` sudah berhasil mengembalikan detail draft program trainer lengkap dengan header program, relasi klien, booking terkait, daftar sesi, dan summary durasi.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Update Trainer Program Session',
        description:
            'Endpoint `PUT /api/v1/trainer/program-sessions/{id}` sudah berhasil memperbarui sesi program trainer dan perubahan langsung tervalidasi di detail program.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Add Trainer Program Session Exercise',
        description:
            'Endpoint `POST /api/v1/trainer/program-sessions/{id}/exercises` sudah berhasil menambahkan latihan custom ke sesi program trainer lengkap dengan urutan, target otot, set, reps, rest time, dan cue coach.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Update Trainer Program Session Exercise',
        description:
            'Endpoint `PUT /api/v1/trainer/program-session-exercises/{id}` sudah berhasil memperbarui latihan pada sesi program trainer dan perubahan langsung tervalidasi di detail program.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Delete Trainer Program Session Exercise',
        description:
            'Endpoint `DELETE /api/v1/trainer/program-session-exercises/{id}` sudah berhasil menghapus latihan dari sesi program trainer dan perubahan langsung tervalidasi di detail program.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Trainer Session Progress Detail',
        description:
            'Endpoint `GET /api/v1/trainer/program-sessions/{id}/progress` sudah berhasil mengembalikan progres sesi trainer lengkap dengan persentase progres, exercise aktif, completed sets, dan status sinkron awal.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Update Trainer Session Progress',
        description:
            'Endpoint `POST /api/v1/trainer/program-sessions/{id}/progress` sudah berhasil menyinkronkan progres sesi trainer dari sisi PT lengkap dengan completed sets, trainer note, dan perhitungan progress percent.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Complete Trainer Session Progress',
        description:
            'Endpoint `POST /api/v1/trainer/program-sessions/{id}/complete` sudah berhasil menutup sesi PT aktif, menaikkan progres ke 100 persen, menyelesaikan set tersisa, dan membuka sesi berikutnya.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Sync Trainer Program Exercise Status',
        description:
            'Sinkronisasi status exercise di detail program setelah sesi trainer diselesaikan sekarang sudah rapi, sehingga state progress trainer dan detail program kembali konsisten.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Member Program Tracker',
        description:
            'Endpoint `GET /api/v1/member/programs/{id}/tracker` sudah berhasil mengembalikan tracker program read-only dari hasil sinkron trainer lengkap dengan sequence summary, active session, sync label, dan progress percent.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Member Program List',
        description:
            'Endpoint `GET /api/v1/member/programs` sudah berhasil mengembalikan daftar program member lengkap dengan progress percent dan active session title.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Member Program Detail',
        description:
            'Endpoint `GET /api/v1/member/programs/{id}` sudah berhasil mengembalikan detail dan ringkasan program member lengkap dengan summary sesi dan exercise count.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Create Member Physical Progress',
        description:
            'Endpoint `POST /api/v1/member/physical-progress` sudah berhasil membuat checkpoint progres fisik member dari backend nyata.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Member Physical Progress History',
        description:
            'Endpoint `GET /api/v1/member/physical-progress` sudah berhasil mengembalikan latest progress, baseline progress, history, dan summary checkpoint member.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Member Notification List',
        description:
            'Endpoint `GET /api/v1/member/notifications` sudah berhasil mengembalikan notification center dasar member dari database.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Read Member Notification',
        description:
            'Endpoint `POST /api/v1/member/notifications/{id}/read` sudah berhasil menandai notifikasi member sebagai sudah dibaca.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Endpoint Auth Device Token',
        description:
            'Fondasi notifikasi FCM-ready lewat `POST /api/v1/auth/device-token` dan `DELETE /api/v1/auth/device-token` sudah berhasil menyimpan serta menonaktifkan device token per user.',
        status: TaskStatus.done,
        scope: 'Backend Foundation',
      ),
      ProjectTask(
        title: 'Bootstrap FCM Android App',
        description:
            'Setup `google-services.json`, `firebase_core`, `firebase_messaging`, plugin Gradle, dan logging token FCM di app Flutter Android sudah siap untuk uji device nyata.',
        status: TaskStatus.done,
        scope: 'Integration',
      ),
      ProjectTask(
        title: 'Bridge Notification Push FCM',
        description:
            'Endpoint `POST /api/v1/member/notifications/{id}/push` sudah berhasil mengirim push notification nyata ke device Android aktif dari data notifikasi backend.',
        status: TaskStatus.done,
        scope: 'Integration',
      ),
      ProjectTask(
        title: 'API Integration & Auth Flow',
        description:
            'Implementasi endpoint mobile berikutnya dari kontrak API sekarang berlanjut ke producer notifikasi otomatis dari event backend ke FCM push dan notification center.',
        status: TaskStatus.todo,
        scope: 'Integration',
      ),
      ProjectTask(
        title: 'Admin Web Dashboard',
        description:
            'Fondasi admin web dashboard untuk operasional EggGym masih belum diimplementasi dan akan mengikuti roadmap production yang baru disusun.',
        status: TaskStatus.todo,
        scope: 'Admin Web',
      ),
    ];
  }
}

import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/public_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum HelpAudience { guest, member, trainer }

class HelpTopic {
  const HelpTopic({
    required this.audience,
    required this.category,
    required this.title,
    required this.steps,
    this.keywords = const <String>[],
  });

  final HelpAudience audience;
  final String category;
  final String title;
  final List<String> steps;
  final List<String> keywords;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return <String>[title, category, ...steps, ...keywords]
        .join(' ')
        .toLowerCase()
        .contains(normalized);
  }
}

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({
    super.key,
    this.audience,
  });

  final HelpAudience? audience;

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _category = 'Semua';

  HelpAudience get _audience => widget.audience ?? _resolveAudience();

  List<HelpTopic> get _roleTopics => _helpTopics
      .where((topic) => topic.audience == _audience)
      .toList(growable: false);

  List<String> get _categories => <String>[
        'Semua',
        ..._roleTopics.map((topic) => topic.category).toSet(),
      ];

  List<HelpTopic> get _filteredTopics => _roleTopics.where((topic) {
        final categoryMatches =
            _category == 'Semua' || topic.category == _category;
        return categoryMatches && topic.matches(_query);
      }).toList(growable: false);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topics = _filteredTopics;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pusat Bantuan'),
        leading: IconButton(
          onPressed: Get.back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          key: const Key('help-center-list'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _HelpHero(audience: _audience),
            const SizedBox(height: 18),
            TextField(
              key: const Key('help-search-field'),
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari bantuan...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: ListView.separated(
                key: const Key('help-category-list'),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return ChoiceChip(
                    key: ValueKey('help-category-$category'),
                    label: Text(category),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: _category == category
                          ? AppColors.background
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: _category == category
                          ? AppColors.accent
                          : AppColors.divider,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            Text(
              topics.isEmpty
                  ? 'HASIL PENCARIAN'
                  : '${topics.length} TOPIK BANTUAN',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            if (topics.isEmpty)
              const _HelpEmptyState()
            else
              ...topics.map(
                (topic) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HelpTopicCard(topic: topic),
                ),
              ),
            const SizedBox(height: 14),
            const _GymContactCard(),
          ],
        ),
      ),
    );
  }
}

class _HelpHero extends StatelessWidget {
  const _HelpHero({required this.audience});

  final HelpAudience audience;

  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (audience) {
      HelpAudience.guest => 'Guest',
      HelpAudience.member => 'Member',
      HelpAudience.trainer => 'Personal Trainer',
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF28220D), Color(0xFF151515)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              color: AppColors.accent,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Temukan panduan penggunaan aplikasi Egg Gym.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Panduan ditampilkan untuk $roleLabel.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTopicCard extends StatelessWidget {
  const _HelpTopicCard({required this.topic});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('help-topic-${topic.title}'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 17),
        iconColor: AppColors.accent,
        collapsedIconColor: AppColors.textSecondary,
        title: Text(
          topic.title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            height: 1.3,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            topic.category,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        children: [
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 14),
          ...topic.steps.indexed.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 21,
                    height: 21,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${entry.$1 + 1}',
                      style: const TextStyle(
                        color: AppColors.background,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.$2,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpEmptyState extends StatelessWidget {
  const _HelpEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('help-empty-state'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            color: AppColors.textSecondary,
            size: 42,
          ),
          SizedBox(height: 13),
          Text(
            'Topik bantuan tidak ditemukan. Coba gunakan kata kunci lain atau hubungi admin Egg Gym.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GymContactCard extends StatelessWidget {
  const _GymContactCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PublicAppSettings>(
      valueListenable: PublicSettingsService.instance.settings,
      builder: (context, settings, _) {
        final contact = settings.whatsapp.trim().isNotEmpty
            ? settings.whatsapp.trim()
            : settings.phone.trim().isNotEmpty
                ? settings.phone.trim()
                : settings.email.trim().isNotEmpty
                    ? settings.email.trim()
                    : 'Hubungi admin Egg Gym di tempat';
        final location = settings.location.trim().isNotEmpty
            ? settings.location.trim()
            : 'Egg Gym Pontianak';
        return Container(
          key: const Key('help-contact-card'),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KONTAK EGG GYM',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 14),
              const _ContactRow(
                icon: Icons.business_rounded,
                value: 'Egg Gym Pontianak',
              ),
              _ContactRow(icon: Icons.support_agent_rounded, value: contact),
              _ContactRow(icon: Icons.location_on_outlined, value: location),
            ],
          ),
        );
      },
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

HelpAudience _resolveAudience() {
  final arguments = Get.arguments;
  final rawRole = arguments is Map
      ? arguments['role']?.toString().toLowerCase()
      : arguments?.toString().toLowerCase();
  final sessionRole =
      AppSessionService.instance.currentSession?.role.toLowerCase();
  return switch (rawRole ?? sessionRole) {
    'member' => HelpAudience.member,
    'trainer' => HelpAudience.trainer,
    _ => HelpAudience.guest,
  };
}

const _helpTopics = <HelpTopic>[
  HelpTopic(
    audience: HelpAudience.guest,
    category: 'Membership',
    title: 'Cara melihat paket membership',
    steps: [
      'Buka halaman Membership.',
      'Pilih paket yang ingin dilihat untuk membaca harga, durasi, dan fasilitas.',
      'Guest hanya dapat melihat informasi. Masuk atau daftar sebagai Member untuk membeli paket.',
    ],
    keywords: ['paket', 'harga', 'keanggotaan'],
  ),
  HelpTopic(
    audience: HelpAudience.guest,
    category: 'Trainer',
    title: 'Cara melihat profil Trainer',
    steps: [
      'Buka menu Trainer.',
      'Pilih salah satu Personal Trainer.',
      'Lihat spesialisasi, rating, jadwal yang tersedia, dan harga sesi.',
    ],
    keywords: ['pt', 'personal trainer', 'jadwal', 'rating'],
  ),
  HelpTopic(
    audience: HelpAudience.guest,
    category: 'Alat Gym',
    title: 'Cara melihat informasi alat gym',
    steps: [
      'Buka bagian Alat Gym dari informasi aplikasi.',
      'Pilih alat untuk melihat deskripsi dan panduan gerakan yang tersedia.',
      'Masuk sebagai Member untuk menggunakan informasi gerakan saat menyusun latihan.',
    ],
    keywords: ['equipment', 'gerakan', 'movement'],
  ),
  HelpTopic(
    audience: HelpAudience.guest,
    category: 'Akun',
    title: 'Cara registrasi akun Member',
    steps: [
      'Tekan tombol Daftar pada halaman Login.',
      'Isi nama lengkap, email, nomor HP, password, dan konfirmasi password.',
      'Gunakan nama tanpa angka atau simbol dan nomor HP yang valid.',
      'Password minimal 8 karakter serta memiliki huruf besar, huruf kecil, angka, dan simbol.',
    ],
    keywords: ['daftar', 'register', 'password', 'akun'],
  ),
  HelpTopic(
    audience: HelpAudience.guest,
    category: 'Akun',
    title: 'Cara login',
    steps: [
      'Tekan Login.',
      'Masukkan email dan password akun.',
      'Jika gagal, pastikan email dan password yang dimasukkan benar.',
    ],
    keywords: ['masuk', 'email', 'password'],
  ),
  HelpTopic(
    audience: HelpAudience.member,
    category: 'Membership',
    title: 'Cara membeli membership',
    steps: [
      'Masuk sebagai Member dan buka menu Membership.',
      'Pilih paket dan metode pembayaran yang aktif.',
      'Lakukan pembayaran sesuai instruksi QRIS atau Virtual Account.',
      'Tunggu sampai transaksi berhasil dan membership aktif atau diperpanjang.',
    ],
    keywords: ['paket', 'pakasir', 'qris', 'virtual account'],
  ),
  HelpTopic(
    audience: HelpAudience.member,
    category: 'Booking PT',
    title: 'Cara membuat booking PT',
    steps: [
      'Pastikan membership aktif.',
      'Buka menu Trainer dan pilih Personal Trainer.',
      'Pilih jumlah sesi serta tanggal dan jam yang tersedia untuk setiap sesi.',
      'Kirim booking dan tunggu keputusan Trainer.',
    ],
    keywords: ['booking', 'trainer', 'jadwal', 'sesi'],
  ),
  HelpTopic(
    audience: HelpAudience.member,
    category: 'Pembayaran',
    title: 'Cara upload bukti pembayaran sesi PT',
    steps: [
      'Setelah booking dikonfirmasi Trainer, buka Aktivitas PT.',
      'Tekan Upload Bukti Pembayaran.',
      'Pilih bukti transfer yang benar dan kirim.',
      'Tunggu Trainer memverifikasi pembayaran.',
    ],
    keywords: ['transfer', 'bukti', 'bayar'],
  ),
  HelpTopic(
    audience: HelpAudience.member,
    category: 'Pembayaran',
    title: 'Cara upload ulang bukti pembayaran',
    steps: [
      'Jika bukti ditolak, buka Aktivitas PT atau notifikasi Pembayaran Ditolak.',
      'Tekan Upload Ulang Bukti.',
      'Pilih bukti transfer yang benar dan kirim pada booking yang sama.',
      'Tunggu verifikasi ulang dari Trainer.',
    ],
    keywords: ['ditolak', 'upload ulang', 'transfer'],
  ),
  HelpTopic(
    audience: HelpAudience.member,
    category: 'Booking PT',
    title: 'Cara mengajukan reschedule',
    steps: [
      'Buka card Aktivitas PT dan tekan Ajukan Reschedule.',
      'Pilih sesi yang ingin dipindahkan.',
      'Pilih tanggal dan jam baru, lalu pilih alasan.',
      'Kirim permintaan dan tunggu keputusan Trainer. Jadwal lama tetap berlaku sebelum permintaan diterima.',
    ],
    keywords: ['ubah jadwal', 'reschedule', 'reservation'],
  ),
  HelpTopic(
    audience: HelpAudience.member,
    category: 'Program Latihan',
    title: 'Cara menggunakan Program PT',
    steps: [
      'Program PT muncul setelah pembayaran valid dan Trainer membuat program.',
      'Buka menu Program dan pilih Program dari PT.',
      'Lihat sesi dan daftar latihan.',
      'Ikuti instruksi sesuai urutan sesi yang aktif.',
    ],
    keywords: ['program pt', 'sesi', 'progressive unlock'],
  ),
  HelpTopic(
    audience: HelpAudience.member,
    category: 'Program Latihan',
    title: 'Arti tombol Mulai Sesi',
    steps: [
      'Tombol Mulai Sesi menyimpan tanda bahwa Member siap menjalankan sesi.',
      'Setelah kesiapan tersimpan, Trainer dapat mencatat progres latihan.',
      'Tombol ini bukan stopwatch utama, bukan verifikasi kehadiran fisik, dan bukan tanda latihan selesai.',
    ],
    keywords: ['ready', 'kesiapan', 'progres'],
  ),
  HelpTopic(
    audience: HelpAudience.member,
    category: 'Latihan Mandiri',
    title: 'Cara membuat latihan mandiri',
    steps: [
      'Buka menu Program dan pilih Latihan Mandiri.',
      'Tekan tambah dan buat program beserta sesi.',
      'Tambahkan gerakan dari database alat atau secara manual.',
      'Simpan dan centang exercise yang telah diselesaikan.',
    ],
    keywords: ['self training', 'exercise', 'gerakan'],
  ),
  HelpTopic(
    audience: HelpAudience.member,
    category: 'Progres Fisik',
    title: 'Cara membuat checkpoint progres fisik',
    steps: [
      'Buka Profil atau halaman Progres Fisik.',
      'Tambahkan checkpoint baru.',
      'Isi berat, tinggi, tanggal, milestone, catatan, serta foto Front, Side, dan Back jika tersedia.',
      'Simpan agar perkembangan fisik terdokumentasi.',
    ],
    keywords: ['progress', 'berat', 'tinggi', 'foto'],
  ),
  HelpTopic(
    audience: HelpAudience.member,
    category: 'Trainer',
    title: 'Cara memberi rating Trainer',
    steps: [
      'Selesaikan seluruh sesi dalam Program PT.',
      'Buka program yang telah selesai.',
      'Berikan rating dan ulasan satu kali untuk Program PT tersebut.',
    ],
    keywords: ['review', 'ulasan', 'bintang'],
  ),
  HelpTopic(
    audience: HelpAudience.member,
    category: 'Akun',
    title: 'Cara meminta bantuan ketika lupa password',
    steps: [
      'Aplikasi belum menyediakan reset password otomatis melalui email.',
      'Hubungi Admin Egg Gym secara langsung di tempat.',
      'Admin dapat membantu reset password melalui Web Admin.',
      'Setelah direset, login kembali menggunakan password baru.',
    ],
    keywords: ['lupa password', 'reset', 'tidak bisa login'],
  ),
  HelpTopic(
    audience: HelpAudience.member,
    category: 'Status & Notifikasi',
    title: 'Arti status booking dan pembayaran PT',
    steps: [
      'Menunggu Konfirmasi: booking menunggu keputusan Trainer.',
      'Dikonfirmasi atau Menunggu Pembayaran: Member perlu mengunggah bukti pembayaran.',
      'Menunggu Verifikasi atau Bukti Terkirim: Trainer sedang memeriksa bukti.',
      'Pembayaran Ditolak atau Bukti Ditolak: Member perlu mengunggah ulang bukti.',
      'Terverifikasi atau Pembayaran Valid: Trainer dapat membuat Program PT.',
      'Selesai: layanan telah selesai. Ditolak: booking ditolak. Expired: batas waktu telah lewat.',
    ],
    keywords: ['status', 'expired', 'ditolak', 'terverifikasi'],
  ),
  HelpTopic(
    audience: HelpAudience.trainer,
    category: 'Akun',
    title: 'Cara mengatur profil Trainer',
    steps: [
      'Buka menu Profil atau Pengaturan Akun.',
      'Isi spesialisasi, bio, pengalaman, sertifikasi, tarif, foto, dan informasi pembayaran.',
      'Simpan perubahan.',
    ],
    keywords: ['profil', 'bio', 'rekening', 'foto'],
  ),
  HelpTopic(
    audience: HelpAudience.trainer,
    category: 'Jadwal',
    title: 'Cara mengatur jadwal',
    steps: [
      'Buka menu Jadwal atau editor jadwal dari Profil.',
      'Atur hari dan shift yang tersedia.',
      'Satu shift diperlakukan sebagai satu slot booking penuh.',
      'Simpan jadwal dan atur tanggal tertentu jika diperlukan.',
    ],
    keywords: ['shift', 'availability', 'tanggal'],
  ),
  HelpTopic(
    audience: HelpAudience.trainer,
    category: 'Booking PT',
    title: 'Cara mengonfirmasi booking',
    steps: [
      'Buka menu Jadwal dan tab Menunggu.',
      'Pilih booking Member.',
      'Tekan Konfirmasi untuk menerima atau Tolak untuk menolak.',
      'Setelah dikonfirmasi, Member harus melakukan pembayaran dan mengunggah bukti.',
    ],
    keywords: ['permintaan', 'konfirmasi', 'tolak'],
  ),
  HelpTopic(
    audience: HelpAudience.trainer,
    category: 'Pembayaran',
    title: 'Cara memverifikasi pembayaran',
    steps: [
      'Buka tab Dikonfirmasi.',
      'Pilih booking dengan aksi Verifikasi Pembayaran.',
      'Cocokkan bukti dengan dana yang masuk.',
      'Tekan Valid jika benar atau Tolak dan isi alasan jika tidak valid.',
    ],
    keywords: ['bukti', 'transfer', 'valid'],
  ),
  HelpTopic(
    audience: HelpAudience.trainer,
    category: 'Booking PT',
    title: 'Cara merespons reschedule',
    steps: [
      'Buka tab Dikonfirmasi dan pilih permintaan reschedule masuk.',
      'Periksa jadwal lama dan jadwal baru.',
      'Tekan Terima Reschedule atau Tolak Reschedule.',
      'Jadwal diperbarui sesuai keputusan. Jadwal lama tetap berlaku sebelum diterima.',
    ],
    keywords: ['ubah jadwal', 'terima', 'tolak'],
  ),
  HelpTopic(
    audience: HelpAudience.trainer,
    category: 'Program Latihan',
    title: 'Cara membuat Program PT',
    steps: [
      'Pastikan pembayaran sesi PT sudah terverifikasi.',
      'Buka detail booking atau menu Program dan tekan Buat Program.',
      'Isi nama serta deskripsi program.',
      'Tambahkan sesi sesuai jumlah sesi yang dibeli Member, lalu tambahkan exercise.',
      'Simpan program.',
    ],
    keywords: ['program', 'member', 'payment verified'],
  ),
  HelpTopic(
    audience: HelpAudience.trainer,
    category: 'Program Latihan',
    title: 'Cara menambah exercise',
    steps: [
      'Pada sesi latihan, tekan tambah exercise.',
      'Pilih Database untuk memilih alat dan gerakan, atau pilih Tambah Manual.',
      'Jika memilih database, tentukan sets dan reps. Target otot mengikuti data movement.',
      'Simpan exercise pada sesi.',
    ],
    keywords: ['alat', 'movement', 'sets', 'reps'],
  ),
  HelpTopic(
    audience: HelpAudience.trainer,
    category: 'Program Latihan',
    title: 'Cara mencatat completed sets',
    steps: [
      'Pastikan Member telah menekan Mulai Sesi.',
      'Buka kontrol progres dan pilih sesi aktif.',
      'Catat jumlah set yang telah diselesaikan pada setiap exercise.',
      'Progres bertambah berdasarkan completed sets dan sesi berikutnya terbuka setelah sesi aktif selesai.',
    ],
    keywords: ['progres', 'checklist', 'progressive unlock'],
  ),
  HelpTopic(
    audience: HelpAudience.trainer,
    category: 'Status & Notifikasi',
    title: 'Arti badge merah Permintaan Booking',
    steps: [
      'Badge merah menunjukkan jumlah booking yang membutuhkan tindakan Trainer.',
      'Tab Menunggu menghitung booking baru yang perlu dikonfirmasi atau ditolak.',
      'Tab Dikonfirmasi menghitung verifikasi pembayaran, reschedule masuk, atau Program PT yang perlu dibuat setelah pembayaran valid.',
      'Buka tab yang memiliki badge dan selesaikan tindakan yang tersedia.',
    ],
    keywords: ['badge', 'notifikasi', 'aksi'],
  ),
  HelpTopic(
    audience: HelpAudience.trainer,
    category: 'Status & Notifikasi',
    title: 'Arti status pembayaran sesi PT',
    steps: [
      'Menunggu Pembayaran: Member belum mengunggah bukti.',
      'Bukti Terkirim: bukti menunggu verifikasi Trainer.',
      'Bukti Ditolak: Member perlu mengunggah ulang bukti.',
      'Pembayaran Valid: Program PT dapat dibuat.',
    ],
    keywords: ['status', 'bukti', 'valid', 'ditolak'],
  ),
];

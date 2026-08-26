import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/constants/trainer_specialties.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/public_storage_url.dart';
import 'package:egg_gym/core/utils/trainer_rating_display.dart';
import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:egg_gym/data/services/backend_rating_service.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:egg_gym/data/services/backend_trainer_availability_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/domain/entities/trainer_availability.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/trainer_review_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class TrainerProfileDetailPage extends StatefulWidget {
  const TrainerProfileDetailPage({super.key});

  @override
  State<TrainerProfileDetailPage> createState() =>
      _TrainerProfileDetailPageState();
}

class _TrainerProfileDetailPageState extends State<TrainerProfileDetailPage>
    with WidgetsBindingObserver {
  final BackendTrainerAvailabilityService _availabilityService =
      BackendTrainerAvailabilityService();
  final BackendMemberService _memberService = BackendMemberService();
  _ResolvedTrainerDetail? _detail;
  TrainerAvailability? _availability;
  String? _selectedCalendarDate;
  TrainerAvailabilityDate? _selectedAvailabilityDate;
  bool _isLoadingAvailability = false;
  String? _availabilityError;
  bool? _profileComplete;
  bool _isLoadingProfileStatus = false;
  ValueListenable<bool?>? _profileCompleteness;
  final BackendRatingService _ratingService = BackendRatingService();
  TrainerRatingSummary? _ratingSummary;
  bool _isLoadingRatings = false;
  bool _hasRatingError = false;

  bool get _canLoadAvailability =>
      (_detail?.source == 'member' || _detail?.source == 'guest') &&
      _detail?.isSelfProfile == false &&
      _detail?.trainer.backendId != null;

  bool get _canLoadMemberProfileStatus =>
      _detail?.source == 'member' &&
      _detail?.isSelfProfile == false &&
      _detail?.trainer.backendId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detail = _resolveTrainerDetail();
    final args = Get.arguments;
    if (args is Map && args['profileCompleteness'] is ValueListenable<bool?>) {
      _profileCompleteness =
          args['profileCompleteness'] as ValueListenable<bool?>;
      _profileComplete = _profileCompleteness!.value;
      _profileCompleteness!.addListener(_onProfileCompletenessChanged);
    }
    if (_canLoadAvailability) {
      _loadAvailability();
    }
    if (_canLoadMemberProfileStatus) {
      _loadProfileStatus();
    }
    if (_detail?.trainer.backendId != null) {
      _loadRatings();
    }
  }

  @override
  void dispose() {
    _profileCompleteness?.removeListener(_onProfileCompletenessChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _canLoadAvailability) {
      _loadAvailability(silent: _availability != null);
    }
    if (state == AppLifecycleState.resumed && _canLoadMemberProfileStatus) {
      _loadProfileStatus();
    }
  }

  void _onProfileCompletenessChanged() {
    if (mounted) {
      setState(() => _profileComplete = _profileCompleteness?.value);
    }
  }

  Future<void> _loadProfileStatus() async {
    if (_isLoadingProfileStatus) return;
    _isLoadingProfileStatus = true;
    try {
      final dashboard = await _memberService.getDashboard();
      if (!mounted) return;
      setState(() => _profileComplete = dashboard.profileComplete);
    } catch (_) {
      // Unknown/network error bukan berarti profil incomplete.
      if (mounted) setState(() => _profileComplete = null);
    } finally {
      _isLoadingProfileStatus = false;
    }
  }

  Future<void> _loadAvailability({bool silent = false}) async {
    final trainerId = _detail?.trainer.backendId;
    if (trainerId == null || _isLoadingAvailability) return;
    setState(() {
      _isLoadingAvailability = true;
      _availabilityError = null;
    });
    try {
      final availability =
          await _availabilityService.getAvailability(trainerId);
      if (!mounted) return;
      final selectedDate = _selectedAvailabilityDate?.date;
      TrainerAvailabilityDate? reconciledDate;
      for (final date in availability.dates) {
        if (date.date == selectedDate) {
          reconciledDate = date;
          break;
        }
      }
      final candidateCalendarDate = _selectedCalendarDate;
      final reconciledCalendarDate = candidateCalendarDate != null &&
              candidateCalendarDate.compareTo(availability.currentServerDate) >=
                  0 &&
              candidateCalendarDate.compareTo(availability.monthEndDate) <= 0
          ? candidateCalendarDate
          : availability.currentServerDate;
      if (reconciledDate?.date != reconciledCalendarDate) {
        reconciledDate =
            availability.dates.cast<TrainerAvailabilityDate?>().firstWhere(
                  (date) => date?.date == reconciledCalendarDate,
                  orElse: () => null,
                );
      }
      setState(() {
        _availability = availability;
        _selectedCalendarDate = reconciledCalendarDate;
        _selectedAvailabilityDate = reconciledDate;
        _isLoadingAvailability = false;
        _availabilityError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingAvailability = false;
        _availabilityError = 'Gagal memuat jadwal tersedia.';
      });
    }
  }

  Future<void> _loadRatings() async {
    final trainerId = _detail?.trainer.backendId;
    if (trainerId == null || _isLoadingRatings) return;
    setState(() {
      _isLoadingRatings = true;
      _hasRatingError = false;
    });
    try {
      final summary = await _ratingService.getTrainerRatings(trainerId);
      if (!mounted) return;
      setState(() {
        _ratingSummary = summary;
        _isLoadingRatings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingRatings = false;
        _hasRatingError = true;
      });
    }
  }

  _ResolvedTrainerDetail? _resolveTrainerDetail() {
    final argument = Get.arguments;
    TrainerProfile? trainer;
    var source = 'member';
    var isSelfProfile = false;
    var hasActivePtEngagement = false;
    String? activePtStatus;
    String? activePtTrainerName;

    if (argument is TrainerProfile) {
      trainer = argument;
    } else if (argument is Map<String, dynamic>) {
      final mappedTrainer = argument['trainer'];
      if (mappedTrainer is TrainerProfile) {
        trainer = mappedTrainer;
      }
      final mappedSource = argument['source'];
      if (mappedSource is String && mappedSource.isNotEmpty) {
        source = mappedSource;
      }
      final mappedSelfProfile = argument['isSelfProfile'];
      if (mappedSelfProfile is bool) {
        isSelfProfile = mappedSelfProfile;
      }
      if (argument['hasActivePtEngagement'] is bool) {
        hasActivePtEngagement = argument['hasActivePtEngagement'] as bool;
      }
      final mappedStatus = argument['activePtStatus'];
      if (mappedStatus is String && mappedStatus.isNotEmpty) {
        activePtStatus = mappedStatus;
      }
      final mappedTrainerName = argument['activePtTrainerName'];
      if (mappedTrainerName is String && mappedTrainerName.isNotEmpty) {
        activePtTrainerName = mappedTrainerName;
      }
    }

    if (trainer == null) return null;

    return _ResolvedTrainerDetail(
      trainer: trainer,
      source: source,
      isSelfProfile: isSelfProfile,
      hasActivePtEngagement: hasActivePtEngagement,
      activePtStatus: activePtStatus,
      activePtTrainerName: activePtTrainerName,
    );
  }

  Future<void> _onPrimaryAction(_ResolvedTrainerDetail detail) async {
    if (detail.isSelfProfile) {
      Get.toNamed(
        AppRoutes.trainerAccountSettings,
        arguments: {
          'trainer': detail.trainer,
        },
      );
      return;
    }

    if (detail.source == 'guest') {
      Get.offAllNamed(AppRoutes.login);
      return;
    }

    final created = await Get.toNamed(
      AppRoutes.memberBookingForm,
      arguments: <String, dynamic>{
        'trainer': detail.trainer,
        'trainerProfileId': detail.trainer.backendId,
        if (_selectedAvailabilityDate != null)
          'availabilityDateHint': _selectedAvailabilityDate!.date,
      },
    );
    if (created == true && mounted) {
      await _loadAvailability(silent: true);
    }
  }

  void _onSecondaryAction(_ResolvedTrainerDetail detail) {
    if (detail.isSelfProfile) {
      Get.toNamed(
        AppRoutes.trainerShareProfile,
        arguments: {
          'trainer': detail.trainer,
        },
      );
      return;
    }

    Get.toNamed(
      AppRoutes.membershipPackages,
      arguments: {
        'source': detail.source == 'guest' ? 'guest' : 'member',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail == null) return const _InvalidTrainerDetailPage();
    final trainer = detail.trainer;

    if (detail.source == 'guest') {
      return _buildGuestDetail(context, trainer);
    }

    final primaryLabel = detail.isSelfProfile
        ? 'Pengaturan Akun'
        : detail.source == 'guest'
            ? 'Login untuk Booking'
            : 'Booking Sesi';
    final secondaryLabel =
        detail.isSelfProfile ? 'Bagikan Profil' : 'Lihat Paket Member';

    // Booking Sesi dinonaktifkan bila member (bukan guest/self):
    // (1) sedang punya engagement PT aktif, ATAU
    // (2) kuota trainer ini sudah penuh.
    final isBookableContext = !detail.isSelfProfile && detail.source != 'guest';
    final profileIncomplete = isBookableContext && _profileComplete == false;
    final scheduleUnavailable =
        isBookableContext && !detail.trainer.hasActiveSchedule;
    final quotaFull = isBookableContext && !detail.trainer.isAvailable;
    final bookingDisabled = isBookableContext &&
        (profileIncomplete ||
            scheduleUnavailable ||
            detail.hasActivePtEngagement ||
            quotaFull);

    return DecoratedScreen(
      child: RefreshIndicator(
        onRefresh: () => _canLoadAvailability
            ? Future.wait([
                _loadAvailability(silent: true),
                _loadProfileStatus(),
                _loadRatings(),
              ])
            : _loadRatings(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // (1) Hero foto image-dominant full-width (edge-to-edge).
            _TrainerHeroSection(
              trainer: trainer,
              ratingDisplay: _memberRatingDisplay,
              onBack: () => Get.back(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // (2) Supra-label "THE SPECIALIST" + bio nyata (ganti "Coach Profile").
                  _InfoSectionCard(
                    title: 'THE SPECIALIST',
                    child: Text(
                      trainer.bio,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // (3) Baris statistik horizontal — HANYA stat NYATA:
                  // Experience (dari experience_years backend) + Active Clients
                  // (dari activeMembers). Success Rate & Response DIHAPUS (tidak ada
                  // datanya di backend -- lihat CHANGELOG).
                  _RealStatsRow(trainer: trainer),
                  const SizedBox(height: 18),
                  if (_canLoadAvailability) ...[
                    _AvailabilitySection(
                      availability: _availability,
                      selectedCalendarDate: _selectedCalendarDate,
                      selectedDate: _selectedAvailabilityDate,
                      isLoading: _isLoadingAvailability,
                      error: _availabilityError,
                      onRetry: _loadAvailability,
                      onSelected: (calendarDate, occurrence) {
                        setState(() {
                          _selectedCalendarDate = calendarDate;
                          _selectedAvailabilityDate = occurrence;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                  // (5) "Session Offers" DIHAPUS: konten hardcode tanpa data nyata.
                  // (6) "Certifications & Highlights" & "Specializations" DIHAPUS:
                  //     hardcode; specialty nyata sudah tampil sebagai tags di hero.
                  if (trainer.backendId != null) ...[
                    const SizedBox(height: 18),
                    _TrainerReviewsSection(
                      trainerName: trainer.name,
                      summary: _ratingSummary,
                      isLoading: _isLoadingRatings,
                      hasError: _hasRatingError,
                      onRetry: _loadRatings,
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (detail.isSelfProfile)
                    // Trainer melihat profilnya sendiri: Pengaturan Akun + Bagikan Profil.
                    Row(
                      children: [
                        Expanded(
                          child: EggButton.secondary(
                            label: secondaryLabel,
                            onPressed: () => _onSecondaryAction(detail),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: EggButton.primary(
                            label: primaryLabel,
                            onPressed: () => _onPrimaryAction(detail),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    // Member/guest: hanya tombol Booking Sesi (tanpa Lihat Paket Member).
                    SizedBox(
                      width: double.infinity,
                      child: EggButton.primary(
                        label: primaryLabel,
                        onPressed: bookingDisabled
                            ? null
                            : () => _onPrimaryAction(detail),
                      ),
                    ),
                    if (bookingDisabled) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_clock_rounded,
                                size: 16, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                profileIncomplete
                                    ? 'Lengkapi data profil (TB, BB, dan Target) terlebih dahulu sebelum booking.'
                                    : scheduleUnavailable
                                        ? 'Trainer ini belum memiliki jadwal booking yang tersedia.'
                                        : quotaFull
                                            ? 'Kuota trainer ini sedang penuh (maksimal ${detail.trainer.maxMembers} member aktif). Silakan pilih trainer lain.'
                                            : _engagementMessage(detail),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ], // tutup Column children (konten di bawah hero)
              ), // tutup Column
            ), // tutup Padding
          ], // tutup ListView children
        ),
      ),
    );
  }

  Widget _buildGuestDetail(BuildContext context, TrainerProfile trainer) {
    return DecoratedScreen(
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => Future.wait([
          _loadAvailability(silent: true),
          _loadRatings(),
        ]),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _GuestTrainerHeader(onBack: () => Get.back()),
            _GuestTrainerHero(trainer: trainer),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GuestSpecialtyAndRating(
                    trainer: trainer,
                    ratingDisplay: _guestRatingDisplay(trainer),
                  ),
                  const SizedBox(height: 24),
                  _GuestSection(
                    title: 'BIO',
                    child: Text(
                      _guestBio(trainer.bio),
                      style: const TextStyle(
                        color: Color(0xFFC4BDAE),
                        fontSize: 13,
                        height: 1.65,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _GuestAvailabilityPreview(
                    availability: _availability,
                    isLoading: _isLoadingAvailability,
                    error: _availabilityError,
                    onRetry: _loadAvailability,
                  ),
                  const SizedBox(height: 24),
                  _GuestPricingCard(trainer: trainer),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: () => Get.offAllNamed(AppRoutes.login),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'Pesan Sesi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'LOGIN SEBAGAI MEMBER UNTUK MEMESAN SESI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8F866E),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _memberRatingDisplay {
    if (_isLoadingRatings) return 'Memuat rating...';
    if (_hasRatingError || _ratingSummary == null) {
      return 'Rating tidak tersedia';
    }
    return trainerRatingDisplay(
      rating: _ratingSummary!.averageRating,
      reviewsCount: _ratingSummary!.reviewsCount,
    );
  }

  String _guestRatingDisplay(TrainerProfile trainer) {
    final summary = _ratingSummary;
    return trainerRatingDisplay(
      rating: summary?.averageRating ?? trainer.rating,
      reviewsCount: summary?.reviewsCount ?? trainer.reviewsCount,
    );
  }

  String _guestBio(String value) {
    final normalized = value.trim();
    return normalized.isEmpty || normalized == '-'
        ? 'Belum ada bio trainer.'
        : normalized;
  }

  /// Pesan kontekstual saat tombol Booking Sesi dinonaktifkan karena member
  /// sedang punya booking/engagement PT aktif.
  String _engagementMessage(_ResolvedTrainerDetail detail) {
    final coach = _coachLabel(detail.activePtTrainerName);

    switch (detail.activePtStatus) {
      case 'pending':
      case 'rescheduled':
        return 'Kamu sedang menunggu konfirmasi dari $coach. Selesaikan proses ini terlebih dahulu.';
      case 'waiting_payment':
        return 'Kamu memiliki tagihan pembayaran yang belum diselesaikan dengan $coach. Selesaikan pembayaran terlebih dahulu.';
      case 'payment_uploaded':
        return 'Pembayaran kamu sedang diverifikasi oleh $coach. Tunggu konfirmasi dari trainer.';
      case 'payment_verified':
      case 'confirmed':
        return 'Kamu sedang dalam sesi PT aktif dengan $coach. Selesaikan program dan beri rating terlebih dahulu.';
      default:
        return 'Kamu sedang dalam sesi PT aktif dengan $coach. Selesaikan program dan beri rating terlebih dahulu.';
    }
  }

  /// Bangun label "Coach X" tanpa menggandakan prefix bila nama sudah
  /// berawalan "Coach".
  String _coachLabel(String? trainerName) {
    final name = trainerName?.trim();
    if (name == null || name.isEmpty) {
      return 'trainer kamu';
    }
    if (name.toLowerCase().startsWith('coach')) {
      return name;
    }
    return 'Coach $name';
  }
}

/// Baris statistik horizontal — HANYA stat yang punya data NYATA.
/// Baris statistik 3 kotak (EXP YEARS / ACTIVE CLIENTS / CERTS), semua dari
/// data NYATA. EXP YEARS dari `experienceYears`; ACTIVE CLIENTS dari
/// `servedClientsCount` (member yang sudah/sedang dilayani; fallback ke
/// `activeMembers` bila field backend belum tersedia); CERTS dari jumlah item
/// hasil split koma `certifications` (0 bila kosong). Dipisah garis vertikal.
class _RealStatsRow extends StatelessWidget {
  const _RealStatsRow({required this.trainer});

  final TrainerProfile trainer;

  @override
  Widget build(BuildContext context) {
    // ACTIVE CLIENTS: pakai servedClientsCount (definisi baru) begitu tersedia
    // dari backend; sementara fallback ke activeMembers agar tidak menampilkan
    // "0" palsu sebelum computed field backend ada.
    final activeClients = trainer.servedClientsCount ?? trainer.activeMembers;
    final stats = <({String label, String value})>[
      (label: 'EXP YEARS', value: '${trainer.experienceYears ?? 0}'),
      (label: 'ACTIVE CLIENTS', value: '$activeClients'),
      (label: 'CERTS', value: '${trainer.certificationCount}'),
    ];

    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      children.add(Expanded(
        child: Column(
          children: [
            Text(
              stats[i].value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stats[i].label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: Color(0xFF9A9A9A),
              ),
            ),
          ],
        ),
      ));
      if (i < stats.length - 1) {
        children.add(Container(
          width: 1,
          height: 36,
          color: const Color(0xFF262626),
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(children: children),
    );
  }
}

class _AvailabilitySection extends StatelessWidget {
  const _AvailabilitySection({
    required this.availability,
    required this.selectedCalendarDate,
    required this.selectedDate,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.onSelected,
  });

  final TrainerAvailability? availability;
  final String? selectedCalendarDate;
  final TrainerAvailabilityDate? selectedDate;
  final bool isLoading;
  final String? error;
  final Future<void> Function({bool silent}) onRetry;
  final void Function(String date, TrainerAvailabilityDate? occurrence)
      onSelected;

  @override
  Widget build(BuildContext context) {
    return _InfoSectionCard(
      title: 'JADWAL TERSEDIA',
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading && availability == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && availability == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => onRetry(),
            child: const Text('Coba Lagi'),
          ),
        ],
      );
    }
    final data = availability;
    final weekdays = data?.weekdays ?? const <TrainerAvailabilityWeekday>[];
    if (weekdays.isEmpty) return const SizedBox.shrink();
    final calendarDates = _calendarDates(data!);
    final selectedRawDate = selectedCalendarDate ?? data.currentServerDate;
    final selectedParsedDate = DateTime.tryParse(selectedRawDate);
    final selectedWeekday = weekdays.firstWhere(
      (day) => day.dayOfWeek == selectedParsedDate?.weekday,
      orElse: () => weekdays.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null) ...[
          Text(
            '$error Menampilkan jadwal terakhir.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
          ),
          const SizedBox(height: 8),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: calendarDates.map((date) {
              final rawDate = _isoDate(date);
              final selected = rawDate == selectedRawDate;
              final weekday = weekdays.firstWhere(
                (day) => day.dayOfWeek == date.weekday,
              );
              final occurrence = weekday.occurrences
                  .cast<TrainerAvailabilityDate?>()
                  .firstWhere(
                    (item) => item?.date == rawDate,
                    orElse: () => null,
                  );
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  onSelected: (_) => onSelected(rawDate, occurrence),
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_shortDay(weekday.dayName)),
                      const SizedBox(height: 2),
                      Text('${date.day}'),
                    ],
                  ),
                  labelStyle: TextStyle(
                    color:
                        selected ? AppColors.background : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surfaceSoft,
                  side: BorderSide(color: AppColors.divider),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        if (!selectedWeekday.scheduleEnabled)
          Text(
            'Tidak ada jadwal untuk hari ini.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          )
        else if (selectedDate == null)
          Text(
            'Tidak ada slot tersedia untuk tanggal ini.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedDate!.slots.map((slot) {
              return Chip(
                label: Text(
                  '${_displayTime(slot.startTime)} - ${_displayTime(slot.endTime)}',
                ),
                backgroundColor: slot.isAvailable
                    ? AppColors.surfaceSoft
                    : AppColors.divider.withValues(alpha: 0.35),
                labelStyle: TextStyle(
                  color: slot.isAvailable
                      ? AppColors.textPrimary
                      : AppColors.textSecondary.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(color: AppColors.divider),
              );
            }).toList(),
          ),
          if (selectedDate!.slots.isEmpty &&
              selectedDate!.date == data.currentServerDate &&
              selectedDate!.effectiveShifts.isNotEmpty) ...[
            Text(
              'Slot hari ini sudah lewat batas waktu pemesanan (minimal ${data.leadTimeMinutes ~/ 60} jam sebelum sesi).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ],
    );
  }

  String _displayTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return value;
    return '${parts[0]}.${parts[1]}';
  }

  String _shortDay(String value) {
    const labels = <String, String>{
      'Monday': 'SEN',
      'Tuesday': 'SEL',
      'Wednesday': 'RAB',
      'Thursday': 'KAM',
      'Friday': 'JUM',
      'Saturday': 'SAB',
      'Sunday': 'MIN',
    };
    return labels[value] ?? value.substring(0, 3).toUpperCase();
  }

  List<DateTime> _calendarDates(TrainerAvailability data) {
    final start = DateTime.tryParse(data.currentServerDate);
    final end = DateTime.tryParse(data.monthEndDate);
    if (start == null || end == null || end.isBefore(start)) return const [];
    return [
      for (var date = start;
          !date.isAfter(end);
          date = date.add(const Duration(days: 1)))
        date,
    ];
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Hero foto image-dominant Trainer Detail (spec Figma).
///
/// Foto memakai urutan display photo -> avatar -> initial. Overlay: back button,
/// badge rating, nama, dan specialty dari object public trainer yang sama dengan card.
class _TrainerHeroSection extends StatelessWidget {
  const _TrainerHeroSection({
    required this.trainer,
    required this.ratingDisplay,
    required this.onBack,
  });

  final TrainerProfile trainer;
  final String ratingDisplay;
  final VoidCallback onBack;

  String get _initials {
    final trimmed = trainer.name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.take(2).map((w) => w[0]).join().toUpperCase();
  }

  // Specialty canonical selalu tampil sebagai satu label utuh; karakter `&`
  // adalah bagian resmi dari beberapa label dan tidak boleh dipecah.
  List<String> get _tags {
    return trainer.specialtyLabels
        .where((value) => value.trim().isNotEmpty && value != '-')
        .toList(growable: false);
  }

  Widget _buildPhoto() {
    final displayUrl = resolvePublicStorageUrl(trainer.displayPhotoPath);
    final avatarUrl = resolvePublicStorageUrl(trainer.avatarUrl);
    final initialFallback = ColoredBox(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
    );

    Widget avatarOrInitial() => avatarUrl == null
        ? initialFallback
        : Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => initialFallback,
          );

    return displayUrl == null
        ? avatarOrInitial()
        : Image.network(
            displayUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => avatarOrInitial(),
          );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final tags = _tags;
    final tierLabel = trainerTierLabel(trainer.tier);

    return SizedBox(
      height: 420,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildPhoto(),
          // Gradient overlay bawah agar teks terbaca.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.35, 1.0],
                colors: [Colors.transparent, Color(0xF20E0E0E)],
              ),
            ),
          ),
          // Overlay atas: back button + badge rating (data nyata).
          Positioned(
            top: topInset + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _CircleIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack,
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        ratingDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Overlay bawah: nama + tags dari specialty nyata.
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tierLabel != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tierLabel,
                      key: const Key('member-trainer-detail-tier'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: AppColors.background,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  trainer.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.5,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                t.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF0E0E0E),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestTrainerHeader extends StatelessWidget {
  const _GuestTrainerHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: const Color(0xFF151515),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, topInset + 8, 16, 10),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
              tooltip: 'Kembali',
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'TRAINER DETAIL',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => Get.offAllNamed(AppRoutes.login),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: Color(0xFF6A5810)),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Text('Masuk'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestTrainerHero extends StatelessWidget {
  const _GuestTrainerHero({required this.trainer});

  final TrainerProfile trainer;

  @override
  Widget build(BuildContext context) {
    final displayUrl = resolvePublicStorageUrl(trainer.displayPhotoPath);
    final avatarUrl = resolvePublicStorageUrl(trainer.avatarUrl);
    final tierLabel = trainerTierLabel(trainer.tier);

    Widget fallback() => ColoredBox(
          color: const Color(0xFF1A1A1A),
          child: Center(
            child: Text(
              _trainerInitials(trainer.name),
              style: TextStyle(
                color: AppColors.accent.withValues(alpha: 0.18),
                fontSize: 96,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );

    Widget avatarOrFallback() => avatarUrl == null
        ? fallback()
        : Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          );

    final photo = displayUrl == null
        ? avatarOrFallback()
        : Image.network(
            displayUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => avatarOrFallback(),
          );

    return AspectRatio(
      aspectRatio: 0.88,
      child: Stack(
        fit: StackFit.expand,
        children: [
          photo,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.35, 0.72, 1],
                colors: [
                  Colors.transparent,
                  Color(0x99101010),
                  Color(0xFF101010),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tierLabel != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$tierLabel TRAINER',
                      style: const TextStyle(
                        color: AppColors.background,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Text(
                  trainer.name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    height: 1.03,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
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

class _GuestSpecialtyAndRating extends StatelessWidget {
  const _GuestSpecialtyAndRating({
    required this.trainer,
    required this.ratingDisplay,
  });

  final TrainerProfile trainer;
  final String ratingDisplay;

  @override
  Widget build(BuildContext context) {
    final specialties = trainer.specialtyLabels
        .map(TrainerSpecialties.displayLabel)
        .where((item) => item.trim().isNotEmpty && item != '-')
        .toList(growable: false);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GuestEyebrow(label: 'SPECIALIZATION'),
              const SizedBox(height: 10),
              if (specialties.isEmpty)
                const Text(
                  'Belum ada spesialisasi',
                  style: TextStyle(color: Color(0xFFA8A08E), fontSize: 12),
                )
              else
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: specialties
                      .map((label) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF292929),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Color(0xFFD7D0C2),
                                fontSize: 10,
                              ),
                            ),
                          ))
                      .toList(growable: false),
                ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Flexible(
          child: _GuestMetric(
            label: 'RATING',
            value: ratingDisplay,
            showStar: true,
          ),
        ),
      ],
    );
  }
}

class _GuestMetric extends StatelessWidget {
  const _GuestMetric({
    required this.label,
    required this.value,
    this.showStar = false,
  });

  final String label;
  final String value;
  final bool showStar;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuestEyebrow(label: label),
          const SizedBox(height: 7),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (showStar) ...[
                const SizedBox(width: 3),
                const Icon(Icons.star_rounded,
                    color: AppColors.accent, size: 16),
              ],
            ],
          ),
        ],
      );
}

class _GuestSection extends StatelessWidget {
  const _GuestSection(
      {required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 28, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      );
}

class _GuestAvailabilityPreview extends StatelessWidget {
  const _GuestAvailabilityPreview({
    required this.availability,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final TrainerAvailability? availability;
  final bool isLoading;
  final String? error;
  final Future<void> Function({bool silent}) onRetry;

  @override
  Widget build(BuildContext context) {
    final data = availability;
    final dates = data?.dates
            .where((date) => date.slots.any((slot) => slot.isAvailable))
            .take(5)
            .toList(growable: false) ??
        const <TrainerAvailabilityDate>[];
    return _GuestSection(
      title: 'JADWAL TERSEDIA',
      trailing: data == null
          ? null
          : Text(
              data.timezone.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF817965),
                fontSize: 8,
                letterSpacing: 0.6,
              ),
            ),
      child: Builder(builder: (context) {
        if (isLoading && data == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }
        if (error != null && data == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Jadwal belum dapat dimuat.',
                style: TextStyle(color: Color(0xFFA8A08E), fontSize: 12),
              ),
              TextButton(
                onPressed: () => onRetry(),
                child: const Text('Coba Lagi'),
              ),
            ],
          );
        }
        if (dates.isEmpty) {
          return const Text(
            'Belum ada jadwal tersedia.',
            style: TextStyle(color: Color(0xFFA8A08E), fontSize: 12),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: dates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (_, index) {
                  final date = dates[index];
                  return Container(
                    width: 66,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: index == 0
                          ? AppColors.accent
                          : const Color(0xFF292929),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          AppDateFormatter.date(
                            date.date,
                            includeWeekday: true,
                            includeYear: false,
                            abbreviatedMonth: true,
                          ).split(' ').first.toUpperCase(),
                          style: TextStyle(
                            color: index == 0
                                ? AppColors.background
                                : const Color(0xFFD0C8B8),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateTime.tryParse(date.date)?.day.toString() ?? '-',
                          style: TextStyle(
                            color: index == 0
                                ? AppColors.background
                                : Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: dates
                  .expand(
                      (date) => date.slots.where((slot) => slot.isAvailable))
                  .take(6)
                  .map((slot) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF292929),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '${AppDateFormatter.time(slot.startTime)} - ${AppDateFormatter.time(slot.endTime)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ))
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            const Text(
              'Preview jadwal. Login sebagai member untuk memilih dan memesan slot.',
              style: TextStyle(
                color: Color(0xFF817965),
                fontSize: 9,
                height: 1.4,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _GuestPricingCard extends StatelessWidget {
  const _GuestPricingCard({required this.trainer});

  final TrainerProfile trainer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF292929),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF343434)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _GuestEyebrow(label: 'PRICING'),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _rupiah(trainer.pricePerSession),
                    style: TextStyle(
                      color: trainer.pricePerSession == null
                          ? const Color(0xFFD0C8B8)
                          : AppColors.accent,
                      fontSize: trainer.pricePerSession == null ? 17 : 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (trainer.pricePerSession != null)
                    const TextSpan(
                      text: ' / sesi',
                      style: TextStyle(
                        color: Color(0xFFA8A08E),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 19),
            const _GuestPriceInfo(
              icon: Icons.fitness_center_rounded,
              label: 'Sesi personal trainer',
            ),
            const SizedBox(height: 12),
            const _GuestPriceInfo(
              icon: Icons.schedule_rounded,
              label: 'Durasi mengikuti jadwal trainer',
            ),
            const SizedBox(height: 12),
            const _GuestPriceInfo(
              icon: Icons.location_on_outlined,
              label: 'Lokasi mengikuti slot yang tersedia',
            ),
          ],
        ),
      );

  String _rupiah(double? value) {
    if (value == null || value <= 0) return 'Harga belum tersedia';
    final digits = value.round().toString();
    final output = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) output.write('.');
      output.write(digits[i]);
    }
    return 'Rp $output';
  }
}

class _GuestPriceInfo extends StatelessWidget {
  const _GuestPriceInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 18),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFD1CABB),
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
}

class _GuestEyebrow extends StatelessWidget {
  const _GuestEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: Color(0xFF9B927D),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      );
}

String _trainerInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2);
  final result = words.map((word) => word[0]).join().toUpperCase();
  return result.isEmpty ? '?' : result;
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _InvalidTrainerDetailPage extends StatelessWidget {
  const _InvalidTrainerDetailPage();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: Get.back,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Trainer Detail'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Data trainer tidak valid.',
              key: Key('invalid-trainer-detail'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}

class _ResolvedTrainerDetail {
  const _ResolvedTrainerDetail({
    required this.trainer,
    required this.source,
    required this.isSelfProfile,
    this.hasActivePtEngagement = false,
    this.activePtStatus,
    this.activePtTrainerName,
  });

  final TrainerProfile trainer;
  final String source;
  final bool isSelfProfile;
  final bool hasActivePtEngagement;
  final String? activePtStatus;
  final String? activePtTrainerName;
}

class _InfoSectionCard extends StatelessWidget {
  const _InfoSectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;

  /// Widget opsional di pojok kanan atas, sejajar judul (mis. link "SEE ALL").
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Seksi testimoni memakai summary yang sama dengan hero sebagai satu authority.
class _TrainerReviewsSection extends StatelessWidget {
  const _TrainerReviewsSection({
    required this.trainerName,
    required this.summary,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  final String trainerName;
  final TrainerRatingSummary? summary;
  final bool isLoading;
  final bool hasError;
  final Future<void> Function() onRetry;

  /// Review berkomentar teks, diurutkan TERBARU dulu berdasarkan createdAt
  /// (null diperlakukan paling lama; bila semua null, urutan data dipertahankan).
  List<TrainerRatingData> _sortedReviews() {
    final currentSummary = summary;
    if (currentSummary == null) return const [];
    final list = currentSummary.reviews
        .where((r) => r.testimonial != null && r.testimonial!.isNotEmpty)
        .toList();
    list.sort((a, b) {
      final da = a.createdAt;
      final db = b.createdAt;
      if (da == null && db == null) return 0;
      if (da == null) return 1; // null -> paling belakang (paling lama)
      if (db == null) return -1;
      return db.compareTo(da); // terbaru dulu
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _sortedReviews();
    // SEE ALL hanya tampil bila ada > 2 review (ada yang perlu dilihat lagi).
    final showSeeAll = reviews.length > 2;
    return _InfoSectionCard(
      title: 'RECENT FEEDBACK',
      trailing: showSeeAll
          ? GestureDetector(
              onTap: () => Get.toNamed(
                AppRoutes.trainerAllReviews,
                arguments: {
                  'trainerName': trainerName,
                  'reviews': reviews,
                },
              ),
              child: Text(
                'SEE ALL',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
              ),
            )
          : null,
      child: _buildBody(context, reviews),
    );
  }

  Widget _buildBody(BuildContext context, List<TrainerRatingData> reviews) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'Gagal memuat ulasan.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      );
    }

    final currentSummary = summary;
    if (currentSummary == null || currentSummary.reviewsCount == 0) {
      return Text(
        'Belum ada ulasan. Jadilah member pertama yang memberi rating setelah program selesai.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
      );
    }

    // Ringkasan rata-rata TIDAK ditampilkan di sini — sudah ada di badge hero
    // atas (★ 4.7 (N reviews)). Ada rating tapi tak ada komentar teks:
    if (reviews.isEmpty) {
      return Text(
        'Belum ada komentar tertulis dari member.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
      );
    }

    // Tampilkan maksimal 2 kartu (terbaru dulu). Selebihnya via "SEE ALL".
    final visible = reviews.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visible.map((r) => TrainerReviewTile(review: r)),
      ],
    );
  }
}

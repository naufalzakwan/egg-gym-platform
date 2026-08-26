import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/core/utils/trainer_rating_display.dart';
import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:egg_gym/data/services/backend_booking_service.dart';
import 'package:egg_gym/data/services/backend_trainer_availability_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/domain/entities/trainer_availability.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:egg_gym/presentation/controllers/member_shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum _MembershipRequiredAction { back, viewPackages }

class MemberBookingFormPage extends StatefulWidget {
  const MemberBookingFormPage({super.key});

  @override
  State<MemberBookingFormPage> createState() => _MemberBookingFormPageState();
}

class _MemberBookingFormPageState extends State<MemberBookingFormPage>
    with WidgetsBindingObserver {
  final BackendBookingService _bookingService = BackendBookingService();
  final BackendTrainerAvailabilityService _availabilityService =
      BackendTrainerAvailabilityService();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingAvailability = false;
  bool _isCheckingMembership = true;
  bool _hasActiveMembership = false;
  bool _isMembershipDialogVisible = false;
  String? _errorMessage;
  String? _availabilityError;
  TrainerProfile? _trainer;
  int? _trainerProfileId;
  TrainerAvailability? _availability;
  int _sessionCount = 1;
  List<_ManualSessionSelection> _sessionSelections = [
    const _ManualSessionSelection(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolveArguments();
    _checkMembership();
  }

  void _resolveArguments() {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final trainer = argument['trainer'];
      if (trainer is TrainerProfile) {
        _trainer = trainer;
      }
      final trainerId = argument['trainerProfileId'];
      if (trainerId is int) {
        _trainerProfileId = trainerId;
      } else if (trainerId != null) {
        _trainerProfileId = int.tryParse(trainerId.toString());
      }
    }
  }

  Future<void> _checkMembership() async {
    try {
      final hasActive = await _bookingService.checkActiveMembership();
      if (!mounted) return;
      setState(() {
        _hasActiveMembership = hasActive;
        _isCheckingMembership = false;
      });

      if (!hasActive) {
        await _showMembershipRequiredDialog();
      } else {
        await _loadAvailability();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isCheckingMembership = false;
        _hasActiveMembership = false;
      });
      await _showMembershipRequiredDialog();
    }
  }

  Future<void> _showMembershipRequiredDialog() async {
    if (!mounted || _isMembershipDialogVisible) return;
    setState(() => _isMembershipDialogVisible = true);

    final action = await showDialog<_MembershipRequiredAction>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      barrierLabel: 'Membership diperlukan',
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        elevation: 24,
        shadowColor: Colors.black,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            const Icon(Icons.card_membership_rounded, color: AppColors.accent),
            const SizedBox(width: 10),
            Text(
              'Membership Diperlukan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        content: Text(
          'Anda harus memiliki membership aktif sebelum bisa memesan sesi Personal Trainer. Silakan pilih paket membership terlebih dahulu.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
              rootNavigator: true,
            ).pop(_MembershipRequiredAction.back),
            child: Text(
              'Kembali',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(
              dialogContext,
              rootNavigator: true,
            ).pop(_MembershipRequiredAction.viewPackages),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Lihat Paket Membership'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == _MembershipRequiredAction.viewPackages) {
      Get.offNamed(
        AppRoutes.membershipPackages,
        arguments: const {'source': 'member'},
      );
      return;
    }

    // Route ini hanya form booking. Jika membership tidak aktif dan user memilih
    // Kembali, tutup route form satu kali agar kembali ke halaman pemicu booking.
    Get.back();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasActiveMembership) {
      _loadAvailability(silent: _availability != null);
    }
  }

  Future<void> _loadAvailability({bool silent = false}) async {
    final trainerId = _trainerProfileId;
    if (trainerId == null || _isLoadingAvailability) return;
    setState(() {
      _isLoadingAvailability = true;
      _availabilityError = null;
    });
    try {
      final availability =
          await _availabilityService.getAvailability(trainerId);
      if (!mounted) return;
      setState(() {
        _availability = availability;
        _sessionSelections = _reconcileSelections(availability);
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

  Future<void> _submitBooking() async {
    if (_isLoading) return;

    if (_trainerProfileId == null) {
      setState(() => _errorMessage = 'Trainer tidak valid.');
      return;
    }
    if (_availableDateCount < _sessionCount) {
      setState(() => _errorMessage = _insufficientSlotsMessage);
      return;
    }
    if (_hasInvalidSessionDates) {
      setState(() => _errorMessage =
          'Tanggal setiap sesi harus berbeda dan berurutan maju.');
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Judul sesi wajib diisi.');
      return;
    }

    if (_sessionSelections.length != _sessionCount ||
        _sessionSelections.any((selection) => !selection.isComplete)) {
      setState(() => _errorMessage =
          'Pilih tanggal dan waktu untuk seluruh $_sessionCount sesi.');
      return;
    }

    final pricePerSession = _trainer?.pricePerSession;
    if (pricePerSession == null || pricePerSession <= 0) {
      setState(() => _errorMessage =
          'Trainer belum mengatur harga per sesi. Booking belum dapat dibuat.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fresh =
          await _availabilityService.getAvailability(_trainerProfileId!);
      final freshSelections = <BookingReservationSelection>[];
      var allStillAvailable = true;
      for (final selection in _sessionSelections) {
        TrainerAvailabilitySlot? freshSlot;
        for (final date in fresh.dates) {
          if (date.date == selection.date) {
            for (final slot in date.slots) {
              if (slot.key == selection.slotKey && slot.isAvailable) {
                freshSlot = slot;
                break;
              }
            }
          }
        }
        if (freshSlot == null) {
          allStillAvailable = false;
          break;
        }
        freshSelections.add(BookingReservationSelection(
          sessionDate: selection.date!,
          startTime: freshSlot.startTime,
          endTime: freshSlot.endTime,
        ));
      }
      if (!allStillAvailable) {
        setState(() {
          _availability = fresh;
          _sessionSelections = _reconcileSelections(fresh);
          _isLoading = false;
          _errorMessage =
              'Salah satu slot tidak lagi tersedia. Silakan pilih ulang.';
        });
        return;
      }
      final result = await _bookingService.createBooking(
        trainerProfileId: _trainerProfileId!,
        sessionTitle: _titleController.text.trim(),
        location: 'Egg Gym Pontianak',
        sessionCount: _sessionCount,
        reservations: freshSelections,
        memberNote: _noteController.text.trim(),
      );

      if (!mounted) return;

      _clearFormState();
      if (Get.isRegistered<MemberShellController>()) {
        Get.find<MemberShellController>().changeTab(0);
      }
      Get.offAllNamed(AppRoutes.memberShell);
      Get.snackbar(
        'Booking Terkirim',
        'Booking "${result.sessionTitle}" berhasil dikirim dengan status ${result.status}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
        duration: const Duration(seconds: 3),
      );
    } on BookingConflictException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
      await _loadAvailability(silent: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _clearFormState() {
    _titleController.clear();
    _noteController.clear();
    _sessionCount = 1;
    _sessionSelections = const [_ManualSessionSelection()];
    _errorMessage = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trainer = _trainer;

    if (_isCheckingMembership) {
      return DecoratedScreen(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Memeriksa status membership...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasActiveMembership) {
      // UI membership-required hanya dialog compact. Surface kosong ini berada
      // di bawah modal selama transisi dan tidak memiliki CTA duplikat.
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.expand(),
      );
    }

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DetailScreenHeader(
            title: 'Booking Sesi PT',
            subtitle: trainer != null
                ? 'Pilih jadwal sesi dengan ${trainer.name}'
                : 'Isi form booking sesi Personal Trainer.',
          ),
          const SizedBox(height: 20),
          if (trainer != null)
            EggCard(
              highlight: true,
              child: Row(
                children: [
                  InitialAvatar(name: trainer.name, radius: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trainer.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trainer.specialty,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trainerTierDisplay(trainer.tier),
                          key: const Key('member-booking-trainer-tier'),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label:
                        '★ ${trainerRatingDisplay(rating: trainer.rating, reviewsCount: trainer.reviewsCount)}',
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Sesi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _titleController,
                  label: 'Judul Sesi',
                  hint: 'Contoh: Upper Body Hypertrophy',
                  icon: Icons.fitness_center_rounded,
                ),
                const SizedBox(height: 14),
                _buildManualSessionPickers(),
                const SizedBox(height: 14),
                _buildSessionCountAndPrice(),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _noteController,
                  label: 'Catatan (Opsional)',
                  hint: 'Contoh: Fokus chest dan triceps',
                  icon: Icons.note_alt_outlined,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            EggCard(
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          EggButton.primary(
            label: _isLoading ? 'Mengirim...' : 'Kirim Booking',
            onPressed: _isLoading ? null : _submitBooking,
          ),
          const SizedBox(height: 10),
          EggButton.secondary(
            label: 'Batal',
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surfaceSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualSessionPickers() {
    if (_isLoadingAvailability && _availability == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_availabilityError != null && _availability == null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _availabilityError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
          ),
          TextButton(
              onPressed: _loadAvailability, child: const Text('Coba Lagi')),
        ],
      );
    }
    final dates = _bookingDates;
    if (dates.isEmpty) {
      return Text(
        'Belum ada slot PT yang tersedia dalam 14 hari ke depan.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih Jadwal Setiap Sesi',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        if (_availableDateCount < _sessionCount) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              _insufficientSlotsMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                    height: 1.4,
                  ),
            ),
          ),
        ],
        ..._sessionSelections.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildManualSessionPicker(entry.key, dates),
              ),
            ),
      ],
    );
  }

  Widget _buildManualSessionPicker(
    int index,
    List<TrainerAvailabilityDate> dates,
  ) {
    final selection = _sessionSelections[index];
    TrainerAvailabilityDate? selectedDate;
    for (final date in dates) {
      if (date.date == selection.date) selectedDate = date;
    }
    final usedDates = <String>{
      for (var otherIndex = 0;
          otherIndex < _sessionSelections.length;
          otherIndex++)
        if (otherIndex != index && _sessionSelections[otherIndex].date != null)
          _sessionSelections[otherIndex].date!,
    };
    final previousDate = index > 0 ? _sessionSelections[index - 1].date : null;
    final hasSelectableSlot =
        selectedDate?.slots.any((slot) => slot.isAvailable) ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selection.isComplete ? AppColors.accent : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sesi ${index + 1}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: dates.map((date) {
                final selected = date.date == selection.date;
                final dateUsed = usedDates.contains(date.date);
                final previousReady = index == 0 || previousDate != null;
                final afterPrevious = previousDate == null ||
                    date.date.compareTo(previousDate) > 0;
                final enabled = !dateUsed && previousReady && afterPrevious;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    onSelected: enabled
                        ? (_) => setState(() {
                              _sessionSelections[index] =
                                  _ManualSessionSelection(date: date.date);
                              _clearInvalidFollowingSelections(index);
                              _errorMessage = null;
                            })
                        : null,
                    label: Text(_formatDateChip(date.date)),
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.surfaceSoft,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.background
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(color: AppColors.divider),
                  ),
                );
              }).toList(),
            ),
          ),
          if (index > 0 && previousDate == null) ...[
            const SizedBox(height: 8),
            Text(
              'Pilih tanggal Sesi $index terlebih dahulu.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
          if (selectedDate != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedDate.slots.map((slot) {
                final enabled = slot.isAvailable;
                final selected = selection.slotKey == slot.key;
                return ChoiceChip(
                  selected: selected,
                  onSelected: enabled
                      ? (_) => setState(() {
                            _sessionSelections[index] = _ManualSessionSelection(
                              date: selectedDate!.date,
                              slotKey: slot.key,
                              startTime: slot.startTime,
                              endTime: slot.endTime,
                            );
                            _errorMessage = null;
                          })
                      : null,
                  label: Text(
                    '${_displayTime(slot.startTime)}-${_displayTime(slot.endTime)}',
                  ),
                  selectedColor: AppColors.accent,
                  backgroundColor: enabled
                      ? AppColors.surface
                      : AppColors.divider.withValues(alpha: 0.35),
                );
              }).toList(),
            ),
            if (!hasSelectableSlot) ...[
              const SizedBox(height: 10),
              Text(
                'Tidak ada slot tersedia untuk tanggal ini.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<TrainerAvailabilityDate> get _bookingDates {
    final availability = _availability;
    if (availability == null) return const [];
    final serverToday = DateTime.tryParse(availability.currentServerDate);
    if (serverToday == null) return const [];
    final lastDate = serverToday.add(const Duration(days: 13));

    return availability.dates.where((date) {
      final concreteDate = DateTime.tryParse(date.date);
      if (concreteDate == null ||
          concreteDate.isBefore(serverToday) ||
          concreteDate.isAfter(lastDate)) {
        return false;
      }
      return date.slots.isNotEmpty;
    }).toList(growable: false);
  }

  String _formatDateChip(String rawDate) {
    return AppDateFormatter.date(
      rawDate,
      abbreviatedMonth: true,
      includeWeekday: true,
      includeYear: false,
    );
  }

  int get _availableDateCount => _bookingDates
      .where((date) => date.slots.any((slot) => slot.isAvailable))
      .length;

  String get _insufficientSlotsMessage =>
      'Slot tersedia tidak cukup untuk $_sessionCount sesi. '
      'Pilih jumlah sesi lebih sedikit atau pilih trainer/jadwal lain.';

  bool get _hasInvalidSessionDates {
    final dates = _sessionSelections
        .where((selection) => selection.date != null)
        .map((selection) => selection.date!)
        .toList(growable: false);
    if (dates.toSet().length != dates.length) return true;
    for (var index = 1; index < dates.length; index++) {
      if (dates[index].compareTo(dates[index - 1]) <= 0) return true;
    }
    return false;
  }

  List<_ManualSessionSelection> _reconcileSelections(
    TrainerAvailability availability,
  ) {
    final acceptedDates = <String>{};
    String? previousDate;
    return _sessionSelections.map((selection) {
      if (selection.date == null) return const _ManualSessionSelection();
      final stillAvailable = availability.dates.any((date) =>
          date.date == selection.date &&
          date.slots.any(
              (slot) => slot.key == selection.slotKey && slot.isAvailable));
      final ascending =
          previousDate == null || selection.date!.compareTo(previousDate!) > 0;
      if (!stillAvailable ||
          !ascending ||
          !acceptedDates.add(selection.date!)) {
        return const _ManualSessionSelection();
      }
      previousDate = selection.date;
      return selection;
    }).toList(growable: false);
  }

  void _clearInvalidFollowingSelections(int changedIndex) {
    var previousDate = _sessionSelections[changedIndex].date;
    for (var index = changedIndex + 1;
        index < _sessionSelections.length;
        index++) {
      final current = _sessionSelections[index];
      if (previousDate == null ||
          current.date == null ||
          current.date!.compareTo(previousDate) <= 0) {
        _sessionSelections[index] = const _ManualSessionSelection();
        previousDate = null;
        continue;
      }
      previousDate = current.date;
    }
  }

  Widget _buildSessionCountAndPrice() {
    final price = _trainer?.pricePerSession;
    final hasPrice = price != null && price > 0;
    final total = hasPrice ? price * _sessionCount : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jumlah Sesi',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: _sessionCount > 1
                        ? () => setState(() {
                              _sessionCount--;
                              _sessionSelections = _sessionSelections
                                  .take(_sessionCount)
                                  .toList(growable: false);
                            })
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '$_sessionCount',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _sessionCount < 30
                        ? () => setState(() {
                              _sessionCount++;
                              _sessionSelections = [
                                ..._sessionSelections,
                                const _ManualSessionSelection(),
                              ];
                            })
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Pilih tanggal dan jam masing-masing sesi secara manual. Setiap shift adalah satu slot utuh.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hasPrice
                          ? '${_formatRupiah(price)} x $_sessionCount sesi'
                          : 'Harga per sesi belum tersedia',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                  if (total != null)
                    Text(
                      _formatRupiah(total),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatRupiah(double value) {
    final digits = value.round().toString();
    final result = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) result.write('.');
      result.write(digits[index]);
    }
    return 'Rp $result';
  }

  String _displayTime(String value) {
    return value.length >= 5
        ? value.substring(0, 5).replaceAll(':', '.')
        : value;
  }
}

class _ManualSessionSelection {
  const _ManualSessionSelection({
    this.date,
    this.slotKey,
    this.startTime,
    this.endTime,
  });

  final String? date;
  final String? slotKey;
  final String? startTime;
  final String? endTime;

  bool get isComplete =>
      date != null && slotKey != null && startTime != null && endTime != null;
}

import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_trainer_availability_service.dart';
import 'package:egg_gym/data/services/backend_trainer_profile_service.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/domain/entities/trainer_availability.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BookingReschedulePage extends StatefulWidget {
  const BookingReschedulePage({super.key});

  @override
  State<BookingReschedulePage> createState() => _BookingReschedulePageState();
}

class _BookingReschedulePageState extends State<BookingReschedulePage> {
  final _availabilityService = BackendTrainerAvailabilityService();
  final _profileService = BackendTrainerProfileService();
  final _trainerService = BackendTrainerService();

  ScheduleSession? _session;
  int? _trainerProfileId;
  TrainerAvailability? _availability;
  TrainerAvailabilityDate? _selectedDate;
  TrainerAvailabilitySlot? _selectedSlot;
  BookingSessionReservation? _selectedReservation;
  String? _error;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _reasonType;
  final TextEditingController _reasonNoteController = TextEditingController();

  bool get _isMember => AppSessionService.instance.isMemberAuthenticated;

  List<MapEntry<String, String>> get _reasonOptions => _isMember
      ? const [
          MapEntry('unwell', 'Sakit / kurang fit'),
          MapEntry('family_matter', 'Ada urusan keluarga'),
          MapEntry('work_or_study', 'Ada urusan kerja/kuliah'),
          MapEntry('schedule_conflict', 'Jadwal mendadak bentrok'),
          MapEntry('transportation', 'Kendala transportasi'),
          MapEntry('other', 'Lainnya'),
        ]
      : const [
          MapEntry('unwell', 'Sakit / kurang fit'),
          MapEntry('urgent_schedule', 'Ada jadwal mendadak'),
          MapEntry('gym_operational_issue', 'Kendala operasional gym'),
          MapEntry('family_matter', 'Urusan keluarga'),
          MapEntry(
              'trainer_schedule_conflict', 'Jadwal bentrok dengan sesi lain'),
          MapEntry('other', 'Lainnya'),
        ];

  @override
  void initState() {
    super.initState();
    final argument = Get.arguments;
    if (argument is ScheduleSession) {
      _session = argument;
      _trainerProfileId = argument.trainerProfileId;
    } else if (argument is Map<String, dynamic>) {
      if (argument['session'] is ScheduleSession) {
        _session = argument['session'] as ScheduleSession;
      }
      _trainerProfileId =
          _asInt(argument['trainerProfileId']) ?? _session?.trainerProfileId;
    }
    final reserved = _session?.reservations
        .where((reservation) =>
            reservation.status == 'reserved' &&
            reservation.id != null &&
            reservation.activeRescheduleRequest == null)
        .toList(growable: false);
    if (reserved != null && reserved.length == 1) {
      _selectedReservation = reserved.first;
    }
    _initializeAvailability();
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    return value == null ? null : int.tryParse(value.toString());
  }

  @override
  void dispose() {
    _reasonNoteController.dispose();
    super.dispose();
  }

  Future<void> _initializeAvailability() async {
    if (_session == null) return;
    if (_trainerProfileId == null &&
        AppSessionService.instance.isTrainerAuthenticated) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        final profile = await _profileService.getProfile();
        if (!mounted) return;
        _trainerProfileId = profile.id;
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
    if (_trainerProfileId != null) {
      await _loadAvailability();
    }
  }

  Future<void> _loadAvailability() async {
    final trainerProfileId = _trainerProfileId;
    if (trainerProfileId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bookingId = _session?.backendId;
      final reservationId = _selectedReservation?.id;
      final availability = bookingId != null && reservationId != null
          ? await _availabilityService.getRescheduleAvailability(
              bookingId: bookingId,
              reservationId: reservationId,
              asMember: _isMember,
            )
          : await _availabilityService.getAvailability(trainerProfileId);
      final dates = _selectableDates(availability);
      if (!mounted) return;
      setState(() {
        _availability = availability;
        _selectedDate =
            _selectedReservation == null || dates.isEmpty ? null : dates.first;
        _selectedSlot = null;
        if (_selectedReservation != null && dates.isEmpty) {
          _error =
              'Tidak ada slot valid setelah jadwal sesi ini dalam horizon ${availability.horizonDays} hari. Tanggal yang dipakai sesi lain juga tidak dapat dipilih.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<TrainerAvailabilityDate> _selectableDates(
    TrainerAvailability availability,
  ) {
    final selectedReservation = _selectedReservation;
    if (selectedReservation == null) return const [];
    final siblingDates = (_session?.reservations ?? const [])
        .where((item) => item.id != selectedReservation.id)
        .map((item) => item.sessionDate)
        .toSet();
    siblingDates.addAll(
      (_session?.reservations ?? const [])
          .where((item) => item.id != selectedReservation.id)
          .map((item) => item.activeRescheduleRequest?.proposedDate)
          .whereType<String>(),
    );
    final uniqueDates = <String, TrainerAvailabilityDate>{};
    for (final date in availability.dates) {
      if (siblingDates.contains(date.date)) continue;
      if (date.slots.any((slot) =>
          slot.isAvailable &&
          _isAfterCurrentReservation(date.date, slot) &&
          !_isCurrentReservationSlot(date.date, slot))) {
        uniqueDates[date.date] = date;
      }
    }
    final dates = uniqueDates.values.toList();
    dates.sort((a, b) => a.date.compareTo(b.date));
    return dates;
  }

  bool _isCurrentReservationSlot(
    String date,
    TrainerAvailabilitySlot slot,
  ) {
    final reservation = _selectedReservation;
    if (reservation == null || reservation.sessionDate != date) return false;
    return _shortTime(reservation.startTime) == _shortTime(slot.startTime) &&
        _shortTime(reservation.endTime) == _shortTime(slot.endTime);
  }

  bool _isAfterCurrentReservation(
    String date,
    TrainerAvailabilitySlot slot,
  ) {
    final reservation = _selectedReservation;
    if (reservation == null) return false;
    final oldStart = DateTime.tryParse(
      '${reservation.sessionDate}T${_normalizedTime(reservation.startTime)}',
    );
    final proposedStart = DateTime.tryParse(
      '${date}T${_normalizedTime(slot.startTime)}',
    );
    return oldStart != null &&
        proposedStart != null &&
        proposedStart.isAfter(oldStart);
  }

  String _normalizedTime(String value) {
    final short = _shortTime(value);
    return short.length == 5 ? '$short:00' : short;
  }

  String _shortTime(String value) =>
      value.length >= 5 ? value.substring(0, 5) : value;

  String _formatConcreteDate(String rawDate) {
    return AppDateFormatter.date(
      rawDate,
      abbreviatedMonth: true,
      includeWeekday: true,
      includeYear: false,
    );
  }

  Future<void> _submit() async {
    final session = _session;
    final bookingId = session?.backendId;
    final date = _selectedDate;
    final slot = _selectedSlot;
    if (session == null || bookingId == null || date == null || slot == null) {
      return;
    }
    final reservation = _selectedReservation;
    if (reservation == null) {
      setState(() => _error =
          'Pilih child reservation aktif. Booking legacy tidak mendukung reschedule approval.');
      return;
    }
    if (_reasonType == null) {
      setState(() => _error = 'Pilih alasan reschedule.');
      return;
    }
    if (_reasonType == 'other' && _reasonNoteController.text.trim().isEmpty) {
      setState(() => _error = 'Alasan tambahan wajib diisi untuk Lainnya.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      if (reservation.sessionDate == date.date &&
          reservation.startTime.substring(0, 5) ==
              slot.startTime.substring(0, 5) &&
          reservation.endTime.substring(0, 5) == slot.endTime.substring(0, 5)) {
        setState(() => _error = 'Jadwal baru harus berbeda dari jadwal lama.');
        return;
      }
      await _trainerService.createRescheduleRequest(
        bookingId,
        reservation.id!,
        sessionDate: date.date,
        startTime: slot.startTime,
        endTime: slot.endTime,
        reasonType: _reasonType!,
        reasonNote: _reasonNoteController.text,
        asMember: _isMember,
      );
      if (!mounted) return;
      Get.back(result: true);
      Get.snackbar(
        'Permintaan Terkirim',
        'Jadwal lama tetap berlaku sampai pihak lawan menyetujui.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is TrainerApiException
            ? error.message
            : error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final missingData = session == null
        ? 'Data sesi tidak tersedia. Buka reschedule dari detail booking.'
        : session.backendId == null
            ? 'ID booking tidak tersedia sehingga sesi tidak dapat diubah.'
            : _trainerProfileId == null && !_isLoading
                ? _error ??
                    'ID profil trainer tidak tersedia sehingga jadwal live tidak dapat dimuat.'
                : null;
    final dates = _availability == null
        ? const <TrainerAvailabilityDate>[]
        : _selectableDates(_availability!);
    final slots = _selectedDate?.slots
            .where((slot) =>
                slot.isAvailable &&
                _isAfterCurrentReservation(_selectedDate!.date, slot) &&
                !_isCurrentReservationSlot(_selectedDate!.date, slot))
            .toList(growable: false) ??
        const <TrainerAvailabilitySlot>[];
    final reservedOccurrences = session?.reservations
            .where((reservation) =>
                reservation.status == 'reserved' &&
                reservation.id != null &&
                reservation.activeRescheduleRequest == null)
            .toList(growable: false) ??
        const <BookingSessionReservation>[];
    final requiresOccurrence = reservedOccurrences.isNotEmpty;

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const DetailScreenHeader(
            title: 'Reschedule Session',
            subtitle: 'Pilih slot terbaru dari jadwal trainer.',
          ),
          const SizedBox(height: 20),
          if (session != null)
            EggCard(
              highlight: true,
              child: Row(
                children: [
                  InitialAvatar(
                    name: session.clientName,
                    radius: 28,
                    avatarPath: session.trainerDisplayPhotoPath ??
                        session.trainerAvatarUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.clientName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          'Jadwal saat ini: ${session.timeRange}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (session != null) const SizedBox(height: 16),
          if (reservedOccurrences.isNotEmpty) ...[
            EggCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih Sesi yang Dipindah',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...reservedOccurrences.map(
                    (reservation) => RadioListTile<int>(
                      value: reservation.id!,
                      groupValue: _selectedReservation?.id,
                      onChanged: (_) async {
                        setState(() {
                          _selectedReservation = reservation;
                          _selectedDate = null;
                          _selectedSlot = null;
                          _error = null;
                        });
                        await _loadAvailability();
                      },
                      title: Text('Sesi ${reservation.sequenceOrder}'),
                      subtitle: Text(
                        AppDateFormatter.schedule(
                          dateValue: reservation.sessionDate,
                          startTime: reservation.startTime,
                          endTime: reservation.endTime,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (missingData != null)
            _MessageCard(message: missingData)
          else if (_isLoading)
            const EggCard(
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_error != null) ...[
              _MessageCard(message: _error!),
              const SizedBox(height: 12),
            ],
            if (_availability != null) ...[
              EggCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pilih Hari Baru',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    if (_selectedReservation == null)
                      const Text(
                        'Pilih sesi yang akan dipindah terlebih dahulu.',
                      )
                    else if (dates.isEmpty)
                      const Text(
                        'Tidak ada tanggal setelah jadwal sesi ini yang tersedia. Tanggal sesi lain dalam booking yang sama juga tidak dapat dipilih.',
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: dates
                            .map((date) => ChoiceChip(
                                  label: Text(
                                    _formatConcreteDate(date.date),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                  ),
                                  selected: identical(date, _selectedDate),
                                  onSelected: (_) => setState(() {
                                    _selectedDate = date;
                                    _selectedSlot = null;
                                  }),
                                ))
                            .toList(growable: false),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              EggCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pilih Jam Baru',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    if (slots.isEmpty)
                      const Text('Tidak ada slot tersedia pada tanggal ini.')
                    else
                      ...slots.map((slot) => RadioListTile<String>(
                            value: slot.key,
                            groupValue: _selectedSlot?.key,
                            onChanged: (_) =>
                                setState(() => _selectedSlot = slot),
                            title: Text(
                              '${_shortTime(slot.startTime)} - ${_shortTime(slot.endTime)}',
                            ),
                            subtitle: const Text('Egg Gym Pontianak'),
                            activeColor: AppColors.accent,
                            contentPadding: EdgeInsets.zero,
                          )),
                  ],
                ),
              ),
              if (requiresOccurrence) ...[
                const SizedBox(height: 16),
                EggCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alasan Reschedule',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _reasonType,
                        decoration: const InputDecoration(
                          labelText: 'Pilih alasan',
                        ),
                        items: _reasonOptions
                            .map((item) => DropdownMenuItem(
                                  value: item.key,
                                  child: Text(item.value),
                                ))
                            .toList(growable: false),
                        onChanged: (value) => setState(() {
                          _reasonType = value;
                          if (value != 'other') {
                            _reasonNoteController.clear();
                          }
                        }),
                      ),
                      if (_reasonType == 'other') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _reasonNoteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Alasan tambahan (wajib)',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
          const SizedBox(height: 18),
          EggButton.primary(
            label: _isSubmitting
                ? 'Mengirim...'
                : requiresOccurrence
                    ? 'Kirim Permintaan Reschedule'
                    : 'Reschedule Tidak Tersedia',
            onPressed: missingData == null &&
                    _selectedSlot != null &&
                    (!requiresOccurrence || _selectedReservation != null) &&
                    (!requiresOccurrence || _reasonType != null) &&
                    !_isSubmitting
                ? _submit
                : null,
          ),
          const SizedBox(height: 10),
          EggButton.secondary(label: 'Kembali', onPressed: () => Get.back()),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

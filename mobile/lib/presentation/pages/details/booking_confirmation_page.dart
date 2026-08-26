import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BookingConfirmationPage extends StatelessWidget {
  const BookingConfirmationPage({super.key});

  String _resolveViewerRole() {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final viewerRole = argument['viewerRole'];
      if (viewerRole is String && viewerRole.isNotEmpty) {
        return viewerRole;
      }
    }
    return 'trainer';
  }

  ScheduleSession _resolveSession() {
    final argument = Get.arguments;
    if (argument is ScheduleSession) {
      return argument;
    }
    if (argument is Map<String, dynamic> &&
        argument['session'] is ScheduleSession) {
      return argument['session'] as ScheduleSession;
    }

    return const ScheduleSession(
      clientName: 'Siska Amelia',
      timeRange: 'Besok, 07.00',
      location: 'Power Yoga',
      status: 'Menunggu',
      note: 'Need confirmation before booking locks',
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _resolveSession();
    final viewerRole = _resolveViewerRole();
    final isMemberViewer = viewerRole == 'member';

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DetailScreenHeader(
            title: isMemberViewer ? 'Booking Request' : 'Booking Confirmation',
            subtitle: isMemberViewer
                ? 'Tinjau slot coach lalu kirim request booking demo.'
                : 'Konfirmasi request booking personal trainer.',
          ),
          const SizedBox(height: 20),
          EggCard(
            highlight: true,
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [AppColors.accentBronze, Color(0xFF181818)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StatusChip(label: 'BOOKING REQUEST'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      InitialAvatar(name: session.clientName, radius: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.clientName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${session.timeRange} | ${session.location}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const StatusChip(
                        label: 'PENDING',
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isMemberViewer
                        ? 'Review detail coach dan slot yang dipilih sebelum request booking dikirim.'
                        : 'Tinjau request ini sebelum mengunci jadwal sesi di kalender trainer.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ringkasan Permintaan',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                _ConfirmationLine(
                  label: isMemberViewer ? 'Coach' : 'Client',
                  value: session.clientName,
                ),
                const SizedBox(height: 10),
                _ConfirmationLine(
                    label: 'Preferred slot', value: session.timeRange),
                const SizedBox(height: 10),
                _ConfirmationLine(label: 'Studio', value: session.location),
                const SizedBox(height: 10),
                _ConfirmationLine(label: 'Focus', value: session.note),
              ],
            ),
          ),
          const SizedBox(height: 16),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checklist Sebelum Konfirmasi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                const _ChecklistTile(
                  title: 'Cek slot studio',
                  subtitle:
                      'Pastikan area latihan masih tersedia di jam yang dipilih.',
                ),
                const SizedBox(height: 10),
                const _ChecklistTile(
                  title: 'Cek kesiapan program',
                  subtitle: 'Program sesi sudah sesuai dengan request klien.',
                ),
                const SizedBox(height: 10),
                const _ChecklistTile(
                  title: 'Lock jadwal trainer',
                  subtitle:
                      'Tidak bentrok dengan sesi coach lain di hari yang sama.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aksi Cepat',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  isMemberViewer
                      ? 'Kalau slot kurang cocok, kamu bisa pilih ulang jadwal demo sebelum request booking dikirim.'
                      : 'Kalau slot kurang cocok, kamu bisa pindah dulu ke flow reschedule sebelum final konfirmasi.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          EggButton.primary(
            label:
                isMemberViewer ? 'Kirim Request Booking' : 'Konfirmasi Booking',
            onPressed: () {
              if (isMemberViewer) {
                Get.back();
                Get.snackbar(
                  'Booking Terkirim',
                  'Request booking sudah dikirim. Menunggu konfirmasi dari Personal Trainer.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.surface,
                  colorText: AppColors.textPrimary,
                  duration: const Duration(seconds: 3),
                );
                return;
              }

              Get.offNamed(
                AppRoutes.trainerSessionDetail,
                arguments: <String, dynamic>{
                  'session': session,
                  'status': 'Dikonfirmasi',
                  'note': '${session.note} | Booking confirmed for demo',
                },
              );
            },
          ),
          const SizedBox(height: 10),
          EggButton.secondary(
            label: isMemberViewer ? 'Pilih Slot Lain' : 'Reschedule Dulu',
            onPressed: () => Get.toNamed(
              AppRoutes.bookingReschedule,
              arguments: session,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationLine extends StatelessWidget {
  const _ConfirmationLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surfaceElevated, AppColors.surfaceSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accentBronze, AppColors.background],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_rounded,
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
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

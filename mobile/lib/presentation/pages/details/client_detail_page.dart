import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ClientDetailPage extends StatefulWidget {
  const ClientDetailPage({super.key});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  late final ClientSummary _client = _resolveClient();
  final BackendTrainerService _trainerService = BackendTrainerService();

  TrainerClientDetailSnapshot? _liveDetail;
  String? _errorMessage;

  bool get _hasLiveSync => _liveDetail != null;

  @override
  void initState() {
    super.initState();
    _loadClientDetail();
  }

  ClientSummary _resolveClient() {
    final argument = Get.arguments;
    if (argument is ClientSummary) {
      return argument;
    }

    return const ClientSummary(
      name: 'Naufal Raharjo',
      goal: 'Hypertrophy Focus',
      progressLabel: '6-week mass builder - 65% completed',
      nextSession: 'Tomorrow, 08.00',
    );
  }

  Future<void> _loadClientDetail() async {
    final backendId = _client.backendId;
    if (backendId == null) {
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      final detail = await _trainerService.getClientDetail(backendId);
      if (!mounted) {
        return;
      }

      setState(() {
        _liveDetail = detail;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    }
  }

  WorkoutSession _linkedProgram() {
    final detail = _liveDetail;
    if (detail != null) {
      final focus = detail.activeProgramGoal ?? detail.goal ?? _client.goal;
      final membership = detail.activeMembershipPlanName;
      final activeSessions = _activeSessionCount(detail);
      final title = detail.activeProgramTitle;

      return WorkoutSession(
        title: title ??
            (membership != null
                ? '$membership Coaching Track'
                : '$focus Program'),
        focus: '$focus | $activeSessions sesi aktif',
        progressText: 'Buka tracker program member',
        statusLabel: detail.activeProgramStatus ??
            (detail.pendingSessions > 0 ? 'Needs review' : 'Active'),
      );
    }

    return WorkoutSession(
      title: '${_client.goal} Program',
      focus: _client.progressLabel,
      progressText: 'Buka tracker program member',
      statusLabel: 'Active',
    );
  }

  List<_CoachNoteEntry> _coachNotes() {
    final detail = _liveDetail;
    if (detail != null) {
      final notes = detail.recentSessions
          .map((session) {
            final subtitle = session.trainerNote ??
                session.memberNote ??
                'Belum ada catatan dari sesi ini.';
            if (subtitle.trim().isEmpty) {
              return null;
            }

            return _CoachNoteEntry(
              title: session.sessionTitle,
              subtitle: subtitle,
            );
          })
          .whereType<_CoachNoteEntry>()
          .toList();

      if (notes.isNotEmpty) {
        return notes;
      }
    }

    return const <_CoachNoteEntry>[
      _CoachNoteEntry(
        title: 'Posture check',
        subtitle: 'Bench press setup sudah lebih stabil dari minggu lalu.',
      ),
      _CoachNoteEntry(
        title: 'Nutrition reminder',
        subtitle: 'Naikkan protein harian untuk support recovery.',
      ),
      _CoachNoteEntry(
        title: 'Recovery',
        subtitle: 'Tidur minimal 7 jam di hari sebelum sesi kaki berikutnya.',
      ),
    ];
  }

  int _activeSessionCount(TrainerClientDetailSnapshot detail) {
    return detail.confirmedSessions + detail.rescheduledSessions;
  }

  String _sessionSummaryLabel(TrainerClientDetailSnapshot detail) {
    final activeSessions = _activeSessionCount(detail);

    if (activeSessions > 0 && detail.pendingSessions > 0) {
      return '$activeSessions sesi aktif, ${detail.pendingSessions} menunggu';
    }

    if (activeSessions > 0) {
      return '$activeSessions sesi aktif bersama trainer';
    }

    if (detail.pendingSessions > 0) {
      return '${detail.pendingSessions} booking menunggu konfirmasi';
    }

    return '${detail.totalSessions} histori sesi bersama trainer';
  }

  double _programProgressValue(TrainerClientDetailSnapshot detail) {
    // Progres program berbasis sesi yang benar-benar selesai (dari backend),
    // konsisten dengan Session Timeline / menu Program. Fallback ke hitungan
    // manual completed/total bila persentase belum tersedia.
    if (detail.activeProgramProgressPercent > 0) {
      return (detail.activeProgramProgressPercent / 100).clamp(0, 1).toDouble();
    }

    if (detail.activeProgramTotalSessions > 0) {
      return (detail.activeProgramCompletedSessions /
              detail.activeProgramTotalSessions)
          .clamp(0, 1)
          .toDouble();
    }

    return 0;
  }

  String _formatNumber(double value, {String suffix = ''}) {
    final whole = value % 1 == 0;
    final number = whole ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return suffix.isEmpty ? number : '$number $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final detail = _liveDetail;
    final displayName = detail?.name ?? _client.name;
    // Avatar member: relative path dari detail live (fallback ke summary list) ->
    // dirender via InitialAvatar (baseUrl dinamis); null -> fallback inisial.
    final displayAvatarPath = detail?.avatarUrl ?? _client.avatarUrl;
    final displayGoal = detail?.goal ?? _client.goal;
    final progressLabel =
        detail != null ? _sessionSummaryLabel(detail) : _client.progressLabel;
    final totalSessions = detail?.totalSessions.toString() ?? '12';
    final weightValue = detail?.weightKg != null
        ? _formatNumber(detail!.weightKg!, suffix: 'kg')
        : '78.5 kg';
    final heightValue = detail?.heightCm != null
        ? _formatNumber(detail!.heightCm!, suffix: 'cm')
        : '175 cm';
    final membershipLabel =
        detail?.activeMembershipPlanName ?? 'Active coaching track';
    final nextSessionLabel = detail?.nextSessionLabel ?? _client.nextSession;
    final coachNotes = _coachNotes();

    return DecoratedScreen(
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _loadClientDetail,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const DetailScreenHeader(
              title: 'Client Detail',
              subtitle: 'Ringkasan klien untuk dashboard trainer.',
            ),
            const SizedBox(height: 20),
            EggCard(
              highlight: true,
              child: Column(
                children: [
                  InitialAvatar(
                    name: displayName,
                    radius: 34,
                    avatarPath: displayAvatarPath,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayGoal,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    progressLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  if (_errorMessage != null && !_hasLiveSync) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ClientMetric(label: 'Height', value: heightValue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ClientMetric(label: 'Weight', value: weightValue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ClientMetric(label: 'Sessions', value: totalSessions),
                ),
              ],
            ),
            const SizedBox(height: 18),
            EggCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Client Snapshot',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        detail?.memberCode ?? 'DEMO',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    membershipLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    detail?.email ?? 'Email belum tersinkron',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail?.phone ?? 'Nomor telepon belum tersinkron',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      StatusChip(label: 'Next: $nextSessionLabel'),
                      if ((detail?.status ?? '').isNotEmpty)
                        StatusChip(
                          label: detail!.status!.toUpperCase(),
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                  if (detail?.medicalNote != null &&
                      detail!.medicalNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      detail.medicalNote!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            EggCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Program Saat Ini',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _linkedProgram().title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    detail != null
                        ? 'Fokus saat ini: ${detail.goal ?? _client.goal}. Membership aktif: $membershipLabel.'
                        : 'Fokus peningkatan massa otot dengan split 4 hari dan evaluasi mingguan.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value:
                        detail != null ? _programProgressValue(detail) : 0.65,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: AppColors.surfaceSoft,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    detail != null
                        ? '${detail.activeProgramCompletedSessions}/${detail.activeProgramTotalSessions} sesi selesai (${detail.activeProgramProgressPercent}%)'
                        : '65% progress completed',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
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
                    'Coach Notes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 14),
                  ...coachNotes.asMap().entries.map(
                        (entry) => Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key == coachNotes.length - 1 ? 0 : 10,
                          ),
                          child: _NoteTile(
                            title: entry.value.title,
                            subtitle: entry.value.subtitle,
                          ),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            EggButton.secondary(
              label: 'Kembali',
              onPressed: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientMetric extends StatelessWidget {
  const _ClientMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
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
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.sticky_note_2_rounded,
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
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

class _CoachNoteEntry {
  const _CoachNoteEntry({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

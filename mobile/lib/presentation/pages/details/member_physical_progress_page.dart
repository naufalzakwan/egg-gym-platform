import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/physical_progress_comparison.dart';
import 'package:egg_gym/core/utils/physical_progress_history_badge.dart';
import 'package:egg_gym/core/utils/physical_progress_history_sort.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Rangkai URL penuh foto checkpoint dari RELATIVE PATH + baseUrl aktif
/// (konsisten dgn avatar; tahan ganti IP LAN). Null bila path kosong/baseUrl
/// belum ada. Data lama bisa URL absolut -> dipakai apa adanya.
String? _resolveCheckpointPhotoUrl(String? path) {
  final p = path?.trim();
  if (p == null || p.isEmpty) return null;
  if (p.startsWith('http://') || p.startsWith('https://')) return p;
  final baseUrl = AppSessionService.instance.currentSession?.baseUrl;
  if (baseUrl == null || baseUrl.isEmpty) return null;
  final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final cleanPath = p.replaceAll(RegExp(r'^/+'), '');
  return '$cleanBase/storage/$cleanPath';
}

const List<String> _kMonthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _formatCheckpointDate(DateTime? date) {
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  return '$day ${_kMonthLabels[date.month - 1]} ${date.year}';
}

/// Badge WEEK/BASELINE dihitung dari selisih tanggal terhadap baseline (record
/// pertama). Checkpoint pertama = "BASELINE"; sisanya "WEEK X" (X = minggu ke-).
String _stageLabelFor(DateTime? recordedAt, DateTime? baselineAt) {
  if (recordedAt == null || baselineAt == null) return 'CHECKPOINT';
  final days = recordedAt.difference(baselineAt).inDays;
  if (days <= 0) return 'BASELINE';
  final week = (days / 7).floor();
  return week <= 0 ? 'WEEK 1' : 'WEEK $week';
}

class MemberPhysicalProgressPage extends StatefulWidget {
  const MemberPhysicalProgressPage({super.key});

  @override
  State<MemberPhysicalProgressPage> createState() =>
      _MemberPhysicalProgressPageState();
}

class _MemberPhysicalProgressPageState
    extends State<MemberPhysicalProgressPage> {
  final BackendMemberService _service = BackendMemberService();

  bool _isLoading = true;
  String? _error;
  MemberPhysicalProgressSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final snapshot = await _service.getPhysicalProgress();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } on MemberApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('MemberApiException: ', '');
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat progres fisik. Pastikan backend aktif.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openForm() async {
    // Form mengembalikan true bila checkpoint baru berhasil disimpan -> refetch.
    final result = await Get.toNamed(AppRoutes.memberPhysicalProgressForm);
    if (result == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedScreen(
      child: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return ListView(
        children: const [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const DetailScreenHeader(
            title: 'Progress Fisik',
            subtitle: 'Checkpoint fisik member.',
          ),
          const SizedBox(height: 40),
          const Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          EggButton.secondary(label: 'Coba Lagi', onPressed: _load),
        ],
      );
    }

    final snapshot = _snapshot;
    final history = snapshot?.history ?? const <MemberCheckpoint>[];

    // EMPTY STATE: member belum pernah isi checkpoint sama sekali.
    if (snapshot == null || history.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildData(context, snapshot, history);
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const DetailScreenHeader(
          title: 'Progress Fisik',
          subtitle:
              'Catat checkpoint fisik pertamamu sebagai baseline progres.',
        ),
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.monitor_weight_outlined,
                    size: 34, color: AppColors.accent),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Checkpoint',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Kamu belum pernah mencatat progres fisik. Buat checkpoint pertama (baseline) berisi berat, tinggi, foto, dan catatan.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        EggButton.primary(
          label: 'Buat Checkpoint Pertama',
          onPressed: _openForm,
        ),
      ],
    );
  }

  Widget _buildData(
    BuildContext context,
    MemberPhysicalProgressSnapshot snapshot,
    List<MemberCheckpoint> history,
  ) {
    // history dari backend urut DESC (terbaru dulu). Latest = pertama.
    final latest = snapshot.latest ?? history.first;
    final baseline = snapshot.baseline ?? history.last;
    final newestHistory = physicalProgressNewestFirst(history);
    final comparisonAfter = physicalProgressComparisonAfter(snapshot);
    final weightDelta = comparisonAfter == null
        ? 0.0
        : comparisonAfter.weightKg - baseline.weightKg;
    final weightDeltaLabel =
        '${weightDelta >= 0 ? '+' : ''}${weightDelta.toStringAsFixed(1)} kg';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const DetailScreenHeader(
          title: 'Progress Fisik',
        ),
        const SizedBox(height: 16),
        // Baseline vs Latest compare.
        EggCard(
          highlight: true,
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF231F14), AppColors.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Baseline vs Terbaru',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ProgressPhotoCard(
                          heading: 'BEFORE',
                          checkpoint: baseline,
                          heroTag: 'progress-photo-before',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ProgressPhotoCard(
                          heading: 'AFTER',
                          checkpoint: comparisonAfter,
                          heroTag: 'progress-photo-after',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _ProgressMetricCard(
                label: 'Berat',
                value: '${latest.weightKg.toStringAsFixed(1)} kg',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProgressMetricCard(
                label: 'Selisih',
                value: weightDeltaLabel,
                accent: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProgressMetricCard(
                label: 'Checkpoint',
                value: '${snapshot.totalRecords}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ProgressMetricCard(
                label: 'Tinggi',
                value: '${latest.heightCm.toStringAsFixed(0)} cm',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProgressMetricCard(
                label: 'Update',
                value: _formatCheckpointDate(latest.recordedAt),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Riwayat Checkpoint.
        Row(
          children: [
            Text(
              'Riwayat Checkpoint',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            if (newestHistory.length > 2)
              TextButton(
                onPressed: () => Get.toNamed(
                  AppRoutes.memberAllCheckpoints,
                  arguments: {
                    'history': newestHistory,
                    'baseline': baseline,
                    'latest': latest,
                  },
                ),
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...newestHistory.take(2).map(
              (checkpoint) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProgressHistoryCard(
                  checkpoint: checkpoint,
                  baseline: baseline,
                  latest: latest,
                ),
              ),
            ),
        const SizedBox(height: 8),
        EggButton.primary(
          label: 'Buka Form Checkpoint',
          onPressed: _openForm,
        ),
      ],
    );
  }
}

class MemberAllCheckpointsPage extends StatelessWidget {
  const MemberAllCheckpointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = Get.arguments;
    final rawHistory = arguments is Map ? arguments['history'] : null;
    final baseline =
        arguments is Map && arguments['baseline'] is MemberCheckpoint
            ? arguments['baseline'] as MemberCheckpoint
            : null;
    final latest = arguments is Map && arguments['latest'] is MemberCheckpoint
        ? arguments['latest'] as MemberCheckpoint
        : null;
    final history = rawHistory is List
        ? physicalProgressNewestFirst(rawHistory.whereType<MemberCheckpoint>())
        : const <MemberCheckpoint>[];

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DetailScreenHeader(
            title: 'Riwayat Checkpoint',
            subtitle: 'Semua checkpoint dari terbaru hingga baseline.',
            onBack: Get.back,
          ),
          const SizedBox(height: 18),
          if (history.isEmpty || baseline == null || latest == null)
            Text(
              'Riwayat checkpoint tidak tersedia.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          else
            ...history.map(
              (checkpoint) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProgressHistoryCard(
                  checkpoint: checkpoint,
                  baseline: baseline,
                  latest: latest,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kartu foto BEFORE/AFTER. Render foto pose "Front" (fallback foto pertama)
/// dari relative path + baseUrl; kalau tak ada foto -> ikon placeholder.
class _ProgressPhotoCard extends StatelessWidget {
  const _ProgressPhotoCard({
    required this.heading,
    this.checkpoint,
    required this.heroTag,
  });

  final String heading;
  final MemberCheckpoint? checkpoint;

  /// Tag Hero unik per foto (mis. 'progress-photo-before'/'-after') supaya
  /// transisi thumbnail -> viewer fullscreen mulus.
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final checkpoint = this.checkpoint;
    if (checkpoint == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 136,
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.25),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  size: 42,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada checkpoint pembanding',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '-',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    MemberCheckpointPhoto? photo;
    for (final p in checkpoint.photos) {
      if (p.type.toLowerCase() == 'front') {
        photo = p;
        break;
      }
    }
    photo ??= checkpoint.photos.isNotEmpty ? checkpoint.photos.first : null;
    final photoUrl = _resolveCheckpointPhotoUrl(photo?.path);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          _buildThumbnail(context, photoUrl),
          const SizedBox(height: 12),
          Text(
            _formatCheckpointDate(checkpoint.recordedAt),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${checkpoint.weightKg.toStringAsFixed(1)} kg',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  /// Thumbnail BEFORE/AFTER: TETAP BoxFit.cover (tampilan card tidak berubah).
  /// Bila ada foto -> dibungkus Hero + tap membuka viewer fullscreen. Bila null/
  /// kosong -> placeholder ikon yang TIDAK bisa diklik (tidak buka viewer kosong).
  Widget _buildThumbnail(BuildContext context, String? photoUrl) {
    final Widget inner = photoUrl != null
        ? Hero(
            tag: heroTag,
            child: Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 36, color: AppColors.textSecondary),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
          )
        : const Center(
            child: Icon(Icons.accessibility_new_rounded,
                size: 42, color: AppColors.textSecondary),
          );

    final Widget thumb = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 136,
        width: double.infinity,
        color: Colors.black.withValues(alpha: 0.25),
        child: inner,
      ),
    );

    // Foto null/kosong -> tidak bisa diklik.
    if (photoUrl == null) return thumb;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        _FullscreenPhotoViewer.route(photoUrl: photoUrl, heroTag: heroTag),
      ),
      child: thumb,
    );
  }
}

/// Viewer foto fullscreen: BoxFit.contain (utuh, tak kepotong) + InteractiveViewer
/// (pinch-zoom & pan) + Hero (transisi mulus dari thumbnail) + latar hitam.
/// Tutup via tombol X, tap di luar foto, atau swipe (drag vertikal) saat tidak zoom.
/// URL sudah dirangkai pemanggil via _resolveCheckpointPhotoUrl (relative path +
/// baseUrl dinamis) — viewer TIDAK merangkai/hardcode URL sendiri.
class _FullscreenPhotoViewer extends StatefulWidget {
  const _FullscreenPhotoViewer({required this.photoUrl, required this.heroTag});

  final String photoUrl;
  final String heroTag;

  static Route<void> route({
    required String photoUrl,
    required String heroTag,
  }) {
    return PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) =>
          _FullscreenPhotoViewer(photoUrl: photoUrl, heroTag: heroTag),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  State<_FullscreenPhotoViewer> createState() => _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState extends State<_FullscreenPhotoViewer> {
  final TransformationController _transform = TransformationController();
  bool _isZoomed = false;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransformChanged);
    _transform.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.05;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tap di luar foto -> tutup.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          Center(
            child: GestureDetector(
              // Swipe (drag vertikal) untuk menutup — hanya saat TIDAK zoom
              // (saat zoom, pan diserahkan ke InteractiveViewer).
              onVerticalDragUpdate: (d) {
                if (_isZoomed) return;
                setState(() => _dragOffset += d.delta.dy);
              },
              onVerticalDragEnd: (_) {
                if (_isZoomed) return;
                if (_dragOffset.abs() > 120) {
                  _close();
                } else {
                  setState(() => _dragOffset = 0);
                }
              },
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Hero(
                  tag: widget.heroTag,
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: 1,
                    maxScale: 5,
                    panEnabled: _isZoomed,
                    child: Image.network(
                      widget.photoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            size: 64, color: Colors.white54),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Tombol close (X).
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Material(
              color: Colors.black.withValues(alpha: 0.5),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: _close,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressMetricCard extends StatelessWidget {
  const _ProgressMetricCard({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: accent ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHistoryCard extends StatelessWidget {
  const _ProgressHistoryCard({
    required this.checkpoint,
    required this.baseline,
    required this.latest,
  });

  final MemberCheckpoint checkpoint;
  final MemberCheckpoint baseline;
  final MemberCheckpoint latest;

  @override
  Widget build(BuildContext context) {
    final stageLabel = physicalProgressHistoryBadge(
      checkpoint: checkpoint,
      baseline: baseline,
      latest: latest,
    );
    final isLatest = stageLabel == 'TERBARU';
    final isHighlighted = checkpoint.isMilestone || isLatest;

    // Tap -> halaman DETAIL read-only. Data checkpoint & baseline dioper apa
    // adanya (sudah di memori dari list Riwayat) -> TANPA request backend baru.
    return GestureDetector(
      onTap: () => Get.toNamed(
        AppRoutes.memberCheckpointDetail,
        arguments: {
          'checkpoint': checkpoint,
          'baseline': baseline,
          'stageLabel': stageLabel,
        },
      ),
      child: EggCard(
        padding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: isHighlighted
                ? const LinearGradient(
                    colors: [AppColors.accentBronze, Color(0xFF171717)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [AppColors.surfaceMuted, Color(0xFF171717)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(
              color: isHighlighted
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatCheckpointDate(checkpoint.recordedAt),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  StatusChip(
                    label: stageLabel,
                    color: isHighlighted
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _HistoryValue(
                      label: 'Berat badan',
                      value: '${checkpoint.weightKg.toStringAsFixed(1)} kg',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HistoryValue(
                      label: 'Tinggi badan',
                      value: '${checkpoint.heightCm.toStringAsFixed(0)} cm',
                    ),
                  ),
                ],
              ),
              if (checkpoint.note != null &&
                  checkpoint.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  checkpoint.note!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                ),
              ],
              if (checkpoint.photos.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${checkpoint.photos.length} foto pose: ${checkpoint.photos.map((p) => p.type).join(', ')}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryValue extends StatelessWidget {
  const _HistoryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

/// Pose foto yang ditampilkan di halaman detail (urutan tetap).
const List<String> _kDetailPoses = ['Back', 'Front', 'Side'];

const Map<String, String> _kPoseLabels = {
  'Back': 'Belakang',
  'Front': 'Depan',
  'Side': 'Samping',
};

/// Halaman DETAIL checkpoint — MODE LIHAT SAJA (read-only). TIDAK ada
/// TextField / tombol Edit / Simpan. Semua nilai ditampilkan sebagai teks statis.
///
/// Argumen (Get.arguments):
/// `{ 'checkpoint': MemberCheckpoint, 'baseline': MemberCheckpoint,
///    'stageLabel': String }`.
/// Data dioper apa adanya dari list Riwayat (sudah di memori) -> TANPA request
/// backend baru. Foto memakai resolver relative path + baseUrl dinamis yang SAMA
/// (`_resolveCheckpointPhotoUrl`) & viewer fullscreen yang SAMA
/// (`_FullscreenPhotoViewer`) dengan card Baseline vs Latest.
class CheckpointDetailPage extends StatelessWidget {
  const CheckpointDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    final checkpoint = (args is Map && args['checkpoint'] is MemberCheckpoint)
        ? args['checkpoint'] as MemberCheckpoint
        : null;
    final baseline = (args is Map && args['baseline'] is MemberCheckpoint)
        ? args['baseline'] as MemberCheckpoint
        : null;
    final stageLabel = (args is Map && args['stageLabel'] is String)
        ? args['stageLabel'] as String
        : _stageLabelFor(checkpoint?.recordedAt, baseline?.recordedAt);

    if (checkpoint == null) {
      return DecoratedScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const DetailScreenHeader(
              title: 'Detail Checkpoint',
              subtitle: 'Data checkpoint tidak tersedia.',
            ),
            const SizedBox(height: 24),
            EggButton.secondary(label: 'Kembali', onPressed: () => Get.back()),
          ],
        ),
      );
    }

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DetailScreenHeader(
            title: 'Detail Checkpoint',
            subtitle: 'Rincian catatan fisik (lihat saja).',
          ),
          const SizedBox(height: 20),
          _buildSummaryCard(context, checkpoint, baseline, stageLabel),
          const SizedBox(height: 18),
          _buildPhotosCard(context, checkpoint),
          if (checkpoint.note != null &&
              checkpoint.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildNoteCard(context, checkpoint.note!.trim()),
          ],
          const SizedBox(height: 24),
          EggButton.secondary(
            label: 'Kembali ke Riwayat',
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    MemberCheckpoint checkpoint,
    MemberCheckpoint? baseline,
    String stageLabel,
  ) {
    final bool isBaseline = baseline != null && checkpoint.id == baseline.id;
    final String deltaLabel;
    if (isBaseline || baseline == null) {
      deltaLabel = 'Checkpoint baseline (titik awal, tanpa delta)';
    } else {
      final delta = checkpoint.weightKg - baseline.weightKg;
      final abs = delta.abs().toStringAsFixed(1);
      if (delta > 0) {
        deltaLabel = 'Ada Kenaikan $abs kg dari baseline';
      } else if (delta < 0) {
        deltaLabel = 'Ada Penurunan $abs kg dari baseline';
      } else {
        deltaLabel = 'Tidak ada perubahan berat dari baseline';
      }
    }

    return EggCard(
      highlight: true,
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF231F14), AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatCheckpointDate(checkpoint.recordedAt),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                StatusChip(
                  label: stageLabel,
                  color: checkpoint.isMilestone
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _HistoryValue(
                    label: 'Berat badan',
                    value: '${checkpoint.weightKg.toStringAsFixed(1)} kg',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HistoryValue(
                    label: 'Tinggi badan',
                    value: '${checkpoint.heightCm.toStringAsFixed(0)} cm',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.trending_up_rounded,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deltaLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            if (checkpoint.isMilestone) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Checkpoint ini ditandai sebagai MILESTONE',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosCard(BuildContext context, MemberCheckpoint checkpoint) {
    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Foto Pose',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ketuk foto untuk memperbesar.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _kDetailPoses.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _PosePhotoTile(
                      pose: _kDetailPoses[i],
                      checkpoint: checkpoint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, String note) {
    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catatan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            note,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

/// Satu slot foto pose (Back/Front/Side) di halaman detail. Cari foto dengan
/// type sesuai (case-insensitive). Ada foto -> thumbnail cover + Hero + tap buka
/// viewer fullscreen (reuse [_FullscreenPhotoViewer]). Tidak ada foto ->
/// placeholder yang TIDAK bisa diklik.
class _PosePhotoTile extends StatelessWidget {
  const _PosePhotoTile({required this.pose, required this.checkpoint});

  final String pose;
  final MemberCheckpoint checkpoint;

  @override
  Widget build(BuildContext context) {
    MemberCheckpointPhoto? photo;
    for (final p in checkpoint.photos) {
      if (p.type.toLowerCase() == pose.toLowerCase()) {
        photo = p;
        break;
      }
    }
    final photoUrl = _resolveCheckpointPhotoUrl(photo?.path);
    final heroTag = 'checkpoint-${checkpoint.id}-pose-$pose';
    final label = _kPoseLabels[pose] ?? pose;

    final Widget thumb = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 128,
        width: double.infinity,
        color: Colors.black.withValues(alpha: 0.25),
        child: photoUrl != null
            ? Hero(
                tag: heroTag,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined,
                        size: 30, color: AppColors.textSecondary),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              )
            : const Center(
                child: Icon(Icons.image_not_supported_outlined,
                    size: 30, color: AppColors.textSecondary),
              ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Foto null -> tidak bisa diklik (tidak buka viewer kosong).
        photoUrl == null
            ? thumb
            : GestureDetector(
                onTap: () => Navigator.of(context).push(
                  _FullscreenPhotoViewer.route(
                    photoUrl: photoUrl,
                    heroTag: heroTag,
                  ),
                ),
                child: thumb,
              ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: photoUrl != null
                    ? AppColors.accent
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

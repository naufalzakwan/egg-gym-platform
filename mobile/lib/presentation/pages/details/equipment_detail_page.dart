import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_public_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/equipment_image.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EquipmentDetailPage extends StatefulWidget {
  const EquipmentDetailPage({super.key});

  @override
  State<EquipmentDetailPage> createState() => _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends State<EquipmentDetailPage> {
  final BackendPublicService _service = BackendPublicService();
  EquipmentInfo? _equipment;
  String _source = 'guest';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is EquipmentInfo) {
      _equipment = args;
    } else if (args is Map) {
      if (args['equipment'] is EquipmentInfo) {
        _equipment = args['equipment'] as EquipmentInfo;
      }
      if (args['source'] is String) _source = args['source'] as String;
    }
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final id = _equipment?.id;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final equipment = await _service.getEquipment(id);
      if (!mounted) return;
      setState(() {
        _equipment = equipment;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Detail alat belum tersedia.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipment = _equipment;
    final isGuest = _source == 'guest';
    final visibleMovements = equipment == null
        ? const <GymEquipmentMovement>[]
        : isGuest
            ? equipment.movements.take(3).toList(growable: false)
            : equipment.movements;
    final hasHiddenGuestMovements =
        isGuest && (equipment?.movements.length ?? 0) > 3;

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DetailScreenHeader(
            title: 'Equipment Detail',
            subtitle: isGuest
                ? 'Preview alat gym, status, target otot, dan panduan dasar.'
                : 'Informasi alat dan panduan penggunaan dari Egg Gym.',
          ),
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.error)),
                ),
                TextButton(
                    onPressed: _loadDetail, child: const Text('Coba Lagi')),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (equipment == null)
            const Center(child: Text('Data alat tidak tersedia.'))
          else ...[
            _EquipmentHero(equipment: equipment),
            if (_hasText(equipment.bestFor) ||
                _hasText(equipment.difficulty)) ...[
              const SizedBox(height: 18),
              // Row stretch di dalam ListView harus diberi tinggi terhingga.
              // Tanpa IntrinsicHeight, card BEST FOR/LEVEL gagal layout dan
              // menyisakan ruang kosong sebelum section Key Benefits.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_hasText(equipment.bestFor))
                      Expanded(
                        child: _MetricCard(
                          label: 'BEST FOR',
                          value: equipment.bestFor!,
                          accent: true,
                        ),
                      ),
                    if (_hasText(equipment.bestFor) &&
                        _hasText(equipment.difficulty))
                      const SizedBox(width: 10),
                    if (_hasText(equipment.difficulty))
                      Expanded(
                        child: _MetricCard(
                          label: 'LEVEL',
                          value: equipment.difficulty!,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (equipment.keyBenefits.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Key Benefits',
                child: Column(
                  children: equipment.keyBenefits
                      .map((item) => _BulletTile(
                            icon: Icons.auto_awesome_rounded,
                            text: item,
                          ))
                      .toList(),
                ),
              ),
            ],
            if (equipment.usageFlow.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Cara Pakai Singkat',
                child: Column(
                  children: equipment.usageFlow
                      .asMap()
                      .entries
                      .map((entry) => _StepTile(
                            number: entry.key + 1,
                            text: entry.value,
                          ))
                      .toList(),
                ),
              ),
            ],
            if (equipment.safetyNotes.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Safety Notes',
                child: Column(
                  children: equipment.safetyNotes
                      .map((item) => _BulletTile(
                            icon: Icons.shield_outlined,
                            text: item,
                          ))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Gerakan yang Bisa Dilakukan',
              child: equipment.movements.isEmpty
                  ? Text(
                      'Belum ada gerakan untuk alat ini.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    )
                  : Column(
                      children: [
                        ...visibleMovements.map(
                          (movement) => _MovementTile(movement: movement),
                        ),
                        if (hasHiddenGuestMovements) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Masuk sebagai member untuk melihat semua gerakan alat.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.45,
                                    ),
                          ),
                          const SizedBox(height: 12),
                          EggButton.secondary(
                            label: 'Login untuk Lihat Semua Gerakan',
                            icon: Icons.lock_open_rounded,
                            onPressed: () => Get.offAllNamed(AppRoutes.login),
                          ),
                        ],
                      ],
                    ),
            ),
            // Related Equipment sengaja disembunyikan: belum ada relasi backend.
          ],
        ],
      ),
    );
  }
}

class _EquipmentHero extends StatelessWidget {
  const _EquipmentHero({required this.equipment});

  final EquipmentInfo equipment;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveEquipmentImageUrl(equipment.imagePath);
    return EggCard(
      highlight: true,
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54D), AppColors.accentDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_hasText(equipment.statusLabel))
                  StatusChip(
                    label: equipment.statusLabel.toUpperCase(),
                    color: _statusColor(equipment.status),
                  ),
                if (_hasText(equipment.stageLabel))
                  StatusChip(
                    label: equipment.stageLabel!,
                    color: AppColors.background,
                  ),
                if (_hasText(equipment.code))
                  StatusChip(
                    label: equipment.code!,
                    color: AppColors.background,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: imageUrl == null
                  ? null
                  : () => _showEquipmentImagePreview(
                        context,
                        imageUrl: imageUrl,
                        equipmentName: equipment.name,
                      ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 230,
                  width: double.infinity,
                  color: Colors.black.withValues(alpha: 0.12),
                  child: imageUrl == null
                      ? const Icon(Icons.fitness_center_rounded,
                          size: 54, color: AppColors.background)
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            size: 54,
                            color: AppColors.background,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              equipment.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.background,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            if (_hasText(equipment.category)) ...[
              const SizedBox(height: 6),
              Text(
                equipment.category,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.background.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            if (_hasText(equipment.description)) ...[
              const SizedBox(height: 12),
              Text(
                equipment.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.background.withValues(alpha: 0.82),
                      height: 1.45,
                    ),
              ),
            ],
            if (_hasText(equipment.focus) ||
                _hasText(equipment.usageWindow)) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_hasText(equipment.focus))
                    Expanded(
                      child: _HeroStat(
                        label: 'FOCUS',
                        value: equipment.focus,
                      ),
                    ),
                  if (_hasText(equipment.focus) &&
                      _hasText(equipment.usageWindow))
                    const SizedBox(width: 10),
                  if (_hasText(equipment.usageWindow))
                    Expanded(
                      child: _HeroStat(
                        label: 'USAGE',
                        value: equipment.usageWindow!,
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
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.background.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.background,
                    fontWeight: FontWeight.w800,
                  )),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label, required this.value, this.accent = false});
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
          Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  )),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: accent ? AppColors.accent : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  )),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _BulletTile extends StatelessWidget {
  const _BulletTile({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      )),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$number',
                style: const TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.w800,
                )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      )),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});

  final GymEquipmentMovement movement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              movement.movementName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Target: ${movement.targetArea}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

Color _statusColor(String status) {
  switch (status) {
    case 'maintenance':
      return AppColors.accent;
    case 'broken':
      return AppColors.error;
    default:
      return AppColors.success;
  }
}

Future<void> _showEquipmentImagePreview(
  BuildContext context, {
  required String imageUrl,
  required String equipmentName,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 680),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                semanticLabel: 'Preview foto $equipmentName',
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 56,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.68),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Tutup preview',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

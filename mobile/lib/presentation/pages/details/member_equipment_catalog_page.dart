import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/equipment_code_display.dart';
import 'package:egg_gym/data/services/backend_public_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/equipment_image.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MemberEquipmentCatalogPage extends StatefulWidget {
  const MemberEquipmentCatalogPage({super.key});

  @override
  State<MemberEquipmentCatalogPage> createState() =>
      _MemberEquipmentCatalogPageState();
}

class _MemberEquipmentCatalogPageState
    extends State<MemberEquipmentCatalogPage> {
  final BackendPublicService _service = BackendPublicService();
  List<EquipmentInfo> _equipments = const <EquipmentInfo>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map && args['equipments'] is List<EquipmentInfo>) {
      _equipments = args['equipments'] as List<EquipmentInfo>;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final equipments = await _service.getEquipments();
      if (!mounted) return;
      setState(() {
        _equipments = equipments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat katalog alat. Pastikan backend aktif.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedScreen(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const DetailScreenHeader(
              title: 'Alat Gym',
              subtitle:
                  'Katalog semua alat aktif dan status operasional terbarunya.',
            ),
            const SizedBox(height: 20),
            if (_loading && _equipments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 160),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _equipments.isEmpty)
              _CatalogError(message: _error!, onRetry: _load)
            else if (_equipments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: Text('Belum ada alat aktif.')),
              )
            else ...[
              Row(
                children: [
                  Text(
                    '${_equipments.length} ALAT AKTIF',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${_equipments.where((e) => e.isAvailable).length} TERSEDIA',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Gagal menyegarkan data. Menampilkan data terakhir.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              ..._equipments.map(
                (equipment) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _EquipmentCatalogCard(equipment: equipment),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EquipmentCatalogCard extends StatelessWidget {
  const _EquipmentCatalogCard({required this.equipment});

  final EquipmentInfo equipment;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveEquipmentImageUrl(equipment.imagePath);
    final equipmentCode = realEquipmentCode(equipment.code);
    return GestureDetector(
      onTap: () => Get.toNamed(
        AppRoutes.equipmentDetail,
        arguments: {'equipment': equipment, 'source': 'member'},
      ),
      child: EggCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 96,
                height: 112,
                color: AppColors.surfaceSoft,
                child: imageUrl == null
                    ? const Icon(Icons.fitness_center_rounded,
                        color: AppColors.textSecondary, size: 34)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          equipmentCode ?? equipment.name,
                          style: equipmentCode != null
                              ? Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w800,
                                  )
                              : Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      StatusChip(
                        label: equipment.statusLabel.toUpperCase(),
                        color: _statusColor(equipment.status),
                      ),
                    ],
                  ),
                  if (equipmentCode != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      equipment.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${equipment.category} · ${equipment.focus}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
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
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 44, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}

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

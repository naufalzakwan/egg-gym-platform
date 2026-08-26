import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/public_storage_url.dart';
import 'package:egg_gym/core/utils/trainer_rating_display.dart';
import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GuestHomeTabV2 extends StatelessWidget {
  const GuestHomeTabV2({
    super.key,
    required this.showcase,
    required this.isLoading,
    required this.loadError,
    required this.onRetry,
  });

  final GuestShowcaseData showcase;
  final bool isLoading;
  final String? loadError;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: onRetry,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          const _GuestHeader(),
          const SizedBox(height: 20),
          const _GuestHero(),
          const SizedBox(height: 24),
          const _GuestTimerPreview(),
          if (loadError != null) ...[
            const SizedBox(height: 14),
            _GuestLoadNotice(message: loadError!, onRetry: onRetry),
          ],
          const SizedBox(height: 22),
          const _GuestSectionHeader(
            eyebrow: 'EKSKLUSIVITAS',
            title: 'Paket Keanggotaan',
            hint: 'Geser untuk lihat',
          ),
          const SizedBox(height: 12),
          _MembershipPreview(
            plans: showcase.plans,
            loading: isLoading && showcase.plans.isEmpty,
          ),
          const SizedBox(height: 24),
          const _GuestSectionHeader(
            eyebrow: 'BIMBINGAN',
            title: 'Personal Trainer',
          ),
          const SizedBox(height: 12),
          _TrainerPreview(
            trainers: showcase.trainers,
            loading: isLoading && showcase.trainers.isEmpty,
          ),
          const SizedBox(height: 24),
          const _GuestSectionHeader(
            eyebrow: 'FASILITAS',
            title: 'Alat Gym Unggulan',
          ),
          const SizedBox(height: 12),
          _EquipmentPreview(
            equipments: showcase.equipments,
            loading: isLoading && showcase.equipments.isEmpty,
          ),
          const SizedBox(height: 26),
          _OperationHoursCard(
            hours: showcase.operationHours,
            loading: isLoading && showcase.operationHours.isEmpty,
          ),
        ],
      ),
    );
  }
}

class _GuestHeader extends StatelessWidget {
  const _GuestHeader();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: BrandLogo(compact: true, showTagline: false)),
          FilledButton(
            onPressed: () => Get.offAllNamed(AppRoutes.login),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              minimumSize: const Size(84, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Masuk',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      );
}

class _GuestHero extends StatelessWidget {
  const _GuestHero();

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 220),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A3A0D), Color(0xFF191919), Color(0xFF0D0D0D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                right: -22,
                top: 18,
                child: Icon(Icons.fitness_center_rounded,
                    size: 178, color: Color(0x1AFFD600)),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Daftar sekarang untuk\nmenikmati fitur penuh\nEggGym',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Akses program, progress latihan, membership, dan booking trainer dalam satu aplikasi.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFC8C8C8),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () => Get.toNamed(AppRoutes.register),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Daftar Sekarang'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.background,
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
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

class _GuestTimerPreview extends StatelessWidget {
  const _GuestTimerPreview();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF252525)),
        ),
        child: const Column(
          children: [
            Text('STOPWATCH',
                style: TextStyle(
                    color: Color(0xFF686868),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2)),
            SizedBox(height: 7),
            Text('00:00:00',
                style: TextStyle(
                    color: Color(0xFF4F4F4F),
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Icon(Icons.lock_rounded, color: Color(0xFF77715D), size: 21),
            SizedBox(height: 7),
            Text('Login untuk menggunakan timer',
                style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 11)),
          ],
        ),
      );
}

class _GuestSectionHeader extends StatelessWidget {
  const _GuestSectionHeader({
    required this.eyebrow,
    required this.title,
    this.hint,
  });

  final String eyebrow;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow,
              style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2)),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
              ),
              if (hint != null)
                Text(hint!,
                    style: const TextStyle(
                        color: Color(0xFF7E7E7E), fontSize: 10)),
            ],
          ),
        ],
      );
}

class _MembershipPreview extends StatelessWidget {
  const _MembershipPreview({required this.plans, required this.loading});

  final List<MembershipPlan> plans;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _GuestLoadingBox(height: 210);
    if (plans.isEmpty) {
      return const _GuestEmptyBox(message: 'Belum ada paket membership aktif.');
    }
    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: plans.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _MembershipCard(plan: plans[index]),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.plan});
  final MembershipPlan plan;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 272,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF292929),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: const Color(0xFF343434)),
                ),
              ),
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: ColoredBox(
                  color: AppColors.accent,
                  child: SizedBox(width: 3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 16, 16, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      plan.periodLabel.trim().isEmpty
                          ? 'PAKET MEMBERSHIP'
                          : plan.periodLabel.trim().toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      plan.priceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
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

class _TrainerPreview extends StatelessWidget {
  const _TrainerPreview({required this.trainers, required this.loading});
  final List<TrainerProfile> trainers;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _GuestLoadingBox(height: 238);
    if (trainers.isEmpty) {
      return const _GuestEmptyBox(message: 'Belum ada trainer aktif.');
    }
    return SizedBox(
      height: 245,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: trainers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            _GuestTrainerCard(trainer: trainers[index]),
      ),
    );
  }
}

class _GuestTrainerCard extends StatelessWidget {
  const _GuestTrainerCard({required this.trainer});
  final TrainerProfile trainer;

  @override
  Widget build(BuildContext context) {
    final photo = resolvePublicStorageUrl(
      trainer.displayPhotoPath ?? trainer.avatarUrl,
    );
    final tierLabel = trainerTierLabel(trainer.tier);
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: const Color(0xFF252525),
            backgroundImage: photo == null ? null : NetworkImage(photo),
            child: photo == null
                ? Text(_initials(trainer.name),
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w900))
                : null,
          ),
          const SizedBox(height: 13),
          Text(trainer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2B23),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(trainer.specialty,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: AppColors.accent, size: 17),
              const SizedBox(width: 4),
              Text(
                trainerRatingDisplay(
                  rating: trainer.rating,
                  reviewsCount: trainer.reviewsCount,
                ),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
              if (tierLabel != null) ...[
                const SizedBox(width: 7),
                Text(tierLabel,
                    style:
                        const TextStyle(color: Color(0xFF8A8A8A), fontSize: 9)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EquipmentPreview extends StatelessWidget {
  const _EquipmentPreview({required this.equipments, required this.loading});
  final List<EquipmentInfo> equipments;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _GuestLoadingBox(height: 220);
    if (equipments.isEmpty) {
      return const _GuestEmptyBox(message: 'Belum ada alat gym aktif.');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: equipments
              .take(4)
              .map((equipment) => SizedBox(
                    width: width,
                    child: _GuestEquipmentCard(equipment: equipment),
                  ))
              .toList(growable: false),
        );
      },
    );
  }
}

class _GuestEquipmentCard extends StatelessWidget {
  const _GuestEquipmentCard({required this.equipment});
  final EquipmentInfo equipment;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolvePublicStorageUrl(equipment.imagePath);
    return Semantics(
      button: true,
      label: 'Lihat detail ${equipment.name}',
      child: Material(
        color: const Color(0xFF292929),
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Get.toNamed(
            AppRoutes.equipmentDetail,
            arguments: <String, dynamic>{
              'equipment': equipment,
              'source': 'guest',
            },
          ),
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFF303030)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF202020),
                    child: imageUrl == null
                        ? const Icon(Icons.fitness_center_rounded,
                            color: AppColors.accent, size: 42)
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.fitness_center_rounded,
                              color: AppColors.accent,
                              size: 42,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(equipment.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      if (equipment.category.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(equipment.category.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF8A8A8A),
                                fontSize: 8,
                                fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OperationHoursCard extends StatelessWidget {
  const _OperationHoursCard({required this.hours, required this.loading});
  final List<OperationHour> hours;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF202020)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.schedule_rounded, color: AppColors.accent, size: 22),
                SizedBox(width: 10),
                Text('Jam Operasional',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 15),
            if (loading)
              const Center(
                  child: CircularProgressIndicator(color: AppColors.accent))
            else if (hours.isEmpty)
              const Text('Jam operasional belum tersedia.',
                  style: TextStyle(color: Color(0xFF8A8A8A)))
            else
              ...hours.asMap().entries.map(
                    (entry) => Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(entry.value.day,
                                    style: const TextStyle(
                                        color: Color(0xFFD0D0D0),
                                        fontSize: 12)),
                              ),
                              Text(entry.value.hours,
                                  style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        if (entry.key < hours.length - 1)
                          const Divider(height: 1, color: Color(0xFF242424)),
                      ],
                    ),
                  ),
          ],
        ),
      );
}

class _GuestLoadNotice extends StatelessWidget {
  const _GuestLoadNotice({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Color(0xFF9A9A9A), size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message, style: const TextStyle(fontSize: 11))),
            TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      );
}

class _GuestLoadingBox extends StatelessWidget {
  const _GuestLoadingBox({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
}

class _GuestEmptyBox extends StatelessWidget {
  const _GuestEmptyBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFF242424)),
        ),
        child: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 12)),
      );
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final value = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return value.isEmpty ? '?' : value;
}

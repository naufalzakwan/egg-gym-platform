import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TrainerShareProfilePage extends StatelessWidget {
  const TrainerShareProfilePage({super.key});

  TrainerProfile? _resolveTrainer() {
    final argument = Get.arguments;
    if (argument is TrainerProfile) {
      return argument;
    }
    if (argument is Map<String, dynamic> &&
        argument['trainer'] is TrainerProfile) {
      return argument['trainer'] as TrainerProfile;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final trainer = _resolveTrainer();
    if (trainer == null) return const _InvalidTrainerSharePage();
    final tierLabel = trainerTierLabel(trainer.tier);

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const DetailScreenHeader(
            title: 'Bagikan Profil',
            subtitle:
                'Preview share profile trainer untuk kebutuhan demo. Nanti bisa disambungkan ke deep link atau share sheet nyata.',
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
                      if (tierLabel != null)
                        StatusChip(
                          label: tierLabel,
                          color: AppColors.background,
                        ),
                      const StatusChip(
                        label: 'SHARE PREVIEW',
                        color: AppColors.background,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    trainer.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.background,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trainer.specialty,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.background.withValues(alpha: 0.8),
                        ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    trainer.bio,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.background.withValues(alpha: 0.8),
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
                  'Share Link',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'egggym.app/trainer/${trainer.name.toLowerCase().replaceAll(' ', '-')}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Deep link ini nanti bisa dibagikan ke member atau calon member untuk membuka profil coach langsung dari mobile app atau web.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
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
                  'Channel Preview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                const _ShareOptionTile(
                  icon: Icons.message_outlined,
                  title: 'WhatsApp Member',
                  subtitle: 'Kirim profil coach ke lead atau member aktif.',
                ),
                const SizedBox(height: 10),
                const _ShareOptionTile(
                  icon: Icons.link_rounded,
                  title: 'Copy Link',
                  subtitle:
                      'Salin tautan profil untuk dipakai di web admin atau chat.',
                ),
                const SizedBox(height: 10),
                const _ShareOptionTile(
                  icon: Icons.qr_code_2_outlined,
                  title: 'Generate QR',
                  subtitle: 'Opsi lanjut untuk poster gym atau kartu trainer.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          EggButton.primary(
            label: 'Kembali ke Pengaturan Akun',
            onPressed: () => Get.toNamed(
              AppRoutes.trainerAccountSettings,
              arguments: {
                'trainer': trainer,
              },
            ),
          ),
          const SizedBox(height: 10),
          EggButton.secondary(
            label: 'Kembali ke Profil Lengkap',
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }
}

class _InvalidTrainerSharePage extends StatelessWidget {
  const _InvalidTrainerSharePage();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Bagikan Profil')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Data trainer tidak valid untuk dibagikan.',
              key: Key('invalid-trainer-share'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}

class _ShareOptionTile extends StatelessWidget {
  const _ShareOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
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
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
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

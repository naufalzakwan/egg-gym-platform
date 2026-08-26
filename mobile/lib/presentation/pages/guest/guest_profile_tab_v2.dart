import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/public_settings_service.dart';
import 'package:egg_gym/presentation/pages/guest/guest_shared_shell_widgets.dart';
import 'package:egg_gym/presentation/widgets/common/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GuestProfileTabV2 extends StatelessWidget {
  const GuestProfileTabV2({super.key});

  void _openLogin() => Get.offAllNamed(AppRoutes.login);

  void _openRegister() => Get.toNamed(AppRoutes.register);

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      children: [
        _GuestProfileHeader(onLogin: _openLogin),
        const SizedBox(height: 28),
        const _SignedOutCard(),
        const SizedBox(height: 22),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _openLogin,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.login_rounded, size: 20),
            label: const Text(
              'Masuk',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 11),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _openRegister,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: Color(0xFF51482B)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
            label: const Text(
              'Daftar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 32),
        const _MembershipBenefitCard(),
        const SizedBox(height: 14),
        const _GymInformationCard(),
        const SizedBox(height: 14),
        const ProfileActionCard(
          title: 'Bantuan & Panduan',
          subtitle: 'Cara menggunakan fitur publik Egg Gym',
          icon: Icons.help_outline_rounded,
          routeName: AppRoutes.helpCenter,
          arguments: {'role': 'guest'},
        ),
        const SizedBox(height: 14),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MiniBenefitCard(
                icon: Icons.bolt_rounded,
                title: 'Program\nLatihan',
                subtitle: 'Program terarah',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _MiniBenefitCard(
                icon: Icons.groups_rounded,
                title: 'Private Trainer',
                subtitle: 'Trainer profesional',
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _GuestPromoBanner(),
      ],
    );
  }
}

class _GymInformationCard extends StatelessWidget {
  const _GymInformationCard();

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<PublicAppSettings>(
        valueListenable: PublicSettingsService.instance.settings,
        builder: (context, settings, _) {
          final rows = <(IconData, String)>[
            if (settings.location.isNotEmpty)
              (Icons.location_on_outlined, settings.location),
            if (settings.phone.isNotEmpty)
              (Icons.phone_outlined, settings.phone),
            if (settings.whatsapp.isNotEmpty)
              (Icons.chat_outlined, settings.whatsapp),
            if (settings.email.isNotEmpty)
              (Icons.email_outlined, settings.email),
            if (settings.instagram.isNotEmpty)
              (Icons.camera_alt_outlined, settings.instagram),
          ];
          if (rows.isEmpty) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF242424)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('INFORMASI GYM',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
              const SizedBox(height: 12),
              ...rows.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(row.$1, color: AppColors.accent, size: 17),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(row.$2,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      height: 1.4))),
                        ]),
                  )),
            ]),
          );
        },
      );
}

class _GuestProfileHeader extends StatelessWidget {
  const _GuestProfileHeader({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: BrandLogo(compact: true, showTagline: false)),
          TextButton(
            onPressed: onLogin,
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text(
              'Masuk',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      );
}

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 32, 22, 30),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF202020)),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 136,
              height: 126,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 126,
                    height: 126,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.035),
                        width: 16,
                      ),
                    ),
                  ),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: Color(0xFF343434),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_off_rounded,
                      color: Color(0xFF858585),
                      size: 37,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Kamu belum masuk',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Masuk atau daftar untuk mengakses program latihan dan memantau progres kebugaranmu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFB8B09F),
                fontSize: 12,
                height: 1.55,
              ),
            ),
          ],
        ),
      );
}

class _MembershipBenefitCard extends StatelessWidget {
  const _MembershipBenefitCard();

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          constraints: const BoxConstraints(minHeight: 166),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF303030), Color(0xFF272727)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -25,
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: Colors.white.withValues(alpha: 0.07),
                  size: 116,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(22, 22, 64, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEMBERSHIP',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                    SizedBox(height: 13),
                    Text(
                      'Akses Semua Fasilitas &\nTrainer Terbaik',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Bergabunglah dengan komunitas EggGym dan capai target kebugaranmu.',
                      style: TextStyle(
                        color: Color(0xFFA29B8C),
                        fontSize: 10,
                        height: 1.5,
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

class _MiniBenefitCard extends StatelessWidget {
  const _MiniBenefitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 140),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF292929),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.accent, size: 25),
            const SizedBox(height: 17),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
}

class _GuestPromoBanner extends StatelessWidget {
  const _GuestPromoBanner();

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          height: 155,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF343434), Color(0xFF101010)],
                  ),
                ),
              ),
              Positioned(
                right: 18,
                top: 10,
                child: Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.white.withValues(alpha: 0.08),
                  size: 118,
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xE8121212)],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 17,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      color: AppColors.accent,
                      child: const Text(
                        'MULAI HARI INI',
                        style: TextStyle(
                          color: AppColors.background,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Bangun kebiasaan latihan bersama EggGym',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
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

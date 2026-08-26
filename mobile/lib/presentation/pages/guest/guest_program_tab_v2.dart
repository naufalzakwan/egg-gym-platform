import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/presentation/widgets/common/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GuestProgramTabV2 extends StatelessWidget {
  const GuestProgramTabV2({
    super.key,
    required this.onOpenMembership,
  });

  final VoidCallback onOpenMembership;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      children: [
        const _ProgramGuestHeader(),
        const SizedBox(height: 20),
        const _ProgramHero(),
        const SizedBox(height: 22),
        _LockedAccessCard(onOpenMembership: onOpenMembership),
        const SizedBox(height: 22),
        const _MembershipBenefitsCard(),
      ],
    );
  }
}

class _ProgramGuestHeader extends StatelessWidget {
  const _ProgramGuestHeader();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: BrandLogo(compact: true, showTagline: false)),
          TextButton(
            onPressed: () => Get.offAllNamed(AppRoutes.login),
            child: const Text(
              'Masuk',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
}

class _ProgramHero extends StatelessWidget {
  const _ProgramHero();

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Container(
          height: 178,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B1B1B), Color(0xFF101010)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              const Positioned(
                left: -30,
                right: -16,
                bottom: -20,
                child: Text(
                  'PROGRAM',
                  maxLines: 1,
                  style: TextStyle(
                    color: Color(0xFF292929),
                    fontSize: 82,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -5,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 34, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EKSKLUSIF MEMBER',
                      style: TextStyle(
                        color: Color(0xFFB0A98E),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Program Latihan\nTerpersonalisasi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
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

class _LockedAccessCard extends StatelessWidget {
  const _LockedAccessCard({required this.onOpenMembership});

  final VoidCallback onOpenMembership;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 25, 22, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF292929),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF343434)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 20,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF3A3A3A),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: AppColors.accent,
                size: 34,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Akses Terbatas',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 11),
            const Text(
              'Program latihan hanya tersedia untuk member yang sudah login. Dapatkan akses ke rutinitas latihan profesional yang terarah.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFC0B8A3),
                fontSize: 12,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Get.offAllNamed(AppRoutes.login),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Masuk / Daftar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 9),
            TextButton(
              onPressed: onOpenMembership,
              child: const Text(
                'PELAJARI MEMBERSHIP',
                style: TextStyle(
                  color: Color(0xFFD4CEBC),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      );
}

class _MembershipBenefitsCard extends StatelessWidget {
  const _MembershipBenefitsCard();

  static const _benefits = <String>[
    'Akses fasilitas gym sesuai paket aktif',
    'Booking sesi Personal Trainer',
    'Pantau program latihan dan progres fisik',
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF252525)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF393316),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'KENAPA MEMBERSHIP?',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 17),
            const Text(
              'Latihan Lebih Terarah\ndengan EGG GYM',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1.25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            ..._benefits.map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        benefit,
                        style: const TextStyle(
                          color: Color(0xFFC7C0AF),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const _TrainingVisual(),
          ],
        ),
      );
}

class _TrainingVisual extends StatelessWidget {
  const _TrainingVisual();

  @override
  Widget build(BuildContext context) => Container(
        height: 205,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF333333), Color(0xFF151515)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFF303030)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(
              right: -12,
              bottom: -20,
              child: Icon(
                Icons.fitness_center_rounded,
                color: Color(0x1AFFFFFF),
                size: 180,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF3A351A),
                  ),
                  child: const Icon(
                    Icons.sports_gymnastics_rounded,
                    color: AppColors.accent,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'PROGRAM TERARAH',
                  style: TextStyle(
                    color: Color(0xFFC9C3B0),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

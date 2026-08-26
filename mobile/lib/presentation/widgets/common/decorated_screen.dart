import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class DecoratedScreen extends StatelessWidget {
  const DecoratedScreen({
    super.key,
    required this.child,
    this.safeArea = true,
    this.showGlow = true,
  });

  final Widget child;
  final bool safeArea;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final content = safeArea ? SafeArea(child: child) : child;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: showGlow
          ? Stack(
              children: [
                Positioned(
                  top: -80,
                  right: -40,
                  child: _GlowOrb(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    size: 220,
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: -60,
                  child: _GlowOrb(
                    color: const Color(0x30FFFFFF),
                    size: 240,
                  ),
                ),
                content,
              ],
            )
          : ColoredBox(
              color: AppColors.background,
              child: SizedBox.expand(child: content),
            ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

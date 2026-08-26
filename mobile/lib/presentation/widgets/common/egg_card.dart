import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class EggCard extends StatelessWidget {
  const EggCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final borderColor = highlight
        ? AppColors.accent.withValues(alpha: 0.44)
        : Colors.white.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: highlight
              ? const [Color(0xFF231F14), AppColors.surface]
              : const [AppColors.surfaceElevated, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          if (highlight)
            const BoxShadow(
              color: Color(0x22FFD700),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
        ],
      ),
      child: child,
    );
  }
}

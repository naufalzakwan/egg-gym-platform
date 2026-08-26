import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class EggButton extends StatelessWidget {
  const EggButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
  }) : isPrimary = true;

  const EggButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
  }) : isPrimary = false;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Ikon opsional di SISI KANAN teks (mis. panah "->"). Beda dari [icon]
  /// yang tampil di kiri (leading). Bila diisi, tombol memakai layout Row
  /// label + ikon kanan.
  final IconData? trailingIcon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final foreground = isPrimary ? AppColors.background : AppColors.accent;
    final background = isPrimary ? AppColors.accent : AppColors.surfaceElevated;
    final border = isPrimary
        ? Colors.transparent
        : AppColors.accent.withValues(alpha: 0.36);
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        );

    return SizedBox(
      width: double.infinity,
      child: icon == null
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: background,
                foregroundColor: foreground,
                disabledBackgroundColor:
                    AppColors.surfaceElevated.withValues(alpha: 0.6),
                disabledForegroundColor: AppColors.textSecondary,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                minimumSize: const Size.fromHeight(56),
                shadowColor:
                    isPrimary ? AppColors.accent.withValues(alpha: 0.28) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: border),
                ),
                textStyle: textStyle,
              ),
              child: trailingIcon == null
                  ? Text(label)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(label),
                        const SizedBox(width: 8),
                        Icon(trailingIcon, size: 18),
                      ],
                    ),
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: background,
                foregroundColor: foreground,
                disabledBackgroundColor:
                    AppColors.surfaceElevated.withValues(alpha: 0.6),
                disabledForegroundColor: AppColors.textSecondary,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                minimumSize: const Size.fromHeight(56),
                shadowColor:
                    isPrimary ? AppColors.accent.withValues(alpha: 0.28) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: border),
                ),
                textStyle: textStyle,
              ),
            ),
    );
  }
}

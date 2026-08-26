import 'package:cached_network_image/cached_network_image.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/public_storage_url.dart';
import 'package:egg_gym/data/services/public_settings_service.dart';
import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.compact = false,
    this.showTagline = true,
    this.showFallbackIcon = true,
    this.vertical = false,
    this.taglineColor,
    this.logoSize,
  });

  final bool compact;
  final bool showTagline;
  final bool showFallbackIcon;
  final bool vertical;
  final Color? taglineColor;
  final double? logoSize;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PublicAppSettings>(
      valueListenable: PublicSettingsService.instance.settings,
      builder: (context, settings, _) => _buildLogo(context, settings),
    );
  }

  Widget _buildLogo(BuildContext context, PublicAppSettings settings) {
    final resolvedLogoSize = logoSize ?? (compact ? 34.0 : 58.0);
    final iconSize = compact ? 18.0 : resolvedLogoSize * 0.48;
    final resolvedLogo = resolvePublicStorageUrl(settings.logoPath);
    final titleStyle = compact
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.headlineSmall;

    final logo = Container(
      width: resolvedLogoSize,
      height: resolvedLogoSize,
      decoration: resolvedLogo == null
          ? BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(compact ? 12 : 20),
            )
          : BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(compact ? 8 : 12),
            ),
      child: _BrandImage(
        settings: settings,
        iconSize: iconSize,
        resolvedLogo: resolvedLogo,
        showFallbackIcon: showFallbackIcon,
      ),
    );
    final labels = Column(
      crossAxisAlignment:
          vertical ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          settings.brandName,
          textAlign: vertical ? TextAlign.center : TextAlign.start,
          style: titleStyle?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (showTagline)
          Text(
            settings.tagline,
            textAlign: vertical ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: taglineColor ?? AppColors.textSecondary,
                ),
          ),
      ],
    );

    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [logo, const SizedBox(height: 14), labels],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [logo, const SizedBox(width: 12), labels],
    );
  }
}

class _BrandImage extends StatelessWidget {
  const _BrandImage({
    required this.settings,
    required this.iconSize,
    required this.resolvedLogo,
    required this.showFallbackIcon,
  });
  final PublicAppSettings settings;
  final double iconSize;
  final String? resolvedLogo;
  final bool showFallbackIcon;

  @override
  Widget build(BuildContext context) {
    final fallback = showFallbackIcon
        ? Icon(Icons.fitness_center_rounded,
            color: AppColors.accent, size: iconSize)
        : const SizedBox.shrink();
    final resolved = resolvedLogo;
    if (resolved == null) return fallback;
    final separator = resolved.contains('?') ? '&' : '?';
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: '$resolved${separator}v=${settings.logoVersion}',
        fit: BoxFit.contain,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

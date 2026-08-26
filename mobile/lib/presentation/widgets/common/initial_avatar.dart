import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/public_storage_url.dart';
import 'package:flutter/material.dart';

class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.name,
    this.radius = 24,
    this.avatarPath,
    this.onTap,
    this.semanticLabel,
  });

  final String name;
  final double radius;

  /// Relative path avatar dari backend (mis. "avatars/abc.jpg"). Bila diisi,
  /// foto dirender dengan merangkai baseUrl AKTIF (dari session) + /storage/ +
  /// path -- konsisten dgn resolver baseUrl (tahan ganti IP LAN). Null/kosong
  /// -> tampil inisial nama. Gagal muat (broken) -> fallback ke inisial juga.
  final String? avatarPath;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Rangkai URL penuh foto dari relative path + baseUrl aktif.
  /// Kembalikan null bila tak ada path / baseUrl belum tersedia.
  String? _resolveAvatarUrl() {
    return resolvePublicStorageUrl(avatarPath);
  }

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters =
        parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join();
    return letters.isEmpty ? '?' : letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolveAvatarUrl();

    final initialsChild = Text(
      _initials,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w700,
          ),
    );

    final avatar = Container(
      width: radius * 2,
      height: radius * 2,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [AppColors.accentBronze, Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: url == null
          ? initialsChild
          : Image.network(
              url,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              // Broken image / gagal fetch -> jangan tampil ikon rusak,
              // fallback ke inisial supaya tetap rapi.
              errorBuilder: (_, __, ___) => Center(child: initialsChild),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Center(child: initialsChild);
              },
            ),
    );

    if (onTap == null) return avatar;

    return Semantics(
      button: true,
      label: semanticLabel ?? 'Buka profil',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: radius * 2 < 44 ? 44 : radius * 2,
          height: radius * 2 < 44 ? 44 : radius * 2,
          child: Center(child: avatar),
        ),
      ),
    );
  }
}

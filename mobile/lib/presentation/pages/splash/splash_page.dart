import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/public_storage_url.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/public_settings_service.dart';
import 'package:egg_gym/data/services/notification_center_service.dart';
import 'package:egg_gym/presentation/widgets/common/brand_logo.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _minimumTimer;
  Timer? _maximumTimer;
  Timer? _brandingVisibleTimer;
  bool _minimumElapsed = false;
  bool _brandingVisibleElapsed = false;
  bool _navigated = false;
  bool _brandingVisualReady = false;
  bool _preparingBranding = false;

  @override
  void initState() {
    super.initState();
    PublicSettingsService.instance.state.addListener(_brandingStateChanged);
    _minimumTimer = Timer(const Duration(milliseconds: 1500), () {
      _minimumElapsed = true;
      _tryNavigate();
    });
    _maximumTimer = Timer(const Duration(seconds: 6), () => _navigate());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareBrandingVisual();
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    _maximumTimer?.cancel();
    _brandingVisibleTimer?.cancel();
    PublicSettingsService.instance.state.removeListener(_brandingStateChanged);
    super.dispose();
  }

  void _brandingStateChanged() {
    _prepareBrandingVisual();
  }

  Future<void> _prepareBrandingVisual() async {
    if (_preparingBranding || !mounted) return;
    final state = PublicSettingsService.instance.state.value;
    if (state == PublicSettingsState.initial) {
      if (_brandingVisualReady) setState(() => _brandingVisualReady = false);
      return;
    }

    _preparingBranding = true;
    final settings = PublicSettingsService.instance.settings.value;
    final resolvedLogo = resolvePublicStorageUrl(settings.logoPath);
    if (state == PublicSettingsState.ready && resolvedLogo != null) {
      final separator = resolvedLogo.contains('?') ? '&' : '?';
      try {
        await precacheImage(
          CachedNetworkImageProvider(
            '$resolvedLogo${separator}v=${settings.logoVersion}',
          ),
          context,
        );
      } catch (_) {
        // Branding text remains usable if the uploaded logo cannot be decoded.
      }
    }
    if (!mounted) return;
    setState(() {
      _brandingVisualReady = true;
      _preparingBranding = false;
    });
    _brandingVisibleTimer ??= Timer(const Duration(seconds: 2), () {
      _brandingVisibleElapsed = true;
      _tryNavigate();
    });
  }

  void _tryNavigate() {
    final state = PublicSettingsService.instance.state.value;
    if (_minimumElapsed &&
        _brandingVisibleElapsed &&
        state != PublicSettingsState.initial &&
        _brandingVisualReady) {
      _navigate();
    }
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    final session = AppSessionService.instance.currentSession;
    if (session?.role == 'trainer') {
      Get.offNamed(AppRoutes.trainerShell);
    } else if (session?.role == 'member') {
      Get.offNamed(AppRoutes.memberShell);
    } else {
      Get.offNamed(AppRoutes.login);
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => NotificationCenterService.instance.dispatchPendingPush(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = PublicSettingsService.instance.state.value;
    return DecoratedScreen(
      safeArea: false,
      showGlow: false,
      child: Center(
        child: !_brandingVisualReady
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : settingsState == PublicSettingsState.ready
                ? const BrandLogo(
                    showFallbackIcon: false,
                    vertical: true,
                    taglineColor: AppColors.accent,
                    logoSize: 88,
                  )
                : settingsState == PublicSettingsState.failed
                    ? ValueListenableBuilder<PublicAppSettings>(
                        valueListenable:
                            PublicSettingsService.instance.settings,
                        builder: (context, settings, _) => Text(
                          settings.brandName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      )
                    : const SizedBox.shrink(),
      ),
    );
  }
}

import 'package:egg_gym/app/app.dart';
import 'package:egg_gym/data/services/public_settings_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows login screen after splash delay',
      (WidgetTester tester) async {
    PublicSettingsService.instance.state.value = PublicSettingsState.initial;
    PublicSettingsService.instance.settings.value = PublicAppSettings.fallback;
    await tester.pumpWidget(const EggGymApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<DecoratedScreen>(find.byType(DecoratedScreen)).showGlow,
      isFalse,
    );
    expect(find.byIcon(Icons.fitness_center_rounded), findsNothing);
    expect(find.text('EggGym'), findsNothing);

    PublicSettingsService.instance.settings.value = PublicAppSettings.fromJson({
      'gym': {'brand_name': 'Brand Admin', 'tagline': 'Tagline Admin'},
    });
    PublicSettingsService.instance.state.value = PublicSettingsState.ready;
    await tester.pump();

    expect(find.text('Brand Admin'), findsOneWidget);
    expect(find.text('Tagline Admin'), findsOneWidget);
    expect(find.text('Built for stronger routines'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('Brand Admin'), findsOneWidget);
    expect(find.text('Selamat Datang'), findsNothing);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang'), findsOneWidget);
    expect(find.text('Masuk ke akun Brand Admin Anda'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Selamat Datang')).textAlign,
        TextAlign.center);
    expect(
        tester
            .widget<Text>(find.text('Masuk ke akun Brand Admin Anda'))
            .textAlign,
        TextAlign.center);
    expect(find.text('Lanjut sebagai Guest'), findsOneWidget);
  });
}

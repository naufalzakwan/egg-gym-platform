import 'dart:io';

import 'package:egg_gym/core/theme/app_theme.dart';
import 'package:egg_gym/data/services/public_settings_service.dart';
import 'package:egg_gym/presentation/pages/details/help_center_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    PublicSettingsService.instance.settings.value = PublicAppSettings.fallback;
  });

  Widget app(HelpAudience audience) => GetMaterialApp(
        theme: AppTheme.dark(),
        home: HelpCenterPage(audience: audience),
      );

  testWidgets('Guest sees public help topics and contact fallback',
      (tester) async {
    await tester.pumpWidget(app(HelpAudience.guest));
    await tester.pumpAndSettle();

    expect(find.text('Pusat Bantuan'), findsOneWidget);
    expect(
      find.text('Temukan panduan penggunaan aplikasi Egg Gym.'),
      findsOneWidget,
    );
    expect(find.text('Cara melihat paket membership'), findsOneWidget);
    expect(find.text('Cara membuat booking PT'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('help-contact-card')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Egg Gym Pontianak'), findsWidgets);
    expect(find.text('Hubungi admin Egg Gym di tempat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Member search finds booking and password guidance',
      (tester) async {
    await tester.pumpWidget(app(HelpAudience.member));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('help-search-field')),
      'booking',
    );
    await tester.pump();

    expect(find.text('Cara membuat booking PT'), findsOneWidget);
    expect(find.text('Cara membeli membership'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('help-search-field')),
      'password',
    );
    await tester.pump();

    expect(
      find.text('Cara meminta bantuan ketika lupa password'),
      findsOneWidget,
    );
    expect(find.text('Cara membuat booking PT'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Category filters topics and unknown search shows empty state',
      (tester) async {
    await tester.pumpWidget(app(HelpAudience.member));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('help-category-Membership')));
    await tester.pump();

    expect(find.text('Cara membeli membership'), findsOneWidget);
    expect(find.text('Cara membuat booking PT'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('help-search-field')),
      'topik-yang-tidak-tersedia',
    );
    await tester.pump();

    expect(find.byKey(const Key('help-empty-state')), findsOneWidget);
    expect(
      find.text(
        'Topik bantuan tidak ditemukan. Coba gunakan kata kunci lain atau hubungi admin Egg Gym.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trainer sees operational help without Member-only topics',
      (tester) async {
    await tester.pumpWidget(app(HelpAudience.trainer));
    await tester.pumpAndSettle();

    expect(find.text('Cara mengonfirmasi booking'), findsOneWidget);
    expect(find.text('Cara membeli membership'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('help-search-field')),
      'badge',
    );
    await tester.pump();

    expect(find.text('Arti badge merah Permintaan Booking'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Profile menus expose Help with the correct role', () {
    final guest = File(
      'lib/presentation/pages/guest/guest_profile_tab_v2.dart',
    ).readAsStringSync();
    final member = File(
      'lib/presentation/pages/member/member_shell_page.dart',
    ).readAsStringSync();
    final trainer = File(
      'lib/presentation/pages/trainer/trainer_shell_page.dart',
    ).readAsStringSync();

    for (final source in [guest, member, trainer]) {
      expect(source, contains("title: 'Bantuan & Panduan'"));
      expect(source, contains('AppRoutes.helpCenter'));
    }
    expect(guest, contains("arguments: {'role': 'guest'}"));
    expect(member, contains("arguments: const {'role': 'member'}"));
    expect(trainer, contains("arguments: {'role': 'trainer'}"));
  });
}

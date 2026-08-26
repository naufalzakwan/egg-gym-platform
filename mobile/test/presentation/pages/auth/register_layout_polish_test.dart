import 'package:egg_gym/data/services/public_settings_service.dart';
import 'package:egg_gym/presentation/pages/auth/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    PublicSettingsService.instance.settings.value = PublicAppSettings.fallback;
  });

  testWidgets('register starts at title without brand on standard emulator',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GetMaterialApp(home: RegisterPage()));
    await tester.pump();

    final title = tester.getRect(find.byKey(const Key('register-title')));
    final submit =
        tester.getRect(find.byKey(const Key('register-submit-button')));
    expect(title.top, 48);
    expect(find.text('EGG GYM'), findsNothing);
    expect(find.text('Your Gym, Smarter'), findsNothing);
    expect(submit.bottom, lessThanOrEqualTo(915));
    expect(find.text('Daftar sebagai member untuk mulai berlatih.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('register validation errors wrap without ellipsis',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GetMaterialApp(home: RegisterPage()));
    await tester.scrollUntilVisible(
      find.byKey(const Key('register-submit-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
    await tester.pump();
    await tester.tap(find.byKey(const Key('register-submit-button')));
    await tester.pump();

    expect(find.text('Nama lengkap wajib diisi.'), findsOneWidget);
    expect(find.text('Nomor HP wajib diisi.'), findsOneWidget);
    expect(find.text('Password wajib diisi.'), findsOneWidget);
    for (final decorator
        in tester.widgetList<InputDecorator>(find.byType(InputDecorator))) {
      expect(decorator.decoration.errorMaxLines, 2);
    }
    expect(tester.takeException(), isNull);
  });
}

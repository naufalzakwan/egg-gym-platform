import 'package:egg_gym/data/services/public_settings_service.dart';
import 'package:egg_gym/presentation/pages/auth/login_page.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    PublicSettingsService.instance.settings.value = PublicAppSettings.fallback;
  });

  testWidgets('login is compact on a small screen without forgot password',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GetMaterialApp(home: LoginPage()));

    expect(find.text('Selamat Datang'), findsOneWidget);
    expect(find.text('Lupa Password?'), findsNothing);
    expect(find.text('Masuk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login eye toggles password visibility', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: LoginPage()));

    EditableText passwordField() =>
        tester.widgetList<EditableText>(find.byType(EditableText)).last;

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('Tampilkan password'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
    expect(find.byTooltip('Sembunyikan password'), findsOneWidget);
  });

  testWidgets('password field has balanced spacing before login button',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: LoginPage()));

    final passwordField =
        tester.getRect(find.byKey(const Key('login-password-field')));
    final loginButton =
        tester.getRect(find.byKey(const Key('login-submit-button')));

    expect(loginButton.top - passwordField.bottom, 28);
    expect(find.text('Lupa Password?'), findsNothing);
  });

  testWidgets('login disables decorative background glow locally',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: LoginPage()));

    final screen = tester.widget<DecoratedScreen>(find.byType(DecoratedScreen));
    expect(screen.showGlow, isFalse);
  });
}

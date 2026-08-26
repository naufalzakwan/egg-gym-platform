import 'package:egg_gym/presentation/pages/auth/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('phone field keeps digits only and stops at fifteen digits',
      (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: RegisterPage())),
    );
    await tester.pump();

    final phone = find.byKey(const Key('register-phone-field'));
    expect(phone, findsOneWidget);

    await tester.enterText(
      phone,
      '+62 08abc-222222222222222222222222222',
    );
    await tester.pump();

    final field = tester.widget<TextFormField>(phone);
    expect(field.controller?.text, '620822222222222');
    expect(field.controller?.text.length, 15);
  });
}

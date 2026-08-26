import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'register uses field validators and digit-only phone without clearing inputs',
      () {
    final source = File(
      'lib/presentation/pages/auth/register_page.dart',
    ).readAsStringSync();

    expect(source, contains('final _formKey = GlobalKey<FormState>()'));
    expect(source, contains('key: _formKey'));
    expect(source, contains('TextFormField('));
    expect(source, contains('validator: AccountInputValidators.fullName'));
    expect(source, contains('validator: AccountInputValidators.phone'));
    expect(
        source, contains('validator: AccountInputValidators.strongPassword'));
    expect(source, contains('FilteringTextInputFormatter.digitsOnly'));
    expect(source, contains('LengthLimitingTextInputFormatter(15)'));
    expect(source, contains("Key('register-phone-field')"));
    expect(source, contains("hint: 'Password kuat'"));
    expect(source, contains('errorMaxLines: 2'));
    expect(source, isNot(contains('Minimal 8 karakter, huruf besar/kecil')));
    expect(source, isNot(contains('BrandLogo')));
    expect(source, contains('_formKey.currentState?.validate()'));
    expect(source, contains('final password = _passwordController.text;'));
    expect(source, isNot(contains('_passwordController.text.trim()')));
    expect(source, isNot(contains('_nameController.clear()')));
    expect(source, isNot(contains('_phoneController.clear()')));
  });
}

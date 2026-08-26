import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('clickable avatar has a comfortable target and invokes callback',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InitialAvatar(
            name: 'Bale Member',
            radius: 16,
            onTap: () => taps++,
            semanticLabel: 'Buka Profil Member',
          ),
        ),
      ),
    );

    final target = find.byType(GestureDetector);
    expect(target, findsOneWidget);
    expect(tester.getSize(target).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(target).height, greaterThanOrEqualTo(44));

    await tester.tap(target);
    expect(taps, 1);
  });

  testWidgets('avatar without callback keeps its original visual size',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: InitialAvatar(name: 'Bale', radius: 16)),
      ),
    );

    expect(tester.getSize(find.byType(InitialAvatar)), const Size(32, 32));
  });
}

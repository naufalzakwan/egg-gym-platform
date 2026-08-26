import 'package:egg_gym/core/theme/app_theme.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:egg_gym/presentation/pages/details/member_trainer_rating_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const program = MemberProgramData(
    id: 12,
    title: 'Program Selesai',
    status: 'completed',
    trainerName: 'Coach Elena',
    progressPercent: 100,
    totalSessions: 1,
    completedSessions: 1,
    programCompleted: true,
    canRate: true,
  );

  testWidgets('completed unrated card and badge open rating page',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: GestureDetector(
              key: const Key('rating-card'),
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MemberTrainerRatingPage(
                    program: program,
                    submitRating: ({
                      required trainingProgramId,
                      required rating,
                      testimonial,
                    }) async {},
                  ),
                ),
              ),
              child: const SizedBox(
                width: 300,
                height: 160,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text('BERI RATING'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('BERI RATING'));
    await tester.pumpAndSettle();

    expect(find.byType(MemberTrainerRatingPage), findsOneWidget);
    expect(find.text('Beri Rating Trainer'), findsOneWidget);
    expect(find.text('Coach Elena'), findsOneWidget);
  });
}

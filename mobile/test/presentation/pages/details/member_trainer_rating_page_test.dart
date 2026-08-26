import 'package:egg_gym/core/theme/app_theme.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:egg_gym/presentation/pages/details/member_trainer_rating_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const program = MemberProgramData(
    id: 27,
    title: 'Program Kekuatan Dasar',
    status: 'completed',
    trainerName: 'Coach Maya',
    progressPercent: 100,
    totalSessions: 6,
    completedSessions: 6,
    programCompleted: true,
    canRate: true,
    lastSessionDate: '2026-07-25',
    lastSessionDurationMinutes: 60,
  );

  Future<ValueNotifier<bool?>> pumpPage(
    WidgetTester tester, {
    required MemberRatingSubmitCallback submitRating,
  }) async {
    final result = ValueNotifier<bool?>(null);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result.value = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => MemberTrainerRatingPage(
                          program: program,
                          submitRating: submitRating,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows real program metadata and requires a star rating',
      (tester) async {
    var submitCalls = 0;
    await pumpPage(
      tester,
      submitRating: ({
        required trainingProgramId,
        required rating,
        testimonial,
      }) async {
        submitCalls++;
      },
    );

    expect(find.text('Coach Maya'), findsOneWidget);
    expect(find.text('Program Kekuatan Dasar'), findsOneWidget);
    expect(find.text('25 Juli 2026'), findsOneWidget);
    expect(find.text('60 menit'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('submit-rating-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('submit-rating-button')));
    await tester.pump();

    expect(find.text('Pilih rating bintang terlebih dahulu.'), findsOneWidget);
    expect(submitCalls, 0);
  });

  testWidgets('uses a compact in-content back button without an app bar',
      (tester) async {
    await pumpPage(
      tester,
      submitRating: ({
        required trainingProgramId,
        required rating,
        testimonial,
      }) async {},
    );

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('rating-back-button')), findsOneWidget);

    final backRect =
        tester.getRect(find.byKey(const Key('rating-back-button')));
    final titleRect = tester.getRect(find.text('Program Selesai'));
    expect(backRect.height, lessThanOrEqualTo(48));
    expect(titleRect.top - backRect.bottom, lessThanOrEqualTo(16));
  });

  testWidgets('Nanti Saja returns false without submitting', (tester) async {
    var submitCalls = 0;
    final result = await pumpPage(
      tester,
      submitRating: ({
        required trainingProgramId,
        required rating,
        testimonial,
      }) async {
        submitCalls++;
      },
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('rating-later-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('rating-later-button')));
    await tester.pumpAndSettle();

    expect(result.value, isFalse);
    expect(submitCalls, 0);
    expect(program.alreadyRated, isFalse);
    expect(program.canRate, isTrue);
  });

  testWidgets('successful submit forwards real values and returns true',
      (tester) async {
    int? submittedProgramId;
    int? submittedRating;
    String? submittedTestimonial;
    final result = await pumpPage(
      tester,
      submitRating: ({
        required trainingProgramId,
        required rating,
        testimonial,
      }) async {
        submittedProgramId = trainingProgramId;
        submittedRating = rating;
        submittedTestimonial = testimonial;
      },
    );

    await tester.tap(find.byKey(const Key('rating-star-5')));
    await tester.enterText(
      find.byKey(const Key('rating-testimonial-field')),
      'Programnya terarah dan menantang.',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('submit-rating-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('submit-rating-button')));
    await tester.pumpAndSettle();

    expect(submittedProgramId, 27);
    expect(submittedRating, 5);
    expect(submittedTestimonial, 'Programnya terarah dan menantang.');
    expect(result.value, isTrue);
  });
}

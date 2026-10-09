// Ticket 79 (testing-wave develop-2026-10), Finding 68-002: Describe text
// over 2,000 characters showed "The AI service returned an error" and sent a
// degraded `error_reported`.
//
// Now: the field refuses more than [describeMaxChars] trimmed characters with
// `meal_log.describe.too_long` ({n} = 2000) and no call; describe-meal's 400
// carries `too_long: true` (`errorResponse(..., 400, undefined, { too_long,
// max_length })`), and the real [MealAiService] maps it to
// [MealAiFailureKind.tooLong] with one `expected_failure` and no degraded.
//
// Seam: the real service over a mocktail SupabaseClient whose
// `functions.invoke('describe-meal', …)` throws the FunctionException the
// supabase client raises for the function's flagged 400 body.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/meal_review_screen.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/test_content.dart';
import '../../helpers/widget_test_harness.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockAuthUser extends Mock implements User {}

/// What `errorResponse("description is too long (max 2000 characters)", 400,
/// undefined, { too_long: true, max_length: 2000 })` sends, as the client
/// raises it (`details` undefined is dropped by JSON.stringify).
const _tooLong400 = FunctionException(
  status: 400,
  details: {
    'success': false,
    'error': 'description is too long (max 2000 characters)',
    'too_long': true,
    'max_length': 2000,
  },
  reasonPhrase: 'Bad Request',
);

/// An older deployment's `validationError(...)`: no flag.
const _plain400 = FunctionException(
  status: 400,
  details: {
    'success': false,
    'error': 'description is too long (max 2000 characters)',
  },
  reasonPhrase: 'Bad Request',
);

const _serverErrorLine = 'The AI service returned an error. Please try again.';

SupabaseClient _client(FunctionsClient functions) {
  final authUser = _MockAuthUser();
  when(() => authUser.id).thenReturn(_user);
  final goTrue = fakeGoTrueClient();
  when(() => goTrue.currentUser).thenReturn(authUser);
  final client = fakeSupabaseClient(auth: goTrue) as MockSupabaseClient;
  when(() => client.functions).thenReturn(functions);
  return client;
}

FunctionsClient _functionsThrowing(FunctionException e) {
  final functions = _MockFunctionsClient();
  when(
    () => functions.invoke('describe-meal', body: any(named: 'body')),
  ).thenThrow(e);
  return functions;
}

Future<void> _openDescribe(
  WidgetTester tester,
  FunctionsClient functions,
) async {
  await smokeScreen(
    tester,
    const LogMealScreen(logDate: '2026-10-08', source: 'test'),
    settle: false,
    overrides: [
      contentServiceProvider.overrideWith(testContentService),
      mealAiServiceProvider.overrideWithValue(
        MealAiService(supabase: _client(functions), report: const NoopReport()),
      ),
    ],
  );
  addTearDown(tester.view.reset);
  await tester.tap(find.text('Describe'));
  await tester.pump();
}

void main() {
  final content = loadDefaultContent();
  final tooLongLine = content['meal_log.describe.too_long']!.replaceAll(
    '{n}',
    '2000',
  );

  test('the content line names 2000', () {
    expect(tooLongLine, startsWith("That's more than 2000 characters."));
  });

  group('Describe screen', () {
    testWidgets('2,001 characters: the field says too long, wrapped, and '
        'describe-meal is never called', (tester) async {
      final functions = _functionsThrowing(_tooLong400);
      await _openDescribe(tester, functions);

      await tester.enterText(
        find.byType(TextFormField),
        'a' * (describeMaxChars + 1),
      );
      await tester.pump();
      await tester.tap(find.text('Analyze'));
      await tester.pump();

      expect(find.text(tooLongLine), findsOneWidget);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField),
          matching: find.byType(TextField),
        ),
      );
      expect(field.decoration!.errorMaxLines, 3);
      verifyNever(
        () => functions.invoke('describe-meal', body: any(named: 'body')),
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('2,000 characters plus spaces: the call is made; the server\'s '
        'flagged 400 shows the same line under the text, no snackbar', (
      tester,
    ) async {
      final functions = _functionsThrowing(_tooLong400);
      await _openDescribe(tester, functions);

      final text = '  ${'b' * describeMaxChars}   ';
      await tester.enterText(find.byType(TextFormField), text);
      await tester.pump();
      await tester.tap(find.text('Analyze'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The trimmed text is exactly at the limit, so it is sent.
      final sent = verify(
        () =>
            functions.invoke('describe-meal', body: captureAny(named: 'body')),
      ).captured;
      expect(sent, hasLength(1));
      expect(
        ((sent.single as Map)['description'] as String).length,
        describeMaxChars,
      );
      expect(find.byType(MealReviewScreen), findsNothing);
      expect(find.text(tooLongLine), findsOneWidget);
      expect(find.text(_serverErrorLine), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller!.text, text);

      // Editing the text clears the server's verdict.
      await tester.enterText(find.byType(TextFormField), 'eggs and toast');
      await tester.pump();
      expect(find.text(tooLongLine), findsNothing);
    });
  });

  group('MealAiService.describeMeal', () {
    late RecordingReport report;
    late RecordingAnalyticsTracker analytics;

    MealAiService service(FunctionException answer) => MealAiService(
      supabase: _client(_functionsThrowing(answer)),
      report: report,
      analytics: analytics,
    );

    setUp(() {
      report = RecordingReport();
      analytics = RecordingAnalyticsTracker();
    });

    test('flagged 400: tooLong, one expected_failure, no degraded or '
        'fault', () async {
      await expectLater(
        () => service(_tooLong400).describeMeal('c' * 2149),
        throwsA(
          isA<MealAiException>()
              .having((e) => e.kind, 'kind', MealAiFailureKind.tooLong)
              .having((e) => e.userMessage, 'userMessage', isEmpty),
        ),
      );
      expect(report.degradeds, isEmpty);
      expect(report.faults, isEmpty);
      expect(report.notes.single.area, 'meal_logging');
      expect(report.notes.single.data, {
        'expected_failure': 'description_too_long',
        'status': 400,
        'max_length': 2000,
      });
      expect(analytics.findEvents(expectedFailureEvent).single.properties, {
        'area': 'meal_logging',
        'reason': 'description_too_long',
      });
    });

    test('400 without the flag (an older deployment): serverError, one '
        'degraded, no count', () async {
      await expectLater(
        () => service(_plain400).describeMeal('c' * 2149),
        throwsA(
          isA<MealAiException>()
              .having((e) => e.kind, 'kind', MealAiFailureKind.serverError)
              .having((e) => e.userMessage, 'userMessage', _serverErrorLine),
        ),
      );
      expect(report.degradeds, hasLength(1));
      expect(analytics.findEvents(expectedFailureEvent), isEmpty);
    });

    test('isTooLongAnswer keys on status 400 and the flag', () {
      expect(MealAiService.isTooLongAnswer(_tooLong400), isTrue);
      expect(MealAiService.isTooLongAnswer(_plain400), isFalse);
      expect(
        MealAiService.isTooLongAnswer(
          const FunctionException(status: 422, details: {'too_long': true}),
        ),
        isFalse,
      );
    });
  });
}

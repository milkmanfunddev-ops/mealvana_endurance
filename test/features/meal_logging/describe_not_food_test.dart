// Ticket 45 (testing-wave develop-2026-10): what Describe says before Review.
//
// 31-003: "my bike ride" opened a loggable 0 kcal Review. describe-meal now
// answers non-food with 422 `{ not_food: true }` (free, Lee 2026-10-08), the
// real [MealAiService] maps it to [MealAiFailureKind.notFood], and the field
// says `meal_log.describe.not_food` under the kept text. No Review is pushed.
//
// 31-007: the short-input line names the minimum, from content
// (`meal_log.describe.too_short` with {n} = 5), and no call is made.
//
// Seam: the real service over a mocktail SupabaseClient whose
// `functions.invoke('describe-meal', …)` throws the FunctionException the
// supabase client raises for the function's 422 body.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/describe_analysis_controller.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/meal_review_screen.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/test_content.dart';
import '../../helpers/widget_test_harness.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockAuthUser extends Mock implements User {}

/// What `errorResponse("That doesn't describe food or drink.", 422,
/// undefined, { not_food: true })` sends, as the client raises it.
const _notFood422 = FunctionException(
  status: 422,
  details: {
    'success': false,
    'error': "That doesn't describe food or drink.",
    'not_food': true,
  },
  reasonPhrase: 'Unprocessable Entity',
);

FunctionsClient _functions() {
  final functions = _MockFunctionsClient();
  when(
    () => functions.invoke('describe-meal', body: any(named: 'body')),
  ).thenThrow(_notFood422);
  return functions;
}

Future<void> _openDescribe(
  WidgetTester tester,
  FunctionsClient functions,
) async {
  final authUser = _MockAuthUser();
  when(() => authUser.id).thenReturn(_user);
  final goTrue = fakeGoTrueClient();
  when(() => goTrue.currentUser).thenReturn(authUser);
  final client = fakeSupabaseClient(auth: goTrue) as MockSupabaseClient;
  when(() => client.functions).thenReturn(functions);

  await smokeScreen(
    tester,
    const LogMealScreen(logDate: '2026-10-08', source: 'test'),
    settle: false,
    overrides: [
      contentServiceProvider.overrideWith(testContentService),
      mealAiServiceProvider.overrideWithValue(
        MealAiService(supabase: client, report: const NoopReport()),
      ),
    ],
  );
  addTearDown(tester.view.reset);
  await tester.tap(find.text('Describe'));
  await tester.pump();
}

void main() {
  final content = loadDefaultContent();

  testWidgets('"my bike ride": no Review, the field says it is not food, the '
      'text stays', (tester) async {
    final functions = _functions();
    await _openDescribe(tester, functions);

    await tester.enterText(find.byType(TextFormField), 'my bike ride');
    await tester.pump();
    await tester.tap(find.text('Analyze'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => functions.invoke('describe-meal', body: any(named: 'body')),
    ).called(1);
    expect(find.byType(MealReviewScreen), findsNothing);
    // The failure never reaches notifier state (the Riverpod observer would
    // fault it with no area; wave 4 review): the controller holds no error.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LogMealScreen)),
    );
    final held = container.read(describeAnalysisControllerProvider);
    expect(held.hasError, isFalse);
    expect(held.value, isNull);
    final notFood = content['meal_log.describe.not_food']!;
    expect(notFood, startsWith("That doesn't sound like food or drink."));
    expect(find.text(notFood), findsOneWidget);
    // Not the photo sentence the service carries for a 422.
    expect(find.textContaining("photo doesn't appear"), findsNothing);
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text, 'my bike ride');

    // Editing the text clears the verdict.
    await tester.enterText(find.byType(TextFormField), 'my bike ride snack');
    await tester.pump();
    expect(find.text(notFood), findsNothing);
  });

  testWidgets('"Eggs" is too short: the line names 5 and nothing is sent', (
    tester,
  ) async {
    final functions = _functions();
    await _openDescribe(tester, functions);

    await tester.enterText(find.byType(TextFormField), 'Eggs');
    await tester.pump();
    await tester.tap(find.text('Analyze'));
    await tester.pump();

    expect(
      find.text(
        'Add a bit more: at least 5 characters, like what you ate and how '
        'much.',
      ),
      findsOneWidget,
    );
    verifyNever(
      () => functions.invoke('describe-meal', body: any(named: 'body')),
    );
  });

  testWidgets('empty text shows the same line', (tester) async {
    final functions = _functions();
    await _openDescribe(tester, functions);

    await tester.tap(find.text('Analyze'));
    await tester.pump();

    expect(find.textContaining('at least 5 characters'), findsOneWidget);
    verifyNever(
      () => functions.invoke('describe-meal', body: any(named: 'body')),
    );
  });
}

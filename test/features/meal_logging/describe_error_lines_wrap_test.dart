// Ticket 66 (testing-wave develop-2026-10, Finding 49-002): Describe's field
// errors wrap instead of ellipsising at one line.
//
// The Describe `TextFormField` set no `errorMaxLines`, so Flutter showed one
// line and cut the rest. On run 49's 402 pt iPhone 17 Pro the too-short line
// needs two. Now the field allows three.
//
// On the `describe_not_food_test.dart` harness: the real [LogMealScreen] →
// Describe, the real [MealAiService] over a mocktail SupabaseClient whose
// `functions.invoke('describe-meal', …)` throws the 422 not-food answer.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/test_content.dart';
import '../../helpers/widget_test_harness.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';

/// Run 49's iPhone 17 Pro, in logical pixels.
const _iphone17Pro = Size(402, 874);

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockAuthUser extends Mock implements User {}

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
    sizes: const [_iphone17Pro],
    overflowSizes: const [_iphone17Pro],
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

/// The error line is shown whole: up to three lines, none cut.
void _expectWhole(WidgetTester tester, String line) {
  final finder = find.text(line);
  expect(finder, findsOneWidget);
  final text = tester.widget<Text>(finder);
  expect(text.maxLines, 3);
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: finder, matching: find.byType(RichText)),
  );
  expect(paragraph.didExceedMaxLines, isFalse);
}

void main() {
  final content = loadDefaultContent();

  testWidgets('"egg": the too-short line shows whole on a 402 pt phone', (
    tester,
  ) async {
    final functions = _functions();
    await _openDescribe(tester, functions);
    expect(tester.view.physicalSize, _iphone17Pro);

    await tester.enterText(find.byType(TextFormField), 'egg');
    await tester.pump();
    await tester.tap(find.text('Analyze'));
    await tester.pump();

    final line = content['meal_log.describe.too_short']!.replaceAll('{n}', '5');
    expect(line, contains('at least 5 characters'));
    _expectWhole(tester, line);
    verifyNever(
      () => functions.invoke('describe-meal', body: any(named: 'body')),
    );
  });

  testWidgets('the not-food line shows whole on a 402 pt phone', (
    tester,
  ) async {
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
    _expectWhole(tester, content['meal_log.describe.not_food']!);
  });
}

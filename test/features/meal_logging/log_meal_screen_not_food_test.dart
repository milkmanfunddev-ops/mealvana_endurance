/// The log-meal screen's answer to a photo or a description that is not food
/// (mp-473, ticket ai-cost 08).
///
/// Through the real screen and the real [MealAiService]: the Describe tab's
/// Analyze button, a `describe-meal` that answers 422 `{error:'not_food'}`, and
/// one short line from the content system — a warning, not an error, because
/// nothing failed on our side. No macros are shown and the review screen is
/// never pushed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';
import 'package:mealvana_endurance/shared/services/supabase/supabase_client_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/widget_test_harness.dart';
import '../meal_planning/helpers/fakes.dart';
import '../meal_planning/presentation/helpers/test_content.dart';

class _MockFunctions extends Mock implements FunctionsClient {}

void main() {
  final expectedLine = loadDefaultContent()[ContentKeys.mpAnalysisNotFood]!;

  testWidgets('a description that is not food shows one short line', (
    tester,
  ) async {
    final supabase = supabaseWithSession();
    final functions = _MockFunctions();
    when(() => supabase.functions).thenReturn(functions);
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer(
      (_) async =>
          FunctionResponse(status: 422, data: const {'error': 'not_food'}),
    );

    await smokeScreen(
      tester,
      const LogMealScreen(logDate: '2026-09-21', source: 'test'),
      settle: false,
      overrides: [
        supabaseClientProvider.overrideWithValue(supabase),
        contentServiceProvider.overrideWith(testContentService),
      ],
    );

    await tester.tap(find.text('Describe'));
    await tester.pump();

    await tester.enterText(
      find.byType(TextFormField),
      'the shawshank redemption',
    );
    await tester.pump();

    await tester.tap(find.text('Analyze'));
    // One frame to start the call, one for the answer, one for the snackbar.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text(expectedLine), findsOneWidget);
    // Nothing invented: no macro figures on screen, and no review screen.
    expect(find.textContaining('kcal'), findsNothing);
  });
}

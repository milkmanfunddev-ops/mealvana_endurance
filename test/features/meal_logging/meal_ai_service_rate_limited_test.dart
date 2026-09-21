/// Meal logging when the shared server-side limiter turns a call away
/// (mp-469, ticket ai-cost 04): `describe-meal` and `analyze-meal-photo` now
/// reserve their place in `_shared/vana/rate-limit.ts` before the model runs
/// and answer 429 `{error:'rate_limited', retry_after_seconds}`.
///
/// The server sends a code and a number, never prose. The line the athlete
/// reads comes from the content system, with the wait the server named — and
/// it is never an [InsufficientCreditsException]: nothing was spent, so the
/// top-up sheet would be a lie.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/insufficient_credits_exception.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../meal_planning/helpers/fakes.dart';
import '../meal_planning/presentation/helpers/test_content.dart';

class _MockFunctions extends Mock implements FunctionsClient {}

void main() {
  final content = loadDefaultContent();

  MealAiService serviceThrowing(FunctionException e) {
    final supabase = supabaseWithSession();
    final functions = _MockFunctions();
    when(() => supabase.functions).thenReturn(functions);
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenThrow(e);
    final container = ProviderContainer(
      overrides: [contentServiceProvider.overrideWith(testContentService)],
    );
    addTearDown(container.dispose);
    return MealAiService(
      supabase: supabase,
      content: container.read(contentServiceProvider),
    );
  }

  test('429 rate_limited → the content system\'s line, with the wait', () async {
    final service = serviceThrowing(
      FunctionException(
        status: 429,
        details: const {'error': 'rate_limited', 'retry_after_seconds': 60},
      ),
    );
    final expected = ContentKeys.format(
      content[ContentKeys.mpAnalysisRateLimited]!,
      {'n': 60},
    );
    expect(expected.contains('60'), isTrue);
    await expectLater(
      service.describeMeal('two eggs on toast'),
      throwsA(
        isA<MealAiException>()
            .having((e) => e.kind, 'kind', MealAiFailureKind.serverError)
            .having((e) => e.userMessage, 'userMessage', expected),
      ),
    );
  });

  test('a rate limit is never the top-up sheet', () {
    final service = serviceThrowing(
      FunctionException(
        status: 429,
        details: const {'error': 'rate_limited', 'retry_after_seconds': 10},
      ),
    );
    expect(
      service.describeMeal('two eggs on toast'),
      throwsA(isNot(isA<InsufficientCreditsException>())),
    );
  });
}

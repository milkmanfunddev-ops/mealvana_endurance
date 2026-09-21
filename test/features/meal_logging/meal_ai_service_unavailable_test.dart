/// Meal logging when the AI Gateway refuses OUR key (mp-437, ticket ai-cost
/// 02): describe-meal and analyze-meal-photo answer 503
/// `{success:false, error:'ai_unavailable'}` (`_shared/ai/gateway_error.ts`).
/// The service reports "Vana is unavailable right now" from the content
/// system and never an [InsufficientCreditsException] (the top-up sheet).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/insufficient_credits_exception.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
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

  for (final status in [503, 402]) {
    test(
      '$status ai_unavailable → "Vana is unavailable right now", never the top-up',
      () async {
        final service = serviceThrowing(
          FunctionException(
            status: status,
            details: const {'success': false, 'error': 'ai_unavailable'},
          ),
        );
        await expectLater(
          service.describeMeal('two eggs on toast'),
          throwsA(
            isA<MealAiException>()
                .having((e) => e.kind, 'kind', MealAiFailureKind.serverError)
                .having(
                  (e) => e.userMessage,
                  'userMessage',
                  content['meal_planning.ai_unavailable'],
                ),
          ),
        );
      },
    );
  }

  test('the athlete\'s own 402 still raises InsufficientCreditsException', () {
    final service = serviceThrowing(
      FunctionException(
        status: 402,
        details: const {
          'error': 'insufficient_credits',
          'balance': 0,
          'cost': 1,
        },
      ),
    );
    expect(
      service.describeMeal('two eggs on toast'),
      throwsA(isA<InsufficientCreditsException>()),
    );
  });
}

/// The Review sheet counts in the singular for one (testing-wave 16-004,
/// ticket 48): a Draft with one meal at one serving reads "1 meal ·
/// 1 serving", never "1 meals · 1 servings".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/review_sheet.dart';

import '../../domain/fixture_helpers.dart';
import '../helpers/test_content.dart';

void main() {
  /// The producer-shaped `batch` fixture, cut to its first [meals] meals,
  /// each at [servings].
  MealPlan planOf({required int meals, required int servings}) {
    final fixture = VanaActionResult.fromJson(loadFixture('batch')).plan!;
    return fixture.copyWith(
      meals: [
        for (final m in fixture.meals.take(meals))
          m.copyWith(servings: servings, servingsLeft: servings),
      ],
    );
  }

  Future<void> openReview(WidgetTester tester, MealPlan plan) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showReviewSheet(
                  context: context,
                  ref: ref,
                  plan: plan,
                  onTapMeal: (_) {},
                  onServings: (_, __) {},
                  onRemove: (_) {},
                  onConfirm: () async => true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder summary() =>
      find.byKey(const ValueKey('meal_planning.review_sheet.summary'));

  String text(WidgetTester tester) => tester.widget<Text>(summary()).data!;

  testWidgets('one meal at one serving reads in the singular', (tester) async {
    await openReview(tester, planOf(meals: 1, servings: 1));
    expect(text(tester), '1 meal · 1 serving');
  });

  testWidgets('one meal at four servings: meal singular, servings plural', (
    tester,
  ) async {
    await openReview(tester, planOf(meals: 1, servings: 4));
    expect(text(tester), '1 meal · 4 servings');
  });

  testWidgets('two meals at one serving each read in the plural', (
    tester,
  ) async {
    await openReview(tester, planOf(meals: 2, servings: 1));
    expect(text(tester), '2 meals · 2 servings');
  });
}

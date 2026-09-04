import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_badge.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_rail_card.dart';

import '../helpers/test_content.dart';

/// The rail card's badge strip: which badges a meal earns, what tapping one
/// explains, and that the old meta line ("no recipe · 20 min · 560 kcal")
/// and icon row are gone.
void main() {
  Future<void> pumpCard(WidgetTester tester, MealRef meal) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: MealRailCard(meal: meal, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder badge(MealBadgeKind kind) =>
      find.byKey(ValueKey('meal_planning.meal_badge_${kind.name}'));

  testWidgets('a fast, low-cal, no-recipe vegan meal earns all four badges', (
    tester,
  ) async {
    await pumpCard(
      tester,
      MealRef(
        source: MealSource.library,
        id: 'D-1',
        name: 'Green smoothie with berries',
        mealType: MealType.breakfast,
        prepMinutes: 5,
        kcal: 280,
        dietsOk: const ['vegan'],
        kind: MealKind.assembly,
      ),
    );

    expect(badge(MealBadgeKind.plantBased), findsOneWidget);
    expect(badge(MealBadgeKind.fast), findsOneWidget);
    expect(badge(MealBadgeKind.lowCal), findsOneWidget);
    expect(badge(MealBadgeKind.noRecipe), findsOneWidget);
  });

  testWidgets('a slow, high-kcal omnivore recipe earns none', (tester) async {
    await pumpCard(
      tester,
      MealRef(
        source: MealSource.library,
        id: 'D-2',
        name: 'Salmon, quinoa, asparagus & spinach salad',
        mealType: MealType.dinner,
        prepMinutes: 20,
        kcal: 560,
        dietsOk: const ['omnivore', 'pescatarian'],
        kind: MealKind.recipe,
      ),
    );

    expect(badge(MealBadgeKind.plantBased), findsNothing);
    expect(badge(MealBadgeKind.fast), findsNothing);
    expect(badge(MealBadgeKind.lowCal), findsNothing);
    expect(badge(MealBadgeKind.noRecipe), findsNothing);
    // Title still renders; the meta line is gone.
    expect(
      find.text('Salmon, quinoa, asparagus & spinach salad'),
      findsOneWidget,
    );
    expect(find.textContaining('560 kcal'), findsNothing);
    expect(find.textContaining('20 min'), findsNothing);
  });

  testWidgets('tapping a badge opens its explanation sheet', (tester) async {
    await pumpCard(
      tester,
      MealRef(
        source: MealSource.library,
        id: 'D-3',
        name: 'Bagel with jam',
        mealType: MealType.breakfast,
        prepMinutes: 5,
        kcal: 300,
        kind: MealKind.assembly,
      ),
    );

    await tester.tap(badge(MealBadgeKind.noRecipe));
    await tester.pumpAndSettle();

    expect(find.text('No recipe'), findsWidgets);
    expect(find.textContaining('pieces together'), findsOneWidget);
  });
}

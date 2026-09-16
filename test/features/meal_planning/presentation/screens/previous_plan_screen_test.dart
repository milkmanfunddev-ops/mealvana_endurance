import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/providers/daily_macros_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/plan_meal_photos.dart';
import 'package:mealvana_endurance/features/meal_planning/application/previous_plans.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_settings_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/previous_plan_screen.dart';

import '../../domain/fixture_helpers.dart';
import '../helpers/test_content.dart';

/// The read-only view of an earlier plan: the plan's rows without any of
/// the Plan tab's actions, and a note when the plan is gone.
void main() {
  final plan = MealPlan.fromJson(
    (loadFixture('confirm_plan')['parts'] as List).firstWhere(
          (p) => (p as Map)['kind'] == 'batch',
        )['plan']
        as Map<String, dynamic>,
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Map<String, MealPlan> plans,
    required String id,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          planByIdProvider.overrideWith((ref, id) async => plans[id]),
          planMealPhotosProvider.overrideWith((ref, key) async => const {}),
          vanaSettingsControllerProvider.overrideWith(
            _FakeSettingsController.new,
          ),
          dailyMacrosControllerProvider.overrideWith(_NoMacrosController.new),
        ],
        child: MaterialApp(home: PreviousPlanScreen(planId: id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('draws the plan as rows with no swipes, menus or Confirm', (
    tester,
  ) async {
    await pumpScreen(tester, plans: {plan.id: plan}, id: plan.id);

    for (final meal in plan.meals) {
      expect(
        find.byKey(ValueKey('meal_planning.previous_plan_tile_${meal.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('meal_planning.tile_overflow_${meal.id}')),
        findsNothing,
      );
    }
    expect(find.byType(Dismissible), findsNothing);
    expect(
      find.byKey(const ValueKey('meal_planning.btn_confirm')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.plan_overflow')),
      findsNothing,
    );
    // The header is the plan's own summary line, and the way back is there.
    expect(
      find.byKey(const ValueKey('meal_planning.plan_summary.coverage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.previous_plan_back')),
      findsOneWidget,
    );
    final content = loadDefaultContent();
    expect(
      find.text(content['meal_planning.previous_plan_read_only']!),
      findsOneWidget,
    );
  });

  testWidgets('a plan the server no longer has says so', (tester) async {
    await pumpScreen(tester, plans: const {}, id: 'gone');

    expect(
      find.byKey(const ValueKey('meal_planning.previous_plan_missing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.previous_plan_rows')),
      findsNothing,
    );
  });
}

class _FakeSettingsController extends VanaSettingsController {
  @override
  Future<VanaSettingsState> build() async => const VanaSettingsState();
}

class _NoMacrosController extends DailyMacrosController {
  @override
  Future<DailyMacrosState> build() async =>
      throw StateError('no macros in this test');
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/providers/daily_macros_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/plan_meal_photos.dart';
import 'package:mealvana_endurance/features/meal_planning/application/previous_plans.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_settings_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan_status.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/previous_plan_screen.dart';

import '../../domain/fixture_helpers.dart';
import '../helpers/test_content.dart';

/// An earlier plan's view (ticket 73, mp-675): its rows with a servings
/// stepper and a Remove, and a ⋮ that renames the plan, uses it again or
/// deletes it; a draft has a Confirm. The notifier is a recording stand-in —
/// its own seam tests are in `earlier_plan_controller_test.dart`.
void main() {
  final fixture = MealPlan.fromJson(
    (loadFixture('confirm_plan')['parts'] as List).firstWhere(
          (p) => (p as Map)['kind'] == 'batch',
        )['plan']
        as Map<String, dynamic>,
  );
  final earlier = fixture.copyWith(
    id: 'plan-sep14',
    status: MealPlanStatus.archived,
    name: 'Race block',
  );
  final draft = fixture.copyWith(id: 'plan-copy', status: MealPlanStatus.draft);

  late _Log recorder;

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Map<String, MealPlan> plans,
    required String id,
  }) async {
    recorder = _Log();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('plan tab')),
        ),
        GoRoute(
          path: '/food/plans/:id',
          builder: (_, state) =>
              PreviousPlanScreen(planId: state.pathParameters['id']!),
        ),
        // Where a confirm lands the athlete: Food > Shopping (mp-235).
        GoRoute(
          path: '/main',
          builder: (_, state) =>
              Scaffold(body: Text('main ${state.uri.query}')),
        ),
        GoRoute(
          path: '/food/meals/:id',
          builder: (_, state) =>
              Scaffold(body: Text('detail ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          earlierPlanProvider.overrideWith(
            () => _RecordingEarlierPlan(plans, recorder),
          ),
          planMealPhotosProvider.overrideWith((ref, key) async => const {}),
          vanaSettingsControllerProvider.overrideWith(
            _FakeSettingsController.new,
          ),
          dailyMacrosControllerProvider.overrideWith(_NoMacrosController.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/food/plans/$id');
    await tester.pumpAndSettle();
  }

  Future<void> openMenuItem(WidgetTester tester, String key) async {
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.previous_plan_more')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('draws the plan\'s name, its rows with servings and Remove, and '
      'no Confirm for a plan that was confirmed', (tester) async {
    await pumpScreen(tester, plans: {earlier.id: earlier}, id: earlier.id);

    expect(find.text('Race block'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meal_planning.plan_summary.coverage')),
      findsOneWidget,
    );
    for (final meal in earlier.meals) {
      expect(
        find.byKey(ValueKey('meal_planning.previous_plan_tile_${meal.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('meal_planning.tile_overflow_${meal.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('meal_planning.previous_plan_servings_${meal.id}')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey('meal_planning.btn_confirm')),
      findsNothing,
    );
  });

  /// Ticket 132: the Plan tab's row opens the meal sheet with Ate it; an
  /// earlier plan's row is not a plan being eaten from, so it keeps its own
  /// rule and opens the meal's detail page, with no sheet.
  testWidgets('a row opens the meal detail, not the Ate it sheet', (
    tester,
  ) async {
    await pumpScreen(tester, plans: {earlier.id: earlier}, id: earlier.id);
    final meal = earlier.meals.last;

    await tester.tap(find.text(meal.name));
    await tester.pumpAndSettle();

    expect(find.text('detail ${meal.libraryMealId}'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meal_planning.meal_sheet.ate_it')),
      findsNothing,
    );
  });

  testWidgets('a servings step goes to the notifier for that row', (
    tester,
  ) async {
    await pumpScreen(tester, plans: {earlier.id: earlier}, id: earlier.id);
    final meal = earlier.meals.first;

    await tester.tap(
      // The stepper's "+", the last button in the row.
      find
          .descendant(
            of: find.byKey(
              ValueKey('meal_planning.previous_plan_servings_${meal.id}'),
            ),
            matching: find.byType(IconButton),
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(recorder.servings, [(meal.id, meal.servings + 1)]);
  });

  testWidgets('Rename sends what was typed', (tester) async {
    await pumpScreen(tester, plans: {earlier.id: earlier}, id: earlier.id);

    await openMenuItem(tester, 'meal_planning.previous_plan_rename');
    await tester.enterText(
      find.byKey(const ValueKey('meal_planning.previous_plan_rename_field')),
      'Taper week',
    );
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.previous_plan_rename_save')),
    );
    await tester.pumpAndSettle();

    expect(recorder.renamed, ['Taper week']);
  });

  testWidgets('Delete asks first, then deletes and goes back', (tester) async {
    await pumpScreen(tester, plans: {earlier.id: earlier}, id: earlier.id);

    await openMenuItem(tester, 'meal_planning.previous_plan_delete');
    expect(
      find.byKey(const ValueKey('meal_planning.previous_plan_delete_confirm')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.previous_plan_delete_go')),
    );
    await tester.pumpAndSettle();

    expect(recorder.deleted, 1);
    expect(find.byType(PreviousPlanScreen), findsNothing);
    expect(find.text('plan tab'), findsOneWidget);
  });

  testWidgets('Use this plan again opens the new draft, which has a Confirm', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      plans: {earlier.id: earlier, draft.id: draft},
      id: earlier.id,
    );

    await openMenuItem(tester, 'meal_planning.previous_plan_use_again');

    expect(recorder.usedAgain, 1);
    // The earlier plan's view was replaced by the draft's.
    expect(
      tester.widget<PreviousPlanScreen>(find.byType(PreviousPlanScreen)).planId,
      draft.id,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.btn_confirm')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('meal_planning.btn_confirm')));
    await tester.pumpAndSettle();
    expect(recorder.confirmed, 1);
    expect(find.byType(PreviousPlanScreen), findsNothing);
    // mp-235 (ticket 131): the confirm lands on Food > Shopping.
    expect(find.text('main tab=food&food=shopping'), findsOneWidget);
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
    expect(
      find.byKey(const ValueKey('meal_planning.previous_plan_more')),
      findsNothing,
    );
  });
}

/// Every write the screen asked for, across the plans it opened.
class _Log {
  final List<(String, int)> servings = [];
  final List<String> renamed = [];
  int deleted = 0;
  int usedAgain = 0;
  int confirmed = 0;
}

/// Answers from [plans] and records every write in [log]; Use again answers
/// the plan stored under `plan-copy`.
class _RecordingEarlierPlan extends EarlierPlan {
  _RecordingEarlierPlan(this.plans, this.log);

  final Map<String, MealPlan> plans;
  final _Log log;

  @override
  Future<MealPlan?> build(String id) async => plans[id];

  @override
  Future<void> setServings(String planMealId, int servings) async =>
      log.servings.add((planMealId, servings));

  @override
  Future<void> rename(String name) async => log.renamed.add(name);

  @override
  Future<void> delete() async => log.deleted++;

  @override
  Future<MealPlan?> useAgain() async {
    log.usedAgain++;
    return plans['plan-copy'];
  }

  @override
  Future<void> confirm() async => log.confirmed++;
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

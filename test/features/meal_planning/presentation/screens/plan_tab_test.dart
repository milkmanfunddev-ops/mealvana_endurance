import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/providers/daily_macros_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/home_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/previous_plans.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_settings_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/home_payload.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan_summary.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/week_start.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/plan_tab.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/buttons/primary_button.dart';

import '../../domain/fixture_helpers.dart';
import '../helpers/test_content.dart';

/// The Plan tab through fake notifiers: the three plan states render.
/// (The tile sheet and its "Ate it" wiring were removed 2026-09-03 — taps
/// now route to the meal detail page; the `logFromPlan` remote-ack path
/// stays covered by `application/meal_plan_controller_test.dart`.)
/// Bounded settle — the Plan tab's day-note avatar pulses forever while the
/// home payload loads (and these tests mostly leave it loading), so
/// `pumpAndSettle` can never return. A few fixed frames cover route/sheet/
/// snackbar animations without waiting out an infinite one.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  final confirmedPlan = MealPlan.fromJson(
    (loadFixture('confirm_plan')['parts'] as List).firstWhere(
          (p) => (p as Map)['kind'] == 'batch',
        )['plan']
        as Map<String, dynamic>,
  );
  final draftPlan = MealPlan.fromJson({
    ...confirmedPlan.toJson(),
    'status': 'draft',
  });

  Future<void> pumpTab(
    WidgetTester tester, {
    required MealPlanController plan,
    HomePayload? home,
    List<MealPlanSummary> previous = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          mealPlanControllerProvider.overrideWith(() => plan),
          previousPlansProvider.overrideWith((ref) async => previous),
          planPeriodProvider.overrideWith(
            (ref) => Stream.value(const PlanPeriod()),
          ),
          homeControllerProvider.overrideWith(() => _FakeHomeController(home)),
          vanaSettingsControllerProvider.overrideWith(
            _FakeSettingsController.new,
          ),
          dailyMacrosControllerProvider.overrideWith(_NoMacrosController.new),
        ],
        child: const MaterialApp(home: Scaffold(body: PlanTab())),
      ),
    );
    await settle(tester);
  }

  Finder planTiles() => find.byWidgetPredicate((w) {
    final key = w.key;
    return key is ValueKey<String> &&
        key.value.startsWith('meal_planning.plan_tile_');
  });

  /// Ticket 46 (testing-wave 19-004): the first read was answered from an
  /// empty local table while the sync was still on the wire, so the tab
  /// said "No plan yet" for ~6 s over a confirmed plan. While the read is
  /// in flight the dashed slot holds a spinner and New meal plan waits.
  testWidgets('a plan still loading shows a loading card, not No plan yet, '
      'and New meal plan waits', (tester) async {
    await pumpTab(tester, plan: _LoadingPlanController());

    expect(
      find.byKey(const ValueKey('meal_planning.plan_loading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.empty_plan_title')),
      findsNothing,
    );
    final newPlan = tester.widget<KylePrimaryButton>(
      find.byKey(const ValueKey('meal_planning.btn_new_plan')),
    );
    expect(newPlan.onPressed, isNull);
  });

  testWidgets('empty plan shows the dashed card with both ways in', (
    tester,
  ) async {
    await pumpTab(tester, plan: _FakePlanController(null));

    expect(
      find.byKey(const ValueKey('meal_planning.empty_plan_title')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.btn_new_plan')),
      findsOneWidget,
    );
    expect(planTiles(), findsNothing);
    expect(
      find.byKey(const ValueKey('meal_planning.btn_confirm')),
      findsNothing,
    );
  });

  testWidgets('draft plan lists its meals and offers Confirm', (tester) async {
    await pumpTab(tester, plan: _FakePlanController(draftPlan));

    expect(planTiles(), findsNWidgets(draftPlan.meals.length));
    expect(
      find.byKey(const ValueKey('meal_planning.btn_confirm')),
      findsOneWidget,
    );
  });

  testWidgets('confirmed plan lists its meals with no Confirm button', (
    tester,
  ) async {
    await pumpTab(tester, plan: _FakePlanController(confirmedPlan));

    expect(planTiles(), findsNWidgets(confirmedPlan.meals.length));
    expect(
      find.byKey(const ValueKey('meal_planning.btn_confirm')),
      findsNothing,
    );
  });

  /// Lee's 09-16 demo: there was no way to delete a plan by hand. The menu
  /// belongs to the plan, so it only exists when there is one.
  testWidgets('no plan means no plan menu', (tester) async {
    await pumpTab(tester, plan: _FakePlanController(null));
    expect(
      find.byKey(const ValueKey('meal_planning.plan_overflow')),
      findsNothing,
    );
  });

  testWidgets('a plan with meals carries the ⋮ with all three plan actions', (
    tester,
  ) async {
    await pumpTab(tester, plan: _FakePlanController(confirmedPlan));
    final menu = find.byKey(const ValueKey('meal_planning.plan_overflow'));
    expect(menu, findsOneWidget);

    await tester.tap(menu);
    await settle(tester);
    expect(
      find.byKey(const ValueKey('meal_planning.plan_new')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.plan_previous')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.plan_delete')),
      findsOneWidget,
    );
  });

  /// 2026-09-16: the "THIS WEEK'S PLAN" overline is gone; the summary row
  /// is the header, with the ⋮ on its right.
  testWidgets('the summary row is the header, with no overline above it', (
    tester,
  ) async {
    await pumpTab(tester, plan: _FakePlanController(confirmedPlan));

    expect(
      find.byKey(const ValueKey('meal_planning.plan_summary.coverage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.plan_section')),
      findsNothing,
    );
  });

  testWidgets('Previous plans opens the sheet with the earlier plans', (
    tester,
  ) async {
    final earlier = MealPlanSummary.fromJson({
      'id': 'plan-prev',
      'weekStart': '2026-08-23',
      'status': 'archived',
      'batchCooking': true,
      'mealCount': 3,
    });
    await pumpTab(
      tester,
      plan: _FakePlanController(confirmedPlan),
      previous: [earlier],
    );

    await tester.tap(find.byKey(const ValueKey('meal_planning.plan_overflow')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('meal_planning.plan_previous')));
    await settle(tester);

    expect(
      find.byKey(const ValueKey('meal_planning.previous_plans_sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.previous_plan_plan-prev')),
      findsOneWidget,
    );
    expect(find.text('Aug 23 – Aug 29'), findsOneWidget);
    expect(find.text('3 meals'), findsOneWidget);
  });

  testWidgets('Delete plan asks first, then deletes and offers Undo', (
    tester,
  ) async {
    final controller = _FakePlanController(confirmedPlan);
    await pumpTab(tester, plan: controller);

    await tester.tap(find.byKey(const ValueKey('meal_planning.plan_overflow')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('meal_planning.plan_delete')));
    await settle(tester);

    // Nothing is sent until the question is answered.
    expect(
      find.byKey(const ValueKey('meal_planning.plan_delete_confirm')),
      findsOneWidget,
    );
    expect(controller.deleted, 0);

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.plan_delete_go')),
    );
    await settle(tester);

    expect(controller.deleted, 1);
    final content = loadDefaultContent();
    expect(find.text(content['meal_planning.plan_deleted']!), findsOneWidget);
    expect(find.text(content['meal_planning.undo']!), findsOneWidget);

    // Undo sends the receipt the server answered with, untouched.
    await tester.tap(find.text(content['meal_planning.undo']!));
    await settle(tester);
    expect(controller.undone, hasLength(1));
    expect(controller.undone.single.action, VanaReceiptAction.deletePlan);
  });

  testWidgets('Keep it sends nothing', (tester) async {
    final controller = _FakePlanController(confirmedPlan);
    await pumpTab(tester, plan: controller);

    await tester.tap(find.byKey(const ValueKey('meal_planning.plan_overflow')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('meal_planning.plan_delete')));
    await settle(tester);
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.plan_delete_cancel')),
    );
    await settle(tester);

    expect(controller.deleted, 0);
  });

  testWidgets('the day note renders when the home payload carries one', (
    tester,
  ) async {
    // The real wire payload from the frozen `home` fixture, note included.
    final home = HomePayload.fromJson(
      loadFixture('home')['home'] as Map<String, dynamic>,
    );
    await pumpTab(tester, plan: _FakePlanController(confirmedPlan), home: home);
    expect(
      find.byKey(const ValueKey('meal_planning.day_note')),
      findsOneWidget,
    );
    expect(find.text(home.vana.text!), findsOneWidget);
  });
}

/// Serves a fixed plan.
/// A first read that never answers.
class _LoadingPlanController extends MealPlanController {
  @override
  Future<MealPlan?> build() => Completer<MealPlan?>().future;
}

class _FakePlanController extends MealPlanController {
  _FakePlanController(this.plan);

  final MealPlan? plan;

  @override
  Future<MealPlan?> build() async => plan;

  @override
  Future<void> setServings(String planMealId, int servings) async {}

  @override
  Future<void> removeMeal(String planMealId) async {}

  int deleted = 0;
  final List<VanaReceiptPart> undone = [];

  /// The producer's receipt for a hand delete, verbatim from the fixture the
  /// contract test reads.
  static final receipt =
      VanaPart.fromJson(loadFixture('receipt_delete_plan'))! as VanaReceiptPart;

  @override
  Future<VanaReceiptPart?> deletePlan({String? id}) async {
    deleted++;
    return receipt;
  }

  @override
  Future<void> undoDeletePlan(VanaReceiptPart receipt) async {
    undone.add(receipt);
  }
}

class _FakeHomeController extends HomeController {
  _FakeHomeController(this.home);

  final HomePayload? home;

  @override
  Future<HomePayload?> build([String? date]) async => home;
}

class _FakeSettingsController extends VanaSettingsController {
  @override
  Future<VanaSettingsState> build() async => const VanaSettingsState();
}

/// No macro targets — the "today target" line hides, which is its offline
/// contract.
class _NoMacrosController extends DailyMacrosController {
  @override
  Future<DailyMacrosState> build() async =>
      throw StateError('no macros in this test');
}

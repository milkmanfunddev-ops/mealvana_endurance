// Seeded CONTENT tests for nutrition-plan + carb-loading screens.
//
// Template: test/seeded_tests/daily_macros_content_test.dart
// Harness:  test/helpers/widget_test_harness.dart → pumpSeeded()
//
// Each test drives a screen with fake seeded state and asserts that the
// rendered VALUES are correct — not just "does it render without crashing".
//
// Bug #4 fixed: macroTargetsControllerProvider use-after-dispose (2026-06-25).
// _scheduleCleanupIfNeeded now captures DraftActivityCleanupService before
// disposal and passes it directly to scheduleCleanup(); no ref access in the
// delayed closure. AdjustMacrosScreen canary test now runs without skip.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/activity_detail_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/new_activity_screen.dart';

import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';

import '../helpers/widget_test_harness.dart';

// ---------------------------------------------------------------------------
// Helpers shared across tests
// ---------------------------------------------------------------------------

Activity _makeRunActivity({String id = 'act-1'}) {
  final now = DateTime.now();
  return Activity(
    id: id,
    userId: 'u1',
    activityType: ActivityType.running,
    title: 'Long Run',
    scheduledDateTime: now.add(const Duration(hours: 2)),
    status: ActivityStatus.planned,
    distanceMiles: 13.1,
    paceTargetMinutesPerMile: 9.0,
    durationMinutes: 118,
    timeBeforeMinutes: 60,
    createdAt: now,
    updatedAt: now,
  );
}

/// Build a minimal NutritionPlan with known food values so we can assert them.
NutritionPlan _makeNutritionPlan({String activityId = 'act-1'}) {
  final now = DateTime.now();

  // Before section: 1 banana (25g carbs, 105 cal)
  final bananaFood = FoodItemData(
    id: 'food-banana',
    name: 'Banana',
    quantity: '1 medium Banana',
    nutritionalInfo: const NutritionalInfo(
      calories: 105,
      carbs: 25,
      protein: 1,
      fat: 0,
      sodium: 1,
    ),
  );

  // During section: 2 energy gels (2 × 22g carbs = 44g carbs, 2 × 100 cal)
  final gelFood = FoodItemData(
    id: 'food-gel',
    name: 'Energy Gel',
    quantity: '2 packets Energy Gel',
    nutritionalInfo: const NutritionalInfo(
      calories: 200,
      carbs: 44,
      protein: 0,
      fat: 0,
      sodium: 100,
      fluids: 0,
    ),
  );

  // After section: 1 chocolate milk (30g carbs, 20g protein, 150 cal)
  final milkFood = FoodItemData(
    id: 'food-milk',
    name: 'Chocolate Milk',
    quantity: '1 cup Chocolate Milk',
    nutritionalInfo: const NutritionalInfo(
      calories: 150,
      carbs: 30,
      protein: 20,
      fat: 5,
      sodium: 200,
    ),
  );

  return NutritionPlan(
    id: 'plan-1',
    name: 'Long Run Plan',
    activityId: activityId,
    createdAt: now,
    updatedAt: now,
    sections: [
      PlanSection(
        id: 'before_run',
        title: 'Before Run',
        foodItems: [bananaFood],
        carbsTarget: 25,
        proteinTarget: 1,
      ),
      PlanSection(
        id: 'during_run',
        title: 'During Run',
        foodItems: [gelFood],
        carbsTarget: 44,
        sodiumTarget: 100,
      ),
      PlanSection(
        id: 'after_run',
        title: 'After Run',
        foodItems: [milkFood],
        carbsTarget: 30,
        proteinTarget: 20,
      ),
    ],
  );
}

/// Build a minimal ActivityDetailState with an activity and nutrition plan.
ActivityDetailState _makeDetailState({
  Activity? activity,
  NutritionPlan? plan,
}) {
  final act = activity ?? _makeRunActivity();
  return ActivityDetailState(
    activity: act,
    nutritionPlan: plan ?? _makeNutritionPlan(activityId: act.id),
    scheduledDateTime: act.scheduledDateTime,
  );
}

// ---------------------------------------------------------------------------
// Fake controllers (local to this file — never modify the harness)
// ---------------------------------------------------------------------------

class _FakeActivityDetailController extends ActivityDetailController {
  _FakeActivityDetailController(this._state);
  final ActivityDetailState _state;

  @override
  FutureOr<ActivityDetailState> build({
    required String activityId,
    bool isNewActivity = false,
  }) async => _state;
}

// ---------------------------------------------------------------------------
// ActivityDetailScreen — SEEDED content tests
// ---------------------------------------------------------------------------

void main() {
  group('ActivityDetailScreen — seeded content', () {
    // ActivityDetailScreen uses AsyncNotifier (async build). We must settle so
    // the Future completes and the 'data' branch of .when() renders.
    //
    // Bug #6(b) fixed: ActivityDetailAppBar now shows the activity's own title
    // (eventName ?? activity.title ?? fallback). For a non-event activity with
    // title "Long Run" and no eventName, the app bar renders "Long Run".
    testWidgets(
      'renders the activity title "Long Run" in the app bar for a non-event activity',
      (tester) async {
        final state = _makeDetailState();

        await pumpSeeded(
          tester,
          const ActivityDetailScreen(activityId: 'act-1'),
          overrides: [
            activityDetailControllerProvider(activityId: 'act-1')
                .overrideWith(() => _FakeActivityDetailController(state)),
          ],
          settle: true,
        );

        // The app bar shows eventName ?? activity.title ?? 'Activity Details'.
        // _makeRunActivity() sets title: 'Long Run', so the app bar renders that.
        expect(find.text('Long Run'), findsWidgets);
      },
    );

    testWidgets(
      'shows "BEFORE RUN" section heading (uppercased) for the before section',
      (tester) async {
        final state = _makeDetailState();

        await pumpSeeded(
          tester,
          const ActivityDetailScreen(activityId: 'act-1'),
          overrides: [
            activityDetailControllerProvider(activityId: 'act-1')
                .overrideWith(() => _FakeActivityDetailController(state)),
          ],
          settle: true,
        );

        // NutritionSectionsBuilder renders sectionTitle.toUpperCase().
        // For ActivityType.running + 'before_run' category → 'Before Run'.toUpperCase() = 'BEFORE RUN'.
        expect(find.textContaining('BEFORE RUN'), findsWidgets);
      },
    );

    testWidgets(
      'renders the banana food name from the before-run section',
      (tester) async {
        final state = _makeDetailState();

        await pumpSeeded(
          tester,
          const ActivityDetailScreen(activityId: 'act-1'),
          overrides: [
            activityDetailControllerProvider(activityId: 'act-1')
                .overrideWith(() => _FakeActivityDetailController(state)),
          ],
          settle: true,
        );

        // At least one widget should show "Banana".
        expect(find.textContaining('Banana'), findsWidgets);
      },
    );

    testWidgets(
      'renders the energy gel food name from the during-run section',
      (tester) async {
        final state = _makeDetailState();

        await pumpSeeded(
          tester,
          const ActivityDetailScreen(activityId: 'act-1'),
          overrides: [
            activityDetailControllerProvider(activityId: 'act-1')
                .overrideWith(() => _FakeActivityDetailController(state)),
          ],
          settle: true,
        );

        expect(find.textContaining('Energy Gel'), findsWidgets);
      },
    );

    testWidgets(
      'renders the post-workout food name from the after-run section',
      (tester) async {
        final state = _makeDetailState();

        await pumpSeeded(
          tester,
          const ActivityDetailScreen(activityId: 'act-1'),
          overrides: [
            activityDetailControllerProvider(activityId: 'act-1')
                .overrideWith(() => _FakeActivityDetailController(state)),
          ],
          settle: true,
        );

        expect(find.textContaining('Chocolate Milk'), findsWidgets);
      },
    );

    testWidgets(
      'shows Complete button for a non-completed activity',
      (tester) async {
        final state = _makeDetailState();

        await pumpSeeded(
          tester,
          const ActivityDetailScreen(activityId: 'act-1'),
          overrides: [
            activityDetailControllerProvider(activityId: 'act-1')
                .overrideWith(() => _FakeActivityDetailController(state)),
          ],
          settle: true,
        );

        expect(find.text('Complete'), findsOneWidget);
      },
    );

    testWidgets(
      'carbs value from before-run section food is rendered (25g)',
      (tester) async {
        final state = _makeDetailState();

        await pumpSeeded(
          tester,
          const ActivityDetailScreen(activityId: 'act-1'),
          overrides: [
            activityDetailControllerProvider(activityId: 'act-1')
                .overrideWith(() => _FakeActivityDetailController(state)),
          ],
          settle: true,
        );

        // The macro summary row shows actual/target as "25/25g" or "25g";
        // at minimum the value "25" must appear.
        expect(find.textContaining('25'), findsWidgets);
      },
    );

    testWidgets(
      'delete button is visible (trash icon) for an existing activity',
      (tester) async {
        final state = _makeDetailState();

        await pumpSeeded(
          tester,
          const ActivityDetailScreen(activityId: 'act-1'),
          overrides: [
            activityDetailControllerProvider(activityId: 'act-1')
                .overrideWith(() => _FakeActivityDetailController(state)),
          ],
          settle: true,
        );

        // font_awesome_flutter v11+: FaIconData wraps IconData; use .data for find.byIcon.
        expect(find.byIcon(FontAwesomeIcons.trash.data), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // CarbLoadingScreen — DELETED (2026-07-01)
  // ---------------------------------------------------------------------------
  // lib/features/carb_loading/presentation/screens/carb_loading_screen.dart
  // was a pure mock-data screen with 0 nav references. File deleted.
  // The live entry point is carb_loading_day_detail_page.dart.

  // ---------------------------------------------------------------------------
  // NewActivityScreen — sport selector tab content tests
  // ---------------------------------------------------------------------------

  group('NewActivityScreen — sport selector tabs', () {
    testWidgets(
      'running tab button is present by key',
      (tester) async {
        // NewActivityScreen reads newActivityCoordinatorProvider (a plain
        // @riverpod Notifier, not Async) — the harness's mockAppExternalDeps()
        // satisfies analytics/supabase; the coordinator boots synchronously from
        // its build() default, so no extra override is needed.
        await pumpSeeded(tester, const NewActivityScreen());

        expect(
          find.byKey(const ValueKey('activity_create.tab_running')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'biking tab button is present by key',
      (tester) async {
        await pumpSeeded(tester, const NewActivityScreen());

        expect(
          find.byKey(const ValueKey('activity_create.tab_biking')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'swimming tab button is present by key',
      (tester) async {
        await pumpSeeded(tester, const NewActivityScreen());

        expect(
          find.byKey(const ValueKey('activity_create.tab_swimming')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'brick tab button is present by key',
      (tester) async {
        await pumpSeeded(tester, const NewActivityScreen());

        expect(
          find.byKey(const ValueKey('activity_create.tab_brick')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'RUNNING label is rendered on the running tab',
      (tester) async {
        await pumpSeeded(tester, const NewActivityScreen());

        expect(find.text('RUNNING'), findsOneWidget);
      },
    );

    testWidgets(
      'BIKING label is rendered on the biking tab',
      (tester) async {
        await pumpSeeded(tester, const NewActivityScreen());

        expect(find.text('BIKING'), findsOneWidget);
      },
    );

    testWidgets(
      'SWIMMING label is rendered on the swimming tab',
      (tester) async {
        await pumpSeeded(tester, const NewActivityScreen());

        expect(find.text('SWIMMING'), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // AdjustMacrosScreen — bug #4 regression canary
  //
  // Bug #4 fixed (2026-06-25): macroTargetsControllerProvider use-after-dispose.
  // _scheduleCleanupIfNeeded() previously registered:
  //   ref.onDispose(() => Future.delayed(2s, () => ref.read(...)))
  // The delayed closure read `ref` after the provider was disposed, causing:
  //   StateError: Cannot use ref after it was disposed
  // Fix: capture DraftActivityCleanupService before disposal and call
  // scheduleCleanup() with stored values; no ref access in the closure.
  // ---------------------------------------------------------------------------

  group('AdjustMacrosScreen — bug #4 regression canary', () {
    testWidgets(
      'mounts AdjustMacrosScreen without crashing (bug #4 fixed)',
      (tester) async {
        // Regression guard for macro_targets_controller.dart use-after-dispose.
        // If this test fails again, it means the fix regressed.
        await pumpSeeded(tester, const AdjustMacrosScreen(), settle: false);
        expect(find.byType(AdjustMacrosScreen), findsOneWidget);
      },
    );
  });
}

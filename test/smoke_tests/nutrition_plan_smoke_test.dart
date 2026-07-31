// Screen smoke suite — nutrition_plan + carb_loading screens.
//
// Pumps each screen with mocked external deps and asserts it builds without
// throwing and has no RenderFlex overflow at 390 px width (standard phone).
//
// Design notes per-screen are inline. The general rule: if a screen's
// AsyncNotifier controller requires real database/network calls to resolve,
// we seed it with a minimal override so the "data" branch renders instead of
// hanging in AsyncLoading.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/meal_type.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_loading_food_selection_controller.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/screens/carb_loading_protocol_selection_screen.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/screens/create_custom_carb_loading_food_screen.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/activity_detail_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/cycling_input_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/fuel_log_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/new_activity_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/swimming_input_screen.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_loading_day_detail_controller.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/screens/carb_loading_day_detail_page.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart' as db;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import '../helpers/widget_test_harness.dart';

// ---------------------------------------------------------------------------
// Minimal seeded controllers
// ---------------------------------------------------------------------------

/// Seeds ActivityDetailController with a basic running activity (no plan, no
/// completion) so the data-branch of the screen renders without touching real
/// DB / network.
class _SeededActivityDetailController extends ActivityDetailController {
  _SeededActivityDetailController(this._state);

  final ActivityDetailState _state;

  @override
  FutureOr<ActivityDetailState> build({
    required String activityId,
    bool isNewActivity = false,
  }) async => _state;
}

/// Seeds CarbLoadingFoodSelectionController with an empty state so the
/// data-branch (default / search-empty view) renders without DB calls.
class _SeededCarbLoadingFoodSelectionController
    extends CarbLoadingFoodSelectionController {
  @override
  Future<CarbLoadingFoodSelectionState> build(
    CarbLoadingFoodSelectionParams params,
  ) async => CarbLoadingFoodSelectionState(
    carbLoadingDayId: params.carbLoadingDayId,
    mealType: params.mealType,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal seeded Activity used across several tests.
Activity _minimalActivity({ActivityStatus status = ActivityStatus.planned}) {
  final now = DateTime.now();
  return Activity(
    id: 'smoke-activity-id',
    userId: 'smoke-user-id',
    activityType: ActivityType.running,
    title: 'Smoke Test Run',
    scheduledDateTime: now,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

/// Minimal seeded Event used by CarbLoadingProtocolSelectionScreen.
Event _minimalEvent() {
  final now = DateTime.now();
  return Event(
    id: 'smoke-event-id',
    userId: 'smoke-user-id',
    eventType: ActivityType.running,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // sharedPreferencesProvider is now provided by smokeScreen defaults
  // (mockSharedPreferences() in widget_test_harness.dart), so no explicit
  // override is needed in individual tests.

  group('Nutrition Plan + Carb Loading screen smoke tests', () {
    // -----------------------------------------------------------------------
    // 1. NewActivityScreen
    // -----------------------------------------------------------------------
    // NewActivityScreen uses several AsyncNotifier providers (running/cycling/
    // swimming/brick input controllers, coordinator, macro targets controller).
    // All of them have reasonable synchronous / near-synchronous initial states.
    // The screen calls fetchLocationForActiveTab() via a microtask in initState;
    // the underlying controllers attempt network calls but those are in event
    // handlers / postFrameCallbacks, not in the build path, so the initial
    // frame is safe.  settle:false avoids pumpAndSettle timeout caused by the
    // perpetual location/weather fetch.
    //
    // FIXED (2026-06-25): the DATE/TIME Row in new_activity_date_time_section
    // overflowed ~29 px at 390 px (long date string + xxl gap, no flex). Now
    // wrapped in FittedBox(scaleDown). This test enforces no overflow again.
    testWidgets('NewActivityScreen builds (loading/initial state)', (
      tester,
    ) async {
      await smokeScreen(tester, const NewActivityScreen(), settle: false);
    });

    // -----------------------------------------------------------------------
    // 2. ActivityDetailScreen — seeds the controller with a minimal Activity
    // -----------------------------------------------------------------------
    // Without a seed the controller would await real database + Supabase calls
    // and the screen would hang in AsyncLoading forever in widget-test land.
    // We replicate the same MockActivityDetailController pattern from the
    // existing unit test in
    // test/features/nutrition_plan/presentation/screens/activity_detail_screen_test.dart.
    //
    // FIXED (2026-06-25): two Rows overflowed — the date/time pair in
    // activity_schedule_info (~39 px) and the coach-feedback loading row in
    // activity_coach_feedback_widget (~112 px, label had no flex past a
    // Spacer). Now FittedBox(scaleDown) + Expanded(ellipsis) respectively.
    testWidgets('ActivityDetailScreen renders (seeded planned activity)', (
      tester,
    ) async {
      const activityId = 'smoke-activity-id';
      final activity = _minimalActivity();
      final state = ActivityDetailState(
        activity: activity,
        scheduledDateTime: activity.scheduledDateTime,
      );

      await smokeScreen(
        tester,
        const ActivityDetailScreen(
          activityId: activityId,
          isNewActivity: false,
        ),
        overrides: [
          activityDetailControllerProvider(
            activityId: activityId,
            isNewActivity: false,
          ).overrideWith(() => _SeededActivityDetailController(state)),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // 3. FuelLogScreen
    // -----------------------------------------------------------------------
    // FuelLogScreen watches activityDetailControllerProvider. Seed it with a
    // minimal planned activity that has no nutrition plan so we land on the
    // "no plan" empty state within FuelLogScreen (the simplest branch).
    testWidgets('FuelLogScreen builds (seeded, no-plan state)', (tester) async {
      const activityId = 'smoke-fuel-log-id';
      final activity = _minimalActivity();
      final state = ActivityDetailState(
        activity: activity,
        scheduledDateTime: activity.scheduledDateTime,
      );

      await smokeScreen(
        tester,
        const FuelLogScreen(activityId: activityId, isNewActivity: false),
        overrides: [
          activityDetailControllerProvider(
            activityId: activityId,
            isNewActivity: false,
          ).overrideWith(() => _SeededActivityDetailController(state)),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // 4-6. AdjustMacros / Cycling / Swimming input screens
    // -----------------------------------------------------------------------
    // These watch macroTargetsControllerProvider, whose onDispose schedules a
    // draft cleanup. FIXED (2026-06-25): DraftActivityCleanupService now uses a
    // cancellable Timer cancelled on its (keepAlive) provider's onDispose, so
    // the previously-leaking 2s timer no longer trips "A Timer is still pending"
    // at teardown — unblocking these three smoke tests. settle:false avoids the
    // perpetual location/weather fetch these screens kick off in initState.
    testWidgets('AdjustMacrosScreen builds (initial state)', (tester) async {
      await smokeScreen(tester, const AdjustMacrosScreen(), settle: false);
    });

    testWidgets('CyclingInputScreen builds (initial state)', (tester) async {
      await smokeScreen(tester, const CyclingInputScreen(), settle: false);
    });

    testWidgets('SwimmingInputScreen builds (initial state)', (tester) async {
      await smokeScreen(tester, const SwimmingInputScreen(), settle: false);
    });

    // -----------------------------------------------------------------------
    // 7. CurrentPlanScreen — DELETED (2026-06-25)
    // -----------------------------------------------------------------------
    // lib/features/nutrition_plan/presentation/screens/current_plan_screen.dart
    // was entirely block-commented dead code with zero references in lib/.
    // File deleted; nothing to test.

    // -----------------------------------------------------------------------
    // 8. CarbLoadingScreen — DELETED (2026-07-01)
    // -----------------------------------------------------------------------
    // lib/features/carb_loading/presentation/screens/carb_loading_screen.dart
    // was a pure mock-data screen with 0 nav references. File deleted.
    // The live carb-loading entry point is carb_loading_day_detail_page.dart.

    // -----------------------------------------------------------------------
    // 9. CarbLoadingFoodSelectionScreen
    // -----------------------------------------------------------------------
    // Controller (CarbLoadingFoodSelectionController) is an AsyncNotifier that
    // calls ensureSynced + DB queries in build().  Seed it with an empty state
    // (no foods loaded) so the data-branch (default empty list view) renders.
    testWidgets('CarbLoadingFoodSelectionScreen renders (seeded empty state)', (
      tester,
    ) async {
      const dayId = 'smoke-day-id';
      const mealType = MealType.breakfast;
      final params = CarbLoadingFoodSelectionParams(
        carbLoadingDayId: dayId,
        mealType: mealType,
      );

      await smokeScreen(
        tester,
        const CarbLoadingFoodSelectionScreen(dayId: dayId, mealType: mealType),
        overrides: [
          carbLoadingFoodSelectionControllerProvider(
            params,
          ).overrideWith(() => _SeededCarbLoadingFoodSelectionController()),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // 10. CreateCustomCarbLoadingFoodScreen
    // -----------------------------------------------------------------------
    // Pure form screen with no AsyncNotifier dependency on its initial render.
    // initState only pre-selects the mealType in a local Set.
    testWidgets('CreateCustomCarbLoadingFoodScreen renders without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const CreateCustomCarbLoadingFoodScreen(
          dayId: 'smoke-day-id',
          mealType: MealType.lunch,
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 11. CarbLoadingProtocolSelectionScreen
    // -----------------------------------------------------------------------
    // Pure ConsumerWidget — renders static protocol cards from hardcoded data.
    // Requires one constructor param: an Event object.
    testWidgets('CarbLoadingProtocolSelectionScreen renders without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        CarbLoadingProtocolSelectionScreen(event: _minimalEvent()),
      );
    });

    // -----------------------------------------------------------------------
    // 12. CarbLoadingDayDetailPage
    // -----------------------------------------------------------------------
    // Takes a Drift CarbLoadingDay row as a constructor param and watches the
    // carbLoadingDayDetailControllerProvider family (the real build() runs
    // ensureSynced + repository/DB queries). The family is pinned to a
    // never-completing future so the loading branch (Center + spinner) renders
    // deterministically. initState fires an analytics event — covered by the
    // harness's mocked AppExternalDeps. settle:false for the perpetual spinner.
    testWidgets('CarbLoadingDayDetailPage builds (loading state)', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        CarbLoadingDayDetailPage(carbLoadingDay: _minimalCarbLoadingDay()),
        overrides: [
          carbLoadingDayDetailControllerProvider.overrideWith(
            _LoadingCarbLoadingDayDetailController.new,
          ),
        ],
        settle: false,
      );
    });
  });
}

/// Pins CarbLoadingDayDetailController to AsyncLoading forever so the page's
/// loading branch renders deterministically without DB/Supabase.
class _LoadingCarbLoadingDayDetailController
    extends CarbLoadingDayDetailController {
  @override
  Future<CarbLoadingDayDetailState> build(String carbLoadingDayId) =>
      Completer<CarbLoadingDayDetailState>().future;
}

/// Minimal Drift CarbLoadingDay row for the page's constructor param (only
/// the app-bar title/date and analytics read it while the controller loads).
db.CarbLoadingDay _minimalCarbLoadingDay() => db.CarbLoadingDay(
  id: 'smoke-day-id',
  carbLoadingPlanId: 'smoke-plan-id',
  planDate: DateTime(2026, 7, 20),
  dayNumber: 1,
  carbTargetGrams: 500,
  carbProtocolGPerKg: 8.0,
  mealCount: 6,
  breakfastPercent: 0.25,
  morningSnackPercent: 0.10,
  lunchPercent: 0.25,
  afternoonSnackPercent: 0.10,
  dinnerPercent: 0.20,
  eveningSnackPercent: 0.10,
  loggedCarbsGrams: 0,
  loggedCalories: 0,
  completed: false,
  needsUpload: false,
  localUpdatedAt: DateTime(2026, 7, 20),
);

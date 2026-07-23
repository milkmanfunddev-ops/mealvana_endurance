import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/fuel_log_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fixtures/user_fixtures.dart';

// Regression tests for Bug Reports 391e3fdb754c81a4b47bd4ccd06b9647 ("Returning
// to workout nutrition logging hides the dashboard, blocks editing, and shows
// an inconsistent number") and 391e3fdb754c81f591bbc984fccf6de6 ("Post-workout
// carb/hr summary: editing workout nutrition updates the dashboard live but
// reverts on Save").
//
// Both fixes landed in `ActivityDetailController` inside commit
// c678917365a014d53db7f4589f4c232f2b2a633b ("chore: checkpoint WIP across
// active workstreams (stopping point)"), which is an ancestor of develop via
// `fix/web-edge-functions-cors`. Pre-fix behavior (confirmed via `git show`):
//
//  - `enterFuelLogMode()` unconditionally called
//    `FuelLogData.fromNutritionPlan(plan)`, resetting every item's
//    `actualQuantity` back to `plannedQuantity` and discarding any
//    previously-saved edit -> bug 1's "inconsistent number" / reset-on-reopen.
//  - `saveFuelLogAndComplete()`'s returned state did NOT carry the just-saved
//    `activity` forward (`currentState.copyWith(isCompleting: false, ...)`
//    with no `activity:` argument), so immediately after Save,
//    `state.value!.activity` was still the pre-edit activity until the async
//    `ref.invalidateSelf()` reload resolved -> bug 2's "reverts on Save".
//
// These tests drive the real (non-overridden) controller methods against a
// seeded state and prove the post-fix behavior; see inline comments for how
// each assertion would fail against the pre-fix logic.

class MockActivitiesService extends Mock implements ActivitiesService {}

class MockAuthService extends Mock implements AuthService {}

class FakeActivity extends Fake implements Activity {}

/// Test-only controller that seeds a fixed initial state (mirrors the
/// `MockActivityDetailController` pattern used in
/// `activity_detail_screen_test.dart`) but otherwise defers to the real
/// `ActivityDetailController` implementation for every other method — in
/// particular `enterFuelLogMode()` and `saveFuelLogAndComplete()`, which are
/// NOT overridden here.
class _SeededActivityDetailController extends ActivityDetailController {
  _SeededActivityDetailController(this._seed);

  final ActivityDetailState _seed;

  @override
  FutureOr<ActivityDetailState> build({
    required String activityId,
    bool isNewActivity = false,
  }) {
    return _seed;
  }
}

const _activityId = 'activity-fuel-log-1';
const _userId = 'user-fuel-log-1';

Activity _activity({Map<String, dynamic>? fuelLogData}) {
  return Activity(
    id: _activityId,
    userId: _userId,
    activityType: ActivityType.running,
    title: 'Long Run',
    scheduledDateTime: DateTime(2026, 7, 1, 7),
    durationMinutes: 120,
    status: ActivityStatus.completed,
    completedAt: DateTime(2026, 7, 1, 9),
    fuelLogData: fuelLogData,
    createdAt: DateTime(2026, 6, 30),
    updatedAt: DateTime(2026, 6, 30),
  );
}

NutritionPlan _plan() {
  return const NutritionPlan(
    id: 'plan-1',
    name: 'Long Run Nutrition Plan',
    sections: [
      PlanSection(
        id: 'during_run',
        title: 'During Run',
        foodItems: [
          FoodItemData(
            id: 'gel',
            name: 'Energy Gel',
            quantity: '3', // plannedQuantity == 3
            isIndivisible: true,
            nutritionalInfo: NutritionalInfo(carbs: 30),
          ),
        ],
      ),
    ],
  );
}

/// A previously-saved fuel log where the user logged 5 gels (actual) against
/// a plan of 3 (planned) — i.e. an edit made on a prior visit.
FuelLogData _savedEditedLog() {
  return FuelLogData(
    items: [
      FuelLogItem(
        foodId: 'gel',
        sectionId: 'during_run',
        plannedQuantity: 3,
        actualQuantity: 5,
        name: 'Energy Gel',
        isIndivisible: true,
        nutritionalInfo: const NutritionalInfo(carbs: 30),
      ),
    ],
  );
}

ProviderContainer _containerWithSeed(
  ActivityDetailState seed, {
  required MockActivitiesService activitiesService,
  required MockAuthService authService,
}) {
  final container = ProviderContainer(
    overrides: [
      activitiesServiceProvider.overrideWithValue(activitiesService),
      authServiceProvider.overrideWithValue(authService),
      activityDetailControllerProvider(
        activityId: _activityId,
        isNewActivity: false,
      ).overrideWith(() => _SeededActivityDetailController(seed)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeActivity());
  });

  group('Bug 391e3fdb…9647 — enterFuelLogMode must restore saved edits', () {
    test('enterFuelLogMode() loads the previously-saved actualQuantity, not '
        'the reset planned quantity', () async {
      final mockActivitiesService = MockActivitiesService();
      final mockAuthService = MockAuthService();

      final activityWithSavedLog = _activity(
        fuelLogData: _savedEditedLog().toJson(),
      );

      final seed = ActivityDetailState(
        activity: activityWithSavedLog,
        nutritionPlan: _plan(),
        scheduledDateTime: activityWithSavedLog.scheduledDateTime,
        // Not yet in fuel-log mode; fuelLogData starts null, exactly as it
        // does when a user navigates back into an already-logged workout.
        isFuelLogMode: false,
        fuelLogData: null,
      );

      final container = _containerWithSeed(
        seed,
        activitiesService: mockActivitiesService,
        authService: mockAuthService,
      );

      // Prime the provider (synchronous seeded build).
      container.read(
        activityDetailControllerProvider(
          activityId: _activityId,
          isNewActivity: false,
        ),
      );

      container
          .read(
            activityDetailControllerProvider(
              activityId: _activityId,
              isNewActivity: false,
            ).notifier,
          )
          .enterFuelLogMode();

      final state = container.read(
        activityDetailControllerProvider(
          activityId: _activityId,
          isNewActivity: false,
        ),
      );

      final fuelLog = state.value!.fuelLogData;
      expect(fuelLog, isNotNull);
      // Pre-fix, enterFuelLogMode() always called
      // FuelLogData.fromNutritionPlan(plan), so actualQuantity would be reset
      // to plannedQuantity (3) here, discarding the saved edit (5).
      expect(
        fuelLog!.items.single.actualQuantity,
        5,
        reason:
            'Reopening the fuel log must restore the saved actual '
            'quantity (5), not reset it to the planned quantity (3).',
      );
      expect(fuelLog.items.single.plannedQuantity, 3);
      expect(state.value!.isFuelLogMode, isTrue);
    });
  });

  group('Bug 391e3fdb…f591 — saveFuelLogAndComplete must not revert the '
      'dashboard number', () {
    test(
      'the state returned immediately after Save carries the just-saved '
      'activity (with the edited fuelLogData), not the pre-edit activity',
      () async {
        final mockActivitiesService = MockActivitiesService();
        final mockAuthService = MockAuthService();

        when(
          () => mockAuthService.getCurrentUser(),
        ).thenAnswer((_) async => UserFixtures.completedUser(id: _userId));

        // updateActivity echoes back whatever activity it was asked to save,
        // exactly like the real repository would once the write succeeds.
        when(
          () => mockActivitiesService.updateActivity(
            deviceId: any(named: 'deviceId'),
            activity: any(named: 'activity'),
          ),
        ).thenAnswer(
          (invocation) async =>
              invocation.namedArguments[#activity] as Activity,
        );

        // Pre-edit activity has no saved fuel log at all yet.
        final preEditActivity = _activity(fuelLogData: null);

        // In-memory fuel log data as it stands right before Save: the user
        // bumped actualQuantity from 3 (planned) to 5.
        final editedFuelLog = _savedEditedLog();

        final seed = ActivityDetailState(
          activity: preEditActivity,
          nutritionPlan: _plan(),
          scheduledDateTime: preEditActivity.scheduledDateTime,
          isFuelLogMode: true,
          fuelLogData: editedFuelLog,
        );

        final container = _containerWithSeed(
          seed,
          activitiesService: mockActivitiesService,
          authService: mockAuthService,
        );

        final provider = activityDetailControllerProvider(
          activityId: _activityId,
          isNewActivity: false,
        );

        // Capture every state emission (via a listener, like the real
        // `ActivityDetailScreen`/`FuelLogFeedbackSection` widgets do via
        // `ref.watch`), rather than reading the provider again after the
        // `await` below. A bare re-read after `saveFuelLogAndComplete()`
        // resolves is unreliable in this test harness because the seeded
        // controller's `build()` override is *synchronous*, so
        // `ref.invalidateSelf()` (called inside the method, purely to trigger
        // a background reload in production, where `build()` is async and
        // slow) can resolve its rebuild before a subsequent `container.read`
        // — clobbering the very state under test with the pristine seed. In
        // production `build()` awaits real DB/service calls, so it can't
        // resolve synchronously; the widget tree observes exactly the
        // transient value captured here before any reload completes. This
        // listener-capture approach observes what widgets actually see,
        // immune to that test-only timing artifact.
        final states = <AsyncValue<ActivityDetailState>>[];
        container.listen<AsyncValue<ActivityDetailState>>(
          provider,
          (previous, next) => states.add(next),
          fireImmediately: true,
        );

        await container
            .read(provider.notifier)
            .saveFuelLogAndComplete(overallSatisfaction: 5);

        // The state immediately following the save (i.e. the value the guard
        // block assigned, before any later invalidateSelf-triggered rebuild)
        // must carry the just-saved activity forward, with isCompleting back
        // to false and fuel-log mode exited.
        final postSave = states.lastWhere(
          (s) => s.hasValue && s.value!.isCompleting == false,
          orElse: () => throw StateError(
            'No post-save (isCompleting == false) state was ever emitted; '
            'captured states: $states',
          ),
        );

        final savedActivity = postSave.value!.activity;
        expect(
          savedActivity,
          isNotNull,
          reason:
              'saveFuelLogAndComplete must carry the just-saved activity '
              'forward in its returned state.',
        );

        // Pre-fix, `currentState.copyWith(isCompleting: false, ...)` was called
        // WITHOUT `activity: completedActivity`, so the state emitted right
        // after save would still carry `preEditActivity` here — whose
        // `fuelLogData` is null — instead of the value just written. Any
        // display that reads the dashboard number from `activity.fuelLogData`
        // (e.g. the carbs/hr card fallback) would therefore show reverted /
        // planned data for the window before the background reload resolves.
        expect(savedActivity!.fuelLogData, isNotNull);
        final persisted = FuelLogData.fromJson(savedActivity.fuelLogData!);
        expect(
          persisted.items.single.actualQuantity,
          5,
          reason:
              'The activity carried forward in state must reflect the '
              'just-edited actualQuantity (5), not the pre-edit value.',
        );

        // fuelLogData (in-memory) is intentionally cleared on exit — this is
        // correct in both pre- and post-fix behavior, and is exactly why the
        // display must fall back to `activity.fuelLogData` rather than reading
        // stale in-memory data.
        expect(postSave.value!.fuelLogData, isNull);
        expect(postSave.value!.isFuelLogMode, isFalse);
      },
    );
  });
}

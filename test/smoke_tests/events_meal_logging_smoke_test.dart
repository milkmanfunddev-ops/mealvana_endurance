// Screen smoke suite — events and meal-logging screens.
//
// Strategy:
//  • Screens with no GoRouter dependency: smokeScreen() directly.
//  • Screens that call GoRouterState.of(context) in didChangeDependencies:
//    wrapped with a minimal GoRouter so the lookup succeeds (extra == null is
//    safe in every case — screens fall back gracefully). settle:false because
//    async providers (Drift/Supabase) never resolve without real seeding.
//  • EventsListScreen / EventDetailScreen / RaceChecklistScreen: settle:false
//    because their async controllers never settle without DB/Supabase.

import 'dart:async';

// ignore: implementation_imports
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/src/internals.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/features/events/presentation/screens/events_list_screen.dart';
import 'package:mealvana_endurance/features/events/presentation/screens/event_form_screen.dart';
import 'package:mealvana_endurance/features/events/presentation/screens/event_detail_screen.dart';
import 'package:mealvana_endurance/features/race_checklist/presentation/screens/race_checklist_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/build_meal_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/edit_meal_log_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/manual_log_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/photo_capture_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/describe_meal_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/meal_review_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/recent_saved_picker_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/recipe_picker_screen.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../helpers/widget_test_harness.dart';

// ---------------------------------------------------------------------------
// Fake controllers that stay in AsyncLoading indefinitely (never-completing
// Future). Used to pin EventsListScreen to its loading branch so overflow
// enforcement is deterministic across machines with different local DB state.
// ---------------------------------------------------------------------------

class _LoadingEventsController extends EventsController {
  @override
  Future<List<Event>> build() => Completer<List<Event>>().future;
}

class _LoadingActivitiesController extends ActivitiesController {
  @override
  Future<List<Activity>> build() => Completer<List<Activity>>().future;
}

// ---------------------------------------------------------------------------
// GoRouter wrapper helper
//
// Screens that call GoRouterState.of(context) in didChangeDependencies will
// throw "No GoRouter found in widget tree" when pumped under plain MaterialApp.
// This helper builds a minimal GoRouter that serves the given screen as its
// sole route with no extra data (null extra — all screens handle that safely).
// ---------------------------------------------------------------------------

Future<void> _smokeWithRouter(
  WidgetTester tester,
  Widget Function() buildScreen, {
  List<Override> overrides = const [],
  bool settle = false,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, __) => buildScreen())],
  );

  final allOverrides = <Override>[
    mockAppExternalDeps(),
    appConfigProvider.overrideWithValue(AppConfig.forTesting()),
    ...overrides,
  ];

  bool isOverflow(String s) =>
      s.contains('overflowed') || s.contains('infinite size');

  const size = standardPhoneSize;
  final captured = <String>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) => captured.add(details.exceptionAsString());

  try {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: allOverrides,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  } finally {
    FlutterError.onError = previousOnError;
    router.dispose();
  }

  for (
    dynamic e = tester.takeException();
    e != null;
    e = tester.takeException()
  ) {
    captured.add(e.toString());
  }

  final crashes = captured.where((s) => !isOverflow(s)).toList();
  expect(
    crashes,
    isEmpty,
    reason:
        'Screen threw during build/layout at $size:\n${crashes.join('\n\n')}',
  );

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Events screen smoke tests', () {
    // EventsListScreen watches eventsControllerProvider and
    // activitiesControllerProvider — both async, never settle without DB.
    // Both providers are pinned to AsyncLoading (never-completing Future) so
    // the screen stays in the loading branch (Center + CircularProgressIndicator)
    // deterministically across machines. The loading branch uses a simple
    // Center(CircularProgressIndicator) — no unconstrained Column/ListView —
    // so overflow enforcement at 390px is safe and expected to pass.
    testWidgets('EventsListScreen builds (loading state)', (tester) async {
      await smokeScreen(
        tester,
        const EventsListScreen(),
        settle: false,
        overrides: [
          eventsControllerProvider.overrideWith(_LoadingEventsController.new),
          activitiesControllerProvider.overrideWith(
            _LoadingActivitiesController.new,
          ),
        ],
      );
    });

    // EventFormScreen is a pure form with no providers watched at build time
    // (searches happen on text-change debounce, not during initial render).
    // settle:true is safe here.
    testWidgets('EventFormScreen renders without overflow', (tester) async {
      await smokeScreen(tester, const EventFormScreen());
    });

    // EventDetailScreen watches eventDetailProvider (async, won't resolve).
    // No GoRouter dependency — uses constructor param not route state.
    // settle:false for the perpetual loading spinner.
    testWidgets('EventDetailScreen builds (loading state)', (tester) async {
      await smokeScreen(
        tester,
        const EventDetailScreen(eventId: 'test-event-id'),
        settle: false,
      );
    });

    // RaceChecklistScreen watches checklistControllerProvider (async, DB-backed).
    // No GoRouter dependency — uses constructor param.
    // settle:false for perpetual loading state.
    testWidgets('RaceChecklistScreen builds (loading state)', (tester) async {
      await smokeScreen(
        tester,
        const RaceChecklistScreen(eventId: 'test-event-id'),
        settle: false,
      );
    });
  });

  group('Meal logging screen smoke tests', () {
    // EditMealLogScreen reads GoRouterState.of(context) in didChangeDependencies.
    // With null extra, _originalLog stays null and the screen renders its empty
    // form (safe fallback — _submit() returns early when _originalLog == null).
    // settle:false because mealLogControllerProvider still needs the async init.
    testWidgets('EditMealLogScreen builds (no extra, empty form)', (
      tester,
    ) async {
      await _smokeWithRouter(tester, () => const EditMealLogScreen());
    });

    // ManualLogScreen reads GoRouterState.of(context) for logDate.
    // With null extra it falls back to today's date string — fully safe.
    testWidgets('ManualLogScreen builds', (tester) async {
      await _smokeWithRouter(tester, () => const ManualLogScreen());
    });

    // PhotoCaptureScreen reads GoRouterState.of(context) for logDate.
    // ImagePicker is only invoked on button taps, not at build time.
    // NOTE: If a MethodChannel error fires for image_picker on the test host,
    // this is a native-plugin init issue, not a code bug — mark Patrol-only.
    testWidgets('PhotoCaptureScreen builds', (tester) async {
      await _smokeWithRouter(tester, () => const PhotoCaptureScreen());
    });

    // DescribeMealScreen reads GoRouterState.of(context) for logDate.
    // Pure form UI — AI call only fires on submit tap.
    testWidgets('DescribeMealScreen builds', (tester) async {
      await _smokeWithRouter(tester, () => const DescribeMealScreen());
    });

    // MealReviewScreen reads GoRouterState.of(context) for MealAnalysisResult.
    // With null extra, _result == null and the screen shows 'Missing analysis
    // result.' fallback text — a defined safe state, not a crash.
    testWidgets('MealReviewScreen builds (missing result fallback)', (
      tester,
    ) async {
      await _smokeWithRouter(tester, () => const MealReviewScreen());
    });

    // RecentSavedPickerScreen reads GoRouterState.of(context) for logDate and
    // watches savedMealsProvider + recentMealsProvider (both async streams).
    // settle:false — streams never emit without real Drift DB.
    testWidgets('RecentSavedPickerScreen builds (loading state)', (
      tester,
    ) async {
      await _smokeWithRouter(tester, () => const RecentSavedPickerScreen());
    });

    // RecipePickerScreen reads GoRouterState.of(context) for logDate and calls
    // recipeService.ensureSynced() + getAllRecipes() in didChangeDependencies.
    // settle:false — async recipe load never completes without a real DB.
    testWidgets('RecipePickerScreen builds (loading state)', (tester) async {
      await _smokeWithRouter(tester, () => const RecipePickerScreen());
    });

    // LogMealScreen (full-screen "Log a Meal" redesign) — logDate is a plain
    // constructor param (no GoRouterState dependency), so it renders under a
    // bare MaterialApp like smokeScreen() does elsewhere. It watches several
    // async providers (recentMeals/savedMeals/recipes) that never resolve
    // without a real Drift DB + auth session, and its initState schedules
    // non-fatal best-effort seeding (wrapped in try/catch) via a post-frame
    // callback — settle:false keeps the test deterministic and avoids waiting
    // on work that never completes in this harness.
    testWidgets('LogMealScreen builds (loading state)', (tester) async {
      await smokeScreen(
        tester,
        const LogMealScreen(logDate: '2026-07-04'),
        settle: false,
      );
    });

    testWidgets('LogMealScreen hides Describe when release flag is off', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const LogMealScreen(logDate: '2026-07-04'),
        settle: false,
        appConfig: AppConfig.forTesting(describeMealEnabled: false),
      );

      expect(find.text('Describe'), findsNothing);
    });

    // BuildMealScreen (Surface 2 of the meal-logging split) — same shape as
    // LogMealScreen: plain constructor params, no GoRouterState dependency.
    // Renders its empty state synchronously (draftMealControllerProvider's
    // initial state has zero components) — no async provider gates the
    // first frame, so settle:true is safe here.
    testWidgets('BuildMealScreen builds (empty draft state)', (tester) async {
      await smokeScreen(tester, const BuildMealScreen(logDate: '2026-07-04'));
    });
  });
}

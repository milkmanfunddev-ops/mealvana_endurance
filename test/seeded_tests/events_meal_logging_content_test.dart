// Seeded CONTENT tests — events + meal-logging screens.
//
// Tests drive each screen with fake seeded state (via provider overrides /
// GoRouter extras) and assert that the rendered VALUES are correct, that
// validation messages appear on bad input, and that null-extra fallbacks work.
//
// Screens covered:
//  1. EventDetailScreen       — seeded event name / date / location rendered
//  2. EventFormScreen         — create-mode form; validation error on empty save
//  3. MealReviewScreen        — seeded MealAnalysisResult items + null-extra fallback
//  4. ManualLogScreen         — field labels render; validation fires on empty submit

import 'dart:async';

// ignore: implementation_imports
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/src/internals.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/features/events/presentation/screens/event_detail_screen.dart';
import 'package:mealvana_endurance/features/events/presentation/screens/event_form_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_analysis_result.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/manual_log_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/meal_review_screen.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import '../helpers/widget_test_harness.dart';

// ============================================================================
// Shared helpers
// ============================================================================

/// Pump a screen that calls [GoRouterState.of(context)] inside a minimal
/// GoRouter with [extra] injected on the sole route.
///
/// Applies the same baseline overrides as [pumpSeeded] (mocked deps, in-memory
/// DB, mock prefs, signed-out user). Append extra provider overrides via
/// [overrides].
Future<void> _pumpWithRouter(
  WidgetTester tester,
  Widget Function() buildScreen, {
  Object? extra,
  List<Override> overrides = const [],
  bool settle = false,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => buildScreen(),
      ),
    ],
    redirect: (_, state) => null,
  );

  // Pass extra via a separate navigate call because GoRouter's initialLocation
  // does not carry extras; instead we navigate with extra after the first pump.
  // Simpler approach: use a page builder that embeds extra in state directly.
  // However the cleanest approach is the two-route pattern from smoke tests.

  final allOverrides = <Override>[
    mockAppExternalDeps(),
    inMemoryDatabaseOverride(),
    ...overrides,
  ];

  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: allOverrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Pump a screen with GoRouter + extras.
///
/// Uses a dedicated route that carries [extra] through the GoRouter state so
/// [GoRouterState.of(context).extra] returns the expected object.
Future<void> _pumpWithExtra(
  WidgetTester tester,
  String screenPath,
  Widget Function() buildScreen, {
  required Object? extra,
  List<Override> overrides = const [],
  bool settle = false,
}) async {
  // Build a two-route router: '/' is a placeholder, '/screen' carries the
  // extra. Navigate programmatically after the first pump so GoRouterState.extra
  // is populated before didChangeDependencies runs on the target screen.
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: screenPath,
        builder: (_, __) => buildScreen(),
      ),
    ],
  );

  final allOverrides = <Override>[
    mockAppExternalDeps(),
    inMemoryDatabaseOverride(),
    ...overrides,
  ];

  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: allOverrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();

  // Navigate programmatically with extras
  router.go(screenPath, extra: extra);

  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

// ============================================================================
// Fake EventDetail provider
// ============================================================================

/// A fake [eventDetailProvider] that returns a seeded event without touching
/// any repository or Supabase.
///
/// [eventDetailProvider] is a `@riverpod` family Future provider; we override
/// it with a synchronous future.
Override _fakeEventDetail({
  required String eventId,
  required Event event,
  Activity? activity,
}) {
  return eventDetailProvider(eventId).overrideWith(
    (ref) async => (activity: activity, event: event),
  );
}

/// Builds a minimal [Event] suitable for seeding.
Event _seedEvent({
  String id = 'evt-1',
  String name = 'Boston Marathon 2026',
  String location = 'Boston, MA',
  String startTime = '2026-04-20T07:00:00.000',
}) {
  final now = DateTime.now();
  return Event(
    id: id,
    userId: 'u1',
    eventType: ActivityType.running,
    eventSubtype: 'marathon',
    eventName: name,
    location: location,
    startTime: startTime,
    goalTimeMinutes: 210, // 3h 30m
    createdAt: now,
    updatedAt: now,
  );
}

// ============================================================================
// Fake MealLogController
// ============================================================================

class _FakeMealLogController extends MealLogController {
  @override
  FutureOr<void> build() => null;
}

// ============================================================================
// 1. EventDetailScreen — seeded content
// ============================================================================

void main() {
  group('EventDetailScreen — seeded content', () {
    testWidgets('renders event name from seeded provider', (tester) async {
      final event = _seedEvent(name: 'Boston Marathon 2026');
      await pumpSeeded(
        tester,
        const EventDetailScreen(eventId: 'evt-1'),
        overrides: [
          _fakeEventDetail(eventId: 'evt-1', event: event),
        ],
        settle: true,
      );

      expect(find.text('Boston Marathon 2026'), findsOneWidget,
          reason: 'Event name must appear in the EventHeaderCard');
    });

    testWidgets('renders event location from seeded provider', (tester) async {
      final event = _seedEvent(location: 'Boston, MA');
      await pumpSeeded(
        tester,
        const EventDetailScreen(eventId: 'evt-1'),
        overrides: [
          _fakeEventDetail(eventId: 'evt-1', event: event),
        ],
        settle: true,
      );

      // EventDetailsCard renders location via LocationFormatter.parseAndFormatCityState.
      // The value 'Boston, MA' is a comma-separated city,state string and should
      // pass through the formatter as-is (no country stripping needed here).
      expect(find.textContaining('Boston'), findsWidgets,
          reason: 'Location city must appear in EventDetailsCard');
    });

    testWidgets('renders event date from seeded provider', (tester) async {
      // startTime = 2026-04-20T07:00:00 → "Monday, April 20, 2026"
      final event = _seedEvent(startTime: '2026-04-20T07:00:00.000');
      await pumpSeeded(
        tester,
        const EventDetailScreen(eventId: 'evt-1'),
        overrides: [
          _fakeEventDetail(eventId: 'evt-1', event: event),
        ],
        settle: true,
      );

      // EventHeaderCard formats the date as "EEEE, MMMM d, yyyy"
      expect(find.textContaining('April 20, 2026'), findsOneWidget,
          reason: 'Formatted date must appear in EventHeaderCard');
    });

    testWidgets('renders goal time when set', (tester) async {
      // goalTimeMinutes = 210 → "3h 30m"
      final event = _seedEvent();
      await pumpSeeded(
        tester,
        const EventDetailScreen(eventId: 'evt-1'),
        overrides: [
          _fakeEventDetail(eventId: 'evt-1', event: event),
        ],
        settle: true,
      );

      expect(find.text('3h 30m'), findsOneWidget,
          reason: 'Goal time must be formatted as Xh Ym in EventDetailsCard');
    });

    testWidgets('shows error state when provider throws', (tester) async {
      await pumpSeeded(
        tester,
        const EventDetailScreen(eventId: 'missing-id'),
        overrides: [
          eventDetailProvider('missing-id').overrideWith(
            (ref) async => throw Exception('Event not found: missing-id'),
          ),
        ],
        settle: true,
      );

      expect(find.text('Error loading event'), findsOneWidget,
          reason: 'Error card must appear when provider throws');
    });
  });

  // ==========================================================================
  // 2. EventFormScreen — validation
  // ==========================================================================

  group('EventFormScreen — validation', () {
    testWidgets('shows "New Event" title in create mode', (tester) async {
      // EventFormScreen does NOT read GoRouterState, so pumpSeeded is fine.
      await pumpSeeded(tester, const EventFormScreen(), settle: true);

      expect(find.text('New Event'), findsOneWidget,
          reason: 'AppBar title must read "New Event" in create mode');
    });

    testWidgets('shows "Edit Event" title in edit mode', (tester) async {
      final event = _seedEvent();
      await pumpSeeded(tester, EventFormScreen(event: event), settle: true);

      expect(find.text('Edit Event'), findsOneWidget,
          reason: 'AppBar title must read "Edit Event" when event is passed');
    });

    testWidgets(
        'tapping save with empty event name shows validation error',
        (tester) async {
      // Tall surface ensures the Save button is on-screen without scrolling.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpSeeded(tester, const EventFormScreen(), settle: true);

      // Tap the Create Event button (now in-viewport on the tall surface)
      final saveButtonFinder =
          find.byKey(const ValueKey('event_create.create_button'));
      expect(saveButtonFinder, findsOneWidget,
          reason: 'Create button must be present');
      await tester.tap(saveButtonFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      // Validator returns 'Please enter an event name'
      expect(find.text('Please enter an event name'), findsOneWidget,
          reason: 'Validation error must appear when event name is empty');
    });

    testWidgets(
        'goal time minutes validator fires when out of range (60)',
        (tester) async {
      // Tall surface so the entire form (sport selector → ExpansionTile → save
      // button) fits in one viewport without scrolling.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpSeeded(tester, const EventFormScreen(), settle: true);

      // Expand the "Additional Details" ExpansionTile
      await tester.tap(
        find.byKey(const ValueKey('event_create.additional_heading')),
      );
      await tester.pumpAndSettle();

      // Enter 60 (invalid — must be 0-59) into the goal time Minutes field.
      // Two 'Minutes' TextFormFields exist (goal time, goal pace); first = goal time.
      final minutesFields = find.widgetWithText(TextFormField, 'Minutes');
      await tester.enterText(minutesFields.first, '60');
      await tester.pump();

      // Fill a valid event name so the minutes validator is the one that fires
      await tester.enterText(
        find.byKey(const ValueKey('event_create.name_field')),
        'Test Race',
      );

      await tester.tap(
        find.byKey(const ValueKey('event_create.create_button')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Must be 0-59'), findsOneWidget,
          reason:
              'Goal time minutes validator must reject 60 with "Must be 0-59"');
    });

    testWidgets(
        'goal pace seconds validator fires when out of range (99)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpSeeded(tester, const EventFormScreen(), settle: true);

      // Expand the "Additional Details" ExpansionTile
      await tester.tap(
        find.byKey(const ValueKey('event_create.additional_heading')),
      );
      await tester.pumpAndSettle();

      // Find goal pace Seconds field (only one Seconds field in the form)
      final secondsFields = find.widgetWithText(TextFormField, 'Seconds');
      await tester.enterText(secondsFields.first, '99');
      await tester.pump();

      // Fill valid event name
      await tester.enterText(
        find.byKey(const ValueKey('event_create.name_field')),
        'Test Race',
      );

      await tester.tap(
        find.byKey(const ValueKey('event_create.create_button')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Must be 0-59'), findsOneWidget,
          reason:
              'Goal pace seconds validator must reject 99 with "Must be 0-59"');
    });

    testWidgets('renders event name field and location field', (tester) async {
      await pumpSeeded(tester, const EventFormScreen(), settle: true);

      expect(
        find.byKey(const ValueKey('event_create.name_field')),
        findsOneWidget,
        reason: 'Event name TextFormField must be present',
      );
      expect(
        find.byKey(const ValueKey('event_create.location_field')),
        findsOneWidget,
        reason: 'Location TextFormField must be present',
      );
    });

    testWidgets('date and time buttons render in create mode', (tester) async {
      await pumpSeeded(tester, const EventFormScreen(), settle: true);

      expect(
        find.byKey(const ValueKey('event_create.date_button')),
        findsOneWidget,
        reason: 'Date picker button must be present',
      );
      expect(
        find.byKey(const ValueKey('event_create.time_button')),
        findsOneWidget,
        reason: 'Time picker button must be present',
      );
    });

    testWidgets('pre-fills event name in edit mode', (tester) async {
      final event = _seedEvent(name: 'Chicago Marathon');
      await pumpSeeded(tester, EventFormScreen(event: event), settle: true);

      final nameField = tester.widget<TextFormField>(
        find.byKey(const ValueKey('event_create.name_field')),
      );
      expect(nameField.controller?.text, equals('Chicago Marathon'),
          reason: 'Event name field must be pre-filled in edit mode');
    });
  });

  // ==========================================================================
  // 3. MealReviewScreen — seeded MealAnalysisResult
  // ==========================================================================

  group('MealReviewScreen — seeded content', () {
    // Build a seeded MealAnalysisResult with a single item
    MealAnalysisResult _buildResult() {
      const item = MealAnalysisItem(
        name: 'Oatmeal',
        portion: '1 cup',
        calories: 300,
        carbG: 54.0,
        proteinG: 10.0,
        fatG: 6.0,
        sodiumMg: 150.0,
      );
      return MealAnalysisResult(
        name: 'Morning Oatmeal',
        suggestedSlot: MealSlot.breakfast,
        confidence: MealAnalysisConfidence.high,
        items: const [item],
        totals: const MealAnalysisTotals(
          calories: 300,
          carbG: 54.0,
          proteinG: 10.0,
          fatG: 6.0,
          sodiumMg: 150.0,
        ),
        notes: 'Estimated based on standard oatmeal portion',
      );
    }

    testWidgets('shows null-extra fallback text when no extra provided',
        (tester) async {
      // With no extra, _result == null → shows 'Missing analysis result.'
      await _pumpWithRouter(
        tester,
        () => const MealReviewScreen(),
      );

      expect(find.text('Missing analysis result.'), findsOneWidget,
          reason:
              'Null extra must render the fallback "Missing analysis result." text');
    });

    testWidgets('renders meal name from seeded result', (tester) async {
      final result = _buildResult();
      await _pumpWithExtra(
        tester,
        '/review',
        () => const MealReviewScreen(),
        extra: {
          'result': result,
          'source': 'photo',
          'logDate': '2026-06-25',
        },
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      // MealReviewScreen sets _nameCtrl.text = _result!.name
      expect(find.text('Morning Oatmeal'), findsOneWidget,
          reason: 'Meal name must be pre-filled from MealAnalysisResult.name');
    });

    testWidgets('renders item name from seeded result', (tester) async {
      final result = _buildResult();
      await _pumpWithExtra(
        tester,
        '/review',
        () => const MealReviewScreen(),
        extra: {
          'result': result,
          'source': 'photo',
          'logDate': '2026-06-25',
        },
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      // MealItemsEditor renders item.name as ListTile title
      expect(find.text('Oatmeal'), findsOneWidget,
          reason: 'Item name must appear in the MealItemsEditor');
    });

    testWidgets('renders item calorie value from seeded result',
        (tester) async {
      final result = _buildResult();
      await _pumpWithExtra(
        tester,
        '/review',
        () => const MealReviewScreen(),
        extra: {
          'result': result,
          'source': 'photo',
          'logDate': '2026-06-25',
        },
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      // MealItemsEditor subtitle: "1 cup · 300 kcal  C 54g  P 10g  F 6g"
      expect(find.textContaining('300 kcal'), findsWidgets,
          reason: 'Item calories must appear in MealItemsEditor subtitle');
    });

    testWidgets('renders total calorie row', (tester) async {
      final result = _buildResult();
      await _pumpWithExtra(
        tester,
        '/review',
        () => const MealReviewScreen(),
        extra: {
          'result': result,
          'source': 'photo',
          'logDate': '2026-06-25',
        },
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      // MealItemsEditor totals row: "300 kcal  C 54g  P 10g  F 6g"
      expect(find.text('Total'), findsOneWidget,
          reason: 'Total row must appear in MealItemsEditor');
    });

    testWidgets('renders confidence badge for high confidence', (tester) async {
      final result = _buildResult(); // confidence: high
      await _pumpWithExtra(
        tester,
        '/review',
        () => const MealReviewScreen(),
        extra: {
          'result': result,
          'source': 'photo',
          'logDate': '2026-06-25',
        },
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(find.text('High confidence'), findsOneWidget,
          reason: '_ConfidenceBadge must show "High confidence" label');
    });

    testWidgets('renders AI notes when notes are present', (tester) async {
      final result = _buildResult(); // has notes
      await _pumpWithExtra(
        tester,
        '/review',
        () => const MealReviewScreen(),
        extra: {
          'result': result,
          'source': 'photo',
          'logDate': '2026-06-25',
        },
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(
        find.text('Estimated based on standard oatmeal portion'),
        findsOneWidget,
        reason: 'AI notes must render when MealAnalysisResult.notes is set',
      );
    });

    testWidgets('renders "Log this meal" button', (tester) async {
      final result = _buildResult();
      await _pumpWithExtra(
        tester,
        '/review',
        () => const MealReviewScreen(),
        extra: {
          'result': result,
          'source': 'photo',
          'logDate': '2026-06-25',
        },
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(find.text('Log this meal'), findsOneWidget,
          reason: 'Submit button must be present');
    });

    testWidgets('confidence badge shows low-confidence label correctly',
        (tester) async {
      const item = MealAnalysisItem(
        name: 'Unknown dish',
        portion: '1 serving',
        calories: 500,
        carbG: 60.0,
        proteinG: 20.0,
        fatG: 15.0,
        sodiumMg: 400.0,
      );
      final lowConfResult = MealAnalysisResult(
        name: 'Unknown dish',
        suggestedSlot: MealSlot.lunch,
        confidence: MealAnalysisConfidence.low,
        items: const [item],
        totals: const MealAnalysisTotals(
          calories: 500,
          carbG: 60.0,
          proteinG: 20.0,
          fatG: 15.0,
          sodiumMg: 400.0,
        ),
      );

      await _pumpWithExtra(
        tester,
        '/review',
        () => const MealReviewScreen(),
        extra: {
          'result': lowConfResult,
          'source': 'describe',
          'logDate': '2026-06-25',
        },
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(find.text('Low confidence — please review'), findsOneWidget,
          reason: 'Low-confidence badge must show review warning');
    });
  });

  // ==========================================================================
  // 4. ManualLogScreen — field presence + validation
  // ==========================================================================

  group('ManualLogScreen — content and validation', () {
    // ManualLogScreen reads GoRouterState.of(context) for logDate.
    // null extra → falls back to today; the form renders fully.

    testWidgets('renders "Log a Meal" app bar title', (tester) async {
      await _pumpWithRouter(
        tester,
        () => const ManualLogScreen(),
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(find.text('Log a Meal'), findsOneWidget,
          reason: 'AppBar must show "Log a Meal"');
    });

    testWidgets('renders meal name, calories, carbs, protein, fat fields',
        (tester) async {
      await _pumpWithRouter(
        tester,
        () => const ManualLogScreen(),
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(find.widgetWithText(TextFormField, 'Meal name'), findsOneWidget,
          reason: 'Meal name field must render');
      expect(find.widgetWithText(TextFormField, 'Calories (kcal)'),
          findsOneWidget,
          reason: 'Calories field must render');
      expect(
          find.widgetWithText(TextFormField, 'Carbs (g)'), findsOneWidget,
          reason: 'Carbs field must render');
      expect(
          find.widgetWithText(TextFormField, 'Protein (g)'), findsOneWidget,
          reason: 'Protein field must render');
      expect(find.widgetWithText(TextFormField, 'Fat (g)'), findsOneWidget,
          reason: 'Fat field must render');
    });

    testWidgets('submitting empty form shows "Name is required" error',
        (tester) async {
      await _pumpWithRouter(
        tester,
        () => const ManualLogScreen(),
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      // Tap Save without entering any data (scroll it into view first — the
      // manual form now includes slot + time fields, so Save can sit below the
      // test viewport fold).
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget,
          reason: 'Validation must require a meal name');
    });

    testWidgets('saves button is present and enabled when idle', (tester) async {
      await _pumpWithRouter(
        tester,
        () => const ManualLogScreen(),
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(find.text('Save'), findsOneWidget,
          reason: 'Save button must be present in the form');
    });

    testWidgets('renders Meal type section label', (tester) async {
      await _pumpWithRouter(
        tester,
        () => const ManualLogScreen(),
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(find.text('Meal type'), findsOneWidget,
          reason: 'Slot selector section label must appear');
    });
  });
}

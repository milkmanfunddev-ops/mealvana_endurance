import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/activities/presentation/widgets/activity_card.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';

/// Records delete/restore calls without touching the real service/DB stack.
///
/// The recording lists are passed in (not owned) because the autoDispose
/// provider may be recreated between the delete and the Undo tap — each
/// recreation needs a FRESH notifier instance writing to the same lists.
class _FakeActivitiesController extends ActivitiesController {
  _FakeActivitiesController(this.deleted, this.restored);

  final List<String> deleted;
  final List<Activity> restored;

  @override
  FutureOr<List<Activity>> build() async => const [];

  @override
  Future<void> deleteActivity(String activityId) async {
    deleted.add(activityId);
  }

  @override
  Future<void> restoreActivity(Activity activity) async {
    restored.add(activity);
  }
}

class _MockAppExternalDeps extends Mock implements AppExternalDeps {}

void main() {
  group('ActivityCard Widget Tests', () {
    late Activity testActivity;

    setUp(() {
      testActivity = Activity(
        id: 'test-activity-1',
        userId: 'test-user-1',
        activityType: ActivityType.running,
        title: 'Morning Run',
        scheduledDateTime: DateTime(2026, 1, 27, 6, 0), // 6:00 AM
        distanceMiles: 10.5,
        paceTargetMinutesPerMile: 8.5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    testWidgets('displays activity title', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ActivityCard(activity: testActivity),
            ),
          ),
        ),
      );

      expect(find.text('Morning Run'), findsOneWidget);
    });

    testWidgets('displays scheduled time in activity details',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ActivityCard(activity: testActivity),
            ),
          ),
        ),
      );

      // Should display "6:00 AM · 10.5 mi · 8:30/mi"
      expect(find.textContaining('6:00 AM'), findsOneWidget);
    });

    testWidgets('displays distance and pace for running activity',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ActivityCard(activity: testActivity),
            ),
          ),
        ),
      );

      // Should display distance
      expect(find.textContaining('10.5 mi'), findsOneWidget);
    });

    // Unified card interaction (391e3fdb): the chevron affordance is gone in
    // BOTH modes — tap anywhere on the card opens the detail/edit surface.
    testWidgets('never shows a chevron icon', (WidgetTester tester) async {
      for (final selectionMode in [false, true]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ActivityCard(
                  activity: testActivity,
                  isSelectionMode: selectionMode,
                ),
              ),
            ),
          ),
        );
        expect(
          find.byIcon(Icons.chevron_right),
          findsNothing,
          reason: 'no chevron expected (selectionMode: $selectionMode)',
        );
      }
    });

    testWidgets('shows selection indicator when in selection mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ActivityCard(
                activity: testActivity,
                isSelectionMode: true,
                isSelected: false,
              ),
            ),
          ),
        ),
      );

      // Should show empty checkbox (a container with border)
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('shows numbered indicator when selected in selection mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ActivityCard(
                activity: testActivity,
                isSelectionMode: true,
                isSelected: true,
                selectionOrder: 1,
              ),
            ),
          ),
        ),
      );

      // Should show "1" for first selected item
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('is wrapped in Dismissible when NOT in selection mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ActivityCard(
                activity: testActivity,
                isSelectionMode: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('is NOT wrapped in Dismissible when in selection mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ActivityCard(
                activity: testActivity,
                isSelectionMode: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Dismissible), findsNothing);
    });

    testWidgets('displays correct activity icon for running',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ActivityCard(activity: testActivity),
            ),
          ),
        ),
      );

      // Running icon should be present
      expect(find.byType(Icon), findsWidgets);
    });

    testWidgets('displays cycling details correctly',
        (WidgetTester tester) async {
      final cyclingActivity = Activity(
        id: 'test-cycling-1',
        userId: 'test-user-1',
        activityType: ActivityType.cycling,
        title: 'Morning Ride',
        scheduledDateTime: DateTime(2026, 1, 27, 7, 30), // 7:30 AM
        distanceMiles: 25.0,
        cyclingSpeedMph: 18.5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ActivityCard(activity: cyclingActivity),
            ),
          ),
        ),
      );

      // Should display scheduled time
      expect(find.textContaining('7:30 AM'), findsOneWidget);
      // Should display distance
      expect(find.textContaining('25.0 mi'), findsOneWidget);
      // Should display speed
      expect(find.textContaining('18.5 mph'), findsOneWidget);
    });
  });

  group('ActivityCard swipe-to-delete (unified interaction 391e3fdb)', () {
    late Activity testActivity;
    late List<String> deleted;
    late List<Activity> restored;

    setUp(() {
      testActivity = Activity(
        id: 'test-activity-1',
        userId: 'test-user-1',
        activityType: ActivityType.running,
        title: 'Morning Run',
        scheduledDateTime: DateTime(2026, 1, 27, 6, 0),
        distanceMiles: 10.5,
        paceTargetMinutesPerMile: 8.5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      deleted = [];
      restored = [];
    });

    Widget host() => ProviderScope(
          overrides: [
            activitiesControllerProvider.overrideWith(
              () => _FakeActivitiesController(deleted, restored),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: ActivityCard(activity: testActivity)),
          ),
        );

    for (final (label, offset) in [
      ('right→left', const Offset(-400.0, 0.0)),
      ('left→right', const Offset(400.0, 0.0)),
    ]) {
      testWidgets(
          'swipe $label deletes immediately with an Undo snackbar '
          '(no confirm dialog)', (tester) async {
        await tester.pumpWidget(host());
        await tester.drag(find.byType(Dismissible), offset);
        await tester.pumpAndSettle();

        // No blocking AlertDialog — offline-first soft delete fired directly.
        expect(find.byType(AlertDialog), findsNothing);
        expect(deleted, ['test-activity-1']);

        // Undo snackbar, consistent with the meal delete pattern.
        expect(find.text('Activity deleted'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);

        // The card is still in the tree (confirmDismiss returned false; the
        // row leaves via the provider rebuild in the real list).
        expect(find.text('Morning Run'), findsOneWidget);
      });
    }

    testWidgets('Undo restores the activity via restoreActivity',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.drag(find.byType(Dismissible), const Offset(-400, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(restored.map((a) => a.id), ['test-activity-1']);
    });
  });

  group('ActivityCard tap navigation (unified interaction 391e3fdb)', () {
    late _MockAppExternalDeps deps;

    Activity activity({Map<String, dynamic>? plan}) => Activity(
          id: 'test-activity-1',
          userId: 'test-user-1',
          activityType: ActivityType.running,
          title: 'Morning Run',
          scheduledDateTime: DateTime(2026, 1, 27, 6, 0),
          distanceMiles: 10.5,
          nutritionPlanData: plan,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    setUp(() {
      deps = _MockAppExternalDeps();
      when(() => deps.analytics).thenReturn(const NoopAnalyticsTracker());
    });

    Widget host(Activity a) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(body: ActivityCard(activity: a)),
          ),
          GoRoute(
            path: '/plan',
            builder: (_, __) =>
                const Scaffold(body: Text('activity-detail-screen')),
          ),
          GoRoute(
            path: '/distancepacegut',
            builder: (_, __) =>
                const Scaffold(body: Text('activity-editor-screen')),
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          activitiesControllerProvider.overrideWith(
            () => _FakeActivitiesController([], []),
          ),
          appExternalDepsProvider.overrideWithValue(deps),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('tap anywhere opens Activity Detail when a plan exists',
        (tester) async {
      await tester.pumpWidget(
        host(activity(plan: {'sections': <dynamic>[]})),
      );
      await tester.tap(find.text('Morning Run'));
      await tester.pumpAndSettle();
      expect(find.text('activity-detail-screen'), findsOneWidget);
    });

    testWidgets('tap anywhere opens the prefilled editor when no plan exists',
        (tester) async {
      await tester.pumpWidget(host(activity()));
      await tester.tap(find.text('Morning Run'));
      await tester.pumpAndSettle();
      expect(find.text('activity-editor-screen'), findsOneWidget);
    });

    testWidgets('selection-mode tap toggles selection instead of navigating',
        (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activitiesControllerProvider.overrideWith(
              () => _FakeActivitiesController([], []),
            ),
            appExternalDepsProvider.overrideWithValue(deps),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ActivityCard(
                activity: activity(),
                isSelectionMode: true,
                onSelectionToggle: () => toggled = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Morning Run'));
      expect(toggled, isTrue);
    });
  });
}

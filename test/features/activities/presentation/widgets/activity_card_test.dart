import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/widgets/activity_card.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

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

    testWidgets('shows chevron icon when NOT in selection mode',
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

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('does NOT show chevron when in selection mode',
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

      expect(find.byIcon(Icons.chevron_right), findsNothing);
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
}

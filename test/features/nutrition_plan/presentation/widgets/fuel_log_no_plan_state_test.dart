import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/fuel_log/fuel_log_no_plan_state.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

Activity _activity({
  String? syncedFromProvider,
  String? garminSummaryId,
  String? garminDeviceName,
}) {
  return Activity(
    id: 'act-1',
    userId: 'user-1',
    activityType: ActivityType.running,
    title: 'Garmin running',
    scheduledDateTime: DateTime(2026, 5, 6, 7, 30),
    status: ActivityStatus.completed,
    syncedFromProvider: syncedFromProvider,
    garminSummaryId: garminSummaryId,
    garminDeviceName: garminDeviceName,
    createdAt: DateTime(2026, 5, 6, 7, 30),
    updatedAt: DateTime(2026, 5, 6, 7, 30),
  );
}

void main() {
  group('FuelLogNoPlanState', () {
    testWidgets('renders Garmin-specific copy + Garmin attribution when '
        'activity has Garmin data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FuelLogNoPlanState(
              activity: _activity(
                syncedFromProvider: 'garmin',
                garminSummaryId: 'garmin-sum-1',
                garminDeviceName: 'Forerunner 965',
              ),
              onGeneratePlan: () {},
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('No fueling plan for this workout'), findsOneWidget);
      expect(
        find.textContaining('came in from Garmin'),
        findsOneWidget,
      );
      // Brand-compliant attribution must surface "Garmin" with the device.
      expect(find.textContaining('Garmin'), findsWidgets);
    });

    testWidgets('renders neutral copy when activity has no Garmin data',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FuelLogNoPlanState(
              activity: _activity(),
              onGeneratePlan: () {},
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('No fueling plan for this workout'), findsOneWidget);
      expect(
        find.textContaining('There is no nutrition plan attached'),
        findsOneWidget,
      );
      // No Garmin badge for non-Garmin activities.
      expect(find.textContaining('Garmin'), findsNothing);
    });

    testWidgets('Generate fueling plan button invokes onGeneratePlan',
        (tester) async {
      var generated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FuelLogNoPlanState(
              activity: _activity(syncedFromProvider: 'garmin'),
              onGeneratePlan: () => generated = true,
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Generate fueling plan'));
      await tester.pumpAndSettle();

      expect(generated, isTrue);
    });

    testWidgets('Close button invokes onClose', (tester) async {
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FuelLogNoPlanState(
              activity: _activity(syncedFromProvider: 'garmin'),
              onGeneratePlan: () {},
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });
  });
}

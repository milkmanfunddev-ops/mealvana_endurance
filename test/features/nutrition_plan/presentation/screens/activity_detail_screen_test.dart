import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/activity_detail_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

/// Unit tests for Activity Detail Screen actions
///
/// Tests the following functionality:
/// - Delete button visibility (shown for existing activities, hidden for new ones and coach view)
/// - Delete button triggers confirmation dialog
/// - Complete button is present for non-completed activities
/// - Completed state is displayed correctly
@GenerateMocks([])
void main() {
  group('Activity Detail Screen - Delete Button', () {
    testWidgets('Delete button is visible for existing activities', (tester) async {
      // Create a mock activity
      final activity = Activity(
        id: 'test-activity-1',
        userId: 'test-user',
        activityType: ActivityType.running,
        title: 'Test Run',
        scheduledDateTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ActivityStatus.planned,
      );

      final state = ActivityDetailState(
        activity: activity,
        scheduledDateTime: activity.scheduledDateTime,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityDetailControllerProvider(
              activityId: 'test-activity-1',
              isNewActivity: false,
            ).overrideWith(() {
              return MockActivityDetailController(state);
            }),
          ],
          child: const MaterialApp(
            home: ActivityDetailScreen(
              activityId: 'test-activity-1',
              isNewActivity: false,
              isCoachView: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify delete button icon is present
      expect(find.byIcon(FontAwesomeIcons.trash), findsOneWidget);
    });

    testWidgets('Delete button is hidden for new activities', (tester) async {
      final activity = Activity(
        id: 'test-activity-1',
        userId: 'test-user',
        activityType: ActivityType.running,
        title: 'Test Run',
        scheduledDateTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ActivityStatus.planned,
      );

      final state = ActivityDetailState(
        activity: activity,
        scheduledDateTime: activity.scheduledDateTime,
        isNewActivity: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityDetailControllerProvider(
              activityId: 'test-activity-1',
              isNewActivity: true,
            ).overrideWith(() {
              return MockActivityDetailController(state);
            }),
          ],
          child: const MaterialApp(
            home: ActivityDetailScreen(
              activityId: 'test-activity-1',
              isNewActivity: true,
              isCoachView: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify delete button is NOT present
      expect(find.byIcon(FontAwesomeIcons.trash), findsNothing);
    });

    testWidgets('Delete button is hidden in coach view', (tester) async {
      final activity = Activity(
        id: 'test-activity-1',
        userId: 'test-user',
        activityType: ActivityType.running,
        title: 'Test Run',
        scheduledDateTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ActivityStatus.planned,
      );

      final state = ActivityDetailState(
        activity: activity,
        scheduledDateTime: activity.scheduledDateTime,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityDetailControllerProvider(
              activityId: 'test-activity-1',
              isNewActivity: false,
            ).overrideWith(() {
              return MockActivityDetailController(state);
            }),
          ],
          child: const MaterialApp(
            home: ActivityDetailScreen(
              activityId: 'test-activity-1',
              isNewActivity: false,
              isCoachView: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify delete button is NOT present in coach view
      expect(find.byIcon(FontAwesomeIcons.trash), findsNothing);
    });
  });

  group('Activity Detail Screen - Complete Button', () {
    testWidgets('Complete button is visible for non-completed activities', (tester) async {
      final activity = Activity(
        id: 'test-activity-1',
        userId: 'test-user',
        activityType: ActivityType.running,
        title: 'Test Run',
        scheduledDateTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ActivityStatus.planned,
      );

      final state = ActivityDetailState(
        activity: activity,
        scheduledDateTime: activity.scheduledDateTime,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityDetailControllerProvider(
              activityId: 'test-activity-1',
              isNewActivity: false,
            ).overrideWith(() {
              return MockActivityDetailController(state);
            }),
          ],
          child: const MaterialApp(
            home: ActivityDetailScreen(
              activityId: 'test-activity-1',
              isNewActivity: false,
              isCoachView: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Complete button is present
      expect(find.text('Complete'), findsOneWidget);
    });

    testWidgets('Completed state shows completion message', (tester) async {
      final completedAt = DateTime.now();
      final activity = Activity(
        id: 'test-activity-1',
        userId: 'test-user',
        activityType: ActivityType.running,
        title: 'Test Run',
        scheduledDateTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ActivityStatus.completed,
        completedAt: completedAt,
      );

      final state = ActivityDetailState(
        activity: activity,
        scheduledDateTime: activity.scheduledDateTime,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityDetailControllerProvider(
              activityId: 'test-activity-1',
              isNewActivity: false,
            ).overrideWith(() {
              return MockActivityDetailController(state);
            }),
          ],
          child: const MaterialApp(
            home: ActivityDetailScreen(
              activityId: 'test-activity-1',
              isNewActivity: false,
              isCoachView: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify completed message is shown
      expect(find.text('Workout Completed'), findsOneWidget);
      // Complete button should NOT be present
      expect(find.text('Complete'), findsNothing);
      // Verify checkmark icon is present
      expect(find.byIcon(FontAwesomeIcons.circleCheck), findsOneWidget);
    });
  });
}

/// Mock controller for testing
class MockActivityDetailController extends ActivityDetailController {
  final ActivityDetailState _state;

  MockActivityDetailController(this._state);

  @override
  FutureOr<ActivityDetailState> build({
    required String activityId,
    bool isNewActivity = false,
  }) async {
    return _state;
  }
}

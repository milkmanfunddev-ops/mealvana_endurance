import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/activity_detail_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/activity_completion.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_activity_detail_controller.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

/// Unit tests for Activity Detail Screen actions
///
/// Tests the following functionality:
/// - Delete button visibility (shown for existing activities and coach view, hidden for new ones)
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

      // Verify delete button icon is present.
      // font_awesome_flutter v11 wraps IconData in FaIconData; FaIcon.icon
      // exposes the underlying IconData via .data, so find.byIcon requires .data.
      expect(find.byIcon(FontAwesomeIcons.trash.data), findsOneWidget);
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

      // Verify delete button is NOT present for new activities
      expect(find.byIcon(FontAwesomeIcons.trash.data), findsNothing);
    });

    testWidgets('Delete button is visible in coach view', (tester) async {
      // The production AppBar shows delete for all existing activities,
      // including in coach view (see comment "including coach view" in AppBar).
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

      final activityDetailState = ActivityDetailState(
        activity: activity,
        scheduledDateTime: activity.scheduledDateTime,
      );
      final coachState = CoachActivityDetailState(
        activity: activity,
        scheduledDateTime: activity.scheduledDateTime,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coachActivityDetailControllerProvider(
              'test-activity-1',
            ).overrideWith(() {
              return MockCoachActivityDetailController(coachState);
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

      // Delete button is present in coach view (production AppBar shows it for
      // all existing activities regardless of coach/athlete mode).
      expect(find.byIcon(FontAwesomeIcons.trash.data), findsOneWidget);
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

      // ActivityDetailState.isCompleted is true when completion != null.
      // A completion object must be provided to trigger the completed UI.
      final completion = ActivityCompletion(
        id: 1,
        activityId: 1,
        userId: 'test-user',
        completedAt: completedAt,
      );

      final state = ActivityDetailState(
        activity: activity,
        completion: completion,
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
      // Verify checkmark icon is present (FaIcon.icon returns .data; use .data for find.byIcon)
      expect(find.byIcon(FontAwesomeIcons.circleCheck.data), findsOneWidget);
    });
  });
}

/// Mock controller for the regular (athlete) activity detail path
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

/// Mock controller for the coach-view path
class MockCoachActivityDetailController extends CoachActivityDetailController {
  final CoachActivityDetailState _state;

  MockCoachActivityDetailController(this._state);

  @override
  FutureOr<CoachActivityDetailState> build(String activityId) async {
    return _state;
  }
}

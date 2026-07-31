import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/activity_completion.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/activity_completed_badge.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/activity_detail_action_buttons.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Functional tests for [ActivityDetailActionButtons].
///
/// The widget switches its rendered content based on the supplied
/// [ActivityDetailState]:
///   * completed activity  -> rich [ActivityCompletedCard]
///   * coach view          -> single Save button
///   * default (planned)   -> Save + Complete buttons
///
/// These tests exercise that real branching behavior and the data the
/// completed card surfaces (rating stars, carb-feedback label, notes).
void main() {
  Activity buildActivity({
    required int durationMinutes,
    int? completionRating,
    String? completionNotes,
    int? nutritionRating,
    bool completed = true,
  }) {
    return Activity(
      id: 'a1',
      userId: 'u1',
      activityType: ActivityType.running,
      title: 'Long Run',
      scheduledDateTime: DateTime(2026, 3, 20, 7),
      status: completed ? ActivityStatus.completed : ActivityStatus.planned,
      durationMinutes: durationMinutes,
      completionRating: completionRating,
      completionNotes: completionNotes,
      nutritionRating: nutritionRating,
      completedAt: completed ? DateTime(2026, 3, 20, 9) : null,
      createdAt: DateTime(2026, 3, 19),
      updatedAt: DateTime(2026, 3, 20),
    );
  }

  NutritionPlan buildPlan() {
    return const NutritionPlan(
      id: 'p1',
      name: 'Plan',
      sections: [
        PlanSection(
          id: 'during_run',
          title: 'During Run',
          foodItems: [],
          carbsTarget: 100,
        ),
      ],
    );
  }

  ActivityDetailState buildCompletedState({
    required int durationMinutes,
    int? completionRating = 4,
    String? completionNotes = 'Felt strong on the back half',
    int? nutritionRating = 4,
  }) {
    final activity = buildActivity(
      durationMinutes: durationMinutes,
      completionRating: completionRating,
      completionNotes: completionNotes,
      nutritionRating: nutritionRating,
    );

    final completion = ActivityCompletion(
      id: 1,
      activityId: 1,
      userId: 'u1',
      completedAt: DateTime(2026, 3, 20, 9),
      overallSatisfaction: completionRating,
      textNotes: completionNotes,
    );

    return ActivityDetailState(
      activity: activity,
      completion: completion,
      nutritionPlan: buildPlan(),
      scheduledDateTime: activity.scheduledDateTime,
    );
  }

  Widget wrap(ActivityDetailState state, {bool isCoachView = false}) {
    return MaterialApp(
      home: Scaffold(
        body: ActivityDetailActionButtons(
          state: state,
          isNewActivity: false,
          isCoachView: isCoachView,
          onSave: () {},
          onComplete: (_, __, {isBrick = false, carbAdjustment}) {},
          onRatingChanged: (_) {},
          onNotesChanged: (_) {},
        ),
      ),
    );
  }

  group('ActivityDetailActionButtons - completed state', () {
    testWidgets('renders the completed card with rating, carbs and notes', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildCompletedState(durationMinutes: 120)));

      // Completed activities render the rich completed card.
      expect(find.byType(ActivityCompletedCard), findsOneWidget);
      expect(find.text('Workout Completed'), findsOneWidget);

      // nutritionRating 4 maps to CarbAdjustmentLevel.more -> "Needed More".
      expect(find.textContaining('Needed More'), findsOneWidget);

      // Notes are surfaced.
      expect(find.text('Felt strong on the back half'), findsOneWidget);
    });

    testWidgets('hides the carb feedback row when no carb rating exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(buildCompletedState(durationMinutes: 80, nutritionRating: null)),
      );

      expect(find.byType(ActivityCompletedCard), findsOneWidget);
      // No carb adjustment -> the "Carbs" feedback row is not built.
      expect(find.text('Carbs'), findsNothing);
      expect(find.textContaining('Needed More'), findsNothing);
    });

    testWidgets('omits the notes section when there are no notes', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(buildCompletedState(durationMinutes: 120, completionNotes: null)),
      );

      expect(find.byType(ActivityCompletedCard), findsOneWidget);
      // Rating row still renders even without notes.
      expect(find.text('Rating'), findsOneWidget);
    });
  });

  group('ActivityDetailActionButtons - actionable state', () {
    testWidgets('shows Save and Complete buttons for a planned activity', (
      tester,
    ) async {
      final state = ActivityDetailState(
        activity: buildActivity(durationMinutes: 120, completed: false),
        // No completion -> not completed -> action buttons rendered.
        scheduledDateTime: DateTime(2026, 3, 20, 7),
      );

      await tester.pumpWidget(wrap(state));

      expect(find.byType(ActivityCompletedCard), findsNothing);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);
    });

    testWidgets('coach view shows only a Save button', (tester) async {
      final state = ActivityDetailState(
        activity: buildActivity(durationMinutes: 120, completed: false),
        scheduledDateTime: DateTime(2026, 3, 20, 7),
      );

      await tester.pumpWidget(wrap(state, isCoachView: true));

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Complete'), findsNothing);
    });
  });
}

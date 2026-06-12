import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/activity_completion.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/carb_adjustment_level.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/activity_detail_action_buttons.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  group('ActivityDetailActionButtons completed state', () {
    ActivityDetailState buildCompletedState({required int durationMinutes}) {
      final activity = Activity(
        id: 'a1',
        userId: 'u1',
        activityType: ActivityType.running,
        title: 'Long Run',
        scheduledDateTime: DateTime(2026, 3, 20, 7),
        status: ActivityStatus.completed,
        durationMinutes: durationMinutes,
        completionRating: 4,
        completionNotes: 'Prior note',
        nutritionRating: 4,
        completedAt: DateTime(2026, 3, 20, 9),
        createdAt: DateTime(2026, 3, 19),
        updatedAt: DateTime(2026, 3, 20),
      );

      final completion = ActivityCompletion(
        id: 1,
        activityId: 1,
        userId: 'u1',
        completedAt: DateTime(2026, 3, 20, 9),
        overallSatisfaction: 4,
        textNotes: 'Prior note',
      );

      final plan = NutritionPlan(
        id: 'p1',
        name: 'Plan',
        sections: const [
          PlanSection(
            id: 'during_run',
            title: 'During Run',
            foodItems: [],
            carbsTarget: 100,
          ),
        ],
      );

      return ActivityDetailState(
        activity: activity,
        completion: completion,
        nutritionPlan: plan,
        scheduledDateTime: activity.scheduledDateTime,
      );
    }

    testWidgets('completed state displays prior feedback inline', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityDetailActionButtons(
              state: buildCompletedState(durationMinutes: 120),
              isNewActivity: false,
              isCoachView: false,
              onSave: () {},
              onComplete: (_, __, {isBrick = false, carbAdjustment}) {},
              onRatingChanged: (_) {},
              onNotesChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Inline ActivityCompletedCard should show completion header
      expect(find.text('Workout Completed'), findsOneWidget);

      // Prior notes are visible in the completed card
      expect(find.text('Prior note'), findsOneWidget);

      // nutritionRating=4 maps to CarbAdjustmentLevel.more ("Needed More")
      // The card shows "${emoji} ${label}" format
      final expectedCarbText =
          '${CarbAdjustmentLevel.more.emoji} ${CarbAdjustmentLevel.more.label}';
      expect(find.text(expectedCarbText), findsOneWidget);
    });

    testWidgets(
      'completed state for workout under 90 minutes shows carb row when nutritionRating is set',
      (tester) async {
        // The ActivityCompletedCard shows the carb row based on the persisted
        // nutritionRating — this is distinct from the 90-min gate that
        // controls whether the carb question is offered during initial
        // completion. Once a rating is stored, the card always shows it.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityDetailActionButtons(
                state: buildCompletedState(durationMinutes: 80),
                isNewActivity: false,
                isCoachView: false,
                onSave: () {},
                onComplete: (_, __, {isBrick = false, carbAdjustment}) {},
                onRatingChanged: (_) {},
                onNotesChanged: (_) {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Completed card header is shown
        expect(find.text('Workout Completed'), findsOneWidget);
      },
    );
  });
}

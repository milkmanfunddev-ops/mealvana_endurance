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
  group('ActivityDetailActionButtons feedback edit', () {
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

    testWidgets('reopens edit dialog prefilled with prior feedback', (
      tester,
    ) async {
      CarbAdjustmentLevel? editedCarb;
      int? editedRating;
      String? editedNotes;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityDetailActionButtons(
              state: buildCompletedState(durationMinutes: 120),
              isNewActivity: false,
              isCoachView: false,
              onSave: () {},
              onComplete: (_, __, {isBrick = false, carbAdjustment}) {},
              onEditFeedback: (rating, notes, carbAdjustment) {
                editedRating = rating;
                editedNotes = notes;
                editedCarb = carbAdjustment;
              },
              onRatingChanged: (_) {},
              onNotesChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Edit feedback'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Workout Feedback'), findsOneWidget);
      expect(find.text('Prior note'), findsWidgets);
      expect(find.text('Needed More'), findsOneWidget);
      expect(find.text('You consumed ~50g/hr'), findsOneWidget);
      expect(editedRating, isNull);
      expect(editedNotes, isNull);
      expect(editedCarb, isNull);
    });

    testWidgets('hides carb section for workouts under 90 minutes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityDetailActionButtons(
              state: buildCompletedState(durationMinutes: 80),
              isNewActivity: false,
              isCoachView: false,
              onSave: () {},
              onComplete: (_, __, {isBrick = false, carbAdjustment}) {},
              onEditFeedback: (_, __, ___) {},
              onRatingChanged: (_) {},
              onNotesChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Edit feedback'));
      await tester.pumpAndSettle();

      expect(find.text('How did the carbs feel?'), findsNothing);
    });
  });
}

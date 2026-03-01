import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/time_slot_assignment.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/hour_bucket_widget.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

void main() {
  group('HourBucketWidget', () {
    testWidgets(
      'renders sip-throughout items in dedicated section when expanded',
      (tester) async {
        final drink = FoodItemData(
          id: 'drink-1',
          name: 'Sports Drink',
          quantity: '2 bottles',
          isDrink: true,
          timingCategory: TimingCategory.sipThroughout,
          nutritionalInfo: const NutritionalInfo(
            calories: 80,
            carbs: 20,
            sodium: 300,
            fluids: 500,
          ),
        );

        final gel = FoodItemData(
          id: 'gel-1',
          name: 'Energy Gel',
          quantity: '1 gel',
          timingCategory: TimingCategory.quickConsume,
          nutritionalInfo: const NutritionalInfo(
            calories: 100,
            carbs: 25,
            sodium: 100,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HourBucketWidget(
                hourIndex: 0,
                slotCount: 4,
                assignments: const [
                  TimeSlotAssignment(
                    foodItemId: 'drink-1',
                    timeSlot: TimeSlot(hourIndex: 0, slotIndex: 0),
                    isSipThroughout: true,
                    adjustedQuantity: 1.0,
                    timingCategory: TimingCategory.sipThroughout,
                  ),
                  TimeSlotAssignment(
                    foodItemId: 'gel-1',
                    timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
                    adjustedQuantity: 1.0,
                    timingCategory: TimingCategory.quickConsume,
                  ),
                ],
                foodMap: {drink.id: drink, gel.id: gel},
                sectionColor: AppColors.orange,
                category: 'during_run',
                useImperial: true,
                activityType: ActivityType.running,
                onSwapFood: (_, __, ___) {},
                onDeleteFood: (_, __) {},
                onUpdateQuantity: (_, __, ___) {},
                onAddFood: (_, __) {},
                onMoveFoodToTimeSlot: (_, __, ___, ____) {},
              ),
            ),
          ),
        );

        // Expand hour bucket
        await tester.tap(find.text('Hour 1'));
        await tester.pumpAndSettle();

        expect(find.text('Sip Throughout'), findsOneWidget);
        expect(
          find.text('Not tied to a specific minute mark.'),
          findsOneWidget,
        );
        expect(find.text('Sports Drink'), findsOneWidget);
        expect(find.text('Energy Gel'), findsOneWidget);
        expect(find.text('Sip throughout hour'), findsNothing);
      },
    );

    testWidgets(
      'uses timingCategory sipThroughout as backward-compatible signal',
      (tester) async {
        final drink = FoodItemData(
          id: 'drink-legacy',
          name: 'Hydration Mix',
          quantity: '1 bottle',
          isDrink: true,
          timingCategory: TimingCategory.sipThroughout,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HourBucketWidget(
                hourIndex: 0,
                slotCount: 4,
                assignments: const [
                  TimeSlotAssignment(
                    foodItemId: 'drink-legacy',
                    timeSlot: TimeSlot(hourIndex: 0, slotIndex: 0),
                    // Legacy case: isSipThroughout is false
                    isSipThroughout: false,
                    timingCategory: TimingCategory.sipThroughout,
                  ),
                ],
                foodMap: {drink.id: drink},
                sectionColor: AppColors.orange,
                category: 'during_run',
                useImperial: true,
                activityType: ActivityType.running,
                onSwapFood: (_, __, ___) {},
                onDeleteFood: (_, __) {},
                onUpdateQuantity: (_, __, ___) {},
                onAddFood: (_, __) {},
                onMoveFoodToTimeSlot: (_, __, ___, ____) {},
              ),
            ),
          ),
        );

        await tester.tap(find.text('Hour 1'));
        await tester.pumpAndSettle();

        expect(find.text('Sip Throughout'), findsOneWidget);
        expect(find.text('Hydration Mix'), findsOneWidget);
      },
    );
  });
}

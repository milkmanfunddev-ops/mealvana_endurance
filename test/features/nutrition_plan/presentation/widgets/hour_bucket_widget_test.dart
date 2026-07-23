import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/time_slot_assignment.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/hour_bucket_widget.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/time_slot_row.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

void main() {
  group('HourBucketWidget', () {
    testWidgets(
      'places sip-throughout and quick-consume items inline in the timeline '
      'when expanded',
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
                onMoveFoodToTimeSlot: (_, __, ___, ____) {},
              ),
            ),
          ),
        );

        // Collapsed by default: timeline slots are not shown yet.
        expect(find.byType(TimeSlotRow), findsNothing);

        // Expand hour bucket.
        await tester.tap(find.text('Hour 1'));
        await tester.pumpAndSettle();

        // Sip-throughout is now global, not a dedicated per-hour section.
        expect(find.text('Sip Throughout'), findsNothing);
        expect(find.text('Not tied to a specific minute mark.'), findsNothing);

        // Instead, every slot of the hour renders as a TimeSlotRow and the
        // assignments are placed inline at their slot times (:00 and :15).
        expect(find.byType(TimeSlotRow), findsNWidgets(4));
        expect(find.text('0:00'), findsOneWidget);
        expect(find.text('0:15'), findsOneWidget);

        // The sip-throughout drink (slot :00) and the quick-consume gel
        // (slot :15) both surface their quantity and carbs inline.
        expect(find.text('1 bottles'), findsOneWidget);
        expect(find.text('1 gel'), findsOneWidget);
        expect(find.text('10g'), findsOneWidget); // drink carbs (scaled)
        expect(find.text('25g'), findsOneWidget); // gel carbs
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
                onMoveFoodToTimeSlot: (_, __, ___, ____) {},
              ),
            ),
          ),
        );

        await tester.tap(find.text('Hour 1'));
        await tester.pumpAndSettle();

        // Even though the assignment carries the legacy sipThroughout timing
        // category, there is no dedicated "Sip Throughout" section anymore...
        expect(find.text('Sip Throughout'), findsNothing);

        // ...the item is still placed inline at its slot (:00) in the timeline.
        expect(find.byType(TimeSlotRow), findsNWidgets(4));
        expect(find.text('0:00'), findsOneWidget);
        expect(find.text('1 bottle'), findsOneWidget);
      },
    );
  });
}

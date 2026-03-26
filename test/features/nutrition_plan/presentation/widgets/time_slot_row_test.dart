import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/time_slot_assignment.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/time_slot_row.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

void main() {
  group('TimeSlotRow tap-to-place', () {
    testWidgets('places selected tray food when tapping an occupied slot', (
      tester,
    ) async {
      final occupiedFood = FoodItemData(
        id: 'occupied-food',
        name: 'Existing Gel',
        quantity: '1 gel',
        isIndivisible: true,
        timingCategory: TimingCategory.quickConsume,
      );
      final trayFood = FoodItemData(
        id: 'tray-food',
        name: 'Dates',
        quantity: '2 servings',
        isIndivisible: false,
      );

      String? placedFoodId;
      TimeSlot? placedSlot;
      double? placedQuantity;
      TimingCategory? placedTimingCategory;
      bool? placedIsSipThroughout;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeSlotRow(
              timeSlot: const TimeSlot(hourIndex: 0, slotIndex: 1),
              assignments: const [
                TimeSlotAssignment(
                  foodItemId: 'occupied-food',
                  timeSlot: TimeSlot(hourIndex: 0, slotIndex: 1),
                  adjustedQuantity: 1.0,
                  timingCategory: TimingCategory.quickConsume,
                ),
              ],
              foodMap: {'occupied-food': occupiedFood, 'tray-food': trayFood},
              sectionColor: AppColors.orange,
              category: 'during_run',
              useImperial: true,
              isLastInHour: false,
              onSwapFood: (_, __, ___) {},
              onDeleteFood: (_, __) {},
              onUpdateQuantity: (_, __, ___) {},
              onMoveFoodToTimeSlot: (_, __, ___, ____) {},
              selectedFoodId: 'tray-food',
              onPlaceFromTray:
                  (foodId, slot, qty, timingCategory, isSipThroughout) {
                    placedFoodId = foodId;
                    placedSlot = slot;
                    placedQuantity = qty;
                    placedTimingCategory = timingCategory;
                    placedIsSipThroughout = isSipThroughout;
                  },
            ),
          ),
        ),
      );

      await tester.tap(find.text('0:15'));
      await tester.pumpAndSettle();

      expect(placedFoodId, 'tray-food');
      expect(placedSlot, const TimeSlot(hourIndex: 0, slotIndex: 1));
      expect(placedQuantity, 0.5);
      expect(placedTimingCategory, TimingCategory.slowConsume);
      expect(placedIsSipThroughout, false);
    });
  });
}

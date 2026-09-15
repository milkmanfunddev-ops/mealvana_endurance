// Xuan/Claudia (2026-08-31): the carbs badge on a Sip Throughout row kept its
// original value when the row's quantity changed (3 cups 52g → 2.5 cups still
// 52g). Root cause: sip rows handed PlacedSlotFoodWidget the RAW food while the
// badge read the food's base carbs. Fix: the widget scales carbs off its own
// slot quantity, so the badge reflects the row's actual quantity — and a sip
// row and a time-slot row at equal quantity now render the same badge.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/time_slot_assignment.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/placed_slot_food_widget.dart';

void main() {
  FoodItemData drink() => const FoodItemData(
    id: 'sd',
    name: 'Sports Drink',
    quantity: '3 cups',
    nutritionalInfo: NutritionalInfo(carbs: 52),
  );

  Future<void> pump(
    WidgetTester tester, {
    double? adjustedQuantity,
    bool sip = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacedSlotFoodWidget(
            food: drink(),
            assignment: TimeSlotAssignment(
              foodItemId: 'sd',
              timeSlot: const TimeSlot(hourIndex: 0, slotIndex: 0),
              isSipThroughout: sip,
              adjustedQuantity: adjustedQuantity,
            ),
            sectionColor: Colors.teal,
            onAdjustQuantity: (_) {},
            onUnassign: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('badge scales with the slot quantity', (tester) async {
    // 52g at 3 cups → 2.5 cups is 52 * 2.5/3 = 43.3 → 43g.
    await pump(tester, adjustedQuantity: 2.5);
    expect(find.text('43g'), findsOneWidget);
    expect(find.text('52g'), findsNothing);
  });

  testWidgets('unadjusted slot shows the base carbs', (tester) async {
    await pump(tester, adjustedQuantity: null);
    expect(find.text('52g'), findsOneWidget);
  });

  testWidgets(
    'a sip row and a time-slot row at equal qty render the same badge',
    (tester) async {
      await pump(tester, adjustedQuantity: 2.5, sip: true);
      expect(find.text('43g'), findsOneWidget);
      await pump(tester, adjustedQuantity: 2.5, sip: false);
      expect(find.text('43g'), findsOneWidget);
    },
  );
}

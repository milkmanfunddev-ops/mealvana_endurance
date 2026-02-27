import 'package:flutter/material.dart';
import '../../../domain/nutrition_plan.dart';
import '../../../domain/time_slot_assignment.dart';
import 'hour_bucket_widget.dart';

/// Renders a column of hour buckets for the By Hour view.
///
/// Each bucket represents one hour of the activity, showing the food items
/// assigned to that hour's 15-minute time slots.
class ByHourView extends StatelessWidget {
  const ByHourView({
    super.key,
    required this.section,
    required this.byHourData,
    required this.sectionColor,
    required this.category,
    required this.useImperial,
    required this.onSwapFood,
    required this.onDeleteFood,
    required this.onUpdateQuantity,
    required this.onAddFood,
    required this.onMoveFoodToTimeSlot,
  });

  final PlanSection section;
  final ByHourData byHourData;
  final Color sectionColor;
  final String category;
  final bool useImperial;
  final void Function(String foodId, String foodName, String category) onSwapFood;
  final void Function(String foodId, String category) onDeleteFood;
  final void Function(String foodId, String category, double newQuantity)
      onUpdateQuantity;
  final void Function(String category) onAddFood;
  final void Function(String foodId, String category, TimeSlot newTimeSlot)
      onMoveFoodToTimeSlot;

  @override
  Widget build(BuildContext context) {
    final totalHours = byHourData.totalHours;

    // Build a map of foodItemId -> FoodItemData for quick lookup
    final foodMap = {
      for (final food in section.foodItems) food.id: food,
    };

    return Column(
      children: List.generate(totalHours, (hourIndex) {
        final assignments = byHourData.assignmentsForHour(hourIndex);
        final slotCount = byHourData.slotCountForHour(hourIndex);

        return HourBucketWidget(
          hourIndex: hourIndex,
          slotCount: slotCount,
          assignments: assignments,
          foodMap: foodMap,
          sectionColor: sectionColor,
          category: category,
          useImperial: useImperial,
          onSwapFood: onSwapFood,
          onDeleteFood: onDeleteFood,
          onUpdateQuantity: onUpdateQuantity,
          onAddFood: onAddFood,
          onMoveFoodToTimeSlot: onMoveFoodToTimeSlot,
        );
      }),
    );
  }
}

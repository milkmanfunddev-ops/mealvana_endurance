import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/time_slot_assignment.dart';
import 'placed_slot_food_widget.dart';

/// Global "Sip Throughout" section displayed above all hour buckets.
///
/// Shows drinks and electrolytes that apply across the entire activity duration.
/// Items stored with hourIndex == -1 in the ByHourData assignments.
/// Uses PlacedSlotFoodWidget for inline qty adjustment and unassign actions.
class GlobalSipSectionWidget extends StatelessWidget {
  const GlobalSipSectionWidget({
    super.key,
    required this.sipAssignments,
    required this.foodMap,
    required this.sectionColor,
    required this.onAdjustSlotQuantity,
    required this.onUnassignFood,
  });

  final List<TimeSlotAssignment> sipAssignments;
  final Map<String, FoodItemData> foodMap;
  final Color sectionColor;

  /// Called to adjust a sip item's quantity by delta.
  final void Function(String foodId, TimeSlot slot, double delta) onAdjustSlotQuantity;

  /// Called to unassign a food from the global sip section.
  final void Function(String foodId, TimeSlot slot) onUnassignFood;

  @override
  Widget build(BuildContext context) {
    if (sipAssignments.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.smRadius,
        color: sectionColor.withValues(alpha: 0.04),
        border: Border.all(
          color: sectionColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.water_drop,
                  size: 16,
                  color: sectionColor,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'SIP THROUGHOUT',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: sectionColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          // Sip items
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Column(
              children: sipAssignments.map((assignment) {
                final food = foodMap[assignment.foodItemId];
                if (food == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: PlacedSlotFoodWidget(
                    food: food,
                    assignment: assignment,
                    sectionColor: sectionColor,
                    onAdjustQuantity: (delta) {
                      onAdjustSlotQuantity(
                        assignment.foodItemId,
                        assignment.timeSlot,
                        delta,
                      );
                    },
                    onUnassign: () {
                      onUnassignFood(
                        assignment.foodItemId,
                        assignment.timeSlot,
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          // Hint text
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Text(
              'Drag to a specific hour for precise timing',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.5),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

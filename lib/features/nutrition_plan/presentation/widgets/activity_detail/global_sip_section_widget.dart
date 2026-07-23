import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../application/by_hour_apportionment_service.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/time_slot_assignment.dart';
import '../../../domain/unassigned_tray_item.dart';
import 'placed_slot_food_widget.dart';

/// Global "Sip Throughout" section displayed above all hour buckets.
///
/// Shows drinks and electrolytes that apply across the entire activity duration.
/// Items stored with hourIndex == -1 in the ByHourData assignments.
/// Supports drag-to-hour and tap-to-select-then-place interactions.
class GlobalSipSectionWidget extends StatelessWidget {
  const GlobalSipSectionWidget({
    super.key,
    required this.sipAssignments,
    required this.foodMap,
    required this.sectionColor,
    required this.onAdjustSlotQuantity,
    required this.onUnassignFood,
    this.selectedFoodId,
    this.onSelectFood,
  });

  final List<TimeSlotAssignment> sipAssignments;
  final Map<String, FoodItemData> foodMap;
  final Color sectionColor;

  /// Called to adjust a sip item's quantity by delta.
  final void Function(String foodId, TimeSlot slot, double delta)
  onAdjustSlotQuantity;

  /// Called to unassign a food from the global sip section.
  final void Function(String foodId, TimeSlot slot) onUnassignFood;

  /// Currently selected sip food ID for tap-to-place mode.
  final String? selectedFoodId;

  /// Called when a sip food is tapped to select/deselect.
  final void Function(String? foodId)? onSelectFood;

  @override
  Widget build(BuildContext context) {
    if (sipAssignments.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.smRadius,
        color: sectionColor.withValues(alpha: 0.04),
        border: Border.all(color: sectionColor.withValues(alpha: 0.2)),
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
                Icon(Icons.water_drop, size: 16, color: sectionColor),
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

                final isSelected = selectedFoodId == assignment.foodItemId;
                final stepSize = food.isIndivisible ? 1.0 : 0.5;
                final timingCategory =
                    ByHourApportionmentService.resolveTimingCategory(food);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: LongPressDraggable<TrayDragData>(
                    data: TrayDragData(
                      foodId: assignment.foodItemId,
                      food: food,
                      quantity: stepSize,
                      timingCategory: timingCategory,
                    ),
                    delay: const Duration(milliseconds: 300),
                    hapticFeedbackOnStart: true,
                    feedback: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: sectionColor),
                        ),
                        child: Text(
                          _dragLabel(food, stepSize),
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    child: GestureDetector(
                      onTap: onSelectFood != null
                          ? () => onSelectFood!(
                              isSelected ? null : assignment.foodItemId,
                            )
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: isSelected
                            ? BoxDecoration(
                                color: sectionColor.withValues(alpha: 0.12),
                                borderRadius: AppRadius.smRadius,
                                border: Border.all(
                                  color: sectionColor.withValues(alpha: 0.4),
                                ),
                              )
                            : null,
                        child: Row(
                          children: [
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.xs,
                                ),
                                child: Icon(
                                  Icons.touch_app,
                                  size: 14,
                                  color: sectionColor,
                                ),
                              ),
                            Expanded(
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
                            ),
                          ],
                        ),
                      ),
                    ),
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
              'Drag or tap to place in a specific hour',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dragLabel(FoodItemData food, double stepSize) {
    final qtyStr = stepSize == stepSize.roundToDouble()
        ? stepSize.round().toString()
        : stepSize.toStringAsFixed(1);
    return food.displayAtQuantity(qtyStr);
  }
}

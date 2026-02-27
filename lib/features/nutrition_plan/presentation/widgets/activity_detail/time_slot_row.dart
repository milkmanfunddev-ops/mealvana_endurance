import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/time_slot_assignment.dart';
import 'dismissible_food_item.dart';

/// A single time slot row in the By Hour timeline.
///
/// Shows: time label (e.g., "0:15") + dot + vertical line + food item(s).
/// Empty slots show just the time label and dot (with lighter styling).
/// Serves as a DragTarget for drag-and-drop reordering.
class TimeSlotRow extends StatelessWidget {
  const TimeSlotRow({
    super.key,
    required this.timeSlot,
    required this.assignments,
    required this.foodMap,
    required this.sectionColor,
    required this.category,
    required this.useImperial,
    required this.isLastInHour,
    required this.onSwapFood,
    required this.onDeleteFood,
    required this.onUpdateQuantity,
    required this.onMoveFoodToTimeSlot,
  });

  final TimeSlot timeSlot;
  final List<TimeSlotAssignment> assignments;
  final Map<String, FoodItemData> foodMap;
  final Color sectionColor;
  final String category;
  final bool useImperial;
  final bool isLastInHour;
  final void Function(String foodId, String foodName, String category) onSwapFood;
  final void Function(String foodId, String category) onDeleteFood;
  final void Function(String foodId, String category, double newQuantity)
      onUpdateQuantity;
  final void Function(String foodId, String category, TimeSlot newTimeSlot)
      onMoveFoodToTimeSlot;

  @override
  Widget build(BuildContext context) {
    final hasItems = assignments.isNotEmpty;
    final timeColor = hasItems
        ? sectionColor
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final dotColor = hasItems
        ? sectionColor
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);

    return DragTarget<TimeSlotAssignment>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final draggedAssignment = details.data;
        onMoveFoodToTimeSlot(
          draggedAssignment.foodItemId,
          category,
          timeSlot,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;

        return Container(
          decoration: isDropTarget
              ? BoxDecoration(
                  color: sectionColor.withValues(alpha: 0.08),
                  borderRadius: AppRadius.smRadius,
                )
              : null,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time label
                SizedBox(
                  width: 44,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      timeSlot.displayLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: timeColor,
                        fontSize: 13,
                        fontWeight:
                            hasItems ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                // Dot + vertical line
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                      ),
                      if (!isLastInHour)
                        Expanded(
                          child: Container(
                            width: 1,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.15),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                // Food items
                Expanded(
                  child: hasItems
                      ? _buildFoodItems(context)
                      : const SizedBox(height: 32),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFoodItems(BuildContext context) {
    return Column(
      children: assignments.map((assignment) {
        final food = foodMap[assignment.foodItemId];
        if (food == null) return const SizedBox.shrink();

        // If adjustedQuantity is set, create a display copy with scaled values
        final displayFood = _adjustFoodForDisplay(food, assignment);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: _buildDraggableFoodItem(context, assignment, displayFood),
        );
      }).toList(),
    );
  }

  /// Creates a display copy of FoodItemData with adjusted quantity and scaled nutrition.
  FoodItemData _adjustFoodForDisplay(FoodItemData food, TimeSlotAssignment assignment) {
    if (assignment.adjustedQuantity == null) return food;

    final originalQty = _parseQuantity(food);
    if (originalQty <= 0) return food;

    final adjustedQty = assignment.adjustedQuantity!;
    final scale = adjustedQty / originalQty;

    // Build adjusted quantity string
    final qtyStr = adjustedQty == adjustedQty.roundToDouble() && adjustedQty >= 1
        ? adjustedQty.toInt().toString()
        : adjustedQty.toStringAsFixed(1);

    // Extract the unit part from the original quantity string
    final unitMatch = RegExp(r'^[\d.]+\s*(.*)$').firstMatch(food.quantity);
    final unit = unitMatch?.group(1) ?? '';
    final adjustedQuantityStr = unit.isNotEmpty ? '$qtyStr $unit' : qtyStr;

    final ni = food.nutritionalInfo;
    return FoodItemData(
      id: food.id,
      name: food.name,
      quantity: adjustedQuantityStr,
      imageAddress: food.imageAddress,
      description: food.description,
      timing: food.timing,
      instructions: food.instructions,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      displayOverride: food.displayOverride,
      servingSize: food.servingSize,
      isDrink: food.isDrink,
      templateId: food.templateId,
      scaleMultiplier: food.scaleMultiplier,
      nutritionalInfo: ni != null
          ? NutritionalInfo(
              calories: ((ni.calories ?? 0) * scale).round(),
              carbs: ((ni.carbs ?? 0) * scale).round(),
              protein: ((ni.protein ?? 0) * scale).round(),
              fat: ((ni.fat ?? 0) * scale).round(),
              sodium: ((ni.sodium ?? 0) * scale).round(),
              fluids: (ni.fluids ?? 0) * scale,
            )
          : null,
    );
  }

  double _parseQuantity(FoodItemData food) {
    final match = RegExp(r'^([\d.]+)').firstMatch(food.quantity);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 1.0;
    }
    return 1.0;
  }

  Widget _buildDraggableFoodItem(
    BuildContext context,
    TimeSlotAssignment assignment,
    FoodItemData food,
  ) {
    final child = _TimeSlotFoodItem(
      food: food,
      assignment: assignment,
      category: category,
      sectionColor: sectionColor,
      useImperial: useImperial,
      onSwapFood: onSwapFood,
      onDeleteFood: onDeleteFood,
      onUpdateQuantity: onUpdateQuantity,
    );

    return LongPressDraggable<TimeSlotAssignment>(
      data: assignment,
      delay: const Duration(milliseconds: 300),
      hapticFeedbackOnStart: true,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: 0.85,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            child: child,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: child,
      ),
      child: Row(
        children: [
          // 6-dot drag handle
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Icon(
              Icons.drag_indicator,
              size: 16,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Individual food item within a time slot.
///
/// Shows the food with an optional "Sip throughout hour" subtitle for drinks.
/// Wraps DismissibleFoodItem for swipe-to-delete/swap functionality.
class _TimeSlotFoodItem extends StatelessWidget {
  const _TimeSlotFoodItem({
    required this.food,
    required this.assignment,
    required this.category,
    required this.sectionColor,
    required this.useImperial,
    required this.onSwapFood,
    required this.onDeleteFood,
    required this.onUpdateQuantity,
  });

  final FoodItemData food;
  final TimeSlotAssignment assignment;
  final String category;
  final Color sectionColor;
  final bool useImperial;
  final void Function(String foodId, String foodName, String category) onSwapFood;
  final void Function(String foodId, String category) onDeleteFood;
  final void Function(String foodId, String category, double newQuantity)
      onUpdateQuantity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DismissibleFoodItem(
          food: food,
          category: category,
          onSwap: () => onSwapFood(food.id, food.name, category),
          onDelete: () => onDeleteFood(food.id, category),
          onQuantityChange: (newQuantity) =>
              onUpdateQuantity(food.id, category, newQuantity),
          useImperial: useImperial,
        ),
        if (assignment.isSipThroughout) ...[
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm, top: 2),
            child: Text(
              'Sip throughout hour',
              style: AppTextStyles.bodySmall.copyWith(
                color: sectionColor.withValues(alpha: 0.7),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

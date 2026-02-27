import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/time_slot_assignment.dart';
import 'time_slot_row.dart';

/// Collapsible hour bucket showing time-slotted food items.
///
/// Collapsed view: "Hour 1  350 cal . 75g carbs . 400mg sodium" with chevron
/// Expanded view: Timeline of TimeSlotRows + "ADD TO HOUR X" button
class HourBucketWidget extends StatefulWidget {
  const HourBucketWidget({
    super.key,
    required this.hourIndex,
    required this.slotCount,
    required this.assignments,
    required this.foodMap,
    required this.sectionColor,
    required this.category,
    required this.useImperial,
    required this.onSwapFood,
    required this.onDeleteFood,
    required this.onUpdateQuantity,
    required this.onAddFood,
    required this.onMoveFoodToTimeSlot,
  });

  final int hourIndex;
  final int slotCount;
  final List<TimeSlotAssignment> assignments;
  final Map<String, FoodItemData> foodMap;
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
  State<HourBucketWidget> createState() => _HourBucketWidgetState();
}

class _HourBucketWidgetState extends State<HourBucketWidget> {
  bool _isExpanded = false;

  /// Calculate aggregate macros for this hour's food items
  _HourMacros get _macros {
    int calories = 0;
    int carbs = 0;
    int sodium = 0;

    for (final assignment in widget.assignments) {
      final food = widget.foodMap[assignment.foodItemId];
      if (food?.nutritionalInfo != null) {
        calories += food!.nutritionalInfo!.calories ?? 0;
        carbs += food.nutritionalInfo!.carbs ?? 0;
        sodium += food.nutritionalInfo!.sodium ?? 0;
      }
    }

    return _HourMacros(calories: calories, carbs: carbs, sodium: sodium);
  }

  @override
  Widget build(BuildContext context) {
    final macros = _macros;
    final hourLabel = 'Hour ${widget.hourIndex + 1}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hour header row (always visible)
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Text(
                  hourLabel,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildMacroSummaryInline(context, macros),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        // Divider under header
        Divider(
          height: 1,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        // Expanded content: time slot rows
        if (_isExpanded) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildTimeSlotTimeline(context),
          const SizedBox(height: AppSpacing.sm),
          // ADD TO HOUR X button
          Center(
            child: KyleAddFoodButton(
              text: '+ ADD TO HOUR ${widget.hourIndex + 1}',
              onPressed: () => widget.onAddFood(widget.category),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildMacroSummaryInline(BuildContext context, _HourMacros macros) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final dotStyle = AppTextStyles.smallLabel.copyWith(
      color: onSurfaceVariant,
      fontSize: 12,
    );

    // Use deviation colors for carbs and sodium if targets are available
    final carbsColor = onSurfaceVariant;
    final sodiumColor = onSurfaceVariant;

    return Text.rich(
      TextSpan(
        style: dotStyle,
        children: [
          TextSpan(text: '${macros.calories} cal'),
          TextSpan(text: '  \u00B7  '),
          TextSpan(
            text: '${macros.carbs}g carbs',
            style: dotStyle.copyWith(color: carbsColor),
          ),
          TextSpan(text: '  \u00B7  '),
          TextSpan(
            text: '${macros.sodium}mg sodium',
            style: dotStyle.copyWith(color: sodiumColor),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTimeSlotTimeline(BuildContext context) {
    // Build all slots for this hour
    final slots = <Widget>[];

    for (int slotIdx = 0; slotIdx < widget.slotCount; slotIdx++) {
      final slot = TimeSlot(hourIndex: widget.hourIndex, slotIndex: slotIdx);
      final slotAssignments = widget.assignments
          .where((a) => a.timeSlot.slotIndex == slotIdx)
          .toList();

      final isLastSlot = slotIdx == widget.slotCount - 1;

      slots.add(
        TimeSlotRow(
          timeSlot: slot,
          assignments: slotAssignments,
          foodMap: widget.foodMap,
          sectionColor: widget.sectionColor,
          category: widget.category,
          useImperial: widget.useImperial,
          isLastInHour: isLastSlot,
          onSwapFood: widget.onSwapFood,
          onDeleteFood: widget.onDeleteFood,
          onUpdateQuantity: widget.onUpdateQuantity,
          onMoveFoodToTimeSlot: widget.onMoveFoodToTimeSlot,
        ),
      );
    }

    return Column(children: slots);
  }
}

class _HourMacros {
  const _HourMacros({
    required this.calories,
    required this.carbs,
    required this.sodium,
  });

  final int calories;
  final int carbs;
  final int sodium;
}

import 'package:flutter/material.dart';
import '../../../../../shared/domain/activity_type.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../application/by_hour_apportionment_service.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/time_slot_assignment.dart';
import 'time_slot_row.dart';

/// Collapsible hour bucket showing time-slotted food items.
///
/// Collapsed view: "Hour 1  Xg carbs . Xmg sodium" with chevron
/// Expanded view: SipThroughoutRow + Timeline of TimeSlotRows
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
    required this.onMoveFoodToTimeSlot,
    this.activityType = ActivityType.running,
    this.selectedFoodId,
    this.onPlaceFromTray,
    this.onRemoveFromSlot,
    this.onAdjustSlotQuantity,
  });

  final int hourIndex;
  final int slotCount;
  final List<TimeSlotAssignment> assignments;
  final Map<String, FoodItemData> foodMap;
  final Color sectionColor;
  final String category;
  final bool useImperial;
  final ActivityType activityType;
  final void Function(String foodId, String foodName, String category)
  onSwapFood;
  final void Function(String foodId, String category) onDeleteFood;
  final void Function(String foodId, String category, double newQuantity)
  onUpdateQuantity;
  final void Function(
    String foodId,
    String category,
    TimeSlot sourceTimeSlot,
    TimeSlot newTimeSlot,
  )
  onMoveFoodToTimeSlot;

  /// Currently selected food ID for tap-to-place mode.
  final String? selectedFoodId;

  /// Called when a food is placed from tray (tap or drop).
  final void Function(
    String foodId,
    TimeSlot slot,
    double qty,
    TimingCategory? timingCategory,
    bool isSipThroughout,
  )?
  onPlaceFromTray;

  /// Called when a food is removed from a slot.
  final void Function(String foodId, TimeSlot slot)? onRemoveFromSlot;

  /// Called to adjust a placed food's slot quantity by delta.
  final void Function(String foodId, TimeSlot slot, double delta)?
  onAdjustSlotQuantity;

  @override
  State<HourBucketWidget> createState() => _HourBucketWidgetState();
}

class _HourBucketWidgetState extends State<HourBucketWidget> {
  bool _isExpanded = false;

  /// Calculate aggregate macros for this hour's food items,
  /// scaling by adjustedQuantity when present.
  _HourMacros get _macros {
    double calories = 0;
    double carbs = 0;
    double sodium = 0;

    for (final assignment in widget.assignments) {
      final food = widget.foodMap[assignment.foodItemId];
      if (food?.nutritionalInfo != null) {
        final scale = _quantityScale(food!, assignment);
        calories += (food.nutritionalInfo!.calories ?? 0) * scale;
        carbs += (food.nutritionalInfo!.carbs ?? 0) * scale;
        sodium += (food.nutritionalInfo!.sodium ?? 0) * scale;
      }
    }

    return _HourMacros(
      calories: calories.round(),
      carbs: carbs.round(),
      sodium: sodium.round(),
    );
  }

  /// Returns the scaling factor for an assignment's nutritional values.
  double _quantityScale(FoodItemData food, TimeSlotAssignment assignment) {
    if (assignment.adjustedQuantity == null) return 1.0;
    final originalQty = ByHourApportionmentService.parseQuantity(food);
    if (originalQty <= 0) return 1.0;
    return assignment.adjustedQuantity! / originalQty;
  }

  @override
  Widget build(BuildContext context) {
    final macros = _macros;
    final hourLabel = 'Hour ${widget.hourIndex + 1}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hour header row (always visible) — auto-expand on drag hover
        DragTarget<Object>(
          onWillAcceptWithDetails: (details) {
            if (!_isExpanded) {
              setState(() => _isExpanded = true);
            }
            return false; // Don't accept here — let child slots handle it
          },
          builder: (context, _, __) {
            return InkWell(
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
                    Expanded(child: _buildMacroSummaryInline(context, macros)),
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
            );
          },
        ),
        // Divider under header
        Divider(
          height: 1,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        // Expanded content (sip-throughout is now global, not per-hour)
        if (_isExpanded) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildTimeSlotTimeline(context, widget.assignments),
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

    return Text.rich(
      TextSpan(
        style: dotStyle,
        children: [
          TextSpan(text: '${macros.carbs}g carbs'),
          const TextSpan(text: '  \u00B7  '),
          TextSpan(text: '${macros.sodium}mg sodium'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTimeSlotTimeline(
    BuildContext context,
    List<TimeSlotAssignment> assignments,
  ) {
    // Build all slots starting from :00 (sip-throughout is now global)
    final slots = <Widget>[];

    for (int slotIdx = 0; slotIdx < widget.slotCount; slotIdx++) {
      final slot = TimeSlot(hourIndex: widget.hourIndex, slotIndex: slotIdx);
      final slotAssignments = assignments
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
          activityType: widget.activityType,
          onSwapFood: widget.onSwapFood,
          onDeleteFood: widget.onDeleteFood,
          onUpdateQuantity: widget.onUpdateQuantity,
          onMoveFoodToTimeSlot: widget.onMoveFoodToTimeSlot,
          selectedFoodId: widget.selectedFoodId,
          onPlaceFromTray: widget.onPlaceFromTray,
          onRemoveFromSlot: widget.onRemoveFromSlot,
          onAdjustSlotQuantity: widget.onAdjustSlotQuantity,
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

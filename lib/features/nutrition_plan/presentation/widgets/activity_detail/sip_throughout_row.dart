import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../application/by_hour_apportionment_service.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/time_slot_assignment.dart';
import '../../../domain/unassigned_tray_item.dart';

/// Dedicated "Sip Throughout" row at the top of each expanded hour bucket.
///
/// Accepts drops from the unassigned tray and tap-to-place for drink items.
/// Visually distinct from :00/:15/:30/:45 slots (wave icon + label).
class SipThroughoutRow extends StatelessWidget {
  const SipThroughoutRow({
    super.key,
    required this.hourIndex,
    required this.sipAssignments,
    required this.foodMap,
    required this.sectionColor,
    required this.category,
    this.selectedFoodId,
    this.onPlaceFromTray,
    this.onRemoveFromSlot,
  });

  final int hourIndex;
  final List<TimeSlotAssignment> sipAssignments;
  final Map<String, FoodItemData> foodMap;
  final Color sectionColor;
  final String category;

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

  /// Called when a food is removed from this row.
  final void Function(String foodId, TimeSlot slot)? onRemoveFromSlot;

  TimeSlot get _sipSlot => TimeSlot(hourIndex: hourIndex, slotIndex: 0);

  @override
  Widget build(BuildContext context) {
    return DragTarget<TrayDragData>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final data = details.data;
        onPlaceFromTray?.call(
          data.foodId,
          _sipSlot,
          data.quantity,
          data.timingCategory,
          true,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        final hasTapTarget = selectedFoodId != null;

        return GestureDetector(
          onTap: hasTapTarget
              ? () {
                  final food = foodMap[selectedFoodId];
                  if (food != null) {
                    final stepSize = food.isIndivisible ? 1.0 : 0.5;
                    final timingCategory =
                        ByHourApportionmentService.resolveTimingCategory(food);
                    onPlaceFromTray?.call(
                      selectedFoodId!,
                      _sipSlot,
                      stepSize,
                      timingCategory,
                      true,
                    );
                  }
                }
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isDropTarget
                  ? sectionColor.withValues(alpha: 0.12)
                  : sectionColor.withValues(alpha: 0.04),
              borderRadius: AppRadius.smRadius,
              border: Border.all(
                color: isDropTarget
                    ? sectionColor.withValues(alpha: 0.4)
                    : sectionColor.withValues(alpha: 0.15),
                width: isDropTarget ? 1.5 : 1,
              ),
            ),
            child: sipAssignments.isEmpty
                ? _buildEmptyRow(context, hasTapTarget)
                : _buildPopulatedRow(context),
          ),
        );
      },
    );
  }

  Widget _buildEmptyRow(BuildContext context, bool hasTapTarget) {
    return Row(
      children: [
        Icon(
          Icons.water_drop_outlined,
          size: 16,
          color: sectionColor.withValues(alpha: 0.5),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            hasTapTarget ? 'Tap to place drink' : 'Sip Throughout',
            style: AppTextStyles.bodySmall.copyWith(
              color: hasTapTarget
                  ? sectionColor
                  : Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPopulatedRow(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.water_drop, size: 16, color: sectionColor),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 2,
            children: sipAssignments.map((assignment) {
              final food = foodMap[assignment.foodItemId];
              if (food == null) return const SizedBox.shrink();

              final qty =
                  assignment.adjustedQuantity ??
                  ByHourApportionmentService.parseQuantity(food);
              final qtyStr = _formatQuantity(qty);
              final name = food.displayName ?? food.name;

              return Dismissible(
                key: ValueKey(
                  '${assignment.foodItemId}_${assignment.timeSlot}_sip',
                ),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  color: Colors.red.withValues(alpha: 0.1),
                  child: const Icon(Icons.close, size: 16, color: Colors.red),
                ),
                onDismissed: (_) {
                  onRemoveFromSlot?.call(
                    assignment.foodItemId,
                    assignment.timeSlot,
                  );
                },
                child: Text(
                  '$qtyStr $name',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _formatQuantity(double value) {
    if ((value - value.roundToDouble()).abs() < 0.01) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}

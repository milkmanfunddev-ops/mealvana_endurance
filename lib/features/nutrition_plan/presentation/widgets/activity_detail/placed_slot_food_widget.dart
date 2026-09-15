import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../../shared/widgets/swipe_action_background.dart';
import '../../../application/by_hour_sync_service.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/time_slot_assignment.dart';

/// Compact inline widget for foods placed in by-hour time slots.
///
/// Layout: `1 pkt Energy Gel    25g  [-] 1 [+]  x`
///
/// - **+** increases slot qty by step size, drawing from unassigned
/// - **-** decreases slot qty by step size, returning to unassigned
/// - **x** unassigns the food entirely (returns full qty to tray)
/// - Swipe-left also = "Unassign"
class PlacedSlotFoodWidget extends StatelessWidget {
  const PlacedSlotFoodWidget({
    super.key,
    required this.food,
    required this.assignment,
    required this.sectionColor,
    required this.onAdjustQuantity,
    required this.onUnassign,
  });

  final FoodItemData food;
  final TimeSlotAssignment assignment;
  final Color sectionColor;

  /// Called with delta (+step or -step) to adjust slot quantity.
  final void Function(double delta) onAdjustQuantity;

  /// Called to unassign the food entirely from this slot.
  final VoidCallback onUnassign;

  double get _slotQty =>
      assignment.adjustedQuantity ?? ByHourSyncService.parseQuantity(food);

  double get _originalQty => ByHourSyncService.parseQuantity(food);

  /// Carbs scaled to THIS slot's quantity, for the badge. The widget is handed
  /// the RAW (unscaled) food and scales off its own slot quantity — sip rows
  /// used to pass raw food to a badge that read the food's base carbs, so the
  /// number never moved when the row's quantity changed (Xuan/Claudia,
  /// 2026-08-31: 3 cups → 2.5 cups still read 52g).
  int? get _scaledCarbs {
    final base = food.nutritionalInfo?.carbs;
    if (base == null) return null;
    final orig = _originalQty;
    if (orig <= 0) return base;
    return (base * (_slotQty / orig)).round();
  }

  double get _stepSize => food.isIndivisible ? 1.0 : 0.5;

  @override
  Widget build(BuildContext context) {
    final carbs = _scaledCarbs;
    final qtyStr = _formatQuantity(_slotQty);
    final displayText = food.displayAtQuantity(qtyStr);

    return Dismissible(
      key: ValueKey(
        '${assignment.foodItemId}_${assignment.timeSlot.hourIndex}_${assignment.timeSlot.slotIndex}_placed',
      ),
      direction: DismissDirection.endToStart,
      // Radius matches the foreground chip below so the reveal is chip-shaped.
      background: SwipeActionBackground(
        alignment: Alignment.centerRight,
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: AppRadius.smRadius,
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        label: 'Unassign',
        labelStyle: AppTextStyles.smallLabel.copyWith(
          color: Colors.orange,
          fontSize: 11,
        ),
      ),
      onDismissed: (_) => onUnassign(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: sectionColor.withValues(alpha: 0.04),
          borderRadius: AppRadius.smRadius,
          border: Border.all(color: sectionColor.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            // Food name with quantity
            Expanded(
              child: Text(
                displayText,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Carbs badge
            if (carbs != null && carbs > 0) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: sectionColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${carbs}g',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: sectionColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.xs),
            // Minus button
            _StepButton(
              icon: Icons.remove,
              color: sectionColor,
              onTap: _slotQty > _stepSize - 0.01
                  ? () => onAdjustQuantity(-_stepSize)
                  : null,
            ),
            // Current slot qty
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                _formatQuantity(_slotQty),
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Plus button
            _StepButton(
              icon: Icons.add,
              color: sectionColor,
              onTap: () => onAdjustQuantity(_stepSize),
            ),
            const SizedBox(width: 2),
            // Unassign button
            GestureDetector(
              onTap: onUnassign,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatQuantity(double value) {
    if ((value - value.roundToDouble()).abs() < 0.01) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.color, this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled
              ? color.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.05),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isEnabled ? color : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../application/by_hour_apportionment_service.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/unassigned_tray_item.dart';

/// Collapsible tray at the top of the By-Hour view showing unassigned food items.
///
/// Items can be tapped to select (for tap-to-place) or long-pressed to drag.
/// Disappears entirely when all items are fully assigned.
class UnassignedTrayWidget extends StatefulWidget {
  const UnassignedTrayWidget({
    super.key,
    required this.items,
    required this.sectionColor,
    required this.selectedFoodId,
    required this.onSelectFood,
    required this.foodMap,
  });

  final List<UnassignedTrayItem> items;
  final Color sectionColor;
  final String? selectedFoodId;
  final void Function(String? foodId) onSelectFood;
  final Map<String, FoodItemData> foodMap;

  @override
  State<UnassignedTrayWidget> createState() => _UnassignedTrayWidgetState();
}

class _UnassignedTrayWidgetState extends State<UnassignedTrayWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.smRadius,
        color: widget.sectionColor.withValues(alpha: 0.04),
        border: Border.all(
          color: widget.sectionColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          if (_isExpanded) _buildItemsList(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: AppRadius.smRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 16,
              color: widget.sectionColor,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'UNASSIGNED',
              style: AppTextStyles.smallLabel.copyWith(
                color: widget.sectionColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: widget.sectionColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.items.length}',
                style: AppTextStyles.smallLabel.copyWith(
                  color: widget.sectionColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              _isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              color:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        children: widget.items.map((item) {
          final isSelected = widget.selectedFoodId == item.foodId;
          final food = item.food;
          final qtyStr = _formatQuantity(item.remainingQuantity);
          final name = food.displayName ?? food.name;

          // Get unit from original quantity string
          final unitMatch =
              RegExp(r'^[\d.]+\s*(.*)$').firstMatch(food.quantity);
          final unit = unitMatch?.group(1)?.trim() ?? '';
          final displayText =
              unit.isNotEmpty ? '$qtyStr $unit $name' : '$qtyStr $name';

          final timingCategory =
              ByHourApportionmentService.resolveTimingCategory(food);

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: LongPressDraggable<TrayDragData>(
              data: TrayDragData(
                foodId: item.foodId,
                food: food,
                quantity: item.stepSize,
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
                    border: Border.all(color: widget.sectionColor),
                  ),
                  child: Text(
                    displayText,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  widget.onSelectFood(isSelected ? null : item.foodId);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.sectionColor.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: AppRadius.smRadius,
                    border: isSelected
                        ? Border.all(
                            color: widget.sectionColor.withValues(alpha: 0.4),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? widget.sectionColor
                              : widget.sectionColor.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          displayText,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.touch_app,
                          size: 14,
                          color: widget.sectionColor,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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

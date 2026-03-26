import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/fuel_log_data.dart';

/// A single food row in the fuel log with +/- quantity controls.
class FuelLogFoodRow extends StatelessWidget {
  const FuelLogFoodRow({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    this.sectionColor = AppColors.orange,
    this.isViewOnly = false,
  });

  final FuelLogItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final Color sectionColor;
  final bool isViewOnly;

  @override
  Widget build(BuildContext context) {
    final isZero = item.actualQuantity <= 0;
    final displayQty = _formatQuantity(item.actualQuantity);
    final foodName = item.displayName ?? item.name;

    return Opacity(
      opacity: isZero ? 0.4 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Food icon
            KyleFoodIcon(foodType: mapFoodType(name: item.name), size: 36),
            const SizedBox(width: AppSpacing.sm),

            // Food name and status label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    foodName,
                    style: AppTextStyles.foodTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  _buildStatusLabel(context),
                ],
              ),
            ),

            // Quantity controls
            if (isViewOnly)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  displayQty,
                  style: AppTextStyles.dataNumber.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              _buildQuantityControls(context, displayQty),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLabel(BuildContext context) {
    if (item.isAdded) {
      return Text(
        'Added',
        style: AppTextStyles.bodySmall.copyWith(
          color: sectionColor,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final diff = item.actualQuantity - item.plannedQuantity;
    String label = '';
    Color color = Theme.of(context).colorScheme.onSurfaceVariant;

    if (item.actualQuantity <= 0 && item.plannedQuantity > 0) {
      label = 'Skipped';
      color = AppColors.dragonfruit;
    } else if (diff < 0) {
      label = 'Partial';
      color = AppColors.orange;
    } else if (diff > 0) {
      label = 'More than planned';
      color = sectionColor;
    }

    if (label.isEmpty) return const SizedBox.shrink();

    return Text(
      label,
      style: AppTextStyles.bodySmall.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildQuantityControls(BuildContext context, String displayQty) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minus button
        _CircleControlButton(
          icon: Icons.remove,
          onTap: onDecrement,
          color: theme.colorScheme.onSurface,
        ),
        const SizedBox(width: AppSpacing.sm),

        // Quantity display
        SizedBox(
          width: 36,
          child: Text(
            displayQty,
            textAlign: TextAlign.center,
            style: AppTextStyles.dataNumber.copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),

        // Plus button
        _CircleControlButton(
          icon: Icons.add,
          onTap: onIncrement,
          color: AppColors.orange,
        ),
      ],
    );
  }

  String _formatQuantity(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    // Show one decimal for .5 values
    return qty.toStringAsFixed(1);
  }
}

/// Small circular outlined button for +/- controls.
class _CircleControlButton extends StatelessWidget {
  const _CircleControlButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

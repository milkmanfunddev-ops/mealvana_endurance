import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/food_item_data.dart';
import '../../utils/activity_detail_helpers.dart';
import 'expandable_food_item_widget.dart';

/// Reusable dismissible food item with swipe-to-delete and swipe-to-swap
/// Used by both single-sport and brick nutrition sections
class DismissibleFoodItem extends StatelessWidget {
  const DismissibleFoodItem({
    super.key,
    required this.food,
    required this.category,
    required this.onSwap,
    required this.onDelete,
    required this.onQuantityChange,
    this.showSwipeHint = false,
    this.useImperial = true,
    this.subtitleOverride,
  });

  final FoodItemData food;
  final String category;
  final VoidCallback onSwap;
  final VoidCallback onDelete;
  final ValueChanged<double> onQuantityChange;
  final bool showSwipeHint;
  final bool useImperial;
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(food.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.dragonfruit,
          borderRadius: AppRadius.smRadius,
        ),
        child: Row(
          children: [
            FaIcon(
              FontAwesomeIcons.trash,
              color: Colors.white,
              size: AppIconSizes.md,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Delete',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.electrolyte,
          borderRadius: AppRadius.smRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Swap',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FaIcon(
              FontAwesomeIcons.arrowRightArrowLeft,
              color: Colors.white,
              size: AppIconSizes.md,
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Delete Food Item'),
              content: Text('Remove ${food.name} from this section?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    'Delete',
                    style: TextStyle(color: AppColors.dragonfruit),
                  ),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            onDelete();
          }
          return false;
        } else if (direction == DismissDirection.endToStart) {
          onSwap();
          return false;
        }
        return false;
      },
      child: ExpandableFoodItemWidget(
        food: food,
        getFoodIcon: ActivityDetailHelpers.getFoodIcon,
        isUserImportedFood: ActivityDetailHelpers.isUserImportedFood,
        getFoodIconColor: ActivityDetailHelpers.getFoodIconColor,
        onSwap: onSwap,
        onRemove: onDelete,
        showSwipeHint: showSwipeHint,
        onQuantityChange: onQuantityChange,
        useImperial: useImperial,
        subtitleOverride: subtitleOverride,
      ),
    );
  }
}

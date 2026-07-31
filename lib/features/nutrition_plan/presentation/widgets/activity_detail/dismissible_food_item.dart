import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../../shared/widgets/swipe_action_background.dart';
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
    this.showQuantity = true,
  });

  final FoodItemData food;
  final String category;
  final VoidCallback onSwap;
  final VoidCallback onDelete;
  final ValueChanged<double> onQuantityChange;
  final bool showSwipeHint;
  final bool useImperial;
  final String? subtitleOverride;

  /// Forwarded to [ExpandableFoodItemWidget] — false hides the quantity in the
  /// title and the +/- stepper (personal-formula editor).
  final bool showQuantity;

  @override
  Widget build(BuildContext context) {
    // Swipe right→left (endToStart) = Delete, swipe left→right (startToEnd) =
    // Swap — the iOS-conventional "swipe left to delete". Kept in sync with the
    // Fuel Timeline rows (TimelineNodeTile).
    return Dismissible(
      key: Key(food.id),
      // Both reveals carry ExpandableFoodItemWidget's radius so no square
      // corner shows behind the rounded row.
      background: const SwipeActionBackground(
        alignment: Alignment.centerLeft,
        color: AppColors.electrolyte,
        borderRadius: AppRadius.smRadius,
        padding: EdgeInsets.only(left: AppSpacing.lg),
        icon: FaIcon(
          FontAwesomeIcons.arrowRightArrowLeft,
          color: Colors.white,
          size: AppIconSizes.md,
        ),
        label: 'Swap',
      ),
      secondaryBackground: const SwipeActionBackground(
        alignment: Alignment.centerRight,
        color: AppColors.dragonfruit,
        borderRadius: AppRadius.smRadius,
        padding: EdgeInsets.only(right: AppSpacing.lg),
        icon: FaIcon(
          FontAwesomeIcons.trash,
          color: Colors.white,
          size: AppIconSizes.md,
        ),
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
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
        } else if (direction == DismissDirection.startToEnd) {
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
        showQuantity: showQuantity,
      ),
    );
  }
}

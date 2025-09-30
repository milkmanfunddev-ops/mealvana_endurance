import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../theme/app_theme.dart';
import '../../../features/nutrition_plan/domain/food.dart';
import '../../../features/auth/domain/user_preferences.dart';
import '../food_icon.dart';
import '../food_preference_widget.dart';

/// Unified food item display tile
/// Configurable for different contexts (preferences, swap, recommendations)
class FoodItemTile extends StatelessWidget {
  const FoodItemTile({
    super.key,
    required this.food,
    required this.onTap,
    this.showPreference = false,
    this.selectedPreference,
    this.onPreferenceChanged,
    this.isAvoided = false,
    this.showDeleteButton = false,
    this.onDelete,
    this.likeLabel = 'Love',
    this.willingLabel = 'Willing to Try',
    this.dislikeLabel = 'Avoid',
  });

  final Food food;
  final VoidCallback onTap;
  final bool showPreference;
  final FoodPreference? selectedPreference;
  final Function(FoodPreference)? onPreferenceChanged;
  final bool isAvoided;
  final bool showDeleteButton;
  final VoidCallback? onDelete;
  final String likeLabel;
  final String willingLabel;
  final String dislikeLabel;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isAvoided ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(12.r),
            border: isAvoided ? Border.all(color: AppTheme.primary100) : null,
          ),
          child: showPreference ? _buildPreferenceItem() : _buildSimpleItem(),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (isAvoided) {
      return AppTheme.primary50.withValues(alpha: 0.3);
    }
    if (showPreference) {
      return AppTheme.baseWhite;
    }
    return AppTheme.primary50.withValues(alpha: 0.2);
  }

  /// Build item with preference selection (for preferences screen)
  Widget _buildPreferenceItem() {
    return FoodPreferenceChipItem(
      food: _convertToFoodItem(),
      selected: selectedPreference ?? FoodPreference.willingToTry,
      likeLabel: likeLabel,
      willingLabel: willingLabel,
      dislikeLabel: dislikeLabel,
      showDeleteButton: showDeleteButton,
      onChanged: onPreferenceChanged ?? (_) {},
      onDelete: onDelete,
    );
  }

  /// Build simple item (for swap/add screens)
  Widget _buildSimpleItem() {
    return Row(
      children: [
        // Food icon
        FoodIcon(
          imageUrl: food.imageUrl,
          size: 40.w,
        ),
        SizedBox(width: 12.w),

        // Food name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                food.displayName ?? food.name,
                style: TextStyle(
                  color: isAvoided ? AppTheme.primary100 : AppTheme.baseBlack,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isAvoided) ...[
                SizedBox(height: 2.h),
                Text(
                  'Marked as Avoid',
                  style: TextStyle(
                    color: AppTheme.primary100,
                    fontSize: 11.sp,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Action indicator
        Icon(
          Icons.chevron_right,
          color: isAvoided ? AppTheme.primary100 : AppTheme.primary900,
          size: 24.sp,
        ),
      ],
    );
  }

  /// Convert Food to FoodItem for compatibility with existing widgets
  /// TODO: Refactor FoodPreferenceChipItem to use Food directly
  dynamic _convertToFoodItem() {
    return FoodItemMock(
      id: food.id,
      name: food.name,
      displayName: food.displayName,
      imageAddress: food.imageUrl,
    );
  }
}

/// Temporary mock class to satisfy FoodPreferenceChipItem interface
/// TODO: Refactor FoodPreferenceChipItem to use Food domain object
class FoodItemMock {
  const FoodItemMock({
    required this.id,
    required this.name,
    this.displayName,
    this.imageAddress,
  });

  final String id;
  final String name;
  final String? displayName;
  final String? imageAddress;
}
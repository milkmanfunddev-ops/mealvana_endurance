import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../features/auth/domain/user_preferences.dart';
import '../../features/nutrition_plan/domain/food_item.dart';

/// Shared widget for food preference selection
/// Used in both onboarding and settings screens
class FoodPreferenceChipItem extends StatelessWidget {
  final FoodItem food;
  final FoodPreference selected;
  final String likeLabel;
  final String willingLabel;
  final String dislikeLabel;
  final ValueChanged<FoodPreference> onChanged;
  final bool showDeleteButton;
  final VoidCallback? onDelete;

  const FoodPreferenceChipItem({
    super.key,
    required this.food,
    required this.selected,
    required this.likeLabel,
    required this.willingLabel,
    required this.dislikeLabel,
    required this.onChanged,
    this.showDeleteButton = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food name with optional delete button
          Row(
            children: [
              Expanded(
                child: Text(
                  food.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (showDeleteButton && onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8.w),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red[600],
                      size: 18.sp,
                    ),
                  ),
                ),
            ],
          ),
          if (food.servingSize != null && food.servingSize!.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              'Serving: ${food.servingSize}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          SizedBox(height: 12.h),
          // Icons above the slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => onChanged(FoodPreference.dislike),
                child: Text('❌', style: TextStyle(fontSize: 24.sp)),
              ),
              GestureDetector(
                onTap: () => onChanged(FoodPreference.like),
                child: Text('❤️', style: TextStyle(fontSize: 24.sp)),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // Slider for preference selection
          Row(
            children: [
              PreferenceChip(
                label: dislikeLabel,
                icon: '',
                isSelected: selected == FoodPreference.dislike,
                onTap: () => onChanged(FoodPreference.dislike),
                color: Colors.red,
                theme: theme,
              ),
              SizedBox(width: 8.w),
              PreferenceChip(
                label: willingLabel,
                icon: '🤔',
                isSelected: selected == FoodPreference.willingToTry,
                onTap: () => onChanged(FoodPreference.willingToTry),
                color: Colors.orange,
                theme: theme,
              ),
              SizedBox(width: 8.w),
              PreferenceChip(
                label: likeLabel,
                icon: '',
                isSelected: selected == FoodPreference.like,
                onTap: () => onChanged(FoodPreference.like),
                color: Colors.green,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PreferenceChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  final ThemeData theme;

  const PreferenceChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? color
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon.isNotEmpty) ...[
                Text(icon, style: TextStyle(fontSize: 18.sp)),
                SizedBox(height: 4.h),
              ],
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? color
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

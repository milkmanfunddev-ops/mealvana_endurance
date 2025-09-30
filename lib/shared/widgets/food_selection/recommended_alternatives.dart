import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../theme/app_theme.dart';
import '../../../features/nutrition_plan/domain/food.dart';
import '../../../features/auth/domain/user_preferences.dart';
import 'food_item_tile.dart';

/// Widget for displaying recommended alternatives
/// Used in swap food and add food screens
class RecommendedAlternatives extends StatelessWidget {
  const RecommendedAlternatives({
    super.key,
    required this.foods,
    required this.onFoodSelected,
    required this.preferences,
    this.title = 'Recommended Alternatives',
    this.maxItems = 10,
  });

  final List<Food> foods;
  final Function(Food) onFoodSelected;
  final Map<String, FoodPreference> preferences;
  final String title;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    // Limit to maxItems
    final displayFoods = foods.take(maxItems).toList();

    if (displayFoods.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            title,
            style: AppTheme.subtitleStyle.copyWith(
              color: AppTheme.primary900,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        SizedBox(height: 16.h),

        // Foods list
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: displayFoods.length,
            separatorBuilder: (context, index) => SizedBox(height: 8.h),
            itemBuilder: (context, index) {
              final food = displayFoods[index];
              final preference = preferences[food.name];
              final isAvoided = preference == FoodPreference.dislike;

              return FoodItemTile(
                food: food,
                onTap: () => onFoodSelected(food),
                isAvoided: isAvoided,
                showPreference: false, // Don't show preference chips in recommendations
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.restaurant,
              size: 48.sp,
              color: AppTheme.primary100,
            ),
            SizedBox(height: 16.h),
            Text(
              'No recommendations available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                color: AppTheme.primary600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Try searching for foods or use the barcode scanner',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.primary100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_icon_classifier.dart';
import '../../domain/meal_ref.dart';
import 'meal_icon_glyphs.dart';

/// Compact square card for the catalog rails (Recents / My Foods /
/// Assemblies / Recipes): icon tile + two-line name, fixed rail width.
class MealRailCard extends StatelessWidget {
  const MealRailCard({
    super.key,
    required this.meal,
    required this.onTap,
    this.width = 128,
  });

  final MealRef meal;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;

    final icon =
        meal.icon ??
        MealIconClassifier.classify(
          name: meal.name,
          ingredients: meal.ingredients,
          pattern: meal.pattern,
        );

    return SizedBox(
      width: width,
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MealIconTile(icon: icon, mealType: meal.mealType, size: 32),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  meal.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

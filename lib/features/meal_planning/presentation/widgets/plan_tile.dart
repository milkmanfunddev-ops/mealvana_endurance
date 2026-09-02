import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_icon_classifier.dart';
import '../../domain/plan_meal.dart';
import 'meal_icon_glyphs.dart';
import 'session_chip.dart';
import 'slot_chip.dart';

/// One planned meal row: icon, name, slot + session chips, kcal · servings.
/// Tap opens the tile sheet (stepper · Swap · Remove); swipes are owned by
/// [PlanList] (05 §4).
class PlanTile extends StatelessWidget {
  const PlanTile({
    super.key,
    required this.meal,
    required this.onTap,
    this.showMacros = false,
  });

  final PlanMeal meal;
  final VoidCallback onTap;
  final bool showMacros;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final surface = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;

    final icon =
        meal.icon ??
        MealIconClassifier.classify(name: meal.name);

    final facts = <String>[
      if (meal.kcal != null) '${meal.kcal} kcal',
      if (showMacros && meal.carbsG != null)
        '${meal.carbsG!.round()}g carbs',
    ];

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              MealIconTile(icon: icon, mealType: meal.mealType, size: 36),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.foodTitle.copyWith(
                        color: textColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SlotChip(type: meal.mealType),
                        if (meal.session != null)
                          SessionChip(session: meal.session!),
                        if (facts.isNotEmpty)
                          Text(
                            facts.join(' · '),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: secondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '×${meal.servings}',
                style: AppTextStyles.bodySmall.copyWith(color: secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

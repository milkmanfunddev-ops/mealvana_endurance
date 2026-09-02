import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_icon_classifier.dart';
import '../../domain/meal_ref.dart';
import '../../domain/vana_part.dart';
import 'meal_icon_glyphs.dart';

/// `day_guidance` part — one day's note: label, optional workout, the
/// minimum-carbs line and Vana's note. Suggestions render as small tappable
/// chips (05 §3).
class DayCard extends StatelessWidget {
  const DayCard({super.key, required this.part, required this.onTapMeal});

  final VanaDayGuidancePart part;
  final ValueChanged<MealRef> onTapMeal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final surface = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;

    return Container(
      key: ValueKey('meal_planning.day_card_${part.date}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  part.label,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
              ),
              if (part.workout != null)
                Flexible(
                  child: Text(
                    part.workout!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(color: secondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (part.minCarbsG > 0)
            Text(
              '≥${part.minCarbsG}g carbs',
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
          if (part.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              part.note,
              style: AppTextStyles.bodyMedium.copyWith(
                color: textColor,
                height: 1.5,
              ),
            ),
          ],
          if (part.suggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final meal in part.suggestions)
                  GestureDetector(
                    onTap: () => onTapMeal(meal),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: mealTypeColor(
                          meal.mealType,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MealIconTile(
                            icon:
                                meal.icon ??
                                MealIconClassifier.classify(
                                  name: meal.name,
                                  ingredients: meal.ingredients,
                                  pattern: meal.pattern,
                                ),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              meal.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

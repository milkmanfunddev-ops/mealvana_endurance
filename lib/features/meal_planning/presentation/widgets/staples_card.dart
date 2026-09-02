import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_icon_classifier.dart';
import '../../domain/meal_ref.dart';
import '../../domain/vana_part.dart';
import 'meal_icon_glyphs.dart';

/// `staples` part — the compact "Your staples" card. Suggest only: nothing
/// is added until a row is tapped (the prototype's behaviour, kept). The
/// carb line shows how much of the target the current staples cover.
class StaplesCard extends ConsumerWidget {
  const StaplesCard({super.key, required this.part, required this.onTapMeal});

  final VanaStaplesPart part;
  final ValueChanged<MealRef> onTapMeal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final surface = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content.getValue(ContentKeys.mpStaplesTitle),
            style: AppTextStyles.sectionTitle.copyWith(
              color: textColor,
              fontSize: 16,
            ),
          ),
          if (part.planCarbsPerDay != null && part.targetCarbsPerDay != null)
            Text(
              ContentKeys.format(
                content.getValue(ContentKeys.mpStaplesCarbLine),
                {
                  'plan': part.planCarbsPerDay,
                  'target': part.targetCarbsPerDay,
                },
              ),
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final staple in part.meals)
                _StapleChip(
                  staple: staple,
                  onTap: () => onTapMeal(staple.meal),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StapleChip extends StatelessWidget {
  const _StapleChip({required this.staple, required this.onTap});

  final StapleMeal staple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.cream : AppColors.blackberry;
    final meal = staple.meal;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.yolk.withValues(alpha: 0.14),
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
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              meal.name,
              style: AppTextStyles.bodySmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (staple.timesLogged > 0)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '×${staple.timesLogged}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: fg.withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

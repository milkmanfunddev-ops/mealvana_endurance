import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_ref.dart';
import '../../domain/vana_part.dart';
import 'dashed_box.dart';

/// `staples` part — the compact "Your staples" card: an electrolyte-outlined
/// list of what the athlete already eats, each row ticked when it is in the
/// plan. Suggest only: nothing is added until a row is tapped. The carb line
/// shows how much of the target the current staples cover.
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

    if (part.meals.isEmpty) {
      return DashedBox(
        child: Text(
          content.getValue(ContentKeys.mpStaplesEmpty),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: secondary),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                content.getValue(ContentKeys.mpStaplesTitle).toUpperCase(),
                style: AppTextStyles.overline.copyWith(
                  color: secondary,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                content.getValue(ContentKeys.mpStaplesTapToAdd),
                style: AppTextStyles.bodySmall.copyWith(color: secondary),
              ),
            ],
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
          const SizedBox(height: 6),
          for (final staple in part.meals)
            _StapleRow(
              staple: staple,
              onTap: () => onTapMeal(staple.meal),
            ),
        ],
      ),
    );
  }
}

/// One staple: the tick showing whether it is already in the plan, the name,
/// and how often it has been logged ("12×") or that it is simply saved.
class _StapleRow extends ConsumerWidget {
  const _StapleRow({required this.staple, required this.onTap});

  final StapleMeal staple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.cream : AppColors.blackberry;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: staple.ticked ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: staple.ticked ? accent : fg.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: staple.ticked
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.blackberry,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                staple.meal.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.foodTitle.copyWith(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              staple.timesLogged > 0
                  ? '${staple.timesLogged}×'
                  : content.getValue(ContentKeys.mpStaplesSaved),
              style: AppTextStyles.bodySmall.copyWith(
                color: fg.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

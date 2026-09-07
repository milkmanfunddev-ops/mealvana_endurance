import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_ref.dart';
import 'meal_rail_card.dart';

/// A titled horizontal rail of [MealRailCard]s with an optional trailing
/// "See all" action (Recents → `/food/meals/recents`). The title is drawn as
/// an uppercase, letter-spaced eyebrow and "See all" in electrolyte —
/// the prototype's `.v-rail`. All labels are resolved from content keys by
/// the caller.
class MealRail extends StatelessWidget {
  const MealRail({
    super.key,
    required this.title,
    required this.meals,
    required this.onTapMeal,
    this.seeAllLabel,
    this.onSeeAll,
    this.emptyText,
    this.actionBuilder,
  });

  final String title;
  final List<MealRef> meals;
  final ValueChanged<MealRef> onTapMeal;

  /// Label for the trailing action; hidden when null.
  final String? seeAllLabel;
  final VoidCallback? onSeeAll;

  /// Shown instead of the strip when the rail is empty; the whole rail
  /// collapses when both are unset.
  final String? emptyText;

  /// Per-card action beside the name (the browse screen's Add button);
  /// cards are plain when null.
  final Widget? Function(MealRef meal)? actionBuilder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);

    if (meals.isEmpty && emptyText == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.96,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ),
            if (seeAllLabel != null && onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: Text(
                  seeAllLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.electrolyte
                        : AppColors.electrolyteDark,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (meals.isEmpty)
          Text(
            emptyText ?? '',
            style: AppTextStyles.bodySmall.copyWith(color: secondary),
          )
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: meals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => MealRailCard(
                key: ValueKey('meal_planning.rail_${title}_$i'),
                meal: meals[i],
                onTap: () => onTapMeal(meals[i]),
                action: actionBuilder?.call(meals[i]),
              ),
            ),
          ),
      ],
    );
  }
}

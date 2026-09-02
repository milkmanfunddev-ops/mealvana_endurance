import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_icon_classifier.dart';
import '../../domain/meal_ref.dart';
import 'meal_icon_glyphs.dart';
import 'slot_chip.dart';

/// A [MealRef] presented as a tappable card: icon tile, name, why-line,
/// prep · kcal, macros (when on), slot chip, attribution. Used by the
/// picker carousel, search results and detail-adjacent lists.
///
/// [greysWhen] renders the card disabled — the Meals tab greys cards the
/// athlete's allergens exclude even though the server already filters
/// suggestions (05 §4).
class MealCard extends ConsumerWidget {
  const MealCard({
    super.key,
    required this.meal,
    required this.onTap,
    this.trailing,
    this.showMacros = false,
    this.excluded = false,
    this.compact = false,
  });

  final MealRef meal;
  final VoidCallback onTap;

  /// Optional right-aligned action (e.g. the picker's "Add").
  final Widget? trailing;
  final bool showMacros;
  final bool excluded;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final surface = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;

    final facts = <String>[
      if (meal.prepMinutes != null) '${meal.prepMinutes} min',
      if (meal.kcal != null) '${meal.kcal} kcal',
    ];
    if (showMacros && meal.carbsG != null) {
      facts.addAll([
        '${meal.carbsG!.round()}g carbs',
        if (meal.proteinG != null) '${meal.proteinG!.round()}g protein',
      ]);
    }

    return Opacity(
      opacity: excluded ? 0.45 : 1,
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                MealIconTile(
                  icon: meal.effectiveIcon,
                  mealType: meal.mealType,
                  size: compact ? 32 : 40,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.name,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.foodTitle.copyWith(
                          color: textColor,
                          fontSize: compact ? 15 : 17,
                        ),
                      ),
                      if (!compact && meal.why.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meal.why,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SlotChip(type: meal.mealType),
                          if (!compact && facts.isNotEmpty)
                            Text(
                              facts.join(' · '),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: secondary,
                              ),
                            ),
                          if (!compact && meal.attributionShort.isNotEmpty)
                            Text(
                              meal.attributionShort,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: secondary.withValues(alpha: 0.8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on MealRef {
  MealIcon get effectiveIcon =>
      icon ??
      MealIconClassifier.classify(
        name: name,
        ingredients: ingredients,
        pattern: pattern,
      );
}

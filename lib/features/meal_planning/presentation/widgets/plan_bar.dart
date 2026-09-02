import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_ref.dart';
import '../../domain/plan_meal.dart';
import 'meal_sheet.dart';
import 'stepper.dart';

/// The draft-plan bar pinned above the chat composer. **Starts minimized**
/// and re-minimizes on every new turn (05 §4): minimized shows "N meals
/// picked" + expand; expanded lists tiles with × and a stepper plus the
/// "Review plan" button.
class PlanBar extends ConsumerStatefulWidget {
  const PlanBar({
    super.key,
    required this.meals,
    required this.onServings,
    required this.onRemove,
    required this.onSwap,
    required this.onReview,
  });

  final List<PlanMeal> meals;
  final void Function(PlanMeal meal, int servings) onServings;
  final ValueChanged<PlanMeal> onRemove;

  /// Opens the meal sheet (stepper · inline SwapPicker · Remove).
  final void Function(PlanMeal meal, MealRef replacement) onSwap;
  final VoidCallback onReview;

  @override
  ConsumerState<PlanBar> createState() => PlanBarState();
}

class PlanBarState extends ConsumerState<PlanBar> {
  bool _expanded = false;

  /// Collapses on each new turn — the chat screen calls this from its
  /// stream listener.
  void minimize() {
    if (mounted && _expanded) setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final surface = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    if (widget.meals.isEmpty) return const SizedBox.shrink();

    final summary = ContentKeys.format(
      content.getValue(ContentKeys.mpPlanBarMeals),
      {'n': widget.meals.length},
    );

    if (!_expanded) {
      return Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: InkWell(
          key: const ValueKey('meal_planning.plan_bar.minimized'),
          borderRadius: BorderRadius.circular(100),
          onTap: () => setState(() => _expanded = true),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                FaIcon(FontAwesomeIcons.bowlFood, color: accent, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FaIcon(
                  FontAwesomeIcons.chevronUp,
                  color: secondary,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.xs,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    summary,
                    key: const ValueKey('meal_planning.plan_bar.expanded'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: minimize,
                  icon: FaIcon(FontAwesomeIcons.xmark, color: secondary),
                ),
              ],
            ),
          ),
          Flexible(
            // SingleChildScrollView (not a shrinkWrap ListView) so the tile
            // rows receive bounded width — the steppers expand.
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final meal in widget.meals)
                    Row(
                      key: ValueKey('meal_planning.plan_bar.tile_${meal.id}'),
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _openMealSheet(meal),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xxs,
                              ),
                              child: Text(
                                meal.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        ServingsStepper(
                          value: meal.servings,
                          onChanged: (next) => widget.onServings(meal, next),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 14,
                          onPressed: () => widget.onRemove(meal),
                          icon: FaIcon(FontAwesomeIcons.xmark, color: secondary),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const ValueKey('meal_planning.plan_bar.review'),
                onPressed: widget.onReview,
                style: TextButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.16),
                ),
                child: Text(
                  content.getValue(ContentKeys.mpPlanBarReview),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.blackberry,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMealSheet(PlanMeal meal) {
    return showMealSheet(
      context: context,
      ref: ref,
      meal: meal,
      onServings: (servings) => widget.onServings(meal, servings),
      onSwap: widget.onSwap,
      onRemove: () => widget.onRemove(meal),
    );
  }
}

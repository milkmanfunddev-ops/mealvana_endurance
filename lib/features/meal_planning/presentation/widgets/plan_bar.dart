import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../shared/widgets/kyle_design/buttons/secondary_button.dart';
import '../../../../shared/widgets/kyle_design/data/macro_pill_row.dart';
import '../../application/meal_icon_classifier.dart';
import '../../application/meal_plan_controller.dart';
import '../../domain/meal_ref.dart';
import '../../domain/plan_meal.dart';
import 'meal_icon_glyphs.dart';
import 'meal_sheet.dart';
import 'slot_chip.dart';
import 'stepper.dart';

/// The draft-plan bar pinned above the chat composer. **Starts minimized**
/// and re-minimizes on every new turn (05 §4) so Vana's reply is never hidden
/// behind it. Minimized: "Your plan · N meals" and the Review action;
/// expanded: a strip of tiles, each with its own × and servings stepper.
/// Nothing here calls the model.
class PlanBar extends ConsumerStatefulWidget {
  const PlanBar({
    super.key,
    required this.meals,
    required this.onServings,
    required this.onRemove,
    required this.onSwap,
    required this.onReview,
    this.confirmed = false,
    this.showMacros = true,
  });

  final List<PlanMeal> meals;
  final void Function(PlanMeal meal, int servings) onServings;
  final ValueChanged<PlanMeal> onRemove;

  /// Opens the meal sheet (stepper · inline SwapPicker · Remove).
  final void Function(PlanMeal meal, MealRef replacement) onSwap;
  final VoidCallback onReview;

  /// The plan has been confirmed — Review reads back, and is inert.
  final bool confirmed;

  /// Each expanded tile carries a compact [MacroPillRow]. Defaults on (the
  /// `show_macros` default, plan §4.2); the chat screen passes the athlete's
  /// setting through.
  final bool showMacros;

  /// Meals in the plan before Review is worth offering as the primary action.
  static const reviewAt = 3;

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
    final secondary = textColor.withValues(alpha: 0.6);
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    if (widget.meals.isEmpty) return const SizedBox.shrink();

    final n = widget.meals.length;
    final count = n == 1
        ? content.getValue(ContentKeys.mpPlanBarCountOne)
        : ContentKeys.format(content.getValue(ContentKeys.mpPlanBarCount), {
            'n': n,
          });
    final reviewLabel = content.getValue(
      widget.confirmed
          ? ContentKeys.mpReviewConfirmed
          : ContentKeys.mpPlanBarReview,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, AppSpacing.xs),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: textColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  key: ValueKey(
                    _expanded
                        ? 'meal_planning.plan_bar.expanded'
                        : 'meal_planning.plan_bar.minimized',
                  ),
                  onTap: () => setState(() => _expanded = !_expanded),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Flexible(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: AppTextStyles.sectionTitle.copyWith(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            children: [
                              TextSpan(
                                text: content.getValue(
                                  ContentKeys.mpPlanBarTitle,
                                ),
                              ),
                              TextSpan(
                                text: ' · $count',
                                style: const TextStyle(color: AppColors.orange),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      FaIcon(
                        _expanded
                            ? FontAwesomeIcons.chevronDown
                            : FontAwesomeIcons.chevronUp,
                        color: secondary,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Review only becomes the primary action once there is enough
              // of a week to review. The button keeps its intrinsic width —
              // the Expanded count text on the left gives way and
              // ellipsizes, so the label is never clipped.
              n >= PlanBar.reviewAt
                  ? KylePrimaryButton(
                      key: const ValueKey('meal_planning.plan_bar.review'),
                      text: reviewLabel,
                      height: 34,
                      fontSize: 13,
                      isFullWidth: false,
                      onPressed: widget.confirmed ? null : widget.onReview,
                    )
                  : KyleSecondaryButton(
                      key: const ValueKey('meal_planning.plan_bar.review'),
                      text: reviewLabel,
                      height: 34,
                      fontSize: 13,
                      isFullWidth: false,
                      onPressed: widget.confirmed ? null : widget.onReview,
                    ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            SizedBox(
              // The macro strip needs one more line on the tile.
              height: widget.showMacros ? 150 : 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.meals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _PlanBarTile(
                  meal: widget.meals[i],
                  showMacros: widget.showMacros,
                  onOpen: () => _openMealSheet(widget.meals[i]),
                  onRemove: () => widget.onRemove(widget.meals[i]),
                  onServings: (next) =>
                      widget.onServings(widget.meals[i], next),
                ),
              ),
            ),
          ] else if (n < PlanBar.reviewAt) ...[
            const SizedBox(height: 4),
            Text(
              ContentKeys.format(content.getValue(ContentKeys.mpPlanBarMore), {
                'n': PlanBar.reviewAt - n,
              }),
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
          ],
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
      // Ingredient-level swap (plan Phase 6.3) goes straight to the plan
      // controller: it is a plan write like the others, and the bar already
      // owns a ref. A failure surfaces as the sheet's snackbar having been
      // optimistic — the next server fold corrects the tile.
      onSwapIngredient: (meal, swap) => ref
          .read(mealPlanControllerProvider.notifier)
          .swapIngredient(
            meal.id,
            from: swap.from,
            to: swap.to,
            effect: swap.effect,
          ),
    );
  }
}

/// One tile in the expanded bar: a corner × to drop the meal, the icon and
/// name (tap for the sheet), the compact macro strip when shown, then the
/// slot chip beside its stepper.
class _PlanBarTile extends StatelessWidget {
  const _PlanBarTile({
    required this.meal,
    required this.onOpen,
    required this.onRemove,
    required this.onServings,
    this.showMacros = true,
  });

  final PlanMeal meal;
  final bool showMacros;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final ValueChanged<int> onServings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return SizedBox(
      width: 184,
      child: Container(
        key: ValueKey('meal_planning.plan_bar.tile_${meal.id}'),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.blackberry : AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: textColor.withValues(alpha: 0.18)),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onOpen,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MealIconTile(
                          icon:
                              meal.icon ??
                              MealIconClassifier.classify(name: meal.name),
                          size: 30,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            // Clear of the × in the corner.
                            padding: const EdgeInsets.only(right: 20),
                            child: Text(
                              meal.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.foodTitle.copyWith(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (showMacros) ...[
                  const SizedBox(height: 4),
                  MacroPillRow(
                    kcal: meal.kcal,
                    carbsG: meal.carbsG,
                    proteinG: meal.proteinG,
                    fatG: meal.fatG,
                    compact: true,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // The chip yields first — the stepper must stay tappable
                    // at its full size on a 184pt tile.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SlotChip(type: meal.mealType, short: true),
                      ),
                    ),
                    ServingsStepper(
                      value: meal.servings,
                      dense: true,
                      onChanged: onServings,
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: textColor.withValues(alpha: 0.08),
                    border: Border.all(
                      color: textColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(Icons.close, size: 14, color: textColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

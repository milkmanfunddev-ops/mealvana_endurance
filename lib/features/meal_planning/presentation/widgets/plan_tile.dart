import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';

import '../../../../shared/widgets/kyle_design/data/macro_pill_row.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_icon_classifier.dart';
import '../../domain/plan_meal.dart';
import 'card_overflow_menu.dart';
import 'meal_icon_glyphs.dart';
import 'slot_chip.dart';

/// One planned meal row: icon, name (up to two lines), the slot chip and the
/// servings-left note, then "×N" on the trailing edge — the prototype's
/// `.v-tile`. Tap opens the meal's detail page; swipes and the `⋮` overflow
/// are owned by [PlanList] / the tile (05 §4).
///
/// Macros ([MacroPillRow], compact) render under the slot chip line when
/// "Show macros" is on in Vana settings — on by default since the chatbot
/// update (plan §4.2); the prototype had them behind a tap.
class PlanTile extends ConsumerWidget {
  const PlanTile({
    super.key,
    required this.meal,
    required this.onTap,
    this.onSwap,
    this.onRemove,
    this.showMacros = false,
  });

  final PlanMeal meal;
  final VoidCallback onTap;

  /// Card-scoped Swap / Remove in a `⋮` overflow after the servings figure
  /// (plan Phase 6.2) — the same actions the swipes and the sheet offer.
  final VoidCallback? onSwap;
  final VoidCallback? onRemove;
  final bool showMacros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;
    final border = textColor.withValues(alpha: 0.10);

    final icon =
        meal.icon ??
        MealIconClassifier.classify(name: meal.name);

    final macros = showMacros
        ? MacroPillRow(
            kcal: meal.kcal,
            carbsG: meal.carbsG,
            proteinG: meal.proteinG,
            fatG: meal.fatG,
            compact: true,
          )
        : null;

    final servingsLeftNote = meal.servingsLeft < meal.servings
        ? ContentKeys.format(
            content.getValue(ContentKeys.mpServingsLeftShort),
            {'left': meal.servingsLeft, 'total': meal.servings},
          )
        : null;

    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              MealIconTile(icon: icon, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SlotChip(type: meal.mealType),
                        if (servingsLeftNote != null)
                          Text(
                            servingsLeftNote,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: textColor.withValues(alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                    if (macros != null && !macros.isEmpty) ...[
                      const SizedBox(height: 4),
                      macros,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '×${meal.servings}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onSwap != null || onRemove != null)
                CardOverflowMenu(
                  menuKey: ValueKey('meal_planning.tile_overflow_${meal.id}'),
                  onSwap: onSwap,
                  onRemove: onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

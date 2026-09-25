import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';

import '../../../../shared/widgets/kyle_design/data/macro_pill_row.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_photo.dart';
import '../../domain/plan_meal.dart';
import 'card_overflow_menu.dart';
import 'meal_photo_view.dart';
import 'slot_chip.dart';

/// One planned meal row: the picture, name (up to two lines), the slot chip and the
/// servings-left note, then "×N" on the trailing edge — the prototype's
/// `.v-tile`. Tap does what the host says (the Plan tab opens the row's
/// sheet; an earlier plan opens the meal's detail page); swipes and the `⋮` overflow
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
    this.slot,
  });

  final PlanMeal meal;

  /// What this row draws where a picture goes — the library Meal's current
  /// Dish photo, looked up by [PlanList] and never stored on the plan row
  /// (ADR 0003). Omitted, or empty, the row draws no picture at all and
  /// starts at the meal's name.
  final MealPhotoSlot? slot;
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
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;
    final border = textColor.withValues(alpha: 0.10);

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
              // The library Meal's Dish photo, or no picture slot at all: a
              // row with nothing to show starts at the meal's name, and a
              // plan mixing the two still lines up its names and macros
              // (ADR 0003).
              MealPhotoThumb(
                photo: slot?.photo,
                size: 36,
                borderRadius: BorderRadius.circular(9),
              ),
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

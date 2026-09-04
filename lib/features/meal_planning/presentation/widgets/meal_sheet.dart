import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/utils/adaptive_modal.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/ingredient_swap.dart';
import '../../domain/meal_detail.dart';
import '../../domain/meal_ref.dart';
import '../../domain/plan_meal.dart';
import '../../../../shared/widgets/kyle_design/buttons/secondary_button.dart';
import '../../application/meal_detail_controller.dart';
import '../../application/meal_icon_classifier.dart';
import 'choice_chip_button.dart';
import 'meal_icon_glyphs.dart';
import 'slot_chip.dart';
import 'stepper.dart';
import 'swap_picker.dart';

/// Opens the chat-screen tile sheet: servings stepper · Swap (expands an
/// inline [SwapPicker]) · Remove · Swap an ingredient (expands the meal's
/// ingredient list with the library's swap suggestions — plan Phase 6.3)
/// (05 §4). Controller calls stay with the caller — the sheet reports
/// intents; [onSwapIngredient] is optional so hosts without the action
/// wired simply do not show the row.
Future<void> showMealSheet({
  required BuildContext context,
  required WidgetRef ref,
  required PlanMeal meal,
  required ValueChanged<int> onServings,
  required void Function(PlanMeal meal, MealRef replacement) onSwap,
  required VoidCallback onRemove,
  void Function(PlanMeal meal, IngredientSwap swap)? onSwapIngredient,
}) {
  return showAdaptiveModal<void>(
    context: context,
    builder: (sheetContext) => MealSheet(
      meal: meal,
      onServings: onServings,
      onSwap: onSwap,
      onRemove: onRemove,
      onSwapIngredient: onSwapIngredient,
    ),
  );
}

class MealSheet extends ConsumerStatefulWidget {
  const MealSheet({
    super.key,
    required this.meal,
    required this.onServings,
    required this.onSwap,
    required this.onRemove,
    this.onSwapIngredient,
  });

  final PlanMeal meal;
  final ValueChanged<int> onServings;

  /// Runs the remote-ack `swap_meal` with the picked replacement.
  final void Function(PlanMeal meal, MealRef replacement) onSwap;
  final VoidCallback onRemove;

  /// Runs the remote-ack `swap_ingredient` with the picked suggestion.
  final void Function(PlanMeal meal, IngredientSwap swap)? onSwapIngredient;

  @override
  ConsumerState<MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends ConsumerState<MealSheet> {
  bool _swapping = false;
  bool _swappingIngredient = false;

  /// The id `get_meal` wants: library id, else the saved uuid.
  String? get _detailId => widget.meal.libraryMealId ?? widget.meal.savedMealId;

  void _pickIngredientSwap(ContentService content, IngredientSwap swap) {
    // The snackbar goes up before the pop so the host's messenger (above
    // the modal route) is the one showing it.
    MealvanaSnackbar.showInfo(
      context,
      ContentKeys.format(content.getValue(ContentKeys.mpSwappedToast), {
        'from': swap.from,
        'to': swap.to,
      }),
    );
    Navigator.of(context).pop();
    widget.onSwapIngredient?.call(widget.meal, swap);
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);

    return SafeArea(
      child: ConstrainedBox(
        // The swap picker stacks up to 8 candidate cards and the ingredient
        // swap list another block — without the scroll the sheet's column
        // overflows the screen (05 §4 walkthrough).
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: icon · name · slot, as on the plan tile sheet.
                Row(
                  children: [
                    MealIconTile(
                      icon:
                          widget.meal.icon ??
                          MealIconClassifier.classify(name: widget.meal.name),
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.meal.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.foodTitle.copyWith(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SlotChip(type: widget.meal.mealType, short: true),
                  ],
                ),
                if (widget.meal.kcal != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    ContentKeys.format(
                      content.getValue(ContentKeys.mpPerServingMacros),
                      {
                        'kcal': widget.meal.kcal,
                        'c': (widget.meal.carbsG ?? 0).round(),
                        'p': (widget.meal.proteinG ?? 0).round(),
                      },
                    ),
                    style: AppTextStyles.bodySmall.copyWith(color: secondary),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        content.getValue(ContentKeys.mpServingsLabel),
                        key: const ValueKey(
                          'meal_planning.meal_sheet.servings',
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: textColor,
                        ),
                      ),
                    ),
                    ServingsStepper(
                      value: widget.meal.servings,
                      max: 14,
                      onChanged: widget.onServings,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (!_swapping)
                  Row(
                    children: [
                      Expanded(
                        child: KyleSecondaryButton(
                          key: const ValueKey('meal_planning.meal_sheet.swap'),
                          text: content.getValue(ContentKeys.mpBtnSwap),
                          height: 44,
                          onPressed: () => setState(() => _swapping = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: KyleSecondaryButton(
                          key: const ValueKey(
                            'meal_planning.meal_sheet.remove',
                          ),
                          text: content.getValue(ContentKeys.mpBtnRemove),
                          height: 44,
                          variant: SecondaryButtonVariant.dragonfruit,
                          onPressed: widget.onRemove,
                        ),
                      ),
                    ],
                  ),
                if (_swapping)
                  ConstrainedBox(
                    // The picker's candidates scroll inside this window so the
                    // sheet never grows past the screen.
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: SingleChildScrollView(
                      child: SwapPicker(
                        mealType: widget.meal.mealType,
                        onPick: (replacement) {
                          Navigator.of(context).pop();
                          widget.onSwap(widget.meal, replacement);
                        },
                      ),
                    ),
                  ),
                if (widget.onSwapIngredient != null && _detailId != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  if (!_swappingIngredient)
                    KyleSecondaryButton(
                      key: const ValueKey(
                        'meal_planning.meal_sheet.swap_ingredient',
                      ),
                      text: content.getValue(ContentKeys.mpSwapIngredient),
                      height: 44,
                      onPressed: () => setState(() {
                        _swappingIngredient = true;
                        _swapping = false;
                      }),
                    )
                  else
                    _IngredientSwapList(
                      detailId: _detailId!,
                      onPick: (swap) => _pickIngredientSwap(content, swap),
                    ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: ChoiceChipButton(
                    label: content.getValue(ContentKeys.mpSheetDone),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The meal's ingredients (from `get_meal`) and, under them, the library's
/// swap suggestions as tappable rows — "water → milk · +10g protein".
class _IngredientSwapList extends ConsumerWidget {
  const _IngredientSwapList({required this.detailId, required this.onPick});

  final String detailId;
  final ValueChanged<IngredientSwap> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    final detail = ref.watch(mealDetailControllerProvider(detailId));

    return switch (detail) {
      AsyncData(value: final MealDetail d) => Column(
        key: const ValueKey('meal_planning.meal_sheet.ingredient_swaps'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.ingredients.isNotEmpty) ...[
            Text(
              content
                  .getValue(ContentKeys.mpSwapIngredientIngredients)
                  .toUpperCase(),
              style: AppTextStyles.overline.copyWith(color: secondary),
            ),
            const SizedBox(height: 4),
            Text(
              [
                for (final i in d.ingredients)
                  i.qty.isEmpty ? i.name : '${i.name} (${i.qty})',
              ].join(' · '),
              style: AppTextStyles.bodySmall.copyWith(
                color: textColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            content.getValue(ContentKeys.mpSwapIngredient).toUpperCase(),
            style: AppTextStyles.overline.copyWith(color: secondary),
          ),
          if (IngredientSwap.parseAll(d.swaps) case final swaps
              when swaps.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                content.getValue(ContentKeys.mpSwapIngredientEmpty),
                key: const ValueKey('meal_planning.meal_sheet.no_swaps'),
                style: AppTextStyles.bodySmall.copyWith(color: secondary),
              ),
            )
          else
            for (final swap in IngredientSwap.parseAll(d.swaps))
              InkWell(
                key: ValueKey(
                  'meal_planning.meal_sheet.swap_${swap.from}_${swap.to}',
                ),
                onTap: () => onPick(swap),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: swap.from),
                              TextSpan(
                                text: '  →  ',
                                style: TextStyle(color: secondary),
                              ),
                              TextSpan(
                                text: swap.to,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (swap.effect != null)
                                TextSpan(
                                  text: ' · ${swap.effect}',
                                  style: TextStyle(color: accent),
                                ),
                            ],
                          ),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: textColor,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: textColor.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
      AsyncError() => Text(
        content.getValue(ContentKeys.mpServerError),
        style: AppTextStyles.bodySmall.copyWith(color: secondary),
      ),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    };
  }
}

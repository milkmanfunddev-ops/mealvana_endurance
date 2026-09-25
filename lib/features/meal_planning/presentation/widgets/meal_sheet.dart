import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/utils/adaptive_modal.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../data/vana_exceptions.dart';
import '../../domain/ingredient_swap.dart';
import '../../domain/meal_detail.dart';
import '../../domain/meal_ref.dart';
import '../../domain/plan_meal.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../shared/widgets/kyle_design/buttons/secondary_button.dart';
import '../../application/meal_detail_controller.dart';
import 'choice_chip_button.dart';
import 'slot_chip.dart';
import 'stepper.dart';
import 'swap_picker.dart';

/// Opens the plan meal sheet (05 §4, mp-239 detail 2): servings stepper ·
/// Ate it · Swap (expands an inline [SwapPicker]) · Remove · Swap an
/// ingredient (expands the meal's ingredient list with the library's swap
/// suggestions — plan Phase 6.3) · Recipe. The chat and the Plan tab share
/// it. Controller calls stay with the caller — the sheet reports intents;
/// [onAteIt], [onOpenRecipe] and [onSwapIngredient] are optional so hosts
/// without the action wired simply do not show the row.
Future<void> showMealSheet({
  required BuildContext context,
  required WidgetRef ref,
  required PlanMeal meal,
  required ValueChanged<int> onServings,
  required void Function(PlanMeal meal, MealRef replacement) onSwap,
  required VoidCallback onRemove,
  void Function(PlanMeal meal, IngredientSwap swap)? onSwapIngredient,
  Future<void> Function(PlanMeal meal)? onAteIt,
  ValueChanged<PlanMeal>? onOpenRecipe,
  ProviderListenable<PlanMeal?>? liveMeal,
  Set<String> excludeIds = const {},
}) {
  return showAdaptiveModal<void>(
    context: context,
    builder: (sheetContext) => MealSheet(
      meal: meal,
      onServings: onServings,
      onSwap: onSwap,
      onRemove: onRemove,
      onSwapIngredient: onSwapIngredient,
      onAteIt: onAteIt,
      onOpenRecipe: onOpenRecipe,
      liveMeal: liveMeal,
      excludeIds: excludeIds,
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
    this.onAteIt,
    this.onOpenRecipe,
    this.liveMeal,
    this.excludeIds = const {},
  });

  /// The meal as it was when the sheet opened. With [liveMeal], the sheet
  /// follows that instead while it has the row, so the stepper and Ate it
  /// show the servings the plan holds now.
  final PlanMeal meal;

  /// The row in the plan the host shows, watched while the sheet is open.
  final ProviderListenable<PlanMeal?>? liveMeal;

  /// "Ate it" (mp-239 detail 4): the remote-ack `log_from_plan`. The sheet
  /// waits for it: done, it says so and closes; refused, it says why and
  /// stays, the row as it was. Hidden when the row has no servings left.
  final Future<void> Function(PlanMeal meal)? onAteIt;

  /// The meal's detail page, with Start cooking (Lee, 2026-09-25: the row
  /// tap opens this sheet, so the sheet keeps the way to the recipe). The
  /// sheet closes first.
  final ValueChanged<PlanMeal>? onOpenRecipe;

  /// Library / saved ids of the plan's meals: the Swap list never offers
  /// them. The meal itself is always left out (testing-wave 88-009).
  final Set<String> excludeIds;

  /// The ids a host passes as [excludeIds] for a plan holding [meals].
  static Set<String> planMealIds(Iterable<PlanMeal> meals) =>
      meals.map((m) => m.libraryMealId ?? m.savedMealId).nonNulls.toSet();
  final ValueChanged<int> onServings;

  /// Runs the remote-ack `swap_meal` with the picked replacement.
  final void Function(PlanMeal meal, MealRef replacement) onSwap;

  /// The row leaves the plan; the sheet closes first, as a Swap pick does.
  final VoidCallback onRemove;

  /// Runs the remote-ack `swap_ingredient` with the picked suggestion.
  final void Function(PlanMeal meal, IngredientSwap swap)? onSwapIngredient;

  @override
  ConsumerState<MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends ConsumerState<MealSheet> {
  bool _swapping = false;
  bool _swappingIngredient = false;

  /// Ate it is on the wire: the button spins and a second tap does nothing.
  bool _logging = false;

  /// Why the last Ate it did not land, shown in the sheet (a snackbar would
  /// sit under it).
  String? _ateItError;

  /// The row as the plan holds it now, else as it was when opened.
  PlanMeal get _meal {
    final live = widget.liveMeal;
    return (live == null ? null : ref.watch(live)) ?? widget.meal;
  }

  /// The id `get_meal` wants: library id, else the saved uuid.
  String? get _detailId => widget.meal.libraryMealId ?? widget.meal.savedMealId;

  Future<void> _ateIt(ContentService content, PlanMeal meal) async {
    final onAteIt = widget.onAteIt;
    if (onAteIt == null || _logging) return;
    setState(() {
      _logging = true;
      _ateItError = null;
    });
    try {
      await onAteIt(meal);
      if (!mounted) return;
      // Up before the pop, so the host's messenger shows it (as below).
      MealvanaSnackbar.showSuccess(
        context,
        content.getValue(ContentKeys.mpLoggedDoneToast),
      );
      Navigator.of(context).pop();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _logging = false;
        _ateItError = content.getValue(
          e is NeedsConnectionException || e is VanaOfflineException
              ? ContentKeys.mpNeedsConnection
              : ContentKeys.mpAteItFailed,
        );
      });
    }
  }

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
    final meal = _meal;

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
                // Header: placeholder · name · slot, as on the plan tile.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meal.name,
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
                    SlotChip(type: meal.mealType, short: true),
                  ],
                ),
                if (meal.kcal != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    ContentKeys.format(
                      content.getValue(ContentKeys.mpPerServingMacros),
                      {
                        'kcal': meal.kcal,
                        'c': (meal.carbsG ?? 0).round(),
                        'p': (meal.proteinG ?? 0).round(),
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
                      value: meal.servings,
                      max: 14,
                      onChanged: widget.onServings,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Ate it: while a serving is left (mp-239 detail 4).
                if (widget.onAteIt != null && meal.servingsLeft > 0) ...[
                  KylePrimaryButton(
                    key: const ValueKey('meal_planning.meal_sheet.ate_it'),
                    text: content.getValue(ContentKeys.mpAteIt),
                    height: 44,
                    isLoading: _logging,
                    onPressed: _logging ? null : () => _ateIt(content, meal),
                  ),
                  if (_ateItError case final String error) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      error,
                      key: const ValueKey(
                        'meal_planning.meal_sheet.ate_it_error',
                      ),
                      style: AppTextStyles.bodySmall.copyWith(color: secondary),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                ],
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
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onRemove();
                          },
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
                        excludeIds: {...widget.excludeIds, ?_detailId},
                        onPick: (replacement) {
                          Navigator.of(context).pop();
                          widget.onSwap(meal, replacement);
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
                if (widget.onOpenRecipe != null && _detailId != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  KyleSecondaryButton(
                    key: const ValueKey('meal_planning.meal_sheet.recipe'),
                    text: content.getValue(ContentKeys.mpSheetRecipe),
                    height: 44,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onOpenRecipe!(meal);
                    },
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

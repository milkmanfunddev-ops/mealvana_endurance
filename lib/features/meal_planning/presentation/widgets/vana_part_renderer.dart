import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_ref.dart';
import '../../domain/meal_type.dart';
import '../../domain/vana_part.dart';
import 'choice_chips.dart';
import 'confirmed_card.dart';
import 'day_card.dart';
import 'meal_picker_carousel.dart';
import 'picker_chips.dart';
import 'rule_chip.dart';
import 'staples_card.dart';

/// Everything the [VanaPartRenderer] needs from the screen, so the renderer
/// itself stays a pure function of part → widget (02 §3).
class VanaPartCallbacks {
  const VanaPartCallbacks({
    required this.onTapMeal,
    required this.onPickMeal,
    this.pickedIds = const {},
    this.coverageCovered = 0,
    this.coverageOf = 0,
    this.nextType,
    this.planHasMeals = false,
    this.chipsEnabled = true,
    required this.onChipPick,
    required this.onSomethingElse,
    required this.onAcceptRule,
    required this.onViewShopping,
  });

  /// Navigate to `/food/meals/:id`.
  final ValueChanged<MealRef> onTapMeal;

  /// Pick the meal into the draft plan (remote-ack `pick_meals`).
  final void Function(MealRef meal, int servings) onPickMeal;

  /// Ids picked in the current picker (multi mode ticks).
  final Set<String> pickedIds;

  // Chip-strip context (02 §6).
  final int coverageCovered;
  final int coverageOf;
  final MealType? nextType;
  final bool planHasMeals;
  final bool chipsEnabled;
  final ValueChanged<String> onChipPick;
  final VoidCallback onSomethingElse;

  /// `accept_rule` (remote-ack).
  final ValueChanged<VanaRulePart> onAcceptRule;

  /// Open the Shopping tab.
  final VoidCallback onViewShopping;
}

/// Switches a [VanaPart] to its widget (02 §3). `batch` parts are folded
/// into the plan controller upstream and never render; `brief` is legacy
/// and deliberately renders nothing; unknown kinds were already dropped at
/// parse time.
class VanaPartRenderer extends ConsumerWidget {
  const VanaPartRenderer({
    super.key,
    required this.part,
    required this.callbacks,
  });

  final VanaPart part;
  final VanaPartCallbacks callbacks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);

    switch (part) {
      case VanaChoicesPart p:
        return ChoiceChips(part: p, onTap: callbacks.onChipPick);
      case VanaMealPickerPart p:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MealPickerCarousel(
              title: p.title,
              meals: p.meals,
              multi: p.multi,
              pickedIds: callbacks.pickedIds,
              onPick: (meal) => callbacks.onPickMeal(meal, p.defaultServings),
            ),
            const SizedBox(height: AppSpacing.xs),
            PickerChips(
              covered: callbacks.coverageCovered,
              of: callbacks.coverageOf,
              nextType: callbacks.nextType,
              hasMeals: callbacks.planHasMeals,
              enabled: callbacks.chipsEnabled,
              onPick: callbacks.onChipPick,
              onSomethingElse: callbacks.onSomethingElse,
            ),
          ],
        );
      case VanaStaplesPart p:
        return StaplesCard(part: p, onTapMeal: callbacks.onTapMeal);
      case VanaRulePart p:
        return RuleChip(part: p, onAccept: () => callbacks.onAcceptRule(p));
      case VanaShoppingListPart p:
        return ConfirmedCard(part: p, onView: callbacks.onViewShopping);
      case VanaDayGuidancePart p:
        return DayCard(part: p, onTapMeal: callbacks.onTapMeal);
      case VanaMemorySavedPart p:
        return _MemorySavedRow(fact: p.memory.fact);
      case VanaLoggedPart p:
        return _LoggedRow(
          text: ContentKeys.format(content.getValue(ContentKeys.mpLoggedRow), {
            'name': p.name,
            'n': p.servingsLeft,
          }),
        );
      case VanaDayPart p:
        return _DayWidget(part: p);
      case VanaBatchPart():
      case VanaBriefPart():
        return const SizedBox.shrink();
    }
  }
}

class _MemorySavedRow extends ConsumerWidget {
  const _MemorySavedRow({required this.fact});

  final String fact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = (isDark ? AppColors.cream : AppColors.blackberry)
        .withValues(alpha: 0.65);

    return Text(
      ContentKeys.format(content.getValue(ContentKeys.mpMemorySavedRow), {
        'fact': fact,
      }),
      key: const ValueKey('meal_planning.memory_saved_row'),
      style: AppTextStyles.bodySmall.copyWith(
        color: secondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _LoggedRow extends StatelessWidget {
  const _LoggedRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    return Text(
      text,
      key: const ValueKey('meal_planning.logged_row'),
      style: AppTextStyles.bodySmall.copyWith(
        color: accent,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// `day` part — the Plan tab's day grid row: label + filled slot chips.
/// Chat shows it inline when `plan_day` runs from a conversation.
class _DayWidget extends StatelessWidget {
  const _DayWidget({required this.part});

  final VanaDayPart part;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          part.label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          [
            for (final slot in part.slots.filled) slot.wire,
          ].join(' · '),
          style: AppTextStyles.bodySmall.copyWith(color: secondary),
        ),
      ],
    );
  }
}

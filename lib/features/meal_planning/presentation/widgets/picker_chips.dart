import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_type.dart';
import 'slot_chip.dart';

/// The client-drawn chip strip under every `meal_picker` in a planning
/// conversation (02 §6 — never model-generated). Tapping a chip sends its
/// label as the next user message; `Something else…` focuses the composer.
///
/// The primary chip follows coverage: "That's my week" when the 14
/// lunch+dinner slots are covered, else "`Next: <type>`" for the next slot
/// Vana will fill, else "I like these". Filter chips appear once the plan
/// has at least one meal.
class PickerChips extends ConsumerWidget {
  const PickerChips({
    super.key,
    required this.covered,
    required this.of,
    this.nextType,
    required this.hasMeals,
    required this.onPick,
    required this.onSomethingElse,
    this.enabled = true,
  });

  /// Current plan coverage (lunch+dinner slots covered / total).
  final int covered;
  final int of;

  /// The slot the next picker will fill, when known.
  final MealType? nextType;

  /// Whether the draft plan has ≥1 meal (gates the filter chips).
  final bool hasMeals;
  final ValueChanged<String> onPick;
  final VoidCallback onSomethingElse;

  /// One chip of the strip has been acted on — all but
  /// `Something else…` disable until the next picker arrives.
  final bool enabled;

  String _primaryLabel(ContentService content) {
    if (of > 0 && covered >= of) {
      return content.getValue(ContentKeys.mpChipThatsMyWeek);
    }
    if (nextType != null) {
      return ContentKeys.format(content.getValue(ContentKeys.mpChipNextLabel), {
        'type': SlotChip.labelFor(content, nextType!),
      });
    }
    return content.getValue(ContentKeys.mpChipLikeThese);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final neutral = isDark ? AppColors.cream : AppColors.blackberry;

    final primary = _primaryLabel(content);
    final other = content.getValue(ContentKeys.mpChipOther);
    final somethingElse = content.getValue(ContentKeys.mpChipSomethingElse);

    Widget filter(String key) => _PickerChip(
      label: content.getValue(key),
      accent: neutral,
      emphasized: false,
      enabled: enabled,
      onTap: () => onPick(content.getValue(key)),
    );

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _PickerChip(
          label: primary,
          accent: accent,
          emphasized: true,
          enabled: enabled,
          onTap: () => onPick(primary),
        ),
        _PickerChip(
          label: other,
          accent: accent,
          emphasized: false,
          enabled: enabled,
          onTap: () => onPick(other),
        ),
        _PickerChip(
          label: somethingElse,
          accent: neutral,
          emphasized: false,
          enabled: true,
          onTap: onSomethingElse,
        ),
        if (hasMeals) ...[
          filter(ContentKeys.mpFilterNoRecipe),
          filter(ContentKeys.mpFilterProtein),
          filter(ContentKeys.mpFilterUnder20),
        ],
      ],
    );
  }
}

class _PickerChip extends StatelessWidget {
  const _PickerChip({
    required this.label,
    required this.accent,
    required this.emphasized,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final bool emphasized;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      key: ValueKey('meal_planning.picker_chip_$label'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: emphasized ? 0.16 : 0.06),
        border: Border.all(
          color: accent.withValues(alpha: emphasized ? 0.9 : 0.45),
          width: emphasized ? 1.4 : 1,
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: accent,
          fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );

    if (!enabled) {
      return Opacity(opacity: 0.45, child: chip);
    }
    return GestureDetector(onTap: onTap, child: chip);
  }
}

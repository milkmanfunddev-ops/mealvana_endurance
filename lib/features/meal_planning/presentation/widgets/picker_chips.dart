import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../domain/meal_type.dart';
import 'choice_chip_button.dart';
import 'slot_chip.dart';

/// Where a picker sits in the conversation — the screen wraps each
/// transcript turn in one so the strip can tell the first picker from the
/// rest without the part renderer carrying the flag (plan §5 Phase 2.3).
/// Absent (bare widget tests) reads as "first".
class VanaPickerScope extends InheritedWidget {
  const VanaPickerScope({
    super.key,
    required this.isFirstPicker,
    required super.child,
  });

  final bool isFirstPicker;

  static bool isFirstPickerOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<VanaPickerScope>()
          ?.isFirstPicker ??
      true;

  @override
  bool updateShouldNotify(VanaPickerScope oldWidget) =>
      oldWidget.isFirstPicker != isFirstPicker;
}

/// The client-drawn chip strip under every `meal_picker` in a planning
/// conversation (02 §6 — never model-generated). Tapping a chip sends its
/// label as the next user message; `Something else…` focuses the composer.
///
/// The primary chip follows coverage: "That's my week" when the 14
/// lunch+dinner slots are covered, else "`Next: <type>`" for the next slot
/// Vana will fill, else "I like these". Filter chips appear once the plan
/// has at least one meal. On the conversation's first picker, while the
/// draft is still empty, a leading "Draft my whole week" chip offers the
/// propose-first door (the server's `draftWeek` tool answers it).
class PickerChips extends ConsumerWidget {
  const PickerChips({
    super.key,
    required this.covered,
    required this.of,
    this.nextType,
    required this.hasMeals,
    required this.onPick,
    required this.onSomethingElse,
    this.onBrowse,
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

  /// "Browse meals" — open the catalog to pick straight into the draft.
  /// Null (no conversation id yet: the opener still streaming) renders the
  /// chip disabled. Like `Something else…`, it never spends the strip.
  final VoidCallback? onBrowse;

  /// One chip of the strip has been acted on — all but
  /// `Something else…` / `Browse meals` disable until the next picker
  /// arrives.
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
    final primary = _primaryLabel(content);
    final other = content.getValue(ContentKeys.mpChipOther);
    final somethingElse = content.getValue(ContentKeys.mpChipSomethingElse);
    final draftWeek = content.getValue(ContentKeys.mpChipDraftWeek);
    final browse = content.getValue(ContentKeys.mpChipBrowseMeals);
    final showDraftWeek = !hasMeals && VanaPickerScope.isFirstPickerOf(context);

    Widget filter(String key) => ChoiceChipButton(
      label: content.getValue(key),
      dense: true,
      enabled: enabled,
      onTap: () => onPick(content.getValue(key)),
    );

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        if (showDraftWeek)
          ChoiceChipButton(
            key: const ValueKey('meal_planning.chip_draft_week'),
            label: draftWeek,
            emphasized: true,
            enabled: enabled,
            onTap: () => onPick(draftWeek),
          ),
        ChoiceChipButton(
          label: primary,
          emphasized: true,
          enabled: enabled,
          onTap: () => onPick(primary),
        ),
        ChoiceChipButton(
          label: other,
          enabled: enabled,
          onTap: () => onPick(other),
        ),
        ChoiceChipButton(label: somethingElse, onTap: onSomethingElse),
        ChoiceChipButton(
          key: const ValueKey('meal_planning.chip_browse_meals'),
          label: browse,
          enabled: onBrowse != null,
          onTap: onBrowse ?? () {},
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../domain/meal_type.dart';
import 'meal_icon_glyphs.dart';

/// Small chip naming a day slot in the meal's slot colour (02 §7):
/// breakfast orange, lunch electrolyte-dark, dinner violet, snack dragonfruit.
/// Squared-off 6px corners and 11px bold text — the prototype's `.v-slot`.
class SlotChip extends ConsumerWidget {
  const SlotChip({
    super.key,
    required this.type,
    this.selected = false,
    this.onTap,
    this.enabled = true,
    this.short = false,
  });

  final MealType type;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  /// Use the abbreviated label.
  final bool short;

  /// The abbreviated label used where space is tight (plan-bar tiles, the
  /// review sheet): "Bfast" rather than "Breakfast".
  static String shortLabelFor(ContentService content, MealType type) =>
      switch (type) {
        MealType.breakfast => content.getValue(
          ContentKeys.mpMealTypeBreakfastShort,
        ),
        MealType.lunch => content.getValue(ContentKeys.mpMealTypeLunchShort),
        MealType.dinner => content.getValue(ContentKeys.mpMealTypeDinnerShort),
        MealType.snack => content.getValue(ContentKeys.mpMealTypeSnackShort),
      };

  static String labelFor(ContentService content, MealType type) => switch (
    type
  ) {
    MealType.breakfast => content.getValue(ContentKeys.mpMealTypeBreakfast),
    MealType.lunch => content.getValue(ContentKeys.mpMealTypeLunch),
    MealType.dinner => content.getValue(ContentKeys.mpMealTypeDinner),
    MealType.snack => content.getValue(ContentKeys.mpMealTypeSnack),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = mealTypeColor(type);
    final content = ref.read(contentServiceProvider);
    final label = short
        ? shortLabelFor(content, type)
        : labelFor(content, type);

    final chip = Container(
      key: ValueKey('meal_planning.slot_chip_${type.wire}'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? accent : accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          height: 1.4,
          color: selected ? AppColors.blackberry : accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (onTap == null || !enabled) {
      return Opacity(opacity: enabled ? 1 : 0.4, child: chip);
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: chip,
    );
  }
}

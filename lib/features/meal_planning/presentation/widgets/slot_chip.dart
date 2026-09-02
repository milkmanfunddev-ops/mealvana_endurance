import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../domain/meal_type.dart';
import 'meal_icon_glyphs.dart';

/// Small chip naming a day slot in the meal's slot colour (02 §7):
/// breakfast orange, lunch electrolyte-dark, dinner violet, snack dragonfruit.
class SlotChip extends ConsumerWidget {
  const SlotChip({
    super.key,
    required this.type,
    this.selected = false,
    this.onTap,
    this.enabled = true,
  });

  final MealType type;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = labelFor(ref.read(contentServiceProvider), type);

    final chip = Container(
      key: ValueKey('meal_planning.slot_chip_${type.wire}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? accent : accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: selected
              ? AppColors.blackberry
              : (isDark ? accent : accent),
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (onTap == null || !enabled) {
      return Opacity(opacity: enabled ? 1 : 0.4, child: chip);
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: chip,
    );
  }
}

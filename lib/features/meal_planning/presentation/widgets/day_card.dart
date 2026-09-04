import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_ref.dart';
import '../../domain/vana_part.dart';
import 'slot_chip.dart';
import 'vana_tag.dart';

/// `day_guidance` part — one day's note in an electrolyte-outlined card:
/// the day label and workout, the carb target folded into Vana's sentence,
/// and up to two suggestions as slot-chipped rows (05 §3).
class DayCard extends ConsumerWidget {
  const DayCard({super.key, required this.part, required this.onTapMeal});

  final VanaDayGuidancePart part;
  final ValueChanged<MealRef> onTapMeal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final surface = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;

    return Container(
      key: ValueKey('meal_planning.day_card_${part.date}'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VanaTag(label: part.label),
              if (part.workout != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    part.workout!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(color: secondary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // The note already says "carbs" often enough; only prepend the
          // target when it does not.
          Text.rich(
            _guidance(context, ref, textColor),
            style: AppTextStyles.bodyMedium.copyWith(
              color: textColor,
              height: 1.5,
            ),
          ),
          for (final meal in part.suggestions.take(2)) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => onTapMeal(meal),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  SlotChip(type: meal.mealType),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: meal.name),
                          if (meal.attribution.isNotEmpty)
                            TextSpan(
                              text: ' · ${meal.attribution}',
                              style: TextStyle(color: secondary),
                            ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "At least **290g carbs**, protein at every meal." — the carb target in
  /// bold unless Vana's note already carries one.
  TextSpan _guidance(BuildContext context, WidgetRef ref, Color textColor) {
    final content = ref.read(contentServiceProvider);
    if (RegExp('carb', caseSensitive: false).hasMatch(part.note)) {
      return TextSpan(text: part.note.replaceAll(RegExp(r'\.+$'), '.'));
    }
    final carbs = ContentKeys.format(
      content.getValue(ContentKeys.mpDayAtLeastCarbs),
      {'n': part.minCarbsG},
    );
    return TextSpan(
      children: [
        TextSpan(
          text: carbs,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(text: part.note.isEmpty ? '.' : ', ${part.note}.'),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_ref.dart';
import '../../domain/meal_source.dart';

/// The fact badges a meal card can carry (2026-09-03): plant-based · fast ·
/// low cal · no recipe. Each renders as a small tinted pill (the `VanaTag`
/// fill recipe, one tone per meaning) and taps open a short explanation.
enum MealBadgeKind { plantBased, fast, lowCal, noRecipe }

/// "Fast" — at or under this many prep minutes.
const int kFastPrepMinutes = 15;

/// "Low cal" — at or under this many kcal per serving.
const int kLowCalKcal = 400;

/// The badges a [MealRef] earns, in display order.
List<MealBadgeKind> mealBadgesFor(MealRef meal) => [
  if (meal.dietsOk.any((d) => d == 'vegetarian' || d == 'vegan'))
    MealBadgeKind.plantBased,
  if (meal.prepMinutes != null &&
      meal.prepMinutes! > 0 &&
      meal.prepMinutes! <= kFastPrepMinutes)
    MealBadgeKind.fast,
  if (meal.kcal != null && meal.kcal! <= kLowCalKcal) MealBadgeKind.lowCal,
  if (meal.kind == MealKind.assembly) MealBadgeKind.noRecipe,
];

class MealBadge extends ConsumerWidget {
  const MealBadge({super.key, required this.kind});

  final MealBadgeKind kind;

  String get _labelKey => switch (kind) {
    MealBadgeKind.plantBased => ContentKeys.mpBadgePlantBased,
    MealBadgeKind.fast => ContentKeys.mpBadgeFast,
    MealBadgeKind.lowCal => ContentKeys.mpBadgeLowCal,
    MealBadgeKind.noRecipe => ContentKeys.mpBadgeNoRecipe,
  };

  String get _infoKey => switch (kind) {
    MealBadgeKind.plantBased => ContentKeys.mpBadgePlantBasedInfo,
    MealBadgeKind.fast => ContentKeys.mpBadgeFastInfo,
    MealBadgeKind.lowCal => ContentKeys.mpBadgeLowCalInfo,
    MealBadgeKind.noRecipe => ContentKeys.mpBadgeNoRecipeInfo,
  };

  FaIconData get _icon => switch (kind) {
    MealBadgeKind.plantBased => FontAwesomeIcons.leaf,
    MealBadgeKind.fast => FontAwesomeIcons.bolt,
    MealBadgeKind.lowCal => FontAwesomeIcons.feather,
    MealBadgeKind.noRecipe => FontAwesomeIcons.puzzlePiece,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // One tone per meaning — same alpha recipe as VanaTag, text colour picked
    // for contrast on both grounds.
    final (fill, text) = switch (kind) {
      MealBadgeKind.plantBased => (
        AppColors.electrolyte,
        AppColors.electrolyteDark,
      ),
      MealBadgeKind.fast => (AppColors.orange, AppColors.orange),
      MealBadgeKind.lowCal => (
        AppColors.dragonfruit,
        isDark ? AppColors.dragonfruitLight : AppColors.dragonfruitDark,
      ),
      MealBadgeKind.noRecipe => (
        AppColors.yolk,
        isDark ? AppColors.cream : AppColors.blackberry,
      ),
    };

    return GestureDetector(
      key: ValueKey('meal_planning.meal_badge_${kind.name}'),
      onTap: () => _showInfo(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: fill.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fill.withValues(alpha: 0.45), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(_icon, size: 9, color: text),
            const SizedBox(width: 4),
            Text(
              content.getValue(_labelKey),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: text,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaIcon(_icon, size: 16, color: textColor),
                const SizedBox(width: 10),
                Text(
                  content.getValue(_labelKey),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: textColor,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              content.getValue(_infoKey),
              style: AppTextStyles.bodyMedium.copyWith(
                color: textColor,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../domain/meal_ref.dart';
import '../../domain/meal_source.dart';
import 'meal_badge.dart';

/// One card in a catalog rail: up to three lines of name, then the fact
/// badge strip underneath (plant-based · fast · low cal · no recipe — tap a
/// badge for what it means). The icon tile and the "no recipe · 12 min ·
/// 480 kcal" meta line were removed in the 2026-09-03 cleanup; the facts
/// live in the badges and the detail page. Mirrors the prototype's
/// `.v-railcard` — 188pt wide, 15pt corners, a cream hairline border.
class MealRailCard extends StatelessWidget {
  const MealRailCard({
    super.key,
    required this.meal,
    required this.onTap,
    this.width = 188,
    this.action,
  });

  final MealRef meal;
  final VoidCallback onTap;
  final double width;

  /// Optional action rendered top-right of the name (the browse screen's
  /// Add button); the name column narrows to make room.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    final badges = mealBadgesFor(meal);
    final isYours = meal.source == MealSource.saved;

    return SizedBox(
      width: width,
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: textColor.withValues(alpha: 0.14)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fixed three-line box keeps every card in the rail the same
                // height whether the name wraps once or three times.
                SizedBox(
                  height: 51,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          meal.name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: 6),
                        action!,
                      ],
                    ],
                  ),
                ),
                if (badges.isNotEmpty || isYours) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final badge in badges) MealBadge(kind: badge),
                      if (isYours)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: textColor.withValues(alpha: 0.25),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'Yours',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: textColor.withValues(alpha: 0.7),
                              height: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

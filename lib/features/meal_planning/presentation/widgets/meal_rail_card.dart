import 'dart:math' as math;

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

  static const double _nameFontSize = 13.5;
  static const double _nameLineHeight = 1.25;
  static const double _badgeFontSize = 10;
  static const double _padding = 12;

  /// The three-line name box, scaled with the athlete's text size (Finding
  /// 88-014): a fixed 51 px clipped the name at accessibility-large.
  static double nameBoxHeight(BuildContext context) =>
      (MediaQuery.textScalerOf(context).scale(_nameFontSize) *
              _nameLineHeight *
              3)
          .ceilToDouble();

  /// What a rail must give one card: padding, the name box, the gap and two
  /// rows of badges, plus a little slack — 132 at the default text size (the
  /// prototype's rail), taller as the text grows. A card whose badges need
  /// more rows than that clips them at the bottom rather than overflowing.
  static double railHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final badgeRow = scaler.scale(_badgeFontSize) * 1.2 + 6 + 1;
    final computed =
        _padding * 2 + nameBoxHeight(context) + 8 + badgeRow * 2 + 4 + 8;
    return math.max(132, computed.ceilToDouble());
  }

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
            padding: const EdgeInsets.all(_padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fixed three-line box keeps every card in the rail the same
                // height whether the name wraps once or three times.
                SizedBox(
                  height: nameBoxHeight(context),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          meal.name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _nameFontSize,
                            fontWeight: FontWeight.w600,
                            height: _nameLineHeight,
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
                  // Loose in the room the rail leaves, and clipped there: at
                  // a large text size the badges may need a third row, and
                  // the card must never paint the overflow stripe (88-014).
                  Flexible(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      clipBehavior: Clip.hardEdge,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: _badgeFontSize,
                                fontWeight: FontWeight.w600,
                                color: textColor.withValues(alpha: 0.7),
                                height: 1.2,
                              ),
                            ),
                          ),
                      ],
                    ),
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

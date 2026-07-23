import 'package:flutter/material.dart';
import '../../../theme/kyle_design/app_colors.dart';

/// Types of indicators that can be shown on calendar days
enum DayIndicatorType {
  activity, // Electrolyte/green - for activities
  event, // Orange - for events
  carbLoading, // Dragonfruit/pink - for carb loading days
}

/// Helper class for managing calendar day indicators
class CalendarDayIndicators {
  /// Get the color for a specific indicator type
  static Color getColor(DayIndicatorType type) {
    switch (type) {
      case DayIndicatorType.activity:
        return AppColors.electrolyte; // Green/cyan
      case DayIndicatorType.event:
        return AppColors.orange; // Orange
      case DayIndicatorType.carbLoading:
        return AppColors.dragonfruit; // Pink
    }
  }

  /// Build indicator dots for a day
  static List<Widget> buildDots({
    required Set<DayIndicatorType> indicators,
    double dotSize = 4.0,
    double spacing = 2.0,
  }) {
    if (indicators.isEmpty) return [];

    // Sort indicators in a consistent order
    final sortedIndicators = indicators.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    // Build dots
    final dots = <Widget>[];
    for (var i = 0; i < sortedIndicators.length; i++) {
      if (i > 0) {
        dots.add(SizedBox(width: spacing));
      }
      dots.add(
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: getColor(sortedIndicators[i]),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return dots;
  }
}

import 'package:flutter/material.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';

/// Card theme configurations for nutrition data display
class AppCardThemes {
  /// Card theme for nutrition information display
  static CardThemeData cardTheme(ColorScheme colorScheme) {
    return CardThemeData(
      color: colorScheme.surfaceContainerLow,
      shadowColor: colorScheme.shadow,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

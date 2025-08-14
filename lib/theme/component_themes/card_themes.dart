import 'package:flutter/material.dart';

/// Card theme configurations for nutrition data display
class AppCardThemes {
  /// Card theme for nutrition information display
  static CardThemeData cardTheme(ColorScheme colorScheme) {
    return CardThemeData(
      color: colorScheme.surfaceContainerLow,
      shadowColor: colorScheme.shadow,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
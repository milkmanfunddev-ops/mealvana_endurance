import 'package:flutter/material.dart';

/// AppBar theme configuration for consistent navigation styling
class AppBarThemes {
  /// AppBar theme for nutrition app screens
  static AppBarTheme appBarTheme(ColorScheme colorScheme, TextTheme textTheme) {
    return AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 2,
      surfaceTintColor: colorScheme.surfaceTint,
      shadowColor: colorScheme.shadow,
      
      // Title styling
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
      
      // Center titles for consistent look
      centerTitle: true,
      
      // Icon themes
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: 24,
      ),
      
      actionsIconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: 24,
      ),
    );
  }
}
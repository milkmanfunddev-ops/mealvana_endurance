import 'package:flutter/material.dart';

/// Button theme configurations for the nutrition app
class AppButtonThemes {
  /// ElevatedButton theme with nutrition app styling
  static ElevatedButtonThemeData elevatedButtonTheme(ColorScheme colorScheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: colorScheme.onPrimary,
        backgroundColor: colorScheme.primary,
        elevation: 2,
        shadowColor: colorScheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ).copyWith(
        // Different states
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.pressed)) {
            return colorScheme.primary.withValues(alpha: 0.8);
          }
          return colorScheme.primary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          }
          return colorScheme.onPrimary;
        }),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return 8;
          }
          if (states.contains(WidgetState.hovered)) {
            return 4;
          }
          return 2;
        }),
      ),
    );
  }

  /// OutlinedButton theme for secondary actions
  static OutlinedButtonThemeData outlinedButtonTheme(ColorScheme colorScheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// TextButton theme for tertiary actions
  static TextButtonThemeData textButtonTheme(ColorScheme colorScheme) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

/// Input decoration themes for forms and text fields
class AppInputThemes {
  /// InputDecoration theme for text fields and form inputs
  static InputDecorationTheme inputDecorationTheme(ColorScheme colorScheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,

      // Default border
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline, width: 1),
      ),

      // Enabled border
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline, width: 1),
      ),

      // Focused border
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),

      // Error border
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 1),
      ),

      // Focused error border
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),

      // Content padding
      contentPadding: const EdgeInsets.all(16),

      // Label style
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),

      // Floating label style
      floatingLabelStyle: TextStyle(color: colorScheme.primary, fontSize: 12),

      // Hint style
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        fontSize: 16,
      ),

      // Error style
      errorStyle: TextStyle(color: colorScheme.error, fontSize: 12),

      // Helper style
      helperStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
    );
  }
}

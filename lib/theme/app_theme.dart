import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'nutrition_theme_extension.dart';
import 'component_themes/button_themes.dart';
import 'component_themes/input_themes.dart';
import 'component_themes/card_themes.dart';
import 'component_themes/app_bar_themes.dart';

/// Main theme configuration for Mealvana Endurance
/// Implements Material Design 3 with nutrition-specific extensions
class AppTheme {
  // Use existing brand blue from UI/UX docs as seed color
  static const Color _seedColor = Color(0xFF3B82F6);

  /// Light theme configuration
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    final textTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(textTheme, colorScheme),
      extensions: const [
        NutritionThemeExtension.light,
      ],
      elevatedButtonTheme: AppButtonThemes.elevatedButtonTheme(colorScheme),
      inputDecorationTheme: AppInputThemes.inputDecorationTheme(colorScheme),
      cardTheme: AppCardThemes.cardTheme(colorScheme),
      appBarTheme: AppBarThemes.appBarTheme(colorScheme, textTheme),
    );
  }

  /// Dark theme configuration
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    final textTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(textTheme, colorScheme),
      extensions: const [
        NutritionThemeExtension.dark,
      ],
      elevatedButtonTheme: AppButtonThemes.elevatedButtonTheme(colorScheme),
      inputDecorationTheme: AppInputThemes.inputDecorationTheme(colorScheme),
      cardTheme: AppCardThemes.cardTheme(colorScheme),
      appBarTheme: AppBarThemes.appBarTheme(colorScheme, textTheme),
    );
  }

  /// Build text theme optimized for nutrition data display
  static TextTheme _buildTextTheme(TextTheme baseTheme, ColorScheme colorScheme) {
    return baseTheme.copyWith(
      // Large numbers for calories/macros
      displayLarge: GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        height: 1.1,
        color: colorScheme.onSurface,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        height: 1.1,
        color: colorScheme.onSurface,
      ),
      
      // Headlines for screens and sections
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 1.2,
        color: colorScheme.onSurface,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.3,
        color: colorScheme.onSurface,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: colorScheme.onSurface,
      ),

      // Body text for nutrition information and forms
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: colorScheme.onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: colorScheme.onSurface,
      ),

      // Labels for form inputs and nutrition labels
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: colorScheme.onSurfaceVariant,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
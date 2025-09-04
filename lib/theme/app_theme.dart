import 'package:flutter/material.dart';
import 'component_themes/button_themes.dart';
import 'component_themes/input_themes.dart';
import 'component_themes/card_themes.dart';
import 'component_themes/app_bar_themes.dart';

/// Main theme configuration for Mealvana Endurance
/// Implements Material Design 3 with nutrition-specific styling
/// Light mode only - no dark theme support
class AppTheme {
  // Brand Colors - Primary (Blues)
  static const Color primary900 = Color(0xFF001C71);
  static const Color primary600 = Color(0xFF3366FF);
  static const Color primary100 = Color(0xFFD6E0FF);
  static const Color primary50 = Color(0xFFE0E8FF);
  
  // Highlight Colors (Coral/Pink)
  static const Color highlight600 = Color(0xFFD92D20);
  static const Color highlight600Alt = Color(0xFFDC2597);
  static const Color highlight490 = Color(0xFFF97066);
  static const Color highlight400 = Color(0xFFFF8476);
  static const Color highlight290 = Color(0xFFFDA29B);
  static const Color highlight100 = Color(0xFFFEE4E2);
  static const Color highlight50 = Color(0xFFFEF3F2);
  
  // Base Colors
  static const Color baseBlack = Color(0xFF000000);
  static const Color baseCream = Color(0xFFF8F6EB);
  static const Color baseWhite = Color(0xFFFFFFFF);
  static const Color baseGrey = Color(0xFF667085);
  
  // Warning
  static const Color warning500 = Color(0xFFFFC629);

  // Macro-specific colors for nutrition data visualization
  static const Color proteinColor = Color(0xFFDC2597);      // Pink for protein
  static const Color carbsColor = Color(0xFFFFC629);        // Yellow for carbohydrates
  static const Color fatsColor = Color(0xFF3366FF);         // Blue for fats
  static const Color caloriesColor = Color(0xFF001C71);     // Dark blue for calories
  static const Color sodiumColor = Color(0xFFFFC629);       // Yellow for sodium
  static const Color fluidsColor = Color(0xFF3366FF);       // Blue for fluids
  
  // Status colors
  static const Color successColor = Color(0xFF4CAF50);      // Green for success
  static const Color warningColor = Color(0xFFD92D20);      // Red for warnings
  static const Color infoColor = Color(0xFF3366FF);         // Blue for info

  /// Light theme configuration (only theme)
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: primary600,
      onPrimary: baseWhite,
      secondary: highlight600,
      onSecondary: baseWhite,
      surface: baseWhite,
      onSurface: baseBlack,
      error: highlight600,
      onError: baseWhite,
      outline: baseGrey,
      surfaceContainerHighest: primary50,
      onSurfaceVariant: baseGrey,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(colorScheme),
      elevatedButtonTheme: AppButtonThemes.elevatedButtonTheme(colorScheme),
      inputDecorationTheme: AppInputThemes.inputDecorationTheme(colorScheme),
      cardTheme: AppCardThemes.cardTheme(colorScheme),
      appBarTheme: AppBarThemes.appBarTheme(colorScheme, _buildTextTheme(colorScheme)),
    );
  }

  /// Build text theme with custom fonts based on design system
  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      // Display styles - Using Sansita for large titles
      displayLarge: const TextStyle(
        fontFamily: 'Sansita',
        fontSize: 48,
        fontWeight: FontWeight.w900,
        height: 1.1,
      ),
      displayMedium: const TextStyle(
        fontFamily: 'Sansita',
        fontSize: 36,
        fontWeight: FontWeight.bold,
        height: 1.1,
      ),
      displaySmall: const TextStyle(
        fontFamily: 'Sansita',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
      
      // Headlines - Sansita for section headers
      headlineLarge: const TextStyle(
        fontFamily: 'Sansita',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'Sansita',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'Sansita',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),

      // Title styles
      titleLarge: const TextStyle(
        fontFamily: 'Sansita',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleMedium: const TextStyle(
        fontFamily: 'Sansita',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      titleSmall: const TextStyle(
        fontFamily: 'Sansita',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),

      // Body text - Apercu for readability
      bodyLarge: const TextStyle(
        fontFamily: 'Apercu',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodyMedium: const TextStyle(
        fontFamily: 'Apercu',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      bodySmall: const TextStyle(
        fontFamily: 'Apercu',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.3,
      ),

      // Labels - for form inputs and small text
      labelLarge: TextStyle(
        fontFamily: 'Apercu',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: colorScheme.onSurfaceVariant,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Apercu',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: colorScheme.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Apercu',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
  
  // Custom text styles based on design specs
  
  // Sansita-based styles
  static const TextStyle titleStyle = TextStyle(
    fontFamily: 'Sansita',
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle subtitleStyle = TextStyle(
    fontFamily: 'Sansita',
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle hintStyle = TextStyle(
    fontFamily: 'Sansita',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
  );
  
  static const TextStyle heading1Style = TextStyle(
    fontFamily: 'Sansita',
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle heading2Style = TextStyle(
    fontFamily: 'Sansita',
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle heading3Style = TextStyle(
    fontFamily: 'Sansita',
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle calendarStyle = TextStyle(
    fontFamily: 'Sansita',
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
  
  // Apercu-based styles
  static const TextStyle textStyle = TextStyle(
    fontFamily: 'Apercu',
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle textCrossedStyle = TextStyle(
    fontFamily: 'Apercu',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.lineThrough,
  );
  
  static const TextStyle noteStyle = TextStyle(
    fontFamily: 'Apercu',
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle linkStyle = TextStyle(
    fontFamily: 'Apercu',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.underline,
  );
  
  // Compadre-based style
  static const TextStyle selectionStyle = TextStyle(
    fontFamily: 'Compadre',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
  );
  
  // Helvetica-based nutrition text styles
  static const TextStyle nutritionRegularStyle = TextStyle(
    fontFamily: 'Helvetica',
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle nutritionRegularObliqueStyle = TextStyle(
    fontFamily: 'Helvetica',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
  );
  
  static const TextStyle nutritionFootnoteStyle = TextStyle(
    fontFamily: 'Helvetica',
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle nutritionBoldStyle = TextStyle(
    fontFamily: 'Helvetica',
    fontSize: 14,
    fontWeight: FontWeight.w900,
  );
  
  static const TextStyle nutritionTitleStyle = TextStyle(
    fontFamily: 'Helvetica',
    fontSize: 16,
    fontWeight: FontWeight.w900,
  );
  
  static const TextStyle nutritionLargeStyle = TextStyle(
    fontFamily: 'Helvetica',
    fontSize: 18,
    fontWeight: FontWeight.w900,
  );

  // Nutrition-specific custom text styles
  static const TextStyle macroLabelStyle = TextStyle(
    fontFamily: 'Helvetica',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: baseGrey,
  );
  
  static const TextStyle macroValueStyle = TextStyle(
    fontFamily: 'Helvetica',
    fontSize: 20,
    fontWeight: FontWeight.w900,
    color: baseBlack,
  );
  
  static const TextStyle calorieTitleStyle = TextStyle(
    fontFamily: 'Helvetica',
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: baseBlack,
  );
  
  static const TextStyle nutritionFactStyle = TextStyle(
    fontFamily: 'Helvetica',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: baseGrey,
  );

  // Shadow and effects constants
  static const BoxShadow dropShadow = BoxShadow(
    color: Color(0x1A000000),
    offset: Offset(0, 2),
    blurRadius: 4,
  );
  
  static const BoxShadow glowShadow = BoxShadow(
    color: Color(0x40FFFFFF),
    offset: Offset(0, 0),
    blurRadius: 10,
    spreadRadius: 2,
  );
  
  static const BoxShadow tabBarShadow = BoxShadow(
    color: Color(0x0D000000),
    offset: Offset(0, -1),
    blurRadius: 4,
  );
  
  static const BoxShadow checkboxDropShadow = BoxShadow(
    color: Color(0x0D000000),
    offset: Offset(0, 1),
    blurRadius: 2,
  );
}
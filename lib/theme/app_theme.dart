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
  // Brand Colors
  static const Color primary900 = Color(0xFF001C71);
  static const Color primary600 = Color(0xFF3366FF);
  static const Color primary100 = Color(0xFFD6E0FF);
  static const Color primary50 = Color(0xFFE0E8FF);
  
  // Highlight Colors
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

  /// Light theme configuration
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: primary600,
      onPrimary: baseWhite,
      secondary: highlight600,
      onSecondary: baseWhite,
      surface: baseWhite,
      onSurface: baseBlack,
      // background: baseCream, // Deprecated - using surface instead
      // onBackground: baseBlack, // Deprecated - using onSurface instead
      error: highlight600,
      onError: baseWhite,
      outline: baseGrey,
      surfaceContainerHighest: primary50,
      onSurfaceVariant: baseGrey,
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
    final colorScheme = ColorScheme.dark(
      primary: primary600,
      onPrimary: baseWhite,
      secondary: highlight490,
      onSecondary: baseBlack,
      surface: primary900,
      onSurface: baseWhite,
      // background: baseBlack, // Deprecated - using surface instead
      // onBackground: baseWhite, // Deprecated - using onSurface instead
      error: highlight490,
      onError: baseBlack,
      outline: baseGrey,
      surfaceContainerHighest: primary100,
      onSurfaceVariant: baseGrey,
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

  /// Build text theme with custom fonts based on design system
  static TextTheme _buildTextTheme(TextTheme baseTheme, ColorScheme colorScheme) {
    return baseTheme.copyWith(
      // Title - Sansita font
      displayLarge: GoogleFonts.sansita(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        height: 1.1,
        color: colorScheme.onSurface,
      ),
      displayMedium: GoogleFonts.sansita(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        height: 1.1,
        color: colorScheme.onSurface,
      ),
      
      // Headlines - Sansita for titles, headings
      headlineLarge: GoogleFonts.sansita(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 1.2,
        color: colorScheme.onSurface,
      ),
      headlineMedium: GoogleFonts.sansita(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.3,
        color: colorScheme.onSurface,
      ),
      headlineSmall: GoogleFonts.sansita(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: colorScheme.onSurface,
      ),

      // Body text - Apercu for text and notes
      bodyLarge: GoogleFonts.lato( // Using Lato as Apercu substitute
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: colorScheme.onSurface,
      ),
      bodyMedium: GoogleFonts.lato(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: colorScheme.onSurface,
      ),

      // Labels - for form inputs  
      labelLarge: GoogleFonts.lato(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: colorScheme.onSurfaceVariant,
      ),
      labelMedium: GoogleFonts.lato(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
  
  /// Custom text styles for specific use cases
  static TextStyle get titleStyle => GoogleFonts.sansita(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );
  
  static TextStyle get subtitleStyle => GoogleFonts.sansita(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle get heading1Style => GoogleFonts.sansita(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );
  
  static TextStyle get heading2Style => GoogleFonts.sansita(
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );
  
  static TextStyle get heading3Style => GoogleFonts.sansita(
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle get textStyle => GoogleFonts.lato(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );
  
  static TextStyle get noteStyle => GoogleFonts.lato(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
  
  static TextStyle get selectionStyle => GoogleFonts.roboto( // Using Roboto as Compadre substitute
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
  
  // Nutrition text styles - Helvetica
  static TextStyle get nutritionRegularStyle => GoogleFonts.roboto( // Using Roboto as Helvetica substitute
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
  
  static TextStyle get nutritionBoldStyle => GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );
  
  static TextStyle get nutritionTitleStyle => GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle get nutritionLargeStyle => GoogleFonts.roboto(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );
}
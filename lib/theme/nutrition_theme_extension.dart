import 'package:flutter/material.dart';

/// Custom theme extension for nutrition-specific colors and styles
/// Provides macro colors and nutrition-specific text styles
@immutable
class NutritionThemeExtension extends ThemeExtension<NutritionThemeExtension> {
  /// Macro-specific colors for nutrition data visualization
  final Color? proteinColor;    // Pink for protein
  final Color? carbsColor;      // Orange for carbohydrates
  final Color? fatsColor;       // Purple for fats
  final Color? caloriesColor;   // Blue for calories
  final Color? sodiumColor;     // Yellow for sodium
  final Color? fluidsColor;     // Light blue for fluids
  
  /// Status and feedback colors
  final Color? successColor;
  final Color? warningColor;
  final Color? infoColor;

  /// Custom text styles for nutrition labels and values
  final TextStyle? macroLabelStyle;
  final TextStyle? macroValueStyle;
  final TextStyle? calorieTitleStyle;
  final TextStyle? nutritionFactStyle;

  const NutritionThemeExtension({
    this.proteinColor,
    this.carbsColor,
    this.fatsColor,
    this.caloriesColor,
    this.sodiumColor,
    this.fluidsColor,
    this.successColor,
    this.warningColor,
    this.infoColor,
    this.macroLabelStyle,
    this.macroValueStyle,
    this.calorieTitleStyle,
    this.nutritionFactStyle,
  });

  @override
  NutritionThemeExtension copyWith({
    Color? proteinColor,
    Color? carbsColor,
    Color? fatsColor,
    Color? caloriesColor,
    Color? sodiumColor,
    Color? fluidsColor,
    Color? successColor,
    Color? warningColor,
    Color? infoColor,
    TextStyle? macroLabelStyle,
    TextStyle? macroValueStyle,
    TextStyle? calorieTitleStyle,
    TextStyle? nutritionFactStyle,
  }) {
    return NutritionThemeExtension(
      proteinColor: proteinColor ?? this.proteinColor,
      carbsColor: carbsColor ?? this.carbsColor,
      fatsColor: fatsColor ?? this.fatsColor,
      caloriesColor: caloriesColor ?? this.caloriesColor,
      sodiumColor: sodiumColor ?? this.sodiumColor,
      fluidsColor: fluidsColor ?? this.fluidsColor,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      infoColor: infoColor ?? this.infoColor,
      macroLabelStyle: macroLabelStyle ?? this.macroLabelStyle,
      macroValueStyle: macroValueStyle ?? this.macroValueStyle,
      calorieTitleStyle: calorieTitleStyle ?? this.calorieTitleStyle,
      nutritionFactStyle: nutritionFactStyle ?? this.nutritionFactStyle,
    );
  }

  @override
  NutritionThemeExtension lerp(
    ThemeExtension<NutritionThemeExtension>? other,
    double t,
  ) {
    if (other is! NutritionThemeExtension) {
      return this;
    }
    return NutritionThemeExtension(
      proteinColor: Color.lerp(proteinColor, other.proteinColor, t),
      carbsColor: Color.lerp(carbsColor, other.carbsColor, t),
      fatsColor: Color.lerp(fatsColor, other.fatsColor, t),
      caloriesColor: Color.lerp(caloriesColor, other.caloriesColor, t),
      sodiumColor: Color.lerp(sodiumColor, other.sodiumColor, t),
      fluidsColor: Color.lerp(fluidsColor, other.fluidsColor, t),
      successColor: Color.lerp(successColor, other.successColor, t),
      warningColor: Color.lerp(warningColor, other.warningColor, t),
      infoColor: Color.lerp(infoColor, other.infoColor, t),
      macroLabelStyle: TextStyle.lerp(macroLabelStyle, other.macroLabelStyle, t),
      macroValueStyle: TextStyle.lerp(macroValueStyle, other.macroValueStyle, t),
      calorieTitleStyle: TextStyle.lerp(calorieTitleStyle, other.calorieTitleStyle, t),
      nutritionFactStyle: TextStyle.lerp(nutritionFactStyle, other.nutritionFactStyle, t),
    );
  }

  /// Light theme nutrition extension
  static const light = NutritionThemeExtension(
    proteinColor: Color(0xFFE91E63),      // Pink
    carbsColor: Color(0xFFFF9800),        // Orange
    fatsColor: Color(0xFF9C27B0),         // Purple
    caloriesColor: Color(0xFF2196F3),     // Blue
    sodiumColor: Color(0xFFFFC107),       // Amber
    fluidsColor: Color(0xFF03DAC6),       // Cyan
    successColor: Color(0xFF4CAF50),      // Green
    warningColor: Color(0xFFF44336),      // Red
    infoColor: Color(0xFF2196F3),         // Blue
    macroLabelStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Color(0xFF757575),
    ),
    macroValueStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Color(0xFF212121),
    ),
    calorieTitleStyle: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Color(0xFF212121),
    ),
    nutritionFactStyle: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Color(0xFF424242),
    ),
  );

  /// Dark theme nutrition extension
  static const dark = NutritionThemeExtension(
    proteinColor: Color(0xFFF48FB1),      // Light pink
    carbsColor: Color(0xFFFFCC02),        // Light orange
    fatsColor: Color(0xFFCE93D8),         // Light purple
    caloriesColor: Color(0xFF64B5F6),     // Light blue
    sodiumColor: Color(0xFFFFD54F),       // Light amber
    fluidsColor: Color(0xFF4DD0E1),       // Light cyan
    successColor: Color(0xFF81C784),      // Light green
    warningColor: Color(0xFFE57373),      // Light red
    infoColor: Color(0xFF64B5F6),         // Light blue
    macroLabelStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Color(0xFFBDBDBD),
    ),
    macroValueStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Color(0xFFFFFFFF),
    ),
    calorieTitleStyle: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Color(0xFFFFFFFF),
    ),
    nutritionFactStyle: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Color(0xFFE0E0E0),
    ),
  );
}

/// Extension to easily access nutrition theme from BuildContext
extension NutritionThemeContext on BuildContext {
  NutritionThemeExtension get nutritionTheme =>
      Theme.of(this).extension<NutritionThemeExtension>()!;
}
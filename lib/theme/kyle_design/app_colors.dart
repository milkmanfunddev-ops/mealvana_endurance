import 'package:flutter/material.dart';

/// Kyle's Design System Color Palette
/// Exact hex values extracted from Figma
class AppColors {
  AppColors._();

  // === Core Colors ===

  // Blackberry (Dark theme background)
  static const Color blackberry = Color(0xFF3D1F47);
  static const Color blackberryLight = Color(0xFF4A2854);
  static const Color blackberryDark = Color(0xFF2D1535);

  // Input field background - brighter than blackberryLight for better contrast
  static const Color inputBackground = Color(0xFF5A3366);

  // Cream (Light theme background)
  static const Color cream = Color(0xFFF5F3ED);
  static const Color creamDark = Color(0xFFE8E6E0);

  // Orange (Primary actions)
  static const Color orange = Color(0xFFFF8B3D);
  static const Color orangeLight = Color(0xFFFFA05A);
  static const Color orangeDark = Color(0xFFE67A2E);

  // Electrolyte (Activity/food icons, positive actions)
  static const Color electrolyte = Color(0xFF5DE4D3);
  static const Color electrolyteLight = Color(0xFF7FEEE0);
  static const Color electrolyteDark = Color(0xFF3FD4C0);

  // Dragonfruit (Warnings, tertiary actions)
  static const Color dragonfruit = Color(0xFFE84393);
  static const Color dragonfruitLight = Color(0xFFF060A8);
  static const Color dragonfruitDark = Color(0xFFD0357E);

  // === Semantic Colors ===

  // Success (uses Electrolyte)
  static const Color success = electrolyte;

  // Error (uses Dragonfruit)
  static const Color error = dragonfruit;

  // Warning (uses Orange)
  static const Color warning = orange;

  // Info (uses Electrolyte)
  static const Color info = electrolyte;

  // === Neutral Colors ===

  // Inactive states
  static const Color inactive = Color(0xFF9B8AA3);

  // Disabled states
  static const Color disabled = Color(0xFF6B5C6F);

  // === Text Colors ===

  // Light theme text
  static const Color textLight = Color(0xFF381633);
  static const Color textLightSecondary = Color(0xFF666666);

  // Dark theme text
  static const Color textDark = Color(0xFFF8F6EB);
  static const Color textDarkSecondary = Color(0xFFCCCCCC);

  // === Border Colors ===

  // Light theme borders
  static const Color borderLight = Color(0xFF381633);
  static const Color borderLightSecondary = Color(0xFFE0E0E0);

  // Dark theme borders
  static const Color borderDark = Color(0xFFF8F6EB);
  static const Color borderDarkSecondary = Color(0xFF333333);

  // === Surface Colors ===

  // Light theme surfaces
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLightSecondary = Color(0xFFF9F9F9);

  // Dark theme surfaces
  static const Color surfaceDark = Color(0xFF4A2854);
  static const Color surfaceDarkSecondary = Color(0xFF381633);
}

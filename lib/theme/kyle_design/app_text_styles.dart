import 'package:flutter/material.dart';

/// Kyle's Design System Typography
/// Three typefaces with exact sizes from Figma
class AppTextStyles {
  AppTextStyles._();

  // === Font Families ===
  static const String sansita = 'Sansita';
  static const String compadre = 'Compadre';
  static const String apercu = 'Apercu';

  // === Headings (Sansita Bold) ===
  
  // Page titles (28px)
  static const TextStyle pageTitle = TextStyle(
    fontFamily: sansita,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  // Section titles (20px)
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: sansita,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  // Date/Time display (24px)
  static const TextStyle dateTime = TextStyle(
    fontFamily: sansita,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  // Date Picker Header (24px) - Smaller to fit year in header
  static const TextStyle datePickerHeader = TextStyle(
    fontFamily: apercu, // Changed from sansita to save space
    fontSize: 18, // Reduced to 18px (was 20, and before that 24)
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  // === Activity & Food Titles (Compadre Wide) ===
  
  // Activity titles (18px)
  static const TextStyle activityTitle = TextStyle(
    fontFamily: compadre,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: 0.5,
  );

  // Subtitles (16px)
  static const TextStyle subtitle = TextStyle(
    fontFamily: compadre,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.5,
  );

  // Descriptors (14px)
  static const TextStyle descriptor = TextStyle(
    fontFamily: compadre,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.5,
  );

  // Food titles (13px) - Uses Compadre wide font, sized for readability in narrow cards
  static const TextStyle foodTitle = TextStyle(
    fontFamily: compadre,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: 0,
  );

  // === Body & Data (Apercu) ===
  
  // Body large (16px)
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: apercu,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // Body medium (14px)
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: apercu,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // Data numbers (32px)
  static const TextStyle dataNumber = TextStyle(
    fontFamily: apercu,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  // Large data numbers (48px)
  static const TextStyle dataNumberLarge = TextStyle(
    fontFamily: apercu,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  // Input text (16px)
  static const TextStyle inputText = TextStyle(
    fontFamily: apercu,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // Small labels (12px)
  static const TextStyle smallLabel = TextStyle(
    fontFamily: apercu,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  // === Button Styles ===
  
  // Primary button text (16px)
  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: sansita,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  // Tertiary button text (14px)
  static const TextStyle buttonTertiary = TextStyle(
    fontFamily: apercu,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  // === Specialized Styles ===
  
  // Segmented control text (12px)
  static const TextStyle segmentedControl = TextStyle(
    fontFamily: sansita,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  // Tab selector text (12px)
  static const TextStyle tabSelector = TextStyle(
    fontFamily: apercu,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.5,
  );

  // Calendar day numbers (16px)
  static const TextStyle calendarDay = TextStyle(
    fontFamily: apercu,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  // Calendar day letters (12px)
  static const TextStyle calendarDayLetter = TextStyle(
    fontFamily: apercu,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.5,
  );

  // Macro labels (10px)
  static const TextStyle macroLabel = TextStyle(
    fontFamily: apercu,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.5,
  );

  // Nutrition facts (10px)
  static const TextStyle nutritionFact = TextStyle(
    fontFamily: apercu,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.5,
  );

  // === Marketing & Pro Screens (Traditional Heading Hierarchy) ===

  // h1 - Main page title (28px) - alias for pageTitle
  static const TextStyle h1 = pageTitle;

  // h2 - Large heading (24px) - alias for dateTime
  static const TextStyle h2 = dateTime;

  // h3 - Section heading (20px) - alias for sectionTitle
  static const TextStyle h3 = sectionTitle;

  // h4 - Subsection heading (18px) - alias for activityTitle
  static const TextStyle h4 = activityTitle;

  // h5 - Small heading (16px) - alias for subtitle
  static const TextStyle h5 = subtitle;

  // bodySmall - Small body text (12px)
  static const TextStyle bodySmall = TextStyle(
    fontFamily: apercu,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
}
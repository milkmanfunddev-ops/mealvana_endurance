/// Canonical macro accent colours for the Nutrition Diary surface.
///
/// Before this existed the daily-macros widgets disagreed: the macro breakdown
/// row used the brand palette (teal / orange / pink) while the hero card +
/// summary strip hardcoded a separate green / purple / red set. Every macro
/// widget now imports these four constants so the same nutrient is always the
/// same colour across the card, the comparison table, and the detail sheet.
///
/// Accents are mutually distinct and brand-aligned: orange (energy), teal
/// (carbs), violet (protein), pink (fat). They're tuned for use on small
/// labels and dots — data numbers should stay in the theme's text colour for
/// contrast, not the accent.
library;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Calories / energy accent.
const Color kMacroColorCalories = AppColors.orange;

/// Carbohydrate accent.
const Color kMacroColorCarbs = AppColors.electrolyteDark;

/// Protein accent — a muted brand violet, distinct from the calories orange.
const Color kMacroColorProtein = Color(0xFF8E6FD8);

/// Fat accent.
const Color kMacroColorFat = AppColors.dragonfruit;

/// Canonical per-meal-slot accent colours.
///
/// Replaces the off-brand orange/green/purple/red set that was previously
/// duplicated in both `slot_chip_selector.dart` and `meal_log_row.dart`. All
/// four map onto the brand palette so slot chips stay consistent with the rest
/// of the Nutrition Diary surface.
library;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/meal_slot.dart';

/// Brand accent colour for [slot]'s chip.
Color slotColor(MealSlot slot) {
  switch (slot) {
    case MealSlot.breakfast:
      return AppColors.orange;
    case MealSlot.lunch:
      return AppColors.electrolyteDark;
    case MealSlot.dinner:
      return const Color(0xFF8E6FD8); // brand violet (matches protein accent)
    case MealSlot.snack:
      return AppColors.dragonfruit;
  }
}

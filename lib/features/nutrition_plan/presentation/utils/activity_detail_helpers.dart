import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/food_item_data.dart';

/// Utility class for Activity Detail Screen
/// Contains formatting, mapping, and UI calculation logic
class ActivityDetailHelpers {
  // Private constructor to prevent instantiation
  ActivityDetailHelpers._();

  /// Format date as "Mon Jan 1, 2024"
  static String formatDate(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  /// Format date as short version "Jan 1, 2024"
  static String formatDateShort(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  /// Format time as "3:30pm" or "12:00am"
  static String formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute$period';
  }

  /// Format duration in minutes as "2h 30m" or "45m"
  static String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours > 0) {
      return '${hours}h ${mins}m';
    } else {
      return '${mins}m';
    }
  }

  /// Map ActivityType to KyleActivityType for Kyle's design system
  static KyleActivityType mapActivityType(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.running:
        return KyleActivityType.running;
      case ActivityType.cycling:
        return KyleActivityType.cycling;
      case ActivityType.swimming:
        return KyleActivityType.swimming;
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
      case ActivityType.brick:
        return KyleActivityType.triathlon; // Map brick to triathlon for now
    }
  }

  /// Map food name to KyleFoodType for icon display
  static KyleFoodType mapFoodType(String foodName) {
    final name = foodName.toLowerCase();

    if (name.contains('banana') || name.contains('fruit')) {
      return KyleFoodType.fruit;
    } else if (name.contains('bread') || name.contains('sandwich')) {
      return KyleFoodType.sandwich;
    } else if (name.contains('pasta')) {
      return KyleFoodType.pasta;
    } else if (name.contains('rice')) {
      return KyleFoodType.rice;
    } else if (name.contains('gel') || name.contains('gummy')) {
      return KyleFoodType.gel;
    } else if (name.contains('bar') || name.contains('energy')) {
      return KyleFoodType.energyBar;
    } else if (name.contains('drink') || name.contains('water') || name.contains('fluid')) {
      return KyleFoodType.drink;
    } else if (name.contains('protein') || name.contains('meat') || name.contains('chicken')) {
      return KyleFoodType.protein;
    } else if (name.contains('vegetable') || name.contains('carrot') || name.contains('salad')) {
      return KyleFoodType.vegetable;
    } else if (name.contains('snack') || name.contains('cookie') || name.contains('cracker')) {
      return KyleFoodType.snack;
    } else if (name.contains('supplement') || name.contains('pill') || name.contains('vitamin')) {
      return KyleFoodType.supplement;
    } else {
      return KyleFoodType.other;
    }
  }

  /// Get the appropriate icon for a food based on its name
  static IconData getFoodIcon(String foodName) {
    final name = foodName.toLowerCase();

    // Map generic foods to specific icons
    if (name.contains('apple') && !name.contains('applesauce')) {
      return FontAwesomeIcons.appleWhole;
    } else if (name.contains('applesauce') || name.contains('purée')) {
      return FontAwesomeIcons.bottleDroplet;
    } else if (name.contains('bagel')) {
      return FontAwesomeIcons.breadSlice;
    } else if (name.contains('banana')) {
      return FontAwesomeIcons.appleWhole;
    } else if (name.contains('berr')) { // matches berry/berries
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('chocolate milk')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('coconut water')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('coffee')) {
      return FontAwesomeIcons.mugHot;
    } else if (name.contains('date')) {
      return FontAwesomeIcons.appleWhole;
    } else if (name.contains('electrolyte drink mix')) {
      return FontAwesomeIcons.flask;
    } else if (name.contains('electrolyte tablet')) {
      return FontAwesomeIcons.pills;
    } else if (name.contains('energy bar')) {
      return FontAwesomeIcons.bars;
    } else if (name.contains('energy chew')) {
      return FontAwesomeIcons.candyCane;
    } else if (name.contains('energy waffle') || name.contains('stroopwafel')) {
      return FontAwesomeIcons.cookie;
    } else if (name.contains('fig bar')) {
      return FontAwesomeIcons.bars;
    } else if (name.contains('gel')) {
      return FontAwesomeIcons.droplet;
    } else if (name.contains('oatmeal')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('orange juice')) {
      return FontAwesomeIcons.glassWater;
    } else if (name.contains('peanut butter')) {
      return FontAwesomeIcons.jar;
    } else if (name.contains('pickle juice')) {
      return FontAwesomeIcons.vial;
    } else if (name.contains('pretzel')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('protein bar')) {
      return FontAwesomeIcons.bars;
    } else if (name.contains('protein powder')) {
      return FontAwesomeIcons.jar;
    } else if (name.contains('protein shake')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('salt packet')) {
      return FontAwesomeIcons.bagShopping;
    } else if (name.contains('sports drink mix')) {
      return FontAwesomeIcons.flask;
    } else if (name.contains('sports drink')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('toast')) {
      return FontAwesomeIcons.breadSlice;
    } else if (name.contains('trail mix')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('water')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('yogurt')) {
      return FontAwesomeIcons.bowlFood;
    }

    // Default fallback icon
    return FontAwesomeIcons.utensils;
  }

  /// Determine if a food is user-imported (vs generic system food)
  static bool isUserImportedFood(FoodItemData food) {
    final name = food.name.toLowerCase();

    final knownGenericFoods = [
      'apple', 'applesauce', 'purée', 'bagel', 'banana', 'berr',
      'chocolate milk', 'coconut water', 'coffee', 'date',
      'electrolyte drink', 'electrolyte tablet', 'energy bar',
      'energy chew', 'energy waffle', 'stroopwafel', 'fig bar',
      'gel', 'oatmeal', 'orange juice', 'peanut butter',
      'pickle juice', 'pretzel', 'protein bar', 'protein powder',
      'protein shake', 'salt packet', 'sports drink', 'toast',
      'trail mix', 'water', 'yogurt',
    ];

    // If none of the generic food keywords are in the name, it's likely user-imported
    return !knownGenericFoods.any((keyword) => name.contains(keyword));
  }

  /// Get the background color for the food icon
  static Color getFoodIconColor(FoodItemData food) {
    // Use different color for user-imported foods
    if (isUserImportedFood(food)) {
      return AppColors.orange;
    }
    return AppColors.electrolyte;
  }

  /// Unified range-based color logic for macro values.
  ///
  /// When [low]/[high] are provided (range mode):
  ///   - Green: actual is within [low, high]
  ///   - Yellow: actual is within 20% margin outside range
  ///   - Red: actual is more than 20% outside range
  ///
  /// When only [target] is provided (ratio mode):
  ///   - Green: 80-120% of target
  ///   - Yellow: 60-80% or 120-150% of target
  ///   - Red: <60% or >150% of target
  static Color getMacroRangeColor(
    BuildContext context,
    int actual,
    int target, {
    int? low,
    int? high,
  }) {
    const inRangeColor = AppColors.electrolyte; // vibrant teal for on-target

    // Range mode: compare against band
    if (low != null && high != null && (low > 0 || high > 0)) {
      if (actual >= low && actual <= high) return inRangeColor;
      final margin = (high - low) * 0.2;
      if (actual >= low - margin && actual <= high + margin) {
        return AppColors.dragonfruit; // within 20% margin
      }
      return AppColors.dragonfruitDark; // >20% outside
    }

    // Ratio mode: compare against single target
    if (target <= 0) return inRangeColor;
    final ratio = actual / target;
    if (ratio >= 0.8 && ratio <= 1.2) return inRangeColor;
    if (ratio >= 0.6 && ratio <= 1.5) return AppColors.dragonfruit;
    return AppColors.dragonfruitDark;
  }

  /// Legacy alias — delegates to [getMacroRangeColor] in ratio mode.
  static Color getMacroDeviationColor(BuildContext context, int actual, int target) {
    return getMacroRangeColor(context, actual, target);
  }
}

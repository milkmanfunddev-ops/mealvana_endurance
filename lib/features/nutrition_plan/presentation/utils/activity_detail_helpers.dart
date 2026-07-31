import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../activities/domain/activity.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/nutrition_plan.dart';
import '../../domain/food_item_data.dart';
import '../../domain/macro_target_status.dart';

/// Utility class for Activity Detail Screen
/// Contains formatting, mapping, and UI calculation logic
class ActivityDetailHelpers {
  // Private constructor to prevent instantiation
  ActivityDetailHelpers._();

  /// Format date as "Mon Jan 1, 2024"
  static String formatDate(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  /// Format date as short version "Jan 1, 2024"
  static String formatDateShort(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  /// Format time as "3:30pm" or "12:00am"
  static String formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
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
      case ActivityType.other:
        return KyleActivityType.other;
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
    } else if (name.contains('drink') ||
        name.contains('water') ||
        name.contains('fluid')) {
      return KyleFoodType.drink;
    } else if (name.contains('protein') ||
        name.contains('meat') ||
        name.contains('chicken')) {
      return KyleFoodType.protein;
    } else if (name.contains('vegetable') ||
        name.contains('carrot') ||
        name.contains('salad')) {
      return KyleFoodType.vegetable;
    } else if (name.contains('snack') ||
        name.contains('cookie') ||
        name.contains('cracker')) {
      return KyleFoodType.snack;
    } else if (name.contains('supplement') ||
        name.contains('pill') ||
        name.contains('vitamin')) {
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
      return FontAwesomeIcons.appleWhole.data;
    } else if (name.contains('applesauce') || name.contains('purée')) {
      return FontAwesomeIcons.bottleDroplet.data;
    } else if (name.contains('bagel')) {
      return FontAwesomeIcons.breadSlice.data;
    } else if (name.contains('banana')) {
      return FontAwesomeIcons.appleWhole.data;
    } else if (name.contains('berr')) {
      // matches berry/berries
      return FontAwesomeIcons.bowlFood.data;
    } else if (name.contains('chocolate milk')) {
      return FontAwesomeIcons.bottleWater.data;
    } else if (name.contains('coconut water')) {
      return FontAwesomeIcons.bottleWater.data;
    } else if (name.contains('coffee')) {
      return FontAwesomeIcons.mugHot.data;
    } else if (name.contains('date')) {
      return FontAwesomeIcons.appleWhole.data;
    } else if (name.contains('electrolyte drink mix')) {
      return FontAwesomeIcons.flask.data;
    } else if (name.contains('electrolyte tablet')) {
      return FontAwesomeIcons.pills.data;
    } else if (name.contains('energy bar')) {
      return FontAwesomeIcons.bars.data;
    } else if (name.contains('energy chew')) {
      return FontAwesomeIcons.candyCane.data;
    } else if (name.contains('energy waffle') || name.contains('stroopwafel')) {
      return FontAwesomeIcons.cookie.data;
    } else if (name.contains('fig bar')) {
      return FontAwesomeIcons.bars.data;
    } else if (name.contains('gel')) {
      return FontAwesomeIcons.droplet.data;
    } else if (name.contains('oatmeal')) {
      return FontAwesomeIcons.bowlFood.data;
    } else if (name.contains('orange juice')) {
      return FontAwesomeIcons.glassWater.data;
    } else if (name.contains('peanut butter')) {
      return FontAwesomeIcons.jar.data;
    } else if (name.contains('pickle juice')) {
      return FontAwesomeIcons.vial.data;
    } else if (name.contains('pretzel')) {
      return FontAwesomeIcons.bowlFood.data;
    } else if (name.contains('protein bar')) {
      return FontAwesomeIcons.bars.data;
    } else if (name.contains('protein powder')) {
      return FontAwesomeIcons.jar.data;
    } else if (name.contains('protein shake')) {
      return FontAwesomeIcons.bottleWater.data;
    } else if (name.contains('salt packet')) {
      return FontAwesomeIcons.bagShopping.data;
    } else if (name.contains('sports drink mix')) {
      return FontAwesomeIcons.flask.data;
    } else if (name.contains('sports drink')) {
      return FontAwesomeIcons.bottleWater.data;
    } else if (name.contains('toast')) {
      return FontAwesomeIcons.breadSlice.data;
    } else if (name.contains('trail mix')) {
      return FontAwesomeIcons.bowlFood.data;
    } else if (name.contains('water')) {
      return FontAwesomeIcons.bottleWater.data;
    } else if (name.contains('yogurt')) {
      return FontAwesomeIcons.bowlFood.data;
    }

    // Default fallback icon
    return FontAwesomeIcons.utensils.data;
  }

  /// Determine if a food is user-imported (vs generic system food)
  static bool isUserImportedFood(FoodItemData food) {
    final name = food.name.toLowerCase();

    final knownGenericFoods = [
      'apple',
      'applesauce',
      'purée',
      'bagel',
      'banana',
      'berr',
      'chocolate milk',
      'coconut water',
      'coffee',
      'date',
      'electrolyte drink',
      'electrolyte tablet',
      'energy bar',
      'energy chew',
      'energy waffle',
      'stroopwafel',
      'fig bar',
      'gel',
      'oatmeal',
      'orange juice',
      'peanut butter',
      'pickle juice',
      'pretzel',
      'protein bar',
      'protein powder',
      'protein shake',
      'salt packet',
      'sports drink',
      'toast',
      'trail mix',
      'water',
      'yogurt',
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
    final inRangeColor = Theme.of(context).colorScheme.secondary;

    return switch (classifyMacroTarget(
      actual: actual,
      target: target,
      low: low,
      high: high,
    )) {
      MacroTargetStatus.green => inRangeColor,
      MacroTargetStatus.nonGreen => AppColors.dragonfruit,
      MacroTargetStatus.severe => AppColors.dragonfruitDark,
    };
  }

  /// Legacy alias — delegates to [getMacroRangeColor] in ratio mode.
  static Color getMacroDeviationColor(
    BuildContext context,
    int actual,
    int target,
  ) {
    return getMacroRangeColor(context, actual, target);
  }

  /// Returns completed duration when available, falling back to planned.
  static int? effectiveDurationMinutes(Activity? activity) {
    if (activity == null) return null;
    return activity.actualDurationMinutes ?? activity.durationMinutes;
  }

  /// Computes the during-workout carb rate (g/hr) shown to users for feedback.
  ///
  /// Returns null when feedback is not eligible:
  /// - no activity or plan
  /// - swimming workouts (no during carb intake)
  /// - effective duration < 90 minutes
  /// - no during section carb target
  static double? computeDuringCarbRateGPerH({
    required Activity? activity,
    required NutritionPlan? nutritionPlan,
    int minimumDurationMinutes = 90,
  }) {
    if (activity == null || nutritionPlan == null) return null;
    if (activity.activityType == ActivityType.swimming) {
      return null;
    }

    final durationMin = effectiveDurationMinutes(activity);
    if (durationMin == null || durationMin < minimumDurationMinutes) {
      return null;
    }

    final duringSection = nutritionPlan.sections
        .where((section) => section.id.contains('during'))
        .firstOrNull;
    final carbsTarget = duringSection?.carbsTarget;
    if (carbsTarget == null || carbsTarget <= 0) {
      return null;
    }

    return carbsTarget / (durationMin / 60.0);
  }

  static bool isCarbFeedbackEligible({
    required Activity? activity,
    required NutritionPlan? nutritionPlan,
    int minimumDurationMinutes = 90,
  }) {
    return computeDuringCarbRateGPerH(
          activity: activity,
          nutritionPlan: nutritionPlan,
          minimumDurationMinutes: minimumDurationMinutes,
        ) !=
        null;
  }
}

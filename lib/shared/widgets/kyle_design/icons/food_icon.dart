import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';


/// Food icon for Kyle's design system
/// 36px circular icon with Electrolyte background
class KyleFoodIcon extends ConsumerWidget {
  const KyleFoodIcon({
    super.key,
    required this.foodType,
    this.size = AppIconSizes.foodIcon,
    this.backgroundColor,
    this.iconColor,
  });

  final KyleFoodType foodType;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconData = _getIconForFoodType(foodType);
    final bgColor = backgroundColor ?? AppColors.electrolyte;
    final icColor = iconColor ?? AppColors.textLight;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: size * 0.5,
        color: icColor,
      ),
    );
  }

  IconData _getIconForFoodType(KyleFoodType type) {
    switch (type) {
      case KyleFoodType.energyBar:
        return FontAwesomeIcons.bars;
      case KyleFoodType.gel:
        return FontAwesomeIcons.jar;
      case KyleFoodType.drink:
        return FontAwesomeIcons.bottleWater;
      case KyleFoodType.fruit:
        return FontAwesomeIcons.appleWhole;
      case KyleFoodType.sandwich:
        return FontAwesomeIcons.burger;
      case KyleFoodType.pasta:
        return FontAwesomeIcons.bowlFood;
      case KyleFoodType.rice: 
        return FontAwesomeIcons.bowlRice;
      case KyleFoodType.protein:
        return FontAwesomeIcons.drumstickBite;
      case KyleFoodType.vegetable:
        return FontAwesomeIcons.carrot;
      case KyleFoodType.snack:
        return FontAwesomeIcons.cookie;
      case KyleFoodType.supplement:
        return FontAwesomeIcons.pills;
      case KyleFoodType.other:
        return FontAwesomeIcons.utensils;
    }
  }
}

/// Food icon with label
class KyleFoodIconWithLabel extends ConsumerWidget {
  const KyleFoodIconWithLabel({
    super.key,
    required this.foodType,
    required this.label,
    this.size = AppIconSizes.foodIcon,
    this.backgroundColor,
    this.iconColor,
    this.labelColor,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final KyleFoodType foodType;
  final String label;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? labelColor;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        KyleFoodIcon(
          foodType: foodType,
          size: size,
          backgroundColor: backgroundColor,
          iconColor: iconColor,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: labelColor ?? Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Food preference selector icon
class KyleFoodPreferenceIcon extends ConsumerWidget {
  const KyleFoodPreferenceIcon({
    super.key,
    required this.foodType,
    required this.preferenceLevel,
    required this.onTap,
    this.size = AppIconSizes.foodIcon,
  });

  final KyleFoodType foodType;
  final KylePreferenceLevel preferenceLevel;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = _getColorsForPreference(preferenceLevel);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: colors.borderColor,
            width: 2,
          ),
        ),
        child: Icon(
          _getIconForFoodType(foodType),
          size: size * 0.5,
          color: colors.iconColor,
        ),
      ),
    );
  }

  _PreferenceColors _getColorsForPreference(KylePreferenceLevel level) {
    switch (level) {
      case KylePreferenceLevel.avoid:
        return _PreferenceColors(
          backgroundColor: AppColors.dragonfruit.withOpacity(0.2),
          borderColor: AppColors.dragonfruit,
          iconColor: AppColors.dragonfruit,
        );
      case KylePreferenceLevel.dislike:
        return _PreferenceColors(
          backgroundColor: AppColors.orange.withOpacity(0.2),
          borderColor: AppColors.orange,
          iconColor: AppColors.orange,
        );
      case KylePreferenceLevel.neutral:
        return _PreferenceColors(
          backgroundColor: AppColors.electrolyte.withOpacity(0.2),
          borderColor: AppColors.electrolyte,
          iconColor: AppColors.electrolyte,
        );
      case KylePreferenceLevel.like:
        return _PreferenceColors(
          backgroundColor: AppColors.electrolyte.withOpacity(0.4),
          borderColor: AppColors.electrolyte,
          iconColor: AppColors.electrolyte,
        );
      case KylePreferenceLevel.love:
        return _PreferenceColors(
          backgroundColor: AppColors.electrolyte,
          borderColor: AppColors.electrolyte,
          iconColor: AppColors.textLight,
        );
    }
  }

  IconData _getIconForFoodType(KyleFoodType type) {
    switch (type) {
      case KyleFoodType.energyBar:
        return FontAwesomeIcons.bars;
      case KyleFoodType.gel:
        return FontAwesomeIcons.jar;
      case KyleFoodType.drink:
        return FontAwesomeIcons.bottleWater;
      case KyleFoodType.fruit:
        return FontAwesomeIcons.appleWhole;
      case KyleFoodType.sandwich:
        return FontAwesomeIcons.burger;
      case KyleFoodType.pasta:
        return FontAwesomeIcons.bowlFood;
      case KyleFoodType.rice:
        return FontAwesomeIcons.bowlRice;
      case KyleFoodType.protein:
        return FontAwesomeIcons.drumstickBite;
      case KyleFoodType.vegetable:
        return FontAwesomeIcons.carrot;
      case KyleFoodType.snack:
        return FontAwesomeIcons.cookie;
      case KyleFoodType.supplement:
        return FontAwesomeIcons.pills;
      case KyleFoodType.other:
        return FontAwesomeIcons.utensils;
    }
  }
}

/// Food types enum
enum KyleFoodType {
  energyBar,
  gel,
  drink,
  fruit,
  sandwich,
  pasta,
  rice,
  protein,
  vegetable,
  snack,
  supplement,
  other,
}

/// Preference levels enum
enum KylePreferenceLevel {
  avoid,    // 0 - Dragonfruit
  dislike,  // 1 - Orange
  neutral,  // 2 - Electrolyte light
  like,     // 3 - Electrolyte medium
  love,     // 4 - Electrolyte full
}

/// Extension to get display name for food types
extension KyleFoodTypeExtension on KyleFoodType {
  String get displayName {
    switch (this) {
      case KyleFoodType.energyBar:
        return 'Energy Bar';
      case KyleFoodType.gel:
        return 'Energy Gel';
      case KyleFoodType.drink:
        return 'Sports Drink';
      case KyleFoodType.fruit:
        return 'Fruit';
      case KyleFoodType.sandwich:
        return 'Sandwich';
      case KyleFoodType.pasta:
        return 'Pasta';
      case KyleFoodType.rice:
        return 'Rice';
      case KyleFoodType.protein:
        return 'Protein';
      case KyleFoodType.vegetable:
        return 'Vegetable';
      case KyleFoodType.snack:
        return 'Snack';
      case KyleFoodType.supplement:
        return 'Supplement';
      case KyleFoodType.other:
        return 'Other';
    }
  }
}

/// Helper class for preference colors
class _PreferenceColors {
  const _PreferenceColors({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
}
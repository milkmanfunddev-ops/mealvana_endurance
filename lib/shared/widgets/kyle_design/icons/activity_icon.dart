import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';

/// Activity icon for Kyle's design system
/// 36px circular icon with Electrolyte background
class KyleActivityIcon extends ConsumerWidget {
  const KyleActivityIcon({
    super.key,
    required this.activityType,
    this.size = AppIconSizes.activityIcon,
    this.backgroundColor,
    this.iconColor,
  });

  final KyleActivityType activityType;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconData = _getIconForActivityType(activityType);
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

  IconData _getIconForActivityType(KyleActivityType type) {
    switch (type) {
      case KyleActivityType.running:
        return FontAwesomeIcons.personRunning;
      case KyleActivityType.cycling:
        return FontAwesomeIcons.personBiking;
      case KyleActivityType.swimming:
        return FontAwesomeIcons.personSwimming;
      case KyleActivityType.triathlon:
        return FontAwesomeIcons.medal;
      case KyleActivityType.strength:
        return FontAwesomeIcons.dumbbell;
      case KyleActivityType.yoga:
        return FontAwesomeIcons.spa;
      case KyleActivityType.hiking:
        return FontAwesomeIcons.personHiking;
      case KyleActivityType.walking:
        return FontAwesomeIcons.personWalking;
      case KyleActivityType.other:
        return FontAwesomeIcons.circle;
    }
  }
}

/// Activity icon with label
class KyleActivityIconWithLabel extends ConsumerWidget {
  const KyleActivityIconWithLabel({
    super.key,
    required this.activityType,
    required this.label,
    this.size = AppIconSizes.activityIcon,
    this.backgroundColor,
    this.iconColor,
    this.labelColor,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final KyleActivityType activityType;
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
        KyleActivityIcon(
          activityType: activityType,
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

/// Activity type selector icon
class KyleActivityTypeSelectorIcon extends ConsumerWidget {
  const KyleActivityTypeSelectorIcon({
    super.key,
    required this.activityType,
    required this.isSelected,
    required this.onTap,
    this.size = AppIconSizes.activityIcon,
  });

  final KyleActivityType activityType;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = isSelected ? AppColors.electrolyte : AppColors.electrolyte.withOpacity(0.2);
    final icColor = isSelected ? AppColors.textLight : AppColors.electrolyte;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.electrolyte,
            width: isSelected ? 0 : 2,
          ),
        ),
        child: Icon(
          _getIconForActivityType(activityType),
          size: size * 0.5,
          color: icColor,
        ),
      ),
    );
  }

  IconData _getIconForActivityType(KyleActivityType type) {
    switch (type) {
      case KyleActivityType.running:
        return FontAwesomeIcons.personRunning;
      case KyleActivityType.cycling:
        return FontAwesomeIcons.personBiking;
      case KyleActivityType.swimming:
        return FontAwesomeIcons.personSwimming;
      case KyleActivityType.triathlon:
        return FontAwesomeIcons.medal;
      case KyleActivityType.strength:
        return FontAwesomeIcons.dumbbell;
      case KyleActivityType.yoga:
        return FontAwesomeIcons.spa;
      case KyleActivityType.hiking:
        return FontAwesomeIcons.personHiking;
      case KyleActivityType.walking:  
        return FontAwesomeIcons.personWalking;
      case KyleActivityType.other:
        return FontAwesomeIcons.circle;
    }
  }
}

/// Activity types enum
enum KyleActivityType {
  running,
  cycling,
  swimming,
  triathlon,
  strength,
  yoga,
  hiking,
  walking,
  other,
}

/// Extension to get display name for activity types
extension KyleActivityTypeExtension on KyleActivityType {
  String get displayName {
    switch (this) {
      case KyleActivityType.running:
        return 'Running';
      case KyleActivityType.cycling:
        return 'Cycling';
      case KyleActivityType.swimming:
        return 'Swimming';
      case KyleActivityType.triathlon:
        return 'Triathlon';
      case KyleActivityType.strength:
        return 'Strength';
      case KyleActivityType.yoga:
        return 'Yoga';
      case KyleActivityType.hiking:
        return 'Hiking';
      case KyleActivityType.walking:
        return 'Walking';
      case KyleActivityType.other:
        return 'Other';
    }
  }
}
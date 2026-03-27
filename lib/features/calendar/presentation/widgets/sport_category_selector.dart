import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/domain/activity_type.dart';

/// Kyle's Activity Type Selector for sport categories
///
/// Fixed-size buttons (62px × 74px) with Font Awesome icons and Compadre labels.
/// Follows Kyle's design system with Blackberry/Cream theme.
class SportCategorySelector extends StatelessWidget {
  const SportCategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final ActivityType selectedCategory;
  final ValueChanged<ActivityType> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sport Category',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ActivityType.values.map((category) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _SportCategoryButton(
                  category: category,
                  isSelected: selectedCategory == category,
                  onTap: () => onCategoryChanged(category),
                ),
              );
            }).toList(),
          ),
        ),
        ),
      ],
    );
  }
}

/// Individual button for a sport category (Kyle's Activity Type Selector)
class _SportCategoryButton extends StatelessWidget {
  const _SportCategoryButton({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final ActivityType category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected
        ? AppColors.blackberry
        : Theme.of(context).colorScheme.surface;
    final borderColor = isSelected
        ? AppColors.electrolyte
        : Theme.of(context).colorScheme.outline;
    final iconColor = isSelected
        ? AppColors.cream
        : Theme.of(context).colorScheme.onSurface;
    final textColor = isSelected
        ? AppColors.cream
        : Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        height: 74,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon (36px Font Awesome)
            FaIcon(
              _getIconForCategory(category),
              size: 36,
              color: iconColor,
            ),
            const SizedBox(height: 4),
            // Label (Compadre Regular 12px)
            Text(
              category.displayName,
              style: AppTextStyles.descriptor.copyWith(
                fontSize: 9,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForCategory(ActivityType category) {
    switch (category) {
      case ActivityType.running:
        return FontAwesomeIcons.personRunning;
      case ActivityType.cycling:
        return FontAwesomeIcons.personBiking;
      case ActivityType.swimming:
        return FontAwesomeIcons.personSwimming;
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
        return FontAwesomeIcons.trophy;
      case ActivityType.brick:
        return FontAwesomeIcons.link; // Chain link icon for brick workouts
    }
  }
}

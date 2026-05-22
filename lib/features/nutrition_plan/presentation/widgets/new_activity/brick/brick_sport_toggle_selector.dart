import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';

/// Brick Sport Toggle Selector
///
/// A horizontal row of toggle buttons for selecting sports in a brick workout.
/// Each sport shows an icon and name, with visual feedback for selection state.
/// Selected sports have a highlighted background and checkmark.
///
/// Minimum 2 sports must be selected for a valid brick workout.
class BrickSportToggleSelector extends StatelessWidget {
  final Set<String> selectedSports;
  final Function(String sport) onToggle;

  const BrickSportToggleSelector({
    super.key,
    required this.selectedSports,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final showValidation = selectedSports.length < 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sport toggle buttons in a row
        Row(
          children: [
            Expanded(
              child: _SportToggleButton(
                key: const ValueKey('brick.discipline_swim_chip'),
                sport: 'swimming',
                icon: FontAwesomeIcons.personSwimming,
                label: 'Swim',
                isSelected: selectedSports.contains('swimming'),
                onTap: () => _handleToggle('swimming'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SportToggleButton(
                key: const ValueKey('brick.discipline_bike_chip'),
                sport: 'cycling',
                icon: FontAwesomeIcons.personBiking,
                label: 'Bike',
                isSelected: selectedSports.contains('cycling'),
                onTap: () => _handleToggle('cycling'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SportToggleButton(
                key: const ValueKey('brick.discipline_run_chip'),
                sport: 'running',
                icon: FontAwesomeIcons.personRunning,
                label: 'Run',
                isSelected: selectedSports.contains('running'),
                onTap: () => _handleToggle('running'),
                isDark: isDark,
              ),
            ),
          ],
        ),

        // Validation message
        if (showValidation) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              'Select at least 2 sports',
              style: AppTextStyles.descriptor.copyWith(
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _handleToggle(String sport) {
    // Prevent deselecting if it would go below 2 selected sports
    final isSelected = selectedSports.contains(sport);
    if (isSelected && selectedSports.length <= 2) {
      return; // Don't allow deselecting if already at minimum
    }
    onToggle(sport);
  }
}

/// Individual sport toggle button
class _SportToggleButton extends StatelessWidget {
  final String sport;
  final FaIconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _SportToggleButton({
    super.key,
    required this.sport,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected
        ? AppColors.electrolyte.withValues(alpha: 0.2)
        : (isDark ? AppColors.blackberry : AppColors.cream).withValues(
            alpha: 0.5,
          );

    final borderColor = isSelected
        ? AppColors.electrolyte
        : (isDark ? AppColors.cream : AppColors.blackberry).withValues(
            alpha: 0.3,
          );

    final iconColor = isSelected
        ? AppColors.electrolyte
        : (isDark ? AppColors.cream : AppColors.blackberry).withValues(
            alpha: 0.7,
          );

    final textColor = isSelected
        ? AppColors.electrolyte
        : (isDark ? AppColors.cream : AppColors.blackberry);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sport icon with optional checkmark overlay
            Stack(
              alignment: Alignment.center,
              children: [
                FaIcon(icon, size: 28, color: iconColor),
                if (isSelected)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.electrolyte,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Sport label
            Text(
              label,
              style: AppTextStyles.descriptor.copyWith(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../providers/brick_input_controller.dart';

/// Brick "add a leg" row.
///
/// A horizontal row of Swim / Bike / Run buttons. Tapping one APPENDS a leg of
/// that sport to the brick — the same sport may be added more than once
/// (Run → Bike → Run), so these are not toggles. Buttons disable once the
/// brick holds [BrickFormState.maxLegs] legs. Legs are removed from their
/// cards, not here.
class BrickSportToggleSelector extends StatelessWidget {
  final int legCount;
  final bool canAdd;
  final ValueChanged<String> onAdd;

  const BrickSportToggleSelector({
    super.key,
    required this.legCount,
    required this.canAdd,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _AddLegButton(
                key: const ValueKey('brick.discipline_swim_chip'),
                icon: FontAwesomeIcons.personSwimming,
                label: 'Swim',
                enabled: canAdd,
                onTap: () => onAdd('swimming'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _AddLegButton(
                key: const ValueKey('brick.discipline_bike_chip'),
                icon: FontAwesomeIcons.personBiking,
                label: 'Bike',
                enabled: canAdd,
                onTap: () => onAdd('cycling'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _AddLegButton(
                key: const ValueKey('brick.discipline_run_chip'),
                icon: FontAwesomeIcons.personRunning,
                label: 'Run',
                enabled: canAdd,
                onTap: () => onAdd('running'),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            key: const ValueKey('brick.leg_count_hint'),
            canAdd
                ? 'Tap a sport to add a leg · $legCount of '
                      '${BrickFormState.maxLegs} legs'
                : 'Brick is full · ${BrickFormState.maxLegs} legs',
            style: AppTextStyles.descriptor.copyWith(
              color: onSurface.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// One add-a-leg button: `+` badge over the sport icon.
class _AddLegButton extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool isDark;

  const _AddLegButton({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark ? AppColors.blackberry : AppColors.cream;
    final ink = enabled
        ? AppColors.electrolyte
        : onSurface.withValues(alpha: 0.3);

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Add $label leg',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? AppColors.electrolyte.withValues(alpha: 0.6)
                  : onSurface.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  FaIcon(icon, size: 28, color: ink),
                  Positioned(
                    right: -10,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: enabled
                            ? AppColors.electrolyte
                            : onSurface.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        size: 10,
                        color: enabled ? AppColors.blackberry : surface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: AppTextStyles.descriptor.copyWith(
                  color: enabled ? onSurface : onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

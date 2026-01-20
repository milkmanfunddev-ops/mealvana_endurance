import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../../shared/widgets/kyle_design/inputs/plus_minus_control.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../activities/domain/brick_metadata.dart';

// Constants for control button styling
const double _controlSize = 40.0;
const double _controlIconSize = 20.0;
const double _borderRadius = 20.0;

/// Brick Running Section
///
/// Running-specific input fields for a brick segment:
/// - Distance (miles)
/// - Duration (minutes)
/// - Pace (/mile) - time input
/// - Intensity
///
/// Reuses input patterns from running_tab_content.dart
class BrickRunningSection extends StatelessWidget {
  const BrickRunningSection({
    super.key,
    required this.segment,
    required this.onChanged,
  });

  /// Current segment data (null if new)
  final BrickSegment? segment;

  /// Callback when any field changes
  final ValueChanged<BrickSegment> onChanged;

  void _updateSegment({
    double? distanceMiles,
    int? durationMinutes,
    double? paceMinutesPerMile,
    String? intensity,
  }) {
    final current = segment ??
        const BrickSegment(
          sport: 'running',
          order: 1,
          durationMinutes: 30,
          intensity: 'moderate',
          distanceMiles: 6.0,
          paceMinutesPerMile: 9.0,
        );

    onChanged(
      current.copyWith(
        distanceMiles: distanceMiles,
        durationMinutes: durationMinutes,
        paceMinutesPerMile: paceMinutesPerMile,
        intensity: intensity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distanceMiles = segment?.distanceMiles ?? 6.0;
    final durationMinutes = segment?.durationMinutes ?? 30;
    final paceMinutesPerMile = segment?.paceMinutesPerMile ?? 9.0;
    final intensity = segment?.intensity ?? 'moderate';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Distance (miles)
        KylePlusMinusDecimalControl(
          label: 'Distance',
          value: distanceMiles,
          onChanged: (value) => _updateSegment(distanceMiles: value),
          min: 0.1,
          max: 200.0,
          step: 1.0,
          decimalPlaces: 1,
          unit: 'miles',
          tappable: true,
        ),

        const SizedBox(height: AppSpacing.xl),

        // Duration (minutes)
        KylePlusMinusControl(
          label: 'Duration',
          value: durationMinutes,
          onChanged: (value) => _updateSegment(durationMinutes: value),
          min: 1,
          max: 480,
          step: 1,
          unit: 'minutes',
        ),

        const SizedBox(height: AppSpacing.xl),

        // Average Pace
        _PaceControl(
          paceMinutes: paceMinutesPerMile,
          onChanged: (value) => _updateSegment(paceMinutesPerMile: value),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Intensity Dropdown
        _KyleDropdown(
          label: 'Intensity',
          value: intensity,
          items: const {
            'easy': 'Easy',
            'moderate': 'Moderate',
            'hard': 'Hard',
            'race': 'Race',
          },
          onChanged: (value) => _updateSegment(intensity: value),
        ),
      ],
    );
  }
}

/// Custom pace control (reused from running_tab_content.dart)
class _PaceControl extends StatelessWidget {
  const _PaceControl({
    required this.paceMinutes,
    required this.onChanged,
  });

  final double paceMinutes;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    // Format as M:SS (e.g., 9:00)
    final minutes = paceMinutes.floor();
    final seconds = ((paceMinutes - minutes) * 60).round();
    final formattedPace = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Average Pace',
          style: AppTextStyles.descriptor.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Minus button
            _ControlButton(
              icon: FontAwesomeIcons.minus,
              onPressed: paceMinutes > 4.0
                  ? () => onChanged((paceMinutes - 0.08333).clamp(4.0, 20.0))
                  : null,
              enabled: paceMinutes > 4.0,
            ),
            const SizedBox(width: AppSpacing.xl),
            // Value display
            Expanded(
              child: Text(
                '$formattedPace MIN / MILE',
                style: AppTextStyles.dataNumber.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            // Plus button
            _ControlButton(
              icon: FontAwesomeIcons.plus,
              onPressed: paceMinutes < 20.0
                  ? () => onChanged((paceMinutes + 0.08333).clamp(4.0, 20.0))
                  : null,
              enabled: paceMinutes < 20.0,
            ),
          ],
        ),
      ],
    );
  }
}

/// Control button for plus/minus controls (reused from running_tab_content.dart)
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onPressed,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _controlSize,
      height: _controlSize,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: enabled
              ? Colors.orange
              : Colors.orange.withValues(alpha: 0.4),
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.orange.withValues(alpha: 0.4),
          elevation: 0,
          shadowColor: Colors.transparent,
          side: BorderSide(
            color: enabled
                ? Colors.orange
                : Colors.orange.withValues(alpha: 0.4),
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Icon(
          icon,
          size: _controlIconSize,
          color: enabled
              ? AppColors.cream  // White/cream icon color to match Kyle's design
              : AppColors.cream.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

/// Kyle-styled dropdown component (reused from running_tab_content.dart)
class _KyleDropdown extends StatelessWidget {
  const _KyleDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.descriptor.copyWith(
            color: isDark ? AppColors.cream : AppColors.blackberry,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.blackberry.withValues(alpha: 0.3)
                : AppColors.cream,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isDark ? AppColors.cream : AppColors.blackberry,
              width: 2,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              onChanged: (newValue) {
                if (newValue != null) onChanged(newValue);
              },
              style: AppTextStyles.dataNumber.copyWith(
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
              dropdownColor: isDark ? AppColors.blackberry : AppColors.cream,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
              isExpanded: true,
              items: items.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

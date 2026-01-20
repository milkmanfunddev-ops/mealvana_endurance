import 'package:flutter/material.dart';
import '../../../../../../shared/widgets/kyle_design/inputs/plus_minus_control.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../activities/domain/brick_metadata.dart';

/// Brick Cycling Section
///
/// Cycling-specific input fields for a brick segment:
/// - Distance (miles)
/// - Duration (minutes)
/// - Speed (mph)
/// - Terrain (flat, rolling, hilly)
/// - Indoor/Outdoor
/// - Elevation Gain (ft) - optional
/// - Intensity
///
/// Reuses input patterns from cycling_tab_content.dart
class BrickCyclingSection extends StatelessWidget {
  const BrickCyclingSection({
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
    double? speedMph,
    String? terrain,
    String? indoorOutdoor,
    int? elevationGainFt,
    String? intensity,
  }) {
    final current = segment ??
        const BrickSegment(
          sport: 'cycling',
          order: 1,
          durationMinutes: 60,
          intensity: 'moderate',
          distanceMiles: 20.0,
          speedMph: 20.0,
          terrain: 'flat',
          indoorOutdoor: 'outdoor',
          elevationGainFt: 0,
        );

    onChanged(
      current.copyWith(
        distanceMiles: distanceMiles,
        durationMinutes: durationMinutes,
        speedMph: speedMph,
        terrain: terrain,
        indoorOutdoor: indoorOutdoor,
        elevationGainFt: elevationGainFt,
        intensity: intensity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distanceMiles = segment?.distanceMiles ?? 20.0;
    final durationMinutes = segment?.durationMinutes ?? 60;
    final speedMph = segment?.speedMph ?? 20.0;
    final terrain = segment?.terrain ?? 'flat';
    final indoorOutdoor = segment?.indoorOutdoor ?? 'outdoor';
    final elevationGainFt = segment?.elevationGainFt ?? 0;
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
          max: 300.0,
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

        // Speed (mph)
        KylePlusMinusDecimalControl(
          label: 'Average Speed',
          value: speedMph,
          onChanged: (value) => _updateSegment(speedMph: value),
          min: 5.0,
          max: 40.0,
          step: 0.5,
          decimalPlaces: 1,
          unit: 'mph',
        ),

        const SizedBox(height: AppSpacing.xl),

        // Terrain Dropdown
        _KyleDropdown(
          label: 'Terrain',
          value: terrain,
          items: const {
            'flat': 'Flat',
            'rolling': 'Rolling',
            'hilly': 'Hilly',
          },
          onChanged: (value) => _updateSegment(terrain: value),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Indoor/Outdoor Dropdown
        _KyleDropdown(
          label: 'Indoor/Outdoor',
          value: indoorOutdoor,
          items: const {
            'indoor': 'Indoor',
            'outdoor': 'Outdoor',
          },
          onChanged: (value) => _updateSegment(indoorOutdoor: value),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Elevation Gain (feet)
        KylePlusMinusControl(
          label: 'Elevation Gain',
          value: elevationGainFt,
          onChanged: (value) => _updateSegment(elevationGainFt: value),
          min: 0,
          max: 20000,
          step: 50,
          unit: 'ft',
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

/// Kyle-styled dropdown component (reused from cycling_tab_content.dart)
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

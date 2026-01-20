import 'package:flutter/material.dart';
import '../../../../../../shared/widgets/kyle_design/inputs/plus_minus_control.dart';
import '../../../../../../shared/widgets/kyle_design/buttons/segmented_control.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../activities/domain/brick_metadata.dart';

/// Brick Swimming Section
///
/// Swimming-specific input fields for a brick segment:
/// - Distance (meters)
/// - Duration (minutes)
/// - Pace (/100m)
/// - Pool or Open Water
/// - Water Temperature (°C)
/// - Intensity
///
/// Reuses input patterns from swimming_tab_content.dart
class BrickSwimmingSection extends StatelessWidget {
  const BrickSwimmingSection({
    super.key,
    required this.segment,
    required this.onChanged,
  });

  /// Current segment data (null if new)
  final BrickSegment? segment;

  /// Callback when any field changes
  final ValueChanged<BrickSegment> onChanged;

  void _updateSegment({
    double? distanceMeters,
    int? durationMinutes,
    int? pacePer100mSeconds,
    String? poolOrOpenWater,
    double? waterTempC,
    String? intensity,
  }) {
    final current = segment ??
        const BrickSegment(
          sport: 'swimming',
          order: 1,
          durationMinutes: 30,
          intensity: 'moderate',
          distanceMeters: 1000,
          pacePer100mSeconds: 120,
          poolOrOpenWater: 'pool',
          waterTempC: 24.0,
        );

    onChanged(
      current.copyWith(
        distanceMeters: distanceMeters,
        durationMinutes: durationMinutes,
        pacePer100mSeconds: pacePer100mSeconds,
        poolOrOpenWater: poolOrOpenWater,
        waterTempC: waterTempC,
        intensity: intensity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final distanceMeters = segment?.distanceMeters ?? 1000;
    final durationMinutes = segment?.durationMinutes ?? 30;
    final pacePer100mSeconds = segment?.pacePer100mSeconds ?? 120;
    final poolOrOpenWater = segment?.poolOrOpenWater ?? 'pool';
    final waterTempC = segment?.waterTempC ?? 24.0;
    final intensity = segment?.intensity ?? 'moderate';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pool/Open Water Toggle
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pool or Open Water',
              style: AppTextStyles.descriptor.copyWith(
                color: isDark ? AppColors.cream : AppColors.blackberry,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            KyleSegmentedControl<_WaterType>(
              segments: _WaterType.values,
              selected: poolOrOpenWater == 'pool'
                  ? _WaterType.pool
                  : _WaterType.openWater,
              onChanged: (type) {
                _updateSegment(
                  poolOrOpenWater:
                      type == _WaterType.pool ? 'pool' : 'open_water',
                );
              },
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // Distance (meters)
        KylePlusMinusControl(
          label: 'Distance',
          value: distanceMeters.round(),
          onChanged: (value) => _updateSegment(distanceMeters: value.toDouble()),
          min: 100,
          max: 20000,
          step: 100,
          unit: 'meters',
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

        // Pace per 100m (seconds)
        KylePlusMinusControl(
          label: 'Pace per 100m',
          value: pacePer100mSeconds,
          onChanged: (value) => _updateSegment(pacePer100mSeconds: value),
          min: 60,
          max: 300,
          step: 5,
          unit: 'seconds',
        ),

        const SizedBox(height: AppSpacing.xl),

        // Water Temperature (°C)
        KylePlusMinusDecimalControl(
          label: 'Water Temperature',
          value: waterTempC,
          onChanged: (value) => _updateSegment(waterTempC: value),
          min: 10.0,
          max: 35.0,
          step: 0.5,
          decimalPlaces: 1,
          unit: '°C',
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

/// Water type enum for segmented control
enum _WaterType {
  pool,
  openWater,
}

/// Kyle-styled dropdown component (reused from swimming_tab_content.dart)
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
                ? AppColors.blackberry.withOpacity(0.3)
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

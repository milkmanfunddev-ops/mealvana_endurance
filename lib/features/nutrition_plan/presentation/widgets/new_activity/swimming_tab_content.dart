import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/inputs/plus_minus_control.dart';
import '../../../../../shared/widgets/kyle_design/buttons/segmented_control.dart';
import '../../providers/swimming_input_controller.dart';
import '../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../theme/kyle_design/app_colors.dart';

/// Swimming Tab Content
///
/// Sport-specific form fields for swimming activities:
/// - Pool/Open Water (toggle)
/// - Distance (meters)
/// - Pace per 100m (seconds)
/// - Time before Swim
/// - Intensity Target (dropdown)
/// - Session Goal (dropdown)
/// - Water Temperature
/// - Environment Section (collapsible)
///   - Deck Temperature, Deck Humidity
///
/// Status: Phase 2 - Full implementation with Kyle design components
class SwimmingTabContent extends ConsumerWidget {
  const SwimmingTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(swimmingInputControllerProvider);
    final controller = ref.read(swimmingInputControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

          // Pool/Open Water Toggle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Water Type',
                style: AppTextStyles.descriptor.copyWith(
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              KyleSegmentedControl<_WaterType>(
                segments: _WaterType.values,
                selected: formState.poolOrOpenWater == 'pool'
                    ? _WaterType.pool
                    : _WaterType.openWater,
                onChanged: (type) {
                  controller.updatePoolOrOpenWater(
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
            value: formState.distanceMeters,
            onChanged: controller.updateDistance,
            min: 100,
            max: 20000,
            step: 100,
            unit: 'meters',
          ),

          const SizedBox(height: AppSpacing.xl),

          // Pace per 100m (seconds)
          _PacePer100mControl(
            paceSeconds: formState.pacePer100mSeconds,
            onChanged: controller.updatePace,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Time before Swim
          KylePlusMinusControl(
            label: 'Time Before Swim',
            value: formState.preSwimMinutes,
            onChanged: controller.updatePreSwimMinutes,
            min: 0,
            max: 480,
            step: 15,
            unit: 'minutes',
          ),

          const SizedBox(height: AppSpacing.xl),

          // Intensity Target Dropdown
          _KyleDropdown(
            label: 'Intensity Target',
            value: formState.intensityTarget,
            items: const {
              'zone_1': 'Zone 1 - Easy',
              'zone_2': 'Zone 2 - Moderate',
              'zone_3': 'Zone 3 - Hard',
              'zone_4': 'Zone 4 - Very Hard',
            },
            onChanged: controller.updateIntensityTarget,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Session Goal Dropdown
          _KyleDropdown(
            label: 'Session Goal',
            value: formState.sessionGoal,
            items: const {
              'technique': 'Technique',
              'endurance': 'Endurance',
              'sets': 'Sets',
            },
            onChanged: controller.updateSessionGoal,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Water Temperature
          KylePlusMinusDecimalControl(
            label: 'Water Temperature',
            value: formState.waterTempC,
            onChanged: controller.updateWaterTemp,
            min: 10.0,
            max: 35.0,
            step: 0.5,
            decimalPlaces: 1,
            unit: '°C',
          ),

          const SizedBox(height: AppSpacing.xl),

          // Collapsible Deck Conditions Section
          _DeckConditionsSection(
            isExpanded: formState.showEnvironment,
            onToggle: controller.toggleEnvironmentSection,
            deckTemperature: formState.deckTemperature,
            onTemperatureChanged: controller.updateDeckTemperature,
            deckHumidity: formState.deckHumidity,
            onHumidityChanged: controller.updateDeckHumidity,
            isLoadingWeather: formState.isLoadingWeather,
            onFetchWeather: controller.fetchWeatherForecast,
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
    );
  }
}

/// Water type enum for segmented control
enum _WaterType {
  pool,
  openWater,
}

/// Custom pace per 100m control
class _PacePer100mControl extends StatelessWidget {
  const _PacePer100mControl({
    required this.paceSeconds,
    required this.onChanged,
  });

  final int paceSeconds;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // Note: KylePlusMinusControl handles integer display internally
    return KylePlusMinusControl(
      label: 'Pace per 100m',
      value: paceSeconds,
      onChanged: onChanged,
      min: 60,
      max: 300,
      step: 5,
      unit: 'seconds',
    );
  }
}

/// Kyle-styled dropdown component (reused from cycling)
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
            color: isDark ? AppColors.blackberry.withValues(alpha: 0.3) : AppColors.cream,
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
                size: 24,
              ),
              items: items.entries.map<DropdownMenuItem<String>>((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: AppTextStyles.dataNumber.copyWith(
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                      fontSize: 14,
                    ),
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

/// Collapsible Deck Conditions Section
class _DeckConditionsSection extends StatelessWidget {
  const _DeckConditionsSection({
    required this.isExpanded,
    required this.onToggle,
    required this.deckTemperature,
    required this.onTemperatureChanged,
    required this.deckHumidity,
    required this.onHumidityChanged,
    required this.isLoadingWeather,
    required this.onFetchWeather,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final double deckTemperature;
  final ValueChanged<double> onTemperatureChanged;
  final double deckHumidity;
  final ValueChanged<double> onHumidityChanged;
  final bool isLoadingWeather;
  final VoidCallback onFetchWeather;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with toggle
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.blackberry.withValues(alpha: 0.3) : AppColors.cream,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isDark ? AppColors.cream : AppColors.blackberry,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Deck Conditions',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  isExpanded
                      ? FontAwesomeIcons.chevronUp
                      : FontAwesomeIcons.chevronDown,
                  color: AppColors.orange,
                  size: 16,
                ),
              ],
            ),
          ),
        ),

        // Expanded content
        if (isExpanded) ...[
          const SizedBox(height: AppSpacing.lg),

          // Deck Temperature with Forecast
          Column(
            children: [
              KylePlusMinusDecimalControl(
                label: 'Deck Temperature',
                value: deckTemperature,
                onChanged: onTemperatureChanged,
                min: -5.0,
                max: 40.0,
                step: 1.0,
                decimalPlaces: 0,
                unit: '°C',
                enabled: !isLoadingWeather,
              ),
              const SizedBox(height: AppSpacing.sm),
              GestureDetector(
                onTap: isLoadingWeather ? null : onFetchWeather,
                child: Text(
                  isLoadingWeather ? 'Loading forecast...' : 'Forecast',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: isLoadingWeather
                        ? AppColors.dragonfruit.withValues(alpha: 0.4)
                        : AppColors.dragonfruit,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Deck Humidity
          KylePlusMinusDecimalControl(
            label: 'Deck Humidity',
            value: deckHumidity,
            onChanged: onHumidityChanged,
            min: 20.0,
            max: 95.0,
            step: 5.0,
            decimalPlaces: 0,
            unit: '%',
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/inputs/plus_minus_control.dart';
import '../../providers/cycling_input_controller.dart';
import '../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../theme/kyle_design/app_colors.dart';

/// Cycling Tab Content
///
/// Sport-specific form fields for cycling activities:
/// - Distance (miles)
/// - Speed (mph)
/// - Time before Ride
/// - Intensity Target (dropdown)
/// - Session Goal (dropdown)
/// - Terrain (dropdown)
/// - Elevation Gain (feet)
/// - Environment Section (collapsible)
///   - Temperature, Humidity, Wind, Sun Exposure
///
/// Status: Phase 2 - Full implementation with Kyle design components
class CyclingTabContent extends ConsumerWidget {
  const CyclingTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(cyclingInputControllerProvider);
    final controller = ref.read(cyclingInputControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

          // Distance
          KylePlusMinusDecimalControl(
            label: 'Distance',
            value: formState.distance,
            onChanged: controller.updateDistance,
            min: 0.1,
            max: 300.0,
            step: 1.0,
            decimalPlaces: 1,
            unit: 'miles',
            tappable: true,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Speed
          KylePlusMinusDecimalControl(
            label: 'Average Speed',
            value: formState.speedMph,
            onChanged: controller.updateSpeed,
            min: 5.0,
            max: 40.0,
            step: 0.5,
            decimalPlaces: 1,
            unit: 'mph',
          ),

          const SizedBox(height: AppSpacing.xl),

          // Time before Ride
          KylePlusMinusControl(
            label: 'Time Before Ride',
            value: formState.preRideMinutes,
            onChanged: controller.updatePreRideMinutes,
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
              'zone_1': 'Zone 1 - Recovery',
              'zone_2': 'Zone 2 - Endurance',
              'zone_3': 'Zone 3 - Tempo',
              'zone_4': 'Zone 4 - Threshold',
              'zone_5': 'Zone 5 - VO2 Max',
            },
            onChanged: controller.updateIntensityTarget,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Session Goal Dropdown
          _KyleDropdown(
            label: 'Session Goal',
            value: formState.sessionGoal,
            items: const {
              'endurance': 'Endurance',
              'tempo': 'Tempo',
              'intervals': 'Intervals',
            },
            onChanged: controller.updateSessionGoal,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Terrain Dropdown
          _KyleDropdown(
            label: 'Terrain & Aero Load',
            value: formState.terrain,
            items: const {
              'flat_indoor': 'Flat - Indoor',
              'flat_outdoor': 'Flat - Outdoor',
              'rolling_outdoor': 'Rolling - Outdoor',
              'hilly_outdoor': 'Hilly - Outdoor',
            },
            onChanged: controller.updateTerrain,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Elevation Gain
          KylePlusMinusControl(
            label: 'Elevation Gain',
            value: formState.elevationGainFt,
            onChanged: controller.updateElevationGain,
            min: 0,
            max: 20000,
            step: 100,
            unit: 'feet',
          ),

          const SizedBox(height: AppSpacing.xl),

          // Collapsible Environment Section
          _EnvironmentSection(
            isExpanded: formState.showEnvironment,
            onToggle: controller.toggleEnvironmentSection,
            temperatureC: formState.temperatureC,
            onTemperatureChanged: controller.updateTemperature,
            humidityPct: formState.humidityPct,
            onHumidityChanged: controller.updateHumidity,
            windCondition: formState.windCondition,
            onWindChanged: controller.updateWindCondition,
            sunExposure: formState.sunExposure,
            onSunChanged: controller.updateSunExposure,
            isLoadingWeather: formState.isLoadingWeather,
            onFetchWeather: controller.fetchWeatherForecast,
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
    );
  }
}

/// Kyle-styled dropdown component
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

/// Collapsible Environment Section
class _EnvironmentSection extends StatelessWidget {
  const _EnvironmentSection({
    required this.isExpanded,
    required this.onToggle,
    required this.temperatureC,
    required this.onTemperatureChanged,
    required this.humidityPct,
    required this.onHumidityChanged,
    required this.windCondition,
    required this.onWindChanged,
    required this.sunExposure,
    required this.onSunChanged,
    required this.isLoadingWeather,
    required this.onFetchWeather,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final double temperatureC;
  final ValueChanged<double> onTemperatureChanged;
  final double humidityPct;
  final ValueChanged<double> onHumidityChanged;
  final String windCondition;
  final ValueChanged<String> onWindChanged;
  final String sunExposure;
  final ValueChanged<String> onSunChanged;
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
                  'Environment Conditions',
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

          // Temperature with Forecast
          Column(
            children: [
              KylePlusMinusDecimalControl(
                label: 'Temperature',
                value: temperatureC,
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

          // Humidity
          KylePlusMinusDecimalControl(
            label: 'Humidity',
            value: humidityPct,
            onChanged: onHumidityChanged,
            min: 20.0,
            max: 95.0,
            step: 5.0,
            decimalPlaces: 0,
            unit: '%',
          ),

          const SizedBox(height: AppSpacing.lg),

          // Wind Condition
          _KyleDropdown(
            label: 'Wind Condition',
            value: windCondition,
            items: const {
              'still': 'Still',
              'breezy': 'Breezy',
              'windy': 'Windy',
            },
            onChanged: onWindChanged,
          ),

          const SizedBox(height: AppSpacing.lg),

          // Sun Exposure
          _KyleDropdown(
            label: 'Sun Exposure',
            value: sunExposure,
            items: const {
              'full_sun': 'Full Sun',
              'mixed': 'Mixed',
              'shade': 'Shade',
            },
            onChanged: onSunChanged,
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import '../../../../../shared/widgets/kyle_design/inputs/plus_minus_control.dart';
import '../../providers/cycling_input_controller.dart';
import '../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../shared/widgets/kyle_design/inputs/intensity_distribution_widget.dart';
import 'shared/workout_details_widget.dart';
import '../../../../../shared/domain/activity_type.dart';

import '../../../../../shared/widgets/kyle_design/inputs/indoor_outdoor_toggle.dart';
import 'shared/environment_section.dart';
import 'shared/fasted_toggle.dart';

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
    final isIndoor = formState.terrain.contains('indoor');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

          // WORKOUT DETAILS
          WorkoutDetailsWidget(
            sport: ActivityType.cycling,
            distance: formState.distance,
            distanceUnit: formState.distanceUnit == DistanceUnit.kilometers ? 'km' : 'mi',
            mode: formState.durationPaceMode,
            estimatedDuration: formState.estimatedDuration,
            pace: formState.speedMph,
            paceUnit: formState.distanceUnit == DistanceUnit.kilometers ? 'kph' : 'mph',
            onDistanceChanged: controller.updateDistance,
            onModeChanged: controller.updateDurationPaceMode,
            onPaceChanged: controller.updateSpeed,
            onDurationChanged: controller.updateDuration,
          ),

          const SizedBox(height: AppSpacing.xl),

          // INTENSITY DISTRIBUTION
          IntensityDistributionWidget(
            value: formState.intensity,
            onChanged: controller.updateIntensityDistribution,
            sportType: ActivityType.cycling,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Time before Ride
          KylePlusMinusControl(
            label: 'Pre-Ride Fueling Window',
            value: formState.preRideMinutes,
            onChanged: controller.updatePreRideMinutes,
            min: 0,
            max: 480,
            step: 15,
            unit: 'minutes',
          ),

          // FASTED TOGGLE
          FastedToggle(
            isFasted: formState.isFasted,
            onChanged: controller.updateFasted,
            showWarning: !FastedToggle.isSuitable(
              conversationalPct: formState.intensity.conversationalPct,
              estimatedDurationMinutes: formState.estimatedDuration?.inMinutes ?? 0,
              isSwimming: false,
            ),
            warningText: 'Fasted training is not recommended for longer or harder rides. Consider fueling before.',
          ),

          const SizedBox(height: AppSpacing.xl),

          // Indoor / Outdoor Toggle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Environment',
                style: AppTextStyles.descriptor.copyWith(
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              IndoorOutdoorToggle(
                isIndoor: isIndoor,
                onChanged: controller.updateIndoorOutdoor,
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Collapsible Environment Section
        EnvironmentSection(
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
          isIndoor: isIndoor,
          showWindAndSun: false,
          useImperial: formState.unitSystem == UnitSystem.imperial,
          isLoadingWeather: formState.isLoadingWeather,
          onFetchWeather: controller.fetchWeatherForecast,
          weatherSource: formState.weatherForecast?.source,
          hasAttemptedWeatherFetch: formState.hasAttemptedWeatherFetch,
          locationFailureReason: formState.locationFailureReason,
            onRequestPermission: controller.requestLocationPermissionAndFetch,
            onOpenSettings: controller.openLocationSettings,
            onOpenAppSettings: controller.openAppSettings,
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
    );
  }
}

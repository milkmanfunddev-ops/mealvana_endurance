import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import '../../../domain/fueling_window_limits.dart';
import '../../../../../shared/widgets/kyle_design/inputs/plus_minus_control.dart';
import '../../providers/running_input_controller.dart';
import '../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../theme/kyle_design/app_colors.dart';
import '../../../../weather/presentation/screens/weather_detail_screen.dart';
import '../../../../weather/domain/weather_forecast.dart';
import '../../../../../shared/services/location_service.dart';
import '../../../../../shared/domain/activity_type.dart';
import 'shared/workout_details_widget.dart';
import 'shared/activity_name_field.dart';
import '../../../../../shared/widgets/kyle_design/inputs/intensity_distribution_widget.dart';

/// Running Tab Content
///
/// Sport-specific form fields for running activities:
/// 1. WORKOUT DETAILS - Distance + Duration/Pace toggle + Estimated field
/// 2. INTENSITY DISTRIBUTION - Three-zone slider (Conversational/Tempo/All-Out)
/// 3. PRE-RUN FUELING WINDOW - Time before run
/// 4. WEATHER - Temperature with forecast link
/// 5. HUMIDITY - Humidity percentage
///
/// Note: Gut Training Level and Sweat Rate are managed in Settings > Profile & Preferences
///
/// Status: Phase 6.1 - Integrated new intensity distribution widgets
class RunningTabContent extends ConsumerWidget {
  const RunningTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(runningInputControllerProvider);
    final controller = ref.read(runningInputControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final weatherForecast = formState.weatherForecast;
    final isAutoFilled =
        weatherForecast != null &&
        weatherForecast.forecastAvailable &&
        weatherForecast.source != WeatherSource.defaultValue;
    final showWeatherPrompt =
        formState.hasAttemptedWeatherFetch && !isAutoFilled;
    final locationFailureReason = formState.locationFailureReason;
    final showLocationPrompt =
        showWeatherPrompt && locationFailureReason != null;
    final isServicesDisabled =
        locationFailureReason == LocationFailureReason.servicesDisabled;
    final isPermissionDenied =
        locationFailureReason == LocationFailureReason.permissionDenied;
    final isPermissionBlocked =
        locationFailureReason == LocationFailureReason.permissionDeniedForever;
    final useImperial = formState.unitSystem == UnitSystem.imperial;
    final canOpenForecast = isAutoFilled;
    final forecastActionLabel = formState.isLoadingWeather
        ? 'Loading...'
        : (canOpenForecast ? 'View Forecast' : 'Get Forecast');

    Widget buildAutoBadge() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.electrolyte.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.electrolyte),
        ),
        child: Text(
          'AUTO',
          style: AppTextStyles.smallLabel.copyWith(
            color: AppColors.electrolyteDark,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActivityNameField(
          key: const ValueKey('activity_create.workout_name_field'),
          value: formState.activityTitle,
          onChanged: controller.updateActivityTitle,
          hint: 'e.g., Long Run',
        ),
        const SizedBox(height: AppSpacing.xl),

        // WORKOUT DETAILS - Distance + Duration/Pace Toggle + Estimated Field
        WorkoutDetailsWidget(
          sport: ActivityType.running,
          distance: formState.distance,
          distanceUnit: formState.distanceUnit == DistanceUnit.kilometers
              ? 'km'
              : 'mi',
          mode: formState.durationPaceMode,
          estimatedDuration: formState.estimatedDuration,
          pace: formState.paceMinutes,
          paceUnit: formState.paceUnit == PaceUnit.minPerKm
              ? 'min/km'
              : 'min/mi',
          onDistanceChanged: controller.updateDistance,
          onModeChanged: controller.updateDurationPaceMode,
          onPaceChanged: controller.updatePace,
          onDurationChanged: controller.updateDuration,
          enabled: true,
        ),

        // Zone-based pace hint
        // if (formState.zoneSuggestedPace != null) ...[
        //   const SizedBox(height: AppSpacing.xs),
        //   Row(
        //     children: [
        //       Container(
        //         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        //         decoration: BoxDecoration(
        //           color: AppColors.electrolyte.withValues(alpha: 0.15),
        //           borderRadius: BorderRadius.circular(6),
        //           border: Border.all(
        //             color: AppColors.electrolyte.withValues(alpha: 0.4),
        //           ),
        //         ),
        //         child: Row(
        //           mainAxisSize: MainAxisSize.min,
        //           children: [
        //             Icon(
        //               FontAwesomeIcons.heartPulse.data,
        //               size: 10,
        //               color: AppColors.electrolyteDark,
        //             ),
        //             const SizedBox(width: 4),
        //             Text(
        //               'Pace from Training Peaks zones',
        //               style: AppTextStyles.smallLabel.copyWith(
        //                 color: AppColors.electrolyteDark,
        //                 fontSize: 10,
        //                 fontWeight: FontWeight.w600,
        //               ),
        //             ),
        //           ],
        //         ),
        //       ),
        //     ],
        //   ),
        // ],
        const SizedBox(height: AppSpacing.xl),

        // INTENSITY DISTRIBUTION
        IntensityDistributionWidget(
          value: formState.intensity,
          onChanged: controller.updateIntensityDistribution,
          sportType: ActivityType.running,
          enabled: true,
        ),

        const SizedBox(height: AppSpacing.xl),

        // PRE-RUN FUELING WINDOW
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TimeBeforeRunControl(
              value: formState.preRunMinutes,
              onChanged: controller.updatePreRunMinutes,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // Temperature with Forecast link
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Temperature label with Forecast link on the right.
            // Wrap (vs Row) lets the forecast link drop to a second line when
            // text scaling or longer translations would otherwise truncate it.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Temperature',
                      style: AppTextStyles.descriptor.copyWith(
                        color: isDark ? AppColors.cream : AppColors.blackberry,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isAutoFilled) ...[
                      const SizedBox(width: 8),
                      buildAutoBadge(),
                    ],
                  ],
                ),
                GestureDetector(
                  key: const ValueKey('activity_create.view_forecast_link'),
                  onTap: formState.isLoadingWeather
                      ? null
                      : (canOpenForecast
                            ? () {
                                final forecast = formState.weatherForecast;
                                if (forecast != null) {
                                  // Navigate to weather detail screen
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => WeatherDetailScreen(
                                        forecast: forecast,
                                        location: formState.location,
                                      ),
                                    ),
                                  );
                                }
                              }
                            : controller.fetchWeatherForecast),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        size: 14,
                        color: formState.isLoadingWeather
                            ? AppColors.dragonfruit.withValues(alpha: 0.4)
                            : AppColors.dragonfruit,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        forecastActionLabel,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: formState.isLoadingWeather
                              ? AppColors.dragonfruit.withValues(alpha: 0.4)
                              : AppColors.dragonfruit,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isAutoFilled) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Auto-filled from location',
                style: AppTextStyles.smallLabel.copyWith(
                  color: (isDark ? AppColors.cream : AppColors.blackberry)
                      .withValues(alpha: 0.7),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (showWeatherPrompt) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  if (showLocationPrompt && isServicesDisabled) ...[
                    Text(
                      'Location services are off.',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: (isDark ? AppColors.cream : AppColors.blackberry)
                            .withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                    GestureDetector(
                      onTap: controller.openLocationSettings,
                      child: Text(
                        'Open settings',
                        style: AppTextStyles.smallLabel.copyWith(
                          color: AppColors.dragonfruit,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ] else if (showLocationPrompt && isPermissionBlocked) ...[
                    Text(
                      'Location permission blocked.',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: (isDark ? AppColors.cream : AppColors.blackberry)
                            .withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                    GestureDetector(
                      onTap: controller.openAppSettings,
                      child: Text(
                        'Open app settings',
                        style: AppTextStyles.smallLabel.copyWith(
                          color: AppColors.dragonfruit,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ] else if (showLocationPrompt && isPermissionDenied) ...[
                    Text(
                      'Allow location to auto-fill.',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: (isDark ? AppColors.cream : AppColors.blackberry)
                            .withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                    GestureDetector(
                      onTap: formState.isLoadingWeather
                          ? null
                          : controller.requestLocationPermissionAndFetch,
                      child: Text(
                        'Enable location',
                        style: AppTextStyles.smallLabel.copyWith(
                          color: formState.isLoadingWeather
                              ? AppColors.dragonfruit.withValues(alpha: 0.4)
                              : AppColors.dragonfruit,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: controller.openAppSettings,
                      child: Text(
                        'Open app settings',
                        style: AppTextStyles.smallLabel.copyWith(
                          color: AppColors.dragonfruit,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      "Couldn't fetch weather. Enter manually or",
                      style: AppTextStyles.smallLabel.copyWith(
                        color: (isDark ? AppColors.cream : AppColors.blackberry)
                            .withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                    GestureDetector(
                      onTap: formState.isLoadingWeather
                          ? null
                          : controller.fetchWeatherForecast,
                      child: Text(
                        'try again',
                        style: AppTextStyles.smallLabel.copyWith(
                          color: formState.isLoadingWeather
                              ? AppColors.dragonfruit.withValues(alpha: 0.4)
                              : AppColors.dragonfruit,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            // Temperature control
            Builder(
              builder: (context) {
                final tempC = formState.temperatureC;
                final displayTemp = useImperial ? (tempC * 9 / 5) + 32 : tempC;
                final primaryUnit = useImperial ? '°F' : '°C';
                final minC = -5.0;
                final maxC = 40.0;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Minus button
                    GestureDetector(
                      key: const ValueKey('activity_create.temp_minus'),
                      onTap: !formState.isLoadingWeather && tempC > minC
                          ? () => controller.updateTemperature(
                              (tempC - (useImperial ? 10 / 9 : 1.0)).clamp(
                                minC,
                                maxC,
                              ),
                            )
                          : null,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.orange, width: 2),
                        ),
                        child: Icon(
                          Icons.remove,
                          color: !formState.isLoadingWeather
                              ? AppColors.orange
                              : AppColors.orange.withValues(alpha: 0.4),
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(width: AppSpacing.xl),

                    // Value display - primary unit large, secondary in parens
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            key: const ValueKey('activity_create.temp_value'),
                            '${displayTemp.toStringAsFixed(0)}$primaryUnit',
                            style: AppTextStyles.dataNumber.copyWith(
                              color: isDark
                                  ? AppColors.cream
                                  : AppColors.blackberry,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: AppSpacing.xl),

                    // Plus button
                    GestureDetector(
                      key: const ValueKey('activity_create.temp_plus'),
                      onTap: !formState.isLoadingWeather && tempC < maxC
                          ? () => controller.updateTemperature(
                              (tempC + (useImperial ? 10 / 9 : 1.0)).clamp(
                                minC,
                                maxC,
                              ),
                            )
                          : null,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.orange, width: 2),
                        ),
                        child: Icon(
                          Icons.add,
                          color: !formState.isLoadingWeather
                              ? AppColors.orange
                              : AppColors.orange.withValues(alpha: 0.4),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // Humidity
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Humidity',
                  style: AppTextStyles.descriptor.copyWith(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isAutoFilled) ...[
                  const SizedBox(width: 8),
                  buildAutoBadge(),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            KylePlusMinusDecimalControl(
              key: const ValueKey('activity_create.humidity_control'),
              value: formState.humidityPct,
              onChanged: controller.updateHumidity,
              min: 20.0,
              max: 95.0,
              step: 5.0,
              decimalPlaces: 0,
              unit: '% humidity', // Will be displayed as "% HUMIDITY"
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

/// Control button for plus/minus controls (copied from kyle_design for consistency)
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabledIconColor = isDark ? AppColors.cream : AppColors.orange;
    final disabledIconColor = enabledIconColor.withValues(alpha: 0.4);

    return SizedBox(
      width: AppSizes.controlSize,
      height: AppSizes.controlSize,
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
          shape: RoundedRectangleBorder(borderRadius: AppRadius.circularRadius),
          padding: EdgeInsets.zero,
        ),
        child: Icon(
          icon,
          size: AppIconSizes.controlIcon,
          color: enabled ? enabledIconColor : disabledIconColor,
        ),
      ),
    );
  }
}

/// Custom time before run control that formats as hours
class _TimeBeforeRunControl extends StatelessWidget {
  const _TimeBeforeRunControl({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  String _formatTime(int minutes) {
    if (minutes == 0) return '0 MINUTES';
    if (minutes < 60) return '$minutes MINUTES';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      // Exactly on the hour - show as optimal
      return '$hours ${hours == 1 ? 'HOUR' : 'HOURS'}';
    } else {
      // Show both hours and minutes
      return '$hours ${hours == 1 ? 'HOUR' : 'HOURS'} $remainingMinutes MIN';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canIncrement =
        value + FuelingWindowLimits.stepMinutes <=
        FuelingWindowLimits.maxMinutes;
    final canDecrement =
        value - FuelingWindowLimits.stepMinutes >=
        FuelingWindowLimits.minMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pre-Run Fueling Window',
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
              key: const ValueKey('activity_create.fueling_window_minus'),
              icon: FontAwesomeIcons.minus.data,
              onPressed: canDecrement ? () => onChanged(value - 15) : null,
              enabled: canDecrement,
            ),
            const SizedBox(width: AppSpacing.xl),
            // Value display
            Expanded(
              child: Text(
                key: const ValueKey('activity_create.fueling_window_value'),
                _formatTime(value),
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
              key: const ValueKey('activity_create.fueling_window_plus'),
              icon: FontAwesomeIcons.plus.data,
              onPressed: canIncrement ? () => onChanged(value + 15) : null,
              enabled: canIncrement,
            ),
          ],
        ),
      ],
    );
  }
}

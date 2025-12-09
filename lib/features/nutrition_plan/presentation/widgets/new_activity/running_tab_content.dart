import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/inputs/plus_minus_control.dart';
import '../../../../../shared/widgets/kyle_design/buttons/segmented_control.dart';
import '../../providers/running_input_controller.dart';
import '../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../theme/kyle_design/app_colors.dart';
import '../../../../weather/presentation/screens/weather_detail_screen.dart';

/// Running Tab Content
///
/// Sport-specific form fields for running activities:
/// - Distance (miles)
/// - Average Pace (min/mile)
/// - Time before Run
/// - Gut Training Level (segmented control)
/// - Sweat Rate (segmented control)
/// - Temperature with weather forecast link
/// - Humidity
///
/// Status: Phase 2 - Full implementation with Kyle design components
class RunningTabContent extends ConsumerWidget {
  const RunningTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(runningInputControllerProvider);
    final controller = ref.read(runningInputControllerProvider.notifier);
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
            max: 200.0,
            step: 1.0,
            decimalPlaces: 1,
            unit: 'miles', // Will be displayed as "MILES" in uppercase
            tappable: true,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Average Pace
          _PaceControl(
            paceMinutes: formState.paceMinutes,
            onChanged: controller.updatePace,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Time before Run with helper text
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TimeBeforeRunControl(
                value: formState.preRunMinutes,
                onChanged: controller.updatePreRunMinutes,
              ),
              // const SizedBox(height: AppSpacing.xs),
              // Text(
              //   'Optimal timing: Balanced meal with carbs and protein',
              //   style: AppTextStyles.smallLabel.copyWith(
              //     color: (isDark ? AppColors.cream : AppColors.blackberry).withValues(alpha: 0.7),
              //     fontSize: 11,
              //     fontStyle: FontStyle.italic,
              //   ),
              //   textAlign: TextAlign.left,
              // ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Gut Training Level with g/kg/h values
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gut Training Level',
                style: AppTextStyles.descriptor.copyWith(
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              KyleGutTrainingSegmentedControl(
                selected: formState.gutTraining,
                onChanged: controller.updateGutTraining,
                showValues: true,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Sweat Rate
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sweat Rate',
                style: AppTextStyles.descriptor.copyWith(
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              KyleSweatRateSegmentedControl(
                selected: formState.sweatRate,
                onChanged: controller.updateSweatRate,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Temperature with Forecast link
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Temperature label with Forecast link on the right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Temperature',
                    style: AppTextStyles.descriptor.copyWith(
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: formState.isLoadingWeather || formState.weatherForecast == null
                        ? (formState.isLoadingWeather ? null : controller.fetchWeatherForecast)
                        : () {
                            final forecast = formState.weatherForecast;
                            if (forecast != null) {
                              // Navigate to weather detail screen
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WeatherDetailScreen(
                                    forecast: forecast,
                                  ),
                                ),
                              );
                            }
                          },
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
                          formState.isLoadingWeather ? 'Loading...' : 'Forecast',
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
              const SizedBox(height: AppSpacing.sm),
              // Temperature control
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minus button
                  GestureDetector(
                    onTap: !formState.isLoadingWeather && formState.temperatureC > -5.0
                        ? () => controller.updateTemperature((formState.temperatureC - 1.0).clamp(-5.0, 40.0))
                        : null,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.orange,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.remove,
                        color: !formState.isLoadingWeather ? AppColors.orange : AppColors.orange.withValues(alpha: 0.4),
                        size: 20,
                      ),
                    ),
                  ),

                  const SizedBox(width: AppSpacing.xl),

                  // Value display
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${formState.temperatureC.toStringAsFixed(0)}°C (${_celsiusToFahrenheit(formState.temperatureC)}°F)',
                          style: AppTextStyles.dataNumber.copyWith(
                            color: isDark ? AppColors.cream : AppColors.blackberry,
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
                    onTap: !formState.isLoadingWeather && formState.temperatureC < 40.0
                        ? () => controller.updateTemperature((formState.temperatureC + 1.0).clamp(-5.0, 40.0))
                        : null,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.orange,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: !formState.isLoadingWeather ? AppColors.orange : AppColors.orange.withValues(alpha: 0.4),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Humidity
          KylePlusMinusDecimalControl(
            label: 'Humidity',
            value: formState.humidityPct,
            onChanged: controller.updateHumidity,
            min: 20.0,
            max: 95.0,
            step: 5.0,
            decimalPlaces: 0,
            unit: '% humidity', // Will be displayed as "% HUMIDITY"
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
    );
  }

  /// Convert Celsius to Fahrenheit
  String _celsiusToFahrenheit(double celsius) {
    final fahrenheit = (celsius * 9 / 5) + 32;
    return fahrenheit.toStringAsFixed(0);
  }
}

/// Control button for plus/minus controls (copied from kyle_design for consistency)
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
      width: AppSizes.controlSize,
      height: AppSizes.controlSize,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: enabled
              ? Colors.orange
              : Colors.orange.withOpacity(0.4),
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.orange.withOpacity(0.4),
          elevation: 0,
          shadowColor: Colors.transparent,
          side: BorderSide(
            color: enabled
                ? Colors.orange
                : Colors.orange.withOpacity(0.4),
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.circularRadius,
          ),
          padding: EdgeInsets.zero,
        ),
        child: Icon(
          icon,
          size: AppIconSizes.controlIcon,
          color: enabled
              ? AppColors.cream  // White/cream icon color to match Kyle's design
              : AppColors.cream.withOpacity(0.4),
        ),
      ),
    );
  }
}

/// Custom time before run control that formats as hours
class _TimeBeforeRunControl extends StatelessWidget {
  const _TimeBeforeRunControl({
    required this.value,
    required this.onChanged,
  });

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
    final canIncrement = value + 15 <= 480;
    final canDecrement = value - 15 >= 0;

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
              icon: FontAwesomeIcons.minus,
              onPressed: canDecrement ? () => onChanged(value - 15) : null,
              enabled: canDecrement,
            ),
            const SizedBox(width: AppSpacing.xl),
            // Value display
            Expanded(
              child: Text(
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
              icon: FontAwesomeIcons.plus,
              onPressed: canIncrement ? () => onChanged(value + 15) : null,
              enabled: canIncrement,
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom pace control that displays M:SS format
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


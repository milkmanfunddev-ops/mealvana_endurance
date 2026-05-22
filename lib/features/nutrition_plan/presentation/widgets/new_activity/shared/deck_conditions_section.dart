import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../../shared/widgets/kyle_design/inputs/plus_minus_control.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../weather/domain/weather_forecast.dart';
import '../../../../../../shared/services/location_service.dart';

/// Collapsible Deck Conditions Section
///
/// Used by both swimming tab and brick swimming segment.
/// Weather-related parameters are optional - when null, no forecast UI is shown.
class DeckConditionsSection extends StatelessWidget {
  const DeckConditionsSection({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.deckTemperature,
    required this.onTemperatureChanged,
    required this.deckHumidity,
    required this.onHumidityChanged,
    // Optional weather params (null = no weather UI)
    this.isLoadingWeather = false,
    this.onFetchWeather,
    this.weatherSource,
    this.hasAttemptedWeatherFetch = false,
    this.locationFailureReason,
    this.onRequestPermission,
    this.onOpenSettings,
    this.onOpenAppSettings,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final double deckTemperature;
  final ValueChanged<double> onTemperatureChanged;
  final double deckHumidity;
  final ValueChanged<double> onHumidityChanged;

  // Optional weather integration
  final bool isLoadingWeather;
  final VoidCallback? onFetchWeather;
  final WeatherSource? weatherSource;
  final bool hasAttemptedWeatherFetch;
  final LocationFailureReason? locationFailureReason;
  final VoidCallback? onRequestPermission;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenAppSettings;

  bool get _hasWeatherIntegration => onFetchWeather != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAutoFilled = _hasWeatherIntegration &&
        weatherSource != null &&
        weatherSource != WeatherSource.defaultValue;
    final showWeatherPrompt =
        _hasWeatherIntegration && hasAttemptedWeatherFetch && !isAutoFilled;
    final showLocationPrompt = showWeatherPrompt && locationFailureReason != null;
    final isServicesDisabled =
        locationFailureReason == LocationFailureReason.servicesDisabled;
    final isPermissionDenied =
        locationFailureReason == LocationFailureReason.permissionDenied;
    final isPermissionBlocked =
        locationFailureReason == LocationFailureReason.permissionDeniedForever;
    final forecastActionLabel = isLoadingWeather
        ? 'Loading forecast...'
        : (isAutoFilled ? 'Refetch Forecast' : 'Get Forecast');

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
        // Header with toggle
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Deck Conditions',
                      style: AppTextStyles.smallLabel.copyWith(
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
                Icon(
                  isExpanded
                      ? FontAwesomeIcons.chevronUp.data
                      : FontAwesomeIcons.chevronDown.data,
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

          // Deck Temperature with optional Forecast
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
              if (_hasWeatherIntegration) ...[
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: isLoadingWeather ? null : onFetchWeather,
                  child: Text(
                    forecastActionLabel,
                    style: AppTextStyles.smallLabel.copyWith(
                      color: isLoadingWeather
                          ? AppColors.dragonfruit.withValues(alpha: 0.4)
                          : AppColors.dragonfruit,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
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
                            color: (isDark
                                    ? AppColors.cream
                                    : AppColors.blackberry)
                                .withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                        GestureDetector(
                          onTap: onOpenSettings,
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
                            color: (isDark
                                    ? AppColors.cream
                                    : AppColors.blackberry)
                                .withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                        GestureDetector(
                          onTap: onOpenAppSettings,
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
                            color: (isDark
                                    ? AppColors.cream
                                    : AppColors.blackberry)
                                .withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                        GestureDetector(
                          onTap: isLoadingWeather ? null : onRequestPermission,
                          child: Text(
                            'Enable location',
                            style: AppTextStyles.smallLabel.copyWith(
                              color: isLoadingWeather
                                  ? AppColors.dragonfruit
                                      .withValues(alpha: 0.4)
                                  : AppColors.dragonfruit,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: onOpenAppSettings,
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
                            color: (isDark
                                    ? AppColors.cream
                                    : AppColors.blackberry)
                                .withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                        GestureDetector(
                          onTap: isLoadingWeather ? null : onFetchWeather,
                          child: Text(
                            'try again',
                            style: AppTextStyles.smallLabel.copyWith(
                              color: isLoadingWeather
                                  ? AppColors.dragonfruit
                                      .withValues(alpha: 0.4)
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
              ],
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

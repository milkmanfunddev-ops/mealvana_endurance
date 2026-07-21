import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/providers/unit_system_provider.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../nutrition_plan/domain/run_parameters.dart' show UnitSystem;
import '../../domain/weather_forecast.dart';
import '../../domain/location.dart' as domain;

/// Weather detail screen
/// Shows complete weather forecast information
///
/// Reads the user's imperial/metric preference directly from
/// [unitSystemProvider] so no call site can forget to pass it (and
/// silently default to the wrong unit).
class WeatherDetailScreen extends ConsumerWidget {
  final WeatherForecast forecast;
  final domain.Location? location;

  const WeatherDetailScreen({super.key, required this.forecast, this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitSystem =
        ref.watch(unitSystemProvider).value ?? UnitSystem.imperial;
    final useMetric = unitSystem == UnitSystem.metric;
    final useImperial = !useMetric;

    return Scaffold(
      appBar: AppBar(
        // The bar background is a fixed light cream in every theme, so force a
        // dark foreground. Without this the back-button icon (defaults to
        // colorScheme.onSurface, which is near-white in dark mode) and the
        // white title are invisible on cream — making it look like there is no
        // back button at all.
        leading: const CustomAppBarBackButton(iconColor: AppTheme.primary900),
        title: const Text('Weather Forecast'),
        backgroundColor: AppTheme.baseCream,
        foregroundColor: AppTheme.primary900,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero section with main weather
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primary600, AppTheme.primary900],
                ),
              ),
              child: Column(
                children: [
                  Icon(_getWeatherIcon(), size: 80, color: Colors.white),
                  SizedBox(height: 16.h),
                  Text(
                    UnitFormatter.formatTemperature(
                      forecast.temperatureC,
                      useMetric: useMetric,
                    ),
                    style: TextStyle(
                      fontSize: 48.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (forecast.conditions != null)
                    Text(
                      forecast.conditions!,
                      style: TextStyle(fontSize: 20.sp, color: Colors.white),
                    ),
                  SizedBox(height: 16.h),
                  _buildInfoChip(
                    icon: Icons.water_drop,
                    label: 'Humidity',
                    value: '${forecast.humidityPct}%',
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Location info
            if (location != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: _buildInfoCard(
                  icon: Icons.location_on,
                  title: 'Location',
                  children: [
                    _buildInfoRow('Location', location!.displayName),
                    _buildInfoRow(
                      'Coordinates',
                      '${location!.latitude.toStringAsFixed(4)}, ${location!.longitude.toStringAsFixed(4)}',
                    ),
                  ],
                ),
              ),

            SizedBox(height: 16.h),

            // Weather details
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: _buildInfoCard(
                icon: Icons.thermostat,
                title: 'Weather Details',
                children: [
                  _buildInfoRow(
                    'Temperature',
                    UnitFormatter.formatTemperature(
                      forecast.temperatureC,
                      useMetric: useMetric,
                    ),
                  ),
                  _buildInfoRow('Humidity', '${forecast.humidityPct}%'),
                  if (forecast.windSpeedKmh != null)
                    _buildInfoRow(
                      'Wind Speed',
                      useMetric
                          ? '${forecast.windSpeedKmh} km/h'
                          : '${forecast.windSpeedMph?.round()} mph',
                    ),
                  if (forecast.precipitationMm != null)
                    _buildInfoRow(
                      'Precipitation',
                      useImperial
                          ? '${forecast.precipitationIn?.toStringAsFixed(2)} in'
                          : '${forecast.precipitationMm?.toStringAsFixed(1)} mm',
                    ),
                  if (forecast.conditions != null)
                    _buildInfoRow('Conditions', forecast.conditions!),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Forecast metadata
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: _buildInfoCard(
                icon: Icons.info_outline,
                title: 'Forecast Info',
                children: [
                  _buildInfoRow('Source', forecast.source.displayName),
                  _buildInfoRow(
                    'Forecast Available',
                    forecast.forecastAvailable ? 'Yes' : 'No (using defaults)',
                  ),
                  _buildInfoRow(
                    'Forecast Date',
                    _formatDate(forecast.forecastDate),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Explanation
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppTheme.primary50,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.primary100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: AppTheme.primary600,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'About this forecast',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      _getExplanationText(),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.primary900,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          SizedBox(width: 8.w),
          Text(
            '$label: $value',
            style: TextStyle(fontSize: 14.sp, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.primary100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary600, size: 20),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary900,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: TextStyle(fontSize: 14.sp, color: AppTheme.baseGrey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon() {
    if (forecast.conditions != null) {
      final conditions = forecast.conditions!.toLowerCase();
      if (conditions.contains('clear')) return Icons.wb_sunny;
      if (conditions.contains('cloud')) return Icons.wb_cloudy;
      if (conditions.contains('rain')) return Icons.umbrella;
      if (conditions.contains('snow')) return Icons.ac_unit;
      if (conditions.contains('thunder')) return Icons.flash_on;
      if (conditions.contains('fog')) return Icons.cloud;
    }
    return Icons.cloud;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getExplanationText() {
    if (!forecast.forecastAvailable) {
      return 'No weather forecast available for this date/location. Using default conditions (20°C, 60% humidity) for nutrition calculations.';
    }

    switch (forecast.source) {
      case WeatherSource.forecast:
        return 'This forecast is from Open-Meteo weather service and shows predicted conditions for your activity date. The forecast is cached for 1 hour for faster access.';
      case WeatherSource.historical:
        return 'This is historical weather data from Open-Meteo for a past date. It shows actual recorded conditions from weather stations and models.';
      case WeatherSource.defaultValue:
        return 'Using default weather conditions (20°C, 60% humidity) because the forecast date is outside the available range (16 days future or 92 days past).';
    }
  }
}

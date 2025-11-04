import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/weather_forecast.dart';

/// Weather indicator badge widget
/// Shows when weather data has been fetched with a clickable indicator
class WeatherIndicatorBadge extends StatelessWidget {
  final WeatherForecast forecast;
  final VoidCallback onTap;

  const WeatherIndicatorBadge({
    super.key,
    required this.forecast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(
            color: _getBorderColor(),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getStatusText(),
              style: TextStyle(
                color: _getTextColor(),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.info_outline,
              size: 14,
              color: _getIconColor(),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (!forecast.forecastAvailable) {
      return AppTheme.baseGrey.withValues(alpha: 0.1);
    }

    switch (forecast.source) {
      case WeatherSource.forecast:
        return AppTheme.primary100;
      case WeatherSource.historical:
        return AppTheme.primary50;
      case WeatherSource.defaultValue:
        return AppTheme.baseGrey.withValues(alpha: 0.1);
    }
  }

  Color _getBorderColor() {
    if (!forecast.forecastAvailable) {
      return AppTheme.baseGrey.withValues(alpha: 0.3);
    }

    switch (forecast.source) {
      case WeatherSource.forecast:
        return AppTheme.primary600;
      case WeatherSource.historical:
        return AppTheme.primary600;
      case WeatherSource.defaultValue:
        return AppTheme.baseGrey.withValues(alpha: 0.3);
    }
  }

  Color _getIconColor() {
    if (!forecast.forecastAvailable) {
      return AppTheme.baseGrey;
    }

    switch (forecast.source) {
      case WeatherSource.forecast:
        return AppTheme.primary600;
      case WeatherSource.historical:
        return AppTheme.primary600;
      case WeatherSource.defaultValue:
        return AppTheme.baseGrey;
    }
  }

  Color _getTextColor() {
    return AppTheme.primary900;
  }

  String _getStatusText() {
    if (!forecast.forecastAvailable) {
      return 'default';
    }

    switch (forecast.source) {
      case WeatherSource.forecast:
        return 'Forecast';
      case WeatherSource.historical:
        return 'Forecast';
      case WeatherSource.defaultValue:
        return 'Forecast';
    }
  }
}

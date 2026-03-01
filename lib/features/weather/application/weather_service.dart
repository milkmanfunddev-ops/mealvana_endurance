import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/location_service.dart';
import '../data/weather_repository.dart';
import '../domain/weather_forecast.dart';
import '../domain/location.dart' as domain;

part 'weather_service.g.dart';

/// Weather service provider
@riverpod
WeatherService weatherService(Ref ref) {
  return WeatherService(
    supabase: Supabase.instance.client,
    weatherRepository: ref.watch(weatherRepositoryProvider),
    locationService: ref.watch(locationServiceProvider),
    logger: ref.watch(appLoggerProvider),
  );
}

/// Weather service for fetching weather forecasts
/// Handles API calls to Supabase edge function, caching, and location services
/// Includes in-memory cache to prevent refetches on tab switches
class WeatherService {
  final SupabaseClient supabase;
  final WeatherRepository weatherRepository;
  final LocationService locationService;
  final AppLogger logger;

  /// In-memory cache: Map of cacheKey to WeatherForecast
  /// Cache key format: "lat_lon_yyyy-MM-ddTHH"
  final Map<String, WeatherForecast> _memoryCache = {};

  WeatherService({
    required this.supabase,
    required this.weatherRepository,
    required this.locationService,
    required this.logger,
  }) {
    // Clear stale default weather forecasts on initialization
    weatherRepository.clearDefaultForecasts().ignore();
  }

  /// Normalize a datetime to the top of the hour.
  DateTime _normalizeToHour(DateTime date) {
    return DateTime(date.year, date.month, date.day, date.hour);
  }

  bool _isTodayOrFuture(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requestedDay = DateTime(date.year, date.month, date.day);
    return !requestedDay.isBefore(today);
  }

  bool _shouldBypassHistoricalCache(
    WeatherForecast forecast,
    DateTime activityDate,
  ) {
    // Historical cache is fine for truly past days, but not for same-day/future
    // requests where users expect forecast data.
    return forecast.source == WeatherSource.historical &&
        _isTodayOrFuture(activityDate);
  }

  /// Generate cache key from location and activity hour (time-aware).
  String _getCacheKey(double latitude, double longitude, DateTime date) {
    final hourOnly = _normalizeToHour(date);
    final hourKey =
        '${hourOnly.year.toString().padLeft(4, '0')}-${hourOnly.month.toString().padLeft(2, '0')}-${hourOnly.day.toString().padLeft(2, '0')}T${hourOnly.hour.toString().padLeft(2, '0')}';
    return '${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}_$hourKey';
  }

  /// Get weather forecast for activity
  /// Checks in-memory cache first, then database cache, then API
  ///
  /// Parameters:
  /// - location: Location for forecast (if null, uses device GPS)
  /// - activityDate: Date/time of the activity
  ///
  /// Returns default forecast (20°C, 60%) on error
  Future<WeatherForecast> getWeatherForecast({
    domain.Location? location,
    required DateTime activityDate,
  }) async {
    logger.debug(
      'Weather fetch requested',
      context: 'WeatherService',
      data: {
        'has_location': location != null,
        'activity_date': activityDate.toIso8601String(),
      },
    );
    try {
      // Get location (use provided or fetch current)
      domain.Location? targetLocation = location;
      if (targetLocation == null) {
        targetLocation = await locationService.getCurrentLocation();
        if (targetLocation == null) {
          logger.warning(
            'No location available for weather',
            context: 'WeatherService',
            data: {
              'failure_reason': locationService.getLastFailureReason()?.name,
            },
          );
          logger.warning('Could not get location, using default weather');
          return WeatherForecast.defaultForecast(activityDate);
        }
      }

      // Check in-memory cache first (fastest - prevents refetch on tab switch)
      final cacheKey = _getCacheKey(
        targetLocation.latitude,
        targetLocation.longitude,
        activityDate,
      );

      if (_memoryCache.containsKey(cacheKey)) {
        final cached = _memoryCache[cacheKey]!;
        // Verify it's still fresh (same expiry rules as database)
        if (cached.isFresh()) {
          if (_shouldBypassHistoricalCache(cached, activityDate)) {
            _memoryCache.remove(cacheKey);
            logger.debug(
              'Bypassing stale historical memory cache for same-day/future request',
              context: 'WeatherService',
              data: {'cache_key': cacheKey},
            );
          } else {
            logger.debug(
              'Weather cache hit (memory)',
              context: 'WeatherService',
              data: {'cache_key': cacheKey, 'source': cached.source.value},
            );
            return cached;
          }
        }
      }

      // Check database cache (second level)
      final dbCached = await weatherRepository.getCachedForecast(
        latitude: targetLocation.latitude,
        longitude: targetLocation.longitude,
        forecastDate: activityDate,
      );

      if (dbCached != null) {
        if (_shouldBypassHistoricalCache(dbCached, activityDate)) {
          logger.debug(
            'Bypassing stale historical DB cache for same-day/future request',
            context: 'WeatherService',
            data: {'cache_key': cacheKey},
          );
        } else {
          logger.debug(
            'Weather cache hit (db)',
            context: 'WeatherService',
            data: {'cache_key': cacheKey, 'source': dbCached.source.value},
          );
          _memoryCache[cacheKey] = dbCached;
          return dbCached;
        }
      }

      // Fetch from API (third level)
      logger.debug(
        'Weather cache miss, calling API',
        context: 'WeatherService',
        data: {'cache_key': cacheKey},
      );
      final forecast = await _fetchWeatherFromAPI(
        latitude: targetLocation.latitude,
        longitude: targetLocation.longitude,
        activityDate: activityDate,
      );

      // Only cache non-default forecasts (don't cache fallback values)
      if (forecast.source != WeatherSource.defaultValue) {
        await weatherRepository.cacheForecast(
          latitude: targetLocation.latitude,
          longitude: targetLocation.longitude,
          forecast: forecast,
        );
        _memoryCache[cacheKey] = forecast;

        // Clear expired forecasts (background cleanup)
        weatherRepository.clearExpiredForecasts().ignore();
      } else {
        logger.warning(
          'Weather API returned default forecast',
          context: 'WeatherService',
          data: {'source': forecast.source.value},
        );
      }

      return forecast;
    } catch (e, stackTrace) {
      logger.error(
        'Error getting weather forecast',
        error: e,
        stackTrace: stackTrace,
      );
      return WeatherForecast.defaultForecast(activityDate);
    }
  }

  /// Fetch weather from Supabase edge function
  Future<WeatherForecast> _fetchWeatherFromAPI({
    required double latitude,
    required double longitude,
    required DateTime activityDate,
  }) async {
    try {
      final startTime = DateTime.now();
      final response = await supabase.functions.invoke(
        'get-weather-forecast',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'activity_date': activityDate.toIso8601String(),
        },
      );

      logger.api(
        'Weather edge function response',
        endpoint: 'get-weather-forecast',
        statusCode: response.status,
        duration: DateTime.now().difference(startTime),
        requestData: {
          'latitude': latitude,
          'longitude': longitude,
          'activity_date': activityDate.toIso8601String(),
        },
      );

      if (response.status != 200) {
        logger.warning(
          'Weather API returned non-200 status: ${response.status}',
        );
        return WeatherForecast.defaultForecast(activityDate);
      }

      final data = response.data;
      if (data == null || data['success'] != true || data['data'] == null) {
        logger.warning('Weather API returned invalid response');
        return WeatherForecast.defaultForecast(activityDate);
      }

      final forecast = WeatherForecast.fromJson(data['data']);
      logger.debug(
        'Weather API parsed forecast',
        context: 'WeatherService',
        data: {
          'source': forecast.source.value,
          'forecast_available': forecast.forecastAvailable,
          'temp_c': forecast.temperatureC,
          'humidity_pct': forecast.humidityPct,
        },
      );
      return forecast;
    } catch (e, stackTrace) {
      logger.error(
        'Error fetching weather from API',
        error: e,
        stackTrace: stackTrace,
      );
      return WeatherForecast.defaultForecast(activityDate);
    }
  }

  /// Get current device location
  Future<domain.Location?> getCurrentLocation() async {
    return await locationService.getCurrentLocation();
  }

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    return await locationService.hasLocationPermission();
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    return await locationService.requestLocationPermission();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await locationService.openLocationSettings();
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return await locationService.openAppSettings();
  }

  /// Get last location failure reason (if any)
  LocationFailureReason? getLastLocationFailureReason() {
    return locationService.getLastFailureReason();
  }
}

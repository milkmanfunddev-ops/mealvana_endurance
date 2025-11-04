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
  /// Cache key format: "lat_lon_yyyy-MM-dd"
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

  /// Generate cache key from location and date (date only, no time)
  String _getCacheKey(double latitude, double longitude, DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return '${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}_${dateOnly.toIso8601String().substring(0, 10)}';
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
    try {
      // Get location (use provided or fetch current)
      domain.Location? targetLocation = location;
      if (targetLocation == null) {
        targetLocation = await locationService.getCurrentLocation();
        if (targetLocation == null) {
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
          return cached;
        }
      }

      // Check database cache (second level)
      final dbCached = await weatherRepository.getCachedForecast(
        latitude: targetLocation.latitude,
        longitude: targetLocation.longitude,
        forecastDate: activityDate,
      );

      if (dbCached != null) {
        _memoryCache[cacheKey] = dbCached;
        return dbCached;
      }

      // Fetch from API (third level)
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
      }

      return forecast;
    } catch (e, stackTrace) {
      logger.error('Error getting weather forecast', error: e, stackTrace: stackTrace);
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
      final response = await supabase.functions.invoke(
        'get-weather-forecast',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'date': activityDate.toIso8601String(),
        },
      );

      if (response.status != 200) {
        logger.warning('Weather API returned non-200 status: ${response.status}');
        return WeatherForecast.defaultForecast(activityDate);
      }

      final data = response.data;
      if (data == null || data['success'] != true || data['data'] == null) {
        logger.warning('Weather API returned invalid response');
        return WeatherForecast.defaultForecast(activityDate);
      }

      final forecast = WeatherForecast.fromJson(data['data']);
      return forecast;
    } catch (e, stackTrace) {
      logger.error('Error fetching weather from API', error: e, stackTrace: stackTrace);
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
}

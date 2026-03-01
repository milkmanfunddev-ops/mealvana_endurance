import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../domain/weather_forecast.dart';

part 'weather_repository.g.dart';

/// Weather repository provider
@riverpod
WeatherRepository weatherRepository(Ref ref) {
  return WeatherRepository(
    database: ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  );
}

/// Repository for weather forecast data
/// Handles caching weather forecasts in Drift database with 1-hour expiry
class WeatherRepository {
  final AppDatabase database;
  final AppLogger logger;

  WeatherRepository({
    required this.database,
    required this.logger,
  });

  /// Normalize a datetime to the top of the hour for cache bucketing.
  DateTime _normalizeToHour(DateTime date) {
    return DateTime(date.year, date.month, date.day, date.hour);
  }

  /// Get cached weather forecast for location and activity hour
  /// Returns null if no valid cache exists
  /// Note: Caches by HOUR to support time-sensitive forecasts.
  Future<WeatherForecast?> getCachedForecast({
    required double latitude,
    required double longitude,
    required DateTime forecastDate,
  }) async {
    try {
      final now = DateTime.now();

      // Normalize to top-of-hour bucket
      final forecastHour = _normalizeToHour(forecastDate);

      // Query for cached forecast matching the same hour bucket
      final query = database.select(database.weatherForecastsTable)
        ..where((tbl) =>
            tbl.latitude.equals(latitude) &
            tbl.longitude.equals(longitude) &
            tbl.forecastDate.equals(forecastHour) &
            tbl.expiresAt.isBiggerThanValue(now))
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.fetchedAt)])
        ..limit(1);

      final cached = await query.getSingleOrNull();

      if (cached == null) {
        return null;
      }

      return WeatherForecast(
        temperatureC: cached.temperatureC,
        humidityPct: cached.humidityPct,
        forecastAvailable: cached.forecastAvailable,
        forecastDate: cached.forecastDate,
        source: WeatherSource.fromString(cached.source),
        conditions: cached.conditions,
        windSpeedKmh: cached.windSpeedKmh,
        precipitationMm: cached.precipitationMm,
      );
    } catch (e, stackTrace) {
      logger.error('Error getting cached forecast', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Save weather forecast to cache
  /// Note: Stores by HOUR with variable expiry:
  /// - Historical data: 24 hours (rarely changes)
  /// - Forecast data: 1 hour (can change frequently)
  Future<void> cacheForecast({
    required double latitude,
    required double longitude,
    required WeatherForecast forecast,
  }) async {
    try {
      final now = DateTime.now();

      // Normalize to top-of-hour bucket
      final forecastHour = _normalizeToHour(forecast.forecastDate);

      // Variable expiry: Historical data lasts longer
      final expiryDuration = forecast.source == WeatherSource.historical
          ? const Duration(hours: 24)  // Historical: 24 hours
          : const Duration(hours: 1);   // Forecast: 1 hour

      final expiresAt = now.add(expiryDuration);

      await database.into(database.weatherForecastsTable).insert(
        WeatherForecastsTableCompanion.insert(
          latitude: latitude,
          longitude: longitude,
          forecastDate: forecastHour, // Store hour bucket
          temperatureC: forecast.temperatureC,
          humidityPct: forecast.humidityPct,
          forecastAvailable: Value(forecast.forecastAvailable),
          source: forecast.source.value,
          conditions: Value(forecast.conditions),
          windSpeedKmh: Value(forecast.windSpeedKmh),
          precipitationMm: Value(forecast.precipitationMm),
          expiresAt: expiresAt,
        ),
        mode: InsertMode.insertOrReplace,
      );
    } catch (e, stackTrace) {
      logger.error('Error caching forecast', error: e, stackTrace: stackTrace);
    }
  }

  /// Clear expired weather forecasts from cache
  Future<void> clearExpiredForecasts() async {
    try {
      final now = DateTime.now();

      final deleted = await (database.delete(database.weatherForecastsTable)
            ..where((tbl) => tbl.expiresAt.isSmallerThanValue(now)))
          .go();

      if (deleted > 0) {      }
    } catch (e, stackTrace) {
      logger.error('Error clearing expired forecasts', error: e, stackTrace: stackTrace);
    }
  }

  /// Clear all weather forecasts from cache
  Future<void> clearAllForecasts() async {
    try {
      await database.delete(database.weatherForecastsTable).go();
    } catch (e, stackTrace) {
      logger.error('Error clearing all forecasts', error: e, stackTrace: stackTrace);
    }
  }

  /// Clear default weather forecasts from cache (stale fallback values)
  Future<void> clearDefaultForecasts() async {
    try {
      final deleted = await (database.delete(database.weatherForecastsTable)
            ..where((tbl) => tbl.source.equals('default')))
          .go();

      if (deleted > 0) {      }
    } catch (e, stackTrace) {
      logger.error('Error clearing default forecasts', error: e, stackTrace: stackTrace);
    }
  }
}

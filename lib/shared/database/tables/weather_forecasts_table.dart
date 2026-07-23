import 'package:drift/drift.dart';

/// Weather forecasts cache table
/// Stores weather forecast data with 1-hour expiry for offline access
@DataClassName('WeatherForecastData')
class WeatherForecastsTable extends Table {
  // Primary key
  IntColumn get id => integer().autoIncrement()();

  // Location coordinates (composite key with forecast_date)
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  // Forecast date/time
  DateTimeColumn get forecastDate => dateTime()();

  // Weather data
  RealColumn get temperatureC => real()();
  IntColumn get humidityPct => integer()();

  // Metadata
  BoolColumn get forecastAvailable =>
      boolean().withDefault(const Constant(true))();
  TextColumn get source => text()(); // 'forecast', 'historical', 'default'

  // Optional detailed weather data
  TextColumn get conditions => text().nullable()();
  IntColumn get windSpeedKmh => integer().nullable()();
  RealColumn get precipitationMm => real().nullable()();

  // Cache metadata
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expiresAt => dateTime()(); // fetchedAt + 1 hour
}

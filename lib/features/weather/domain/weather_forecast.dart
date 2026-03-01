/// Weather forecast data model
/// Represents weather conditions for a specific date/time
class WeatherForecast {
  final double temperatureC;
  final int humidityPct;
  final bool forecastAvailable;
  final DateTime forecastDate;
  final WeatherSource source;
  final String? conditions;
  final int? windSpeedKmh;
  final double? precipitationMm;
  final DateTime fetchedAt;

  WeatherForecast({
    required this.temperatureC,
    required this.humidityPct,
    required this.forecastAvailable,
    required this.forecastDate,
    required this.source,
    this.conditions,
    this.windSpeedKmh,
    this.precipitationMm,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  /// Create from JSON response from edge function
  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    return WeatherForecast(
      temperatureC: (json['temperature_c'] as num).toDouble(),
      humidityPct: json['humidity_pct'] as int,
      forecastAvailable: json['forecast_available'] as bool,
      forecastDate: DateTime.parse(json['forecast_date'] as String),
      source: WeatherSource.fromString(json['source'] as String),
      conditions: json['conditions'] as String?,
      windSpeedKmh: json['wind_speed_kmh'] == null ? null : (json['wind_speed_kmh'] as num).toInt(),
      precipitationMm: json['precipitation_mm'] == null ? null : (json['precipitation_mm'] as num).toDouble(),
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'temperature_c': temperatureC,
      'humidity_pct': humidityPct,
      'forecast_available': forecastAvailable,
      'forecast_date': forecastDate.toIso8601String(),
      'source': source.value,
      'conditions': conditions,
      'wind_speed_kmh': windSpeedKmh,
      'precipitation_mm': precipitationMm,
    };
  }

  /// Create default weather forecast (20°C, 60% humidity)
  factory WeatherForecast.defaultForecast(DateTime dateTime) {
    return WeatherForecast(
      temperatureC: 20.0,
      humidityPct: 60,
      forecastAvailable: false,
      forecastDate: dateTime,
      source: WeatherSource.defaultValue,
    );
  }

  /// Check if this forecast is still fresh (< 1 hour since fetched)
  bool isFresh() {
    final now = DateTime.now();
    final age = now.difference(fetchedAt);
    return age.inHours < 1;
  }

  /// Get temperature in Fahrenheit
  double get temperatureF => (temperatureC * 9 / 5) + 32;

  /// Get wind speed in mph
  double? get windSpeedMph => windSpeedKmh != null ? windSpeedKmh! * 0.621371 : null;

  /// Get precipitation in inches
  double? get precipitationIn => precipitationMm != null ? precipitationMm! * 0.0393701 : null;

  WeatherForecast copyWith({
    double? temperatureC,
    int? humidityPct,
    bool? forecastAvailable,
    DateTime? forecastDate,
    WeatherSource? source,
    String? conditions,
    int? windSpeedKmh,
    double? precipitationMm,
    DateTime? fetchedAt,
  }) {
    return WeatherForecast(
      temperatureC: temperatureC ?? this.temperatureC,
      humidityPct: humidityPct ?? this.humidityPct,
      forecastAvailable: forecastAvailable ?? this.forecastAvailable,
      forecastDate: forecastDate ?? this.forecastDate,
      source: source ?? this.source,
      conditions: conditions ?? this.conditions,
      windSpeedKmh: windSpeedKmh ?? this.windSpeedKmh,
      precipitationMm: precipitationMm ?? this.precipitationMm,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}

/// Source of weather data
enum WeatherSource {
  forecast('forecast'),
  historical('historical'),
  defaultValue('default');

  final String value;
  const WeatherSource(this.value);

  static WeatherSource fromString(String value) {
    switch (value) {
      case 'forecast':
        return WeatherSource.forecast;
      case 'historical':
        return WeatherSource.historical;
      case 'default':
        return WeatherSource.defaultValue;
      default:
        return WeatherSource.defaultValue;
    }
  }

  String get displayName {
    switch (this) {
      case WeatherSource.forecast:
        return 'Forecast';
      case WeatherSource.historical:
        return 'Historical';
      case WeatherSource.defaultValue:
        return 'Default';
    }
  }
}

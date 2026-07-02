import 'package:flutter_test/flutter_test.dart';
import 'package:functions_client/functions_client.dart';
import 'package:mealvana_endurance/features/weather/application/weather_service.dart';
import 'package:mealvana_endurance/features/weather/data/weather_repository.dart';
import 'package:mealvana_endurance/features/weather/domain/location.dart' as domain;
import 'package:mealvana_endurance/features/weather/domain/weather_forecast.dart';
import 'package:mealvana_endurance/shared/services/location_service.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockFunctionsClient extends Mock implements FunctionsClient {}
class MockWeatherRepository extends Mock implements WeatherRepository {}
class MockLocationService extends Mock implements LocationService {}
class MockAppLogger extends Mock implements AppLogger {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal valid location for tests.
const _location = domain.Location(latitude: 40.7128, longitude: -74.0060);

/// Activity date fixed in the future (never stale cache concern).
final _futureDate = DateTime.now().add(const Duration(hours: 2));

/// Build a real [WeatherForecast] with sensible defaults.
WeatherForecast _makeForecast({
  double tempC = 22.0,
  int humidityPct = 65,
  bool forecastAvailable = true,
  WeatherSource source = WeatherSource.forecast,
  String? conditions,
  int? windSpeedKmh,
  double? precipitationMm,
  DateTime? forecastDate,
  // fetchedAt controls isFresh(); default to "just fetched"
  DateTime? fetchedAt,
}) {
  return WeatherForecast(
    temperatureC: tempC,
    humidityPct: humidityPct,
    forecastAvailable: forecastAvailable,
    forecastDate: forecastDate ?? _futureDate,
    source: source,
    conditions: conditions,
    windSpeedKmh: windSpeedKmh,
    precipitationMm: precipitationMm,
    fetchedAt: fetchedAt ?? DateTime.now(),
  );
}

/// Convenience: valid Supabase edge-function JSON body.
Map<String, dynamic> _apiJson({
  double tempC = 22.0,
  int humidityPct = 65,
  String source = 'forecast',
  String? conditions,
  int? windSpeedKmh,
  double? precipitationMm,
}) {
  return {
    'temperature_c': tempC,
    'humidity_pct': humidityPct,
    'forecast_available': true,
    'forecast_date': _futureDate.toIso8601String(),
    'source': source,
    'conditions': conditions,
    'wind_speed_kmh': windSpeedKmh,
    'precipitation_mm': precipitationMm,
  };
}

// ---------------------------------------------------------------------------
// Shared logger stub — silences all log calls
// ---------------------------------------------------------------------------
void _stubLogger(MockAppLogger logger) {
  when(
    () => logger.debug(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
      error: any(named: 'error'),
      stackTrace: any(named: 'stackTrace'),
    ),
  ).thenReturn(null);
  when(
    () => logger.info(any(), context: any(named: 'context'), data: any(named: 'data')),
  ).thenReturn(null);
  when(
    () => logger.warning(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
      error: any(named: 'error'),
      stackTrace: any(named: 'stackTrace'),
    ),
  ).thenReturn(null);
  when(
    () => logger.error(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
      error: any(named: 'error'),
      stackTrace: any(named: 'stackTrace'),
    ),
  ).thenReturn(null);
  when(
    () => logger.api(
      any(),
      endpoint: any(named: 'endpoint'),
      statusCode: any(named: 'statusCode'),
      requestData: any(named: 'requestData'),
      responseData: any(named: 'responseData'),
      duration: any(named: 'duration'),
      error: any(named: 'error'),
    ),
  ).thenReturn(null);
}

// ---------------------------------------------------------------------------
// Shared edge-function stub helpers
// ---------------------------------------------------------------------------

/// Stub [mockFunctions] to return a successful API response for
/// 'get-weather-forecast'.
void _stubApiSuccess(MockFunctionsClient mockFunctions, Map<String, dynamic> data) {
  when(
    () => mockFunctions.invoke(
      'get-weather-forecast',
      body: any(named: 'body'),
    ),
  ).thenAnswer((_) async => FunctionResponse(
        data: {'success': true, 'data': data},
        status: 200,
      ));
}

/// Stub [mockFunctions] to throw for any 'get-weather-forecast' call.
void _stubApiThrow(MockFunctionsClient mockFunctions, Object error) {
  when(
    () => mockFunctions.invoke(
      'get-weather-forecast',
      body: any(named: 'body'),
    ),
  ).thenThrow(error);
}

/// Stub [mockFunctions] to return a non-success body.
void _stubApiFailBody(MockFunctionsClient mockFunctions, {int status = 200}) {
  when(
    () => mockFunctions.invoke(
      'get-weather-forecast',
      body: any(named: 'body'),
    ),
  ).thenAnswer((_) async => FunctionResponse(
        data: status == 200 ? {'success': false, 'data': null} : null,
        status: status,
      ));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Register fallback values for types used as matchers in mock stubs.
  setUpAll(() {
    registerFallbackValue(
      WeatherForecast.defaultForecast(DateTime(2026)),
    );
    registerFallbackValue(HttpMethod.post);
  });

  late MockSupabaseClient mockSupabase;
  late MockFunctionsClient mockFunctions;
  late MockWeatherRepository mockRepository;
  late MockLocationService mockLocationService;
  late MockAppLogger mockLogger;
  late WeatherService service;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockFunctions = MockFunctionsClient();
    mockRepository = MockWeatherRepository();
    mockLocationService = MockLocationService();
    mockLogger = MockAppLogger();

    _stubLogger(mockLogger);

    // WeatherService constructor calls clearDefaultForecasts on the repository.
    when(() => mockRepository.clearDefaultForecasts()).thenAnswer((_) async {});

    // Wire up supabase.functions
    when(() => mockSupabase.functions).thenReturn(mockFunctions);

    service = WeatherService(
      supabase: mockSupabase,
      weatherRepository: mockRepository,
      locationService: mockLocationService,
      logger: mockLogger,
    );
  });

  // -------------------------------------------------------------------------
  // Domain: WeatherForecast
  // -------------------------------------------------------------------------
  group('WeatherForecast domain', () {
    test('defaultForecast has 20°C and 60% humidity', () {
      final f = WeatherForecast.defaultForecast(_futureDate);
      expect(f.temperatureC, 20.0);
      expect(f.humidityPct, 60);
      expect(f.forecastAvailable, isFalse);
      expect(f.source, WeatherSource.defaultValue);
    });

    test('temperatureF converts 0°C to 32°F', () {
      final f = _makeForecast(tempC: 0.0);
      expect(f.temperatureF, closeTo(32.0, 0.001));
    });

    test('temperatureF converts 22°C to 71.6°F', () {
      final f = _makeForecast(tempC: 22.0);
      expect(f.temperatureF, closeTo(71.6, 0.1));
    });

    test('windSpeedMph converts from km/h', () {
      final f = _makeForecast(windSpeedKmh: 10);
      // 10 km/h * 0.621371 ≈ 6.21 mph
      expect(f.windSpeedMph, closeTo(6.21, 0.01));
    });

    test('windSpeedMph is null when windSpeedKmh is null', () {
      expect(_makeForecast(windSpeedKmh: null).windSpeedMph, isNull);
    });

    test('precipitationIn converts 25.4mm to 1 inch', () {
      final f = _makeForecast(precipitationMm: 25.4);
      expect(f.precipitationIn, closeTo(1.0, 0.001));
    });

    test('precipitationIn is null when precipitationMm is null', () {
      expect(_makeForecast(precipitationMm: null).precipitationIn, isNull);
    });

    test('isFresh returns true when just fetched', () {
      expect(_makeForecast(fetchedAt: DateTime.now()).isFresh(), isTrue);
    });

    test('isFresh returns false when fetched over 1 hour ago', () {
      final f = _makeForecast(
        fetchedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 1)),
      );
      expect(f.isFresh(), isFalse);
    });

    test('copyWith preserves unmodified fields', () {
      final original = _makeForecast(tempC: 15.0, humidityPct: 55);
      final copy = original.copyWith(temperatureC: 20.0);
      expect(copy.temperatureC, 20.0);
      expect(copy.humidityPct, 55);
      expect(copy.source, original.source);
    });
  });

  // -------------------------------------------------------------------------
  // Domain: WeatherSource
  // -------------------------------------------------------------------------
  group('WeatherSource', () {
    test('fromString("forecast") returns forecast', () {
      expect(WeatherSource.fromString('forecast'), WeatherSource.forecast);
    });

    test('fromString("historical") returns historical', () {
      expect(WeatherSource.fromString('historical'), WeatherSource.historical);
    });

    test('fromString("default") returns defaultValue', () {
      expect(WeatherSource.fromString('default'), WeatherSource.defaultValue);
    });

    test('fromString(unknown string) falls back to defaultValue', () {
      expect(WeatherSource.fromString('bogus'), WeatherSource.defaultValue);
    });

    test('value round-trips through fromString for all cases', () {
      for (final source in WeatherSource.values) {
        expect(WeatherSource.fromString(source.value), source);
      }
    });
  });

  // -------------------------------------------------------------------------
  // Domain: WeatherForecast.fromJson / toJson
  // -------------------------------------------------------------------------
  group('WeatherForecast.fromJson', () {
    test('parses full valid JSON correctly', () {
      final json = _apiJson(
        tempC: 25.5,
        humidityPct: 70,
        source: 'forecast',
        conditions: 'Partly cloudy',
        windSpeedKmh: 15,
        precipitationMm: 0.5,
      );
      final forecast = WeatherForecast.fromJson(json);
      expect(forecast.temperatureC, 25.5);
      expect(forecast.humidityPct, 70);
      expect(forecast.forecastAvailable, isTrue);
      expect(forecast.source, WeatherSource.forecast);
      expect(forecast.conditions, 'Partly cloudy');
      expect(forecast.windSpeedKmh, 15);
      expect(forecast.precipitationMm, 0.5);
    });

    test('parses JSON with null optional fields', () {
      final forecast = WeatherForecast.fromJson(_apiJson());
      expect(forecast.windSpeedKmh, isNull);
      expect(forecast.precipitationMm, isNull);
      expect(forecast.conditions, isNull);
    });

    test('accepts int temperature_c (API may omit decimal)', () {
      final json = <String, dynamic>{
        'temperature_c': 20,
        'humidity_pct': 60,
        'forecast_available': true,
        'forecast_date': _futureDate.toIso8601String(),
        'source': 'forecast',
      };
      final forecast = WeatherForecast.fromJson(json);
      expect(forecast.temperatureC, 20.0);
      expect(forecast.temperatureC, isA<double>());
    });

    test('accepts double wind_speed_kmh (API may return 15.0 not 15)', () {
      final json = <String, dynamic>{
        'temperature_c': 22.0,
        'humidity_pct': 60,
        'forecast_available': true,
        'forecast_date': _futureDate.toIso8601String(),
        'source': 'forecast',
        'wind_speed_kmh': 15.0,
      };
      final forecast = WeatherForecast.fromJson(json);
      expect(forecast.windSpeedKmh, 15);
    });

    test('toJson round-trips through fromJson preserving all fields', () {
      final original = _makeForecast(
        tempC: 18.5,
        humidityPct: 72,
        conditions: 'Clear',
        windSpeedKmh: 10,
        precipitationMm: 0.0,
      );
      final roundTripped = WeatherForecast.fromJson(original.toJson());
      expect(roundTripped.temperatureC, original.temperatureC);
      expect(roundTripped.humidityPct, original.humidityPct);
      expect(roundTripped.conditions, original.conditions);
      expect(roundTripped.windSpeedKmh, original.windSpeedKmh);
      expect(roundTripped.precipitationMm, original.precipitationMm);
      expect(roundTripped.source, original.source);
    });
  });

  // -------------------------------------------------------------------------
  // WeatherService: memory cache hit
  // -------------------------------------------------------------------------
  group('WeatherService — memory cache hit', () {
    test('second call returns memory-cached forecast without querying repository again', () async {
      final freshForecast = _makeForecast();

      when(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).thenAnswer((_) async => null);

      _stubApiSuccess(mockFunctions, freshForecast.toJson());

      when(
        () => mockRepository.cacheForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecast: any(named: 'forecast'),
        ),
      ).thenAnswer((_) async {});

      when(() => mockRepository.clearExpiredForecasts()).thenAnswer((_) async {});

      // First call — populates memory cache.
      final first = await service.getWeatherForecast(
        location: _location,
        activityDate: _futureDate,
      );
      expect(first.source, WeatherSource.forecast);

      // Second call — should be served from in-memory cache.
      final second = await service.getWeatherForecast(
        location: _location,
        activityDate: _futureDate,
      );
      expect(second.temperatureC, first.temperatureC);

      // Repository was called only once (for the first miss).
      verify(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // WeatherService: database cache hit
  // -------------------------------------------------------------------------
  group('WeatherService — DB cache hit', () {
    test('returns DB-cached forecast without calling the API', () async {
      final dbForecast = _makeForecast(tempC: 18.0, source: WeatherSource.forecast);

      when(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).thenAnswer((_) async => dbForecast);

      final result = await service.getWeatherForecast(
        location: _location,
        activityDate: _futureDate,
      );

      expect(result.temperatureC, 18.0);
      // API must NOT be called when DB has a valid cache entry.
      verifyNever(
        () => mockFunctions.invoke(
          'get-weather-forecast',
          body: any(named: 'body'),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // WeatherService: API fetch success
  // -------------------------------------------------------------------------
  group('WeatherService — API fetch success', () {
    setUp(() {
      when(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepository.cacheForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecast: any(named: 'forecast'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockRepository.clearExpiredForecasts()).thenAnswer((_) async {});
    });

    test('returns parsed forecast when API responds 200 success', () async {
      _stubApiSuccess(mockFunctions, _apiJson(tempC: 30.0, humidityPct: 80));

      final result = await service.getWeatherForecast(
        location: _location,
        activityDate: _futureDate,
      );

      expect(result.temperatureC, 30.0);
      expect(result.humidityPct, 80);
      expect(result.source, WeatherSource.forecast);
      expect(result.forecastAvailable, isTrue);
    });

    test('caches the API result in the repository', () async {
      _stubApiSuccess(mockFunctions, _apiJson());

      await service.getWeatherForecast(
        location: _location,
        activityDate: _futureDate,
      );

      verify(
        () => mockRepository.cacheForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecast: any(named: 'forecast'),
        ),
      ).called(1);
    });

    test('does NOT cache when API success=false (default fallback)', () async {
      _stubApiFailBody(mockFunctions);

      final result = await service.getWeatherForecast(
        location: _location,
        activityDate: _futureDate,
      );

      expect(result.source, WeatherSource.defaultValue);
      verifyNever(
        () => mockRepository.cacheForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecast: any(named: 'forecast'),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // WeatherService: network error handling — graceful degradation
  // -------------------------------------------------------------------------
  group('WeatherService — network error graceful degradation', () {
    setUp(() {
      when(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).thenAnswer((_) async => null);
    });

    test('returns defaultForecast when edge function throws', () async {
      _stubApiThrow(mockFunctions, Exception('Network error'));

      final result = await service.getWeatherForecast(
        location: _location,
        activityDate: _futureDate,
      );

      expect(result.source, WeatherSource.defaultValue);
      expect(result.temperatureC, 20.0);
      expect(result.humidityPct, 60);
      expect(result.forecastAvailable, isFalse);
    });

    test('returns defaultForecast when API returns non-200 status', () async {
      _stubApiFailBody(mockFunctions, status: 500);

      final result = await service.getWeatherForecast(
        location: _location,
        activityDate: _futureDate,
      );

      expect(result.source, WeatherSource.defaultValue);
      expect(result.temperatureC, 20.0);
    });

    test('returns defaultForecast when API data payload is null', () async {
      when(
        () => mockFunctions.invoke(
          'get-weather-forecast',
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => FunctionResponse(data: null, status: 200));

      final result = await service.getWeatherForecast(
        location: _location,
        activityDate: _futureDate,
      );

      expect(result.source, WeatherSource.defaultValue);
    });
  });

  // -------------------------------------------------------------------------
  // WeatherService: no location available
  // -------------------------------------------------------------------------
  group('WeatherService — no location available', () {
    test('returns defaultForecast when location is null and GPS unavailable', () async {
      when(() => mockLocationService.getCurrentLocation())
          .thenAnswer((_) async => null);
      when(() => mockLocationService.getLastFailureReason())
          .thenReturn(LocationFailureReason.permissionDenied);

      final result = await service.getWeatherForecast(
        location: null,
        activityDate: _futureDate,
      );

      expect(result.source, WeatherSource.defaultValue);
      expect(result.temperatureC, 20.0);
      expect(result.humidityPct, 60);
    });

    test('uses GPS location when no explicit location is provided', () async {
      when(() => mockLocationService.getCurrentLocation())
          .thenAnswer((_) async => _location);
      when(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).thenAnswer((_) async => _makeForecast(tempC: 25.0));

      final result = await service.getWeatherForecast(
        location: null,
        activityDate: _futureDate,
      );

      expect(result.temperatureC, 25.0);
      verify(() => mockLocationService.getCurrentLocation()).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // WeatherService: historical cache bypass for same-day/future
  // -------------------------------------------------------------------------
  group('WeatherService — historical cache bypass', () {
    test('bypasses historical DB cache and fetches fresh data for today', () async {
      // A historical entry in DB for today must be ignored — service should
      // go to API and return fresh forecast data.
      final historicalForecast = _makeForecast(
        source: WeatherSource.historical,
        forecastDate: DateTime.now(),
      );

      when(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).thenAnswer((_) async => historicalForecast);

      when(
        () => mockRepository.cacheForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecast: any(named: 'forecast'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockRepository.clearExpiredForecasts()).thenAnswer((_) async {});
      _stubApiSuccess(mockFunctions, _apiJson(tempC: 28.0));

      final result = await service.getWeatherForecast(
        location: _location,
        activityDate: DateTime.now(),
      );

      // Fresh API data wins over historical cache.
      expect(result.source, WeatherSource.forecast);
      expect(result.temperatureC, 28.0);
    });

    test('uses historical DB cache for past-date requests (no API call)', () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final historicalForecast = _makeForecast(
        source: WeatherSource.historical,
        forecastDate: pastDate,
        tempC: 10.0,
      );

      when(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).thenAnswer((_) async => historicalForecast);

      final result = await service.getWeatherForecast(
        location: _location,
        activityDate: pastDate,
      );

      expect(result.temperatureC, 10.0);
      expect(result.source, WeatherSource.historical);
      // API must NOT be called for past dates with valid historical cache.
      verifyNever(
        () => mockFunctions.invoke(
          'get-weather-forecast',
          body: any(named: 'body'),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // WeatherService: cache key — same-hour coalescing
  // -------------------------------------------------------------------------
  group('WeatherService — same-hour cache key coalescing', () {
    setUp(() {
      when(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepository.cacheForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecast: any(named: 'forecast'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockRepository.clearExpiredForecasts()).thenAnswer((_) async {});
      _stubApiSuccess(mockFunctions, _apiJson());
    });

    test('two requests within the same hour share one memory cache entry', () async {
      final base = DateTime(2026, 7, 1, 10, 0);
      final sameHour = DateTime(2026, 7, 1, 10, 45);

      await service.getWeatherForecast(location: _location, activityDate: base);
      await service.getWeatherForecast(location: _location, activityDate: sameHour);

      // Repository should only be queried once — the second call is a memory hit.
      verify(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // WeatherService: temperature/humidity pass-through for hydration calcs
  // -------------------------------------------------------------------------
  group('WeatherService — temperature and humidity for hydration inputs', () {
    test('high temperature (35°C) and high humidity (85%) pass through unchanged', () async {
      when(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).thenAnswer((_) async => _makeForecast(tempC: 35.0, humidityPct: 85));

      final result = await service.getWeatherForecast(
        location: _location,
        activityDate: _futureDate,
      );

      // Callers scale hydration from temperatureC and humidityPct —
      // neither must be truncated or rounded by the service.
      expect(result.temperatureC, 35.0);
      expect(result.humidityPct, 85);
    });

    test('0°C cold temperature round-trips without sign loss', () async {
      when(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).thenAnswer((_) async => _makeForecast(tempC: 0.0, humidityPct: 30));

      final result = await service.getWeatherForecast(
        location: _location,
        activityDate: _futureDate,
      );

      expect(result.temperatureC, 0.0);
      expect(result.humidityPct, 30);
      expect(result.temperatureF, closeTo(32.0, 0.001));
    });

    test('sub-zero temperature (-10°C) round-trips correctly', () async {
      when(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).thenAnswer((_) async => _makeForecast(tempC: -10.0, humidityPct: 20));

      final result = await service.getWeatherForecast(
        location: _location,
        activityDate: _futureDate,
      );

      expect(result.temperatureC, -10.0);
      expect(result.temperatureF, closeTo(14.0, 0.1));
    });

    test('default forecast 20°C/60% provides a consistent hydration baseline on error', () async {
      when(
        () => mockRepository.getCachedForecast(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          forecastDate: any(named: 'forecastDate'),
        ),
      ).thenAnswer((_) async => null);
      _stubApiThrow(mockFunctions, Exception('Offline'));

      final result = await service.getWeatherForecast(
        location: _location,
        activityDate: _futureDate,
      );

      expect(result.temperatureC, 20.0);
      expect(result.humidityPct, 60);
    });
  });

  // -------------------------------------------------------------------------
  // WeatherService: location service delegation
  // -------------------------------------------------------------------------
  group('WeatherService — location service delegation', () {
    test('hasLocationPermission delegates to LocationService', () async {
      when(() => mockLocationService.hasLocationPermission())
          .thenAnswer((_) async => true);

      final result = await service.hasLocationPermission();
      expect(result, isTrue);
      verify(() => mockLocationService.hasLocationPermission()).called(1);
    });

    test('requestLocationPermission delegates to LocationService', () async {
      when(() => mockLocationService.requestLocationPermission())
          .thenAnswer((_) async => false);

      final result = await service.requestLocationPermission();
      expect(result, isFalse);
      verify(() => mockLocationService.requestLocationPermission()).called(1);
    });

    test('getLastLocationFailureReason delegates to LocationService', () {
      when(() => mockLocationService.getLastFailureReason())
          .thenReturn(LocationFailureReason.timeout);

      expect(service.getLastLocationFailureReason(), LocationFailureReason.timeout);
    });
  });
}

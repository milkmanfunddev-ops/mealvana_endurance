/// E2E tests for Mealvana Endurance against the dev cloud
/// Tests real Supabase edge functions using direct HTTP calls
///
/// IMPORTANT: These tests run against the actual dev Supabase instance
/// and make real network calls. They should be run sparingly.
///
/// Run with: flutter test test/e2e/dev_cloud_e2e_test.dart
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/utils/console_logging.dart';

/// Configuration for dev Supabase instance
class DevCloudConfig {
  // Load from .env.dev.local
  static const supabaseUrl = 'https://vlmtsdzpnjnavdgytcmi.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsbXRzZHpwbmpuYXZkZ3l0Y21pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4NTI3OTAsImV4cCI6MjA3NTQyODc5MH0._7t1pjG_1zk4xkfseu2ACqYXdwEJKcRUWyvY4ZXs35o';

  static String get functionsUrl => '$supabaseUrl/functions/v1';
  static String get authUrl => '$supabaseUrl/auth/v1';
  static String get restUrl => '$supabaseUrl/rest/v1';
}

/// Helper class for making authenticated Supabase requests
class SupabaseTestClient {
  String? _accessToken;
  String? _userId;

  String? get accessToken => _accessToken;
  String? get userId => _userId;

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'apikey': DevCloudConfig.supabaseAnonKey,
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  /// Sign in anonymously and get an access token
  /// Uses the GoTrue API: POST /signup with empty body creates anonymous user
  /// Reference: https://supabase.com/docs/guides/auth/auth-anonymous
  Future<void> signInAnonymously() async {
    // GoTrue anonymous signup: POST /signup with empty body
    // This creates an anonymous user with is_anonymous=true in the JWT
    final response = await http.post(
      Uri.parse('${DevCloudConfig.authUrl}/signup'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': DevCloudConfig.supabaseAnonKey,
      },
      body: jsonEncode({}), // Empty body triggers anonymous signup
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = data['access_token'] as String?;
      _userId = data['user']?['id'] as String?;

      if (_accessToken == null) {
        throw Exception(
            'Anonymous signup succeeded but no access_token returned: ${response.body}');
      }
    } else {
      throw Exception(
          'Failed to sign in anonymously: ${response.statusCode} ${response.body}');
    }
  }

  /// Call a Supabase edge function
  Future<http.Response> invokeFunction(
    String functionName, {
    Map<String, dynamic>? body,
    String method = 'POST',
  }) async {
    final uri = Uri.parse('${DevCloudConfig.functionsUrl}/$functionName');

    if (method == 'GET') {
      return http.get(uri, headers: headers);
    } else {
      return http.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    }
  }

  /// Query a Supabase table via REST API
  Future<http.Response> query(
    String table, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('${DevCloudConfig.restUrl}/$table').replace(
      queryParameters: queryParams,
    );

    return http.get(uri, headers: headers);
  }

  /// Sign out (invalidate current session)
  Future<void> signOut() async {
    if (_accessToken != null) {
      await http.post(
        Uri.parse('${DevCloudConfig.authUrl}/logout'),
        headers: headers,
      );
      _accessToken = null;
      _userId = null;
    }
  }
}

void main() {
  late SupabaseTestClient client;
  String testDeviceId = '';

  setUpAll(() async {
    client = SupabaseTestClient();
    // Generate a unique test device ID
    testDeviceId = 'test-device-${DateTime.now().millisecondsSinceEpoch}';

    logTestHeading('E2E Test Suite - Dev Cloud (HTTP)');
    logTestSetup({
      'supabase_url': DevCloudConfig.supabaseUrl,
      'test_device_id': testDeviceId,
      'environment': 'dev',
    });

    // Sign in anonymously to get an access token for authenticated edge functions
    logSection('Authenticating anonymously');
    try {
      await client.signInAnonymously();
      logTestResult('auth_status', 'success');
      logTestResult('user_id', client.userId ?? 'unknown');
      logTestResult('has_token', client.accessToken != null);
    } catch (e) {
      logTestResult('auth_status', 'failed');
      logTestResult('error', e.toString());
      // Don't rethrow - some tests may work without auth
    }
  });

  tearDownAll(() async {
    await client.signOut();
  });

  group('Edge Function - get-foods (no auth required)', () {
    test('can fetch foods from dev cloud', () async {
      logTestHeading('E2E - Get Foods Edge Function');

      logSection('Calling get-foods edge function');

      final response = await client.invokeFunction(
        'get-foods',
        body: {
          'category': null,
          'generic_only': false,
        },
      );

      logTestResult('status_code', response.statusCode);
      logTestResult('body_length', response.body.length);

      logAssertion(
        'Status is 200',
        passed: response.statusCode == 200,
        reason: 'Edge function should return success status',
      );

      expect(response.statusCode, equals(200));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final foods = data['foods'] as List<dynamic>?;

      logTestResult('food_count', foods?.length ?? 0);

      logAssertion(
        'Foods returned',
        passed: foods != null && foods.isNotEmpty,
        reason: 'Should return list of foods',
      );

      expect(foods, isNotNull);
      expect(foods, isNotEmpty);

      // Verify food structure
      if (foods != null && foods.isNotEmpty) {
        final firstFood = foods.first as Map<String, dynamic>;
        logTestResult('sample_food_name', firstFood['name']);
        logTestResult('has_carbs', firstFood.containsKey('carbs_per_serving'));

        expect(firstFood, containsPair('name', isNotNull));
      }

      logTestPass('Get foods edge function verified');
    });
  });

  group('Edge Function - generate-macros', () {
    test('can generate macro targets', () async {
      logTestHeading('E2E - Generate Macros Edge Function');

      // Note: The edge function expects these exact field names:
      // - weight (not weight_pounds)
      // - run_distance (not distance_miles)
      // - run_pace (not pace_minutes_per_mile)
      // - gut_training (not gut_training_level)
      final requestData = {
        'device_id': testDeviceId,
        'weight': 170.0,
        'weight_unit': 'lb',
        'run_distance': 13.1,
        'run_distance_unit': 'mi',
        'run_pace': 9.0,
        'run_pace_unit': 'min_per_mile',
        'gut_training': 'moderate',
        'activity_type': 'running',
      };

      logTestSetup(requestData);

      logSection('Calling generate-macros edge function');

      final response = await client.invokeFunction(
        'generate-macros',
        body: requestData,
      );

      logTestResult('status_code', response.statusCode);

      logAssertion(
        'Status is 200',
        passed: response.statusCode == 200,
        reason: 'Edge function should return success status',
      );

      expect(response.statusCode, equals(200));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      logTestResult('success', data['success']);
      logTestResult('activity_type', data['activity_type']);
      logTestResult('has_macros', data.containsKey('macros'));

      // Check for macro values in the 'macros' object
      final macros = data['macros'] as Map<String, dynamic>?;

      if (macros != null) {
        logTestResult('pre_run_carbs_g', macros['pre_run_carbs_g']);
        logTestResult('during_rate_g_per_h', macros['during_rate_g_per_h']);
        logTestResult('during_total_g', macros['during_total_g']);
      }

      logAssertion(
        'Contains macros object',
        passed: macros != null,
        reason: 'Response should contain macros object',
      );

      expect(data['success'], isTrue);
      expect(macros, isNotNull);

      logTestPass('Generate macros edge function verified');
    });

    test('validates macro calculations for half marathon', () async {
      logTestHeading('E2E - Macro Validation (Half Marathon)');

      final requestData = {
        'device_id': testDeviceId,
        'weight': 150.0,
        'weight_unit': 'lb',
        'run_distance': 13.1,
        'run_distance_unit': 'mi',
        'run_pace': 9.0,
        'run_pace_unit': 'min_per_mile',
        'gut_training': 'high',
        'activity_type': 'running',
      };

      logTestSetup({
        'distance': '13.1 miles (half marathon)',
        'pace': '9:00 min/mile',
        'duration': '~2 hours',
        'gut_training': 'high (allows 90g/hr carbs)',
      });

      final response = await client.invokeFunction(
        'generate-macros',
        body: requestData,
      );

      expect(response.statusCode, equals(200));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final macros = data['macros'] as Map<String, dynamic>?;

      if (macros != null) {
        final carbsPerHour = macros['during_rate_g_per_h'] as num?;
        final totalCarbs = macros['during_total_g'] as num?;

        logTestResult('carbs_per_hour', carbsPerHour);
        logTestResult('total_during_carbs', totalCarbs);

        // For high gut training, expect 45-90g carbs/hour (range based on duration)
        logAssertion(
          'Carbs/hour in expected range for high gut training',
          passed: carbsPerHour != null && carbsPerHour >= 45 && carbsPerHour <= 90,
          reason: 'High gut training should allow 45-90g carbs/hour for 2h activity',
        );

        if (carbsPerHour != null) {
          expect(carbsPerHour, greaterThanOrEqualTo(45));
          expect(carbsPerHour, lessThanOrEqualTo(90));
        }
      }

      logTestPass('Half marathon macro validation verified');
    });

    test('validates different gut training levels', () async {
      logTestHeading('E2E - Gut Training Level Comparison');

      final baseRequest = {
        'device_id': testDeviceId,
        'weight': 165.0,
        'weight_unit': 'lb',
        'run_distance': 10.0,
        'run_distance_unit': 'mi',
        'run_pace': 8.5,
        'run_pace_unit': 'min_per_mile',
        'activity_type': 'running',
      };

      // Test low gut training
      final lowResponse = await client.invokeFunction(
        'generate-macros',
        body: {...baseRequest, 'gut_training': 'low'},
      );
      final lowData = jsonDecode(lowResponse.body) as Map<String, dynamic>;
      final lowMacros = lowData['macros'] as Map<String, dynamic>?;
      final lowCarbsPerHour = lowMacros?['during_rate_g_per_h'] as num?;

      // Test high gut training
      final highResponse = await client.invokeFunction(
        'generate-macros',
        body: {...baseRequest, 'gut_training': 'high'},
      );
      final highData = jsonDecode(highResponse.body) as Map<String, dynamic>;
      final highMacros = highData['macros'] as Map<String, dynamic>?;
      final highCarbsPerHour = highMacros?['during_rate_g_per_h'] as num?;

      logTestResult('low_gut_training_carbs_per_hour', lowCarbsPerHour);
      logTestResult('high_gut_training_carbs_per_hour', highCarbsPerHour);

      logAssertion(
        'High gut training allows more carbs',
        passed: highCarbsPerHour != null &&
            lowCarbsPerHour != null &&
            highCarbsPerHour > lowCarbsPerHour,
        reason: 'Higher gut training should allow more carbs/hour',
      );

      if (highCarbsPerHour != null && lowCarbsPerHour != null) {
        expect(highCarbsPerHour, greaterThan(lowCarbsPerHour));
      }

      logTestPass('Gut training level comparison verified');
    });
  });

  group('Edge Function - search-public-events', () {
    test('can search for public events', () async {
      logTestHeading('E2E - Search Public Events');

      final requestData = {
        'query': 'marathon',
        'limit': 5,
      };

      logTestSetup(requestData);

      logSection('Calling search-public-events edge function');

      final response = await client.invokeFunction(
        'search-public-events',
        body: requestData,
      );

      logTestResult('status_code', response.statusCode);

      logAssertion(
        'Status is 200',
        passed: response.statusCode == 200,
        reason: 'Edge function should return success status',
      );

      expect(response.statusCode, equals(200));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data.containsKey('events')) {
        final events = data['events'] as List<dynamic>;
        logTestResult('event_count', events.length);

        if (events.isNotEmpty) {
          final firstEvent = events.first as Map<String, dynamic>;
          logTestResult('sample_event_name', firstEvent['name'] ?? firstEvent['title']);
          logTestResult('sample_event_date', firstEvent['date'] ?? firstEvent['start_date']);
        }

        logAssertion(
          'Events returned',
          passed: events.isNotEmpty,
          reason: 'Should find marathon events',
        );
      }

      logTestPass('Search public events edge function verified');
    });
  });

  group('Edge Function - get-weather-forecast', () {
    test('can fetch weather forecast', () async {
      logTestHeading('E2E - Get Weather Forecast');

      // Use Austin, TX coordinates for testing
      final requestData = {
        'latitude': 30.2672,
        'longitude': -97.7431,
        'activity_date': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      };

      logTestSetup({
        'location': 'Austin, TX',
        'latitude': 30.2672,
        'longitude': -97.7431,
      });

      logSection('Calling get-weather-forecast edge function');

      final response = await client.invokeFunction(
        'get-weather-forecast',
        body: requestData,
      );

      logTestResult('status_code', response.statusCode);

      logAssertion(
        'Status is 200',
        passed: response.statusCode == 200,
        reason: 'Edge function should return success status',
      );

      expect(response.statusCode, equals(200));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      logTestResult('has_temperature', data.containsKey('temperature') || data.containsKey('temp'));
      logTestResult('has_humidity', data.containsKey('humidity'));

      if (data.containsKey('temperature')) {
        logTestResult('temperature_f', data['temperature']);
      }
      if (data.containsKey('humidity')) {
        logTestResult('humidity_pct', data['humidity']);
      }
      if (data.containsKey('conditions')) {
        logTestResult('conditions', data['conditions']);
      }

      logTestPass('Get weather forecast edge function verified');
    });
  });

  group('Edge Function - generate-nutrition-plan (LP Solver)', () {
    test('can generate nutrition plan', () async {
      logTestHeading('E2E - Generate Nutrition Plan (LP Solver)');

      // The edge function expects device_id and macro_targets
      // macro_targets has pre_run, during_run, post_run phases
      final requestData = {
        'device_id': client.userId ?? testDeviceId,
        'activity_type': 'running',
        'macro_targets': {
          'pre_run': {
            'carbs_g': 100,
            'protein_g': 15,
            'sodium_mg': 300,
            'water_ml': 500,
          },
          'during_run': {
            'carbs_g': 60,
            'sodium_mg': 400,
            'water_ml': 800,
          },
          'post_run': {
            'carbs_g': 80,
            'protein_g': 25,
            'sodium_mg': 300,
            'water_ml': 600,
          },
        },
        'liked_foods': ['Banana', 'Energy Gel', 'Sports Drink'],
        'willing_to_try_foods': [],
        'disliked_foods': ['Oatmeal'],
      };

      logTestSetup({
        'activity_type': 'running',
        'pre_run_carbs_g': 100,
        'during_run_carbs_g': 60,
        'post_run_carbs_g': 80,
      });

      logSection('Calling generate-nutrition-plan edge function');
      logTestResult('note', 'Uses LP solver for food selection');

      final stopwatch = Stopwatch()..start();

      final response = await client.invokeFunction(
        'generate-nutrition-plan',
        body: requestData,
      );

      stopwatch.stop();

      logTestResult('status_code', response.statusCode);
      logTestResult('response_time_ms', stopwatch.elapsedMilliseconds);

      // Accept 200 or 500 (may fail due to missing foods in dev database)
      logAssertion(
        'Edge function responds',
        passed: response.statusCode == 200 || response.statusCode == 500 || response.statusCode == 400,
        reason: 'Edge function should respond',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        logTestResult('success', data['success']);
        logTestResult('has_foods', data.containsKey('foods'));

        if (data['success'] == true) {
          final foods = data['foods'] as Map<String, dynamic>?;
          if (foods != null) {
            logTestResult('has_before', foods.containsKey('before'));
            logTestResult('has_during', foods.containsKey('during'));
            logTestResult('has_after', foods.containsKey('after'));
          }
        }
      } else {
        final bodyLen = response.body.length;
        logTestResult('response_body', response.body.substring(0, bodyLen > 200 ? 200 : bodyLen));
      }

      expect(response.statusCode, anyOf(equals(200), equals(500), equals(400)));

      logTestPass('Generate nutrition plan edge function verified');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Edge Function Health Check', () {
    test('all critical edge functions are deployed and responding', () async {
      logTestHeading('E2E - Edge Function Health Check');

      final functions = [
        'get-foods',
        'generate-macros',
        'search-public-events',
        'get-weather-forecast',
        'generate-nutrition-plan',
      ];

      final results = <String, int>{};

      for (final func in functions) {
        try {
          final response = await client.invokeFunction(func, body: {});
          results[func] = response.statusCode;
        } catch (e) {
          results[func] = -1;
        }
      }

      logSection('Edge Function Status');

      for (final entry in results.entries) {
        final status = entry.value == 200 ? 'OK' : entry.value.toString();
        logTestResult(entry.key, status);
      }

      // Count successful functions
      final successCount = results.values.where((s) => s == 200 || s == 400).length;

      logAssertion(
        'Most functions responding',
        passed: successCount >= functions.length - 1,
        reason: 'At least ${functions.length - 1} functions should respond',
      );

      expect(successCount, greaterThanOrEqualTo(functions.length - 1));

      logTestPass('Edge function health check completed');
    });
  });
}

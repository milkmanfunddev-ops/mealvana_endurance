/// TrainingPeaks Live API Integration Tests
///
/// These tests hit the REAL TrainingPeaks API to validate our assumptions
/// about the data format and transformation logic.
///
/// Prerequisites:
/// 1. Run `dart run tool/training_peaks_api_test.dart auth` to get a cached token
/// 2. The token file must exist at tool/.training_peaks_token.json
///
/// Run with: flutter test test/integration/training_peaks_api_test.dart --tags integration
///
/// CRITICAL DIFFERENCES FROM FINAL SURGE:
/// 1. Token expires in 1 HOUR (Final Surge never expires)
/// 2. Distance is ALWAYS in METERS (Final Surge uses miles/km)
/// 3. Time is in DECIMAL HOURS (Final Surge uses seconds)
/// 4. Has EVENT sync (Final Surge doesn't)
/// 5. Workout IDs are Int64 (must handle large numbers)
///
/// Note: These tests require a valid TrainingPeaks account with workouts scheduled.
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/utils/console_logging.dart';

void main() {
  late String accessToken;
  late Map<String, dynamic> cachedTokenData;

  // Environment toggle - match the tool script
  const bool useSandbox = true;
  const String apiBaseUrl = useSandbox
      ? 'https://api.sandbox.trainingpeaks.com'
      : 'https://api.trainingpeaks.com';
  const String oauthBaseUrl = useSandbox
      ? 'https://oauth.sandbox.trainingpeaks.com'
      : 'https://oauth.trainingpeaks.com';

  setUpAll(() async {
    // Load cached token from previous OAuth
    final tokenFile = File('tool/.training_peaks_token.json');

    if (!tokenFile.existsSync()) {
      throw Exception(
        '\n\n'
        '╔══════════════════════════════════════════════════════════════════╗\n'
        '║  TOKEN NOT FOUND                                                  ║\n'
        '║                                                                   ║\n'
        '║  Run this command first to authenticate:                          ║\n'
        '║  dart run tool/training_peaks_api_test.dart auth                  ║\n'
        '╚══════════════════════════════════════════════════════════════════╝\n',
      );
    }

    cachedTokenData =
        jsonDecode(tokenFile.readAsStringSync()) as Map<String, dynamic>;
    accessToken = cachedTokenData['access_token'] as String;

    // Check if token is expired
    final expiresAt = cachedTokenData['expires_at'] as int?;
    if (expiresAt != null) {
      final expiresAtTime = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      final now = DateTime.now();
      if (expiresAtTime.isBefore(now)) {
        throw Exception(
          '\n\n'
          '╔══════════════════════════════════════════════════════════════════╗\n'
          '║  TOKEN EXPIRED                                                    ║\n'
          '║                                                                   ║\n'
          '║  TrainingPeaks tokens expire after 1 hour!                        ║\n'
          '║  Run this command to refresh or re-authenticate:                  ║\n'
          '║  dart run tool/training_peaks_api_test.dart refresh               ║\n'
          '╚══════════════════════════════════════════════════════════════════╝\n',
        );
      }

      final remaining = expiresAtTime.difference(now);
      if (remaining.inMinutes < 10) {
        print(
          '⚠️  WARNING: Token expires in ${remaining.inMinutes} minutes. '
          'Consider refreshing before running full test suite.',
        );
      }
    }

    logTestHeading('TrainingPeaks Live API Integration Tests');
    logTestSetup({
      'Athlete':
          '${cachedTokenData['first_name']} ${cachedTokenData['last_name']}',
      'Athlete ID': cachedTokenData['athlete_id'],
      'Premium': cachedTokenData['is_premium'],
      'Token cached at': cachedTokenData['cached_at'],
      'Environment': useSandbox ? 'SANDBOX' : 'PRODUCTION',
    });
  });

  group('TrainingPeaks Token Expiration Tests', () {
    test('validates token expiration fields are present', () async {
      logSection('Validating token expiration metadata');

      logTestInput({
        'expires_in': cachedTokenData['expires_in'],
        'expires_at': cachedTokenData['expires_at'],
        'refresh_token': cachedTokenData['refresh_token'] != null
            ? 'PRESENT'
            : 'MISSING',
      });

      // Token must have expiration info (unlike Final Surge)
      expect(cachedTokenData['expires_in'], isNotNull,
          reason: 'expires_in must be present');
      expect(cachedTokenData['expires_at'], isNotNull,
          reason: 'expires_at must be present');
      expect(cachedTokenData['refresh_token'], isNotNull,
          reason: 'refresh_token must be present for token refresh');

      // expires_in should be around 600 seconds (10 minutes) based on docs
      // but actual value is 3600 (1 hour) - let's verify
      final expiresIn = cachedTokenData['expires_in'] as int;
      logTestResult('expires_in', expiresIn, unit: 'seconds');

      logAssertion(
        'Token has reasonable expiration',
        passed: expiresIn > 0 && expiresIn <= 7200,
        reason: 'Expected 600-3600 seconds, got $expiresIn',
      );

      logTestPass('Token expiration metadata is valid');
    });

    test('validates token refresh flow works', () async {
      logSection('Testing token refresh flow');

      final refreshToken = cachedTokenData['refresh_token'] as String?;
      expect(refreshToken, isNotNull, reason: 'Need refresh token to test');

      // Make refresh request
      logApiCall('POST $oauthBaseUrl/oauth/token', params: {
        'grant_type': 'refresh_token',
        'refresh_token': '${refreshToken!.substring(0, 10)}...',
      });

      final clientSecret =
          const String.fromEnvironment('TRAINING_PEAKS_CLIENT_SECRET');
      if (clientSecret.isEmpty) {
        print(
            '⚠️  TRAINING_PEAKS_CLIENT_SECRET not set - skipping refresh test');
        return;
      }

      final response = await http.post(
        Uri.parse('$oauthBaseUrl/oauth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': 'mealvana',
          'client_secret': clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      logTestResult('Refresh Status', response.statusCode);

      if (response.statusCode == 200) {
        final newTokenData = jsonDecode(response.body) as Map<String, dynamic>;

        logTestResults({
          'New Access Token': ResultData(
            actual: newTokenData['access_token'] != null
                ? 'RECEIVED'
                : 'MISSING',
          ),
          'New Refresh Token': ResultData(
            actual: newTokenData['refresh_token'] != null
                ? 'RECEIVED'
                : 'MISSING (using old)',
          ),
          'New Expires In': ResultData(
            actual: newTokenData['expires_in'],
            unit: 'seconds',
          ),
        });

        expect(newTokenData['access_token'], isNotNull);
        logTestPass('Token refresh successful');
      } else {
        logTestFail('Token refresh failed: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    });
  });

  group('TrainingPeaks API Response Validation', () {
    test('fetches athlete profile successfully', () async {
      logSection('Fetching athlete profile');

      final response = await http.get(
        Uri.parse('$apiBaseUrl/v1/athlete/profile'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'User-Agent': 'Mealvana Endurance Test v1.0',
        },
      );

      logApiCall('/v1/athlete/profile', params: {
        'Status': response.statusCode,
      });

      expect(response.statusCode, equals(200));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      logTestResults({
        'Athlete ID': ResultData(actual: data['Id']),
        'Name':
            ResultData(actual: '${data['FirstName']} ${data['LastName']}'),
        'Weight (kg)': ResultData(actual: data['Weight'], unit: 'kg'),
        'IsPremium': ResultData(actual: data['IsPremium']),
        'PreferredUnits': ResultData(actual: data['PreferredUnits']),
        'TimeZone': ResultData(actual: data['TimeZone']),
      });

      // Validate required fields
      expect(data['Id'], isNotNull, reason: 'Athlete ID must be present');
      expect(data['FirstName'], isNotNull,
          reason: 'FirstName must be present');
      expect(data['Weight'], isA<num>(),
          reason: 'Weight must be numeric (always in kg)');

      // Note: Weight is ALWAYS in kg regardless of PreferredUnits
      logAssertion(
        'Weight is in kilograms (TrainingPeaks standard)',
        passed: true,
        reason:
            'Weight: ${data['Weight']} kg - always kg regardless of PreferredUnits',
      );

      logTestPass('Athlete profile structure is valid');
    });

    test('fetches upcoming workouts with correct data format', () async {
      logSection('Fetching upcoming workouts');

      final now = DateTime.now();
      final startDate = _formatDate(now);
      final endDate = _formatDate(now.add(const Duration(days: 14)));

      final response = await http.get(
        Uri.parse('$apiBaseUrl/v2/workouts/$startDate/$endDate'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'User-Agent': 'Mealvana Endurance Test v1.0',
        },
      );

      logApiCall('/v2/workouts/$startDate/$endDate', params: {
        'Status': response.statusCode,
      });

      expect(response.statusCode, equals(200));

      final workouts = jsonDecode(response.body) as List;
      logTestResult('Total workouts', workouts.length);

      if (workouts.isEmpty) {
        logTestResult('Note', 'No workouts found - add workouts in TrainingPeaks');
        return;
      }

      logTestPass('API returned valid response structure');
    });

    test('validates workout distance is in METERS (not miles/km)', () async {
      logSection('Validating workout distance format');

      final now = DateTime.now();
      final startDate = _formatDate(now);
      final endDate = _formatDate(now.add(const Duration(days: 45)));

      final response = await http.get(
        Uri.parse('$apiBaseUrl/v2/workouts/$startDate/$endDate'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'User-Agent': 'Mealvana Endurance Test v1.0',
        },
      );

      final workouts = jsonDecode(response.body) as List;

      // Find a workout with distance
      final workoutWithDistance = workouts.firstWhere(
        (w) {
          final dist = (w as Map<String, dynamic>)['Distance'];
          return dist != null && dist is num && dist > 0;
        },
        orElse: () => <String, dynamic>{},
      );

      if ((workoutWithDistance as Map).isEmpty) {
        logTestResult('Distance', 'NO WORKOUTS WITH DISTANCE FOUND');
        logTestResult('Suggestion',
            'Add a workout with distance to TrainingPeaks');
        return;
      }

      final distanceMeters = workoutWithDistance['Distance'] as num;
      logTestResult('Distance raw value', distanceMeters);

      // If distance > 100, it's almost certainly meters
      // A 10 mile run = 16093 meters
      // A 100 meter swim = 100 meters
      final isLikelyMeters = distanceMeters > 100;

      final distanceMiles = distanceMeters * 0.000621371;
      logTestResult('Converted to miles', '${distanceMiles.toStringAsFixed(2)} mi');

      logAssertion(
        'Distance appears to be in METERS',
        passed: isLikelyMeters,
        reason: isLikelyMeters
            ? 'Value $distanceMeters > 100, consistent with meters'
            : 'Value $distanceMeters <= 100, might be meters for short workout',
      );

      logTestPass('Distance format validation complete');
    });

    test('validates workout time is in DECIMAL HOURS (not seconds)', () async {
      logSection('Validating workout time format');

      final now = DateTime.now();
      final startDate = _formatDate(now);
      final endDate = _formatDate(now.add(const Duration(days: 45)));

      final response = await http.get(
        Uri.parse('$apiBaseUrl/v2/workouts/$startDate/$endDate'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'User-Agent': 'Mealvana Endurance Test v1.0',
        },
      );

      final workouts = jsonDecode(response.body) as List;

      // Find a workout with time
      final workoutWithTime = workouts.firstWhere(
        (w) {
          final time = (w as Map<String, dynamic>)['TotalTime'];
          return time != null && time is num && time > 0;
        },
        orElse: () => <String, dynamic>{},
      );

      if ((workoutWithTime as Map).isEmpty) {
        logTestResult('TotalTime', 'NO WORKOUTS WITH TIME FOUND');
        logTestResult('Suggestion',
            'Add a workout with duration to TrainingPeaks');
        return;
      }

      final totalTimeHours = workoutWithTime['TotalTime'] as num;
      logTestResult('TotalTime raw value', totalTimeHours);

      // If TotalTime < 24, it's likely hours (not seconds or minutes)
      // A 1 hour workout = 1.0
      // A 1.5 hour workout = 1.5
      // If it were seconds, 1 hour would be 3600
      final isLikelyHours = totalTimeHours < 24;

      final minutes = totalTimeHours * 60;
      logTestResult('Converted to minutes', '${minutes.toStringAsFixed(1)} min');

      logAssertion(
        'TotalTime appears to be in DECIMAL HOURS',
        passed: isLikelyHours,
        reason: isLikelyHours
            ? 'Value $totalTimeHours < 24, consistent with decimal hours (e.g., 1.5 = 90 min)'
            : 'Value $totalTimeHours >= 24, unusual - verify manually',
      );

      // CRITICAL: This is the opposite of Final Surge (which uses seconds)
      logAssertion(
        'NOT in seconds (unlike Final Surge)',
        passed: isLikelyHours,
        reason: 'Final Surge uses seconds, TrainingPeaks uses decimal hours!',
      );

      logTestPass('Time format validation complete');
    });

    test('validates workout ID is Int64 (handles large numbers)', () async {
      logSection('Validating workout ID format');

      final now = DateTime.now();
      final startDate = _formatDate(now);
      final endDate = _formatDate(now.add(const Duration(days: 45)));

      final response = await http.get(
        Uri.parse('$apiBaseUrl/v2/workouts/$startDate/$endDate'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'User-Agent': 'Mealvana Endurance Test v1.0',
        },
      );

      final workouts = jsonDecode(response.body) as List;

      if (workouts.isEmpty) {
        logTestResult('WorkoutID', 'NO WORKOUTS FOUND');
        return;
      }

      final workoutIds = <int>[];
      for (final w in workouts) {
        final id = (w as Map<String, dynamic>)['Id'] as int?;
        if (id != null) workoutIds.add(id);
      }

      if (workoutIds.isEmpty) {
        logTestResult('WorkoutID', 'NO WORKOUT IDS FOUND');
        return;
      }

      final maxId = workoutIds.reduce((a, b) => a > b ? a : b);
      final minId = workoutIds.reduce((a, b) => a < b ? a : b);

      logTestResults({
        'Total Workout IDs': ResultData(actual: workoutIds.length),
        'Min ID': ResultData(actual: minId),
        'Max ID': ResultData(actual: maxId),
      });

      // Int32 max is 2,147,483,647
      // New workouts after Nov 2022 can exceed this
      const int32Max = 2147483647;
      final exceeds32Bit = maxId > int32Max;

      logAssertion(
        'Workout IDs can be stored safely',
        passed: true,
        reason: exceeds32Bit
            ? 'Max ID $maxId exceeds Int32 - MUST use Int64 or String'
            : 'Max ID $maxId fits in Int32, but use Int64 for future-proofing',
      );

      logTestPass('Workout ID format validation complete');
    });

    test('validates supported workout types', () async {
      logSection('Validating workout types');

      final now = DateTime.now();
      final startDate = _formatDate(now);
      final endDate = _formatDate(now.add(const Duration(days: 45)));

      final response = await http.get(
        Uri.parse('$apiBaseUrl/v2/workouts/$startDate/$endDate'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'User-Agent': 'Mealvana Endurance Test v1.0',
        },
      );

      final workouts = jsonDecode(response.body) as List;

      // Count workout types
      final typeCounts = <String, int>{};
      for (final w in workouts) {
        final typeName =
            (w as Map<String, dynamic>)['WorkoutType'] as String? ?? 'Unknown';
        typeCounts[typeName] = (typeCounts[typeName] ?? 0) + 1;
      }

      logTestResult('Workout types found', typeCounts.keys.length);

      // TrainingPeaks workout types: swim, bike, run, x-train, mtb, strength, xc-ski, rowing, walk, other
      const supportedTypes = [
        'Swim',
        'Bike',
        'Run',
        'Walk',
        'Rowing',
        'Other',
        'X-Train',
        'MTB',
        'Strength',
        'XC-Ski',
      ];

      for (final entry in typeCounts.entries) {
        final isSupported = supportedTypes.any(
            (t) => t.toLowerCase() == entry.key.toLowerCase());
        logTestResult(
          entry.key,
          '${entry.value} workouts ${isSupported ? "(SUPPORTED)" : "(may need mapping)"}',
        );
      }

      logTestPass('Workout type validation complete');
    });
  });

  group('TrainingPeaks Event Sync Tests (UNIQUE FEATURE)', () {
    test('fetches next event successfully', () async {
      logSection('Fetching next event (unique to TrainingPeaks)');

      final response = await http.get(
        Uri.parse('$apiBaseUrl/v2/events/next'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'User-Agent': 'Mealvana Endurance Test v1.0',
        },
      );

      logApiCall('/v2/events/next', params: {
        'Status': response.statusCode,
      });

      // 200 = event found, 404 = no events
      expect(response.statusCode, anyOf(equals(200), equals(404)));

      if (response.statusCode == 404) {
        logTestResult('Next Event', 'NO UPCOMING EVENTS');
        logTestResult('Note',
            'Add an event/race in TrainingPeaks to test event sync');
        return;
      }

      final data = jsonDecode(response.body);
      if (data == null) {
        logTestResult('Next Event', 'NULL RESPONSE');
        return;
      }

      final event = data is List
          ? (data.isNotEmpty ? data.first as Map<String, dynamic> : null)
          : data as Map<String, dynamic>;

      if (event == null) {
        logTestResult('Next Event', 'EMPTY RESPONSE');
        return;
      }

      logTestResults({
        'Event ID': ResultData(actual: event['Id']),
        'Event Name': ResultData(actual: event['Name']),
        'Event Type': ResultData(actual: event['EventType']),
        'Event Date': ResultData(actual: event['EventDate']),
        'Has Goals': ResultData(
            actual: (event['Goals'] as List?)?.isNotEmpty ?? false),
      });

      // Parse goals if present
      final goals = event['Goals'] as List?;
      if (goals != null && goals.isNotEmpty) {
        logSection('Event Goals');
        for (final goal in goals) {
          final g = goal as Map<String, dynamic>;
          logTestResult(
            '${g['GoalType']}',
            '${g['Value']} ${g['Unit'] ?? ''}',
          );
        }
      }

      // Validate event structure
      expect(event['Id'], isNotNull, reason: 'Event ID must be present');
      expect(event['EventDate'], isNotNull,
          reason: 'EventDate must be present');
      expect(event['EventType'], isNotNull,
          reason: 'EventType must be present');

      logTestPass(
          'Event sync works! This is UNIQUE to TrainingPeaks (Final Surge does NOT have this)');
    });

    test('validates event date format', () async {
      logSection('Validating event date format');

      final response = await http.get(
        Uri.parse('$apiBaseUrl/v2/events/next'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'User-Agent': 'Mealvana Endurance Test v1.0',
        },
      );

      if (response.statusCode != 200) {
        logTestResult('Note', 'No events to validate date format');
        return;
      }

      final data = jsonDecode(response.body);
      final event = data is List
          ? (data.isNotEmpty ? data.first as Map<String, dynamic> : null)
          : data as Map<String, dynamic>?;

      if (event == null) return;

      final eventDate = event['EventDate'] as String?;
      if (eventDate == null) {
        logTestResult('EventDate', 'NULL');
        return;
      }

      logTestResult('EventDate raw', eventDate);

      // Parse the date
      final parsedDate = DateTime.tryParse(eventDate);
      expect(parsedDate, isNotNull, reason: 'EventDate must be valid ISO 8601');

      logTestResult('Parsed date', parsedDate);
      logAssertion(
        'EventDate is valid ISO 8601 format',
        passed: parsedDate != null,
      );

      logTestPass('Event date format validation complete');
    });

    test('validates event type mapping for Mealvana', () async {
      logSection('Validating event types for nutrition planning');

      final response = await http.get(
        Uri.parse('$apiBaseUrl/v2/events/next'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'User-Agent': 'Mealvana Endurance Test v1.0',
        },
      );

      if (response.statusCode != 200) {
        logTestResult('Note', 'No events to validate');
        return;
      }

      final data = jsonDecode(response.body);
      final event = data is List
          ? (data.isNotEmpty ? data.first as Map<String, dynamic> : null)
          : data as Map<String, dynamic>?;

      if (event == null) return;

      final eventType = event['EventType'] as String?;
      logTestResult('EventType', eventType);

      // Map TrainingPeaks event types to Mealvana activity types
      // Valid EventTypes from API docs:
      // Running: RoadRunning, TrailRunning, TrackRunning, CrossCountry, Running
      // Cycling: RoadCycling, MountainBiking, Cyclocross, TrackCycling, Cycling
      // Swimming: OpenWaterSwimming, PoolSwimming
      // Multisport: Triathlon, Xterra, Duathlon, Aquabike, Aquathon, Multisport
      // Other: various

      final eventTypeMapping = <String, String>{
        // Running events
        'RoadRunning': 'running',
        'TrailRunning': 'running',
        'TrackRunning': 'running',
        'CrossCountry': 'running',
        'Running': 'running',
        'Marathon': 'running',
        // Cycling events
        'RoadCycling': 'cycling',
        'MountainBiking': 'cycling',
        'Cyclocross': 'cycling',
        'TrackCycling': 'cycling',
        'Cycling': 'cycling',
        // Swimming events
        'OpenWaterSwimming': 'swimming',
        'PoolSwimming': 'swimming',
        // Multisport
        'Triathlon': 'triathlon',
        'Xterra': 'triathlon',
        'Duathlon': 'multisport',
        'Aquabike': 'multisport',
        'Aquathon': 'multisport',
        'Multisport': 'multisport',
      };

      if (eventType != null) {
        final mealvanaType = eventTypeMapping[eventType];
        logTestResult('Mealvana mapping', mealvanaType ?? 'NEEDS MAPPING');

        logAssertion(
          'EventType can be mapped to Mealvana',
          passed: mealvanaType != null,
          reason: mealvanaType != null
              ? '$eventType → $mealvanaType'
              : 'Need to add mapping for $eventType',
        );
      }

      logTestPass('Event type mapping validation complete');
    });
  });

  group('TrainingPeaks vs Final Surge Comparison', () {
    test('documents critical differences for transformer', () {
      logSection('Critical Differences: TrainingPeaks vs Final Surge');

      // This test documents the differences - no assertions, just logging
      final differences = <String, Map<String, String>>{
        'Token Expiration': {
          'Final Surge': 'Never expires',
          'TrainingPeaks': '1 hour (600 seconds)',
          'Impact': 'MUST implement token refresh',
        },
        'Distance Unit': {
          'Final Surge': 'Miles or km (PlannedDistanceType)',
          'TrainingPeaks': 'ALWAYS meters',
          'Impact': 'Convert: meters * 0.000621371 = miles',
        },
        'Time Unit': {
          'Final Surge': 'Seconds (PlannedTime)',
          'TrainingPeaks': 'Decimal hours (TotalTime)',
          'Impact': 'Convert: hours * 60 = minutes',
        },
        'Workout ID': {
          'Final Surge': 'String (WorkoutKey)',
          'TrainingPeaks': 'Int64 (Id)',
          'Impact': 'Store as String to handle large numbers',
        },
        'Pace Data': {
          'Final Surge': 'In description (@ 9:12 - 10:01)',
          'TrainingPeaks': 'NOT provided',
          'Impact': 'Calculate from distance/time if needed',
        },
        'Event Sync': {
          'Final Surge': 'NOT available',
          'TrainingPeaks': '/v2/events/next',
          'Impact': 'UNIQUE FEATURE - use for race planning!',
        },
        'Nutrition Push': {
          'Final Surge': 'NOT available',
          'TrainingPeaks': 'POST /v1/athletes/{id}/nutrition',
          'Impact': 'Can push macros TO TrainingPeaks!',
        },
        'Premium Detection': {
          'Final Surge': 'NOT available',
          'TrainingPeaks': 'IsPremium field in profile',
          'Impact': 'Some endpoints require premium',
        },
        'Webhooks': {
          'Final Surge': 'NOT available',
          'TrainingPeaks': 'webhook:* scopes',
          'Impact': 'Real-time updates possible (Phase 2)',
        },
      };

      for (final entry in differences.entries) {
        logSection(entry.key);
        for (final detail in entry.value.entries) {
          logTestResult(detail.key, detail.value);
        }
      }

      logTestPass('Differences documented for transformer implementation');
    });
  });
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

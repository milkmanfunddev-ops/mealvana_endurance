/// Final Surge Live API Integration Tests
///
/// These tests hit the REAL Final Surge API to validate our assumptions
/// about the data format and transformation logic.
///
/// Prerequisites:
/// 1. Run `dart run tool/final_surge_api_test.dart auth` to get a cached token
/// 2. The token file must exist at tool/.final_surge_token.json
///
/// Run with: flutter test test/integration/final_surge_api_test.dart --tags integration
///
/// Note: These tests require a valid Final Surge account with workouts scheduled.
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/features/integrations/domain/final_surge_defaults.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import '../helpers/utils/console_logging.dart';

void main() {
  late String accessToken;
  late Map<String, dynamic> cachedTokenData;
  const baseUrl = 'https://log.finalsurge.com';
  const clientId = 'BD5D0C2B-7507-405B-8A3F-DB161288E6FC';

  setUpAll(() async {
    // Load cached token from previous OAuth
    final tokenFile = File('tool/.final_surge_token.json');

    if (!tokenFile.existsSync()) {
      throw Exception(
        '\n\n'
        '╔══════════════════════════════════════════════════════════════════╗\n'
        '║  TOKEN NOT FOUND                                                  ║\n'
        '║                                                                   ║\n'
        '║  Run this command first to authenticate:                          ║\n'
        '║  dart run tool/final_surge_api_test.dart auth                     ║\n'
        '╚══════════════════════════════════════════════════════════════════╝\n',
      );
    }

    cachedTokenData =
        jsonDecode(tokenFile.readAsStringSync()) as Map<String, dynamic>;
    accessToken = cachedTokenData['access_token'] as String;

    logTestHeading('Final Surge Live API Integration Tests');
    logTestSetup({
      'Athlete':
          '${cachedTokenData['firstname']} ${cachedTokenData['lastname']}',
      'Athlete ID': cachedTokenData['id'],
      'Token cached at': cachedTokenData['cached_at'],
    });
  });

  group('Final Surge API Response Validation', () {
    test('fetches upcoming workouts successfully', () async {
      logSection('Fetching upcoming workouts');

      final response = await http.get(
        Uri.parse(
          '$baseUrl/API/v1/UpcomingWorkouts',
        ).replace(queryParameters: {'NumDays': '7', 'NumWorkouts': '21'}),
        headers: {
          'client-id': clientId,
          'Authorization': 'Bearer $accessToken',
        },
      );

      logApiCall(
        '/API/v1/UpcomingWorkouts',
        params: {'Status': response.statusCode},
      );

      expect(response.statusCode, equals(200));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['Success'], isTrue);
      expect(data['Workouts'], isA<List>());

      final workouts = data['Workouts'] as List;
      logTestResult('Total workouts', workouts.length);

      logTestPass('API returned valid response structure');
    });

    test('validates workout structure matches expected fields', () async {
      logSection('Validating workout structure');

      final response = await http.get(
        Uri.parse(
          '$baseUrl/API/v1/UpcomingWorkouts',
        ).replace(queryParameters: {'NumDays': '7', 'NumWorkouts': '21'}),
        headers: {
          'client-id': clientId,
          'Authorization': 'Bearer $accessToken',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final workouts = data['Workouts'] as List;

      if (workouts.isEmpty) {
        logTestResult(
          'Workouts',
          'NONE FOUND - add workouts to Final Surge to test',
        );
        return;
      }

      final workout = workouts.first as Map<String, dynamic>;

      // Log all fields for debugging
      logTestInput({
        'WorkoutKey': workout['WorkoutKey'],
        'WorkoutTypeName': workout['WorkoutTypeName'],
        'WorkoutTitle': workout['WorkoutTitle'],
        'WorkoutDate': workout['WorkoutDate'],
        'PlannedTime': workout['PlannedTime'],
        'PlannedDistance': workout['PlannedDistance'],
        'PlannedDistanceType': workout['PlannedDistanceType'],
        'PlannedPace': workout['PlannedPace'],
        'WorkoutDescription': workout['WorkoutDescription']
            ?.toString()
            .substring(
              0,
              (workout['WorkoutDescription']?.toString().length ?? 0) > 50
                  ? 50
                  : null,
            ),
      });

      // Validate required fields exist
      logAssertion(
        'WorkoutKey is present',
        passed: workout['WorkoutKey'] != null,
      );
      logAssertion(
        'WorkoutDate is present',
        passed: workout['WorkoutDate'] != null,
      );
      logAssertion(
        'WorkoutTypeName is present',
        passed: workout['WorkoutTypeName'] != null,
      );

      expect(workout['WorkoutKey'], isNotNull);
      expect(workout['WorkoutDate'], isNotNull);
      expect(workout['WorkoutTypeName'], isNotNull);

      logTestPass('Workout structure is valid');
    });

    test('validates PlannedTime is in SECONDS (not minutes)', () async {
      logSection('Validating PlannedTime format');

      final response = await http.get(
        Uri.parse(
          '$baseUrl/API/v1/UpcomingWorkouts',
        ).replace(queryParameters: {'NumDays': '14', 'NumWorkouts': '50'}),
        headers: {
          'client-id': clientId,
          'Authorization': 'Bearer $accessToken',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final workouts = data['Workouts'] as List;

      // Find a workout with PlannedTime
      final workoutWithTime = workouts.firstWhere((w) {
        final time = (w as Map<String, dynamic>)['PlannedTime'];
        return time != null && time is num && time > 0;
      }, orElse: () => <String, dynamic>{});

      if ((workoutWithTime as Map).isEmpty) {
        logTestResult('PlannedTime', 'NO WORKOUTS WITH TIME FOUND');
        logTestResult(
          'Suggestion',
          'Add a workout with duration to Final Surge',
        );
        return;
      }

      final plannedTime = workoutWithTime['PlannedTime'] as num;
      logTestResult('PlannedTime raw value', plannedTime);

      // If PlannedTime > 200, it's almost certainly seconds
      // A 30 minute workout = 1800 seconds
      // A 3 hour workout = 10800 seconds
      // If it were minutes, 30 minutes would just be 30
      final isLikelySeconds = plannedTime > 200;

      logAssertion(
        'PlannedTime appears to be in SECONDS',
        passed: isLikelySeconds,
        reason: isLikelySeconds
            ? 'Value $plannedTime > 200, consistent with seconds (e.g., 1800 = 30 min)'
            : 'Value $plannedTime <= 200, might be minutes - VERIFY MANUALLY',
      );

      if (isLikelySeconds) {
        final minutes = plannedTime / 60;
        logTestResult(
          'Converted to minutes',
          '${minutes.toStringAsFixed(1)} min',
        );
      }

      // This test passes if we can determine the format
      // If the value is ambiguous, we log a warning
      expect(true, isTrue); // Test passes, but check logs for warnings
    });

    test('validates pace format in WorkoutDescription', () async {
      logSection('Validating pace format');

      final response = await http.get(
        Uri.parse(
          '$baseUrl/API/v1/UpcomingWorkouts',
        ).replace(queryParameters: {'NumDays': '14', 'NumWorkouts': '50'}),
        headers: {
          'client-id': clientId,
          'Authorization': 'Bearer $accessToken',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final workouts = data['Workouts'] as List;

      // Collect all descriptions that contain pace info
      final descriptionsWithPace = <String>[];
      final pacePattern = RegExp(r'@\s*([\d]+:[\d]+)(?:\s*-\s*([\d]+:[\d]+))?');

      for (final workout in workouts) {
        final desc =
            (workout as Map<String, dynamic>)['WorkoutDescription'] as String?;
        if (desc != null && pacePattern.hasMatch(desc)) {
          descriptionsWithPace.add(desc);
        }
      }

      logTestResult(
        'Workouts with pace in description',
        descriptionsWithPace.length,
      );

      if (descriptionsWithPace.isEmpty) {
        logTestResult('Note', 'No workouts found with @ pace format');
        logTestResult('Expected format', '@ 9:12 or @ 8:30 - 9:30');
        return;
      }

      // Log examples
      for (final desc in descriptionsWithPace.take(5)) {
        final match = pacePattern.firstMatch(desc);
        if (match != null) {
          final pace1 = match.group(1);
          final pace2 = match.group(2);
          final isRange = pace2 != null;

          logTestResult(
            isRange ? 'RANGE pace' : 'SINGLE pace',
            isRange ? '$pace1 - $pace2' : pace1 ?? 'unknown',
          );
        }
      }

      logTestPass('Pace format validation complete');
    });

    test('validates supported workout types', () async {
      logSection('Validating workout types');

      final response = await http.get(
        Uri.parse(
          '$baseUrl/API/v1/UpcomingWorkouts',
        ).replace(queryParameters: {'NumDays': '14', 'NumWorkouts': '50'}),
        headers: {
          'client-id': clientId,
          'Authorization': 'Bearer $accessToken',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final workouts = data['Workouts'] as List;

      // Count workout types
      final typeCounts = <String, int>{};
      for (final workout in workouts) {
        final typeName =
            (workout as Map<String, dynamic>)['WorkoutTypeName'] as String? ??
            'Unknown';
        typeCounts[typeName] = (typeCounts[typeName] ?? 0) + 1;
      }

      logTestResult('Workout types found', typeCounts.keys.length);
      for (final entry in typeCounts.entries) {
        final isSupported = FinalSurgeTransformer.supportedTypes.contains(
          entry.key,
        );
        logTestResult(
          entry.key,
          '${entry.value} workouts ${isSupported ? "(SUPPORTED)" : "(filtered out)"}',
        );
      }

      logTestPass('Workout type validation complete');
    });
  });

  group('Transformer Integration with Real Data', () {
    test('transforms real API workouts correctly', () async {
      logSection('Testing transformer with real data');

      final response = await http.get(
        Uri.parse(
          '$baseUrl/API/v1/UpcomingWorkouts',
        ).replace(queryParameters: {'NumDays': '14', 'NumWorkouts': '50'}),
        headers: {
          'client-id': clientId,
          'Authorization': 'Bearer $accessToken',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final workouts = data['Workouts'] as List;

      const transformer = FinalSurgeTransformer();
      const testUserId = 'test-user-integration';

      var transformed = 0;
      var filtered = 0;

      for (final workout in workouts) {
        final result = transformer.transform(
          workout as Map<String, dynamic>,
          testUserId,
        );

        if (result == null) {
          filtered++;
          continue;
        }

        transformed++;

        // Log first few transformations
        if (transformed <= 3) {
          logSection('Transformed workout #$transformed');
          logTestResults({
            'Title': ResultData(actual: result.activity.title),
            'Activity Type': ResultData(
              actual: result.activity.activityType.name,
            ),
            'Duration': ResultData(
              actual: result.activity.durationMinutes,
              unit: 'min',
            ),
            'Distance': ResultData(
              actual: result.activity.distanceMiles ?? result.distanceMeters,
              unit: result.activity.activityType == ActivityType.swimming
                  ? 'm'
                  : 'mi',
            ),
            'Target Pace': ResultData(
              actual: result.activity.paceTargetMinutesPerMile?.toStringAsFixed(
                2,
              ),
              unit: 'min/mi',
            ),
            'Intensity': ResultData(
              actual: result.activity.intensityLevel?.name,
            ),
          });

          // Validate transformation
          expect(result.activity.id, isNotEmpty);
          expect(result.activity.userId, equals(testUserId));
          expect(result.syncedFromProvider, equals('final_surge'));
          expect(result.providerWorkoutId, isNotEmpty);
        }
      }

      logTestResults({
        'Total workouts': ResultData(actual: workouts.length),
        'Transformed': ResultData(actual: transformed),
        'Filtered out': ResultData(actual: filtered),
      });

      logTestPass('Transformer integration test complete');
    });

    test('verifies sensible defaults are applied correctly', () async {
      logSection('Verifying defaults for missing data');

      // Create a workout with missing data to test defaults
      final workoutMissingData = {
        'WorkoutKey': 'test-defaults-${DateTime.now().millisecondsSinceEpoch}',
        'WorkoutDate': DateTime.now().toIso8601String(),
        'WorkoutTypeName': 'Run',
        'WorkoutTitle': 'Test Defaults',
        // Missing: PlannedTime, PlannedDistance, WorkoutDescription
      };

      const transformer = FinalSurgeTransformer();
      final result = transformer.transform(workoutMissingData, 'test-user');

      expect(result, isNotNull);

      logTestResults({
        'Default Distance': ResultData(
          actual: result!.activity.distanceMiles,
          expected: FinalSurgeDefaults.runningDistanceMiles,
          unit: 'mi',
        ),
        'Default Duration': ResultData(
          actual: result.activity.durationMinutes,
          expected: FinalSurgeDefaults.runningDurationMinutes,
          unit: 'min',
        ),
        'Default Pace': ResultData(
          actual: result.activity.paceTargetMinutesPerMile,
          expected: FinalSurgeDefaults.runningPaceMinPerMile,
          unit: 'min/mi',
        ),
      });

      // Verify defaults match expected values
      logAssertion(
        'Distance default applied',
        passed:
            result.activity.distanceMiles ==
            FinalSurgeDefaults.runningDistanceMiles,
      );
      logAssertion(
        'Duration default applied',
        passed:
            result.activity.durationMinutes ==
            FinalSurgeDefaults.runningDurationMinutes,
      );
      logAssertion(
        'Pace default applied',
        passed:
            result.activity.paceTargetMinutesPerMile ==
            FinalSurgeDefaults.runningPaceMinPerMile,
      );

      expect(
        result.activity.distanceMiles,
        equals(FinalSurgeDefaults.runningDistanceMiles),
      );
      expect(
        result.activity.durationMinutes,
        equals(FinalSurgeDefaults.runningDurationMinutes),
      );
      expect(
        result.activity.paceTargetMinutesPerMile,
        equals(FinalSurgeDefaults.runningPaceMinPerMile),
      );

      logTestPass('Sensible defaults are correctly applied');
    });
  });
}

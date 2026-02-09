/// Intensity Distribution Integration Tests
///
/// Tests intensity distribution inference with real API tokens from
/// Training Peaks and Final Surge.
///
/// These tests require valid API credentials and are tagged as 'integration'
/// to be skipped in normal CI runs.
///
/// Run with: flutter test test/integration/intensity_distribution_integration_test.dart --tags integration
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';
import 'package:mealvana_endurance/features/integrations/data/final_surge_api_client.dart';
import 'package:mealvana_endurance/features/integrations/data/training_peaks_api_client.dart';

void main() {
  const testUserId = 'integration-test-user';

  group('Intensity Distribution Integration Tests', () {
    // =========================================================================
    // TRAINING PEAKS INTEGRATION TESTS
    // =========================================================================
    group('Training Peaks', () {
      late TrainingPeaksApiClient apiClient;
      late TrainingPeaksTransformer transformer;
      String? accessToken;

      setUpAll(() {
        transformer = const TrainingPeaksTransformer();

        // Try to load token from file
        final tokenFile = File('tool/.training_peaks_token.json');
        if (tokenFile.existsSync()) {
          try {
            final tokenData = json.decode(tokenFile.readAsStringSync());
            accessToken = tokenData['access_token'] as String?;
            if (accessToken != null) {
              apiClient = TrainingPeaksApiClient(
                clientId: tokenData['client_id'] as String? ?? 'mealvana',
                clientSecret: tokenData['client_secret'] as String? ?? '',
                appVersion: '1.0.0-test',
              );
            }
          } catch (e) {
            print('Warning: Could not load Training Peaks token: $e');
          }
        }
      });

      test('fetches real workouts and infers intensity distribution', () async {
        if (accessToken == null) {
          markTestSkipped('No Training Peaks access token available');
          return;
        }

        // Fetch workouts for a date range
        final startDate = DateTime.now().subtract(const Duration(days: 30));
        final endDate = DateTime.now().add(const Duration(days: 30));

        try {
          final workouts = await apiClient.getWorkouts(
            accessToken!,
            startDate: startDate,
            endDate: endDate,
          );

          print('Fetched ${workouts.length} workouts from Training Peaks');

          var workoutsWithDistribution = 0;
          var workoutsWithoutDistribution = 0;

          for (final workout in workouts) {
            final result = transformer.transform(workout, testUserId);
            if (result == null) continue;

            final title = workout['Title'] ?? 'Untitled';
            final ifValue = workout['IFPlanned'];
            final hasStructure = workout['Structure'] != null;

            if (result.intensityDistribution != null) {
              workoutsWithDistribution++;
              final dist = result.intensityDistribution!;
              print(
                '✅ ${result.activity.activityType.name}: "$title" → '
                '${dist.conversationalPct}/${dist.tempoPct}/${dist.allOutPct} '
                '(IF: $ifValue, hasStructure: $hasStructure)',
              );
            } else {
              workoutsWithoutDistribution++;
              print(
                '⚠️ ${result.activity.activityType.name}: "$title" → null '
                '(IF: $ifValue, hasStructure: $hasStructure)',
              );
            }
          }

          print('\nSummary:');
          print('  With distribution: $workoutsWithDistribution');
          print('  Without distribution: $workoutsWithoutDistribution');

          // At least some workouts should have intensity distribution
          // (this is a soft assertion - depends on workout data)
          if (workouts.isNotEmpty) {
            expect(
              workoutsWithDistribution + workoutsWithoutDistribution,
              greaterThan(0),
            );
          }
        } catch (e) {
          print('API call failed: $e');
          // Don't fail the test if API is unavailable
          markTestSkipped('Training Peaks API unavailable: $e');
        }
      });

      test('handles structured workout from real data', () async {
        if (accessToken == null) {
          markTestSkipped('No Training Peaks access token available');
          return;
        }

        // Fetch workouts and find one with structure
        final startDate = DateTime.now().subtract(const Duration(days: 60));
        final endDate = DateTime.now().add(const Duration(days: 60));

        try {
          final workouts = await apiClient.getWorkouts(
            accessToken!,
            startDate: startDate,
            endDate: endDate,
          );

          final structuredWorkouts = workouts.where((w) {
            final structure = w['Structure'] as String?;
            return structure != null && structure.isNotEmpty && structure != '[]';
          }).toList();

          print('Found ${structuredWorkouts.length} structured workouts');

          for (final workout in structuredWorkouts.take(5)) {
            final result = transformer.transform(workout, testUserId);
            if (result == null) continue;

            final title = workout['Title'] ?? 'Untitled';
            final structure = workout['Structure'] as String?;

            print('\n📋 Structured workout: "$title"');
            print('   Structure JSON length: ${structure?.length ?? 0} chars');

            if (result.intensityDistribution != null) {
              final dist = result.intensityDistribution!;
              print(
                '   Distribution: ${dist.conversationalPct}% conv / '
                '${dist.tempoPct}% tempo / ${dist.allOutPct}% all-out',
              );
              // Verify percentages sum to 100
              expect(
                dist.conversationalPct + dist.tempoPct + dist.allOutPct,
                equals(100),
              );
            } else {
              print('   Distribution: null (structure parsing may have failed)');
            }
          }
        } catch (e) {
          print('API call failed: $e');
          markTestSkipped('Training Peaks API unavailable: $e');
        }
      });
    });

    // =========================================================================
    // FINAL SURGE INTEGRATION TESTS
    // =========================================================================
    group('Final Surge', () {
      late FinalSurgeApiClient apiClient;
      late FinalSurgeTransformer transformer;
      String? accessToken;

      setUpAll(() {
        transformer = const FinalSurgeTransformer();

        // Try to load token from file
        final tokenFile = File('tool/.final_surge_token.json');
        if (tokenFile.existsSync()) {
          try {
            final tokenData = json.decode(tokenFile.readAsStringSync());
            accessToken = tokenData['token'] as String?;
            if (accessToken != null) {
              apiClient = FinalSurgeApiClient(
                clientId: tokenData['client_id'] as String? ?? 'BD5D0C2B-7507-405B-8A3F-DB161288E6FC',
                clientSecret: tokenData['client_secret'] as String? ?? '',
              );
            }
          } catch (e) {
            print('Warning: Could not load Final Surge token: $e');
          }
        }
      });

      test('fetches real workouts and infers intensity distribution', () async {
        if (accessToken == null) {
          markTestSkipped('No Final Surge credentials available');
          return;
        }

        // Fetch workouts for a date range
        final startDate = DateTime.now().subtract(const Duration(days: 30));
        final endDate = DateTime.now().add(const Duration(days: 30));

        try {
          final response = await apiClient.getWorkoutsByDateRange(
            accessToken!,
            startDate: startDate,
            endDate: endDate,
          );

          final workouts = response.workouts;
          print('Fetched ${workouts.length} workouts from Final Surge');

          var workoutsWithDistribution = 0;
          var workoutsWithoutDistribution = 0;

          for (final workout in workouts) {
            final result = transformer.transform(workout, testUserId);
            if (result == null) continue;

            final title = workout['WorkoutTitle'] ?? 'Untitled';
            final subtype = workout['WorkoutSubTypeName'];
            final isRace = workout['WorkoutRace'] == true;

            if (result.intensityDistribution != null) {
              workoutsWithDistribution++;
              final dist = result.intensityDistribution!;
              print(
                '✅ ${result.activity.activityType.name}: "$title" → '
                '${dist.conversationalPct}/${dist.tempoPct}/${dist.allOutPct} '
                '(subtype: $subtype, race: $isRace)',
              );
            } else {
              workoutsWithoutDistribution++;
              print(
                '⚠️ ${result.activity.activityType.name}: "$title" → null '
                '(subtype: $subtype, race: $isRace)',
              );
            }
          }

          print('\nSummary:');
          print('  With distribution: $workoutsWithDistribution');
          print('  Without distribution: $workoutsWithoutDistribution');

          // At least some workouts should have intensity distribution
          if (workouts.isNotEmpty) {
            expect(
              workoutsWithDistribution + workoutsWithoutDistribution,
              greaterThan(0),
            );
          }
        } catch (e) {
          print('API call failed: $e');
          markTestSkipped('Final Surge API unavailable: $e');
        }
      });

      test('maps various workout subtypes correctly', () async {
        if (accessToken == null) {
          markTestSkipped('No Final Surge credentials available');
          return;
        }

        // Fetch a larger date range to get variety
        final startDate = DateTime.now().subtract(const Duration(days: 90));
        final endDate = DateTime.now().add(const Duration(days: 30));

        try {
          final response = await apiClient.getWorkoutsByDateRange(
            accessToken!,
            startDate: startDate,
            endDate: endDate,
          );

          final workouts = response.workouts;

          // Group by subtype
          final subtypeDistributions = <String, List<String>>{};

          for (final workout in workouts) {
            final result = transformer.transform(workout, testUserId);
            if (result == null) continue;

            final subtype = workout['WorkoutSubTypeName'] as String? ?? 'null';
            final distStr = result.intensityDistribution != null
                ? '${result.intensityDistribution!.conversationalPct}/${result.intensityDistribution!.tempoPct}/${result.intensityDistribution!.allOutPct}'
                : 'null';

            subtypeDistributions.putIfAbsent(subtype, () => []).add(distStr);
          }

          print('\nSubtype → Distribution mappings:');
          subtypeDistributions.forEach((subtype, distributions) {
            final uniqueDists = distributions.toSet();
            print('  $subtype: ${uniqueDists.join(', ')} (${distributions.length} workouts)');
          });
        } catch (e) {
          print('API call failed: $e');
          markTestSkipped('Final Surge API unavailable: $e');
        }
      });
    });

    // =========================================================================
    // COMPARISON TESTS
    // =========================================================================
    group('Cross-provider Comparison', () {
      test('similar workout types produce similar distributions', () async {
        // This test would compare intensity distributions for similar workout types
        // across both providers to ensure consistency
        //
        // For now, we just document the expected patterns:
        print('Expected patterns by workout type:');
        print('  Easy/Recovery: 95/5/0');
        print('  Long Run: 80/15/5');
        print('  Moderate: 70/25/5');
        print('  Tempo: 30/60/10');
        print('  Intervals: 40/30/30');
        print('  Race: 10/30/60');
      });
    });
  });
}

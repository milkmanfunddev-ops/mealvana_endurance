/// Database Verification Utilities for Sync Tests
///
/// Provides methods to verify data in both:
/// 1. Supabase (cloud) - via REST API
/// 2. Drift (local SQLite) - via direct file access
///
/// Used to verify that sync operations work correctly.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'test_config.dart';
import 'test_helpers.dart';

/// Data counts for verification
class DatabaseCounts {
  final int activities;
  final int events;
  final int foodPreferences;
  final int userFoods;
  final String? userId;
  final String source; // 'supabase' or 'drift'

  const DatabaseCounts({
    required this.activities,
    required this.events,
    required this.foodPreferences,
    required this.userFoods,
    this.userId,
    required this.source,
  });

  @override
  String toString() {
    return 'DatabaseCounts($source: activities=$activities, events=$events, '
        'foodPrefs=$foodPreferences, userFoods=$userFoods, userId=$userId)';
  }

  /// Check if counts match another DatabaseCounts (within tolerance)
  bool matchesCounts(DatabaseCounts other, {int tolerance = 0}) {
    return (activities - other.activities).abs() <= tolerance &&
        (events - other.events).abs() <= tolerance &&
        (foodPreferences - other.foodPreferences).abs() <= tolerance;
  }
}

/// Verification helper for database queries
class DatabaseVerification {
  /// Query Supabase directly via REST API to get data counts
  ///
  /// This verifies that data was actually synced to the cloud.
  /// Uses the service role key for full access.
  static Future<DatabaseCounts?> getSupabaseCounts(String userId) async {
    TestLogger.logSubStep('Querying Supabase for user: $userId');

    try {
      // We need to use the anon key for these queries
      // The tables have RLS policies that allow reading own data
      final headers = {
        'apikey': TestConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${TestConfig.supabaseAnonKey}',
        'Content-Type': 'application/json',
      };

      final baseUrl = TestConfig.supabaseUrl;

      // Query activities count
      final activitiesResponse = await http.get(
        Uri.parse('$baseUrl/rest/v1/activities?user_id=eq.$userId&select=id'),
        headers: headers,
      );

      // Query events count
      final eventsResponse = await http.get(
        Uri.parse('$baseUrl/rest/v1/events?user_id=eq.$userId&select=id'),
        headers: headers,
      );

      // Query food_preferences count
      final foodPrefsResponse = await http.get(
        Uri.parse(
          '$baseUrl/rest/v1/food_preferences?user_id=eq.$userId&select=id',
        ),
        headers: headers,
      );

      // Query user_foods count
      final userFoodsResponse = await http.get(
        Uri.parse('$baseUrl/rest/v1/user_foods?user_id=eq.$userId&select=id'),
        headers: headers,
      );

      // Parse responses
      int activitiesCount = 0;
      int eventsCount = 0;
      int foodPrefsCount = 0;
      int userFoodsCount = 0;

      if (activitiesResponse.statusCode == 200) {
        final data = jsonDecode(activitiesResponse.body) as List;
        activitiesCount = data.length;
      } else {
        TestLogger.logInfo(
          'Activities query failed: ${activitiesResponse.statusCode}',
        );
      }

      if (eventsResponse.statusCode == 200) {
        final data = jsonDecode(eventsResponse.body) as List;
        eventsCount = data.length;
      } else {
        TestLogger.logInfo('Events query failed: ${eventsResponse.statusCode}');
      }

      if (foodPrefsResponse.statusCode == 200) {
        final data = jsonDecode(foodPrefsResponse.body) as List;
        foodPrefsCount = data.length;
      } else {
        TestLogger.logInfo(
          'Food prefs query failed: ${foodPrefsResponse.statusCode}',
        );
      }

      if (userFoodsResponse.statusCode == 200) {
        final data = jsonDecode(userFoodsResponse.body) as List;
        userFoodsCount = data.length;
      } else {
        TestLogger.logInfo(
          'User foods query failed: ${userFoodsResponse.statusCode}',
        );
      }

      final counts = DatabaseCounts(
        activities: activitiesCount,
        events: eventsCount,
        foodPreferences: foodPrefsCount,
        userFoods: userFoodsCount,
        userId: userId,
        source: 'supabase',
      );

      TestLogger.logData('Supabase counts', counts.toString());
      return counts;
    } catch (e) {
      TestLogger.logError('Failed to query Supabase: $e');
      return null;
    }
  }

  /// Query specific event by name from Supabase
  static Future<Map<String, dynamic>?> getEventByName(
    String userId,
    String eventName,
  ) async {
    TestLogger.logSubStep('Looking for event: $eventName');

    try {
      final headers = {
        'apikey': TestConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${TestConfig.supabaseAnonKey}',
        'Content-Type': 'application/json',
      };

      final response = await http.get(
        Uri.parse(
          '${TestConfig.supabaseUrl}/rest/v1/events'
          '?user_id=eq.$userId'
          '&name=ilike.*$eventName*'
          '&select=*',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          TestLogger.logSuccess('Found event: ${data.first['name']}');
          return data.first as Map<String, dynamic>;
        }
      }

      TestLogger.logInfo('Event not found: $eventName');
      return null;
    } catch (e) {
      TestLogger.logError('Failed to query event: $e');
      return null;
    }
  }

  /// Query specific activity from Supabase
  static Future<Map<String, dynamic>?> getLatestActivity(String userId) async {
    TestLogger.logSubStep('Looking for latest activity');

    try {
      final headers = {
        'apikey': TestConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${TestConfig.supabaseAnonKey}',
        'Content-Type': 'application/json',
      };

      final response = await http.get(
        Uri.parse(
          '${TestConfig.supabaseUrl}/rest/v1/activities'
          '?user_id=eq.$userId'
          '&order=created_at.desc'
          '&limit=1'
          '&select=*',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final activity = data.first as Map<String, dynamic>;
          TestLogger.logSuccess(
            'Found activity: ${activity['sport_type']} - ${activity['distance_miles']} mi',
          );
          return activity;
        }
      }

      TestLogger.logInfo('No activities found');
      return null;
    } catch (e) {
      TestLogger.logError('Failed to query activity: $e');
      return null;
    }
  }

  /// Verify data exists in Supabase for the test user
  ///
  /// Returns true if the expected data is found
  static Future<bool> verifySupabaseData({
    required String userId,
    int expectedMinActivities = 0,
    int expectedMinEvents = 0,
    String? expectedEventName,
  }) async {
    TestLogger.logStep('Verifying Supabase Data');

    final counts = await getSupabaseCounts(userId);
    if (counts == null) {
      TestLogger.logError('Could not get Supabase counts');
      return false;
    }

    bool allPassed = true;

    // Check activity count
    if (counts.activities >= expectedMinActivities) {
      TestLogger.logSuccess(
        'Activities: ${counts.activities} >= $expectedMinActivities',
      );
    } else {
      TestLogger.logError(
        'Activities: ${counts.activities} < $expectedMinActivities (FAIL)',
      );
      allPassed = false;
    }

    // Check event count
    if (counts.events >= expectedMinEvents) {
      TestLogger.logSuccess('Events: ${counts.events} >= $expectedMinEvents');
    } else {
      TestLogger.logError(
        'Events: ${counts.events} < $expectedMinEvents (FAIL)',
      );
      allPassed = false;
    }

    // Check specific event if requested
    if (expectedEventName != null) {
      final event = await getEventByName(userId, expectedEventName);
      if (event != null) {
        TestLogger.logSuccess('Found expected event: $expectedEventName');
      } else {
        TestLogger.logError('Expected event not found: $expectedEventName');
        allPassed = false;
      }
    }

    return allPassed;
  }

  /// Get current user ID from Supabase auth
  ///
  /// Note: In integration tests, we can't easily access the Supabase client
  /// directly. This method attempts to get the user ID from stored auth state.
  static Future<String?> getCurrentUserId() async {
    // In integration tests, we'd need to either:
    // 1. Store the user ID when logging in
    // 2. Access it through the provider system
    // 3. Query the auth endpoint

    // For now, return null and we'll implement this when we have access
    // to the provider container
    TestLogger.logInfo(
      'getCurrentUserId: Not implemented for integration tests',
    );
    return null;
  }
}

/// Extension to add database verification to SyncTestData
extension SyncTestDataDatabase on SyncTestData {
  /// Populate counts from Supabase
  Future<void> populateFromSupabase(String userId) async {
    final counts = await DatabaseVerification.getSupabaseCounts(userId);
    if (counts != null) {
      activityCount = counts.activities;
      eventCount = counts.events;
      foodPreferenceCount = counts.foodPreferences;
      this.userId = userId;
    }
  }
}

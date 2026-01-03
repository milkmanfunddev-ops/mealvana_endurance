import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/user_profiles.dart';
import '../tables/food_preferences.dart';
import '../tables/foods_table.dart';
import '../tables/app_content_table.dart';
import '../tables/activities_table.dart';
import '../tables/events_table.dart';
import '../tables/user_foods_table.dart';
import '../tables/feedback.dart';
import '../tables/carb_loading_plans_table.dart';
import '../tables/carb_loading_days_table.dart';
import '../tables/carb_loading_user_foods_table.dart';
import '../tables/carb_loading_day_meals_table.dart';
import '../tables/feature_survey_responses_table.dart';

part 'diagnostic_dao.g.dart';

/// Data Access Object for diagnostic operations.
///
/// This DAO handles:
/// - Database cleanup operations (clearUserScopedData, clearAllData)
/// - Troubleshooting (deleteEverythingForTroubleshooting)
/// - User data migration (migrateUserData)
/// - Database health checks (isDatabaseHealthy, canExecuteQueries)
/// - Database statistics (getDatabaseStats)
@DriftAccessor(tables: [
  UserProfilesTable,
  FoodPreferencesTable,
  FoodsTable,
  AppContentTable,
  ActivitiesTable,
  EventsTable,
  UserFoodsTable,
  FeedbackTable,
  CarbLoadingPlansTable,
  CarbLoadingDaysTable,
  CarbLoadingUserFoodsTable,
  CarbLoadingDayMealsTable,
  FeatureSurveyResponsesTable,
])
class DiagnosticDao extends DatabaseAccessor<AppDatabase>
    with _$DiagnosticDaoMixin {
  DiagnosticDao(super.db);

  // ==================== Cleanup Methods ====================

  /// Clear user-scoped data from local database
  ///
  /// **Behavior:**
  /// - **Logout**: Keeps all data (forceDelete=false) for offline-first architecture
  /// - **Account Deletion**: Deletes user's data (forceDelete=true)
  ///
  /// **Why keep data on logout?**
  /// - Allows users to sign back in offline and see their data
  /// - Supports multi-user scenarios (queries filter by current user)
  /// - Follows offline-first best practices (Linear, Notion, Figma)
  ///
  /// **Security:**
  /// - Queries already filter by getCurrentUserProfile().id
  /// - Data is isolated between users via user_id
  /// - For shared devices, use Settings > Clear Local Data
  ///
  /// @param userId - Required for account deletion, identifies which user to delete
  /// @param forceDelete - If true, actually delete data. If false, keep data (no-op)
  Future<void> clearUserScopedData({
    String? userId,
    bool forceDelete = false,
  }) async {
    // OPTION B: No-op for logout (keep data for offline-first)
    // Only delete if explicitly deleting account (forceDelete = true)

    if (!forceDelete) {
      // Logout scenario - keep all data
      // Queries already filter by getCurrentUserProfile().id
      return;
    }

    // Account deletion scenario - delete this user's data
    if (userId == null) {
      throw ArgumentError('userId required for account deletion');
    }

    await db.transaction(() async {
      // Delete with WHERE user_id = userId
      // Child tables first (foreign key constraints)

      // carb_loading_day_meals (via carb_loading_days via carb_loading_plans.user_id)
      await db.customStatement('''
        DELETE FROM carb_loading_day_meals_table
        WHERE carb_loading_day_id IN (
          SELECT id FROM carb_loading_days_table
          WHERE carb_loading_plan_id IN (
            SELECT id FROM carb_loading_plans_table WHERE user_id = ?
          )
        )
      ''', [userId]);

      // carb_loading_days (via carb_loading_plans.user_id)
      await db.customStatement('''
        DELETE FROM carb_loading_days_table
        WHERE carb_loading_plan_id IN (
          SELECT id FROM carb_loading_plans_table WHERE user_id = ?
        )
      ''', [userId]);

      // Direct user_id filtering
      await (delete(carbLoadingPlansTable)
            ..where((t) => t.userId.equals(userId)))
          .go();
      await (delete(eventsTable)..where((t) => t.userId.equals(userId))).go();
      await (delete(activitiesTable)..where((t) => t.userId.equals(userId)))
          .go();
      await (delete(carbLoadingUserFoodsTable)
            ..where((t) => t.userId.equals(userId)))
          .go();
      await (delete(userFoodsTable)..where((t) => t.userId.equals(userId)))
          .go();
      await (delete(featureSurveyResponsesTable)
            ..where((t) => t.deviceId.equals(userId)))
          .go();

      // feedback uses device_id, need to join with users table
      await db.customStatement('''
        DELETE FROM feedback_table
        WHERE device_id IN (
          SELECT device_id FROM users WHERE id = ?
        )
      ''', [userId]);

      // food_preferences uses user_id
      await (delete(foodPreferencesTable)
            ..where((t) => t.userId.equals(userId)))
          .go();

      // Delete user profile last
      await (delete(userProfilesTable)..where((t) => t.id.equals(userId))).go();
    });
  }

  /// Clear all data (for testing/reset)
  /// This clears ALL data regardless of user - used for testing and full reset
  Future<void> clearAllData() async {
    await db.transaction(() async {
      // Child tables first to satisfy foreign key constraints
      await delete(carbLoadingDayMealsTable).go();
      await delete(carbLoadingDaysTable).go();
      await delete(carbLoadingPlansTable).go();
      await delete(eventsTable).go();
      await delete(activitiesTable).go();
      await delete(carbLoadingUserFoodsTable).go();
      await delete(userFoodsTable).go();
      await delete(featureSurveyResponsesTable).go();
      await delete(feedbackTable).go();
      await delete(userProfilesTable).go();
      await delete(foodPreferencesTable).go();
    });
  }

  /// Delete ALL data from ALL tables - for troubleshooting/reset
  /// Uses PRAGMA to disable foreign keys, making it safe regardless of table order
  /// This is the Drift-recommended approach for complete database clearing
  Future<void> deleteEverythingForTroubleshooting() async {
    await db.transaction(() async {
      // Disable foreign key checks to allow deletion in any order
      await db.customStatement('PRAGMA foreign_keys = OFF');

      // Delete from all tables
      for (final table in db.allTables) {
        await delete(table).go();
      }

      // Re-enable foreign key checks
      await db.customStatement('PRAGMA foreign_keys = ON');
    });
  }

  // ==================== Migration Methods ====================

  /// Migrate all user-scoped data from one user ID to another
  /// Used when signing into an existing OAuth account to preserve anonymous user's data
  /// Strategy: DELETE existing OAuth user data first, then UPDATE anonymous user data to OAuth user ID
  /// This preserves the fresh onboarding data from the anonymous session
  Future<void> migrateUserData(String fromUserId, String toUserId) async {
    await db.transaction(() async {
      // STRATEGY: For each table, we DELETE the OAuth user's old data first,
      // then UPDATE the anonymous user's fresh data to use the OAuth user ID.
      // This ensures the fresh onboarding data is preserved without UNIQUE constraint violations.

      // ============ ACTIVITIES ============
      await db.customStatement(
        'DELETE FROM activities WHERE user_id = ?',
        [toUserId],
      );
      await db.customStatement(
        'UPDATE activities SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ EVENTS ============
      await db.customStatement(
        'DELETE FROM events WHERE user_id = ?',
        [toUserId],
      );
      await db.customStatement(
        'UPDATE events SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ FOOD PREFERENCES ============
      await db.customStatement(
        'DELETE FROM food_preferences_table WHERE user_id = ?',
        [toUserId],
      );
      await db.customStatement(
        'UPDATE food_preferences_table SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ USER FOODS ============
      await db.customStatement(
        'DELETE FROM user_foods WHERE user_id = ?',
        [toUserId],
      );
      await db.customStatement(
        'UPDATE user_foods SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ CARB LOADING PLANS ============
      // Step 1: Delete carb_loading_day_meals for OAuth user's plans
      await db.customStatement('''
        DELETE FROM carb_loading_day_meals_table
        WHERE carb_loading_day_id IN (
          SELECT id FROM carb_loading_days_table
          WHERE carb_loading_plan_id IN (
            SELECT id FROM carb_loading_plans_table WHERE user_id = ?
          )
        )
      ''', [toUserId]);

      // Step 2: Delete carb_loading_days for OAuth user's plans
      await db.customStatement('''
        DELETE FROM carb_loading_days_table
        WHERE carb_loading_plan_id IN (
          SELECT id FROM carb_loading_plans_table WHERE user_id = ?
        )
      ''', [toUserId]);

      // Step 3: Delete carb_loading_plans for OAuth user
      await db.customStatement(
        'DELETE FROM carb_loading_plans_table WHERE user_id = ?',
        [toUserId],
      );
      // Migrate anonymous user's carb loading plans to OAuth user
      await db.customStatement(
        'UPDATE carb_loading_plans SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ CARB LOADING USER FOODS ============
      await db.customStatement(
        'DELETE FROM carb_loading_user_foods WHERE user_id = ?',
        [toUserId],
      );
      await db.customStatement(
        'UPDATE carb_loading_user_foods SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ FEATURE SURVEY RESPONSES ============
      await db.customStatement(
        'DELETE FROM feature_survey_responses WHERE user_id = ?',
        [toUserId],
      );
      await db.customStatement(
        'UPDATE feature_survey_responses SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ USER PROFILE ============
      // Delete the old anonymous user profile
      await db.customStatement(
        'DELETE FROM users WHERE id = ?',
        [fromUserId],
      );
    });
  }

  // ==================== Statistics Methods ====================

  /// Get database statistics for logging/debugging
  Future<Map<String, int>> getDatabaseStats() async {
    final userCount = await (selectOnly(userProfilesTable)
          ..addColumns([userProfilesTable.id.count()]))
        .getSingle();
    final preferencesCount = await (selectOnly(foodPreferencesTable)
          ..addColumns([foodPreferencesTable.userId.count()]))
        .getSingle();
    final foodsCount = await (selectOnly(foodsTable)
          ..addColumns([foodsTable.id.count()]))
        .getSingle();
    final contentCount = await (selectOnly(appContentTable)
          ..addColumns([appContentTable.id.count()]))
        .getSingle();

    return {
      'users': userCount.read(userProfilesTable.id.count())!,
      'preferences': preferencesCount.read(foodPreferencesTable.userId.count())!,
      'foods': foodsCount.read(foodsTable.id.count())!,
      'content': contentCount.read(appContentTable.id.count())!,
    };
  }

  // ==================== Health Check Methods ====================

  /// Check if database is healthy using PRAGMA integrity_check
  /// Returns true if database passes integrity check, false otherwise
  Future<bool> isDatabaseHealthy() async {
    try {
      final result = await db.customSelect('PRAGMA integrity_check').get();

      if (result.isEmpty) {
        return false;
      }

      final integrityCheck = result.first.data['integrity_check'] as String?;
      return integrityCheck == 'ok';
    } catch (e) {
      // If we can't even run the integrity check, database is unhealthy
      return false;
    }
  }

  /// Quick health check - try to execute a simple query
  /// Returns true if database can execute basic queries, false otherwise
  Future<bool> canExecuteQueries() async {
    try {
      // Try to count records in users table (always exists)
      await db.customSelect('SELECT COUNT(*) FROM users').get();
      return true;
    } catch (e) {
      return false;
    }
  }
}

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
import '../tables/integrations_table.dart';

part 'diagnostic_dao.g.dart';

/// Data Access Object for diagnostic operations.
///
/// This DAO handles:
/// - Database cleanup operations (clearUserScopedData, clearAllData)
/// - Troubleshooting (deleteEverythingForTroubleshooting)
/// - User data migration (migrateUserData)
/// - Database health checks (isDatabaseHealthy, canExecuteQueries)
/// - Database statistics (getDatabaseStats)
@DriftAccessor(
  tables: [
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
    IntegrationsTable,
  ],
)
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
      await db.customStatement(
        '''
        DELETE FROM carb_loading_day_meals
        WHERE carb_loading_day_id IN (
          SELECT id FROM carb_loading_days
          WHERE carb_loading_plan_id IN (
            SELECT id FROM carb_loading_plans WHERE user_id = ?
          )
        )
      ''',
        [userId],
      );

      // carb_loading_days (via carb_loading_plans.user_id)
      await db.customStatement(
        '''
        DELETE FROM carb_loading_days
        WHERE carb_loading_plan_id IN (
          SELECT id FROM carb_loading_plans WHERE user_id = ?
        )
      ''',
        [userId],
      );

      // Direct user_id filtering
      await (delete(
        carbLoadingPlansTable,
      )..where((t) => t.userId.equals(userId))).go();
      await (delete(eventsTable)..where((t) => t.userId.equals(userId))).go();
      await (delete(
        activitiesTable,
      )..where((t) => t.userId.equals(userId))).go();
      await (delete(
        carbLoadingUserFoodsTable,
      )..where((t) => t.userId.equals(userId))).go();
      await (delete(
        userFoodsTable,
      )..where((t) => t.userId.equals(userId))).go();

      // feedback uses device_id, need to join with users table.
      // The SQL table is `feedback` (FeedbackTable overrides tableName), NOT
      // the class-derived `feedback_table` — the old hardcoded name threw
      // "no such table: feedback_table" during account deletion (Sentry
      // MEALVANA-ENDURANCE-B1). Use the Drift-generated name, and skip the
      // delete entirely if the table is absent (older upgrade ladders / web
      // DBs whose user_version didn't persist may never have created it).
      final feedbackName = feedbackTable.actualTableName;
      final feedbackExists = await db
          .customSelect(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
            variables: [Variable<String>(feedbackName)],
          )
          .get();
      if (feedbackExists.isNotEmpty) {
        await db.customStatement(
          '''
          DELETE FROM $feedbackName
          WHERE device_id IN (
            SELECT device_id FROM users WHERE id = ?
          )
        ''',
          [userId],
        );
      }

      // food_preferences uses user_id
      await (delete(
        foodPreferencesTable,
      )..where((t) => t.userId.equals(userId))).go();

      // integrations uses user_id
      await (delete(
        integrationsTable,
      )..where((t) => t.userId.equals(userId))).go();

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
      await delete(feedbackTable).go();
      await delete(integrationsTable).go();
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
      await db.customStatement('DELETE FROM activities WHERE user_id = ?', [
        toUserId,
      ]);
      await db.customStatement(
        'UPDATE activities SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ EVENTS ============
      await db.customStatement('DELETE FROM events WHERE user_id = ?', [
        toUserId,
      ]);
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
      await db.customStatement('DELETE FROM user_foods WHERE user_id = ?', [
        toUserId,
      ]);
      await db.customStatement(
        'UPDATE user_foods SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ CARB LOADING PLANS ============
      // Step 1: Delete carb_loading_day_meals for OAuth user's plans
      await db.customStatement(
        '''
        DELETE FROM carb_loading_day_meals
        WHERE carb_loading_day_id IN (
          SELECT id FROM carb_loading_days
          WHERE carb_loading_plan_id IN (
            SELECT id FROM carb_loading_plans WHERE user_id = ?
          )
        )
      ''',
        [toUserId],
      );

      // Step 2: Delete carb_loading_days for OAuth user's plans
      await db.customStatement(
        '''
        DELETE FROM carb_loading_days
        WHERE carb_loading_plan_id IN (
          SELECT id FROM carb_loading_plans WHERE user_id = ?
        )
      ''',
        [toUserId],
      );

      // Step 3: Delete carb_loading_plans for OAuth user
      await db.customStatement(
        'DELETE FROM carb_loading_plans WHERE user_id = ?',
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

      // ============ INTEGRATIONS ============
      // Delete any existing integrations for the target user
      await db.customStatement('DELETE FROM integrations WHERE user_id = ?', [
        toUserId,
      ]);
      // Migrate integrations from temp user to new user
      await db.customStatement(
        'UPDATE integrations SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ ONBOARDING SURVEYS ============
      // user_id is the PRIMARY KEY here (one survey per user), so the
      // delete-then-update pattern doubles as conflict protection.
      await db.customStatement(
        'DELETE FROM onboarding_surveys WHERE user_id = ?',
        [toUserId],
      );
      // Re-dirty the moved row: if it was already uploaded under the anon
      // uid, the remote copy is stranded behind RLS under that uid — the
      // survey must be re-uploaded under the new uid or it never reaches
      // the account's other devices.
      await db.customStatement(
        'UPDATE onboarding_surveys SET user_id = ?, needs_upload = 1 '
        'WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ MEAL LOGS / SAVED MEALS ============
      // Same delete-then-update shape as above. Re-dirty the moved rows for
      // the same reason as the survey: anything already uploaded under the
      // anon uid is stranded behind RLS there and must re-upload under the
      // new uid. (These tables were missing from this migration entirely
      // until 2026-08-07 — anon meal logs were orphaned under the dead uid,
      // while version_check_service's anon-data guard COULD still see them
      // and defer schema resyncs forever.)
      await db.customStatement('DELETE FROM meal_logs WHERE user_id = ?', [
        toUserId,
      ]);
      await db.customStatement(
        'UPDATE meal_logs SET user_id = ?, needs_upload = 1 WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      await db.customStatement('DELETE FROM saved_meals WHERE user_id = ?', [
        toUserId,
      ]);
      await db.customStatement(
        'UPDATE saved_meals SET user_id = ?, needs_upload = 1 '
        'WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ FORMULA KIT (pins, personal formulas, templates) ============
      await db.customStatement('DELETE FROM formula_pins WHERE user_id = ?', [
        toUserId,
      ]);
      await db.customStatement(
        'UPDATE formula_pins SET user_id = ?, needs_upload = 1 '
        'WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      await db.customStatement(
        'DELETE FROM personal_formulas WHERE user_id = ?',
        [toUserId],
      );
      await db.customStatement(
        'UPDATE personal_formulas SET user_id = ?, needs_upload = 1 '
        'WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      await db.customStatement(
        'DELETE FROM personal_templates WHERE user_id = ?',
        [toUserId],
      );
      await db.customStatement(
        'UPDATE personal_templates SET user_id = ?, needs_upload = 1 '
        'WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ RACE CHECKLISTS ============
      // No needs_upload column — LOCAL-ONLY feature with no Supabase
      // hydration, so a deleted destination row is gone forever. Unlike the
      // synced tables above, the destination's rows are therefore KEPT and
      // the source rows simply re-keyed (no unique constraint to collide).
      await db.customStatement(
        'UPDATE race_checklist_items SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ DAILY MACRO TARGETS ============
      // Recomputable cache (calculate-daily-macros repopulates). Keep the
      // destination's rows (at least as valid as the anon's) and move only
      // the source days the destination doesn't already have —
      // UNIQUE(user_id, target_date) forbids a blind re-key.
      // Deliberately NOT re-dirtied: this repository writes needs_upload=0 by
      // design and the server recomputes rather than accepting uploads.
      await db.customStatement(
        'DELETE FROM daily_macro_targets WHERE user_id = ?1 AND target_date '
        'IN (SELECT target_date FROM daily_macro_targets WHERE user_id = ?2)',
        [fromUserId, toUserId],
      );
      await db.customStatement(
        'UPDATE daily_macro_targets SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ TRAININGPEAKS WRITEBACK LOG ============
      // LOCAL-ONLY dedup ledger (no Supabase copy): wiping the destination's
      // rows would re-push already-completed workouts to TrainingPeaks as
      // duplicates. Keep the destination ledger; merge in only the source
      // entries it lacks — UNIQUE(user_id, tp_workout_id) forbids a blind
      // re-key.
      await db.customStatement(
        'DELETE FROM tp_writeback_log WHERE user_id = ?1 AND tp_workout_id '
        'IN (SELECT tp_workout_id FROM tp_writeback_log WHERE user_id = ?2)',
        [fromUserId, toUserId],
      );
      await db.customStatement(
        'UPDATE tp_writeback_log SET user_id = ? WHERE user_id = ?',
        [toUserId, fromUserId],
      );

      // ============ USER PROFILE ============
      // Delete the old anonymous user profile
      await db.customStatement('DELETE FROM users WHERE id = ?', [fromUserId]);
    });
  }

  // ==================== Statistics Methods ====================

  /// Get database statistics for logging/debugging
  Future<Map<String, int>> getDatabaseStats() async {
    final userCount = await (selectOnly(
      userProfilesTable,
    )..addColumns([userProfilesTable.id.count()])).getSingle();
    final preferencesCount = await (selectOnly(
      foodPreferencesTable,
    )..addColumns([foodPreferencesTable.userId.count()])).getSingle();
    final foodsCount = await (selectOnly(
      foodsTable,
    )..addColumns([foodsTable.id.count()])).getSingle();
    final contentCount = await (selectOnly(
      appContentTable,
    )..addColumns([appContentTable.id.count()])).getSingle();

    return {
      'users': userCount.read(userProfilesTable.id.count())!,
      'preferences': preferencesCount.read(
        foodPreferencesTable.userId.count(),
      )!,
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

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/sync/immediate_remote_write_service.dart';
import '../../../shared/data/syncable_repository.dart';
import '../../auth/domain/user_preferences.dart';

part 'food_preferences_repository.g.dart';

/// Repository for managing food preferences data in Drift database and Supabase
/// Level 2 repository - depends on users and foods
class FoodPreferencesRepository with SyncableRepository {
  FoodPreferencesRepository({
    required this.database,
    required this.supabase,
    required this.sentry,
    required this.immediateRemoteWriteService,
  });

  final AppDatabase database;
  final SupabaseClient supabase;
  final SentryReporter sentry;
  final ImmediateRemoteWriteService immediateRemoteWriteService;

  // ========== SyncableRepository Implementation ==========

  @override
  String get repositoryKey => 'food_preferences';

  @override
  List<String> get dependencies => ['users', 'template_foods']; // Needs users and template_foods to validate

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      // Query Supabase for this user's food preferences
      final response = await supabase
          .from('food_preferences')
          .select('*')
          .eq('user_id', userId);

      if (response.isEmpty) {
        // No food preferences to sync
        await setLastSyncTime(DateTime.now());
        return SyncResult.successful(0);
      }

      // Parse food preferences from Supabase response
      final preferences = <String, FoodPreference>{};
      final sliderLevels = <String, int>{};

      for (final row in response) {
        final foodName = row['food_name'] as String?;
        final preferenceValue = row['preference'] as String?;

        if (foodName == null || preferenceValue == null) continue;

        // Parse preference enum
        final parsedPreference = FoodPreference.values.firstWhere(
          (pref) => pref.value == preferenceValue,
          orElse: () => FoodPreference.dislike,
        );
        preferences[foodName] = parsedPreference;

        // Parse preference level (0-4)
        final level = row['preference_level'];
        if (level is num) {
          sliderLevels[foodName] = level.toInt().clamp(0, 4);
        }
      }

      // Save to local Drift database using mergeMode to preserve local preferences
      // that might not be on the server yet
      await saveFoodPreferences(
        userId,
        preferences,
        sliderLevels: sliderLevels.isEmpty ? null : sliderLevels,
        mergeMode: true, // Merge with existing local data
      );

      // Update last sync timestamp
      await setLastSyncTime(DateTime.now());

      sentry.addBreadcrumb(
        message: 'Food preferences synced from Supabase',
        category: 'sync',
        data: {
          'user_id': userId,
          'repository': repositoryKey,
          'count': preferences.length,
        },
      );

      return SyncResult.successful(preferences.length);
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:food_preferences:sync',
        method: 'SELECT',
        stackTrace: stackTrace,
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      // Get all food preference entries for this user
      // Note: Food preferences don't have a needs_upload flag yet
      // For now, we just upload all preferences (this is safe since it's a small dataset)
      final allPreferences = await database.foodPreferencesDao
          .getAllFoodPreferenceEntries(userId);

      if (allPreferences.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      // Convert to JSON array for batch upsert
      final preferencesToUpload = allPreferences
          .map(
            (pref) => {
              'id': pref.id,
              'user_id': pref.userId,
              'food_name': pref.foodName,
              'preference': pref.preference,
              'preference_level': pref.preferenceLevel,
              'preference_source': pref.preferenceSource,
              'created_at': pref.createdAt.toIso8601String(),
              'updated_at': pref.updatedAt.toIso8601String(),
            },
          )
          .toList();

      // Batch upload to Supabase
      await supabase
          .from('food_preferences')
          .upsert(preferencesToUpload, onConflict: 'id');

      sentry.addBreadcrumb(
        message: 'Uploaded food preferences to Supabase',
        category: 'sync',
        data: {
          'user_id': userId,
          'repository': repositoryKey,
          'count': allPreferences.length,
        },
      );

      return UploadResult.successful(allPreferences.length);
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:food_preferences:upload',
        method: 'UPSERT',
        stackTrace: stackTrace,
      );
      return UploadResult.failed(e.toString());
    }
  }

  // ========== End SyncableRepository Implementation ==========

  // ========== Food Preferences CRUD Methods ==========

  /// Save food preferences for a user
  ///
  /// [mergeMode] - when true, merges with existing preferences instead of replacing all.
  /// Use mergeMode=true when syncing from server to avoid data loss.
  /// [source] identifies the origin of the preference:
  /// - 'manual': User explicitly set this preference (default)
  /// - 'allergy:{name}': Auto-set due to an allergy (e.g., 'allergy:gluten')
  /// - 'dietary:{name}': Auto-set due to dietary preference (e.g., 'dietary:vegan')
  Future<void> saveFoodPreferences(
    String userId,
    Map<String, FoodPreference> preferences, {
    Map<String, int>? sliderLevels,
    bool mergeMode = false,
    String source = 'manual',
  }) async {
    try {
      await database.foodPreferencesDao.saveFoodPreferences(
        userId,
        preferences,
        sliderLevels: sliderLevels,
        mergeMode: mergeMode,
        source: source,
      );

      // For local user edits, attempt immediate remote write.
      // Skip for mergeMode sync pulls to avoid upload loops.
      if (!mergeMode) {
        unawaited(
          immediateRemoteWriteService.run(
            repository: repositoryKey,
            operation: 'upsert_preferences',
            recordId: userId,
            method: 'UPSERT',
            write: () => _uploadAllPreferencesForUser(userId),
          ),
        );
      }

      sentry.addBreadcrumb(
        message: 'Food preferences saved successfully',
        category: 'database',
        data: {
          'user_id': userId,
          'count': preferences.length,
          'merge_mode': mergeMode,
        },
      );
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'saveFoodPreferences',
        table: 'food_preferences_table',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Remove food preferences by source
  /// Used when allergies or dietary preferences are removed to undo auto-avoids
  /// Returns the number of preferences removed
  Future<int> removeFoodPreferencesBySource(
    String userId,
    String source,
  ) async {
    try {
      final count = await database.foodPreferencesDao
          .removeFoodPreferencesBySource(userId, source);

      sentry.addBreadcrumb(
        message: 'Removed food preferences by source',
        category: 'database',
        data: {'user_id': userId, 'source': source, 'count': count},
      );

      return count;
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'removeFoodPreferencesBySource',
        table: 'food_preferences_table',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get food preferences with their sources for a user
  Future<Map<String, String>> getFoodPreferenceSources(String userId) async {
    try {
      return await database.foodPreferencesDao.getFoodPreferenceSources(userId);
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'getFoodPreferenceSources',
        table: 'food_preferences_table',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get food preferences for a user
  Future<Map<String, FoodPreference>> getFoodPreferences(String userId) async {
    try {
      return await database.foodPreferencesDao.getUserFoodPreferences(userId);
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'getFoodPreferences',
        table: 'food_preferences_table',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get stored slider levels for each food preference
  Future<Map<String, int>> getFoodPreferenceLevels(String userId) async {
    try {
      return await database.foodPreferencesDao.getUserFoodPreferenceLevels(
        userId,
      );
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'getFoodPreferenceLevels',
        table: 'food_preferences_table',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update a single food preference
  Future<void> updateFoodPreference(
    String userId,
    String foodId,
    FoodPreference preference,
  ) async {
    try {
      final existingPreferences = await getFoodPreferences(userId);
      existingPreferences[foodId] = preference;
      final levels = await getFoodPreferenceLevels(userId);

      await saveFoodPreferences(
        userId,
        existingPreferences,
        sliderLevels: levels,
      );

      sentry.addBreadcrumb(
        message: 'Updated single food preference',
        category: 'database',
        data: {
          'user_id': userId,
          'food_id': foodId,
          'preference': preference.value,
        },
      );
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'updateFoodPreference',
        table: 'food_preferences_table',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get liked foods for a user
  Future<List<String>> getLikedFoods(String userId) async {
    try {
      return await database.foodPreferencesDao.getLikedFoods(userId);
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'getLikedFoods',
        table: 'food_preferences_table',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get disliked foods for a user
  Future<List<String>> getDislikedFoods(String userId) async {
    try {
      return await database.foodPreferencesDao.getDislikedFoods(userId);
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'getDislikedFoods',
        table: 'food_preferences_table',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _uploadAllPreferencesForUser(String userId) async {
    final allPreferences = await database.foodPreferencesDao
        .getAllFoodPreferenceEntries(userId);

    if (allPreferences.isEmpty) {
      return;
    }

    final preferencesToUpload = allPreferences
        .map(
          (pref) => {
            'id': pref.id,
            'user_id': pref.userId,
            'food_name': pref.foodName,
            'preference': pref.preference,
            'preference_level': pref.preferenceLevel,
            'preference_source': pref.preferenceSource,
            'created_at': pref.createdAt.toIso8601String(),
            'updated_at': pref.updatedAt.toIso8601String(),
          },
        )
        .toList(growable: false);

    await supabase
        .from('food_preferences')
        .upsert(preferencesToUpload, onConflict: 'id');
  }
}

/// Repository provider following Andrea's pattern
@riverpod
Future<FoodPreferencesRepository> foodPreferencesRepository(Ref ref) async {
  final database = ref.watch(appDatabaseProvider);
  final sentry = ref.watch(sentryReporterProvider);
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;

  return FoodPreferencesRepository(
    database: database,
    supabase: supabase,
    sentry: sentry,
    immediateRemoteWriteService: ref.watch(immediateRemoteWriteServiceProvider),
  );
}

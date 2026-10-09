import 'dart:async';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/report/report.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../../../shared/data/syncable_repository.dart';
import '../../auth/domain/user_preferences.dart';

part 'food_preferences_repository.g.dart';

/// Repository for managing food preferences data in Drift database and Supabase
/// Level 2 repository - depends on users and foods
class FoodPreferencesRepository with SyncableRepository {
  FoodPreferencesRepository({
    required this.database,
    required this.supabase,
    required Report report,
  }) : _report = report;

  final AppDatabase database;
  final SupabaseClient supabase;
  final Report _report;

  // ========== SyncableRepository Implementation ==========

  @override
  String get repositoryKey => 'food_preferences';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

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
      final sources = <String, String>{};

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
        // Keep the server's source, so an allergy or diet avoid stays
        // removable by its source after a pull (tickets 71, 78).
        final source = row['preference_source'];
        if (source is String && source.isNotEmpty) sources[foodName] = source;
      }

      // The table has no needs_upload flag: the pending flag and names are
      // the dirty state. While an upload is pending the local values are
      // newer than the server's, so the pull only adds foods this phone does
      // not have (ticket 103: the pull now runs after a failed upload).
      if (await _isUploadPending(userId)) {
        final local = await database.foodPreferencesDao.getUserFoodPreferences(
          userId,
        );
        preferences.removeWhere((food, _) => local.containsKey(food));
        sliderLevels.removeWhere((food, _) => local.containsKey(food));
      }

      // Save to local Drift database using mergeMode to preserve local preferences
      // that might not be on the server yet
      // Merge in place: a row this phone already has keeps its local id and
      // created_at (ticket 78).
      await saveFoodPreferences(
        userId,
        preferences,
        sliderLevels: sliderLevels.isEmpty ? null : sliderLevels,
        sources: sources,
        mergeMode: true, // Merge with existing local data
      );

      // Update last sync timestamp
      await setLastSyncTime(DateTime.now());

      _report.breadcrumb(
        'Food preferences synced from Supabase',
        category: 'sync',
        data: {
          'user_id': userId,
          'repository': repositoryKey,
          'count': preferences.length,
        },
      );

      return SyncResult.successful(preferences.length);
    } catch (e, stackTrace) {
      await _report.degraded(
        e,
        stackTrace: stackTrace,
        area: 'network',
        tags: {'method': 'SELECT'},
        extra: {'url': 'supabase:food_preferences:sync'},
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    // The table has no needs_upload column; the SharedPreferences pending
    // flag is the dirty flag (ticket 58). Without this gate every
    // ensureSynced pushed this phone's rows over the server's before the
    // pull, so a stale phone overwrote another device's edit.
    if (!await _isUploadPending(userId)) {
      _report.breadcrumb(
        'Food preferences upload skipped: nothing pending',
        category: 'sync',
        data: {'user_id': userId, 'repository': repositoryKey},
      );
      return UploadResult.nothingToUpload();
    }
    // A user edit saved while this upload runs may not be in the rows sent,
    // and its own immediate upload may fail: clear the flag and names only
    // if no save happened since the rows were read.
    final generation = _saveGenerations[userId] ?? 0;
    try {
      final count = await _uploadPendingPreferencesForUser(userId);

      _report.breadcrumb(
        'Uploaded food preferences to Supabase',
        category: 'sync',
        data: {'user_id': userId, 'repository': repositoryKey, 'count': count},
      );

      if ((_saveGenerations[userId] ?? 0) == generation) {
        await _clearUploadPending(userId);
      } else {
        _report.breadcrumb(
          'Food preferences upload flag kept: a save landed mid-upload',
          category: 'sync',
          data: {'user_id': userId, 'repository': repositoryKey},
        );
      }
      return count == 0
          ? UploadResult.nothingToUpload()
          : UploadResult.successful(count);
    } catch (e, stackTrace) {
      await _keepUploadPending(userId);
      await _report.degraded(
        e,
        stackTrace: stackTrace,
        area: 'network',
        tags: {'method': 'UPSERT'},
        extra: {'url': 'supabase:food_preferences:upload'},
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
  /// [upload] - a user edit saved with [mergeMode] (Settings) that must still
  /// reach the server. A replace ([mergeMode] false) always uploads.
  /// [sources] overrides [source] per food (ticket 71).
  ///
  /// A user-edit save marks the pending (dirty) flag and adds the foods it
  /// saved to the pending names before its upload starts; the upload sends
  /// only those foods and clears both (ticket 78). A save whose upload never
  /// lands is retried by the next dirty walk and protected from the plan
  /// path's reconcile.
  /// The upload runs after this returns: offline-first, the save succeeds on
  /// the local write.
  Future<void> saveFoodPreferences(
    String userId,
    Map<String, FoodPreference> preferences, {
    Map<String, int>? sliderLevels,
    bool mergeMode = false,
    String source = 'manual',
    Map<String, String>? sources,
    bool upload = false,
  }) async {
    try {
      final isUserEdit = upload || !mergeMode;
      // One local write at a time per user, in call order: two saves at once
      // otherwise interleave the DAO's read-then-batch and the first can land
      // last.
      await _serializedWrite(userId, () async {
        // Dirty before the write: a crash between the two leaves the flag
        // set with nothing new to send (harmless), never a new row with no
        // flag.
        if (isUserEdit) {
          _saveGenerations[userId] = (_saveGenerations[userId] ?? 0) + 1;
          await _markUploadPending(userId, preferences.keys);
        }

        await database.foodPreferencesDao.saveFoodPreferences(
          userId,
          preferences,
          sliderLevels: sliderLevels,
          mergeMode: mergeMode,
          source: source,
          sources: sources,
        );

        // For local user edits, attempt immediate remote write.
        // Skip for mergeMode sync pulls to avoid upload loops.
        if (isUserEdit) {
          unawaited(_scheduleImmediateUpload(userId));
        }
      });

      _report.breadcrumb(
        'Food preferences saved successfully',
        category: 'database',
        data: {
          'user_id': userId,
          'count': preferences.length,
          'merge_mode': mergeMode,
        },
      );
    } catch (e, stackTrace) {
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'database',
        tags: {
          'operation': 'saveFoodPreferences',
          'table': 'food_preferences_table',
        },
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

      _report.breadcrumb(
        'Removed food preferences by source',
        category: 'database',
        data: {'user_id': userId, 'source': source, 'count': count},
      );

      return count;
    } catch (e, stackTrace) {
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'database',
        tags: {
          'operation': 'removeFoodPreferencesBySource',
          'table': 'food_preferences_table',
        },
      );
      rethrow;
    }
  }

  /// Delete this user's local rows named [foodNames]. Used by Settings to drop
  /// legacy display-name rows ("Energy Chews") once their level has moved to
  /// the catalog key (`energy_chews`), so the next upload does not send them
  /// again (ticket 58). Local only: the server copies move with the lead's
  /// one-off SQL.
  Future<int> removeFoodPreferencesByNames(
    String userId,
    Iterable<String> foodNames,
  ) async {
    final names = foodNames.toList(growable: false);
    if (names.isEmpty) return 0;
    try {
      final count = await (database.delete(
        database.foodPreferencesTable,
      )..where((f) => f.userId.equals(userId) & f.foodName.isIn(names))).go();
      _report.breadcrumb(
        'Removed legacy food preference rows',
        category: 'database',
        data: {'user_id': userId, 'count': count},
      );
      return count;
    } catch (e, stackTrace) {
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'database',
        tags: {
          'operation': 'removeFoodPreferencesByNames',
          'table': 'food_preferences_table',
        },
      );
      rethrow;
    }
  }

  /// Get food preferences with their sources for a user
  Future<Map<String, String>> getFoodPreferenceSources(String userId) async {
    try {
      return await database.foodPreferencesDao.getFoodPreferenceSources(userId);
    } catch (e, stackTrace) {
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'database',
        tags: {
          'operation': 'getFoodPreferenceSources',
          'table': 'food_preferences_table',
        },
      );
      rethrow;
    }
  }

  /// Get food preferences for a user
  Future<Map<String, FoodPreference>> getFoodPreferences(String userId) async {
    try {
      return await database.foodPreferencesDao.getUserFoodPreferences(userId);
    } catch (e, stackTrace) {
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'database',
        tags: {
          'operation': 'getFoodPreferences',
          'table': 'food_preferences_table',
        },
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
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'database',
        tags: {
          'operation': 'getFoodPreferenceLevels',
          'table': 'food_preferences_table',
        },
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

      _report.breadcrumb(
        'Updated single food preference',
        category: 'database',
        data: {
          'user_id': userId,
          'food_id': foodId,
          'preference': preference.value,
        },
      );
    } catch (e, stackTrace) {
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'database',
        tags: {
          'operation': 'updateFoodPreference',
          'table': 'food_preferences_table',
        },
      );
      rethrow;
    }
  }

  /// Get liked foods for a user
  Future<List<String>> getLikedFoods(String userId) async {
    try {
      return await database.foodPreferencesDao.getLikedFoods(userId);
    } catch (e, stackTrace) {
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'database',
        tags: {'operation': 'getLikedFoods', 'table': 'food_preferences_table'},
      );
      rethrow;
    }
  }

  /// Get disliked foods for a user
  Future<List<String>> getDislikedFoods(String userId) async {
    try {
      return await database.foodPreferencesDao.getDislikedFoods(userId);
    } catch (e, stackTrace) {
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'database',
        tags: {
          'operation': 'getDislikedFoods',
          'table': 'food_preferences_table',
        },
      );
      rethrow;
    }
  }

  /// Whether this user's local preferences have changes the server has not
  /// taken. Kept in SharedPreferences because a rejected upload outlives the
  /// app session, like the `needs_upload` flag other tables carry.
  Future<bool> _isUploadPending(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(foodPreferencesUploadPendingKey(userId)) ?? false;
  }

  /// Sets the flag and adds [foodNames] to the pending names. A phone that
  /// had the flag set before the names existed (upgraded mid-pending) first
  /// lists every local row, so this save does not narrow what goes up.
  Future<void> _markUploadPending(
    String userId,
    Iterable<String> foodNames,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final flagKey = foodPreferencesUploadPendingKey(userId);
    final namesKey = foodPreferencesUploadPendingNamesKey(userId);
    final names = <String>{...?prefs.getStringList(namesKey)};
    if ((prefs.getBool(flagKey) ?? false) && !prefs.containsKey(namesKey)) {
      final rows = await database.foodPreferencesDao
          .getAllFoodPreferenceEntries(userId);
      names.addAll(rows.map((r) => r.foodName));
    }
    names.addAll(foodNames);
    await prefs.setStringList(namesKey, names.toList()..sort());
    await prefs.setBool(flagKey, true);
  }

  /// The foods waiting to go up, or null when the flag predates the names
  /// list (then every local row goes up once).
  Future<Set<String>?> _pendingNames(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getStringList(foodPreferencesUploadPendingNamesKey(userId))
        ?.toSet();
  }

  /// A failed upload: keep the names, make sure the flag is set.
  Future<void> _keepUploadPending(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(foodPreferencesUploadPendingKey(userId), true);
  }

  Future<void> _clearUploadPending(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(foodPreferencesUploadPendingKey(userId));
    await prefs.remove(foodPreferencesUploadPendingNamesKey(userId));
  }

  // One immediate upload in flight per user, across repository instances
  // (the provider is autoDispose, so each caller may hold its own instance).
  // A save while one runs asks for one more pass, so the last save's rows are
  // the last ones sent.
  static final Map<String, Future<void>> _inFlightUploads = {};
  static final Set<String> _uploadRerunOwed = {};

  // User-edit saves per user, counted up before each save's flag is set. The
  // dirty walk clears the flag only if this has not moved since it read the
  // rows it sent.
  static final Map<String, int> _saveGenerations = {};

  /// The in-flight immediate upload for [userId], if any. Tests await it
  /// instead of guessing how many event-loop turns the upload takes.
  @visibleForTesting
  static Future<void>? inFlightUploadFor(String userId) =>
      _inFlightUploads[userId];

  static final Map<String, Future<void>> _writeTails = {};

  Future<void> _serializedWrite(
    String userId,
    Future<void> Function() write,
  ) async {
    final previous = _writeTails[userId];
    final done = Completer<void>();
    final tail = done.future;
    _writeTails[userId] = tail;
    try {
      if (previous != null) {
        // The previous write reports its own failure to its caller.
        await previous.catchError((Object _) {});
      }
      await write();
    } finally {
      done.complete();
      if (identical(_writeTails[userId], tail)) _writeTails.remove(userId);
    }
  }

  Future<void> _scheduleImmediateUpload(String userId) {
    final running = _inFlightUploads[userId];
    if (running != null) {
      _uploadRerunOwed.add(userId);
      return running;
    }
    final future = () async {
      try {
        do {
          _uploadRerunOwed.remove(userId);
          await _runImmediateUpload(userId);
        } while (_uploadRerunOwed.contains(userId));
      } finally {
        _inFlightUploads.remove(userId);
      }
    }();
    _inFlightUploads[userId] = future;
    return future;
  }

  Future<void> _runImmediateUpload(String userId) async {
    final generation = _saveGenerations[userId] ?? 0;
    try {
      await _uploadPendingPreferencesForUser(userId);
      // A save that landed during this upload (its names were added after
      // the read) owes another pass: the flag and names stay until that pass
      // sends its rows. The generation catches a save whose rerun request
      // has not arrived yet.
      if (!_uploadRerunOwed.contains(userId) &&
          (_saveGenerations[userId] ?? 0) == generation) {
        await _clearUploadPending(userId);
      }
    } catch (e, stackTrace) {
      await _keepUploadPending(userId);
      _report.breadcrumb(
        'Immediate upload failed; record stays dirty for retry',
        category: 'sync',
        data: {'operation': 'upsert_preferences', 'recordId': userId},
      );
      await _report.degraded(
        e,
        stackTrace: stackTrace,
        area: 'network',
        tags: {'method': 'UPSERT'},
        extra: {'url': 'supabase:food_preferences:upsert'},
      );
    }
  }

  /// Sends the pending foods' local rows for [userId]; returns how many.
  /// Throws on a rejected write.
  ///
  /// No `id` and no `created_at` (ticket 78): the upsert on
  /// (user_id, food_name) updates only the columns sent, so an existing
  /// server row keeps both and a new one takes the server defaults. Local
  /// ids may then differ from server ids; nothing compares them.
  Future<int> _uploadPendingPreferencesForUser(String userId) async {
    final names = await _pendingNames(userId);
    final allPreferences = await database.foodPreferencesDao
        .getAllFoodPreferenceEntries(userId);
    final pending = names == null
        ? allPreferences
        : allPreferences
              .where((p) => names.contains(p.foodName))
              .toList(growable: false);

    if (pending.isEmpty) {
      return 0;
    }

    final preferencesToUpload = pending
        .map(
          (pref) => {
            'user_id': pref.userId,
            'food_name': pref.foodName,
            'preference': pref.preference,
            'preference_level': pref.preferenceLevel,
            'preference_source': pref.preferenceSource,
            'updated_at': pref.updatedAt.toUtc().toIso8601String(),
          },
        )
        .toList(growable: false);

    // The server index on (user_id, food_name) is full, not partial, so this
    // onConflict target is valid (CLAUDE.md's 42P10 rule does not apply).
    await supabase
        .from('food_preferences')
        .upsert(preferencesToUpload, onConflict: 'user_id,food_name');
    return pending.length;
  }
}

/// SharedPreferences key of the food-preferences upload-pending (dirty) flag.
/// Read by [FoodPreferencesRepository] and by `UserRepository`'s plan-path
/// reconcile, which must not replace local rows the server has not taken.
String foodPreferencesUploadPendingKey(String userId) =>
    'food_preferences_upload_pending_$userId';

/// SharedPreferences key of the food names a user-edit save left for upload
/// (ticket 78). Set beside [foodPreferencesUploadPendingKey], cleared with it.
String foodPreferencesUploadPendingNamesKey(String userId) =>
    'food_preferences_upload_pending_names_$userId';

/// Repository provider following Andrea's pattern
@riverpod
Future<FoodPreferencesRepository> foodPreferencesRepository(Ref ref) async {
  final database = ref.watch(appDatabaseProvider);
  final report = ref.watch(reportProvider);
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;

  return FoodPreferencesRepository(
    database: database,
    supabase: supabase,
    report: report,
  );
}

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables/food_preferences.dart';
import '../tables/user_profiles.dart';
import '../../../features/auth/domain/user_preferences.dart' as domain;

part 'food_preferences_dao.g.dart';

/// Data Access Object for food preferences.
///
/// This DAO handles:
/// - CRUD operations for food preferences
/// - Preference level management (0-4 scale)
/// - Preference source tracking (manual, allergy, dietary)
/// - Liked/disliked food queries
@DriftAccessor(tables: [FoodPreferencesTable, UserProfilesTable])
class FoodPreferencesDao extends DatabaseAccessor<AppDatabase>
    with _$FoodPreferencesDaoMixin {
  FoodPreferencesDao(super.db);

  /// Generate a UUID for new preference entries
  String _generateUuid() => const Uuid().v4();

  /// Save food preferences for a user
  ///
  /// [mergeMode] controls how existing preferences are handled:
  /// - `false` (default): Replace all preferences (used when user explicitly saves)
  /// - `true`: Merge with existing preferences, only updating provided items
  ///   (used when syncing from server to avoid data loss)
  /// [source] identifies the origin of the preference:
  /// - 'manual': User explicitly set this preference (default)
  /// - 'allergy:{name}': Auto-set due to an allergy (e.g., 'allergy:gluten')
  /// - 'dietary:{name}': Auto-set due to dietary preference (e.g., 'dietary:vegan')
  Future<void> saveFoodPreferences(
    String userId,
    Map<String, domain.FoodPreference> preferences, {
    Map<String, int>? sliderLevels,
    bool mergeMode = false,
    String source = 'manual',
  }) async {
    // Get existing preferences to merge metadata properly
    Map<String, domain.FoodPreference>? existingPrefs;
    Map<String, int>? existingLevels;
    if (mergeMode) {
      existingPrefs = await getUserFoodPreferences(userId);
      existingLevels = await getUserFoodPreferenceLevels(userId);
    }

    await batch((batch) {
      // Only delete all preferences if NOT in merge mode
      // In merge mode, we upsert individual items to preserve local data
      if (!mergeMode) {
        batch.deleteWhere(
            foodPreferencesTable, (f) => f.userId.equals(userId));
      }

      // Insert/update preferences using upsert
      for (final entry in preferences.entries) {
        final sliderLevel =
            sliderLevels?[entry.key] ?? _defaultSliderLevel(entry.value);
        batch.insert(
          foodPreferencesTable,
          FoodPreferencesTableCompanion.insert(
            id: _generateUuid(),
            userId: userId,
            foodName: entry.key,
            preference: entry.value.value,
            preferenceLevel: Value(sliderLevel),
            preferenceSource: Value(source),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    // Build metadata map, preserving existing entries in merge mode
    final metadata = <String, dynamic>{};

    // In merge mode, start with existing preferences
    if (mergeMode && existingPrefs != null) {
      for (final entry in existingPrefs.entries) {
        final existingLevel =
            existingLevels?[entry.key] ?? _defaultSliderLevel(entry.value);
        metadata[entry.key] = {
          'preference': entry.value.value,
          'slider_level': existingLevel,
        };
      }
    }

    // Add/update with new preferences (these override existing in merge mode)
    for (final entry in preferences.entries) {
      final sliderLevel =
          sliderLevels?[entry.key] ?? _defaultSliderLevel(entry.value);
      metadata[entry.key] = {
        'preference': entry.value.value,
        'slider_level': sliderLevel,
      };
    }

    await (update(userProfilesTable)..where((u) => u.id.equals(userId))).write(
      UserProfilesTableCompanion(
        foodPreferences: Value(metadata),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get food preferences for a user
  Future<Map<String, domain.FoodPreference>> getUserFoodPreferences(
    String userId,
  ) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId));
    final results = await query.get();

    final preferencesMap = <String, domain.FoodPreference>{};
    for (final row in results) {
      final preference = domain.FoodPreference.values.firstWhere(
        (p) => p.value == row.preference,
        orElse: () => domain.FoodPreference.dislike,
      );
      preferencesMap[row.foodName] = preference;
    }

    return preferencesMap;
  }

  /// Get food preference levels (0-4 scale) for a user
  Future<Map<String, int>> getUserFoodPreferenceLevels(String userId) async {
    final rows = await (select(foodPreferencesTable)
          ..where((f) => f.userId.equals(userId)))
        .get();

    if (rows.isEmpty) {
      // Fallback to legacy JSON metadata in user profile
      final profile = await (select(userProfilesTable)
            ..where((u) => u.id.equals(userId))
            ..limit(1))
          .getSingleOrNull();

      if (profile == null) return {};

      final legacyLevels = <String, int>{};
      profile.foodPreferences.forEach((foodName, rawValue) {
        if (rawValue is Map<String, dynamic>) {
          final slider = rawValue['slider_level'];
          if (slider is num) {
            legacyLevels[foodName] = slider.toInt().clamp(0, 4);
          }
        }
      });

      return legacyLevels;
    }

    final levels = <String, int>{};
    for (final row in rows) {
      final normalizedLevel =
          (row.preferenceLevel ?? _defaultSliderLevel(_parsePreference(row.preference)))
              .clamp(0, 4)
              .toInt();
      levels[row.foodName] = normalizedLevel;
    }

    return levels;
  }

  /// Get liked foods for a user
  Future<List<String>> getLikedFoods(String userId) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId) & f.preference.equals('like'));
    final results = await query.get();
    return results.map((r) => r.foodName).toList();
  }

  /// Get disliked foods for a user
  Future<List<String>> getDislikedFoods(String userId) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId) & f.preference.equals('dislike'));
    final results = await query.get();
    return results.map((r) => r.foodName).toList();
  }

  /// Get willing-to-try foods for a user
  Future<List<String>> getWillingToTryFoods(String userId) async {
    final query = select(foodPreferencesTable)
      ..where((f) =>
          f.userId.equals(userId) & f.preference.equals('willing_to_try'));
    final results = await query.get();
    return results.map((r) => r.foodName).toList();
  }

  /// Remove food preferences by source
  ///
  /// Used when allergies or dietary preferences are removed to undo auto-avoids
  /// [source] - The source to match (e.g., 'allergy:gluten', 'dietary:vegan')
  /// Returns the number of preferences removed
  Future<int> removeFoodPreferencesBySource(String userId, String source) async {
    return await (delete(foodPreferencesTable)
          ..where((f) =>
              f.userId.equals(userId) & f.preferenceSource.equals(source)))
        .go();
  }

  /// Remove all food preferences with sources matching a pattern
  ///
  /// [sourcePrefix] - The prefix to match (e.g., 'allergy:' or 'dietary:')
  /// Returns the number of preferences removed
  Future<int> removeFoodPreferencesBySourcePrefix(
    String userId,
    String sourcePrefix,
  ) async {
    // Use LIKE pattern for prefix matching
    return await (delete(foodPreferencesTable)
          ..where((f) => f.userId.equals(userId))
          ..where((f) => f.preferenceSource.like('$sourcePrefix%')))
        .go();
  }

  /// Get food preferences with their sources for a user
  ///
  /// Returns a map of food name -> preference source
  Future<Map<String, String>> getFoodPreferenceSources(String userId) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId));
    final results = await query.get();

    final sourcesMap = <String, String>{};
    for (final row in results) {
      sourcesMap[row.foodName] = row.preferenceSource;
    }
    return sourcesMap;
  }

  /// Get all food preference entries for a user (for upload to Supabase)
  ///
  /// Returns raw FoodPreferenceEntry objects with id, food_name, preference, preference_level
  Future<List<FoodPreferenceEntry>> getAllFoodPreferenceEntries(
    String userId,
  ) async {
    final query = select(foodPreferencesTable)
      ..where((f) => f.userId.equals(userId));
    return await query.get();
  }

  /// Convert preference to default slider level (0-4 scale)
  int _defaultSliderLevel(domain.FoodPreference preference) {
    switch (preference) {
      case domain.FoodPreference.dislike:
        return 1;
      case domain.FoodPreference.willingToTry:
        return 2;
      case domain.FoodPreference.like:
        return 3;
    }
  }

  /// Parse string preference value to enum
  domain.FoodPreference _parsePreference(String value) {
    return domain.FoodPreference.values.firstWhere(
      (p) => p.value == value,
      orElse: () => domain.FoodPreference.willingToTry,
    );
  }
}

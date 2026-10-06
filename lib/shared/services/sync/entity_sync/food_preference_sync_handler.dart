import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../database/app_database.dart';
import '../../../database/database_provider.dart';
import '../../../../features/auth/domain/user_preferences.dart';
import '../../report/report.dart';

part 'food_preference_sync_handler.g.dart';

@Riverpod(keepAlive: true)
FoodPreferenceSyncHandler foodPreferenceSyncHandler(Ref ref) {
  return FoodPreferenceSyncHandler(
    database: ref.read(appDatabaseProvider),
    report: ref.read(reportProvider),
  );
}

/// Handles sync operations for food preference entities.
class FoodPreferenceSyncHandler {
  const FoodPreferenceSyncHandler({
    required AppDatabase database,
    Report? report,
  }) : _database = database,
       _report = report;

  final AppDatabase _database;
  final Report? _report;

  /// Injected by the provider; tests may pass a `RecordingReport`.
  Report get _r => _report ?? SentryReport.global;

  /// Sync food preferences from edge function response.
  /// Uses merge mode to preserve local preferences not in server response.
  Future<void> syncFoodPreferencesFromEdgeFunction(
    List<dynamic> foodPreferences,
  ) async {
    try {
      if (foodPreferences.isEmpty) {
        return;
      }

      // Extract user_id from first preference (all should have same user_id)
      final firstPref = foodPreferences.first as Map<String, dynamic>;
      final userId = firstPref['user_id'] as String?;
      if (userId == null) {
        _r.degraded(
          const LoggedFault('Food preferences missing user_id, skipping sync'),
          area: 'sync',
        );
        return;
      }

      // Convert to preference maps
      final preferences = <String, FoodPreference>{};
      final sliderLevels = <String, int>{};

      for (final prefData in foodPreferences) {
        final data = prefData as Map<String, dynamic>;
        final foodName = data['food_name'] as String?;
        final preferenceValue = data['preference'] as String?;
        final preferenceLevel = data['preference_level'] as int?;

        if (foodName == null || preferenceValue == null) continue;

        // Parse preference enum
        final preference = FoodPreference.values.firstWhere(
          (p) => p.value == preferenceValue,
          orElse: () => FoodPreference.willingToTry,
        );

        preferences[foodName] = preference;
        if (preferenceLevel != null) {
          sliderLevels[foodName] = preferenceLevel.clamp(0, 4);
        }
      }

      // SAFETY CHECK: Don't wipe local data if server returned empty
      if (preferences.isEmpty) {
        final localPrefs = await _database.foodPreferencesDao
            .getUserFoodPreferences(userId);
        if (localPrefs.isNotEmpty) {
          _r.degraded(
            LoggedFault(
              'Server returned empty food_preferences but local has ${localPrefs.length} items - keeping local data',
            ),
            area: 'sync',
          );
          return;
        }
      }

      // Use merge mode to preserve local preferences not in server response
      await _database.foodPreferencesDao.saveFoodPreferences(
        userId,
        preferences,
        sliderLevels: sliderLevels.isEmpty ? null : sliderLevels,
        mergeMode: true,
      );
    } catch (e, stackTrace) {
      // Don't rethrow - continue with other syncs
      await _r.fault(
        e,
        stackTrace: stackTrace,
        area: 'sync',
        message: 'Failed to sync food preferences from edge function',
        tags: {'entity': 'food_preferences'},
        extra: {'count': foodPreferences.length},
      );
    }
  }
}

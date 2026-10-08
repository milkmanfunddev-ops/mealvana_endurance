import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/report/report.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../food_preferences/data/food_preferences_repository.dart';
import '../../../food_preferences/domain/food_preference_key.dart';
import '../../../nutrition_plan/domain/food_item.dart';

part 'food_preferences_controller.g.dart';

/// Default slider level for a primary catalog food or a user food with no row.
const int defaultPrimaryFoodLevel = 2;

/// Default slider level for an additional catalog food with no row.
const int defaultAdditionalFoodLevel = 0;

/// Slider level (0-4) to the three-state preference the plan engine reads.
FoodPreference foodPreferenceForLevel(int level) {
  if (level <= 1) return FoodPreference.dislike;
  if (level >= 3) return FoodPreference.like;
  return FoodPreference.willingToTry;
}

/// Settings > Food Likes & Dislikes: loads the athlete's levels (synced from
/// the server on demand) and saves them through [FoodPreferencesRepository],
/// which uploads (ticket 58).
///
/// State: slider levels by preference key ([foodPreferenceKey]: the catalog
/// `template_foods.name`, or a user food's name).
@riverpod
class FoodPreferencesController extends _$FoodPreferencesController {
  static const String _area = 'settings';
  static const Duration _syncTimeout = Duration(seconds: 10);

  // Riverpod reuses this instance across invalidate: reset in build. The
  // generation only grows, so a load from before a rebuild never matches.
  int _loadGeneration = 0;
  Set<String> _legacyNames = const {};

  Report get _report => ref.read(reportProvider);

  @override
  FutureOr<Map<String, int>> build() {
    _loadGeneration++;
    _legacyNames = const {};
    return const {};
  }

  /// The signed-in account's profile id (through [userIdProvider]), or null
  /// with no session.
  Future<String?> _resolveUserId() async {
    final hasSession =
        ref.read(appExternalDepsProvider).supabaseClient.auth.currentUser !=
        null;
    if (!hasSession) return null;
    return ref.read(userIdProvider.future);
  }

  /// Sync `food_preferences` on demand, then read the levels for the foods on
  /// screen. A failed sync continues on the cached rows.
  ///
  /// Twice at once: both `ensureSynced` calls join the coordinator's
  /// in-flight sync and the later call's result wins state. After a refresh
  /// the generation counter restarts and a finishing older load is dropped.
  Future<void> load({
    required List<FoodItem> primary,
    required List<FoodItem> additional,
    required List<FoodItem> userFoods,
  }) async {
    final generation = ++_loadGeneration;
    final result = await AsyncValue.guard(
      () =>
          _load(primary: primary, additional: additional, userFoods: userFoods),
    );
    if (!ref.mounted || generation != _loadGeneration) return;
    state = result;
  }

  Future<Map<String, int>> _load({
    required List<FoodItem> primary,
    required List<FoodItem> additional,
    required List<FoodItem> userFoods,
  }) async {
    final report = _report;
    final userId = await _resolveUserId();
    var preferences = const <String, FoodPreference>{};
    var levels = const <String, int>{};

    if (userId == null) {
      await report.note(
        'Food preferences load: no signed-in user; showing defaults',
        area: _area,
      );
    } else {
      // load() drops this result once disposed; stop before touching ref.
      if (!ref.mounted) return const {};
      final coordinator = ref.read(syncCoordinatorProvider.notifier);
      final repo = await ref.read(foodPreferencesRepositoryProvider.future);
      try {
        // Bounded so a slow network shows cached levels instead of a spinner.
        // The timeout does not cancel the sync: its pull and any pending
        // upload (an upsert on user_id,food_name, safe to repeat) finish in
        // the background.
        await coordinator
            .ensureSynced('food_preferences', userId, repository: repo)
            .timeout(_syncTimeout);
      } catch (e, stackTrace) {
        await report.degraded(
          e,
          stackTrace: stackTrace,
          area: _area,
          message: 'Food preferences sync failed; continuing with cached data',
        );
      }
      preferences = await repo.getFoodPreferences(userId);
      levels = await repo.getFoodPreferenceLevels(userId);
    }

    final allKeys = <String>{
      for (final f in [...primary, ...additional, ...userFoods])
        foodPreferenceKey(f),
    };
    final legacyNames = <String>{};

    int? levelFor(String name) {
      final pref = preferences[name];
      if (pref == null) return null;
      return (levels[name] ?? sliderLevelForPreference(pref)).clamp(0, 4);
    }

    int resolve(FoodItem food, int fallback) {
      final key = foodPreferenceKey(food);
      final own = levelFor(key);
      // A row the old Settings wrote under the display name ("Energy
      // Chews"): fold it onto the key when the key has no row of its own.
      final legacyName = food.name;
      final isLegacy =
          legacyName != key &&
          !allKeys.contains(legacyName) &&
          preferences.containsKey(legacyName);
      if (isLegacy) legacyNames.add(legacyName);
      return own ?? (isLegacy ? levelFor(legacyName) : null) ?? fallback;
    }

    final result = <String, int>{};
    for (final food in primary) {
      result[foodPreferenceKey(food)] = resolve(food, defaultPrimaryFoodLevel);
    }
    for (final food in additional) {
      result[foodPreferenceKey(food)] = resolve(
        food,
        defaultAdditionalFoodLevel,
      );
    }
    for (final food in userFoods) {
      result[foodPreferenceKey(food)] = resolve(food, defaultPrimaryFoodLevel);
    }

    _legacyNames = legacyNames;
    return result;
  }

  /// Save [levelsByKey] locally (merging: rows for foods not on this screen,
  /// such as onboarding's avoids, stay) and upload them. A failed upload is
  /// not a failed save: the rows stay dirty and the next sync retries. Only a
  /// missing user is an error state.
  ///
  /// Twice at once: the repository serialises the uploads and reruns the
  /// in-flight one, so the last save's rows are the last sent. The upload
  /// belongs to the repository, so closing Settings mid-upload loses nothing.
  Future<void> save(Map<String, int> levelsByKey) async {
    final report = _report;
    final result = await AsyncValue.guard(() async {
      final userId = await _resolveUserId();
      if (userId == null) {
        await report.note(
          'Food preferences save: no signed-in user; nothing saved',
          area: _area,
          data: {'count': levelsByKey.length},
        );
        throw StateError('No signed-in user to save food preferences for');
      }
      final levels = {
        for (final e in levelsByKey.entries) e.key: e.value.clamp(0, 4),
      };
      final preferences = {
        for (final e in levels.entries) e.key: foodPreferenceForLevel(e.value),
      };
      // Disposed mid-resolve: save() drops the result, so stop before ref.
      if (!ref.mounted) {
        throw StateError('Food preferences controller disposed before save');
      }
      final repo = await ref.read(foodPreferencesRepositoryProvider.future);
      final legacy = _legacyNames.where((n) => !levels.containsKey(n));
      await repo.removeFoodPreferencesByNames(userId, legacy);
      await repo.saveFoodPreferences(
        userId,
        preferences,
        sliderLevels: levels,
        mergeMode: true,
        upload: true,
      );
      _legacyNames = const {};
      return Map<String, int>.unmodifiable(levels);
    });
    if (!ref.mounted) return;
    state = result;
  }
}

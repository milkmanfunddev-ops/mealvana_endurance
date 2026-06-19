/**
 * Regression test for #23: getLikedFoods / getDislikedFoods must not silently
 * return [] when the local Drift cache is empty. The Drift-first / Supabase-
 * fallback policy lives in UserRepository; this test exercises both paths.
 *
 * Mocking the Supabase fluent API end-to-end is brittle (see the note in
 * test/new_sync/food_preferences_repository_test.dart), so we cover the
 * Drift-populated path directly and verify the Drift-empty path doesn't
 * throw — the fallback call to fetchAndCacheRemoteFoodPreferences will fail
 * because the Supabase mock has no stubs, and _safeHydrateFoodPreferencesFromRemote
 * must swallow that and return [].
 */

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSentryReporter extends Mock implements SentryReporter {}

void main() {
  late AppDatabase database;
  late MockSupabaseClient mockSupabase;
  late MockSentryReporter mockSentry;
  late UserRepository repository;

  const testUserId = 'test-user-23';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    mockSupabase = MockSupabaseClient();
    mockSentry = MockSentryReporter();

    when(
      () => mockSentry.reportNetworkError(
        any(),
        url: any(named: 'url'),
        method: any(named: 'method'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockSentry.reportDatabaseError(
        any(),
        operation: any(named: 'operation'),
        table: any(named: 'table'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});

    repository = UserRepository(
      database: database,
      supabase: mockSupabase,
      sentry: mockSentry,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('#23: getLikedFoods / getDislikedFoods Drift-first fallback', () {
    test('returns Drift-stored disliked foods (remote reconcile is best-effort)',
        () async {
      await database.foodPreferencesDao.saveFoodPreferences(testUserId, {
        'baked_potato': FoodPreference.dislike,
        'cream_cheese': FoodPreference.dislike,
        'oatmeal': FoodPreference.like,
      });

      // The read returns Drift data directly. A TTL-gated background reconcile
      // (_reconcileFoodPreferencesIfStale) may fire against Supabase, but it is
      // best-effort: even though mockSupabase has no stubs (so the fetch
      // throws), the returned data still comes from Drift and the read does not
      // throw. (The old contract asserted Supabase was never consulted; the
      // reconcile-if-stale behaviour intentionally superseded that.)
      final dislikes = await repository.getDislikedFoods(testUserId);

      expect(dislikes, containsAll(['baked_potato', 'cream_cheese']));
      expect(dislikes, hasLength(2));
    });

    test('returns Drift-stored liked foods (remote reconcile is best-effort)',
        () async {
      await database.foodPreferencesDao.saveFoodPreferences(testUserId, {
        'oatmeal': FoodPreference.like,
        'bagel': FoodPreference.like,
        'baked_potato': FoodPreference.dislike,
      });

      final likes = await repository.getLikedFoods(testUserId);

      expect(likes, containsAll(['oatmeal', 'bagel']));
      expect(likes, hasLength(2));
    });

    test('returns [] safely when Drift is empty AND Supabase fallback throws', () async {
      // No Supabase stubs → any chained .from(...).select(...).eq(...) call
      // will throw via mocktail. _safeHydrateFoodPreferencesFromRemote must
      // catch that so the read returns [] rather than throwing into the
      // plan-generation pipeline.
      final dislikes = await repository.getDislikedFoods(testUserId);
      expect(dislikes, isEmpty);

      final likes = await repository.getLikedFoods(testUserId);
      expect(likes, isEmpty);
    });
  });
}

// Seeded-foods resync on a curated-row miss (1.30.0 fix, reproduced
// 2026-10-07): `FoodRepository.isStale()` only forces a `foods` sync when
// the mirror is EMPTY and nothing calls `ensureSynced('foods')`, so a
// catalog row seeded server-side after a device's first sync never
// arrives. With the 'Rice' row absent, tapping the curated "Rice (1 cup
// cooked)" row fell through the G25 token pass to 'Rice pudding' (30 g) —
// a wrong food, not even the search fallback.
//
// The provider now runs the exact pass (G26) first; on a miss it asks the
// repository for ONE throttled catalog refresh and re-runs the full
// resolver (exact then token — G25/G26 semantics untouched). Modelled on
// g25_one_tap_log_test.dart: in-memory AppDatabase, the REAL wire mapper
// seeding the mirror, a FoodRepository subclass standing in for the
// network.
//
//  (a) mirror has 'Rice pudding' but not 'Rice' → the refresh seeds 'Rice'
//      → provider returns 'Rice', refresh count == 1 (red before the fix:
//      'Rice pudding', count 0);
//  (b) refresh reports false (offline, fail-closed) → the token-pass
//      result ('Rice pudding') comes back, nothing throws;
//  (c) exact hit present → refresh count == 0.
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/carb_loading/application/carb_slot_recommendations.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/food_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fixtures/g25_catalog_fixtures.dart';

import '../../helpers/fakes/recording_report.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

const userId = 'user-resync';

/// Stands in for the network: counts [refreshAfterMiss] calls and, when
/// [seedOnRefresh] is set, replays a full catalog sync (the real wire
/// mapper, the full post-seed row set) exactly as a successful
/// `syncFromRemote` would, then reports success. Otherwise reports the
/// fail-closed `false` (offline) and leaves the mirror alone.
class _CountingFoodRepository extends FoodRepository {
  _CountingFoodRepository(
    super.supabase,
    super.database, {
    required super.report,
    required this.seedOnRefresh,
  });

  final bool seedOnRefresh;
  int refreshCalls = 0;
  final List<String> seenUserIds = [];

  @override
  Future<bool> refreshAfterMiss(String userId) async {
    refreshCalls++;
    seenUserIds.add(userId);
    if (!seedOnRefresh) return false;
    await syncFoodsToLocalDatabase(wireFoodRowsPostSeed);
    return true;
  }
}

void main() {
  late AppDatabase db;
  late RecordingReport report;

  setUp(() {
    db = AppDatabase.forTesting(
      // A background-isolate executor, like the app's (connection_native.dart):
      // every query crosses an event-loop turn. An autoDispose provider that
      // only gets `read` is scheduled for disposal at the next turn, so a
      // resolver that still touches `ref` after its first await throws there
      // (and did, silently, on the simulator). A plain in-memory executor
      // answers within microtasks and never sees it.
      NativeDatabase.createInBackground(
        File('${Directory.systemTemp.createTempSync('carb_resync').path}/t.db'),
      ),
    );
    addTearDown(db.close);
    report = RecordingReport();
  });

  /// The device's mirror from BEFORE the server-side 'Rice' seed: every
  /// post-seed wire row except 'Rice', through the real sync mapper.
  final wireRowsWithoutRice = wireFoodRowsPostSeed
      .where((row) => row['name'] != 'Rice')
      .toList();

  Future<_CountingFoodRepository> seedMirror(
    List<Map<String, dynamic>> rows, {
    required bool seedOnRefresh,
  }) async {
    final repository = _CountingFoodRepository(
      MockSupabaseClient(),
      db,
      report: report,
      seedOnRefresh: seedOnRefresh,
    );
    await repository.syncFoodsToLocalDatabase(rows);
    return repository;
  }

  ProviderContainer containerFor(_CountingFoodRepository repository) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        userIdProvider.overrideWith((ref) async => userId),
        foodRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    '(a) exact miss: the mirror predates the Rice seed → one catalog '
    'refresh → Rice resolves, not its token-pass sibling Rice pudding',
    () async {
      final repository = await seedMirror(
        wireRowsWithoutRice,
        seedOnRefresh: true,
      );
      // Pre-condition: the stale mirror really lacks 'Rice' and the token
      // pass alone would land on 'Rice pudding' (the reproduced bug).
      final staleOnly = await resolveCarbRecommendation(db, 'Rice');
      expect(staleOnly?.title, 'Rice pudding');

      final container = containerFor(repository);
      final resolution = await container.read(
        carbRecommendationResolutionProvider('Rice').future,
      );

      expect(resolution, isNotNull);
      expect(
        resolution!.title,
        'Rice',
        reason: 'the seeded row must win, never the token-pass sibling',
      );
      expect(
        resolution.component.carbG,
        45.0,
        reason: 'real macros of the seeded Rice row (not Rice pudding\'s 30)',
      );
      expect(resolution.component.calories, 200);
      expect(repository.refreshCalls, 1);
      expect(repository.seenUserIds, [userId]);
    },
  );

  test('(b) refresh fails closed (offline) → the ratified token-pass result '
      'still comes back, nothing throws', () async {
    final repository = await seedMirror(
      wireRowsWithoutRice,
      seedOnRefresh: false,
    );
    final container = containerFor(repository);

    final resolution = await container.read(
      carbRecommendationResolutionProvider('Rice').future,
    );

    expect(repository.refreshCalls, 1);
    expect(resolution, isNotNull);
    expect(
      resolution!.title,
      'Rice pudding',
      reason: 'offline the full resolver (exact then token) runs as before',
    );
    expect(resolution.component.carbG, 30.0);
  });

  test('(c) exact hit present → no refresh at all', () async {
    final repository = await seedMirror(
      wireFoodRowsPostSeed,
      seedOnRefresh: true,
    );
    final container = containerFor(repository);

    final resolution = await container.read(
      carbRecommendationResolutionProvider('Rice').future,
    );

    expect(resolution?.title, 'Rice');
    expect(resolution?.component.carbG, 45.0);
    expect(repository.refreshCalls, 0);
  });

  test('exactOnly: the exact pass alone misses a sibling-only mirror and hits '
      'the real row once seeded', () async {
    await seedMirror(wireRowsWithoutRice, seedOnRefresh: false);
    expect(
      await resolveCarbRecommendation(db, 'Rice', exactOnly: true),
      isNull,
    );
    expect(
      (await resolveCarbRecommendation(db, 'Rice'))?.title,
      'Rice pudding',
    );

    await seedMirror(wireFoodRowsPostSeed, seedOnRefresh: false);
    expect(
      (await resolveCarbRecommendation(db, 'Rice', exactOnly: true))?.title,
      'Rice',
    );
  });

  test('refreshAfterMiss is throttled per instance and fails closed', () async {
    // A real FoodRepository against a Supabase mock that cannot be
    // reached: the fetch throws, the mirror is untouched, result false.
    final supabase = MockSupabaseClient();
    when(() => supabase.from(any())).thenThrow(Exception('offline'));
    final repository = FoodRepository(supabase, db, report: report);
    await repository.syncFoodsToLocalDatabase(wireRowsWithoutRice);
    final before = await db.select(db.foodsTable).get();

    expect(await repository.refreshAfterMiss(userId), isFalse);
    verify(() => supabase.from('foods')).called(1);

    // Second call inside the window never reaches the network.
    expect(await repository.refreshAfterMiss(userId), isFalse);
    verifyNever(() => supabase.from(any()));

    final after = await db.select(db.foodsTable).get();
    expect(
      after.length,
      before.length,
      reason: 'a failed fetch must leave the existing mirror intact',
    );
  });
}

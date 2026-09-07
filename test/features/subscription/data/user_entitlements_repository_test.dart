/// Unit tests for [UserEntitlementsRepository] — the pure row → status rule
/// (mirrors `has_entitlement()`), and the Drift cache read/clear path against
/// an in-memory database. The Supabase read is exercised on device / by the
/// webhook tests; here the client is a mock that is never reached.
library;

import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _FakeLogger extends Fake implements AppLogger {
  @override
  void info(String message, {String? context, Map<String, dynamic>? data}) {}

  @override
  void warning(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {}

  @override
  void error(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {}
}

final _now = DateTime.utc(2026, 9, 1, 12);

void main() {
  group('statusFromRow', () {
    test('active + future expiry → active server status', () {
      final s = UserEntitlementsRepository.statusFromRow(
        active: true,
        expiresAt: _now.add(const Duration(days: 30)),
        periodType: 'NORMAL',
        productId: 'mealvana_pro_annual',
        now: _now,
      );
      expect(s.active, isTrue);
      expect(s.source, SubscriptionSource.server);
      expect(s.isTrial, isFalse);
      expect(s.productId, 'mealvana_pro_annual');
    });

    test('active + past expiry → none (expiry wins, like has_entitlement)', () {
      final s = UserEntitlementsRepository.statusFromRow(
        active: true,
        expiresAt: _now.subtract(const Duration(minutes: 1)),
        periodType: 'NORMAL',
        productId: null,
        now: _now,
      );
      expect(s, SubscriptionStatus.none);
    });

    test('inactive row → none regardless of expiry', () {
      final s = UserEntitlementsRepository.statusFromRow(
        active: false,
        expiresAt: _now.add(const Duration(days: 30)),
        periodType: null,
        productId: null,
        now: _now,
      );
      expect(s, SubscriptionStatus.none);
    });

    test('null expiry is open-ended (promo / internal grants)', () {
      final s = UserEntitlementsRepository.statusFromRow(
        active: true,
        expiresAt: null,
        periodType: null,
        productId: null,
        now: _now,
      );
      expect(s.active, isTrue);
      expect(s.expiresAt, isNull);
    });

    test('TRIAL / INTRO period types flag isTrial (case-insensitive)', () {
      for (final p in ['TRIAL', 'trial', 'INTRO']) {
        expect(
          UserEntitlementsRepository.statusFromRow(
            active: true,
            expiresAt: null,
            periodType: p,
            productId: null,
            now: _now,
          ).isTrial,
          isTrue,
          reason: p,
        );
      }
    });
  });

  group('Drift cache', () {
    late AppDatabase db;
    late UserEntitlementsRepository repo;

    setUp(() {
      db = AppDatabase.memory();
      repo = UserEntitlementsRepository(
        supabase: _MockSupabaseClient(),
        database: db,
        logger: _FakeLogger(),
      );
    });

    tearDown(() => db.close());

    Future<void> seed({required bool active, DateTime? expiresAt}) {
      return db
          .into(db.userEntitlementsTable)
          .insert(
            UserEntitlementsTableCompanion.insert(
              userId: 'user-1',
              entitlement: 'pro',
              active: Value(active),
              expiresAt: Value(expiresAt),
              periodType: const Value('TRIAL'),
              updatedAt: _now,
              fetchedAt: _now,
            ),
          );
    }

    test('readCached: nothing cached → null', () async {
      expect(await repo.readCached('user-1', Entitlement.pro), isNull);
    });

    test('readCached: active unexpired row → active server status', () async {
      await seed(active: true, expiresAt: _now.add(const Duration(days: 7)));
      final s = await repo.readCached('user-1', Entitlement.pro, now: _now);
      expect(s, isNotNull);
      expect(s!.active, isTrue);
      expect(s.source, SubscriptionSource.server);
      expect(s.isTrial, isTrue);
    });

    test('readCached: cached row past its expiry → none', () async {
      await seed(
        active: true,
        expiresAt: _now.subtract(const Duration(days: 1)),
      );
      expect(
        await repo.readCached('user-1', Entitlement.pro, now: _now),
        SubscriptionStatus.none,
      );
    });

    test('readCached is scoped to the user', () async {
      await seed(active: true);
      expect(await repo.readCached('someone-else', Entitlement.pro), isNull);
    });

    test('clearCache removes every row', () async {
      await seed(active: true);
      await repo.clearCache();
      expect(await db.select(db.userEntitlementsTable).get(), isEmpty);
    });

    test(
      'mirrorInternalFlag updates users.is_internal for that user',
      () async {
        final client = _MockSupabaseClient();
        final qb = _MockQueryBuilder();
        final fb = _MockFilterBuilder();
        when(() => client.from('users')).thenAnswer((_) => qb);
        when(() => qb.update(any())).thenAnswer((_) => fb);
        when(() => fb.eq('id', 'user-1')).thenAnswer((_) => fb);
        final r = UserEntitlementsRepository(
          supabase: client,
          database: db,
          logger: _FakeLogger(),
        );

        expect(await r.mirrorInternalFlag('user-1', true), isTrue);
        verify(() => qb.update({'is_internal': true})).called(1);
        verify(() => fb.eq('id', 'user-1')).called(1);

        expect(await r.mirrorInternalFlag('user-1', false), isTrue);
        verify(() => qb.update({'is_internal': false})).called(1);
      },
    );

    test(
      'mirrorInternalFlag returns false (never throws) on failure',
      () async {
        final client = _MockSupabaseClient();
        when(() => client.from('users')).thenThrow(Exception('offline'));
        final r = UserEntitlementsRepository(
          supabase: client,
          database: db,
          logger: _FakeLogger(),
        );
        expect(await r.mirrorInternalFlag('user-1', true), isFalse);
      },
    );

    test('currentUserId / isAnonymousUser read the live session', () {
      final client = _MockSupabaseClient();
      final auth = _MockGoTrue();
      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(null);
      final r = UserEntitlementsRepository(
        supabase: client,
        database: db,
        logger: _FakeLogger(),
      );
      expect(r.currentUserId, isNull);
      expect(r.isAnonymousUser, isFalse);
    });
  });
}

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

/// An awaitable stand-in for the `update().eq()` chain: PostgrestFilterBuilder
/// IS a Future, so completing `then` is what makes `await` return.
class _MockFilterBuilder extends Mock
    implements PostgrestFilterBuilder<dynamic> {
  @override
  Future<R> then<R>(
    FutureOr<R> Function(dynamic value) onValue, {
    Function? onError,
  }) async => onValue(null);
}

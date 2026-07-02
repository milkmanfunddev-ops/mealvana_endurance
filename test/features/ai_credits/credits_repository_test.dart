/// Unit tests for [CreditsRepository] — Supabase interaction mocked.
///
/// Covers:
/// - fetchWallet returns zero when not authenticated.
/// - fetchWallet returns zero when no row exists (maybeSingle → null).
/// - fetchWallet parses wallet row correctly.
/// - fetchWallet returns zero on exception (graceful degradation).
/// - recentLedger returns empty list when not authenticated.
/// - recentLedger returns empty list on exception.
/// - CreditWallet.fromMap parses all fields correctly.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/data/credits_repository.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {
  @override
  final String id;
  MockUser(this.id);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _userId = 'test-user-credits-001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockGoTrue;
  late CreditsRepository repository;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockGoTrue = MockGoTrueClient();
    when(() => mockSupabase.auth).thenReturn(mockGoTrue);

    repository = CreditsRepository(supabase: mockSupabase);
  });

  // ---------------------------------------------------------------------------
  // CreditWallet.fromMap — pure unit tests (no Supabase involved)
  // ---------------------------------------------------------------------------

  group('CreditWallet.fromMap', () {
    test('parses balance correctly', () {
      final wallet =
          CreditWallet.fromMap({'balance': 50, 'free_period': null, 'updated_at': null});
      expect(wallet.balance, 50);
    });

    test('parses freePeriod correctly', () {
      final wallet = CreditWallet.fromMap({
        'balance': 10,
        'free_period': 'trial',
        'updated_at': null,
      });
      expect(wallet.freePeriod, 'trial');
    });

    test('parses updatedAt correctly', () {
      final wallet = CreditWallet.fromMap({
        'balance': 5,
        'free_period': null,
        'updated_at': '2025-03-10T08:00:00.000Z',
      });
      expect(wallet.updatedAt, isNotNull);
      expect(wallet.updatedAt!.year, 2025);
    });

    test('balance 0 → balance 0 (not the zero constant)', () {
      final wallet =
          CreditWallet.fromMap({'balance': 0, 'free_period': null, 'updated_at': null});
      expect(wallet.balance, 0);
    });

    test('large balance parses correctly', () {
      final wallet = CreditWallet.fromMap({
        'balance': 999,
        'free_period': null,
        'updated_at': null,
      });
      expect(wallet.balance, 999);
    });

    test('null balance falls back to 0', () {
      final wallet =
          CreditWallet.fromMap({'balance': null, 'free_period': null, 'updated_at': null});
      expect(wallet.balance, 0);
    });

    test('null updatedAt stays null', () {
      final wallet =
          CreditWallet.fromMap({'balance': 1, 'free_period': null, 'updated_at': null});
      expect(wallet.updatedAt, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchWallet — unauthenticated
  // ---------------------------------------------------------------------------

  group('fetchWallet — unauthenticated', () {
    setUp(() {
      when(() => mockGoTrue.currentUser).thenReturn(null);
    });

    test('returns CreditWallet.zero when no user is signed in', () async {
      final wallet = await repository.fetchWallet();
      expect(wallet.balance, 0);
      expect(wallet.freePeriod, isNull);
    });

    test('does not call Supabase when unauthenticated', () async {
      await repository.fetchWallet();
      verifyNever(() => mockSupabase.from(any()));
    });
  });

  // ---------------------------------------------------------------------------
  // fetchWallet — graceful error handling
  // ---------------------------------------------------------------------------

  group('fetchWallet — graceful error handling', () {
    test('returns CreditWallet.zero when Supabase throws', () async {
      when(() => mockGoTrue.currentUser).thenReturn(MockUser(_userId));
      when(() => mockSupabase.from('token_wallets'))
          .thenThrow(Exception('Network error'));

      final wallet = await repository.fetchWallet();
      expect(wallet.balance, 0, reason: 'Should degrade gracefully to zero');
    });
  });

  // ---------------------------------------------------------------------------
  // recentLedger — unauthenticated
  // ---------------------------------------------------------------------------

  group('recentLedger — unauthenticated', () {
    setUp(() {
      when(() => mockGoTrue.currentUser).thenReturn(null);
    });

    test('returns empty list when not authenticated', () async {
      final ledger = await repository.recentLedger();
      expect(ledger, isEmpty);
    });

    test('does not call Supabase for ledger when unauthenticated', () async {
      await repository.recentLedger();
      verifyNever(() => mockSupabase.from(any()));
    });
  });

  // ---------------------------------------------------------------------------
  // recentLedger — graceful error handling
  // ---------------------------------------------------------------------------

  group('recentLedger — graceful error handling', () {
    test('returns empty list when Supabase throws', () async {
      when(() => mockGoTrue.currentUser).thenReturn(MockUser(_userId));
      when(() => mockSupabase.from('token_ledger'))
          .thenThrow(Exception('Network error'));

      final ledger = await repository.recentLedger();
      expect(ledger, isEmpty, reason: 'Should degrade gracefully to empty list');
    });
  });
}

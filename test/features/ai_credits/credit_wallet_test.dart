/// Unit tests for [CreditWallet] and [InsufficientCreditsException] — pure
/// domain logic with no Supabase or Riverpod dependencies.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/insufficient_credits_exception.dart';

void main() {
  // ---------------------------------------------------------------------------
  // CreditWallet
  // ---------------------------------------------------------------------------

  group('CreditWallet — zero constant', () {
    test('CreditWallet.zero has balance 0', () {
      expect(CreditWallet.zero.balance, 0);
    });

    test('CreditWallet.zero has null freePeriod', () {
      expect(CreditWallet.zero.freePeriod, isNull);
    });

    test('CreditWallet.zero has null updatedAt', () {
      expect(CreditWallet.zero.updatedAt, isNull);
    });
  });

  group('CreditWallet.fromMap — parsing', () {
    test('parses balance as int from int', () {
      final w = CreditWallet.fromMap({'balance': 42});
      expect(w.balance, 42);
    });

    test('parses balance as int from double', () {
      final w = CreditWallet.fromMap({'balance': 42.0});
      expect(w.balance, 42);
    });

    test('missing balance defaults to 0', () {
      final w = CreditWallet.fromMap({});
      expect(w.balance, 0);
    });

    test('null balance defaults to 0', () {
      final w = CreditWallet.fromMap({'balance': null});
      expect(w.balance, 0);
    });

    test('parses freePeriod string', () {
      final w = CreditWallet.fromMap({'balance': 10, 'free_period': 'trial'});
      expect(w.freePeriod, 'trial');
    });

    test('null free_period stays null', () {
      final w = CreditWallet.fromMap({'balance': 10, 'free_period': null});
      expect(w.freePeriod, isNull);
    });

    test('missing free_period stays null', () {
      final w = CreditWallet.fromMap({'balance': 10});
      expect(w.freePeriod, isNull);
    });

    test('parses updatedAt from ISO8601 string', () {
      final w = CreditWallet.fromMap({
        'balance': 5,
        'updated_at': '2025-01-15T10:00:00.000Z',
      });
      expect(w.updatedAt, isNotNull);
      expect(w.updatedAt!.year, 2025);
      expect(w.updatedAt!.month, 1);
      expect(w.updatedAt!.day, 15);
    });

    test('invalid updated_at string results in null (DateTime.tryParse)', () {
      final w = CreditWallet.fromMap({
        'balance': 5,
        'updated_at': 'not-a-date',
      });
      expect(w.updatedAt, isNull);
    });

    test('null updated_at stays null', () {
      final w = CreditWallet.fromMap({'balance': 5, 'updated_at': null});
      expect(w.updatedAt, isNull);
    });

    test('large balance parses correctly', () {
      final w = CreditWallet.fromMap({'balance': 1000000});
      expect(w.balance, 1000000);
    });

    test('balance 0 parses as 0 (not treated as missing)', () {
      final w = CreditWallet.fromMap({'balance': 0});
      expect(w.balance, 0);
    });
  });

  group('CreditWallet — balance semantics', () {
    test('positive balance is accessible', () {
      const w = CreditWallet(balance: 100);
      expect(w.balance, 100);
    });

    test('toString includes balance and freePeriod', () {
      const w = CreditWallet(balance: 25, freePeriod: 'trial');
      final s = w.toString();
      expect(s, contains('25'));
      expect(s, contains('trial'));
    });
  });

  // ---------------------------------------------------------------------------
  // InsufficientCreditsException
  // ---------------------------------------------------------------------------

  group('InsufficientCreditsException — parsing', () {
    test('fromMap parses all fields', () {
      final ex = InsufficientCreditsException.fromMap({
        'balance': 3,
        'cost': 10,
        'message': 'Not enough credits.',
      });
      expect(ex.balance, 3);
      expect(ex.cost, 10);
      expect(ex.message, 'Not enough credits.');
    });

    test('fromMap with missing balance defaults to 0', () {
      final ex = InsufficientCreditsException.fromMap({
        'cost': 5,
        'message': 'Insufficient',
      });
      expect(ex.balance, 0);
    });

    test('fromMap with missing cost defaults to 0', () {
      final ex = InsufficientCreditsException.fromMap({
        'balance': 2,
        'message': 'Insufficient',
      });
      expect(ex.cost, 0);
    });

    test('fromMap with null message defaults to fallback string', () {
      final ex = InsufficientCreditsException.fromMap({
        'balance': 0,
        'cost': 5,
        'message': null,
      });
      expect(ex.message, isNotEmpty);
    });

    test('fromMap with missing message defaults to fallback string', () {
      final ex = InsufficientCreditsException.fromMap({
        'balance': 0,
        'cost': 5,
      });
      expect(ex.message, 'Not enough AI credits.');
    });

    test('fromMap parses balance as int from double', () {
      final ex = InsufficientCreditsException.fromMap({
        'balance': 2.0,
        'cost': 10.0,
        'message': 'x',
      });
      expect(ex.balance, 2);
      expect(ex.cost, 10);
    });

    test('toString includes balance and cost', () {
      const ex = InsufficientCreditsException(
        balance: 3,
        cost: 10,
        message: 'Not enough credits',
      );
      final s = ex.toString();
      expect(s, contains('3'));
      expect(s, contains('10'));
    });

    test('implements Exception (can be caught as Exception)', () {
      const ex = InsufficientCreditsException(
        balance: 0,
        cost: 5,
        message: 'test',
      );
      expect(ex, isA<Exception>());
    });
  });

  // ---------------------------------------------------------------------------
  // Credit balance guard semantics (stateless, pure logic)
  // ---------------------------------------------------------------------------

  group('Credit guard logic', () {
    // These tests verify the guard idiom used across the app:
    // "if (wallet.balance < cost) throw InsufficientCreditsException(...);"
    // We test this pattern's correctness directly since CreditsRepository is
    // read-only and mutations happen server-side.

    bool _hasEnough(int balance, int cost) => balance >= cost;

    test('balance 10, cost 10 → sufficient', () {
      expect(_hasEnough(10, 10), isTrue);
    });

    test('balance 9, cost 10 → insufficient', () {
      expect(_hasEnough(9, 10), isFalse);
    });

    test('balance 0, cost 1 → insufficient', () {
      expect(_hasEnough(0, 1), isFalse);
    });

    test('balance 0, cost 0 → sufficient (zero-cost operation)', () {
      expect(_hasEnough(0, 0), isTrue);
    });

    test('balance 100, cost 1 → sufficient', () {
      expect(_hasEnough(100, 1), isTrue);
    });

    test('negative balance (server bug) would be caught', () {
      // Server guarantees non-negative, but guard still safe.
      expect(_hasEnough(-1, 1), isFalse);
    });

    test('exception carries correct remaining vs cost gap', () {
      const ex = InsufficientCreditsException(
        balance: 3,
        cost: 10,
        message: 'Insufficient credits',
      );
      final gap = ex.cost - ex.balance;
      expect(gap, 7, reason: 'User needs 7 more credits');
    });
  });
}

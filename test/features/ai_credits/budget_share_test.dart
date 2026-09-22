/// What the athlete may see of the monthly budget (mp-430 clause 8, mp-436
/// clause 3), derived from the server's own wallet row.
///
/// The cases mirror `budgetStatus` in
/// `supabase/functions/_shared/ai/allowance.ts` (its Deno test
/// `credits.test.ts`), because the two must never disagree: the app reads the
/// row through PostgREST and realtime as well as through `ensure-credits`.
/// The rows here are shaped as the server writes them — whole micro-dollars —
/// never as this code's own output.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/budget_share.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';

void main() {
  group('budgetShareOf', () {
    test('half a month spent, a quarter-month pack bought', () {
      final share = budgetShareOf(
        CreditWallet.fromMap(const {
          'balance': 3000000,
          'allowance': 2000000,
          'allowance_monthly': 4000000,
          'allowance_expires_at': '2026-10-15T12:00:00+00:00',
        }),
      );

      expect(share.shareUsed, 0.5);
      expect(share.boughtExtraShare, 0.25);
      expect(share.refillAt, DateTime.parse('2026-10-15T12:00:00+00:00'));
      expect(share.hasWindow, isTrue);
      expect(share.isSpent, isFalse);
    });

    test('no window open: nothing to say about a month, bought extra stands', () {
      final noGrant = budgetShareOf(
        CreditWallet.fromMap(const {
          'balance': 400000,
          'allowance': 0,
          'allowance_monthly': 0,
          'allowance_expires_at': null,
        }),
      );
      expect(noGrant.shareUsed, isNull);
      expect(noGrant.refillAt, isNull);
      expect(noGrant.boughtExtraShare, 0.1);

      // A grant size with no expiry is not an open window either.
      final noExpiry = budgetShareOf(
        CreditWallet.fromMap(const {
          'balance': 400000,
          'allowance': 0,
          'allowance_monthly': 4000000,
          'allowance_expires_at': null,
        }),
      );
      expect(noExpiry.shareUsed, isNull);
      expect(noExpiry.boughtExtraShare, 0.1);
    });

    test('an empty wallet inside an open window is the whole month used', () {
      final share = budgetShareOf(
        CreditWallet.fromMap(const {
          'balance': 0,
          'allowance': 0,
          'allowance_monthly': 4000000,
          'allowance_expires_at': '2026-10-15T12:00:00+00:00',
        }),
      );

      expect(share.shareUsed, 1);
      expect(share.boughtExtraShare, 0);
      expect(share.shareLeft, 0);
      expect(share.isSpent, isTrue);
    });

    test('a spent month with bought budget left is not spent', () {
      final share = budgetShareOf(
        CreditWallet.fromMap(const {
          'balance': 1000000,
          'allowance': 0,
          'allowance_monthly': 4000000,
          'allowance_expires_at': '2026-10-15T12:00:00+00:00',
        }),
      );

      expect(share.shareUsed, 1);
      expect(share.boughtExtraShare, 0.25);
      expect(share.isSpent, isFalse);
      expect(share.shareLeft, 0.25);
    });

    test('a fresh month is nothing used', () {
      final share = budgetShareOf(
        CreditWallet.fromMap(const {
          'balance': 4000000,
          'allowance': 4000000,
          'allowance_monthly': 4000000,
          'allowance_expires_at': '2026-10-15T12:00:00+00:00',
        }),
      );

      expect(share.shareUsed, 0);
      expect(share.boughtExtraShare, 0);
      expect(share.shareLeft, 1);
    });

    test('the trial week is a window of its own size', () {
      // The trial grants a quarter of a month; half of it spent is still
      // "half of this month's Vana" to the athlete.
      final share = budgetShareOf(
        CreditWallet.fromMap(const {
          'balance': 500000,
          'allowance': 500000,
          'allowance_monthly': 1000000,
          'allowance_expires_at': '2026-10-01T00:00:00+00:00',
        }),
      );

      expect(share.shareUsed, 0.5);
      expect(share.boughtExtraShare, 0);
    });

    test('an inconsistent row never shows a negative or a share above one', () {
      final share = budgetShareOf(
        CreditWallet.fromMap(const {
          'balance': -5,
          'allowance': 9000000,
          'allowance_monthly': 4000000,
          'allowance_expires_at': '2026-10-15T12:00:00+00:00',
        }),
      );

      expect(share.shareUsed, 0);
      expect(share.boughtExtraShare, 0);
    });
  });

  test('percentOf rounds a share to whole percent', () {
    expect(percentOf(0), 0);
    expect(percentOf(0.25), 25);
    expect(percentOf(1), 100);
    expect(percentOf(1.25), 125);
  });
}

/// Client↔server contract for AI credit packs.
///
/// Two maps have to agree about "how many credits does this SKU grant":
///   • `kCreditsByProductId` in `lib/features/ai_credits/domain/credit_packs.dart`
///     — display only, what the purchase sheet promises the user.
///   • `DEFAULT_PRODUCT_BUDGET` in `supabase/functions/_shared/ai/allowance.ts`
///     — authoritative, what the RevenueCat webhook's `grant_credits` writes to
///     the wallet, in micro-dollars since ai-cost ticket 09 (2 cents a credit).
///
/// When they drift, the user is charged and shown one number while the wallet
/// receives another — or, in the failure bf0b591f hit, the sheet advertises
/// SKUs (`tokens_50`, `tokens_200`) that exist in neither the store nor the
/// webhook, so every purchase grants zero credits.
///
/// This is a pure source-parsing test: no network, no RevenueCat SDK, no
/// Supabase. It runs in the ordinary unit lane and fails loudly the moment one
/// side is edited without the other.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_packs.dart';

/// Pulls the `DEFAULT_PRODUCT_BUDGET` map out of the shared allowance module
/// and converts it back to credits at the one rate the record fixes
/// (`MICRO_PER_CREDIT`, 2 cents a credit, mp-436 clause 2).
///
/// Since ai-cost ticket 09 the map holds micro-dollars, e.g.
/// ```ts
/// export const DEFAULT_PRODUCT_BUDGET: Record<string, number> = {
///   mealvana_credits_50: 1 * USD_MICRO,
///   mealvana_credits_test_1: MICRO_PER_CREDIT,
/// };
/// ```
/// Each value is a plain integer, `<int> * USD_MICRO`, or `MICRO_PER_CREDIT`;
/// the two constants are read from the same file.
Map<String, int> parseWebhookCreditMap(String source) {
  int constant(String name) {
    final m = RegExp('const $name\\s*=\\s*([0-9_]+)').firstMatch(source);
    expect(m, isNotNull, reason: 'Could not find `$name` in allowance.ts.');
    return int.parse(m!.group(1)!.replaceAll('_', ''));
  }

  final usdMicro = constant('USD_MICRO');
  final microPerCredit = constant('MICRO_PER_CREDIT');

  final binding = RegExp(
    r'DEFAULT_PRODUCT_BUDGET[^=]*=\s*\{([^}]*)\}',
    dotAll: true,
  ).firstMatch(source);

  expect(
    binding,
    isNotNull,
    reason:
        'Could not find a DEFAULT_PRODUCT_BUDGET object literal in '
        'allowance.ts. If it was renamed, update this parser — do not delete '
        'the test: it is the only thing keeping the grant map and the '
        'purchase sheet in step.',
  );

  final body = binding!.group(1)!;
  final entry = RegExp(r'''["']?([A-Za-z0-9_]+)["']?\s*:\s*([^,\n]+)''');

  int micro(String expr) {
    final e = expr.trim();
    final times = RegExp(r'^(\d+)\s*\*\s*USD_MICRO$').firstMatch(e);
    if (times != null) return int.parse(times.group(1)!) * usdMicro;
    if (e == 'MICRO_PER_CREDIT') return microPerCredit;
    return int.parse(e.replaceAll('_', ''));
  }

  final parsed = <String, int>{};
  for (final m in entry.allMatches(body)) {
    final value = micro(m.group(2)!);
    expect(
      value % microPerCredit,
      0,
      reason:
          'SKU "${m.group(1)}" grants $value micro-dollars, which is not a '
          'whole number of credits at $microPerCredit each.',
    );
    parsed[m.group(1)!] = value ~/ microPerCredit;
  }
  return parsed;
}

void main() {
  final webhookFile = File('supabase/functions/_shared/ai/allowance.ts');

  group('credit pack contract', () {
    late Map<String, int> serverMap;

    setUpAll(() {
      expect(
        webhookFile.existsSync(),
        isTrue,
        reason:
            'Expected the allowance module at ${webhookFile.path}. Tests run '
            'from the repo root.',
      );
      serverMap = parseWebhookCreditMap(webhookFile.readAsStringSync());
    });

    test('the webhook actually declares some credit packs', () {
      expect(
        serverMap,
        isNotEmpty,
        reason: 'Parsed an empty grant map — the parser is probably stale.',
      );
    });

    test('every client-advertised SKU is granted by the webhook', () {
      for (final entry in kCreditsByProductId.entries) {
        expect(
          serverMap.containsKey(entry.key),
          isTrue,
          reason:
              'The purchase sheet advertises "${entry.key}" but the webhook '
              'has no mapping for it, so buying it would grant 0 credits.',
        );
      }
    });

    test('every webhook SKU is known to the client', () {
      for (final id in serverMap.keys) {
        expect(
          kCreditsByProductId.containsKey(id),
          isTrue,
          reason:
              'The webhook grants credits for "$id" but the client does not '
              'list it, so the sheet cannot show its credit count.',
        );
      }
    });

    test('the credit amounts agree exactly', () {
      for (final entry in kCreditsByProductId.entries) {
        expect(
          serverMap[entry.key],
          entry.value,
          reason:
              'SKU "${entry.key}": the sheet promises ${entry.value} credits '
              'but the webhook grants ${serverMap[entry.key]}.',
        );
      }
    });

    test('no SKU grants a non-positive number of credits', () {
      // The webhook bails on `!credits || credits <= 0`, so a zero here is a
      // silently dead product rather than a loud failure.
      for (final entry in serverMap.entries) {
        expect(
          entry.value,
          greaterThan(0),
          reason: 'SKU "${entry.key}" would be rejected by the webhook guard.',
        );
      }
    });
  });

  group('creditsForProductId', () {
    test('resolves every known pack', () {
      for (final entry in kCreditsByProductId.entries) {
        expect(creditsForProductId(entry.key), entry.value);
      }
    });

    test('returns null for a SKU this build has never heard of', () {
      // Deliberate: a pack added to the store after this version shipped must
      // fall back to the store's own title rather than inventing a count.
      expect(creditsForProductId('mealvana_credits_999999'), isNull);
      expect(creditsForProductId(''), isNull);
    });

    test('does not resolve the dead ids the old sheet hardcoded', () {
      // bf0b591f: these existed in neither RevenueCat nor the webhook.
      expect(creditsForProductId('tokens_50'), isNull);
      expect(creditsForProductId('tokens_200'), isNull);
    });
  });
}

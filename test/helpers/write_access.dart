/// Write-access overrides for controller tests (mp-457 §4, ticket 12).
///
/// Every write controller asks `ref.canWrite()` before writing, so a
/// controller test needs an answer: [writesAllowed] for the usual open
/// account, [writesRefused] plus a [PaywallOpens] to prove a lapsed account
/// gets the paywall and no write.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/src/internals.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/features/subscription/application/write_guard.dart';
import 'package:mealvana_endurance/features/subscription/domain/write_access_denied.dart';

/// The account may write (the gate is open).
Override writesAllowed() => writeAccessProvider.overrideWith((_) async => true);

/// The account may not write (lapsed, or never).
Override writesRefused() =>
    writeAccessProvider.overrideWith((_) async => false);

/// Counts how many times a refused write asked for the paywall. Add
/// [override] to the container; read [count] after the write.
class PaywallOpens {
  int count = 0;

  late final Override override = paywallOpenerProvider.overrideWithValue(
    () => count++,
  );
}

/// One write path on a lapsed account, through the real notifier: [call]
/// returns without writing (a void path) or throws [WriteAccessDenied] (a
/// path that must answer with a value), and the paywall was asked for
/// exactly once. Pair it with dependency overrides that throw on
/// construction, so a write that slipped past the guard fails loudly.
Future<void> expectWriteRefused(
  PaywallOpens opens,
  Future<Object?> Function() call,
) async {
  try {
    await call();
  } on WriteAccessDenied {
    // the value path's refusal
  }
  expect(opens.count, 1, reason: 'the paywall opens once per refused write');
}

/// A dependency a refused write must never reach: constructing it fails the
/// test. Use as `fooProvider.overrideWith(untouched('foo'))`.
Never Function(Ref) untouched(String name) =>
    (_) => throw StateError('$name was touched by a refused write');

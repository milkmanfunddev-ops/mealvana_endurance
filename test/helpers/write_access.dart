/// Write-access overrides for controller tests (mp-457 §4, ticket 12).
///
/// Every write controller asks `ref.canWrite()` before writing, so a
/// controller test needs an answer: [writesAllowed] for the usual open
/// account, [writesRefused] plus a [PaywallOpens] to prove a lapsed account
/// gets the paywall and no write.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/src/internals.dart' show Override;
import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/features/subscription/application/write_guard.dart';

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

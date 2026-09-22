/// The write guard (mp-457 §4, mp-491): every write controller asks
/// [WriteGuard.canWrite] before writing. An open account writes as before;
/// a lapsed account (or an unresolved gate, which is locked) gets the
/// paywall pushed over its read-only screen and nothing is written or queued.
///
/// Boundary: this guards the athlete's own data, coach-on-athlete data and
/// AI calls. Account plumbing the paywall itself relies on stays outside it:
/// sign-in and sign-out, account deletion, startup, purchase and restore,
/// the entitlement refresh, and the upload of rows already queued.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/write_access_denied.dart';
import 'pro_gate.dart';

/// Refused writes asking for the paywall, counted. A controller has no
/// navigator and must not reach for one (FOA: application never navigates),
/// so it records the request here; `PlanEndedHost`, which sits above the
/// router's Navigator, listens and pushes the paywall over the screen.
final paywallRequestsProvider = NotifierProvider<PaywallRequests, int>(
  PaywallRequests.new,
);

class PaywallRequests extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

/// The one way a refused write asks for the paywall. A provider so a
/// controller test can count the opens without a widget tree; the app never
/// overrides it.
final paywallOpenerProvider = Provider<void Function()>(
  (ref) => ref.read(paywallRequestsProvider.notifier).request,
);

extension WriteGuard on Ref {
  /// Whether this account may write right now (`writeAccessProvider`). True:
  /// go ahead. False: the paywall has been opened, so return without writing.
  ///
  /// A settled gate (the app's steady state) answers without waiting on a
  /// future, so an optimistic update lands one microtask after the call, as
  /// it did before the guard. An unresolved gate waits for its bounded
  /// answer, so a write during startup resolves once the gate does rather
  /// than slipping past.
  Future<bool> canWrite() async {
    final settled = read(writeAccessProvider);
    final allowed = settled.hasValue && !settled.isLoading
        ? settled.value!
        : await read(writeAccessProvider.future);
    if (allowed) return true;
    read(paywallOpenerProvider)();
    return false;
  }
}

/// [WriteGuard.canWrite] for a method that must answer with a value and so
/// cannot return quietly: opens the paywall, then throws [WriteAccessDenied].
Future<void> requireWriteAccess(Ref ref) async {
  if (!await ref.canWrite()) throw const WriteAccessDenied();
}

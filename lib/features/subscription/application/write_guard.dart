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

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../main.dart' show sentryNavigatorKey;
import '../domain/write_access_denied.dart';
import 'paywall_location.dart';
import 'pro_gate.dart';

/// The one way a refused write opens the paywall. A provider so a controller
/// test can count the opens without a widget tree; the app never overrides
/// it.
final paywallOpenerProvider = Provider<void Function()>((_) => openPaywall);

/// Push the paywall over the current screen (mp-457 §3: an edit or AI
/// action opens the paywall instead of running).
///
/// [context] is the caller's when it has one (a screen); a controller has
/// none and falls back to the app router's navigator ([sentryNavigatorKey]),
/// the same fallback the credits sheet uses. No navigator (a unit test, or
/// nothing mounted yet) means nothing to push over, so this returns. A
/// paywall already on top is left alone: a double tap, or two writes from
/// one gesture, must not stack a second one.
void openPaywall({BuildContext? context}) {
  final GoRouter router;
  try {
    final ctx = context ?? sentryNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    router = GoRouter.of(ctx);
  } catch (_) {
    return; // no navigator, or no router above this context (a test host)
  }
  if (topPathOf(router.routerDelegate.currentConfiguration) == kPaywallPath) {
    return;
  }
  unawaited(router.push(kPaywallPath));
}

extension WriteGuard on Ref {
  /// Whether this account may write right now (`writeAccessProvider`). True:
  /// go ahead. False: the paywall has been opened, so return without writing.
  ///
  /// The write-access rule waits for the gate's bounded answer, so a write
  /// during startup resolves once the gate does rather than slipping past.
  Future<bool> canWrite() async {
    if (await read(writeAccessProvider.future)) return true;
    read(paywallOpenerProvider)();
    return false;
  }
}

/// [WriteGuard.canWrite] for a method that must answer with a value and so
/// cannot return quietly: opens the paywall, then throws [WriteAccessDenied].
Future<void> requireWriteAccess(Ref ref) async {
  if (!await ref.canWrite()) throw const WriteAccessDenied();
}

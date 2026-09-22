/// Push the paywall over the current screen (mp-457 §3: an edit or AI
/// action opens the paywall instead of running).
///
/// Screens call it with their router; a refused write in a controller asks
/// through `paywallRequestsProvider` instead, and `PlanEndedHost` calls this
/// on its behalf. A paywall already on top is left alone: a double tap, or
/// two writes from one gesture, must not stack a second one.
library;

import 'dart:async';

import 'package:go_router/go_router.dart';

import 'pro_gate_redirect.dart';

void openPaywall(GoRouter router) {
  if (topPathOf(router.routerDelegate.currentConfiguration) == kPaywallPath) {
    return;
  }
  unawaited(router.push(kPaywallPath));
}

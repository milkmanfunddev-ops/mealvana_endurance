/// Send the app to the paywall (mp-457 §3: an edit or AI action on a closed
/// account opens the paywall instead of running).
///
/// The paywall takes the whole app, not a sheet over the screen (mp-280,
/// mp-611): it replaces the navigation stack, so there is nothing under it
/// to go back to, just as when the gate's redirect lands a closed account
/// there. Screens call it with their router. A paywall already on top is
/// left alone.
library;

import 'package:go_router/go_router.dart';

import 'pro_gate_redirect.dart';

void openPaywall(GoRouter router) {
  if (topPathOf(router.routerDelegate.currentConfiguration) == kPaywallPath) {
    return;
  }
  router.go(kPaywallPath);
}

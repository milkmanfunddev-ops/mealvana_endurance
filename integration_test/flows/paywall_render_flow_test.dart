/// Pro/paywall render flow under **Patrol** — open the `/pro` screen and
/// verify it renders its plan widgets without crashing. NO purchase button is
/// ever tapped (the three subscription buttons are currently disabled
/// placeholders anyway — pricing is "Coming Soon", RevenueCat offerings are
/// not wired into this screen).
///
/// Entry point: there is currently NO in-UI entry that pushes '/pro' (the
/// route exists in app_router.dart but nothing navigates to it — verified by
/// grep across lib/). The buy-credits paywall (`/buy-credits`) is gated by
/// describeMealEnabled and only reachable via 402 paywall flows from real AI
/// spend, so it is not a reliable render target either. This flow therefore
/// drives the app's own GoRouter to push '/pro' — exactly what a future entry
/// point (settings row / feature-gate CTA) will do.
///
/// Flow:
///   launchApp → ensureAuthenticated (reuse session, else email login)
///     → GoRouter.push('/pro')
///     → screen renders (pro_version.screen + pro_version.title)
///     → scroll down to the pricing card (pro_version.pricing_card) and
///       assert the three plan buttons exist (Monthly/Annual/Lifetime)
///     → close (pro_version.close_button) → back on the tabs shell.
///
/// Auth: reuses an existing session, else the flavor-matched
/// INTEGRATION_TEST creds; self-skips when neither is available.
///
/// Run:
///   patrol test --target integration_test/flows/paywall_render_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';

void main() {
  patrolTest(
    'pro screen renders its plan widgets without crashing (no purchases)',
    ($) async {
      await launchApp();
      // No pumpAndSettle: startup may show persistent spinners.
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // ---- 1. Navigate to /pro via the app's router ------------------------
      // No UI entry point pushes '/pro' today (documented in the header), so
      // drive the router directly — same navigation a real entry would do.
      final context = $.tester.element(find.byKey(authSentinel).first);
      GoRouter.of(context).push('/pro');
      await $.pump(const Duration(milliseconds: 600));

      await $(
        const ValueKey('pro_version.title'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      expect(
        $(const ValueKey('pro_version.screen')),
        findsOneWidget,
        reason: 'ProVersionScreen scaffold should build without crashing.',
      );

      // ---- 2. Scroll to the pricing/plan section ---------------------------
      // Static screen (no async spinners), so scrollTo is safe here.
      await $(const ValueKey('pro_version.pricing_card')).scrollTo();
      await $.pump(const Duration(milliseconds: 300));

      expect(
        $(const ValueKey('pro_version.pricing_card')),
        findsOneWidget,
        reason: 'Pricing card should render on the Pro screen.',
      );
      // The three plan placeholders — asserted by label, NEVER tapped.
      expect($('Monthly Subscription'), findsOneWidget);
      expect($('Annual Subscription'), findsOneWidget);
      expect($('Lifetime Access'), findsOneWidget);

      // ---- 3. Close and land back on the tabs shell -------------------------
      await $(
        const ValueKey('pro_version.close_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        authSentinel,
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      expect($(authSentinel), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

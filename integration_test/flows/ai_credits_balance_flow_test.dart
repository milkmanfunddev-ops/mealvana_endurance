/// AI credits (token) surface under **Patrol** — balance pill → top-up sheet.
///
/// SPENDS NOTHING, BY CONSTRUCTION. This flow never taps `tokens.buy` and never
/// triggers an AI analysis. Both are real money: a purchase hits StoreKit, and
/// an analysis burns a token against the metered edge function. The flow asserts
/// the sheet RESOLVES and then leaves. If you extend it, keep that boundary —
/// `tokens.buy` is asserted-present, never tapped.
///
/// What this actually guards: `visibleCreditPackagesProvider` resolving to a
/// terminal state. The sheet has three of them — packs, `tokens.unavailable`
/// (no offering / empty offering / fetch error), and `tokens.error`. All three
/// are acceptable here; what is NOT acceptable is the sheet sitting on its
/// spinner forever, which is exactly what a hung RevenueCat fetch looks like to
/// a user and what no unit test observes.
///
/// This surface has a history of failing silently rather than loudly: packs were
/// once hardcoded under ids that matched nothing provisioned, so the buy button
/// was permanently inert; and `aiCreditsEnabled` kept a hard `false` fallback
/// that made the pill and the whole paywall invisible in Codemagic-built dev
/// apps. Both were invisible-by-default bugs. A flow that just proves the pill
/// exists and its sheet resolves would have caught each of them.
///
/// Flow:
///   launchApp → ensureAuthenticated
///     → Fuel Timeline → + Add Food (the pill rides beside the AI prompt here)
///     → tokens.balance_pill renders
///     → tap it → the top-up sheet resolves to packs OR unavailable OR error
///     → dismiss via the modal barrier, back to the add-food sheet
///     → close, back to the timeline.
///
/// `aiCreditsEnabled` defaults ON for dev builds, so the pill is present under
/// `--flavor dev`. If it is ever turned off for dev the flow self-skips with a
/// message naming the flag — note that the M1 workflow treats ANY skip as a
/// failure, which is the correct signal: a silently-disabled paywall is the bug.
///
/// Auth: reuses an existing session, else the flavor-matched INTEGRATION_TEST
/// creds; self-skips when neither is available.
///
/// Run:
///   patrol test --target integration_test/flows/ai_credits_balance_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';

void main() {
  patrolTest(
    'token pill opens the top-up sheet and it resolves — no purchase made',
    ($) async {
      await launchApp();
      // No pumpAndSettle: startup may show persistent spinners.
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // ---- 1. Fuel Timeline → + Add Food -----------------------------------
      await $(
        const ValueKey('bottom_nav.timeline_tab'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('fuel_timeline.add_food'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(
        const ValueKey('fuel_timeline.add_food'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      await $(
        const ValueKey('log_meal.back_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));

      // ---- 2. The balance pill ----------------------------------------------
      const pill = ValueKey('tokens.balance_pill');
      var pillFound = false;
      for (var i = 0; i < 20; i++) {
        if ($(pill).exists) {
          pillFound = true;
          break;
        }
        await $.pump(const Duration(milliseconds: 500));
      }
      if (!pillFound) {
        markTestSkipped(
          'tokens.balance_pill is absent — AI_CREDITS_ENABLED resolved false '
          'for this build. That is the exact condition that hid the paywall in '
          'Codemagic dev apps, so treat this skip as a finding, not as noise.',
        );
        return;
      }

      // ---- 3. Open the top-up sheet ------------------------------------------
      await $(pill).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 600));

      // Poll for ANY terminal state. The simulator usually has no StoreKit
      // configuration, so `tokens.unavailable` is the expected outcome there;
      // a device with a live `credits` offering renders packs instead. Both
      // pass. Only "still spinning after 25s" fails.
      const packs = ValueKey('packs');
      const unavailable = ValueKey('tokens.unavailable');
      const error = ValueKey('tokens.error');

      var resolved = false;
      for (var i = 0; i < 50; i++) {
        if ($(unavailable).exists || $(error).exists || $(packs).exists) {
          resolved = true;
          break;
        }
        await $.pump(const Duration(milliseconds: 500));
      }

      expect(
        resolved,
        isTrue,
        reason:
            'The top-up sheet never reached a terminal state within 25s — it '
            'is stuck on the packages spinner. To the user that is a dead '
            'sheet, which is how the inert-buy-button bug presented.',
      );

      // If packs DID resolve, the buy button must be there — its absence with
      // packs present is the inert-paywall regression. Present, not tapped:
      // tapping it would charge a real account.
      if ($(packs).exists && !$(unavailable).exists) {
        expect(
          $(const ValueKey('tokens.buy')),
          findsOneWidget,
          reason:
              'Packs resolved but no buy button — the paywall renders prices '
              'the user cannot act on.',
        );
      }

      // ---- 4. Dismiss WITHOUT buying ----------------------------------------
      // The sheet carries only a decorative drag handle, no close control, so
      // dismissal is the modal barrier. Tap near the top of the screen, well
      // above the sheet — deliberately nowhere near tokens.buy.
      final size = $.tester.view.physicalSize / $.tester.view.devicePixelRatio;
      await $.tester.tapAt(Offset(size.width / 2, 60));
      await $.pump(const Duration(milliseconds: 600));

      // ---- 5. Back to the timeline -------------------------------------------
      await $(
        const ValueKey('log_meal.back_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      await $(
        const ValueKey('log_meal.back_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('fuel_timeline.add_food'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

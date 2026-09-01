/// Mealvana AI coach chat flow under **Patrol** — open /jade, send one short
/// message, and verify a real assistant response arrives.
///
/// Entry point: the `/jade` route is feature-gated by
/// `appConfig.describeMealEnabled` (DESCRIBE_MEAL_ENABLED in the flavor's
/// dotenv) — the router redirect bounces /jade to '/' when the flag is off,
/// and the AiCoachBanner (the only in-UI entry, `ai_coach.coach_banner`) is not
/// currently mounted anywhere. So: tap the banner if it happens to exist,
/// otherwise push '/jade' through the app's GoRouter; if the chat screen
/// never appears the flag is off for this flavor and the test self-skips.
///
/// Flow:
///   PROD guard: markTestSkipped on prod (never burn prod AI spend)
///   launchApp → ensureAuthenticated (reuse session, else email login)
///     → open /jade (banner tap or router push)
///     → chat screen renders (ai_coach.chat_screen) — else skip
///     → count existing user/assistant bubbles
///     → type 'hi' (ai_coach.input_field) → send (ValueKey('send'))
///     → user bubble count grows (send committed)
///     → poll up to 60 s for the assistant bubble count to grow
///       (ai_coach.message_assistant_* — a REAL round-trip through the jade-chat
///        edge function, not just a button existing)
///     → back out of the chat.
///
/// Note: an empty conversation may trigger Mealvana AI's proactive opener, which
/// also adds an assistant message — the assertions are count-deltas on BOTH
/// roles, so the opener alone cannot green-light a failed send.
///
/// Run (dev only):
///   patrol test --target integration_test/flows/ai_coach_chat_flow_test.dart \
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
import '../helpers/test_config.dart';

Finder _bubbles(String rolePrefix) => find.byWidgetPredicate((w) {
  final key = w.key;
  return key is ValueKey<String> && key.value.startsWith(rolePrefix);
});

Finder _userBubbles() => _bubbles('ai_coach.message_user_');
Finder _assistantBubbles() => _bubbles('ai_coach.message_assistant_');

void main() {
  patrolTest(
    'AI coach chat — send a message and receive an assistant response',
    ($) async {
      if (TestConfig.isProd) {
        markTestSkipped(
          'Mealvana AI chat calls the jade-chat edge function on every send — '
          'skipped on prod to avoid burning real AI spend.',
        );
        return;
      }

      await launchApp();
      // No pumpAndSettle: startup may show persistent spinners.
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // ---- 1. Open /jade ----------------------------------------------------
      if ($(const ValueKey('ai_coach.coach_banner')).exists) {
        await $(
          const ValueKey('ai_coach.coach_banner'),
        ).tap(settlePolicy: SettlePolicy.noSettle);
      } else {
        // No banner mounted — drive the app's own router. The redirect still
        // applies, so a disabled flag bounces this push back to '/'.
        final context = $.tester.element(find.byKey(authSentinel).first);
        GoRouter.of(context).push('/jade');
      }
      await $.pump(const Duration(milliseconds: 400));

      var chatVisible = false;
      for (var i = 0; i < 30; i++) {
        await $.pump(const Duration(milliseconds: 500));
        if ($(const ValueKey('ai_coach.chat_screen')).exists) {
          chatVisible = true;
          break;
        }
      }
      if (!chatVisible) {
        markTestSkipped(
          'Mealvana AI entry not available in this flavor '
          '(describeMealEnabled is off — /jade redirected away).',
        );
        return;
      }

      // The input row renders outside the async history load, so it is
      // available as soon as the screen mounts.
      await $(
        const ValueKey('ai_coach.input_field'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // Give the history load a moment so the pre-send counts are stable
      // (bubbles only render once the controller reaches its data state).
      await $.pump(const Duration(seconds: 3));
      final userBefore = _userBubbles().evaluate().length;
      final assistantBefore = _assistantBubbles().evaluate().length;

      // ---- 2. Send 'hi' -------------------------------------------------------
      await $(
        const ValueKey('ai_coach.input_field'),
      ).enterText('hi', settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));
      await $(const ValueKey('send')).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 500));

      // The user bubble lands synchronously with the send.
      var userGrew = false;
      for (var i = 0; i < 20; i++) {
        await $.pump(const Duration(milliseconds: 500));
        if (_userBubbles().evaluate().length > userBefore) {
          userGrew = true;
          break;
        }
      }
      expect(
        userGrew,
        isTrue,
        reason: 'Sending should append a user bubble to the chat history.',
      );

      // ---- 3. Poll up to 60 s for an assistant response ----------------------
      var assistantGrew = false;
      for (var i = 0; i < 120; i++) {
        await $.pump(const Duration(milliseconds: 500));
        if (_assistantBubbles().evaluate().length > assistantBefore) {
          assistantGrew = true;
          break;
        }
      }
      expect(
        assistantGrew,
        isTrue,
        reason:
            'An assistant response bubble should arrive within 60 s of '
            'sending — the jade-chat round-trip failed or timed out.',
      );

      // ---- 4. Back out of the chat -------------------------------------------
      try {
        await $.tester.tap(find.byTooltip('Back').first);
        await $.pump(const Duration(milliseconds: 500));
      } catch (e) {
        // ignore: avoid_print
        print('ai_coach_chat back-navigation cleanup failed (non-fatal): $e');
      }
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

/// Pro gate under **Patrol** — the meal-planning surfaces (`/food`, `/vana`)
/// are behind the Pro entitlement, and this flow proves the gate is
/// *consistent* in whichever configuration the build under test has.
///
/// **Why it is written as an invariant rather than "the locked user sees the
/// paywall".** `PRO_GATE_ENABLED` is `false` on dev builds (codemagic forces
/// it), so on dev every athlete is unlocked and a test that demanded the
/// paywall would be red on every dev run — the only environment where Patrol
/// actually runs. What is worth pinning either way is that the tab and the
/// route agree:
///
///   * Food tab visible  → pushing `/food` renders the Food screen, and
///                          `/vana` renders the Vana chat.
///   * Food tab absent   → pushing `/food` lands on `/pro` instead,
///                          and so does `/vana`.
///
/// A gate that half-applies (tab hidden but the deep link still opens the
/// feature, or tab shown but the route bounces) fails here in both builds.
///
/// Flow:
///   launchApp → ensureAuthenticated
///     → read whether `bottom_nav.food_tab` exists
///     → router.push('/food'), assert food screen XOR pro screen accordingly
///     → back out, router.push('/vana'), same assertion
///
/// Provider-free (no Garmin/TP credentials), so it runs on iOS and Android.
///
/// Run:
///   patrol test --target integration_test/flows/pro_gate_flow_test.dart \
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

const _foodTab = ValueKey('bottom_nav.food_tab');
const _foodScreen = ValueKey('meal_planning.food_screen');
const _vanaScreen = ValueKey('meal_planning.vana_chat_screen');
const _proScreen = ValueKey('pro_version.screen');

/// Pushes [path] through the app's own GoRouter (the same redirect chain a
/// deep link takes) and pumps until one of [keys] shows up.
Future<ValueKey<String>?> _pushAndSettleOn(
  PatrolIntegrationTester $,
  String path,
  List<ValueKey<String>> keys, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final context = $.tester.element(find.byType(Navigator).first);
  GoRouter.of(context).push(path);

  final polls = timeout.inMilliseconds ~/ 500;
  for (var i = 0; i < polls; i++) {
    await $.pump(const Duration(milliseconds: 500));
    for (final key in keys) {
      if ($(key).exists) return key;
    }
  }
  return null;
}

/// Pops the pushed route through GoRouter. Patrol's `pressBack` is an
/// Android-only affordance and this suite runs on the iOS simulator too.
Future<void> _popRoute(PatrolIntegrationTester $) async {
  final context = $.tester.element(find.byType(Navigator).first);
  final router = GoRouter.of(context);
  if (router.canPop()) router.pop();
  await $.pump(const Duration(seconds: 1));
}

void main() {
  patrolTest(
    'Pro gate — the Food tab and the /food and /vana routes agree',
    ($) async {
      await launchApp();
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      final unlocked = $(_foodTab).exists;

      // ---- /food -------------------------------------------------------
      final foodLanding = await _pushAndSettleOn($, '/food', [
        _foodScreen,
        _proScreen,
      ]);
      expect(
        foodLanding,
        isNotNull,
        reason:
            '/food rendered neither the Food screen nor the paywall within 25 s',
      );
      expect(
        foodLanding,
        unlocked ? _foodScreen : _proScreen,
        reason: unlocked
            ? 'Food tab is visible, so /food must open the feature'
            : 'Food tab is hidden, so /food must redirect to $kProPaywallPathLabel',
      );

      await _popRoute($);

      // ---- /vana -------------------------------------------------------
      final vanaLanding = await _pushAndSettleOn($, '/vana?mode=general', [
        _vanaScreen,
        _proScreen,
      ]);
      expect(
        vanaLanding,
        isNotNull,
        reason:
            '/vana rendered neither the Vana chat nor the paywall within 25 s',
      );
      expect(
        vanaLanding,
        unlocked ? _vanaScreen : _proScreen,
        reason: unlocked
            ? 'Food tab is visible, so /vana must open the chat'
            : 'Food tab is hidden, so /vana must redirect to the paywall',
      );

      await _popRoute($);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

/// Kept as a literal so the failure message names the route without pulling
/// the app's routing constants into the test bundle.
const kProPaywallPathLabel = '/pro';

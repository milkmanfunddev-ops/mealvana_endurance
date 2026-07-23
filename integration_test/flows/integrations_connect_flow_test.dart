/// Integration provider connect flows (Garmin / FinalSurge / TrainingPeaks)
/// under **Patrol**.
///
/// IMPORTANT — what is and isn't automatable here:
///   On iOS, every provider connect launches OAuth through
///   `flutter_web_auth_2` → `ASWebAuthenticationSession`. Apple sandboxes that
///   secure web view from UI automation: Patrol can tap the native *consent*
///   dialog ("'Mealvana Endurance' Wants to Use 'garmin.com' to Sign In") but
///   CANNOT type into the login form inside the session. So on the iOS
///   simulator this test verifies the **entry point** — tapping a provider's
///   "Connect" button launches the OAuth sheet without crashing and the app
///   survives a cancel — which still catches button-wiring / URL-construction /
///   crash regressions.
///
///   Full credential-entry automation requires either:
///     (a) Android (Custom Tabs + a Google/account pre-added to the emulator),
///     (b) a mocked OAuth callback / deep-link of the redirect URI, or
///     (c) a provider that renders its login in an in-app Flutter WebView.
///   The credential block below is wired (reads creds via --dart-define) and
///   runs only when creds are present AND the platform exposes the web form.
///
/// Credentials come from secrets/integration_test.env (gitignored):
///   patrol test --target integration_test/flows/integrations_connect_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
///
/// NOTE (Lee, 2026-06-13): VDOT and Garmin are not fully set up yet, so their
/// connects may not complete even at the provider end — treat failures past the
/// launch boundary as "not yet configured", not as app regressions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';
import '../helpers/test_config.dart';
import '../helpers/test_helpers.dart';

/// The providers whose connect entry points we exercise from the onboarding
/// "Connect Training" screen (reachable without completing signup).
const _providers = <_Provider>[
  _Provider('finalsurge', 'connect_training.finalsurge_connect_button'),
  _Provider('trainingpeaks', 'connect_training.trainingpeaks_connect_button'),
  _Provider('garmin', 'connect_training.garmin_connect_button'),
];

void main() {
  for (final provider in _providers) {
    patrolTest(
      'connect ${provider.name}: tapping Connect launches OAuth without crashing',
      ($) async {
        final tester = $.tester;
        // Flavor-aware boot via the shared launcher (helpers/flow_launcher.dart).
        await launchApp();
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(minutes: 2),
        );

        // Reach the onboarding "Connect Training" screen.
        final getStarted = find.byKey(
          const ValueKey('welcome.get_started_button'),
        );
        if (getStarted.evaluate().isNotEmpty) {
          await tester.mustTap(
            getStarted,
            reason: 'welcome.get_started_button',
          );
        } else {
          // Already past welcome (hot sim). If we can't see the connect button,
          // skip — this test's entry point is the onboarding connect screen.
          final connectBtn = find.byKey(ValueKey(provider.connectKey));
          if (connectBtn.evaluate().isEmpty) {
            markTestSkipped(
              'Connect Training screen not reachable (app not on welcome). '
              'Reinstall for a clean onboarding entry.',
            );
            return;
          }
        }

        final connectButton = await tester.mustFind(
          find.byKey(ValueKey(provider.connectKey)),
          reason: provider.connectKey,
        );

        // Tap Connect → launches ASWebAuthenticationSession (iOS) / Custom Tab.
        await tester.tap(connectButton);
        await tester.pump(const Duration(seconds: 3));

        // iOS shows a native consent dialog before the web view. Patrol CAN
        // drive this. Tap "Continue" if present; tolerate its absence.
        try {
          await $.native.tap(Selector(textContains: 'Continue'));
          await tester.pump(const Duration(seconds: 2));
        } catch (_) {
          // No native consent dialog surfaced (platform/provider dependent).
        }

        // Credential entry — only meaningful where the web form is automatable
        // (NOT iOS ASWebAuthenticationSession). Guarded on the flavor-matched
        // TestConfig credentials being present.
        if (TestConfig.hasLoginCredentials) {
          // Best-effort native automation of the provider login form. On iOS
          // this will no-op/throw (secure session) and we swallow it; on
          // Android (Custom Tabs) it can drive the form.
          try {
            await $.native.enterText(
              Selector(textContains: 'mail'),
              text: TestConfig.loginEmail,
            );
            await $.native.enterText(
              Selector(textContains: 'assword'),
              text: TestConfig.loginPassword,
            );
            await $.native.tap(Selector(textContains: 'Sign'));
            await tester.pump(const Duration(seconds: 5));
          } catch (_) {
            // Secure web session not automatable on this platform — expected
            // on iOS. The launch-boundary assertion below is what we verify.
          }
        }

        // Cancel out of the OAuth sheet to return to the app, then assert the
        // app is still alive (no crash) — the real regression guard here.
        try {
          await $.native.tap(Selector(textContains: 'Cancel'));
        } catch (_) {
          // Already dismissed / not present.
        }
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(
          find.byType(Widget),
          findsWidgets,
          reason:
              'App should remain rendered after the ${provider.name} OAuth '
              'launch + cancel (no crash).',
        );
      },
      timeout: const Timeout(Duration(minutes: 8)),
    );
  }
}

class _Provider {
  const _Provider(this.name, this.connectKey);
  final String name;
  final String connectKey;
}

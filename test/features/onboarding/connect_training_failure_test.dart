// Widget tests for the connect-training step's FAILURE path (onboarding
// step 3, 2026-08 redesign).
//
// The Patrol suite cannot genuinely fail a real OAuth handshake without
// faking it, so the phase-6 e2e rewrite pins the connect-failure contract
// here instead (see integration_test/flows/onboarding_signup_flow_test.dart):
//
//   - a failed connect surfaces a MealvanaSnackbar error naming the provider,
//   - the provider card is back in its Connect state (the same button IS the
//     retry path — tapping it connects again),
//   - and "Skip for now" still advances the PageView.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/connected_apps_screen.dart';

import '../../helpers/widget_test_harness.dart';

/// Seeded controller whose Final Surge connect always fails: it stamps the
/// error onto state and returns false, the same observable outcome as the
/// real controller's catch block (which also resets isConnecting), without
/// touching Supabase.
class _FailingConnectTrainingController extends ConnectTrainingController {
  static int connectAttempts = 0;

  @override
  FutureOr<ConnectTrainingState> build() => const ConnectTrainingState();

  @override
  Future<bool> connectFinalSurge() async {
    connectAttempts++;
    state = AsyncData(
      state.value!.copyWith(errorMessage: 'network unreachable'),
    );
    return false;
  }
}

void main() {
  Future<void> pumpConnectStep(
    WidgetTester tester, {
    VoidCallback? onContinue,
  }) async {
    _FailingConnectTrainingController.connectAttempts = 0;
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          mockSharedPreferences(),
          connectTrainingControllerProvider.overrideWith(
            _FailingConnectTrainingController.new,
          ),
        ],
        child: wrapForTest(
          ConnectedAppsScreen(onContinue: onContinue, stepIndex: 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The tappable Connect affordance inside the Final Surge card.
  Finder finalSurgeConnect() => find.descendant(
    of: find.byKey(
      const ValueKey('connect_training.finalsurge_connect_button'),
    ),
    matching: find.text('Connect'),
  );

  /// The 2026-08 spec port puts the chart card above the provider rows, so
  /// the Final Surge card can start below the fold — scroll it into view
  /// before asserting/tapping.
  Future<void> revealFinalSurgeConnect(WidgetTester tester) async {
    await tester.ensureVisible(finalSurgeConnect());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'failed connect shows the error snackbar and keeps the card in its '
    'Connect (retry) state',
    (tester) async {
      await pumpConnectStep(tester, onContinue: () {});
      await revealFinalSurgeConnect(tester);

      expect(finalSurgeConnect(), findsOneWidget);
      await tester.tap(finalSurgeConnect());
      await tester.pumpAndSettle();

      // MealvanaSnackbar.showError with the provider named and the retry
      // instruction (the controller's errorMessage is included).
      expect(
        find.textContaining('Could not connect Final Surge'),
        findsOneWidget,
      );
      expect(find.textContaining('Tap Connect to try again'), findsOneWidget);

      // The card is back in (never left) its Connect state — no spinner,
      // same button available as the retry path.
      expect(finalSurgeConnect(), findsOneWidget);
      expect(_FailingConnectTrainingController.connectAttempts, 1);

      // Retry actually retries: the same button drives connect again.
      await tester.tap(finalSurgeConnect(), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_FailingConnectTrainingController.connectAttempts, 2);
    },
  );

  testWidgets('Skip for now still advances after a failed connect', (
    tester,
  ) async {
    var continued = 0;
    await pumpConnectStep(tester, onContinue: () => continued++);
    await revealFinalSurgeConnect(tester);

    await tester.tap(finalSurgeConnect());
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not connect Final Surge'),
      findsOneWidget,
    );

    // Let the 5s error snackbar time out so it can't swallow the tap.
    await tester.pumpAndSettle(const Duration(seconds: 6));

    await tester.ensureVisible(
      find.byKey(const ValueKey('connect_training.continue_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('connect_training.continue_button')),
    );
    await tester.pumpAndSettle();

    expect(continued, 1);
  });

  testWidgets(
    'revisit mode shows the kicker instead of the intro block and its '
    'Continue fires the return callback',
    (tester) async {
      var returned = 0;
      tester.view.physicalSize = standardPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockAppExternalDeps(),
            mockSharedPreferences(),
            connectTrainingControllerProvider.overrideWith(
              _FailingConnectTrainingController.new,
            ),
          ],
          child: wrapForTest(
            ConnectedAppsScreen(
              isRevisit: true,
              onContinue: () => returned++,
              onBack: () => returned++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Spec revisit intro: teal kicker only — no orange title, no chart.
      expect(
        find.byKey(const ValueKey('connect_training.revisit_kicker')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('connect_training.title')),
        findsNothing,
      );

      // Providers list is still there.
      expect(finalSurgeConnect(), findsOneWidget);

      // Continue returns to the pushing page (callback pops the route).
      await tester.ensureVisible(
        find.byKey(const ValueKey('connect_training.continue_button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('connect_training.continue_button')),
      );
      await tester.pumpAndSettle();
      expect(returned, 1);
    },
  );
}

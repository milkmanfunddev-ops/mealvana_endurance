// Layout regression tests for the onboarding spec-styled provider rows.
//
// The connected row's "Sync Now" pill is wider than the "Connect" pill it
// replaces. A fixed-width action slot used to clip it (12px overflow on
// device, visible as the debug overflow stripe). These pin that every
// action state lays out within its row, at the narrow end of our supported
// widths, so a future state with a longer label fails here rather than on
// someone's phone.
//
// Note: the test font renders far wider than the shipped Sansita — "Sync
// Now" measures ~130pt here vs ~68pt on device — so passing under these
// conditions is a stricter bar than the real layout faces.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/integrations/presentation/widgets/integration_provider_card.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  /// Renders one spec row in a given state and returns any overflow errors.
  Future<void> pumpSpecRow(
    WidgetTester tester, {
    required bool isConnected,
    required bool hasSynced,
  }) async {
    tester.view.physicalSize = smallPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              IntegrationProviderCard(
                name: 'TrainingPeaks',
                isAvailable: true,
                isConnecting: false,
                isConnected: isConnected,
                hasSynced: hasSynced,
                specStyle: true,
                onConnect: () {},
                onSync: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('unconnected spec row lays out without overflow', (tester) async {
    await pumpSpecRow(
      tester,
      isConnected: false,
      hasSynced: false,
    );
    expectNoRenderOverflow(tester);
  });

  testWidgets('connected spec row fits its wider Sync Now action', (
    tester,
  ) async {
    await pumpSpecRow(
      tester,
      isConnected: true,
      hasSynced: false,
    );
    expect(find.text('Sync Now'), findsOneWidget);
    expectNoRenderOverflow(tester);
  });

  testWidgets('post-sync spec row fits its Synced! action', (tester) async {
    await pumpSpecRow(
      tester,
      isConnected: true,
      hasSynced: true,
    );
    expect(find.text('Synced!'), findsOneWidget);
    expectNoRenderOverflow(tester);
  });

  // The 'history caption stays on a single line' test was removed with ruling
  // D-4 (spec/design/surfaces/integrations-data-display.md, 2026-09-13): the
  // provider connect cards no longer carry a history/window sublabel on either
  // surface, so there is no caption left to pin.
}

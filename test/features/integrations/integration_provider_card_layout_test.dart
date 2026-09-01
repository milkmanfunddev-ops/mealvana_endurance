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
    String? windowCaption,
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
                windowCaption: windowCaption,
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
      windowCaption: 'Imports ~30 days of history',
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
      windowCaption: 'Imports ~30 days of history',
    );
    expect(find.text('Sync Now'), findsOneWidget);
    expectNoRenderOverflow(tester);
  });

  testWidgets('post-sync spec row fits its Synced! action', (tester) async {
    await pumpSpecRow(
      tester,
      isConnected: true,
      hasSynced: true,
      windowCaption: 'Imports ~30 days of history',
    );
    expect(find.text('Synced!'), findsOneWidget);
    expectNoRenderOverflow(tester);
  });

  testWidgets('the history caption stays on a single line', (tester) async {
    await pumpSpecRow(
      tester,
      isConnected: true,
      hasSynced: false,
      windowCaption: 'Imports ~30 days of history',
    );

    // The whole point of keeping the action narrow: this caption must not
    // wrap (see the 2026-08 port ruling).
    final caption = tester.widget<Text>(
      find.text('Imports ~30 days of history'),
    );
    expect(caption.maxLines, 1);
    expect(caption.softWrap, isFalse);
  });
}

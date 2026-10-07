// Ticket 141 (Finding 118-005): each Connected Apps card read as one image
// element whose label ran "Reconnect / Sign in again … / Last synced …".
// Reconnect and Sync Now are their own named buttons.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/integrations/presentation/widgets/integration_provider_card.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget card) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Column(children: [card])),
      ),
    );
    await tester.pump();
  }

  testWidgets('a connected card: Sync Now is its own button, with the '
      'long-press to disconnect', (tester) async {
    final handle = tester.ensureSemantics();
    var syncs = 0;
    await pump(
      tester,
      IntegrationProviderCard(
        name: 'TrainingPeaks',
        isAvailable: true,
        isConnecting: false,
        isConnected: true,
        athleteName: 'Xuan Huang',
        lastSyncAt: DateTime(2026, 9, 26, 9, 30),
        onSync: () => syncs++,
        onDisconnect: () {},
      ),
    );

    final sync = find.bySemanticsLabel('Sync Now');
    expect(sync, findsOneWidget);
    expect(
      tester.getSemantics(sync),
      isSemantics(
        label: 'Sync Now',
        isButton: true,
        hasTapAction: true,
        hasLongPressAction: true,
      ),
    );
    await tester.tap(find.text('Sync Now'));
    expect(syncs, 1);
    handle.dispose();
  });

  testWidgets('a card that needs a fresh sign-in: Reconnect is its own '
      'button', (tester) async {
    final handle = tester.ensureSemantics();
    var connects = 0;
    await pump(
      tester,
      IntegrationProviderCard(
        name: 'TrainingPeaks',
        isAvailable: true,
        isConnecting: false,
        isConnected: true,
        needsReconnect: true,
        reconnectLabel: 'Reconnect',
        reconnectNote: 'Sign in again to keep syncing',
        athleteName: 'Xuan Huang',
        onConnect: () => connects++,
        onDisconnect: () {},
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Reconnect')),
      isSemantics(label: 'Reconnect', isButton: true, hasTapAction: true),
    );
    // The note and the name stay text of their own, not part of the button.
    expect(
      find.bySemanticsLabel(RegExp('Sign in again')),
      findsOneWidget,
    );
    await tester.tap(find.text('Reconnect'));
    expect(connects, 1);
    handle.dispose();
  });

  testWidgets('an unconnected card: Connect is a button', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      IntegrationProviderCard(
        name: 'Garmin',
        isAvailable: true,
        isConnecting: false,
        isConnected: false,
        specStyle: true,
        onConnect: () {},
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Connect')),
      isSemantics(label: 'Connect', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });
}

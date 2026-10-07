// Ticket 141 (Finding 118-005): New Event's leading button had no label.
// It is a button named "Back".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/features/events/presentation/screens/event_form_screen.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  testWidgets('New Event: the leading button is named Back', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const EventFormScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Event'), findsOneWidget);
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('event_create.close_button')),
      ),
      // An IconButton is named by its tooltip.
      isSemantics(tooltip: 'Back', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });
}

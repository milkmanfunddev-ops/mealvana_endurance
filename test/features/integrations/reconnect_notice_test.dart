// Ticket 138 (Finding 118-007, Lee 2026-09-26): when a sync first finds a
// connected app needs signing in again, the Timeline shows a one-time notice
// naming it, with Reconnect. Once per move into requires_reauth, remembered
// locally; a later success forgets it so a relapse is announced again.
//
// The controller is driven through the real notifier (ProviderContainer) with
// real SharedPreferences (mock initial values); the widget test renders the
// real ReconnectNotice with the strings from content_defaults.json.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/reconnect_notice_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/widgets/reconnect_notice.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/widget_test_harness.dart';
import '../../helpers/test_content.dart';

Future<ProviderContainer> containerWithPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ReconnectNoticeController (real notifier)', () {
    test('the first move into requires_reauth shows the provider', () async {
      final c = await containerWithPrefs();
      final notifier = c.read(reconnectNoticeControllerProvider.notifier);

      notifier.onSyncStatusWritten('training_peaks', requiresReauthStatus);

      expect(c.read(reconnectNoticeControllerProvider), 'training_peaks');
    });

    test('the same move written again shows nothing new', () async {
      final c = await containerWithPrefs();
      final notifier = c.read(reconnectNoticeControllerProvider.notifier);
      notifier.onSyncStatusWritten('vdot', requiresReauthStatus);
      notifier.dismiss();

      // A second sync path (event sync, Sync Now) writes the same status.
      notifier.onSyncStatusWritten('vdot', requiresReauthStatus);
      notifier.onSyncStatusWritten('vdot', requiresReauthStatus);

      expect(c.read(reconnectNoticeControllerProvider), isNull);
    });

    test('remembered across a controller refresh', () async {
      final c = await containerWithPrefs();
      c
          .read(reconnectNoticeControllerProvider.notifier)
          .onSyncStatusWritten('garmin', requiresReauthStatus);
      c.invalidate(reconnectNoticeControllerProvider);

      c
          .read(reconnectNoticeControllerProvider.notifier)
          .onSyncStatusWritten('garmin', requiresReauthStatus);

      expect(c.read(reconnectNoticeControllerProvider), isNull);
    });

    test('a success forgets the move, so a relapse shows again', () async {
      final c = await containerWithPrefs();
      final notifier = c.read(reconnectNoticeControllerProvider.notifier);
      notifier.onSyncStatusWritten('training_peaks', requiresReauthStatus);
      expect(c.read(reconnectNoticeControllerProvider), 'training_peaks');

      // Reconnected: the sync succeeds and the pending notice goes.
      notifier.onSyncStatusWritten('training_peaks', 'success');
      expect(c.read(reconnectNoticeControllerProvider), isNull);

      notifier.onSyncStatusWritten('training_peaks', requiresReauthStatus);
      expect(c.read(reconnectNoticeControllerProvider), 'training_peaks');
    });

    test('an ordinary error changes nothing', () async {
      final c = await containerWithPrefs();
      c
          .read(reconnectNoticeControllerProvider.notifier)
          .onSyncStatusWritten('final_surge', 'error');
      expect(c.read(reconnectNoticeControllerProvider), isNull);
    });

    test('one provider at a time; the second waits for its own move',
        () async {
      final c = await containerWithPrefs();
      final notifier = c.read(reconnectNoticeControllerProvider.notifier);
      notifier.onSyncStatusWritten('training_peaks', requiresReauthStatus);
      notifier.onSyncStatusWritten('vdot', requiresReauthStatus);
      expect(c.read(reconnectNoticeControllerProvider), 'training_peaks');
    });
  });

  group('ReconnectNotice widget', () {
    final content = loadDefaultContent();

    Future<ProviderContainer> pump(WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          mockAppExternalDeps(),
          sharedPreferencesProvider.overrideWithValue(prefs),
          contentServiceProvider.overrideWith(testContentService),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: wrapForTest(
            const Scaffold(body: Column(children: [ReconnectNotice()])),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('renders nothing until a connection needs signing in again',
        (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('reconnect_notice.reconnect')),
          findsNothing);
    });

    testWidgets('names the app, offers Reconnect, and shows once',
        (tester) async {
      final container = await pump(tester);
      container
          .read(reconnectNoticeControllerProvider.notifier)
          .onSyncStatusWritten('training_peaks', requiresReauthStatus);
      await tester.pumpAndSettle();

      final expected = content['connections.reconnect_notice']!
          .replaceAll('{provider}', 'TrainingPeaks');
      expect(find.text(expected), findsOneWidget);
      expect(
        find.text(content['connections.reconnect_notice_action']!),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('reconnect_notice.dismiss')));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsNothing);

      // The same finding on the next sync does not bring it back.
      container
          .read(reconnectNoticeControllerProvider.notifier)
          .onSyncStatusWritten('training_peaks', requiresReauthStatus);
      await tester.pumpAndSettle();
      expect(find.text(expected), findsNothing);
    });
  });
}

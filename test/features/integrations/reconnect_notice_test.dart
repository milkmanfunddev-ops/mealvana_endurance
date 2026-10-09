// Ticket 138 (Finding 118-007) and ticket 77 (Finding 68-008, ruling of
// 2026-10-09): the Timeline names a connected app that needs signing in
// again, with Reconnect. The notice is read from the integrations rows (active
// and `requires_reauth`) on every launch until the row changes; the X or
// Reconnect hides it for this launch only.
//
// The controller is driven through the real notifier and the real Drift watch
// on the real IntegrationsRepository (in-memory Drift). The launch pull is
// stubbed here (reauth_from_server_row_seam_test.dart drives the real one);
// the widget test renders the real ReconnectNotice with the strings from
// content_defaults.json.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/reconnect_notice_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/widgets/reconnect_notice.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart';
import '../../helpers/test_content.dart';

const _userId = '00000000-0000-0000-0000-000000000138';

IntegrationModel _row(
  String provider, {
  String? status,
  bool active = true,
}) => IntegrationModel(
  userId: _userId,
  provider: provider,
  accessToken: 'access-$provider',
  refreshToken: 'refresh-$provider',
  providerAthleteId: 'ath-$provider',
  isActive: active,
  lastSyncStatus: status,
);

void main() {
  late AppDatabase db;
  late IntegrationsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    addTearDown(db.close);
    // Writes push to a server that accepts them; the users row is absent, so
    // the eager push defers (DEV-A2) and nothing leaves the device.
    repository = IntegrationsRepository(
      database: db,
      supabase: FakePostgrest().client,
      report: RecordingReport(),
    );
  });

  List<Override> overrides(SharedPreferences prefs) => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    integrationsRepositoryProvider.overrideWithValue(repository),
    userIdProvider.overrideWith((ref) async => _userId),
    integrationRowsLaunchPullProvider(_userId).overrideWith((ref) async {}),
  ];

  Future<ProviderContainer> launch() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: overrides(prefs));
    addTearDown(container.dispose);
    container.listen(reconnectNoticeControllerProvider, (_, _) {});
    return container;
  }

  /// Lets the Drift watch emit and the notice rebuild.
  Future<String?> settled(ProviderContainer c) async {
    for (var i = 0; i < 20; i++) {
      await pumpEventQueue();
    }
    return c.read(reconnectNoticeControllerProvider);
  }

  group('ReconnectNoticeController (real notifier, Drift watch)', () {
    test('an active requires_reauth row shows its provider', () async {
      await repository.upsertIntegration(
        _row('training_peaks', status: requiresReauthStatus),
      );
      final c = await launch();
      expect(await settled(c), 'training_peaks');
    });

    test('a row moving into requires_reauth shows it, and success clears it',
        () async {
      await repository.upsertIntegration(_row('vdot', status: 'success'));
      final c = await launch();
      expect(await settled(c), isNull);

      await repository.updateSyncStatus(
        _userId,
        'vdot',
        status: requiresReauthStatus,
        error: 'reauth_required',
      );
      expect(await settled(c), 'vdot');

      await repository.updateSyncStatus(_userId, 'vdot', status: 'success');
      expect(await settled(c), isNull);
    });

    test('an ordinary error shows nothing', () async {
      await repository.upsertIntegration(_row('final_surge', status: 'error'));
      final c = await launch();
      expect(await settled(c), isNull);
    });

    test('an inactive requires_reauth row shows nothing', () async {
      await repository.upsertIntegration(
        _row('garmin', status: requiresReauthStatus, active: false),
      );
      final c = await launch();
      expect(await settled(c), isNull);
    });

    test('two providers show one at a time; the second after the first is '
        'dismissed', () async {
      await repository.upsertIntegration(
        _row('vdot', status: requiresReauthStatus),
      );
      await repository.upsertIntegration(
        _row('training_peaks', status: requiresReauthStatus),
      );
      final c = await launch();
      expect(await settled(c), 'training_peaks');

      c.read(reconnectNoticeControllerProvider.notifier).dismiss();
      expect(c.read(reconnectNoticeControllerProvider), 'vdot');

      c.read(reconnectNoticeControllerProvider.notifier).dismiss();
      expect(c.read(reconnectNoticeControllerProvider), isNull);

      // The same rows written again in this launch stay dismissed.
      await repository.updateSyncStatus(
        _userId,
        'vdot',
        status: requiresReauthStatus,
      );
      expect(await settled(c), isNull);
    });

    test('dismissed for this launch only: the next launch shows it again',
        () async {
      await repository.upsertIntegration(
        _row('garmin', status: requiresReauthStatus),
      );
      final first = await launch();
      expect(await settled(first), 'garmin');
      first.read(reconnectNoticeControllerProvider.notifier).dismiss();
      expect(first.read(reconnectNoticeControllerProvider), isNull);
      first.dispose();

      final second = await launch();
      expect(await settled(second), 'garmin');
    });
  });

  group('ReconnectNotice widget', () {
    final content = loadDefaultContent();

    Future<ProviderContainer> pump(WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          mockAppExternalDeps(),
          contentServiceProvider.overrideWith(testContentService),
          ...overrides(prefs),
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
      await tester.runAsync(() async {
        for (var i = 0; i < 20; i++) {
          await pumpEventQueue();
        }
      });
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('renders nothing until a connection needs signing in again',
        (tester) async {
      await pump(tester);
      expect(
        find.byKey(const ValueKey('reconnect_notice.reconnect')),
        findsNothing,
      );
    });

    testWidgets('names the app, offers Reconnect, and X hides it for the '
        'launch', (tester) async {
      await tester.runAsync(
        () => repository.upsertIntegration(
          _row('training_peaks', status: requiresReauthStatus),
        ),
      );
      final container = await pump(tester);

      final expected = content['connections.reconnect_notice']!.replaceAll(
        '{provider}',
        'TrainingPeaks',
      );
      expect(find.text(expected), findsOneWidget);
      expect(
        find.text(content['connections.reconnect_notice_action']!),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('reconnect_notice.dismiss')));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsNothing);
      expect(container.read(reconnectNoticeControllerProvider), isNull);
    });
  });
}

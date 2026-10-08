// Testing-wave develop-2026-10 ticket 40 (Findings 30-001, 31-001, 32-001).
//
// The branch split dropped the content half of commit 07dbca24: nothing
// started ContentService.initialize() and getValue had no bundled-defaults
// fallback, so every key-only lookup on the device showed its key
// ("auth.verify_email.error_wrong_code" in the Verify screen, the Settings
// dialogs, the Timeline reconnect notice …). These tests pin the restore:
// a key resolves to its bundled default with NO caller initialising
// anything, and an unknown key still returns itself.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/data/content_repository.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes/recording_report.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockContentRepository repo;

  setUp(() {
    ContentDefaultsCache.debugReset();
    repo = _MockContentRepository();
    // No active content anywhere: the device after clear-app.sh.
    when(
      () => repo.getActiveContent(
        environment: any(named: 'environment'),
        locale: any(named: 'locale'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => repo.refreshContent(
        environment: any(named: 'environment'),
        locale: any(named: 'locale'),
      ),
    ).thenThrow(Exception('offline'));
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(repo),
        reportProvider.overrideWithValue(RecordingReport()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('bootstrap preload: a key-only getValue returns the bundled default',
      () async {
    // What bootstrap.dart does before runApp.
    await ContentDefaultsCache.preload();
    final service = container().read(contentServiceProvider);
    // Nobody called initialize() here; the provider did, unawaited.
    expect(
      service.getValue(ContentKeys.settingsDeleteConfirmTitle),
      isNot(ContentKeys.settingsDeleteConfirmTitle),
      reason: 'the Delete dialog title must be words, not its key',
    );
    expect(service.getValue(ContentKeys.settingsDeleteConfirmTitle),
        isNotEmpty);
  });

  test('the provider starts initialize() itself, which preloads the defaults',
      () async {
    final service = container().read(contentServiceProvider);
    await untilCalled(
      () => repo.getActiveContent(
        environment: any(named: 'environment'),
        locale: any(named: 'locale'),
      ),
    );
    // Let the unawaited preload finish.
    await Future<void>.delayed(Duration.zero);
    await pumpEventQueue();
    expect(ContentDefaultsCache.values, isNotNull,
        reason: 'initialize() preloads the bundled defaults');
    expect(
      service.getValue(ContentKeys.settingsSignOutConfirmTitle),
      isNot(ContentKeys.settingsSignOutConfirmTitle),
    );
  });

  test('an unknown key with no default still returns the key (bug signal)',
      () async {
    await ContentDefaultsCache.preload();
    final service = container().read(contentServiceProvider);
    expect(service.getValue('no.such.key'), 'no.such.key');
    expect(service.getValue('no.such.key', defaultValue: 'x'), 'x');
  });
}

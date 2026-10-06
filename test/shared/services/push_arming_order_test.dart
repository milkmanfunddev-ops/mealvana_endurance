// Patch #3 regression (2026-10-03): the fleet-wide silent-SDK bug.
//
// 1.29.0's startup reorder ran NotificationService.initialize() BEFORE any
// code had handed it the OneSignal app id, so _initializeOneSignal() bailed
// on an empty id — silently, unretried, on every fresh install. These tests
// pin the two guarantees that close that class of bug for good:
//
//   1. the empty-id bail TAPES (a misordered chain is visible on-device), and
//   2. configureRemotePush() ARMS OneSignal itself when the id arrives after
//      initialize() already ran — so step order can never disarm push again.
//
// The OneSignal SDK is a static singleton with platform channels, so "armed"
// is observed through the LaunchTrail tape (which buffers in memory without
// SharedPreferences) rather than by mocking the SDK: the "arming now" line is
// written by our code strictly before the SDK call. In a test environment the
// subsequent OneSignal platform-channel call fails and is swallowed by
// _initializeOneSignal's own catch — the path under test is OURS, not theirs.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/launch_trail.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';

import '../../helpers/fakes/recording_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingReport report;

  setUp(() {
    report = RecordingReport();
    NotificationService.debugSetReport(report);
  });

  tearDown(() => NotificationService.debugSetReport(null));

  setUpAll(() {
    // The arm path fires real OneSignal platform-channel calls (initialize,
    // requestPermission, listeners) un-awaited; without handlers their async
    // MissingPluginExceptions land in the test zone as stray errors. Benign
    // defaults stand in for the native side — the logic under test is ours.
    const channels = [
      'OneSignal',
      'OneSignal#debug',
      'OneSignal#notifications',
      'OneSignal#pushsubscription',
      'OneSignal#user',
      'OneSignal#session',
      'OneSignal#inappmessages',
      'OneSignal#location',
    ];
    for (final name in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async {
            // Bool-typed native reads the SDK awaits during lifecycleInit.
            const boolMethods = {
              'OneSignal#requestPermission',
              'OneSignal#permission',
              'OneSignal#canRequest',
            };
            if (boolMethods.contains(call.method)) return false;
            if (call.method == 'OneSignal#permissionNative') return 0;
            return null;
          });
    }
  });

  test('initialize() before any app id: bail is TAPED; a late '
      'configureRemotePush() arms OneSignal (ordering guard)', () async {
    // Cold start with the 1.29.0 bug ordering: no app id configured.
    // (initialize() itself needs the FLN platform, absent in unit tests —
    // the seam reproduces its completed state and the OneSignal arm call
    // it makes, which is the path under test.)
    NotificationService.debugMarkInitializedForTest();
    await NotificationService.debugInitializeOneSignal();

    expect(
      LaunchTrail.text,
      contains('onesignal init: SKIPPED — no app id configured yet'),
      reason:
          'the empty-id bail must leave a trace — this exact silence hid '
          'the fleet bug for two days',
    );
    expect(
      LaunchTrail.text,
      isNot(contains('arming now')),
      reason: 'nothing may arm before an app id exists',
    );
    // The tape is dev-only; rule D9 wants the bail PROD-readable too. A Note
    // in `push` is promoted to a warning event by Report.
    expect(
      report.notes.where((n) => n.area == 'push'),
      hasLength(1),
      reason: 'the empty-id bail must reach Report, not only the tape',
    );
    expect(report.notes.single.message, contains('no app id configured yet'));

    // The app id arrives late (as deferred.analytics used to deliver it).
    NotificationService.configureRemotePush(
      oneSignalAppId: '335e597f-0000-0000-0000-000000000000',
    );

    expect(
      LaunchTrail.text,
      contains('onesignal: app id arrived AFTER initialize() — arming now'),
      reason:
          'a late-arriving app id must trigger OneSignal arming itself — '
          'the belt-and-braces that makes chain order immaterial',
    );
    expect(NotificationService.isRemotePushConfigured, isTrue);
  });

  test('configureRemotePush with an empty id never claims to arm', () {
    final before = LaunchTrail.length;
    NotificationService.configureRemotePush(oneSignalAppId: '   ');
    final added = LaunchTrail.text.split('\n').skip(before).join('\n');
    expect(added, isNot(contains('arming now')));
  });
}

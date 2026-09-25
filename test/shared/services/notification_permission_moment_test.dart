// Ticket 79 (Findings 03-004, 31-010): a fresh install must not see iOS's
// notification prompt over the splash, before Welcome or sign-in. Deferred
// startup step 3 runs `NotificationService.initialize`, which used to call
// OneSignal's `requestPermission` on every launch; on an install that has
// never answered, that call is the system prompt. The ask now waits until an
// athlete's id is attached to the device (sign-in, or a restored session).
//
// The OneSignal SDK is replaced by a recording fake; everything else is the
// real NotificationService.

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';

class _RecordingRemotePush implements RemotePushClient {
  final permissionRequests = <bool>[];
  final logins = <String>[];
  int starts = 0;

  @override
  void start(String appId, void Function(Map<String, dynamic>) onClickData) {
    starts++;
  }

  @override
  Future<void> requestPermission({required bool fallbackToSettings}) async {
    permissionRequests.add(fallbackToSettings);
  }

  @override
  void login(String externalId) => logins.add(externalId);

  @override
  void logout() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingRemotePush remotePush;

  // The local-notifications plugin answers over its method channel; a test
  // binding has no host side: initialize answers true, everything else null
  // (no launch-from-tap).
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async => call.method == 'initialize' ? true : null,
      );

  setUp(() {
    NotificationService.debugReset();
    remotePush = _RecordingRemotePush();
    NotificationService.remotePush = remotePush;
    NotificationService.configure(
      const NoopAnalyticsTracker(),
      oneSignalAppId: 'test-app-id',
    );
  });

  tearDown(NotificationService.debugReset);

  test('startup with nobody signed in makes no permission request', () async {
    await NotificationService.initialize();

    expect(remotePush.starts, 1, reason: 'OneSignal still starts at launch');
    expect(remotePush.permissionRequests, isEmpty);
  });

  test('a null id from an unrestored session makes no request', () async {
    await NotificationService.initialize();
    await NotificationService.setRemotePushUserId(null);

    expect(remotePush.permissionRequests, isEmpty);
  });

  test('sign-in asks once, without bouncing to Settings', () async {
    await NotificationService.initialize();
    await NotificationService.setRemotePushUserId('athlete-1');

    expect(remotePush.logins, ['athlete-1']);
    expect(remotePush.permissionRequests, [false]);

    // tokenRefreshed and friends re-send the id; no second ask.
    await NotificationService.setRemotePushUserId('athlete-1');
    expect(remotePush.permissionRequests, [false]);
  });

  test('a restored session known before startup asks as OneSignal starts',
      () async {
    await NotificationService.setRemotePushUserId('athlete-1');
    expect(remotePush.permissionRequests, isEmpty);

    await NotificationService.initialize();

    expect(remotePush.permissionRequests, [false]);
  });
}

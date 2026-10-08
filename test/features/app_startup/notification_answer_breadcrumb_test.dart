// develop-2026-10 ticket 41 (Finding 30-011): with no local profile, the
// notification answer is not stored, and that is the normal state of a
// signed-out launch. It used to be a `push` note, a promoted area, so every
// signed-out launch sent a warning event. Now it is a `push` breadcrumb, the
// LaunchTrail line (D9: both PROD-readable), and one held `expected_failure`
// count, and nothing reaches Sentry as an event.
//
// Reached the way the app reaches it: the real AppStartupService arms
// NotificationService's answer callback, and the real NotificationService
// asks (pattern: notification_permission_moment_test.dart). Only OneSignal
// and the user repository are fakes.

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/app_startup/application/app_startup_service.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/launch_trail.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/recording_report.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _AnsweringRemotePush implements RemotePushClient {
  bool granted = true;

  @override
  void start(String appId, void Function(Map<String, dynamic>) onClickData) {}

  @override
  Future<bool> requestPermission({required bool fallbackToSettings}) async =>
      granted;

  @override
  Future<bool> permissionGranted() async => granted;

  @override
  bool? get optedIn => true;

  @override
  Future<void> optIn() async {}

  @override
  void login(String externalId) {}

  @override
  void logout() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The local-notifications plugin answers over its method channel; a test
  // binding has no host side.
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async => call.method == 'initialize' ? true : null,
      );

  late RecordingReport report;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.debugReset();
    LaunchTrail.debugReset();
    ExpectedFailureCounts.debugReset();
    NotificationService.remotePush = _AnsweringRemotePush()..granted = false;
    NotificationService.configure(
      const NoopAnalyticsTracker(),
      oneSignalAppId: 'test-app-id',
    );

    // Signed out: no local profile.
    final users = _MockUserRepository();
    when(() => users.getCurrentUser()).thenAnswer((_) async => null);
    report = RecordingReport();
    container = ProviderContainer(
      overrides: [
        reportProvider.overrideWithValue(report),
        userRepositoryProvider.overrideWith((_) async => users),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() {
    NotificationService.debugReset();
    ExpectedFailureCounts.debugReset();
  });

  test('no local profile: one push breadcrumb, the LaunchTrail line, a held '
      'count, and no note or event', () async {
    container.read(appStartupServiceProvider).armPermissionAnswer();
    await NotificationService.initialize();
    // The ask, and with it the OS's answer, comes once an id is attached.
    await NotificationService.setRemotePushUserId('athlete-1');
    await pumpEventQueue();

    final crumbs = report.calls
        .where((c) => c.severity == 'breadcrumb' && c.area == 'push')
        .toList();
    expect(crumbs, hasLength(1));
    expect(
      crumbs.single.message,
      'Notification permission answer not stored: no local profile',
    );
    expect(crumbs.single.data, {'granted': false});
    expect(
      LaunchTrail.text,
      contains('notification answer not stored: no local profile'),
    );
    expect(report.notes, isEmpty, reason: 'a push note is a warning event');
    expect(report.faults, isEmpty);
    expect(report.degradeds, isEmpty);
    // Before analytics starts there is no tracker to read without reading
    // consent; the count waits for it.
    expect(ExpectedFailureCounts.pending, [
      (area: 'push', reason: 'no_profile'),
    ]);
  });
}

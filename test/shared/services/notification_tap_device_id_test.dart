// Ticket 70: the reminder and activity-upload tap events carry the device id
// `app_opened` sends (deviceInfoServiceProvider), not 'unknown' and not the
// user id. The startup chain hands the device info service to
// NotificationService.configure; this test hands in a fake the same way.
//
// `reminder_set` / `reminder_scheduled` share the same `_analyticsDeviceId`
// getter but sit behind the plugin's permission check in scheduleReminder,
// which a unit test cannot pass (no platform plugin).

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/device_info_service.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';

const _deviceId = 'C8EEF12E-60FE-49A1-80F8-6C51A4BE767D';

class _FakeDeviceInfo implements DeviceInfoService {
  @override
  String get deviceId => _deviceId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late RecordingAnalyticsTracker analytics;

  setUp(() {
    NotificationService.debugReset();
    analytics = RecordingAnalyticsTracker();
    NotificationService.configure(analytics, deviceInfo: _FakeDeviceInfo());
    // Taps with no handler park as pending navigation; nothing else runs.
  });

  tearDown(NotificationService.debugReset);

  List<Map<String, dynamic>?> propsFor(String name) => analytics.events
      .where((e) => e.name == name)
      .map((e) => e.properties)
      .toList();

  test('a reminder tap tracks reminder_clicked with the device id', () {
    NotificationService.handleNotificationPayloadForTest('reminder:act-1');

    final clicked = propsFor('reminder_clicked');
    expect(clicked, hasLength(1));
    expect(clicked.single?['device_id'], _deviceId);
    expect(clicked.single?['activity_id'], 'act-1');
  });

  test('a legacy bare-id tap tracks reminder_clicked with the device id', () {
    NotificationService.handleNotificationPayloadForTest('act-legacy');

    final clicked = propsFor('reminder_clicked');
    expect(clicked, hasLength(1));
    expect(clicked.single?['device_id'], _deviceId);
  });

  test('an activity-upload tap carries the device id, not unknown', () {
    NotificationService.handleNotificationPayloadForTest(
      'activity:act-2:accuracy_hook_v2',
    );

    final clicked = propsFor('activity_upload_notification_clicked');
    expect(clicked, hasLength(1));
    expect(clicked.single?['device_id'], _deviceId);
    expect(clicked.single?['device_id'], isNot('unknown'));
  });

  test('configure without a device info keeps the one already handed in', () {
    // The g29 test re-configures with only a tracker; that must not drop
    // the startup chain's device info.
    NotificationService.configure(analytics);
    NotificationService.handleNotificationPayloadForTest('reminder:act-3');

    expect(propsFor('reminder_clicked').single?['device_id'], _deviceId);
  });
}

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'analytics/analytics_events.dart';
import 'analytics/analytics_tracker.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static String? _pendingNavigationPlanId;
  static AnalyticsTracker _analytics = const NoopAnalyticsTracker();

  static void configure(AnalyticsTracker tracker) {
    _analytics = tracker;
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;

    final planId = response.payload!;
    // Track reminder clicked when user taps notification
    _analytics.trackReminderClicked(
      deviceId: 'unknown', // Will be set properly when app identifies user
      planId: planId,
    );
    _pendingNavigationPlanId = planId;
  }

  static Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        return await iosPlugin.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    }

    return false;
  }

  static Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final result = await iosPlugin.checkPermissions();
        return result?.isEnabled ?? false;
      }
    }

    return false;
  }

  static Future<void> scheduleReminder({
    required DateTime scheduledDate,
    required bool recurring,
    required String title,
    required String body,
    String? planId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final hasPermission = await areNotificationsEnabled();
    if (!hasPermission) {
      return;
    }

    const notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);

    if (planId != null) {
      // Track both reminder_set and reminder_scheduled
      await _analytics.trackReminderSet(
        deviceId: 'unknown', // Will be set properly when app identifies user
        planId: planId,
        reminderTime: scheduledDate,
      );

      // Also track as scheduled (proxy for delivery)
      await _analytics.trackReminderScheduled(
        deviceId: 'unknown', // Will be set properly when app identifies user
        planId: planId,
        reminderTime: scheduledDate,
      );
    }

    if (recurring) {
      await _plugin.zonedSchedule(
        1,
        title,
        body,
        scheduledTZ,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: planId,
      );
    } else {
      await _plugin.zonedSchedule(
        2,
        title,
        body,
        scheduledTZ,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: planId,
      );
    }
  }

  static Future<void> cancelAllReminders() async {
    if (!_isInitialized) {
      await initialize();
    }

    await _plugin.cancelAll();
  }

  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }

    return await _plugin.pendingNotificationRequests();
  }

  static String? getPendingNavigationPlanId() {
    final planId = _pendingNavigationPlanId;
    _pendingNavigationPlanId = null;
    return planId;
  }

  static bool hasPendingNavigation() {
    return _pendingNavigationPlanId != null;
  }

  // Reminder fired tracking removed - using reminder_scheduled as proxy
}

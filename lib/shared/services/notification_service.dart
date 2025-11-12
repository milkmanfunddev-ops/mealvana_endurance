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
  static int? _pendingNavigationActivityId;
  static AnalyticsTracker _analytics = const NoopAnalyticsTracker();

  static void configure(AnalyticsTracker tracker) {
    _analytics = tracker;
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    // Create Android notification channels
    if (Platform.isAndroid) {
      await _createAndroidNotificationChannels();
    }

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');

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

  /// Creates notification channels for Android 8.0+ (API 26+)
  /// Required for notifications to work on Android
  static Future<void> _createAndroidNotificationChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Main nutrition plan reminders channel
    const nutritionRemindersChannel = AndroidNotificationChannel(
      'nutrition_plan_reminders',
      'Nutrition Plan Reminders',
      description: 'Reminders for your nutrition plans and upcoming activities',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Carb loading protocol reminders
    const carbLoadingChannel = AndroidNotificationChannel(
      'carb_loading_reminders',
      'Carb Loading Reminders',
      description: 'Reminders for carb loading meals and protocols',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // General app notifications (low priority)
    const generalChannel = AndroidNotificationChannel(
      'general_notifications',
      'General Notifications',
      description: 'General app updates and information',
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
      showBadge: true,
    );

    await androidPlugin.createNotificationChannel(nutritionRemindersChannel);
    await androidPlugin.createNotificationChannel(carbLoadingChannel);
    await androidPlugin.createNotificationChannel(generalChannel);
  }

  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;

    final activityId = int.tryParse(response.payload!);
    if (activityId == null) return;

    _analytics.trackReminderClicked(
      deviceId: 'unknown', // Will be set properly when app identifies user
      activityId: activityId,
    );
    _pendingNavigationActivityId = activityId;
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
    } else if (Platform.isAndroid) {
      // Android 13+ (API 33+) requires runtime permission for notifications
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Request POST_NOTIFICATIONS permission (Android 13+)
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? true; // Pre-Android 13 doesn't need permission, returns null
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
    } else if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Check if notifications are enabled (Android 13+)
        final enabled = await androidPlugin.areNotificationsEnabled();
        return enabled ?? true; // Pre-Android 13 always returns null (no permission needed)
      }
    }

    return false;
  }

  static Future<void> scheduleReminder({
    required DateTime scheduledDate,
    required bool recurring,
    required String title,
    required String body,
    int? activityId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final hasPermission = await areNotificationsEnabled();
    if (!hasPermission) {
      return;
    }

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'nutrition_plan_reminders',
        'Nutrition Plan Reminders',
        channelDescription: 'Reminders for your nutrition plans and upcoming activities',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);

    if (activityId != null) {
      // Track both reminder_set and reminder_scheduled
      await _analytics.trackReminderSet(
        deviceId: 'unknown', // Will be set properly when app identifies user
        activityId: activityId,
        reminderTime: scheduledDate,
      );

      // Also track as scheduled (proxy for delivery)
      await _analytics.trackReminderScheduled(
        deviceId: 'unknown', // Will be set properly when app identifies user
        activityId: activityId,
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
          payload: activityId?.toString(),
      );
    } else {
      await _plugin.zonedSchedule(
        2,
        title,
        body,
        scheduledTZ,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: activityId?.toString(),
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

  static int? getPendingNavigationActivityId() {
    final activityId = _pendingNavigationActivityId;
    _pendingNavigationActivityId = null;
    return activityId;
  }

  static bool hasPendingNavigation() {
    return _pendingNavigationActivityId != null;
  }

  // Reminder fired tracking removed - using reminder_scheduled as proxy
}

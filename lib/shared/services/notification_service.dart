import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../utils/platform_io.dart'
    if (dart.library.html) '../utils/platform_web.dart';
import 'analytics/analytics_events.dart';
import 'analytics/analytics_tracker.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static bool _isOneSignalInitialized = false;
  static String? _pendingNavigationActivityId;
  static String? _pendingNavigationType;
  static String? _pendingRemoteUserId;
  static String? _lastSyncedRemoteUserId;
  static void Function(String activityId, String? type)? _navigationHandler;
  static Future<void> Function(DateTime date)? _dailyMacroCacheInvalidator;
  static AnalyticsTracker _analytics = const NoopAnalyticsTracker();
  static String _oneSignalAppId = '';

  /// Registers a callback invoked when a Garmin activity-upload notification
  /// carries a [scheduled_date]. The callback should invalidate the macro
  /// cache for that date so the next calculation re-runs with fresh data.
  static void setDailyMacroCacheInvalidator(
    Future<void> Function(DateTime date)? invalidator,
  ) {
    _dailyMacroCacheInvalidator = invalidator;
  }

  static void configure(
    AnalyticsTracker tracker, {
    String oneSignalAppId = '',
  }) {
    _analytics = tracker;
    _oneSignalAppId = oneSignalAppId.trim();
  }

  static bool get isRemotePushConfigured => _oneSignalAppId.isNotEmpty;

  /// Registers a callback for notification-tap deep linking.
  /// If no handler is set, taps are stored as pending navigation.
  /// The [type] is the payload prefix: `reminder`, `activity`, or null for legacy.
  static void setNavigationHandler(
    void Function(String activityId, String? type)? handler,
  ) {
    _navigationHandler = handler;
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Web platform doesn't support local notifications
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    tz.initializeTimeZones();

    // Create Android notification channels
    if (!kIsWeb && PlatformInfo.isAndroid) {
      await _createAndroidNotificationChannels();
    }

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Handle cold-start launches from notification taps.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    final launchPayload = launchResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _handleNotificationPayload(launchPayload);
    }

    await _initializeOneSignal();

    _isInitialized = true;
  }

  static Future<void> _initializeOneSignal() async {
    if (_oneSignalAppId.isEmpty || _isOneSignalInitialized || kIsWeb) {
      return;
    }

    try {
      OneSignal.initialize(_oneSignalAppId);
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        if (data == null) return;
        _handleRemoteNotificationData(data);
      });

      // Show push banners while the app is in the foreground. Without this,
      // iOS suppresses the alert entirely when Mealvana is open.
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        event.preventDefault();
        event.notification.display();
      });

      _isOneSignalInitialized = true;
      await _syncRemotePushUserIdentity();
    } catch (e) {
      debugPrint('OneSignal init failed: $e');
    }
  }

  static void _handleRemoteNotificationData(Map<String, dynamic> data) {
    // Cache invalidation: if the notification carries a scheduled_date,
    // invalidate the macro cache for that date before navigating.
    final scheduledDateStr = data['scheduled_date']?.toString();
    if (scheduledDateStr != null && scheduledDateStr.isNotEmpty) {
      final scheduledDate = DateTime.tryParse(scheduledDateStr);
      if (scheduledDate != null) {
        _dailyMacroCacheInvalidator?.call(scheduledDate);
      }
    }

    final payload = data['payload']?.toString();
    if (payload != null && payload.isNotEmpty) {
      _handleNotificationPayload(payload);
      return;
    }

    final activityId =
        data['activityId']?.toString() ??
        data['activity_id']?.toString() ??
        data['id']?.toString();
    if (activityId == null || activityId.isEmpty) return;

    final type = data['type']?.toString().trim();
    if (type != null && type.isNotEmpty) {
      _handleNotificationPayload('$type:$activityId');
      return;
    }

    _handleNotificationPayload('activity:$activityId');
  }

  /// Syncs Supabase auth user id to OneSignal external id.
  /// This allows server-side targeting with include_aliases.external_id.
  static Future<void> setRemotePushUserId(String? userId) async {
    final normalized = userId?.trim();
    _pendingRemoteUserId = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;

    if (!_isInitialized || !_isOneSignalInitialized) {
      return;
    }

    await _syncRemotePushUserIdentity();
  }

  static Future<void> _syncRemotePushUserIdentity() async {
    if (!_isOneSignalInitialized || kIsWeb) return;

    final targetUserId = _pendingRemoteUserId;
    if (targetUserId == _lastSyncedRemoteUserId) {
      return;
    }

    try {
      if (targetUserId == null) {
        OneSignal.logout();
      } else {
        OneSignal.login(targetUserId);
      }
      _lastSyncedRemoteUserId = targetUserId;
    } catch (e) {
      debugPrint('OneSignal user identity sync failed: $e');
    }
  }

  /// Creates notification channels for Android 8.0+ (API 26+)
  /// Required for notifications to work on Android
  static Future<void> _createAndroidNotificationChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

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

    // Completed activity uploads from connected providers (Garmin, etc.)
    const activityUploadsChannel = AndroidNotificationChannel(
      'activity_upload_notifications',
      'Activity Upload Notifications',
      description: 'Alerts when completed activities are synced into Mealvana',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await androidPlugin.createNotificationChannel(nutritionRemindersChannel);
    await androidPlugin.createNotificationChannel(carbLoadingChannel);
    await androidPlugin.createNotificationChannel(generalChannel);
    await androidPlugin.createNotificationChannel(activityUploadsChannel);
  }

  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;

    final payload = response.payload!;
    if (payload.isEmpty) return;

    _handleNotificationPayload(payload);
  }

  static void _handleNotificationPayload(String payload) {
    if (payload.isEmpty) return;

    // Typed payload format: "<type>:<activityId>"
    final separatorIndex = payload.indexOf(':');
    if (separatorIndex > 0 && separatorIndex < payload.length - 1) {
      final type = payload.substring(0, separatorIndex);
      final activityId = payload.substring(separatorIndex + 1);
      if (activityId.isEmpty) return;

      if (type == 'reminder') {
        _analytics.trackReminderClicked(
          deviceId: 'unknown', // Will be set properly when app identifies user
          activityId: activityId,
        );
      } else if (type == 'activity') {
        _analytics.track(
          'activity_upload_notification_clicked',
          properties: {
            'device_id': 'unknown',
            'activity_id': activityId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      _dispatchNavigation(activityId, type);
      return;
    }

    // Legacy payload compatibility: raw activityId (treated as reminder)
    _analytics.trackReminderClicked(
      deviceId: 'unknown', // Will be set properly when app identifies user
      activityId: payload,
    );
    _dispatchNavigation(payload, null);
  }

  static void _dispatchNavigation(String activityId, String? type) {
    final handler = _navigationHandler;
    if (handler != null) {
      handler(activityId, type);
      return;
    }
    _pendingNavigationActivityId = activityId;
    _pendingNavigationType = type;
  }

  static Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }

    // Web platform doesn't support local notifications
    if (kIsWeb) {
      return false;
    }

    if (!kIsWeb && PlatformInfo.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosPlugin != null) {
        return await iosPlugin.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } else if (!kIsWeb && PlatformInfo.isAndroid) {
      // Android 13+ (API 33+) requires runtime permission for notifications
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        // Request POST_NOTIFICATIONS permission (Android 13+)
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ??
            true; // Pre-Android 13 doesn't need permission, returns null
      }
    }

    return false;
  }

  static Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) {
      await initialize();
    }

    // Web platform doesn't support local notifications
    if (kIsWeb) {
      return false;
    }

    if (!kIsWeb && PlatformInfo.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosPlugin != null) {
        final result = await iosPlugin.checkPermissions();
        return result?.isEnabled ?? false;
      }
    } else if (!kIsWeb && PlatformInfo.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        // Check if notifications are enabled (Android 13+)
        final enabled = await androidPlugin.areNotificationsEnabled();
        return enabled ??
            true; // Pre-Android 13 always returns null (no permission needed)
      }
    }

    return false;
  }

  static Future<void> scheduleReminder({
    required DateTime scheduledDate,
    required bool recurring,
    required String title,
    required String body,
    String? activityId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Web platform doesn't support local notifications
    if (kIsWeb) {
      return;
    }

    final hasPermission = await areNotificationsEnabled();
    if (!hasPermission) {
      return;
    }

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'nutrition_plan_reminders',
        'Nutrition Plan Reminders',
        channelDescription:
            'Reminders for your nutrition plans and upcoming activities',
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
        payload: activityId != null ? 'reminder:$activityId' : null,
      );
    } else {
      await _plugin.zonedSchedule(
        2,
        title,
        body,
        scheduledTZ,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: activityId != null ? 'reminder:$activityId' : null,
      );
    }
  }

  /// Shows an immediate local notification when a completed activity
  /// is uploaded from Garmin Connect (or another push-based provider).
  ///
  /// [provider] should be the human-readable provider label used in the
  /// notification body (e.g. "Garmin Connect"). The default matches
  /// Garmin's brand-compliant full name — never use an abbreviation.
  static Future<void> showActivityUploadedNotification({
    required String activityId,
    required String title,
    required DateTime activityDate,
    String provider = 'Garmin Connect',
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (kIsWeb) {
      return;
    }

    final hasPermission = await areNotificationsEnabled();
    if (!hasPermission) {
      return;
    }

    final month = activityDate.month.toString().padLeft(2, '0');
    final day = activityDate.day.toString().padLeft(2, '0');
    final year = activityDate.year.toString();
    final activityDateText = '$month/$day/$year';

    final notificationDetails = NotificationDetails(
      android: const AndroidNotificationDetails(
        'activity_upload_notifications',
        'Activity Upload Notifications',
        channelDescription:
            'Alerts when completed activities are synced into Mealvana',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final body = 'A workout for $activityDateText was uploaded from $provider.';

    await _plugin.show(
      // Stable-ish positive int for this activity ID
      activityId.hashCode & 0x7fffffff,
      title,
      body,
      notificationDetails,
      payload: 'activity:$activityId',
    );

    await _analytics.track(
      'activity_upload_notification_shown',
      properties: {
        'device_id': 'unknown',
        'activity_id': activityId,
        'provider': provider.toLowerCase(),
        'activity_date': activityDateText,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static Future<void> cancelAllReminders() async {
    if (!_isInitialized) {
      await initialize();
    }

    await _plugin.cancelAll();
  }

  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }

    return await _plugin.pendingNotificationRequests();
  }

  static String? getPendingNavigationActivityId() {
    final activityId = _pendingNavigationActivityId;
    _pendingNavigationActivityId = null;
    return activityId;
  }

  static String? getPendingNavigationType() {
    final type = _pendingNavigationType;
    _pendingNavigationType = null;
    return type;
  }

  static bool hasPendingNavigation() {
    return _pendingNavigationActivityId != null;
  }

  // Reminder fired tracking removed - using reminder_scheduled as proxy
}

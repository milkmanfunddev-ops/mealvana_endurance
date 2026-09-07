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

      // Trigger registerForRemoteNotifications and refresh the APNs token.
      // OneSignal v5.x does not auto-register on iOS — without this call the
      // SDK will sit on a stale (or missing) token even when iOS permission
      // is already granted, and OneSignal eventually flags the subscription
      // invalid_identifier:true after APNs rejects a delivery. fallbackToSettings
      // is false so previously-denied users don't get hijacked into Settings.
      try {
        await OneSignal.Notifications.requestPermission(false);
      } catch (e) {
        debugPrint('OneSignal requestPermission failed: $e');
      }

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

    // Sent by the edge function alongside the copy it chose. Absent on any
    // push queued before copy variants existed — those report "unknown"
    // rather than being mislabelled as the current variant.
    final rawVariant = data['copy_variant']?.toString().trim();
    final copyVariant = (rawVariant == null || rawVariant.isEmpty)
        ? null
        : rawVariant;

    final payload = data['payload']?.toString();
    if (payload != null && payload.isNotEmpty) {
      _handleNotificationPayload(payload, copyVariant: copyVariant);
      return;
    }

    final activityId =
        data['activityId']?.toString() ??
        data['activity_id']?.toString() ??
        data['id']?.toString();
    if (activityId == null || activityId.isEmpty) return;

    final type = data['type']?.toString().trim();
    if (type != null && type.isNotEmpty) {
      _handleNotificationPayload('$type:$activityId', copyVariant: copyVariant);
      return;
    }

    _handleNotificationPayload(
      'activity:$activityId',
      copyVariant: copyVariant,
    );
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

  /// Splits a typed notification payload into its parts.
  ///
  /// Format is `"<type>:<activityId>"` with an optional third
  /// `"<copyVariant>"` segment. Two-segment payloads must keep parsing: every
  /// build before copy variants existed emitted them, and one sitting in a
  /// notification tray across an upgrade still has to navigate.
  ///
  /// Returns null for anything that isn't a typed payload — a bare activity
  /// id, an empty string, or a leading/trailing colon — which the caller
  /// treats as the legacy reminder format.
  @visibleForTesting
  static ({String type, String activityId, String? copyVariant})?
  parseTypedNotificationPayload(String payload) {
    if (payload.isEmpty) return null;

    final separatorIndex = payload.indexOf(':');
    if (separatorIndex <= 0 || separatorIndex >= payload.length - 1) {
      return null;
    }

    final type = payload.substring(0, separatorIndex);
    var activityId = payload.substring(separatorIndex + 1);
    String? copyVariant;

    final variantIndex = activityId.indexOf(':');
    if (variantIndex >= 0) {
      final parsedVariant = activityId.substring(variantIndex + 1);
      activityId = activityId.substring(0, variantIndex);
      copyVariant = parsedVariant.isEmpty ? null : parsedVariant;
    }

    if (activityId.isEmpty) return null;

    return (type: type, activityId: activityId, copyVariant: copyVariant);
  }

  /// [copyVariant] is supplied by the remote path, which reads it from the
  /// OneSignal data payload. Local notifications carry it as a third payload
  /// segment instead, since the tap arrives through the plugin as a bare
  /// string with no room for structured data. An explicitly passed value
  /// wins over a parsed one; both being absent reports "unknown".
  static void _handleNotificationPayload(
    String payload, {
    String? copyVariant,
  }) {
    if (payload.isEmpty) return;

    final parsed = parseTypedNotificationPayload(payload);
    if (parsed != null) {
      final type = parsed.type;
      final activityId = parsed.activityId;
      final payloadVariant = copyVariant ?? parsed.copyVariant;

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
            'copy_variant': payloadVariant ?? _unknownCopyVariant,
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
      // Mirror the grant into OneSignal so it registers for remote
      // notifications and uploads the APNs token. Without this, OneSignal
      // can stay on a stale token and APNs will eventually reject pushes,
      // causing OneSignal to flag the subscription invalid_identifier:true.
      // fallbackToSettings is true here because this method is called from
      // explicit user-driven flows (settings screen, onboarding) where
      // bouncing to Settings on prior denial is the expected UX.
      if (_isOneSignalInitialized) {
        try {
          await OneSignal.Notifications.requestPermission(true);
        } catch (e) {
          debugPrint('OneSignal requestPermission (explicit) failed: $e');
        }
      }
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

  /// Schedules a local notification. [id] names the slot: callers that
  /// keep several reminders alive at once (the meal-plan check-in and
  /// debrief) pass their own ids so one does not overwrite the other; the
  /// default keeps the legacy slots (1 recurring, 2 one-off).
  static Future<void> scheduleReminder({
    required DateTime scheduledDate,
    required bool recurring,
    required String title,
    required String body,
    String? activityId,
    int? id,
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
        id ?? 1,
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
        id ?? 2,
        title,
        body,
        scheduledTZ,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: activityId != null ? 'reminder:$activityId' : null,
      );
    }
  }

  /// Heading for the activity-uploaded notification.
  ///
  /// Must stay in lockstep with the OneSignal heading in
  /// `supabase/functions/_shared/garmin/onesignal.ts` — this local path and
  /// the remote push are mutually exclusive at runtime (see
  /// [isRemotePushConfigured]), so an athlete must get the same message
  /// either way.
  static const _activityUploadedTitle = 'Your targets just updated';

  /// Identifies which wording this notification was sent with, so
  /// click-through can be segmented by copy rather than inferred from a
  /// release date.
  ///
  /// Must stay in lockstep with `ACTIVITY_UPLOAD_COPY_VARIANT` in
  /// `supabase/functions/_shared/garmin/onesignal.ts`. Bump both whenever the
  /// heading or body changes.
  static const _activityUploadCopyVariant = 'accuracy_hook_v2';

  /// Reported when a click arrives with no variant attached — either a push
  /// sent before this field existed, or a legacy payload.
  static const _unknownCopyVariant = 'unknown';

  /// Shows an immediate local notification when a completed activity
  /// is uploaded from Garmin Connect (or another push-based provider).
  ///
  /// The copy leads with the retrospective recalculation rather than the
  /// upload itself: Garmin's measured energy expenditure re-runs the
  /// nutrition calculator, so the athlete's targets genuinely change.
  ///
  /// [provider] should be the human-readable provider label used in the
  /// notification body (e.g. "Garmin Connect"). The default matches
  /// Garmin's brand-compliant full name — never use an abbreviation.
  /// Garmin's Developer API Brand Guidelines require this attribution
  /// wherever Garmin-derived data is surfaced, so it stays in the body.
  static Future<void> showActivityUploadedNotification({
    required String activityId,
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
    // Body uses the short MM/DD form so a long device-model attribution
    // ("Garmin Forerunner 955") doesn't push the copy past the point iOS
    // truncates. Analytics below keeps the full MM/DD/YYYY form.
    final bodyDateText = '$month/$day';

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

    final body =
        'Your $provider workout is in. We recalculated your fuel plan for '
        '$bodyDateText from what you actually burned.';

    await _plugin.show(
      // Stable-ish positive int for this activity ID
      activityId.hashCode & 0x7fffffff,
      _activityUploadedTitle,
      body,
      notificationDetails,
      payload: 'activity:$activityId:$_activityUploadCopyVariant',
    );

    await _analytics.track(
      'activity_upload_notification_shown',
      properties: {
        'device_id': 'unknown',
        'activity_id': activityId,
        'provider': provider.toLowerCase(),
        'activity_date': activityDateText,
        'copy_variant': _activityUploadCopyVariant,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Cancels one scheduled slot by [id] (no-op on web, where nothing was
  /// scheduled).
  static Future<void> cancelReminder(int id) async {
    if (kIsWeb) return;
    if (!_isInitialized) {
      await initialize();
    }
    await _plugin.cancel(id);
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

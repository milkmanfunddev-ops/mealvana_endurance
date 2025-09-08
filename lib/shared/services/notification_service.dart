import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'analytics_service.dart';

/// Static notification service for managing local notifications
/// Handles iOS-specific notification scheduling for survey reminders
/// Also tracks North-Star metric events for reminder lifecycle
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static AnalyticsService? _analytics; // Analytics service for tracking
  
  /// Set analytics service for tracking North-Star metrics
  static void setAnalyticsService(AnalyticsService analytics) {
    _analytics = analytics;
  }
  
  /// Initialize the notification service
  /// Should be called during app startup
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize timezone data
    tz.initializeTimeZones();
    
    // iOS-specific initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Will request when needed
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    // Android settings (not used for now but keeping for future)
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
  
  /// Handle notification tap events
  static void _onNotificationTapped(NotificationResponse response) {
    print('🔔 DEBUG: Notification tapped: ${response.payload}');
    
    // Extract planId from payload and track North-Star event
    if (response.payload != null && _analytics != null) {
      try {
        final planId = response.payload!;
        _analytics!.trackPlanOpenedFromReminder(
          planId: planId,
          screen: 'Current Plan', // Will navigate to the current plan screen
        );
        print('📊 DEBUG: Tracked plan_opened_from_reminder for planId: $planId');
      } catch (e) {
        print('❌ DEBUG: Failed to track plan_opened_from_reminder: $e');
      }
    }
  }
  
  /// Request notification permissions (iOS specific)
  /// Returns true if permissions granted, false otherwise
  static Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        return await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ?? false;
      }
    }
    
    // For Android or if iOS plugin not available
    return false;
  }
  
  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final result = await iosPlugin.checkPermissions();
        return result?.isEnabled ?? false;
      }
    }
    
    return false;
  }
  
  /// Schedule a reminder notification for nutrition plan
  /// - scheduledDate: When to show the notification
  /// - recurring: Whether this should repeat weekly
  /// - title: Notification title
  /// - body: Notification message
  /// - planId: UUID v4 for North-Star metric tracking
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
    
    // Check if we have permission first
    final hasPermission = await areNotificationsEnabled();
    if (!hasPermission) {
      print('NotificationService: No permission to schedule notifications');
      return;
    }
    
    const notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    
    // Convert DateTime to TZDateTime
    final scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);
    
    // Track North-Star metric: reminder_set
    if (planId != null && _analytics != null) {
      try {
        await _analytics!.trackReminderSet(
          planId: planId,
          remindAtIso: scheduledDate.toIso8601String(),
        );
        print('📊 DEBUG: Tracked reminder_set for planId: $planId');
      } catch (e) {
        print('❌ DEBUG: Failed to track reminder_set: $e');
      }
    }
    
    if (recurring) {
      // Schedule weekly recurring notification
      await _plugin.zonedSchedule(
        1, // Notification ID for recurring reminders
        title,
        body,
        scheduledTZ,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: planId, // Include planId for tracking when tapped
      );
    } else {
      // Schedule one-time notification
      await _plugin.zonedSchedule(
        2, // Notification ID for one-time reminders
        title,
        body,
        scheduledTZ,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: planId, // Include planId for tracking when tapped
      );
    }
    
    print('🔔 DEBUG: Scheduled ${recurring ? 'recurring' : 'one-time'} reminder for $scheduledDate with planId: $planId');
  }
  
  /// Cancel all scheduled reminders
  static Future<void> cancelAllReminders() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    await _plugin.cancelAll();
    print('NotificationService: Cancelled all reminders');
  }
  
  /// Get list of pending notifications (for debugging)
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    return await _plugin.pendingNotificationRequests();
  }
  
  /// Track reminder_fired event for planId
  /// Call this when a reminder notification is delivered
  /// Since we can't detect actual delivery, this should be called when appropriate
  static Future<void> trackReminderFired(String planId) async {
    if (_analytics != null) {
      try {
        await _analytics!.trackReminderFired(planId: planId);
        print('📊 DEBUG: Tracked reminder_fired for planId: $planId');
      } catch (e) {
        print('❌ DEBUG: Failed to track reminder_fired: $e');
      }
    }
  }
}
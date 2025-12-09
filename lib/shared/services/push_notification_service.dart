import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'analytics/analytics_tracker.dart';

/// Service for managing OneSignal push notifications
///
/// Handles initialization, permission requests, user identification,
/// and notification event callbacks.
class PushNotificationService {
  static bool _isInitialized = false;
  static AnalyticsTracker _analytics = const NoopAnalyticsTracker();

  /// Callback for when a notification is tapped
  static void Function(String? payload)? onNotificationOpened;

  /// Configure analytics tracker for push notification events
  static void configure(AnalyticsTracker tracker) {
    _analytics = tracker;
  }

  /// Initialize OneSignal with the app ID
  ///
  /// This should be called early in the app lifecycle, typically in main.dart
  /// after other critical services are initialized.
  static Future<void> initialize(String appId) async {
    if (_isInitialized) return;
    if (appId.isEmpty) {
      debugPrint('PushNotificationService: No OneSignal App ID configured, skipping initialization');
      return;
    }

    // Enable verbose logging in debug mode
    if (kDebugMode) {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    }

    // Initialize OneSignal
    OneSignal.initialize(appId);

    // Set up notification opened handler
    OneSignal.Notifications.addClickListener((event) {
      _onNotificationOpened(event);
    });

    // Set up notification received handler (foreground)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      _onNotificationReceived(event);
    });

    _isInitialized = true;
    debugPrint('PushNotificationService: Initialized with app ID: ${appId.substring(0, 8)}...');
  }

  /// Request permission to send push notifications
  ///
  /// Returns true if permission was granted, false otherwise.
  /// On iOS, this shows the system permission dialog.
  /// On Android 13+, this shows the runtime permission dialog.
  static Future<bool> requestPermission() async {
    if (!_isInitialized) {
      debugPrint('PushNotificationService: Cannot request permission - not initialized');
      return false;
    }

    final granted = await OneSignal.Notifications.requestPermission(true);

    if (granted) {
      debugPrint('PushNotificationService: Permission granted');
    } else {
      debugPrint('PushNotificationService: Permission denied');
    }

    return granted;
  }

  /// Check if push notifications are currently enabled
  static bool get hasPermission {
    if (!_isInitialized) return false;
    return OneSignal.Notifications.permission;
  }

  /// Login user to OneSignal with their external ID
  ///
  /// This associates the device with the user for targeted notifications.
  /// Use the Supabase user ID or device ID as the external ID.
  static Future<void> login(String externalUserId) async {
    if (!_isInitialized) {
      debugPrint('PushNotificationService: Cannot login - not initialized');
      return;
    }

    await OneSignal.login(externalUserId);
    debugPrint('PushNotificationService: Logged in user: $externalUserId');
  }

  /// Logout current user from OneSignal
  ///
  /// This disassociates the device from the user.
  static Future<void> logout() async {
    if (!_isInitialized) {
      debugPrint('PushNotificationService: Cannot logout - not initialized');
      return;
    }

    await OneSignal.logout();
    debugPrint('PushNotificationService: Logged out');
  }

  /// Get the OneSignal subscription ID (push token)
  ///
  /// This can be stored in Supabase for server-side notifications.
  static Future<String?> getSubscriptionId() async {
    if (!_isInitialized) return null;
    return OneSignal.User.pushSubscription.id;
  }

  /// Get the OneSignal user ID
  static Future<String?> getOneSignalId() async {
    if (!_isInitialized) return null;
    return await OneSignal.User.getOnesignalId();
  }

  /// Add a tag to the user for segmentation
  ///
  /// Tags can be used to target specific users with notifications.
  static void addTag(String key, String value) {
    if (!_isInitialized) return;
    OneSignal.User.addTagWithKey(key, value);
  }

  /// Add multiple tags at once
  static void addTags(Map<String, String> tags) {
    if (!_isInitialized) return;
    OneSignal.User.addTags(tags);
  }

  /// Remove a tag from the user
  static void removeTag(String key) {
    if (!_isInitialized) return;
    OneSignal.User.removeTag(key);
  }

  /// Handle notification opened event
  static void _onNotificationOpened(OSNotificationClickEvent event) {
    final notification = event.notification;
    final additionalData = notification.additionalData;

    debugPrint('PushNotificationService: Notification opened - ${notification.title}');

    // Extract payload for navigation
    String? payload;
    if (additionalData != null) {
      // Look for activity_id or other navigation data
      payload = additionalData['activity_id']?.toString() ??
                additionalData['payload']?.toString();
    }

    // Track analytics
    _analytics.track(
      'push_notification_opened',
      properties: {
        'notification_id': notification.notificationId,
        'title': notification.title ?? '',
        'has_payload': payload != null,
      },
    );

    // Call the callback if set
    onNotificationOpened?.call(payload);
  }

  /// Handle notification received in foreground
  static void _onNotificationReceived(OSNotificationWillDisplayEvent event) {
    final notification = event.notification;

    debugPrint('PushNotificationService: Notification received - ${notification.title}');

    // Track analytics
    _analytics.track(
      'push_notification_received',
      properties: {
        'notification_id': notification.notificationId,
        'title': notification.title ?? '',
        'in_foreground': true,
      },
    );

    // Display the notification (default behavior)
    // Call event.preventDefault() to suppress the notification
    event.notification.display();
  }
}

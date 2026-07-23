import Flutter
import UIKit
import flutter_local_notifications
import MetricKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required for flutter_local_notifications
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // Note: we deliberately do NOT set UNUserNotificationCenter.current().delegate
    // here. FlutterAppDelegate already manages the delegate via the local
    // notifications and OneSignal plugins' swizzling — assigning self (which
    // doesn't conform to UNUserNotificationCenterDelegate) would silently
    // wipe that out via `as?` returning nil and break OneSignal's APNs token
    // capture path.

    GeneratedPluginRegistrant.register(with: self)

    // Subscribe to Apple MetricKit and forward payloads into Sentry. Passive
    // (iOS already collects this) — see MetricKitReporter.swift. Registered here
    // so we're subscribed before iOS delivers the launch-time daily payload;
    // Sentry itself is started later from Dart, which is fine (capture no-ops
    // until then).
    if #available(iOS 13.0, *) {
      MetricKitReporter.shared.register()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

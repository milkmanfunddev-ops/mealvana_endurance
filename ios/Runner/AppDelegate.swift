import Flutter
import UIKit
import flutter_local_notifications

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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

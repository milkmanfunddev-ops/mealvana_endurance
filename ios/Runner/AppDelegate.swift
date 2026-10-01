import Flutter
import UIKit
import UserNotifications
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

    // CLAIM THE NOTIFICATION DELEGATE, EARLY AND EXPLICITLY.
    //
    // Why this changed (2026-09-30). A notification tap that launched the app
    // from KILLED never reached Dart: the in-app recorder taped
    // `didNotificationLaunchApp=false payload=null` on a real device, which
    // means flutter_local_notifications never saw the response at all — not
    // that we routed it wrongly.
    //
    // The cause is the delegate chain. UNUserNotificationCenter has exactly
    // ONE delegate. OneSignal's iOS SDK swizzles it and FORWARDS to whatever
    // delegate was set BEFORE it initialises — but nothing was, because this
    // block previously set none at all. With no prior delegate to forward to,
    // the local-notification response had nowhere to go, and the plugin's
    // launch-details capture came up empty.
    //
    // Setting it here, before `GeneratedPluginRegistrant.register`, gives
    // OneSignal something to forward to. FlutterAppDelegate conforms to
    // UNUserNotificationCenterDelegate and relays to registered plugins.
    //
    // DIRECT ASSIGNMENT ON PURPOSE — no `as?`. The previous note worried that
    // casting would silently yield nil; a direct assignment turns that exact
    // risk into a COMPILE ERROR instead of a silent no-op, which is the whole
    // lesson of this bug.
    // REVERTED 2026-10-01. 08a0bb127 claimed this delegate; the tape proved the
    // claim TOOK and held, and it did NOT fix the killed-app tap — f24828e6a's
    // legacy-key consume did, and that path reads launchOptions and never
    // touches this delegate.
    //
    // Meanwhile the BACKGROUNDED tap, which worked on 1.28.0, stopped working.
    // The notification is scheduled legacy (UIConcreteLocalNotification), so a
    // backgrounded tap is delivered through the legacy response path, and
    // whatever used to carry it ran through a delegate chain this assignment
    // inserted itself into. Claiming a delegate we do not forward from is the
    // obvious way to break exactly that.
    //
    // So: give the chain back. The instrumentation below still records WHO
    // holds the delegate, which turns this revert into a measurement rather
    // than a guess — if backgrounded recovers, the claim was the regression.
    // CLAIM THE UN DELEGATE, BEFORE ONESIGNAL INITIALISES.
    //
    // Evidence (tapes, 2026-10-01): with no claim, `ios_delegate_at_launch` reads
    // OSUNUserNotificationCenterDelegate — OneSignal holds it, nothing of ours is
    // in the chain, and a BACKGROUNDED tap on our notification goes nowhere. The
    // legacy `application:didReceiveLocalNotification` door is never consulted
    // either, because UIKit only falls back to it when NO UN delegate exists.
    //
    // Claiming alone was ALSO not enough (08a0bb127): that build showed
    // ios_delegate_at_launch=AppDelegate and backgrounded still failed, which
    // says FlutterAppDelegate's own forwarding does not carry the response to
    // flutter_local_notifications. So we claim AND implement
    // `didReceive(response)` ourselves below — delegate plus door, not delegate
    // and hope.
    //
    // OneSignal's SDK forwards to whatever delegate preceded it, which is why
    // this is set BEFORE plugin registration and before OneSignal initialises
    // from Dart. Push delivery is the thing this could plausibly disturb, and
    // it is being explicitly re-tested before the cut.
    UNUserNotificationCenter.current().delegate = self

    GeneratedPluginRegistrant.register(with: self)

    // INSTRUMENTATION (2026-10-01). Four candidate fixes have now been refuted
    // on hardware while the tape kept reading didNotificationLaunchApp=false,
    // so this round tapes FACTS instead of proposing a fifth theory.
    //
    // Written into UserDefaults with the "flutter." prefix that
    // shared_preferences uses, so the Dart-side recorder reads them back and
    // shows them in the on-device dialog — no cable, no console, and it
    // survives release builds where print() is invisible.
    let defaults = UserDefaults.standard

    // Did iOS hand this launch a notification at all? If this is empty on a
    // tap-launch, the response is not arriving through the UIKit launch path
    // and no delegate work will ever surface it.
    let launchKeys = launchOptions?.keys.map { $0.rawValue }.joined(separator: ",") ?? "(none)"
    defaults.set(launchKeys, forKey: "flutter.ios_launch_options")

    // Did our assignment actually take, and who holds it now?
    let atLaunch = UNUserNotificationCenter.current().delegate
    defaults.set(
      atLaunch.map { String(describing: type(of: $0)) } ?? "(nil)",
      forKey: "flutter.ios_delegate_at_launch"
    )

    // THE LEGACY LAUNCH PATH — this is the actual bug (tape IMG_9145,
    // 2026-10-01). iOS hands a killed-app nudge tap to the app through
    // `UIApplicationLaunchOptionsLocalNotificationKey`, the UILocalNotification
    // route deprecated since iOS 10. flutter_local_notifications 19.4.1 is a
    // modern UN-based plugin: it never looks there, and legacy delivery never
    // fires the UN delegate callback either. That combination produces exactly
    // what four rounds of tape showed — didNotificationLaunchApp=false,
    // payload=null, and no callback line at all — while the payload sat in
    // launchOptions the entire time.
    //
    // So read it out and hand it to Dart. Everything downstream (hold, replay,
    // the intent table) already works; it was only ever starved of the tap.
    //
    // The raw class and userInfo are taped too: if the payload key is not
    // where we expect, the next tape says so in one glance instead of costing
    // another round.
    if let raw = launchOptions?[UIApplication.LaunchOptionsKey.localNotification] {
      defaults.set(String(describing: type(of: raw)), forKey: "flutter.ios_legacy_launch_class")

      var info: [AnyHashable: Any]?
      if let legacy = raw as? UILocalNotification {
        info = legacy.userInfo
      } else if let dict = raw as? [AnyHashable: Any] {
        info = dict
      }
      defaults.set(String(describing: info ?? [:]), forKey: "flutter.ios_legacy_launch_userinfo")

      // flutter_local_notifications carries our string under "payload".
      if let payload = info?["payload"] as? String, !payload.isEmpty {
        defaults.set(payload, forKey: "flutter.ios_legacy_launch_payload")
      }
    }

    // …and does anything re-claim it once OneSignal has initialised from Dart?
    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
      let later = UNUserNotificationCenter.current().delegate
      UserDefaults.standard.set(
        later.map { String(describing: type(of: $0)) } ?? "(nil)",
        forKey: "flutter.ios_delegate_after_delay"
      )
    }

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

  /// THE LIVE RESUME DOOR — a tap while the app is BACKGROUNDED.
  ///
  /// Since iOS 10 every notification response, including one for a
  /// legacy-scheduled notification, is delivered here when a UN delegate
  /// exists. We claim that delegate in didFinishLaunching, so this is the
  /// method that actually runs; the legacy `didReceiveLocalNotification`
  /// below is kept only as a belt-and-braces fallback for the case where
  /// something strips our claim.
  ///
  /// We extract the payload OURSELVES rather than trusting the chain to carry
  /// it: a build that claimed the delegate and relied on forwarding
  /// (08a0bb127) left backgrounded taps dead, which is the evidence that the
  /// forwarding does not reach flutter_local_notifications.
  ///
  /// `super` is still called, so anything else in the chain — OneSignal's
  /// handling of its OWN notifications in particular — keeps working.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let info = response.notification.request.content.userInfo
    let defaults = UserDefaults.standard
    defaults.set(String(describing: info), forKey: "flutter.ios_un_response_userinfo")
    if let payload = info["payload"] as? String, !payload.isEmpty {
      defaults.set(payload, forKey: "flutter.ios_un_response_payload")
    }
    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }

  /// THE LEGACY RESUME DOOR — the sibling of the launch-key fix.
  ///
  /// Our nudges are scheduled as UIConcreteLocalNotification (tape, 2026-10-01).
  /// A tap that LAUNCHES the app arrives in `launchOptions` and is handled in
  /// didFinishLaunching above. A tap while the app is merely BACKGROUNDED does
  /// not go there at all — it arrives here, through the UILocalNotification
  /// response method deprecated since iOS 10. Nothing implemented this, so a
  /// backgrounded tap resumed the app wherever it already was and went nowhere
  /// (observed: it "landed" on whatever tab was open).
  ///
  /// Same shape as the launch fix: lift the payload out, leave it where Dart
  /// collects it on resume, and let the existing dispatch do the rest.
  override func application(
    _ application: UIApplication,
    didReceive notification: UILocalNotification
  ) {
    let defaults = UserDefaults.standard
    let info = notification.userInfo ?? [:]
    defaults.set(String(describing: info), forKey: "flutter.ios_legacy_resume_userinfo")
    if let payload = info["payload"] as? String, !payload.isEmpty {
      defaults.set(payload, forKey: "flutter.ios_legacy_resume_payload")
    }
    super.application(application, didReceive: notification)
  }
}

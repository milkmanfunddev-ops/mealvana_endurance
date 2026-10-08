import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../utils/platform_io.dart'
    if (dart.library.html) '../utils/platform_web.dart';
import 'analytics/analytics_events.dart';
import 'launch_trail.dart';
import 'analytics/analytics_tracker.dart';
import 'device_info_service.dart';
import 'report/report.dart';

/// The slice of the OneSignal SDK [NotificationService] drives, behind a
/// seam so tests can see when the permission ask happens (mealplanning
/// tickets 79 and 138, backported by develop-2026-10 ticket 29). develop's
/// opt-out heal reads and flips the push subscription through it too.
abstract class RemotePushClient {
  /// Starts the SDK and wires tap and foreground-display handling.
  void start(String appId, void Function(Map<String, dynamic>) onClickData);

  /// Registers for remote notifications and refreshes the APNs token. On an
  /// install that has never answered, this raises the iOS prompt. Returns
  /// whether notifications are allowed afterwards.
  Future<bool> requestPermission({required bool fallbackToSettings});

  /// Whether the OS currently allows notifications for this app.
  Future<bool> permissionGranted();

  /// The SDK's push-subscription opt state; null until it has hydrated.
  bool? get optedIn;

  /// Flips the SDK opt state back on (promptless when permission is held).
  Future<void> optIn();

  void login(String externalId);
  void logout();
}

class OneSignalRemotePush implements RemotePushClient {
  const OneSignalRemotePush();

  @override
  void start(String appId, void Function(Map<String, dynamic>) onClickData) {
    OneSignal.initialize(appId);
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data == null) return;
      onClickData(data);
    });

    // Show push banners while the app is in the foreground. Without this,
    // iOS suppresses the alert entirely when Mealvana is open.
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.preventDefault();
      event.notification.display();
    });
  }

  @override
  Future<bool> requestPermission({required bool fallbackToSettings}) =>
      OneSignal.Notifications.requestPermission(fallbackToSettings);

  @override
  Future<bool> permissionGranted() async {
    final native = await OneSignal.Notifications.permissionNative();
    return native == OSNotificationPermission.authorized ||
        native == OSNotificationPermission.provisional ||
        native == OSNotificationPermission.ephemeral;
  }

  @override
  bool? get optedIn => OneSignal.User.pushSubscription.optedIn;

  @override
  Future<void> optIn() => OneSignal.User.pushSubscription.optIn();

  @override
  void login(String externalId) => OneSignal.login(externalId);

  @override
  void logout() => OneSignal.logout();
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static bool _isOneSignalInitialized = false;
  static bool _remotePushRegistered = false;
  static String? _pendingNavigationActivityId;
  static String? _pendingNavigationType;
  static String? _pendingRemoteUserId;
  static String? _lastSyncedRemoteUserId;
  static void Function(String activityId, String? type)? _navigationHandler;
  static Future<void> Function(DateTime date)? _dailyMacroCacheInvalidator;
  static AnalyticsTracker _analytics = const NoopAnalyticsTracker();
  static String _oneSignalAppId = '';

  /// Where the analytics events below get their `device_id`: the device id
  /// `app_opened` sends (ticket 70). Handed in by [configure] from
  /// `deviceInfoServiceProvider`; null falls back to the same singleton.
  /// Events only leave the device once [configure] has run, which the
  /// startup chain does after `deferred.device_info`, so the id is the
  /// initialized one by then.
  static DeviceInfoService? _deviceInfo;
  static String get _analyticsDeviceId =>
      (_deviceInfo ?? DeviceInfoService.instance).deviceId;

  /// Where every swallowed failure and silent bail in the push path goes
  /// (area `push`, whose Notes rule D9 promotes to warning events). Null means
  /// [SentryReport.global]; tests inject a recording fake.
  static Report? _report;
  static Report get _r => _report ?? SentryReport.global;

  @visibleForTesting
  static void debugSetReport(Report? report) {
    _report = report;
  }

  /// Receives the OS's answer to the notification ask, and any later change
  /// seen on app resume (ticket 138, Finding 125-004). The startup flow
  /// wires it to `users.notifications_enabled` through the user repository.
  static Future<void> Function(bool granted)? _onPermissionAnswer;
  static bool? _lastReportedPermission;
  static AppLifecycleListener? _resumeListener;

  @visibleForTesting
  static RemotePushClient remotePush = const OneSignalRemotePush();

  /// Time this process has spent awaiting the OS notification prompt
  /// (`requestPermission(false)` in [_registerForRemotePush]). On an install
  /// that has never answered, that call returns only when the athlete taps,
  /// so the startup timer for `deferred.notifications` leaves it out of its
  /// slow checks (develop-2026-10 ticket 22, 08-009). Grows only.
  static Duration get permissionPromptWait => _permissionPromptWait;
  static Duration _permissionPromptWait = Duration.zero;

  /// Returns the static state to a fresh launch, for tests.
  @visibleForTesting
  static void debugReset() {
    _isInitialized = false;
    _isOneSignalInitialized = false;
    _remotePushRegistered = false;
    _pendingNavigationActivityId = null;
    _pendingNavigationType = null;
    _pendingRemoteUserId = null;
    _lastSyncedRemoteUserId = null;
    _navigationHandler = null;
    _dailyMacroCacheInvalidator = null;
    _analytics = const NoopAnalyticsTracker();
    _deviceInfo = null;
    _oneSignalAppId = '';
    _onPermissionAnswer = null;
    _lastReportedPermission = null;
    _resumeListener?.dispose();
    _resumeListener = null;
    remotePush = const OneSignalRemotePush();
    _permissionPromptWait = Duration.zero;
  }

  /// A guard bail in the push path, written down (rule D9): the tape for the
  /// device, a breadcrumb for the next Sentry event.
  static void _trailBail(String line) {
    LaunchTrail.add(line);
    _r.breadcrumb(line, category: 'push');
  }

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
    Future<void> Function(bool granted)? onPermissionAnswer,
    DeviceInfoService? deviceInfo,
  }) {
    _analytics = tracker;
    if (deviceInfo != null) _deviceInfo = deviceInfo;
    configureRemotePush(oneSignalAppId: oneSignalAppId);
    if (onPermissionAnswer != null) {
      configurePermissionAnswer(onPermissionAnswer);
    }
  }

  /// Where the OS's answer to the notification ask goes (ticket 138, Finding
  /// 125-004), and the resume watch that follows later changes made in iOS
  /// Settings. Separate from [configure] because that one waits for
  /// analytics consent, and storing the answer is not tracking.
  static void configurePermissionAnswer(
    Future<void> Function(bool granted) onPermissionAnswer,
  ) {
    _onPermissionAnswer = onPermissionAnswer;
    if (_resumeListener == null) {
      try {
        // A change made in iOS Settings shows up on the next resume.
        _resumeListener = AppLifecycleListener(
          onResume: () => unawaited(refreshPermission()),
        );
      } catch (_) {
        // No widgets binding (tests without one): resume is not watched.
        _trailBail('notification permission: resume not watched (no binding)');
      }
    }
  }

  /// Re-reads the OS permission and reports it when it differs from the last
  /// answer reported this launch. Safe to run twice at once: both read the
  /// same value and the second finds nothing new.
  static Future<void> refreshPermission() async {
    if (kIsWeb || !_isOneSignalInitialized || _onPermissionAnswer == null) {
      _trailBail(
        'notification permission re-read skipped: '
        'web=$kIsWeb oneSignal=$_isOneSignalInitialized '
        'handler=${_onPermissionAnswer != null}',
      );
      return;
    }
    // The answer belongs to a signed-in athlete; nobody attached, nothing
    // to store.
    if (_pendingRemoteUserId == null) {
      _trailBail('notification permission re-read skipped: no athlete id');
      return;
    }
    try {
      final granted = await remotePush.permissionGranted();
      await _reportPermission(granted);
    } catch (e, st) {
      await _r.degraded(
        e,
        stackTrace: st,
        area: 'push',
        message: 'notification permission re-read failed',
      );
    }
  }

  static Future<void> _reportPermission(bool granted) async {
    if (_lastReportedPermission == granted) return;
    _lastReportedPermission = granted;
    LaunchTrail.add('notification permission answer: granted=$granted');
    try {
      await _onPermissionAnswer?.call(granted);
    } catch (e, st) {
      await _r.fault(
        e,
        stackTrace: st,
        area: 'push',
        message: 'storing the notification permission answer failed',
      );
    }
  }

  /// Hands the OneSignal app id to this service — and, if `initialize()` has
  /// ALREADY run without one, arms OneSignal right now instead of silently
  /// keeping the dead state.
  ///
  /// WHY THIS EXISTS (patch #3, 2026-10-03 — the fleet-wide silent-SDK bug).
  /// The 1.29.0 startup reorder (2c63d3e26) made `deferred.notifications` the
  /// FIRST deferred step, which is load-bearing for the launch payload — but
  /// the app id used to arrive via `configure()` inside `deferred.analytics`,
  /// two steps LATER. So `_initializeOneSignal()` always saw an empty app id,
  /// bailed, and nothing ever retried: no user, no login, no permission
  /// prompt, no heal — on every fresh 1.29.0 install, fleet-wide, invisibly.
  /// Two days of device forensics (reinstalls, reboot, keychain theories)
  /// were spent on what was an ordering bug in our own chain.
  ///
  /// The fix is TWO-SIDED so step order can never disarm push again:
  /// the startup chain now passes the app id BEFORE `initialize()` runs
  /// (app_startup_service, deferred.notifications), AND this method arms
  /// OneSignal itself whenever the id arrives after the fact. Either side
  /// alone closes the bug; together, no future reorder reopens it.
  static void configureRemotePush({required String oneSignalAppId}) {
    _oneSignalAppId = oneSignalAppId.trim();
    if (_isInitialized &&
        !_isOneSignalInitialized &&
        _oneSignalAppId.isNotEmpty &&
        !kIsWeb) {
      LaunchTrail.add(
        'onesignal: app id arrived AFTER initialize() — arming now '
        '(ordering guard, patch #3)',
      );
      unawaited(_initializeOneSignal());
    }
  }

  static bool get isRemotePushConfigured => _oneSignalAppId.isNotEmpty;

  /// Test seams for the patch-#3 ordering guard. `initialize()` cannot run in
  /// a unit test (flutter_local_notifications needs a platform), so tests
  /// simulate its completed state and drive the OneSignal arm directly.
  @visibleForTesting
  static void debugMarkInitializedForTest({bool oneSignal = false}) {
    _isInitialized = true;
    _isOneSignalInitialized = oneSignal;
  }

  @visibleForTesting
  static Future<void> debugInitializeOneSignal() => _initializeOneSignal();

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

    LaunchTrail.add('plugin.initialize() starting (handler not yet attached)');
    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    LaunchTrail.add('plugin.initialize() done (handler attached)');

    // Handle cold-start launches from notification taps.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    // The cold-start seam. Until this line runs, a tap that launched the app
    // does not exist to us; logging what it returned is the only way to tell
    // "no tap" from "tap we never read".
    LaunchTrail.add(
      'launchDetails didNotificationLaunchApp='
      '${launchDetails?.didNotificationLaunchApp} '
      'payload=${launchDetails?.notificationResponse?.payload}',
    );
    final launchResponse = launchDetails?.notificationResponse;
    final launchPayload = launchResponse?.payload;
    // THE LEGACY LAUNCH FALLBACK. On iOS the tap can arrive through the
    // deprecated UILocalNotification launch key instead of the UN path, in
    // which case `launchDetails` is empty and no callback ever fires — see
    // AppDelegate. The payload is lifted out there; consume it here so the
    // rest of the chain is unchanged.
    //
    // CONSUMED, not merely read: the key is cleared immediately, or every
    // subsequent cold start would re-navigate to a workout the athlete
    // already dealt with days ago.
    if (launchDetails?.didNotificationLaunchApp != true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final legacy = prefs.getString('ios_legacy_launch_payload');
        if (legacy != null && legacy.isNotEmpty) {
          await prefs.remove('ios_legacy_launch_payload');
          LaunchTrail.add('legacy_launch payload=$legacy (consumed)');
          _handleNotificationPayload(legacy);
          _isInitialized = true;
          return;
        }
      } catch (e, st) {
        LaunchTrail.add('legacy_launch read failed: $e');
        await _r.fault(
          e,
          stackTrace: st,
          area: 'push',
          message: 'legacy iOS launch payload could not be read',
        );
      }
    }

    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _handleNotificationPayload(launchPayload);
    }

    await _initializeOneSignal();

    _isInitialized = true;
  }

  static Future<void> _initializeOneSignal() async {
    if (_isOneSignalInitialized || kIsWeb) {
      return;
    }
    if (_oneSignalAppId.isEmpty) {
      // THE SILENT PATH THAT HID THE FLEET BUG FOR TWO DAYS (2026-10-01→03):
      // this bail is correct behavior, but leaving no trace made "SDK wedged
      // on-device" and "we never gave it an app id" indistinguishable from
      // outside. If this line appears WITHOUT a later "arming now" line, the
      // startup chain is misordered again.
      LaunchTrail.add(
        'onesignal init: SKIPPED — no app id configured yet '
        '(configureRemotePush() will arm when it arrives)',
      );
      // The tape is dev-readable; the Note is the PROD-readable half (D9),
      // promoted to a warning event because the area is `push`.
      await _r.note(
        'onesignal init skipped: no app id configured yet',
        area: 'push',
        data: {'initialized': _isInitialized},
      );
      return;
    }

    try {
      remotePush.start(_oneSignalAppId, _handleRemoteNotificationData);

      // No permission request here: this runs in deferred startup, before
      // Welcome or sign-in, and on an install that has never answered the
      // request IS the iOS prompt (mealplanning ticket 79, Finding 03-004).
      // The APNs registration it also performs, and the opt-out heal that
      // reads its answer, wait for an athlete's id; see
      // [_registerForRemotePush].
      LaunchTrail.add(
        'onesignal started; permission ask + heal wait for an athlete id',
      );
      _isOneSignalInitialized = true;
      await _syncRemotePushUserIdentity();
    } catch (e, st) {
      await _r.fault(
        e,
        stackTrace: st,
        area: 'push',
        message: 'OneSignal init failed',
      );
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
  ///
  /// A NULL/empty id here means "we do not know who this is YET" — it does
  /// NOT mean the athlete signed out, and it must never detach the alias.
  /// Startup calls this with `auth.currentUser?.id`, which is null whenever
  /// the Supabase session has not finished restoring (offline launch, refresh
  /// in flight). Detaching there stranded real athletes: a restored session
  /// emits `initialSession`/`tokenRefreshed`, never `signedIn`, so nothing
  /// re-attached the alias and every server push came back
  /// `invalid_aliases` — silently, because OneSignal answers 200.
  /// Measured 2026-09-22 on prod: 5 of 14 Garmin-active athletes unreachable.
  ///
  /// Use [clearRemotePushUserId] for a real sign-out.
  static Future<void> setRemotePushUserId(String? userId) async {
    final normalized = userId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    _pendingRemoteUserId = normalized;

    if (!_isInitialized || !_isOneSignalInitialized) {
      return;
    }

    await _syncRemotePushUserIdentity();
  }

  /// The id this device will claim in OneSignal on the next sync.
  ///
  /// Exposed so the regression test can prove a null from an unrestored
  /// session does not wipe it — the failure that left athletes unreachable.
  @visibleForTesting
  static String? get pendingRemotePushUserId => _pendingRemoteUserId;

  /// Detach this device from the athlete's OneSignal alias — sign-out ONLY.
  ///
  /// Split out from [setRemotePushUserId] so that "no id available yet" can
  /// never reach `OneSignal.logout()`.
  static Future<void> clearRemotePushUserId() async {
    _pendingRemoteUserId = null;

    if (!_isInitialized || !_isOneSignalInitialized) {
      return;
    }

    await _syncRemotePushUserIdentity();
  }

  static Future<void> _syncRemotePushUserIdentity() async {
    if (!_isOneSignalInitialized || kIsWeb) return;

    final targetUserId = _pendingRemoteUserId;
    if (targetUserId != _lastSyncedRemoteUserId) {
      try {
        if (targetUserId == null) {
          remotePush.logout();
        } else {
          remotePush.login(targetUserId);
        }
        _lastSyncedRemoteUserId = targetUserId;
      } catch (e, st) {
        // An unsynced alias is the `invalid_aliases` bug: every server push
        // to this athlete fails while OneSignal answers 200.
        await _r.fault(
          e,
          stackTrace: st,
          area: 'push',
          message: 'OneSignal user identity sync failed',
          extra: {'detach': targetUserId == null},
        );
      }
    }

    if (targetUserId != null) await _registerForRemotePush();
  }

  /// Triggers registerForRemoteNotifications and refreshes the APNs token,
  /// once per launch, as soon as an athlete's id is attached to the device:
  /// right after sign-in, or at launch for a restored session. OneSignal
  /// v5.x does not auto-register on iOS; without this call the SDK sits on a
  /// stale (or missing) token even when iOS permission is already granted,
  /// and OneSignal eventually flags the subscription invalid_identifier:true
  /// after APNs rejects a delivery.
  ///
  /// On an install that has never answered, this is also where iOS asks:
  /// after sign-in, never over the splash (mealplanning ticket 79).
  /// fallbackToSettings is false so previously-denied athletes don't get
  /// hijacked into Settings. The answer is stored (ticket 138, Finding
  /// 125-004) through [_onPermissionAnswer]; a later change in iOS Settings
  /// is picked up by [refreshPermission] on resume.
  ///
  /// develop's opt-out heal (2026-10-01) moved here with the ask, since it
  /// reads the ask's answer: it now runs once per launch with an athlete
  /// attached instead of at every OneSignal start.
  static Future<void> _registerForRemotePush() async {
    if (_remotePushRegistered) return;
    _remotePushRegistered = true;
    try {
      final promptWatch = Stopwatch()..start();
      final granted = await remotePush.requestPermission(
        fallbackToSettings: false,
      );
      promptWatch.stop();
      _permissionPromptWait += promptWatch.elapsed;
      // Written down (D9): how long the ask held this launch, next to the
      // heal lines; the startup timer leaves this time out (08-009).
      final waitLine =
          'permission prompt wait ${promptWatch.elapsedMilliseconds}ms '
          'granted=$granted';
      LaunchTrail.add(waitLine);
      _r.breadcrumb(waitLine, category: 'push');
      await _reportPermission(granted);

      // HEAL THE ONE-WAY OPT-OUT DOOR (2026-10-01, the unreachable-player
      // Critical's mechanism — a player with a VALID APNs token but
      // enabled=false / notification_types=-30, i.e. SDK-level opted out).
      //
      // The app's only optOut() lives in the settings reset button, whose
      // own comment admits its optOut→optIn sequence can race; and until
      // this line, NOTHING outside that same button ever called optIn().
      // So a device that ever landed opted out — through the race, or
      // through SDK state inherited from an older install — stayed
      // unreachable forever, every session faithfully re-reporting
      // enabled=false on a perfectly good token.
      //
      // The permission gate is load-bearing, not hygiene: the SDK's optIn()
      // "will prompt the user for push notifications permission" when it is
      // missing, and this ask deliberately never hijacks previously-denied
      // users (fallbackToSettings: false above). With permission granted,
      // optIn() only flips the opt flag — idempotent, promptless, and it
      // silently heals the fleet on next app open.
      //
      // `optedIn == false` on purpose (it is a bool?): null means the SDK
      // has not reported state yet — do nothing on unknown; the next launch
      // sees cached state and heals then.
      // THE READ MUST WAIT FOR HYDRATION (patch #2's lesson, 2026-10-01).
      // This app calls OneSignal.initialize() without await, and the Dart
      // side hydrates `optedIn` inside initialize's own lifecycle futures on
      // a DIFFERENT method channel than requestPermission — so a one-shot
      // read here can land before hydration, see null, and skip the heal
      // deterministically on fast launches. Poll briefly instead: bounded at
      // ~3s, exits on first non-null, and still never acts on unknown.
      var optedIn = remotePush.optedIn;
      var waitedMs = 0;
      while (optedIn == null && waitedMs < 3000) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        waitedMs += 300;
        optedIn = remotePush.optedIn;
      }

      // TAPED, NOT debugPrint'd — the first patch's heal was invisible in
      // release, which made "patch not applied" and "heal did not fire"
      // indistinguishable from outside: the silent-path rule biting the fix
      // that exists because of the silent-path rule. The tape answers, on
      // the device, with nothing attached: did it run, what did it read,
      // what did it do, what was the state afterwards.
      LaunchTrail.add(
        'push heal: permission=$granted optedIn=$optedIn '
        '(hydration wait ${waitedMs}ms)',
      );
      if (shouldHealPushOptOut(permissionGranted: granted, optedIn: optedIn)) {
        await remotePush.optIn();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        LaunchTrail.add(
          'push heal: optIn() called → post optedIn=${remotePush.optedIn}',
        );
      } else {
        LaunchTrail.add('push heal: no action');
      }
    } catch (e, st) {
      // Permission + heal is the opt-out door; a failure here leaves a
      // device with a valid token unreachable.
      await _r.fault(
        e,
        stackTrace: st,
        area: 'push',
        message: 'OneSignal requestPermission / opt-out heal failed',
      );
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
    // CALLBACK ENTRY. If this line ever appears on a killed-app tap, the
    // response IS being delivered and the launch-details path is simply the
    // wrong door — the fix would then be to hold from here. If it never
    // appears, iOS delivered the tap to nobody.
    LaunchTrail.add(
      'onDidReceiveNotificationResponse payload=${response.payload} '
      'actionId=${response.actionId} type=${response.notificationResponseType}',
    );
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
  /// Test entry point for the tap dispatch (G29). The plugin delivers taps
  /// through a private callback, so the analytics branches are otherwise
  /// unreachable from a unit test.
  @visibleForTesting
  static void handleNotificationPayloadForTest(
    String payload, {
    String? copyVariant,
  }) => _handleNotificationPayload(payload, copyVariant: copyVariant);

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
          deviceId: _analyticsDeviceId,
          activityId: activityId,
        );
      } else if (type == 'carb_event') {
        // G29: the race-window carb-load nudge's tap. `activityId` carries
        // the EVENT id here (the payload parser is type-agnostic). Headline
        // metric for this CTA is scheduled -> tapped, so this is the
        // measured half of it; conversion is a server-side join against
        // carb_loading_plans, never a client event (qa pin 2026-09-27).
        _analytics.track(
          'notif_tapped',
          properties: {
            'cta': 'carb_load',
            'cta_transport': 'local',
            'event_id': activityId,
          },
        );
      } else if (type == 'activity') {
        _analytics.track(
          'activity_upload_notification_clicked',
          properties: {
            'device_id': _analyticsDeviceId,
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
      deviceId: _analyticsDeviceId,
      activityId: payload,
    );
    _dispatchNavigation(payload, null);
  }

  static void _dispatchNavigation(String activityId, String? type) {
    final handler = _navigationHandler;
    LaunchTrail.add(
      'dispatch id=$activityId type=$type handlerSet=${handler != null}',
    );
    if (handler != null) {
      handler(activityId, type);
      return;
    }
    _pendingNavigationActivityId = activityId;
    _pendingNavigationType = type;
  }

  /// Collect a legacy BACKGROUNDED tap, if iOS left one for us.
  ///
  /// The launch path is handled in [initialize]; this is its resume sibling.
  /// Called from the root widget on every foreground resume, because a
  /// backgrounded tap produces no new launch and so never reaches
  /// `getNotificationAppLaunchDetails`.
  ///
  /// CONSUMED, like the launch key: cleared the instant it is read, or every
  /// later resume would re-navigate off a tap the athlete made once.
  static Future<void> consumeLegacyResumeTap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Two doors can leave a backgrounded tap here, and which one fired is
      // the attribution the next tape needs:
      //   ios_un_response_payload  — the LIVE door (UN delegate we claim)
      //   ios_legacy_resume_payload — the legacy fallback, only consulted by
      //                               UIKit when no UN delegate exists
      for (final key in const [
        'ios_un_response_payload',
        'ios_legacy_resume_payload',
      ]) {
        final payload = prefs.getString(key);
        if (payload == null || payload.isEmpty) continue;
        await prefs.remove(key);
        LaunchTrail.add('$key payload=$payload (consumed)');
        _handleNotificationPayload(payload);
        return;
      }
    } catch (e, st) {
      LaunchTrail.add('legacy_resume read failed: $e');
      await _r.fault(
        e,
        stackTrace: st,
        area: 'push',
        message: 'legacy iOS resume payload could not be read',
      );
    }
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
          await remotePush.requestPermission(fallbackToSettings: true);
        } catch (e, st) {
          await _r.fault(
            e,
            stackTrace: st,
            area: 'push',
            message: 'OneSignal requestPermission (explicit) failed',
          );
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

  /// The heal decision for an SDK-level push opt-out, kept pure so the rule
  /// is testable without the OneSignal static SDK: heal exactly when the OS
  /// permission is granted AND the SDK explicitly reports opted out. Never on
  /// unknown (null) state, and never without permission — optIn() would
  /// prompt, and previously-denied users are deliberately left alone.
  @visibleForTesting
  static bool shouldHealPushOptOut({
    required bool permissionGranted,
    required bool? optedIn,
  }) {
    return permissionGranted && optedIn == false;
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
        deviceId: _analyticsDeviceId,
        activityId: activityId,
        reminderTime: scheduledDate,
      );

      // Also track as scheduled (proxy for delivery)
      await _analytics.trackReminderScheduled(
        deviceId: _analyticsDeviceId,
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
        'device_id': _analyticsDeviceId,
        'activity_id': activityId,
        'provider': provider.toLowerCase(),
        'activity_date': activityDateText,
        'copy_variant': _activityUploadCopyVariant,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// G27 — the race-window carb-load nudge's channel/details. Same posture
  /// as nutrition-plan reminders; the ids, timing and copy come from
  /// CarbNudgeEngine via CarbLoadNudgeService — this layer only delivers.
  static const _carbNudgeDetails = NotificationDetails(
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

  /// Schedules one carb-load nudge fire (G27). Silent no-op without
  /// permission or on web, matching [scheduleReminder].
  static Future<void> scheduleCarbNudge({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    required String payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    if (kIsWeb) return;
    if (!await areNotificationsEnabled()) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(fireAt, tz.local),
      _carbNudgeDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Shows the carb-load nudge immediately (G27's on-open catch-up path).
  static Future<void> showCarbNudge({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    if (kIsWeb) return;
    if (!await areNotificationsEnabled()) return;

    await _plugin.show(id, title, body, _carbNudgeDetails, payload: payload);
  }

  /// Cancels one scheduled local notification by id (G27 disarm path).
  static Future<void> cancelById(int id) async {
    if (!_isInitialized) {
      await initialize();
    }
    if (kIsWeb) return;
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

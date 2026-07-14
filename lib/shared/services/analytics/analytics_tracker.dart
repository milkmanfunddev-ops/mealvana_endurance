import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../device_info_service.dart';
import '../logging_service.dart';
import '../privacy/analytics_consent.dart';
import 'internal_user_service.dart';

/// Abstraction over analytics tracking so we can swap implementations in tests.
abstract class AnalyticsTracker {
  Future<void> initialize();
  Future<void> identifyUser(
    String userId, {
    Map<String, dynamic>? properties,
    String? gender,
    int? age,
    double? weightPounds,
    bool? runsWithWaterBottle,
    String? gutTrainingLevel,
  });
  Future<void> resetUser();
  Future<void> track(String eventName, {Map<String, dynamic>? properties});
  Future<void> timeEvent(String eventName);
  Future<void> flush();

  /// Flag the current Mixpanel profile as an internal/test device so that
  /// historical events can be filtered out in the dashboard.
  ///
  /// Sets People property `is_internal = true` and flushes immediately. Called
  /// when the "Mark this device as internal" toggle is switched on: the
  /// `is_internal` *super property* is only registered at Mixpanel init, so
  /// without this the profile would stay unflagged until the next launch.
  /// No-op on [NoopAnalyticsTracker].
  Future<void> markInternal();
}

/// Default tracker that talks to Mixpanel.
class MixpanelAnalyticsTracker implements AnalyticsTracker {
  MixpanelAnalyticsTracker({required AppConfig config, AppLogger? logger})
    : _config = config,
      _logger = logger ?? const NoopAppLogger();

  final AppConfig _config;
  final AppLogger _logger;

  Mixpanel? _mixpanel;
  bool _isInitialized = false;

  /// Pref key gating [anonymous_user_identified] to once per device.
  static const String _anonIdentifiedKey = 'analytics_anonymous_identified';
  SharedPreferences? _prefs;

  Future<SharedPreferences?> _preferences() async {
    if (_prefs != null) return _prefs;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (error) {
      // Prefs unavailable (e.g. platform channel not ready): degrade to
      // un-gated behavior rather than dropping analytics.
      _logger.warning(
        'SharedPreferences unavailable for analytics gating: $error',
        context: 'ANALYTICS',
      );
    }
    return _prefs;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Use Mixpanel token from AppConfig
      _mixpanel = await Mixpanel.init(
        _config.mixpanelProjectToken,
        trackAutomaticEvents: false,
      );

      await _setupSuperProperties();

      _isInitialized = true;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to initialize Mixpanel',
        context: 'ANALYTICS',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> identifyUser(
    String userId, {
    Map<String, dynamic>? properties,
    String? gender,
    int? age,
    double? weightPounds,
    bool? runsWithWaterBottle,
    String? gutTrainingLevel,
  }) async {
    final mixpanel = _mixpanel;
    if (mixpanel == null) return;

    try {
      mixpanel.identify(userId);
      final people = mixpanel.getPeople();

      if (properties != null && properties.isNotEmpty) {
        properties.forEach((key, value) {
          if (value != null) {
            people.set(key, value);
          }
        });
        people.setOnce('First Seen', DateTime.now().toIso8601String());
        await track('user_identified', properties: properties);
      } else if (gender != null || age != null || weightPounds != null) {
        if (gender != null) people.set('Gender', gender);
        if (age != null) people.set('Age', age);
        if (weightPounds != null) people.set('Weight (lbs)', weightPounds);
        if (runsWithWaterBottle != null) {
          people.set('Runs With Water Bottle', runsWithWaterBottle);
        }
        if (gutTrainingLevel != null) {
          people.set('Gut Training Level', gutTrainingLevel);
        }
        people.setOnce('First Seen', DateTime.now().toIso8601String());
        await track(
          'user_identified',
          properties: {
            'gender': gender,
            'age': age,
            'weight_lbs': weightPounds,
            'runs_with_water_bottle': runsWithWaterBottle,
            'gut_training_level': gutTrainingLevel,
          },
        );
      } else {
        // Fire the anonymous-identity event once per device, not on every
        // cold start — repeated fires inflate event counts and re-stamp the
        // people profile for no analytical value. The flag is cleared in
        // resetUser() so a fresh identity after sign-out is re-marked.
        final prefs = await _preferences();
        final alreadyIdentified = prefs?.getBool(_anonIdentifiedKey) ?? false;
        if (!alreadyIdentified) {
          people.setOnce('First Seen', DateTime.now().toIso8601String());
          people.set('User Type', 'Anonymous');
          await track(
            'anonymous_user_identified',
            properties: {'device_id': userId},
          );
          await prefs?.setBool(_anonIdentifiedKey, true);
        }
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to identify user',
        context: 'ANALYTICS',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> resetUser() async {
    final mixpanel = _mixpanel;
    if (mixpanel == null) return;

    try {
      await track('user_reset');
      mixpanel.reset();
      // The next identity on this device is a new anonymous profile — allow
      // anonymous_user_identified to fire again for it.
      final prefs = await _preferences();
      await prefs?.remove(_anonIdentifiedKey);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to reset analytics user',
        context: 'ANALYTICS',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> track(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async {
    // Dev-only echo: lets engineers verify event names + payloads from the
    // simulator console without needing Mixpanel access. Stripped in prod
    // so we don't add log volume to release builds.
    if (_config.devModeEnabled) {
      _logger.info('📊 $eventName', context: 'ANALYTICS', data: properties);
    }

    final mixpanel = _mixpanel;
    if (mixpanel == null) return;

    try {
      mixpanel.track(eventName, properties: properties);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to track event $eventName',
        context: 'ANALYTICS',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> timeEvent(String eventName) async {
    final mixpanel = _mixpanel;
    if (mixpanel == null) return;

    try {
      mixpanel.timeEvent(eventName);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to time event $eventName',
        context: 'ANALYTICS',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> flush() async {
    final mixpanel = _mixpanel;
    if (mixpanel == null) return;

    try {
      mixpanel.flush();
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to flush analytics events',
        context: 'ANALYTICS',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Flag this device as internal so historical events can be filtered in the
  /// Mixpanel dashboard. Sets `is_internal = true` on the People profile and
  /// flushes immediately.
  ///
  /// Must be called **before** suppressing analytics (before setting the
  /// excluded pref) so the People update still reaches Mixpanel.
  @override
  Future<void> markInternal() async {
    final mixpanel = _mixpanel;
    if (mixpanel == null) return;

    try {
      final people = mixpanel.getPeople();
      people.set('is_internal', true);
      mixpanel.flush();
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to mark device as internal in Mixpanel',
        context: 'ANALYTICS',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _setupSuperProperties() async {
    final mixpanel = _mixpanel;
    if (mixpanel == null) return;

    try {
      // Use the shared DeviceInfoService (already initialized before parallel ops)
      final deviceInfoService = DeviceInfoService.instance;
      final deviceInfo = deviceInfoService.isInitialized
          ? deviceInfoService.deviceInfo
          : {'os_version': 'unknown', 'device_model': 'unknown'};

      // Derive the real app version from PackageInfo so this stays accurate
      // across releases without requiring a code change.
      String appVersion = 'unknown';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
      } catch (_) {
        // Fallback handled above; analytics should not crash the app.
      }

      // Registered as a SUPER property (not just a People property) so it is
      // attached to every event from the very first one — including the
      // pre-login `app_opened` / `anonymous_user_identified` events, which fire
      // long before we know who the user is. Filter `is_internal != true` in
      // Mixpanel to get a clean view.
      final isInternal = InternalUserService.instance.isInternal;

      final superProps = <String, dynamic>{
        'app_version': appVersion,
        'platform': deviceInfo['device_model']?.contains('iPhone') == true
            ? 'iOS'
            : 'Android',
        'os_version': deviceInfo['os_version'] ?? 'unknown',
        'device_model': deviceInfo['device_model'] ?? 'unknown',
        'is_internal': isInternal,
      };

      mixpanel.registerSuperProperties(superProps);

      // Mirror onto the People profile so cohort-based exclusion works too.
      // Mixpanel joins events to profiles at query time against the profile's
      // *current* state, so this also retroactively pulls this user's earlier
      // anonymous events out of any `is_internal != true` cohort once their
      // anonymous distinct_id merges into the identified profile.
      if (isInternal) {
        mixpanel.getPeople().set('is_internal', true);
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to set analytics super properties',
        context: 'ANALYTICS',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// No-op tracker used before analytics is configured or in tests.
class NoopAnalyticsTracker implements AnalyticsTracker {
  const NoopAnalyticsTracker();

  @override
  Future<void> flush() async {}

  @override
  Future<void> identifyUser(
    String userId, {
    Map<String, dynamic>? properties,
    String? gender,
    int? age,
    double? weightPounds,
    bool? runsWithWaterBottle,
    String? gutTrainingLevel,
  }) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> markInternal() async {}

  @override
  Future<void> resetUser() async {}

  @override
  Future<void> timeEvent(String eventName) async {}

  /// Dev-only echo: NoopAnalyticsTracker is the tracker returned in dev mode
  /// (see [analyticsTrackerProvider]). The Mixpanel tracker has its own echo
  /// guarded by `devModeEnabled`, but in dev we never instantiate it — so
  /// without this echo here, engineers have no way to verify event payloads
  /// from the simulator console. Guarded by `kDebugMode` so release builds
  /// using the noop (e.g. tests) stay silent.
  @override
  Future<void> track(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async {
    if (kDebugMode) {
      debugPrint('📊 [ANALYTICS] $eventName ${properties ?? const {}}');
    }
  }
}

/// Provider exposing the default analytics tracker.
///
/// Returns [NoopAnalyticsTracker] — meaning `Mixpanel.init` is never called and
/// nothing leaves the device — when ANY of:
/// - The user has not granted analytics consent ([analyticsConsentProvider]).
///   This is the compliance gate: it holds for signed-in and anonymous users
///   alike, and `unknown` (not yet asked) is treated as "no". Apple Guideline
///   5.1.1(ii) requires consent for usage data "even if such data is considered
///   to be anonymous", so there is no state in which we may fire first and ask
///   later.
/// - Running in the development environment (`config.devModeEnabled`) UNLESS
///   the developer opted into the dev Mixpanel sandbox via
///   `ANALYTICS_DEV_ENABLED` (`config.analyticsDevEnabled`) — which routes dev
///   events to the "Mealvana Endurance Dev" project for verification.
///
/// In all other cases returns [MixpanelAnalyticsTracker].
///
/// There used to be a third condition here: a hidden "Exclude this device from
/// analytics (testers)" toggle that dropped the device's events outright. It was
/// superseded by `is_internal` (see [InternalUserService]), which tags team
/// events instead of suppressing them — so the traffic can be filtered out of
/// reports with `is_internal != true` while still being *visible* as team usage.
/// A tester who wants nothing sent at all now uses Settings → Privacy, which
/// lands on the consent gate above.
final analyticsTrackerProvider = Provider<AnalyticsTracker>((ref) {
  final config = ref.watch(appConfigProvider);
  final consent = ref.watch(analyticsConsentProvider);

  // Consent gate. Withdrawal flows through here too: flipping the Settings
  // toggle off rebuilds this provider, and every consumer reads the tracker
  // through `appExternalDepsProvider`, so subsequent events are dropped.
  if (!consent.allowsAnalytics) {
    return const NoopAnalyticsTracker();
  }

  // No-op in dev unless the dev-sandbox flag is set.
  if (config.devModeEnabled && !config.analyticsDevEnabled) {
    return const NoopAnalyticsTracker();
  }

  // Enable analytics in production environment.
  final logger = ref.watch(appLoggerProvider);
  return MixpanelAnalyticsTracker(config: config, logger: logger);
});

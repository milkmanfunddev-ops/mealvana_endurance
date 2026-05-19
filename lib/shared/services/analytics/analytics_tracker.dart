import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

import '../app_config.dart';
import '../device_info_service.dart';
import '../logging_service.dart';

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
}

/// Default tracker that talks to Mixpanel.
class MixpanelAnalyticsTracker implements AnalyticsTracker {
  MixpanelAnalyticsTracker({
    required AppConfig config,
    AppLogger? logger,
  })  : _config = config,
        _logger = logger ?? const NoopAppLogger();

  final AppConfig _config;
  final AppLogger _logger;

  Mixpanel? _mixpanel;
  bool _isInitialized = false;

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

      _isInitialized = true;    } catch (error, stackTrace) {
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
        await track('user_identified', properties: {
          'gender': gender,
          'age': age,
          'weight_lbs': weightPounds,
          'runs_with_water_bottle': runsWithWaterBottle,
          'gut_training_level': gutTrainingLevel,
        });
      } else {
        people.setOnce('First Seen', DateTime.now().toIso8601String());
        people.set('User Type', 'Anonymous');
        await track('anonymous_user_identified', properties: {
          'device_id': userId,
        });
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
  Future<void> track(String eventName, {Map<String, dynamic>? properties}) async {
    // Dev-only echo: lets engineers verify event names + payloads from the
    // simulator console without needing Mixpanel access. Stripped in prod
    // so we don't add log volume to release builds.
    if (_config.devModeEnabled) {
      _logger.info(
        '📊 $eventName',
        context: 'ANALYTICS',
        data: properties,
      );
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

  Future<void> _setupSuperProperties() async {
    final mixpanel = _mixpanel;
    if (mixpanel == null) return;

    try {
      // Use the shared DeviceInfoService (already initialized before parallel ops)
      final deviceInfoService = DeviceInfoService.instance;
      final deviceInfo = deviceInfoService.isInitialized
          ? deviceInfoService.deviceInfo
          : {'os_version': 'unknown', 'device_model': 'unknown'};

      final superProps = <String, dynamic>{
        'app_version': '1.3.0',
        'platform': deviceInfo['device_model']?.contains('iPhone') == true ? 'iOS' : 'Android',
        'os_version': deviceInfo['os_version'] ?? 'unknown',
        'device_model': deviceInfo['device_model'] ?? 'unknown',
      };

      mixpanel.registerSuperProperties(superProps);
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
  Future<void> resetUser() async {}

  @override
  Future<void> timeEvent(String eventName) async {}

  @override
  Future<void> track(String eventName, {Map<String, dynamic>? properties}) async {}
}

/// Provider exposing the default analytics tracker.
/// In development environment, returns NoopAnalyticsTracker (no tracking).
/// In production environment, returns MixpanelAnalyticsTracker.
final analyticsTrackerProvider = Provider<AnalyticsTracker>((ref) {
  final config = ref.watch(appConfigProvider);

  // Disable analytics in development environment
  if (config.devModeEnabled) {
    return const NoopAnalyticsTracker();
  }

  // Enable analytics in production environment
  final logger = ref.watch(appLoggerProvider);
  return MixpanelAnalyticsTracker(
    config: config,
    logger: logger,
  );
});

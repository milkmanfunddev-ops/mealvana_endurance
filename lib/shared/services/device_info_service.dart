import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/platform_io.dart' if (dart.library.html) '../utils/platform_web.dart';

/// Cached device information for analytics and telemetry.
///
/// IMPORTANT: On Android, DeviceInfoPlugin can deadlock if called during
/// app startup before the first frame renders. This service should only
/// be initialized AFTER the first frame (via initializeDeferredServices).
///
/// The device ID from this service is ONLY used for analytics - NOT for
/// user identity. User identity uses Supabase Auth UUID.
class DeviceInfoService {
  DeviceInfoService._();
  static final DeviceInfoService instance = DeviceInfoService._();

  String? _cachedDeviceId;
  Map<String, String>? _cachedDeviceInfo;
  bool _isInitialized = false;

  /// Initialize device info by fetching from the platform.
  /// IMPORTANT: Only call this AFTER the first frame renders to avoid
  /// Android DeviceInfoPlugin deadlock.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final deviceInfo = DeviceInfoPlugin();

      // Web platform uses browser-based device info
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        _cachedDeviceId = 'web-${webInfo.userAgent?.hashCode.abs() ?? DateTime.now().millisecondsSinceEpoch}';
        _cachedDeviceInfo = {
          'os_version': webInfo.platform ?? 'unknown',
          'device_model': webInfo.browserName.name,
        };
      } else if (PlatformInfo.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _cachedDeviceId = iosInfo.identifierForVendor ?? _generateFallbackId();
        _cachedDeviceInfo = {
          'os_version': iosInfo.systemVersion,
          'device_model': iosInfo.model,
        };
      } else if (PlatformInfo.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _cachedDeviceId = androidInfo.id.isNotEmpty
            ? androidInfo.id
            : 'android-${androidInfo.fingerprint.hashCode.abs()}';
        _cachedDeviceInfo = {
          'os_version': androidInfo.version.release,
          'device_model': androidInfo.model,
        };
      } else {
        _cachedDeviceId = _generateFallbackId();
        _cachedDeviceInfo = {
          'os_version': 'unknown',
          'device_model': 'unknown',
        };
      }

      _isInitialized = true;
    } catch (e) {
      _cachedDeviceId = _generateFallbackId();
      _cachedDeviceInfo = {
        'os_version': 'unknown',
        'device_model': 'unknown',
      };
      _isInitialized = true;
    }
  }

  String _generateFallbackId() {
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get the cached device ID.
  /// Returns a fallback ID if not initialized (should not happen in normal flow).
  String get deviceId {
    if (!_isInitialized) {
      return _generateFallbackId();
    }
    return _cachedDeviceId ?? _generateFallbackId();
  }

  /// Get cached device info.
  Map<String, String> get deviceInfo {
    return _cachedDeviceInfo ?? {'os_version': 'unknown', 'device_model': 'unknown'};
  }

  /// Check if initialized
  bool get isInitialized => _isInitialized;
}

/// Provider for DeviceInfoService singleton
final deviceInfoServiceProvider = Provider<DeviceInfoService>((ref) {
  return DeviceInfoService.instance;
});

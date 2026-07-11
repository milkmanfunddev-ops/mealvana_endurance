import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../device_info_service.dart';
import '../../utils/platform_io.dart'
    if (dart.library.html) '../../utils/platform_web.dart';

/// Compile-time internal flag, set via `--dart-define=IS_INTERNAL=true`.
///
/// Wired into every `.vscode/launch.json` config, `scripts/run_dev.sh`, the
/// Patrol invocation, and the dev/prod-ci Codemagic workflows. Deliberately NOT
/// set on the real `prod-ios` / `prod-android` / `main-*` release workflows.
const bool kIsInternalBuild = bool.fromEnvironment('IS_INTERNAL');

/// Device IDs belonging to the team, checked as a last resort so that the flag
/// survives a reinstall on Android.
///
/// Android's ID here is the SSAID (`Settings.Secure.ANDROID_ID`), which is
/// stable across uninstall/reinstall for a given app-signing key since Android
/// 8 — so listing a device here flags it permanently, with no first-launch gap.
///
/// iOS does NOT need an entry: there the flag is stored in the Keychain, which
/// already survives uninstall. iOS's `identifierForVendor` is *not* reinstall-
/// stable, so do not rely on it here.
///
/// To add a phone: open Settings, tap the version number 7×, and copy the
/// device ID shown in the Developer / Tester card.
const List<String> kInternalDeviceIds = <String>[
  // 'a1b2c3d4e5f6a7b8', // Lee — Pixel 8
];

/// Resolves whether this install belongs to the team, so analytics can tag its
/// events `is_internal: true` and they can be filtered out of Mixpanel reports.
///
/// This must resolve BEFORE Mixpanel is initialized: the flag is registered as
/// a Mixpanel *super property*, so it rides on every event including the
/// pre-login ones (`app_opened`, `anonymous_user_identified`). A People-property
/// -only approach would miss those, which is the whole problem we're solving.
///
/// Resolution order (first match wins):
///   1. `--dart-define=IS_INTERNAL=true`  — dev machines, CI, Patrol
///   2. Not a release build               — debug/profile is never a real user
///   3. Keychain / secure-storage flag    — the 7-tap toggle; reinstall-proof on iOS
///   4. Device ID in [kInternalDeviceIds] — reinstall-proof on Android
///
/// Everything is local, so there is no network call and no startup race.
class InternalUserService {
  InternalUserService._();
  static final InternalUserService instance = InternalUserService._();

  /// Secure-storage key holding the persisted internal flag.
  static const String _internalFlagKey = 'mv_is_internal_device';

  /// `first_unlock` (rather than the default `unlocked`) so the read still
  /// succeeds if the app is cold-launched in the background after a reboot.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _isInternal = false;
  bool _isInitialized = false;

  /// Whether this install belongs to the team. Safe to read synchronously once
  /// [initialize] has completed; returns `false` before that.
  bool get isInternal => _isInternal;

  bool get isInitialized => _isInitialized;

  /// The device ID used for the [kInternalDeviceIds] allowlist. Surfaced in the
  /// hidden Developer / Tester card so a phone can be registered by copy-paste.
  String get deviceId => DeviceInfoService.instance.deviceId;

  /// Signals that make this device internal regardless of the persisted flag,
  /// so [setInternal] can never un-flag a build or a device that is internal by
  /// construction. This is what makes [kInternalDeviceIds] genuinely permanent.
  bool get isForced =>
      kIsInternalBuild ||
      !kReleaseMode ||
      kInternalDeviceIds.contains(deviceId);

  /// Resolve the flag. Call once during startup, BEFORE `AnalyticsTracker
  /// .initialize()`, so the super property is in place for the first event.
  ///
  /// Requires [DeviceInfoService] to already be initialized.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Compile-time signals (1 + 2) and the device allowlist (4) are all
    // authoritative — short-circuit before touching storage.
    if (isForced) {
      _isInternal = true;
      _isInitialized = true;
      return;
    }

    // 3: persisted flag. On iOS this lives in the Keychain and survives an
    // uninstall, so a phone only ever needs the 7-tap toggle once.
    _isInternal = await _readPersistedFlag();

    _isInitialized = true;
  }

  /// Persist (or clear) the internal flag for this device and update the cached
  /// value. Backs the "Mark this device as internal" switch in Settings.
  ///
  /// The Mixpanel super property is only re-registered on the next launch, so
  /// callers should tell the user a restart is needed for full effect.
  Future<void> setInternal(bool value) async {
    // Resolve first: calling this before startup finished would otherwise mark
    // the service initialized and skip the Keychain/allowlist chain entirely.
    await initialize();

    // [isForced] wins over `value` — an allowlisted device or an IS_INTERNAL
    // build cannot be un-flagged from the UI.
    _isInternal = value || isForced;

    try {
      if (value) {
        await _storage.write(key: _internalFlagKey, value: 'true');
      } else {
        await _storage.delete(key: _internalFlagKey);
      }
    } catch (_) {
      // Secure storage is unavailable (e.g. web without a crypto context).
      // The in-memory value still applies for this session; we simply cannot
      // make it durable. Analytics must never crash the app.
    }
  }

  Future<bool> _readPersistedFlag() async {
    // flutter_secure_storage has no desktop/web Keychain equivalent worth
    // relying on here, and web builds already carry their flag via dart-define.
    if (kIsWeb || !(PlatformInfo.isIOS || PlatformInfo.isAndroid)) return false;

    try {
      return await _storage.read(key: _internalFlagKey) == 'true';
    } catch (_) {
      return false;
    }
  }
}

/// Provider for the [InternalUserService] singleton.
final internalUserServiceProvider = Provider<InternalUserService>((ref) {
  return InternalUserService.instance;
});

/// Reactive view of the internal-device flag, for the Developer / Tester card.
final internalDeviceFlagProvider =
    NotifierProvider<InternalDeviceFlagNotifier, bool>(
      InternalDeviceFlagNotifier.new,
    );

class InternalDeviceFlagNotifier extends Notifier<bool> {
  @override
  bool build() => InternalUserService.instance.isInternal;

  Future<void> setInternal(bool value) async {
    await InternalUserService.instance.setInternal(value);
    state = InternalUserService.instance.isInternal;
  }

  /// True when the flag is forced on — an `--dart-define=IS_INTERNAL` build, a
  /// debug/profile build, or a device in [kInternalDeviceIds] — so the switch
  /// cannot be turned off.
  bool get isForced => InternalUserService.instance.isForced;
}

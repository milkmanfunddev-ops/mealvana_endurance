import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Explicit choice made via the 7-tap "Mark this device as internal" switch:
  /// `true`/`false` once the user has toggled it, `null` if they never have.
  bool? _testerOverride;

  /// Whether this install belongs to the team. Safe to read synchronously once
  /// [initialize] has completed; returns `false` before that.
  ///
  /// This drives ANALYTICS tagging only — [isForced] wins here on purpose, so
  /// a dev build's events are always tagged internal. Tester-facing features
  /// (the $0.99 tester SKU) must use [testerModeEnabled] instead, which the
  /// switch genuinely controls.
  bool get isInternal => _isInternal;

  /// Whether tester-only surfaces (the $0.99 tester SKU) should show.
  ///
  /// The user's explicit switch choice always wins; with no explicit choice it
  /// defaults to [isForced]. Unlike [isInternal], toggling the switch OFF
  /// really hides tester surfaces — even on IS_INTERNAL / debug builds.
  bool get testerModeEnabled => _testerOverride ?? isForced;

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

  /// Legacy key of the removed "Exclude this device from analytics (testers)"
  /// toggle. See [_migrateLegacyExclusion].
  static const String _legacyExcludedKey = 'analytics_excluded';

  /// Resolve the flag. Call once during startup, BEFORE `AnalyticsTracker
  /// .initialize()`, so the super property is in place for the first event.
  ///
  /// Requires [DeviceInfoService] to already be initialized.
  Future<void> initialize({SharedPreferences? prefs}) async {
    if (_isInitialized) return;

    if (prefs != null) await _migrateLegacyExclusion(prefs);

    // The persisted tri-state is read even on forced builds so that
    // [testerModeEnabled] honours an explicit toggle-off there too.
    _testerOverride = await _readPersistedFlag();

    // Compile-time signals (1 + 2) and the device allowlist (4) stay
    // authoritative for the analytics flag.
    _isInternal = isForced || (_testerOverride ?? false);

    _isInitialized = true;
  }

  /// One-time migration off the old "Exclude this device from analytics"
  /// toggle, which this flag supersedes.
  ///
  /// That toggle predated `is_internal` and did the same job more bluntly: it
  /// dropped the device's events entirely, so team usage was invisible rather
  /// than merely filterable. `is_internal` tags instead of suppressing, which
  /// keeps the data and lets reports exclude it with `is_internal != true`.
  ///
  /// The migration matters because simply deleting the old toggle would
  /// silently start tracking every tester who had switched it on — they asked
  /// to be kept out of the numbers, and dropping the pref on the floor would
  /// quietly overrule them. Carrying them over to `is_internal` honours that.
  ///
  /// (A tester who wants NOTHING sent, rather than merely tagged, now uses
  /// Settings → Privacy, which returns a NoopAnalyticsTracker.)
  Future<void> _migrateLegacyExclusion(SharedPreferences prefs) async {
    if (prefs.getBool(_legacyExcludedKey) != true) return;

    try {
      await _storage.write(key: _internalFlagKey, value: 'true');
    } catch (_) {
      // Secure storage unavailable — analytics must never crash the app. The
      // pref is deliberately left in place so we can retry on the next launch.
      return;
    }
    await prefs.remove(_legacyExcludedKey);
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

    // The explicit choice is stored verbatim ('false', not a key delete) so
    // [testerModeEnabled] can distinguish "toggled off" from "never toggled".
    _testerOverride = value;

    // [isForced] still wins for the ANALYTICS flag — an allowlisted device or
    // an IS_INTERNAL build keeps tagging its events internal even when the
    // tester surfaces are toggled off.
    _isInternal = value || isForced;

    try {
      await _storage.write(key: _internalFlagKey, value: value.toString());
    } catch (_) {
      // Secure storage is unavailable (e.g. web without a crypto context).
      // The in-memory value still applies for this session; we simply cannot
      // make it durable. Analytics must never crash the app.
    }
  }

  Future<bool?> _readPersistedFlag() async {
    // flutter_secure_storage has no desktop/web Keychain equivalent worth
    // relying on here, and web builds already carry their flag via dart-define.
    if (kIsWeb || !(PlatformInfo.isIOS || PlatformInfo.isAndroid)) return null;

    try {
      return switch (await _storage.read(key: _internalFlagKey)) {
        'true' => true,
        'false' => false,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

/// Provider for the [InternalUserService] singleton.
final internalUserServiceProvider = Provider<InternalUserService>((ref) {
  return InternalUserService.instance;
});

/// Reactive view of the tester-mode switch, for the Developer / Tester card
/// and the tester-SKU filter. Follows [InternalUserService.testerModeEnabled]
/// — i.e. the user's explicit toggle wins, so turning it OFF genuinely hides
/// tester surfaces even on forced-internal builds.
final internalDeviceFlagProvider =
    NotifierProvider<InternalDeviceFlagNotifier, bool>(
      InternalDeviceFlagNotifier.new,
    );

class InternalDeviceFlagNotifier extends Notifier<bool> {
  @override
  bool build() => InternalUserService.instance.testerModeEnabled;

  Future<void> setInternal(bool value) async {
    await InternalUserService.instance.setInternal(value);
    state = InternalUserService.instance.testerModeEnabled;
  }

  /// True when the device is internal by construction — an
  /// `--dart-define=IS_INTERNAL` build, a debug/profile build, or a device in
  /// [kInternalDeviceIds]. Analytics stays tagged internal on these builds
  /// regardless of the switch; the switch itself remains usable.
  bool get isForced => InternalUserService.instance.isForced;
}

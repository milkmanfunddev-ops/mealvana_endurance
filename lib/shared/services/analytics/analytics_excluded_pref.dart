import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs_provider.dart';

/// SharedPreferences key for the "exclude this device from analytics" toggle.
const _analyticsExcludedKey = 'analytics_excluded';

/// Persisted boolean that controls whether this device's events reach Mixpanel.
///
/// Default: `false` (tracking enabled).
/// When `true`, [analyticsTrackerProvider] returns [NoopAnalyticsTracker] even
/// on a prod build, so no events leave the device.
///
/// Used by the hidden "Developer / Tester" section in SettingsScreen (revealed
/// after 7 taps on the version text).
final analyticsExcludedProvider =
    NotifierProvider<AnalyticsExcludedNotifier, bool>(
  AnalyticsExcludedNotifier.new,
);

class AnalyticsExcludedNotifier extends Notifier<bool> {
  @override
  bool build() {
    // SharedPreferences is synchronous once initialized, so we can read it
    // here in a synchronous build().
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_analyticsExcludedKey) ?? false;
  }

  /// Persist the exclusion preference and immediately update reactive state.
  Future<void> setExcluded(bool excluded) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (excluded) {
      await prefs.setBool(_analyticsExcludedKey, true);
    } else {
      await prefs.remove(_analyticsExcludedKey);
    }
    state = excluded;
  }
}

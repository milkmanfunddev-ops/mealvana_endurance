import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_external_deps.dart';

part 'preferences_service.g.dart';

/// Service for managing app-level preferences stored in SharedPreferences
/// These are lightweight flags and settings that don't need database persistence
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  // Keys
  static const String _keyHasCompletedInitialSurvey =
      'has_completed_initial_survey';
  static const String _keyTpWritebackEnabled = 'tp_writeback_enabled';
  static const String _keyTpWritebackPremiumBlocked =
      'tp_writeback_premium_blocked';

  /// Check if user has completed the initial survey after first activity creation
  bool get hasCompletedInitialSurvey {
    return _prefs.getBool(_keyHasCompletedInitialSurvey) ?? false;
  }

  /// Mark the initial survey as completed
  Future<void> markInitialSurveyCompleted() async {
    await _prefs.setBool(_keyHasCompletedInitialSurvey, true);
  }

  /// Clear the initial survey flag (useful for testing)
  Future<void> clearInitialSurveyFlag() async {
    await _prefs.remove(_keyHasCompletedInitialSurvey);
  }

  // ─── TrainingPeaks Write-Back ───

  /// Whether TP write-back is enabled (default ON)
  bool get tpWritebackEnabled => _prefs.getBool(_keyTpWritebackEnabled) ?? true;

  Future<void> setTpWritebackEnabled(bool enabled) async {
    await _prefs.setBool(_keyTpWritebackEnabled, enabled);
  }

  /// Whether TP write-back is blocked due to 403 (non-Premium account)
  bool get tpWritebackPremiumBlocked =>
      _prefs.getBool(_keyTpWritebackPremiumBlocked) ?? false;

  Future<void> setTpWritebackPremiumBlocked(bool blocked) async {
    await _prefs.setBool(_keyTpWritebackPremiumBlocked, blocked);
  }

  // ─── Garmin Connect Banner ───

  static const String _keyGarminBannerDismissed = 'garmin_banner_dismissed';

  /// Whether the user has permanently dismissed the Garmin Connect banner.
  bool get garminBannerDismissed =>
      _prefs.getBool(_keyGarminBannerDismissed) ?? false;

  /// Persist banner dismissal. Once set, the banner never shows again
  /// unless app data is cleared.
  Future<void> dismissGarminBanner() async {
    await _prefs.setBool(_keyGarminBannerDismissed, true);
  }

  // ─── Mealvana AI Baseline Tip Banner ───

  static const String _keyAiCoachBaselineTipDismissed =
      'jade_baseline_tip_dismissed';

  /// Whether the user has dismissed the one-time baseline-logging tutorial
  /// copy on the Mealvana AI coach banner.  Once true, the banner shows the default
  /// "has baseline" copy instead of the tutorial variant.
  bool get aiCoachBaselineTipDismissed =>
      _prefs.getBool(_keyAiCoachBaselineTipDismissed) ?? false;

  /// Persist dismissal of the Mealvana AI baseline tutorial copy.
  Future<void> dismissAiCoachBaselineTip() async {
    await _prefs.setBool(_keyAiCoachBaselineTipDismissed, true);
  }

  // ─── Fuel Timeline Tracking ───

  static const String _keyFuelTrackingEnabled = 'fuel_tracking_enabled';

  /// Whether calorie/macro tracking is shown on the Fuel Timeline (default ON).
  /// When off, the energy dashboard is hidden and meal cards drop their macro
  /// line — a "log without numbers" mode. Global, persisted across sessions.
  bool get fuelTrackingEnabled =>
      _prefs.getBool(_keyFuelTrackingEnabled) ?? true;

  Future<void> setFuelTrackingEnabled(bool enabled) async {
    await _prefs.setBool(_keyFuelTrackingEnabled, enabled);
  }

  // ─── AI credits ───

  static const String _keyCreditsEnsuredStamp = 'credits_ensured_stamp';

  /// Marker for "this user's free monthly credits have already been requested",
  /// stored as `<userId>|<YYYY-MM>`.
  ///
  /// Provisioning the wallet is an edge-function round trip, and the grant it
  /// performs is idempotent for the whole calendar month — so calling it more
  /// than once per user per month is pure cost. The user id is part of the
  /// value so that signing in as somebody else on the same device does not
  /// inherit the previous account's marker.
  String? get creditsEnsuredStamp => _prefs.getString(_keyCreditsEnsuredStamp);

  Future<void> setCreditsEnsuredStamp(String stamp) async {
    await _prefs.setString(_keyCreditsEnsuredStamp, stamp);
  }

  /// Clear all preferences (useful for testing or logout)
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}

/// Provider for PreferencesService (synchronous now that SharedPreferences is pre-initialized)
@Riverpod(keepAlive: true)
PreferencesService preferencesService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
}

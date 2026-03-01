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
  static const String _keyHasCompletedInitialSurvey = 'has_completed_initial_survey';
  static const String _keyTpWritebackEnabled = 'tp_writeback_enabled';
  static const String _keyTpWritebackPremiumBlocked = 'tp_writeback_premium_blocked';

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

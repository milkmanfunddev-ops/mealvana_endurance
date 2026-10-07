import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/services/prefs_provider.dart';
import '../../domain/integration.dart';

part 'reconnect_notice_controller.g.dart';

/// The one-time "sign in again" notice for a connected app (testing-wave
/// ticket 138, Finding 118-007; Lee 2026-09-26).
///
/// State is the provider id whose notice the Timeline should show, or null.
/// [IntegrationsRepository.updateSyncStatus] reports every status it writes
/// through [onSyncStatusWritten], so the notice fires no matter which path
/// found the dead token: a background sync, Sync Now, or Garmin's backfill.
///
/// Shown once per move into `requires_reauth`: the move is remembered in
/// SharedPreferences under the provider's key, and a later `success` for the
/// same provider forgets it, so the next relapse is announced again.
///
/// Repeats are safe: two writes of `requires_reauth` in a row (the same sync
/// hitting two endpoints) read the same flag and show one notice; a refresh
/// of the controller re-reads nothing, because the flag lives in prefs.
@Riverpod(keepAlive: true)
class ReconnectNoticeController extends _$ReconnectNoticeController {
  static const _prefsPrefix = 'reconnect_notice_shown.';

  @override
  String? build() => null;

  /// The repository's hook; see the class comment.
  void onSyncStatusWritten(String provider, String status) {
    final prefs = ref.read(sharedPreferencesProvider);
    final key = '$_prefsPrefix$provider';
    if (status == requiresReauthStatus) {
      if (prefs.getBool(key) == true) return;
      unawaited(prefs.setBool(key, true));
      // One notice at a time; a second provider waits for the next move.
      state ??= provider;
      return;
    }
    if (status == 'success') {
      unawaited(prefs.remove(key));
      if (state == provider) state = null;
    }
  }

  /// The athlete dismissed the line or tapped Reconnect.
  void dismiss() => state = null;
}

/// The name the athlete sees for a provider id.
String reconnectProviderDisplayName(String provider) => switch (provider) {
  'training_peaks' => 'TrainingPeaks',
  'final_surge' => 'Final Surge',
  'vdot' => 'V.O2',
  'garmin' => 'Garmin',
  'runna' => 'Runna',
  _ => provider,
};

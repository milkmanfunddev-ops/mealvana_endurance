import 'package:flutter/foundation.dart' show setEquals;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/services/report/report.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import 'integrations_providers.dart';

part 'reconnect_notice_controller.g.dart';

/// The providers whose integrations row needs a reconnect (active and
/// `requires_reauth`), from a Drift watch on the athlete's rows (ticket 77,
/// Finding 68-008). Every write reaches it: this device's own status write,
/// a pull that brought another device's write, a reconnect clearing the
/// status, a disconnect deactivating the row.
@Riverpod(keepAlive: true)
Stream<Set<String>> integrationsNeedingReconnect(Ref ref, String userId) {
  final repository = ref.watch(integrationsRepositoryProvider);
  return repository
      .watchIntegrationsForUser(userId)
      .map(
        (rows) => <String>{
          for (final row in rows)
            if (row.needsReconnect) row.provider,
        },
      )
      .distinct(setEquals);
}

/// One pull of the athlete's integrations rows per launch (ticket 77,
/// Finding 68-008). `ensureSynced` skips a repository synced within the
/// hour, and Garmin is push-only, so a row another device moved to
/// `requires_reauth` never reached this one. keepAlive makes this once per
/// process per user. The coordinator uploads dirty rows first, then pulls,
/// and records its own skips (offline: `info`) and failures (`fault`).
@Riverpod(keepAlive: true)
Future<void> integrationRowsLaunchPull(Ref ref, String userId) async {
  final report = ref.read(reportProvider);
  try {
    final repository = ref.read(integrationsRepositoryProvider);
    await ref
        .read(syncCoordinatorProvider.notifier)
        .forceSyncRepository('integrations', userId, repository: repository);
  } catch (e, st) {
    // The coordinator catches its own sync failures; this is the rest (no
    // repository, no connectivity plugin). The notice reads local rows.
    await report.degraded(
      e,
      stackTrace: st,
      area: 'integrations',
      message: 'Integrations launch pull failed; reconnect notice reads '
          'local rows',
    );
  }
}

/// The "sign in again" notice for a connected app on the Timeline (ticket
/// 138, Finding 118-007; ticket 77 ruling of 2026-10-09).
///
/// State is the provider id whose notice the Timeline shows, or null. It is
/// derived from the integrations rows ([integrationsNeedingReconnectProvider])
/// on every device and every launch, until the row changes; a launch pull
/// ([integrationRowsLaunchPullProvider]) brings the server's rows in first.
///
/// [dismiss] (the X or Reconnect) hides the shown provider for this launch
/// only; the next provider needing a reconnect then shows. The dismissed set
/// lives in memory, so the notice is back on the next launch while the row
/// still says `requires_reauth`.
@Riverpod(keepAlive: true)
class ReconnectNoticeController extends _$ReconnectNoticeController {
  /// The order the notice names providers in, one at a time.
  static const providerOrder = [
    'garmin',
    'training_peaks',
    'final_surge',
    'vdot',
    'runna',
  ];

  final Set<String> _dismissed = {};
  Set<String> _needing = const {};
  String? _userId;
  Object? _reportedWatchError;

  @override
  String? build() {
    final userId = ref.watch(userIdProvider).value;
    // The notifier instance outlives a rebuild: a new user starts clean.
    if (userId != _userId) {
      _dismissed.clear();
      _userId = userId;
    }
    if (userId == null) {
      _needing = const {};
      return null;
    }
    ref.watch(integrationRowsLaunchPullProvider(userId));
    final needing = ref.watch(integrationsNeedingReconnectProvider(userId));
    if (needing.hasError && !identical(needing.error, _reportedWatchError)) {
      // D9: a dead watch would otherwise read as "nothing needs a reconnect".
      _reportedWatchError = needing.error;
      ref
          .read(reportProvider)
          .degraded(
            needing.error!,
            stackTrace: needing.stackTrace,
            area: 'integrations',
            message: 'reconnect notice: integrations watch failed; no notice shown',
          );
    }
    _needing = needing.value ?? const {};
    return _pick();
  }

  String? _pick() {
    for (final provider in providerOrder) {
      if (_needing.contains(provider) && !_dismissed.contains(provider)) {
        return provider;
      }
    }
    return null;
  }

  /// The athlete dismissed the line or tapped Reconnect: hidden for this
  /// launch.
  void dismiss() {
    final shown = state;
    if (shown == null) return;
    _dismissed.add(shown);
    state = _pick();
  }
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

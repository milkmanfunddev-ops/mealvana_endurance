import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/integrations_repository.dart';
import '../../domain/athlete_zones.dart';
import 'integrations_providers.dart';

part 'athlete_zones_provider.g.dart';

/// Provider that reads athlete zones from the active Training Peaks integration.
///
/// Returns null if:
/// - No Training Peaks integration is connected
/// - No zone data has been fetched yet
/// - Zone data failed to parse
///
/// Zone data is fetched during sync (see training_peaks_sync_service.dart)
/// and stored in the integration record as JSON.
@riverpod
Future<AthleteZones?> athleteZones(Ref ref, String userId) async {
  final repository = ref.watch(integrationsRepositoryProvider);

  // Check Training Peaks integration first (primary source of zones)
  final tpIntegration = await repository.getIntegration(
    userId,
    'training_peaks',
  );
  if (tpIntegration != null &&
      tpIntegration.isActive &&
      tpIntegration.athleteZonesJson != null) {
    return AthleteZones.fromJsonString(tpIntegration.athleteZonesJson);
  }

  return null;
}

/// Provider for just the Zone 2 pace (most commonly needed for auto-suggest)
@riverpod
Future<double?> zone2PaceMinPerMile(Ref ref, String userId) async {
  final zones = await ref.watch(athleteZonesProvider(userId).future);
  return zones?.zone2PaceMinPerMile;
}

/// Provider for threshold pace
@riverpod
Future<double?> thresholdPaceMinPerMile(Ref ref, String userId) async {
  final zones = await ref.watch(athleteZonesProvider(userId).future);
  return zones?.thresholdPaceMinPerMile;
}

/// D-2 provenance feed: the TP-sourced FTP (watts), or null when TP is not
/// connected / carries no power zones.
@riverpod
Future<int?> tpFtpWatts(Ref ref, String userId) async {
  final zones = await ref.watch(athleteZonesProvider(userId).future);
  return zones?.ftpWatts;
}

/// D-2 provenance feed: the TP-derived swim CSS (sec/100m).
@riverpod
Future<int?> tpCssSecondsPer100m(Ref ref, String userId) async {
  final zones = await ref.watch(athleteZonesProvider(userId).future);
  return zones?.cssSecondsPer100m;
}

/// D-2 staleness: true when the TP zones cache is older than the ruled
/// 24 h window (the zones clock — integration.updatedAt tracks the fetch).
@riverpod
Future<bool> tpZonesStale(Ref ref, String userId) async {
  final repository = ref.watch(integrationsRepositoryProvider);
  final tp = await repository.getIntegration(userId, 'training_peaks');
  if (tp == null || !tp.isActive || tp.athleteZonesJson == null) return false;
  final updatedAt = tp.updatedAt;
  if (updatedAt == null) return true;
  return DateTime.now().difference(updatedAt) > const Duration(hours: 24);
}


/// D-2b provenance feed (TP fallback): the athlete weight (kg) TP reported
/// on the basic profile, or null when TP is not connected. Garmin remains
/// the ruled primary body-comp source; this fills the badge when Garmin has
/// no reading (Xuan, 2026-09-13: every field a provider carries shows its
/// badge).
@riverpod
Future<double?> tpAthleteWeightKg(Ref ref, String userId) async {
  final repository = ref.watch(integrationsRepositoryProvider);
  final tp = await repository.getIntegration(userId, 'training_peaks');
  if (tp == null || !tp.isActive) return null;
  return tp.providerAthleteWeightKg;
}

/// TP-reported identity fields for profile provenance badges (name, birth
/// month "YYYY-MM", gender) — null when TP is not connected.
@riverpod
Future<({String? name, String? birthMonth, String? gender})?>
    tpAthleteIdentity(Ref ref, String userId) async {
  final repository = ref.watch(integrationsRepositoryProvider);
  final tp = await repository.getIntegration(userId, 'training_peaks');
  if (tp == null || !tp.isActive) return null;
  return (
    name: tp.providerAthleteName,
    birthMonth: tp.providerAthleteBirthMonth,
    gender: tp.providerAthleteGender,
  );
}

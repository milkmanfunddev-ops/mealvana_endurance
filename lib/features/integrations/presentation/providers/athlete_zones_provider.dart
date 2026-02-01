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
  final tpIntegration = await repository.getIntegration(userId, 'training_peaks');
  if (tpIntegration != null && tpIntegration.isActive && tpIntegration.athleteZonesJson != null) {
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

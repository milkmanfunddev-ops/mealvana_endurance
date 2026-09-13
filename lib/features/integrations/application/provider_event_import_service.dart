import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/logging_service.dart';
import '../../events/data/events_repository.dart';
import '../../events/domain/event.dart' as domain;
import 'final_surge_sync_service.dart';
import 'training_peaks_transformer.dart';

part 'provider_event_import_service.g.dart';

@riverpod
ProviderEventImportService providerEventImportService(Ref ref) {
  return ProviderEventImportService(
    eventsRepository: ref.read(eventsRepositoryProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Persists provider-imported events (TP events, FS race candidates) with
/// the dedupe + D-2c origin rules — the ONE save site for every sync path.
///
/// History: this logic lived only in ConnectTrainingController, so the
/// coordinator's background sync fetched events and silently discarded them
/// (a race added on TP after connect never imported until a manual
/// Sync Now — found live 2026-09-13, ops bug
/// tp-background-sync-discards-imported-events). Both the controller and
/// IntegrationSyncCoordinator now funnel through this service.
class ProviderEventImportService {
  ProviderEventImportService({
    required EventsRepository eventsRepository,
    required AppLogger logger,
  }) : _eventsRepository = eventsRepository,
       _logger = logger;

  final EventsRepository _eventsRepository;
  final AppLogger _logger;

  /// Save TrainingPeaks events. Returns the number of newly created rows.
  ///
  /// Dedupe is by (user, name, date). D-2c: a matched LEGACY (null-origin)
  /// row flips to 'training_peaks'; a 'manual' row is athlete-owned and is
  /// exempt from re-sync overwrite, origin included.
  Future<int> importTrainingPeaksEvents(
    String userId,
    List<TrainingPeaksEventResult> events,
  ) async {
    int saved = 0;
    int skipped = 0;

    for (final event in events) {
      final existing = await _eventsRepository.findExistingEvent(
        userId: userId,
        eventName: event.eventName,
        eventDate: event.eventDate,
      );

      if (existing != null) {
        if (existing.origin == null) {
          await _eventsRepository.updateEvent(
            deviceId: userId,
            event: existing.copyWith(origin: 'training_peaks'),
          );
        }
        skipped++;
        continue;
      }

      try {
        final now = DateTime.now();
        await _eventsRepository.createEvent(
          deviceId: userId,
          event: domain.Event(
            id: '', // Let DB auto-generate
            userId: userId,
            eventType: event.activityType,
            eventSubtype: null,
            eventName: event.eventName,
            eventDate: event.eventDate,
            startTime: event.eventDate.toIso8601String(),
            goalTimeMinutes: event.goalTimeHours != null
                ? (event.goalTimeHours! * 60).round()
                : null,
            origin: 'training_peaks', // D-2c
            createdAt: now,
            updatedAt: now,
          ),
        );
        saved++;
      } catch (e, stackTrace) {
        _logger.warning(
          'Failed to save TrainingPeaks event',
          context: 'EVENT_IMPORT',
          error: e,
          stackTrace: stackTrace,
          data: {'eventName': event.eventName},
        );
      }
    }

    if (kDebugMode) {
      print('✅ Event sync complete: $saved new, $skipped existing');
    }
    return saved;
  }

  /// Save Final Surge race candidates. Returns newly created rows.
  ///
  /// Dedupe is first by linked activity, then by (user, name, date); the
  /// same D-2c legacy-flip / manual-exempt rules apply.
  Future<int> importFinalSurgeRaceCandidates(
    String userId,
    List<FinalSurgeRaceCandidate> candidates,
  ) async {
    int saved = 0;

    for (final candidate in candidates) {
      final activityId = candidate.activityId;
      if (activityId == null || activityId.isEmpty) {
        continue;
      }

      final existingByActivity = await _eventsRepository.getEventForActivity(
        activityId,
      );
      if (existingByActivity != null) {
        continue;
      }

      final eventName = candidate.eventName.trim().isNotEmpty
          ? candidate.eventName
          : 'Race';
      final existingByName = await _eventsRepository.findExistingEvent(
        userId: userId,
        eventName: eventName,
        eventDate: candidate.scheduledAt,
      );
      if (existingByName != null) {
        if (existingByName.origin == null) {
          await _eventsRepository.updateEvent(
            deviceId: userId,
            event: existingByName.copyWith(origin: 'final_surge'),
          );
        }
        continue;
      }

      try {
        final now = DateTime.now();
        await _eventsRepository.createEvent(
          deviceId: userId,
          event: domain.Event(
            id: '', // Let DB auto-generate
            userId: userId,
            activityId: activityId,
            eventType: candidate.eventType,
            eventName: eventName,
            eventDate: candidate.scheduledAt,
            startTime: candidate.scheduledAt.toIso8601String(),
            goalTimeMinutes: candidate.goalTimeMinutes,
            goalPaceMinutesPerMile: candidate.goalPaceMinutesPerMile,
            origin: 'final_surge', // D-2c
            createdAt: now,
            updatedAt: now,
          ),
        );
        saved++;
      } catch (e, stackTrace) {
        _logger.warning(
          'Failed to save Final Surge race event',
          context: 'EVENT_IMPORT',
          error: e,
          stackTrace: stackTrace,
          data: {'eventName': eventName},
        );
      }
    }

    return saved;
  }
}

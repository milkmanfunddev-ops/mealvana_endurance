import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../database/app_database.dart';
import '../../../database/database_provider.dart';
import '../../../utils/sync_type_converters.dart';
import '../../logging_service.dart';

part 'event_sync_handler.g.dart';

@Riverpod(keepAlive: true)
EventSyncHandler eventSyncHandler(Ref ref) {
  return EventSyncHandler(
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Handles sync operations for Event entities.
class EventSyncHandler {
  const EventSyncHandler({
    required AppDatabase database,
    required AppLogger logger,
  })  : _database = database,
        _logger = logger;

  final AppDatabase _database;
  final AppLogger _logger;

  /// Upsert an event from remote data.
  Future<void> upsertEvent(Map<String, dynamic> data, String userId) async {
    try {
      final eventId = SyncTypeConverters.toRequiredStringId(data['id'], 'event.id');
      final existingEvent = await (_database.select(_database.eventsTable)
            ..where((tbl) => tbl.id.equals(eventId)))
          .getSingleOrNull();

      final supabaseUpdatedAt = DateTime.parse(data['updated_at'] as String);

      if (existingEvent == null || existingEvent.updatedAt.isBefore(supabaseUpdatedAt)) {
        // Keep activity_id from the data even if activity doesn't exist locally yet
        // This is important for coach sync scenarios where activities may be synced after events
        // The activity might be synced later, and the foreign key relationship will be valid
        final activityId = SyncTypeConverters.toStringId(data['activity_id']);

        final companion = EventsTableCompanion.insert(
          id: Value(eventId),
          userId: SyncTypeConverters.toStringId(data['user_id']) ?? userId,
          activityId: Value(activityId),
          eventType: data['event_type'] as String,
          eventSubtype: Value(data['event_subtype'] as String?),
          eventName: Value(data['event_name'] as String?),
          location: Value(data['location'] as String?),
          registrationUrl: Value(data['registration_url'] as String?),
          eventDate: Value(
            data['event_date'] != null
                ? DateTime.parse(data['event_date'] as String)
                : null,
          ),
          startTime: Value(data['start_time'] as String?),
          goalTimeMinutes: Value(data['goal_time_minutes'] as int?),
          goalPaceMinutesPerMile: Value((data['goal_pace_minutes_per_mile'] as num?)?.toDouble()),
          predictedFinishTimeMinutes: Value(data['predicted_finish_time_minutes'] as int?),
          hasCarbLoading: Value(SyncTypeConverters.toBool(data['has_carb_loading'])),
          carbLoadingDays: Value(data['carb_loading_days'] as int?),
          carbLoadingStartDate: Value(
            data['carb_loading_start_date'] != null
                ? DateTime.parse(data['carb_loading_start_date'] as String)
                : null,
          ),
          hasNutritionPlan: Value(SyncTypeConverters.toBool(data['has_nutrition_plan'])),
          bibNumber: Value(data['bib_number'] as String?),
          waveStartTime: Value(data['wave_start_time'] as String?),
          packetPickupInfo: Value(data['packet_pickup_info'] as String?),
          actualFinishTimeMinutes: Value(data['actual_finish_time_minutes'] as int?),
          finalPlacement: Value(data['final_placement'] as int?),
          ageGroupPlacement: Value(data['age_group_placement'] as int?),
          createdAt: DateTime.parse(data['created_at'] as String),
          updatedAt: supabaseUpdatedAt,
        );

        await _database
            .into(_database.eventsTable)
            .insert(companion, mode: InsertMode.insertOrReplace);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upsert event',
        context: 'EVENT_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'eventId': data['id']},
      );
    }
  }

  /// Sync multiple athlete events (for coach view).
  Future<void> syncAthleteEvents(List<dynamic> events) async {
    try {
      for (final eventData in events) {
        final eventMap = eventData as Map<String, dynamic>;
        await upsertEvent(eventMap, eventMap['user_id'] as String);
      }

      _logger.info(
        'Synced ${events.length} athlete events',
        context: 'EVENT_SYNC',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync athlete events',
        context: 'EVENT_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - continue with other syncs
    }
  }

  /// Convert Event entity to JSON for edge function upload.
  Map<String, dynamic> eventToJson(Event event) {
    return {
      'id': event.id,
      'user_id': event.userId,
      'activity_id': event.activityId,
      'event_type': event.eventType,
      'event_subtype': event.eventSubtype,
      'event_name': event.eventName,
      'location': event.location,
      'registration_url': event.registrationUrl,
      'event_date': event.eventDate?.toIso8601String(),
      'start_time': event.startTime,
      'goal_time_minutes': event.goalTimeMinutes,
      'goal_pace_minutes_per_mile': event.goalPaceMinutesPerMile,
      'predicted_finish_time_minutes': event.predictedFinishTimeMinutes,
      'has_carb_loading': event.hasCarbLoading,
      'carb_loading_days': event.carbLoadingDays,
      'carb_loading_start_date': event.carbLoadingStartDate?.toIso8601String(),
      'has_nutrition_plan': event.hasNutritionPlan,
      'bib_number': event.bibNumber,
      'wave_start_time': event.waveStartTime,
      'packet_pickup_info': event.packetPickupInfo,
      'actual_finish_time_minutes': event.actualFinishTimeMinutes,
      'final_placement': event.finalPlacement,
      'age_group_placement': event.ageGroupPlacement,
      'created_at': event.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

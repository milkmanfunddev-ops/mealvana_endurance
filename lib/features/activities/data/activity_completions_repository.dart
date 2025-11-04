import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../domain/activity_completion.dart' as domain;

part 'activity_completions_repository.g.dart';

@riverpod
ActivityCompletionsRepository activityCompletionsRepository(Ref ref) {
  return ActivityCompletionsRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Repository for managing activity completions following FOA pattern
/// Prepares for server-authoritative sync with edge functions
class ActivityCompletionsRepository {
  const ActivityCompletionsRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  Future<domain.ActivityCompletion> recordCompletion({
    required String deviceId,
    required domain.ActivityCompletion completion,
  }) async {
    try {
      final completionWithDirtyFlag = completion.copyWith(
        needsUpload: true,
        localUpdatedAt: DateTime.now(),
      );

      await _saveToDrift(completionWithDirtyFlag);

      await (_database.update(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(completion.activityId)))
          .write(ActivitiesTableCompanion(
            status: const Value('completed'),
            completedAt: Value(completion.completedAt),
            actualDistanceMiles: Value(completion.actualDistanceMiles),
            actualDurationMinutes: Value(completion.actualDurationMinutes),
            updatedAt: Value(DateTime.now()),
            needsUpload: const Value(true),
            localUpdatedAt: Value(DateTime.now()),
          ));


      unawaited(_uploadCompletionToSupabase(deviceId, completionWithDirtyFlag, 'create'));

      return completionWithDirtyFlag;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to record activity completion',
        context: 'ACTIVITY_COMPLETIONS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<domain.ActivityCompletion> updateCompletion({
    required String deviceId,
    required domain.ActivityCompletion completion,
  }) async {
    try {
      final completionWithDirtyFlag = completion.copyWith(
        needsUpload: true,
        localUpdatedAt: DateTime.now(),
      );

      await _saveToDrift(completionWithDirtyFlag);


      unawaited(_uploadCompletionToSupabase(deviceId, completionWithDirtyFlag, 'update'));

      return completionWithDirtyFlag;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update activity completion',
        context: 'ACTIVITY_COMPLETIONS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get completion for an activity
  Future<domain.ActivityCompletion?> getCompletionForActivity(String activityId) async {
    try {
      final query = _database.select(_database.activityCompletionsTable)
        ..where((tbl) => tbl.activityId.equals(activityId));

      final completion = await query.getSingleOrNull();
      return completion != null ? _mapToCompletionDomain(completion) : null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get completion for activity',
        context: 'ACTIVITY_COMPLETIONS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get completion by ID
  Future<domain.ActivityCompletion?> getCompletionById(String completionId) async {
    try {
      final query = _database.select(_database.activityCompletionsTable)
        ..where((tbl) => tbl.id.equals(completionId));

      final completion = await query.getSingleOrNull();
      return completion != null ? _mapToCompletionDomain(completion) : null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get completion by ID',
        context: 'ACTIVITY_COMPLETIONS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all completions for a user
  Future<List<domain.ActivityCompletion>> getCompletionsForUser(String userId) async {
    try {
      final query = _database.select(_database.activityCompletionsTable)
        ..where((tbl) => tbl.userId.equals(userId))
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.completedAt)]);

      final completions = await query.get();
      return completions.map(_mapToCompletionDomain).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get completions for user',
        context: 'ACTIVITY_COMPLETIONS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _saveToDrift(domain.ActivityCompletion completion) async {
    final companion = ActivityCompletionsTableCompanion.insert(
      id: completion.id,
      activityId: completion.activityId,
      userId: completion.userId,
      completedAt: completion.completedAt,
      completionType: Value(completion.completionType.name),
      actualDistanceMiles: Value(completion.actualDistanceMiles),
      actualDurationMinutes: Value(completion.actualDurationMinutes),
      averagePaceMinutesPerMile: Value(completion.averagePaceMinutesPerMile),
      maxHeartRate: Value(completion.maxHeartRate),
      averageHeartRate: Value(completion.averageHeartRate),
      caloriesBurned: Value(completion.caloriesBurned),
      effortRating: Value(completion.effortRating),
      nutritionRating: Value(completion.nutritionRating),
      overallSatisfaction: Value(completion.overallSatisfaction),
      textNotes: Value(completion.textNotes),
      voiceNoteId: Value(completion.voiceNoteId),
      hasVoiceRecording: Value(completion.hasVoiceRecording),
      weatherConditions: Value(completion.weatherConditions),
      temperatureFahrenheit: Value(completion.temperatureFahrenheit),
      humidityPercent: Value(completion.humidityPercent),
      nutritionAdherenceScore: Value(completion.nutritionAdherenceScore),
      performanceVsTarget: Value(completion.performanceVsTarget),
      needsUpload: Value(completion.needsUpload ?? false),
      localUpdatedAt: Value(completion.localUpdatedAt ?? DateTime.now()),
    );

    await _database
        .into(_database.activityCompletionsTable)
        .insert(companion, mode: InsertMode.insertOrReplace);
  }

  Future<void> _uploadCompletionToSupabase(
    String deviceId,
    domain.ActivityCompletion completion,
    String operation,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'save-activity-completion',
        body: {
          'device_id': deviceId,
          'completion': completion.toJson(),
          'operation': operation,
        },
      );

      if (response.status >= 200 && response.status < 300) {
        await _clearDirtyFlag(completion.id);
      } else {
        _logger.warning(
          'Failed to upload activity completion, will retry on next sync',
          context: 'ACTIVITY_COMPLETIONS_REPOSITORY',
          data: {'completionId': completion.id, 'status': response.status},
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error uploading activity completion, will retry on next sync',
        context: 'ACTIVITY_COMPLETIONS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _clearDirtyFlag(String completionId) async {
    try {
      await (_database.update(_database.activityCompletionsTable)
            ..where((tbl) => tbl.id.equals(completionId)))
          .write(const ActivityCompletionsTableCompanion(
        needsUpload: Value(false),
      ));
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to clear completion dirty flag',
        context: 'ACTIVITY_COMPLETIONS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  domain.ActivityCompletion _mapToCompletionDomain(ActivityCompletion completion) {
    return domain.ActivityCompletion(
      id: completion.id,
      activityId: completion.activityId,
      userId: completion.userId,
      completedAt: completion.completedAt,
      completionType: domain.CompletionType.values.firstWhere(
        (type) => type.name == completion.completionType,
        orElse: () => domain.CompletionType.manual,
      ),
      actualDistanceMiles: completion.actualDistanceMiles,
      actualDurationMinutes: completion.actualDurationMinutes,
      averagePaceMinutesPerMile: completion.averagePaceMinutesPerMile,
      maxHeartRate: completion.maxHeartRate,
      averageHeartRate: completion.averageHeartRate,
      caloriesBurned: completion.caloriesBurned,
      effortRating: completion.effortRating,
      nutritionRating: completion.nutritionRating,
      overallSatisfaction: completion.overallSatisfaction,
      textNotes: completion.textNotes,
      voiceNoteId: completion.voiceNoteId,
      hasVoiceRecording: completion.hasVoiceRecording,
      weatherConditions: completion.weatherConditions,
      temperatureFahrenheit: completion.temperatureFahrenheit,
      humidityPercent: completion.humidityPercent,
      nutritionAdherenceScore: completion.nutritionAdherenceScore,
      performanceVsTarget: completion.performanceVsTarget,
      needsUpload: completion.needsUpload,
      localUpdatedAt: completion.localUpdatedAt,
    );
  }
}

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/activity_completion.dart' as domain;
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';

part 'activity_completions_service.g.dart';

@riverpod
ActivityCompletionsService activityCompletionsService(Ref ref) {
  return ActivityCompletionsService(
    ref.read(appDatabaseProvider),
    ref.read(appLoggerProvider),
  );
}

/// Service for managing activity completions
/// Handles recording and updating activity completion data
class ActivityCompletionsService {
  final AppDatabase _database;
  final AppLogger _logger;

  ActivityCompletionsService(
    this._database,
    this._logger,
  );

  /// Complete an activity with detailed metrics
  Future<domain.ActivityCompletion> completeActivity({
    required String activityId,
    required String userId,
    required DateTime completedAt,
    domain.CompletionType completionType = domain.CompletionType.manual,
    double? actualDistanceMiles,
    int? actualDurationMinutes,
    double? averagePaceMinutesPerMile,
    int? maxHeartRate,
    int? averageHeartRate,
    int? caloriesBurned,
    int? effortRating,
    int? nutritionRating,
    int? overallSatisfaction,
    String? textNotes,
    String? voiceNoteId,
    bool? hasVoiceRecording,
    String? weatherConditions,
    int? temperatureFahrenheit,
    int? humidityPercent,
  }) async {
    try {
      // Update activity status to completed
      await (_database.update(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(activityId)))
          .write(ActivitiesTableCompanion(
            status: const Value('completed'),
            completedAt: Value(completedAt),
            actualDistanceMiles: Value(actualDistanceMiles),
            actualDurationMinutes: Value(actualDurationMinutes),
            updatedAt: Value(DateTime.now()),
          ));

      // Create completion record
      final id = _generateId();
      final companion = ActivityCompletionsTableCompanion.insert(
        id: id,
        activityId: activityId,
        userId: userId,
        completedAt: completedAt,
        completionType: Value(completionType.name),
        actualDistanceMiles: Value(actualDistanceMiles),
        actualDurationMinutes: Value(actualDurationMinutes),
        averagePaceMinutesPerMile: Value(averagePaceMinutesPerMile),
        maxHeartRate: Value(maxHeartRate),
        averageHeartRate: Value(averageHeartRate),
        caloriesBurned: Value(caloriesBurned),
        effortRating: Value(effortRating),
        nutritionRating: Value(nutritionRating),
        overallSatisfaction: Value(overallSatisfaction),
        textNotes: Value(textNotes),
        voiceNoteId: Value(voiceNoteId),
        hasVoiceRecording: Value(hasVoiceRecording ?? false),
        weatherConditions: Value(weatherConditions),
        temperatureFahrenheit: Value(temperatureFahrenheit),
        humidityPercent: Value(humidityPercent),
      );

      await _database.into(_database.activityCompletionsTable).insert(companion);

      // Get the created completion
      final completion = await getCompletionForActivity(activityId);
      if (completion == null) {
        throw Exception('Failed to retrieve created completion');
      }

      return completion;
    } catch (e) {
      _logger.error('Error completing activity: $activityId', error: e);
      rethrow;
    }
  }

  /// Get completion data for an activity
  Future<domain.ActivityCompletion?> getCompletionForActivity(String activityId) async {
    try {
      final query = _database.select(_database.activityCompletionsTable)
            ..where((tbl) => tbl.activityId.equals(activityId));

      final completion = await query.getSingleOrNull();

      return completion != null ? _mapToCompletionDomain(completion) : null;
    } catch (e) {
      _logger.error('Error getting completion for activity: $activityId', error: e);
      rethrow;
    }
  }

  /// Update activity completion notes
  Future<void> updateActivityCompletion({
    required String activityId,
    String? textNotes,
  }) async {
    try {
      final companion = ActivityCompletionsTableCompanion(
        textNotes: Value(textNotes),
      );

      await (_database.update(_database.activityCompletionsTable)
            ..where((tbl) => tbl.activityId.equals(activityId)))
          .write(companion);
    } catch (e) {
      _logger.error('Error updating activity completion: $activityId', error: e);
      rethrow;
    }
  }

  /// Generate a unique ID for completions
  String _generateId() {
    return 'completion_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Map database ActivityCompletion to domain ActivityCompletion
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
    );
  }
}

import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../application/activity_completions_service.dart';
import '../../domain/activity_completion.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/providers/device_id_provider.dart';

part 'activity_completions_controller.g.dart';

/// Controller for managing activity completions
/// Handles recording and updating activity completion data
@riverpod
class ActivityCompletionsController extends _$ActivityCompletionsController {
  ActivityCompletionsService get _service => ref.read(activityCompletionsServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<void> build() {
    // No state to load on build - completions are fetched on demand
    return null;
  }

  /// Complete an activity with detailed metrics
  Future<ActivityCompletion> completeActivity({
    required String activityId,
    required DateTime completedAt,
    CompletionType completionType = CompletionType.manual,
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
      final userId = await ref.read(deviceIdProvider.future);

      final completion = await _service.completeActivity(
        activityId: activityId,
        userId: userId,
        completedAt: completedAt,
        completionType: completionType,
        actualDistanceMiles: actualDistanceMiles,
        actualDurationMinutes: actualDurationMinutes,
        averagePaceMinutesPerMile: averagePaceMinutesPerMile,
        maxHeartRate: maxHeartRate,
        averageHeartRate: averageHeartRate,
        caloriesBurned: caloriesBurned,
        effortRating: effortRating,
        nutritionRating: nutritionRating,
        overallSatisfaction: overallSatisfaction,
        textNotes: textNotes,
        voiceNoteId: voiceNoteId,
        hasVoiceRecording: hasVoiceRecording,
        weatherConditions: weatherConditions,
        temperatureFahrenheit: temperatureFahrenheit,
        humidityPercent: humidityPercent,
      );

      return completion;
    } catch (e) {
      _logger.error('Error completing activity', error: e);
      rethrow;
    }
  }

  /// Update activity completion notes
  Future<void> updateActivityCompletion({
    required String activityId,
    String? textNotes,
  }) async {
    try {
      await _service.updateActivityCompletion(
        activityId: activityId,
        textNotes: textNotes,
      );
    } catch (e) {
      _logger.error('Error updating activity completion', error: e);
      rethrow;
    }
  }

  /// Get completion for an activity
  Future<ActivityCompletion?> getCompletionForActivity(String activityId) async {
    try {
      return await _service.getCompletionForActivity(activityId);
    } catch (e) {
      _logger.error('Error getting completion for activity', error: e);
      rethrow;
    }
  }
}

/// Provider for getting completion data for a specific activity
@riverpod
Future<ActivityCompletion?> activityCompletion(Ref ref, String activityId) async {
  final service = ref.read(activityCompletionsServiceProvider);
  return await service.getCompletionForActivity(activityId);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/feature_survey_data.dart';
import '../data/feature_survey_repository.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/database/app_database.dart';
import '../../../core/utils/debug_logger.dart';

/// Service for feature survey business logic and analytics tracking
/// Coordinates between repository (local storage) and Mixpanel (analytics)
class FeatureSurveyService {
  FeatureSurveyService(this.ref);
  final Ref ref;

  FeatureSurveyRepository get _repository =>
      ref.read(featureSurveyRepositoryProvider);
  AnalyticsTracker get _analytics =>
      ref.read(appExternalDepsProvider).analytics;
  AppDatabase get _database => ref.read(appDatabaseProvider);

  static const _uuid = Uuid();

  /// Check if the current device has already voted
  Future<bool> hasVoted() async {
    final user = await _database.userDao.getCurrentUserProfile();
    final deviceId = user?.id ?? 'anonymous';
    return await _repository.hasVoted(deviceId);
  }

  /// Get previous votes for the current device
  Future<FeatureSurveyResponse?> getPreviousVotes() async {
    final user = await _database.userDao.getCurrentUserProfile();
    final deviceId = user?.id ?? 'anonymous';
    return await _repository.getPreviousVotes(deviceId);
  }

  /// Submit survey response
  /// Saves to local database and tracks to Mixpanel
  Future<void> submitSurvey(List<Feature> selectedFeatures) async {
    if (selectedFeatures.length != 3) {
      throw ArgumentError('Must select exactly 3 features');
    }

    // 1. Get device ID
    final user = await _database.userDao.getCurrentUserProfile();
    final deviceId = user?.id ?? 'anonymous';

    // 2. Create survey response with unique session ID
    final sessionId = _uuid.v4();
    final response = FeatureSurveyResponse(
      id: sessionId,
      deviceId: deviceId,
      selectedFeatures: selectedFeatures,
      votedAt: DateTime.now(),
    );

    // 3. Save to local database first (offline-first)
    await _repository.saveSurveyResponse(response);

    // 4. Track summary event in Mixpanel (with List property)
    try {
      await _analytics.trackFeatureSurveyCompleted(
        selectedFeatures: selectedFeatures.map((f) => f.id).toList(),
        totalVotes: selectedFeatures.length,
        deviceId: deviceId,
      );

      // 5. Track individual feature votes (for detailed analysis)
      for (var i = 0; i < selectedFeatures.length; i++) {
        await _analytics.trackFeatureVoted(
          featureId: selectedFeatures[i].id,
          featureName: selectedFeatures[i].name,
          rank: i + 1, // 1 = highest priority
          surveySessionId: sessionId, // Groups votes from same submission
          deviceId: deviceId,
        );
      }

      // 6. Update user profile in Mixpanel
      await _analytics.identifyUser(
        deviceId,
        properties: {
          'voted_features': selectedFeatures.map((f) => f.id).toList(),
          'last_survey_date': DateTime.now().toIso8601String(),
          'feature_survey_voted': true,
          'survey_version': 'features_v1',
        },
      );

      // 7. Flush events to ensure immediate delivery
      await _analytics.flush();
    } catch (e) {
      // Analytics errors shouldn't block the user
      // Just log and continue - the vote is already saved locally
      DebugLogger.warning('Failed to track survey to Mixpanel: $e');
    }
  }

  /// Delete survey response (for testing or future "reset vote" feature)
  Future<void> deleteSurveyResponse() async {
    final user = await _database.userDao.getCurrentUserProfile();
    final deviceId = user?.id ?? 'anonymous';
    await _repository.deleteSurveyResponse(deviceId);
  }

  /// Get all survey responses (for admin/analytics)
  Future<List<FeatureSurveyResponse>> getAllResponses() async {
    return await _repository.getAllResponses();
  }
}

/// Provider for feature survey service
final featureSurveyServiceProvider = Provider<FeatureSurveyService>((ref) {
  return FeatureSurveyService(ref);
});

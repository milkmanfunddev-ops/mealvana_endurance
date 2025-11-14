import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../domain/feature_survey_data.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/services/supabase/supabase_client_provider.dart';
import '../../../core/utils/debug_logger.dart';

/// Repository for feature survey responses
/// Handles local storage of user votes in Drift database
class FeatureSurveyRepository {
  FeatureSurveyRepository(this.ref);
  final Ref ref;

  AppDatabase get _database => ref.read(appDatabaseProvider);

  /// Check if device has already voted
  Future<bool> hasVoted(String deviceId) async {
    final query = _database.select(_database.featureSurveyResponsesTable)
      ..where((row) => row.userId.equals(deviceId));

    final results = await query.get();
    return results.isNotEmpty;
  }

  /// Get previous votes for device
  Future<FeatureSurveyResponse?> getPreviousVotes(String deviceId) async {
    final query = _database.select(_database.featureSurveyResponsesTable)
      ..where((row) => row.userId.equals(deviceId));

    final results = await query.get();
    if (results.isEmpty) return null;

    final entry = results.first;
    return FeatureSurveyResponse.fromDatabase(
      {
        'id': entry.id.toString(),
        'device_id': entry.userId,
        'selected_features': entry.selectedFeatures,
        'voted_at': entry.votedAt.toIso8601String(),
      },
      FeatureDefinitions.allFeatures,
    );
  }

  /// Save survey response
  /// Uses insertOrReplace mode to allow updates (for future enhancement)
  Future<void> saveSurveyResponse(FeatureSurveyResponse response) async {
    // 1. Save to local Drift database first (offline-first)
    await _database.into(_database.featureSurveyResponsesTable).insert(
          FeatureSurveyResponsesTableCompanion(
            userId: Value(response.deviceId),
            selectedFeatures: Value(
              jsonEncode(response.selectedFeatures.map((f) => f.id).toList()),
            ),
            votedAt: Value(response.votedAt),
          ),
          mode: InsertMode.insertOrReplace, // Update if already exists
        );

    // 2. Sync to Supabase (best-effort, don't block on failure)
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('feature_survey_responses').upsert({
        'id': response.id,
        'device_id': response.deviceId,
        'selected_features':
            jsonEncode(response.selectedFeatures.map((f) => f.id).toList()),
        'voted_at': response.votedAt.toIso8601String(),
      });
    } catch (e) {
      // Log but don't throw - local save is what matters
      // Analytics and backend sync are secondary concerns
      DebugLogger.warning('Failed to sync survey to Supabase: $e');
    }
  }

  /// Delete survey response (for testing or future "reset vote" feature)
  Future<void> deleteSurveyResponse(String deviceId) async {
    await (_database.delete(_database.featureSurveyResponsesTable)
          ..where((row) => row.userId.equals(deviceId)))
        .go();
  }

  /// Get all survey responses (for admin/analytics)
  Future<List<FeatureSurveyResponse>> getAllResponses() async {
    final results = await _database.select(_database.featureSurveyResponsesTable).get();

    return results.map((entry) {
      return FeatureSurveyResponse.fromDatabase(
        {
          'id': entry.id.toString(),
          'device_id': entry.userId,
          'selected_features': entry.selectedFeatures,
          'voted_at': entry.votedAt.toIso8601String(),
        },
        FeatureDefinitions.allFeatures,
      );
    }).toList();
  }
}

/// Provider for feature survey repository
final featureSurveyRepositoryProvider = Provider<FeatureSurveyRepository>((ref) {
  return FeatureSurveyRepository(ref);
});

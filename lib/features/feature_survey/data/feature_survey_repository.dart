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
    try {
      final query = _database.select(_database.featureSurveyResponsesTable)
        ..where((row) => row.deviceId.equals(deviceId));

      final results = await query.get();
      return results.isNotEmpty;
    } on FormatException {
      // Legacy rows may have TEXT timestamps; normalize and retry
      await _normalizeTimestamps();
      final query = _database.select(_database.featureSurveyResponsesTable)
        ..where((row) => row.deviceId.equals(deviceId));
      final results = await query.get();
      return results.isNotEmpty;
    }
  }

  /// Get previous votes for device
  Future<FeatureSurveyResponse?> getPreviousVotes(String deviceId) async {
    try {
      return await _getPreviousVotesInternal(deviceId);
    } on FormatException {
      // Legacy rows may have TEXT timestamps; normalize and retry
      await _normalizeTimestamps();
      return await _getPreviousVotesInternal(deviceId);
    }
  }

  Future<FeatureSurveyResponse?> _getPreviousVotesInternal(
      String deviceId) async {
    final query = _database.select(_database.featureSurveyResponsesTable)
      ..where((row) => row.deviceId.equals(deviceId));

    final results = await query.get();
    if (results.isEmpty) return null;

    final entry = results.first;
    return FeatureSurveyResponse.fromDatabase(
      {
        'id': entry.id.toString(),
        'device_id': entry.deviceId,
        'selected_features': entry.selectedFeatures,
        'voted_at': entry.votedAt.toIso8601String(),
      },
      FeatureDefinitions.allFeatures,
    );
  }

  /// Normalize legacy TEXT timestamps to Unix millis for Drift compatibility
  Future<void> _normalizeTimestamps() async {
    const timestampColumns = ['voted_at', 'local_updated_at'];

    for (final column in timestampColumns) {
      await _database.customStatement('''
        UPDATE feature_survey_responses
        SET $column = CAST(
          strftime('%s', replace(replace($column, 'T', ' '), 'Z', ''))
          AS INTEGER
        ) * 1000
        WHERE typeof($column) = 'text'
          AND $column IS NOT NULL
          AND $column != ''
          AND strftime('%s', replace(replace($column, 'T', ' '), 'Z', '')) IS NOT NULL;
      ''');
    }

    DebugLogger.info('Normalized feature_survey_responses timestamps');
  }

  /// Save survey response
  /// Uses insertOrReplace mode to allow updates (for future enhancement)
  Future<void> saveSurveyResponse(FeatureSurveyResponse response) async {
    await _database.ensureUserDataSyncColumns();
    // 1. Save to local Drift database first (offline-first)
    await _database.into(_database.featureSurveyResponsesTable).insert(
          FeatureSurveyResponsesTableCompanion(
            deviceId: Value(response.deviceId),
            selectedFeatures: Value(
              jsonEncode(response.selectedFeatures.map((f) => f.id).toList()),
            ),
            votedAt: Value(response.votedAt),
          ),
          mode: InsertMode.insertOrReplace, // Update if already exists
        );

    // Use Unix timestamp in milliseconds for Drift compatibility
    // (CURRENT_TIMESTAMP produces text format which Drift can't parse)
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await _database.customStatement(
      'UPDATE feature_survey_responses SET needs_upload = 1, local_updated_at = ? WHERE device_id = ?',
      [nowMillis, response.deviceId],
    );

    // 2. Sync to Supabase (best-effort, don't block on failure)
    try {
      final supabase = ref.read(supabaseClientProvider);
      // Don't send 'id' - let Supabase auto-generate it with bigserial
      // Use device_id as the unique key (has unique constraint in Supabase)
      await supabase.from('feature_survey_responses').upsert(
        {
          'device_id': response.deviceId,
          'selected_features':
              jsonEncode(response.selectedFeatures.map((f) => f.id).toList()),
          'voted_at': response.votedAt.toIso8601String(),
        },
        onConflict: 'device_id', // Upsert on unique constraint
      );

      await _database.customStatement(
        'UPDATE feature_survey_responses SET needs_upload = 0 WHERE device_id = ?',
        [response.deviceId],
      );
    } catch (e) {
      // Log but don't throw - local save is what matters
      // Analytics and backend sync are secondary concerns
      DebugLogger.warning('Failed to sync survey to Supabase: $e');
    }
  }

  /// Delete survey response (for testing or future "reset vote" feature)
  Future<void> deleteSurveyResponse(String deviceId) async {
    await (_database.delete(_database.featureSurveyResponsesTable)
          ..where((row) => row.deviceId.equals(deviceId)))
        .go();
  }

  /// Get all survey responses (for admin/analytics)
  Future<List<FeatureSurveyResponse>> getAllResponses() async {
    final results = await _database.select(_database.featureSurveyResponsesTable).get();

    return results.map((entry) {
      return FeatureSurveyResponse.fromDatabase(
        {
          'id': entry.id.toString(),
          'device_id': entry.deviceId,
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

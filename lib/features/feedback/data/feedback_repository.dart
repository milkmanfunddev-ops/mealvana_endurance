import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../../../shared/data/syncable_repository.dart';
import '../domain/feedback_data.dart';

/// Provider for feedback repository
final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  final database = ref.read(appDatabaseProvider);
  final deps = ref.read(appExternalDepsProvider);
  return FeedbackRepository(
    database,
    deps.logger,
    deps.supabaseClient,
    deps.sentry,
  );
});

/// Repository for handling feedback data persistence
/// Manages survey responses and notification preferences in local database and Supabase
class FeedbackRepository with SyncableRepository {
  FeedbackRepository(
    this._database,
    this._logger,
    this._supabase,
    this._sentry,
  );

  final AppDatabase _database;
  final AppLogger _logger;
  final SupabaseClient _supabase;
  final SentryReporter _sentry;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'feedback';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      _logger.info(
        'Syncing feedback from Supabase',
        context: 'FEEDBACK_REPOSITORY',
        data: {'userId': userId},
      );

      // NOTE: Feedback table uses device_id, not user_id
      // In our architecture, deviceId === userId
      final response = await _supabase
          .from('feedback')
          .select('*')
          .eq('user_name', userId) // feedback.user_name maps to device_id
          .order('created_at', ascending: false);

      final feedbackRecords = response as List<dynamic>;

      final syncedCount = await _upsertRemoteFeedbackPreservingDirty(
        feedbackRecords,
      );

      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Successfully synced feedback from Supabase',
        context: 'FEEDBACK_REPOSITORY',
        data: {'userId': userId, 'count': syncedCount},
      );

      return SyncResult.successful(syncedCount);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync feedback from Supabase',
        context: 'FEEDBACK_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      _logger.info(
        'Uploading dirty feedback to Supabase',
        context: 'FEEDBACK_REPOSITORY',
        data: {'userId': userId},
      );

      // Query Drift for dirty records (feedback uses deviceId)
      final dirtyRecords =
          await (_database.select(_database.feedbackTable)..where(
                (t) => t.needsUpload.equals(true) & t.deviceId.equals(userId),
              ))
              .get();

      if (dirtyRecords.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      _logger.debug(
        'Found dirty feedback to upload',
        context: 'FEEDBACK_REPOSITORY',
        data: {'count': dirtyRecords.length},
      );

      // Upload to Supabase
      final feedbackToUpload = dirtyRecords.map((record) {
        return _toSupabaseJson(record);
      }).toList();

      await _supabase.from('feedback').upsert(feedbackToUpload);

      // Clear dirty flags
      await _database.batch((batch) {
        for (final record in dirtyRecords) {
          batch.update(
            _database.feedbackTable,
            const FeedbackTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(record.id),
          );
        }
      });

      _logger.info(
        'Successfully uploaded dirty feedback',
        context: 'FEEDBACK_REPOSITORY',
        data: {'count': dirtyRecords.length},
      );

      return UploadResult.successful(dirtyRecords.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty feedback',
        context: 'FEEDBACK_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return UploadResult.failed(e.toString());
    }
  }

  Future<int> _upsertRemoteFeedbackPreservingDirty(
    List<dynamic> remoteRows,
  ) async {
    final remoteById = <String, Map<String, dynamic>>{};
    for (final item in remoteRows) {
      if (item is! Map) continue;
      final mapped = Map<String, dynamic>.from(item);
      final id = mapped['id']?.toString();
      if (id == null || id.isEmpty) continue;
      remoteById[id] = mapped;
    }

    if (remoteById.isEmpty) {
      return 0;
    }

    final remoteIds = remoteById.keys.toList(growable: false);
    final dirtyRows = await (_database.select(
      _database.feedbackTable,
    )..where((t) => t.id.isIn(remoteIds) & t.needsUpload.equals(true))).get();
    final dirtyIds = dirtyRows.map((row) => row.id).toSet();

    var upsertedCount = 0;
    await _database.batch((batch) {
      for (final entry in remoteById.entries) {
        if (dirtyIds.contains(entry.key)) {
          continue;
        }

        final companion = _mapSupabaseJsonToCompanion(entry.value);
        batch.insert(
          _database.feedbackTable,
          companion,
          mode: InsertMode.insertOrReplace,
        );
        upsertedCount++;
      }
    });

    if (dirtyIds.isNotEmpty) {
      _logger.warning(
        'Skipped remote feedback overwrite for dirty local rows',
        context: 'FEEDBACK_REPOSITORY',
        data: {
          'skippedCount': dirtyIds.length,
          'totalRemote': remoteById.length,
        },
      );
    }

    return upsertedCount;
  }

  // ========================================================================
  // Existing Methods
  // ========================================================================

  /// Save survey response to both local database and Supabase
  Future<void> saveSurveyResponse(SurveyResponse response) async {
    final localId = DateTime.now().millisecondsSinceEpoch.toString();

    // Save to local database first (for offline access)
    await _database.contentDao.saveSurveyResponse(
      id: localId,
      confidenceLevel: response.confidenceLevel.value,
      confidenceLabel: response.confidenceLevel.label,
      reuseIntent: response.reuseIntent.value,
      reminderRequested: response.reminderPreference != null,
      missedReasons: response.missedReason != null
          ? [response.missedReason!.value]
          : null,
      missedOther: response.missedOther,
      reminderDayOfWeek: response.reminderPreference?.dayOfWeek,
      reminderHour: response.reminderPreference?.hour,
      reminderMinute: response.reminderPreference?.minute,
      reminderRecurring: response.reminderPreference?.isRecurring,
      deviceId: response.deviceId,
      planName: response.planName,
    );

    try {
      await _saveToSupabase(response);
      await _database.customStatement(
        'UPDATE feedback SET needs_upload = 0 WHERE id = ?',
        [localId],
      );
    } catch (e, stackTrace) {
      _logger.warning(
        'Immediate upload failed; record stays dirty for retry',
        context: 'FEEDBACK_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'operation': 'create', 'recordId': localId},
      );
      _sentry.reportNetworkError(
        e,
        url: 'supabase:feedback:create',
        method: 'INSERT',
        stackTrace: stackTrace,
      );
    }
  }

  /// Save survey response to Supabase feedback table
  Future<void> _saveToSupabase(SurveyResponse response) async {
    final feedbackId = const Uuid().v4();
    final feedbackData = {
      'id': feedbackId,
      'satisfaction_level': response.confidenceLevel.value,
      'satisfaction_emoji': _getConfidenceEmoji(response.confidenceLevel),
      'satisfaction_label': response.confidenceLevel.label,
      'confidence_level': response.confidenceLevel.value,
      'confidence_label': response.confidenceLevel.label,
      'reuse_intent': response.reuseIntent.value,
      'reminder_requested': response.reminderPreference != null,
      'missed_reasons': response.missedReason?.value,
      'missed_other': response.missedOther,
      'reminder_day_of_week': response.reminderPreference?.dayOfWeek,
      'reminder_hour': response.reminderPreference?.hour ?? 17,
      'reminder_minute': response.reminderPreference?.minute ?? 0,
      'reminder_recurring': response.reminderPreference?.isRecurring ?? false,
      'plan_name': response.planName,
      'user_name': response.deviceId, // Using deviceId as user identifier
      'timestamp':
          response.timestamp?.toIso8601String() ??
          DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('feedback').insert(feedbackData).select();
    } catch (e) {
      _logger.error(
        'Supabase insert failed for survey feedback',
        context: 'FEEDBACK',
        error: e,
      );
      rethrow; // Let the caller handle the error
    }
  }

  /// Get emoji for confidence level (since ConfidenceLevel doesn't have emoji property)
  String _getConfidenceEmoji(ConfidenceLevel level) {
    switch (level) {
      case ConfidenceLevel.notAtAll:
        return '😞';
      case ConfidenceLevel.aLittle:
        return '😐';
      case ConfidenceLevel.somewhat:
        return '🤔';
      case ConfidenceLevel.very:
        return '😊';
      case ConfidenceLevel.extremely:
        return '🤗';
    }
  }

  /// Get latest survey response for device
  Future<FeedbackEntry?> getLatestSurveyResponse(String deviceId) async {
    return await _database.contentDao.getLatestSurveyResponse(deviceId);
  }

  /// Update user notification preferences
  Future<void> updateUserNotificationPreferences({
    required String userId,
    required NotificationPreference preference,
  }) async {
    await _database.userDao.updateUserNotificationPreferences(
      userId: userId,
      notificationsEnabled: true, // User explicitly requested notifications
      defaultReminderDay:
          preference.dayOfWeek ?? 4, // Default to Thursday if null
      defaultReminderHour: preference.hour,
      defaultReminderMinute: preference.minute,
      defaultReminderRecurring: preference.isRecurring,
    );
  }

  /// Check if user has submitted survey recently
  /// Rate limits to one survey per 24 hours per device to prevent spam/abuse
  Future<bool> hasRecentSurveyResponse(String deviceId) async {
    final latestResponse = await _database.contentDao.getLatestSurveyResponse(
      deviceId,
    );
    if (latestResponse == null) return false;

    final hoursSinceLastResponse = DateTime.now()
        .difference(latestResponse.createdAt)
        .inHours;

    // Allow one survey per 24 hours
    return hoursSinceLastResponse < 24;
  }

  /// Convert database entry to domain model for UI consumption
  SurveyResponse? convertToSurveyResponse(FeedbackEntry? entry) {
    if (entry == null) return null;

    final confidenceLevel = entry.confidenceLevel != null
        ? ConfidenceLevel.fromValue(entry.confidenceLevel!)
        : ConfidenceLevel.somewhat;

    final reuseIntent = entry.reuseIntent != null
        ? ReuseIntent.fromValue(entry.reuseIntent!)
        : ReuseIntent.maybe;

    NotificationPreference? reminderPreference;
    if (entry.reminderRequested && entry.reminderDayOfWeek != null) {
      reminderPreference = NotificationPreference(
        dayOfWeek: entry.reminderDayOfWeek!,
        hour: entry.reminderHour,
        minute: entry.reminderMinute,
        isRecurring: entry.reminderRecurring,
      );
    }

    MissedReason? missedReason;
    if (entry.missedReasons != null && entry.missedReasons!.isNotEmpty) {
      // Parse comma-separated reasons, take first one
      final reasons = entry.missedReasons!.split(',');
      if (reasons.isNotEmpty) {
        missedReason = MissedReason.fromValue(reasons.first.trim());
      }
    }

    return SurveyResponse(
      confidenceLevel: confidenceLevel,
      reuseIntent: reuseIntent,
      reminderPreference: reminderPreference,
      missedReason: missedReason,
      missedOther: entry.missedOther,
      deviceId: entry.deviceId,
      planName: entry.planName,
      timestamp: entry.createdAt,
    );
  }

  // ========================================================================
  // Helper Methods for Sync
  // ========================================================================

  /// Map Supabase JSON (snake_case) to Drift FeedbackTableCompanion
  FeedbackTableCompanion _mapSupabaseJsonToCompanion(
    Map<String, dynamic> json,
  ) {
    return FeedbackTableCompanion(
      id: Value(json['id'] as String),
      deviceId: Value(
        json['user_name'] as String?,
      ), // Supabase user_name -> Drift deviceId
      satisfactionLevel: Value(json['satisfaction_level'] as int),
      satisfactionEmoji: Value(json['satisfaction_emoji'] as String),
      satisfactionLabel: Value(json['satisfaction_label'] as String),
      appFeedback: Value(json['app_feedback'] as String?),
      suggestions: Value(json['suggestions'] as String?),
      planName: Value(json['plan_name'] as String?),
      userName: Value(json['user_name'] as String?),
      timestamp: Value(
        json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : null,
      ),
      confidenceLevel: Value(json['confidence_level'] as int?),
      confidenceLabel: Value(json['confidence_label'] as String?),
      reuseIntent: Value(json['reuse_intent']?.toString()),
      reminderRequested: Value(json['reminder_requested'] as bool? ?? false),
      missedReasons: Value(json['missed_reasons'] as String?),
      missedOther: Value(json['missed_other'] as String?),
      reminderDayOfWeek: Value(json['reminder_day_of_week'] as int?),
      reminderHour: Value(json['reminder_hour'] as int? ?? 17),
      reminderMinute: Value(json['reminder_minute'] as int? ?? 0),
      reminderRecurring: Value(json['reminder_recurring'] as bool? ?? false),
      needsUpload: const Value(false), // Coming from server, so not dirty
      localUpdatedAt: Value(DateTime.now()),
      createdAt: Value(DateTime.parse(json['created_at'] as String)),
    );
  }

  /// Map Drift FeedbackEntry to Supabase JSON (snake_case)
  Map<String, dynamic> _toSupabaseJson(FeedbackEntry entry) {
    return {
      'id': entry.id,
      'satisfaction_level': entry.satisfactionLevel,
      'satisfaction_emoji': entry.satisfactionEmoji,
      'satisfaction_label': entry.satisfactionLabel,
      'app_feedback': entry.appFeedback,
      'suggestions': entry.suggestions,
      'plan_name': entry.planName,
      'user_name': entry.deviceId, // Drift deviceId -> Supabase user_name
      'timestamp': entry.timestamp?.toIso8601String(),
      'confidence_level': entry.confidenceLevel,
      'confidence_label': entry.confidenceLabel,
      'reuse_intent': entry.reuseIntent,
      'reminder_requested': entry.reminderRequested,
      'missed_reasons': entry.missedReasons,
      'missed_other': entry.missedOther,
      'reminder_day_of_week': entry.reminderDayOfWeek,
      'reminder_hour': entry.reminderHour,
      'reminder_minute': entry.reminderMinute,
      'reminder_recurring': entry.reminderRecurring,
      'created_at': entry.createdAt.toIso8601String(),
    };
  }
}

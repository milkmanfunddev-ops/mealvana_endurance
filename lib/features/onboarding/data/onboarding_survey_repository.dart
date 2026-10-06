import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/syncable_repository.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/report/report.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../domain/onboarding_draft.dart';

part 'onboarding_survey_repository.g.dart';

@riverpod
OnboardingSurveyRepository onboardingSurveyRepository(Ref ref) {
  return OnboardingSurveyRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    report: ref.read(reportProvider),
  );
}

/// Repository for the one-row-per-user `onboarding_surveys` record
/// (sports/goals/pitfalls + `survey_payload` flag JSON).
///
/// Same offline-first shape as `formula_pins`: local write with
/// `needs_upload = true`, non-blocking immediate upload, dirty-preserving
/// remote sync, and coordinator-driven retry via [uploadDirtyRecords].
/// `user_id` is the primary key on both sides, so the PostgREST upsert
/// conflicts on `user_id` (a real PK — not a partial unique index).
///
/// Observability contract (redesign plan §6): every Drift write failure —
/// FK/constraint SqliteExceptions included — is captured to Sentry with
/// feature/step tags, never swallowed into a silent log line.
class OnboardingSurveyRepository with SyncableRepository {
  OnboardingSurveyRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required Report report,
  }) : _supabase = supabase,
       _database = database,
       _report = report;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final Report _report;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'onboarding_surveys';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      final response = await _supabase
          .from('onboarding_surveys')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        await setLastSyncTime(DateTime.now());
        return SyncResult.successful(0);
      }

      // Dirty-preserve: never clobber a local row awaiting upload.
      final local = await getSurveyRow(userId);
      if (local?.needsUpload == true) {
        _report.degraded(
          LoggedFault(
            'Skipped remote survey overwrite for dirty local row',
            context: 'onboarding',
          ),
          area: 'onboarding',
          extra: {'userId': userId},
        );
        await setLastSyncTime(DateTime.now());
        return SyncResult.successful(0);
      }

      await _database
          .into(_database.onboardingSurveysTable)
          .insert(
            _mapSupabaseJsonToCompanion(Map<String, dynamic>.from(response)),
            mode: InsertMode.insertOrReplace,
          );

      await setLastSyncTime(DateTime.now());
      return SyncResult.successful(1);
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'onboarding',
        extra: {'userId': userId},
        message: 'Failed to sync onboarding survey from Supabase',
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      final dirty =
          await (_database.select(_database.onboardingSurveysTable)..where(
                (t) => t.needsUpload.equals(true) & t.userId.equals(userId),
              ))
              .get();

      if (dirty.isEmpty) return UploadResult.nothingToUpload();

      await _supabase
          .from('onboarding_surveys')
          .upsert(dirty.map(_toSupabaseJson).toList(), onConflict: 'user_id');

      await (_database.update(
        _database.onboardingSurveysTable,
      )..where((t) => t.userId.equals(userId))).write(
        const OnboardingSurveysTableCompanion(needsUpload: Value(false)),
      );

      _report.info(
        'Uploaded onboarding survey',
        area: 'onboarding',
        data: {'userId': userId},
      );
      return UploadResult.successful(dirty.length);
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'onboarding',
        extra: {'userId': userId},
        message: 'Failed to upload onboarding survey',
      );
      return UploadResult.failed(e.toString());
    }
  }

  // ========================================================================
  // Write path
  // ========================================================================

  /// Upsert the survey for [userId] from the finished onboarding [draft].
  /// Local-first with `needs_upload = true`, then a non-blocking immediate
  /// upload; on any Drift failure the exception is reported to Sentry and
  /// rethrown so `saveAllOnboardingData` surfaces it (no silent failure).
  Future<void> saveSurveyFromDraft({
    required String userId,
    required OnboardingDraft draft,
    DateTime? completedAt,
  }) async {
    final now = DateTime.now();
    final payload = <String, dynamic>{
      if (draft.connectedProvider != null)
        'connected_provider': draft.connectedProvider,
      if (draft.declinedTrainingApps) 'declined_training_apps': true,
      if (draft.tridotNotifyRequested) 'tridot_notify': true,
      if (draft.sweatTestInterest) 'sweat_test_interest': true,
    };

    final companion = OnboardingSurveysTableCompanion.insert(
      userId: userId,
      sports: jsonEncode([for (final s in draft.sports) s.dbValue]),
      goals: jsonEncode([for (final g in draft.goals) g.dbValue]),
      pitfalls: jsonEncode([for (final p in draft.pitfalls) p.dbValue]),
      surveyPayload: Value(payload.isEmpty ? null : jsonEncode(payload)),
      completedAt: completedAt ?? now,
      createdAt: now,
      updatedAt: now,
      needsUpload: const Value(true),
      localUpdatedAt: Value(now),
    );

    try {
      await _database
          .into(_database.onboardingSurveysTable)
          .insert(companion, mode: InsertMode.insertOrReplace);
    } catch (e, stackTrace) {
      // FK/constraint SqliteExceptions land here — report loudly, then
      // rethrow so the controller's save step fails visibly.
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'onboarding',
        tags: {
          'operation': 'onboarding_survey_write',
          'table': 'onboarding_surveys',
        },
        extra: {'userId': userId},
        message: 'Failed to write onboarding survey to Drift',
      );
      rethrow;
    }

    _scheduleImmediateUpload(userId);
  }

  /// Move a locally-saved survey row from the temp onboarding user to the
  /// authenticated user (called from the controller's migration step; the
  /// diagnostic DAO's migrateUserData covers the delete-and-resync path).
  Future<void> migrateSurveyUser({
    required String fromUserId,
    required String toUserId,
  }) async {
    await _database.customStatement(
      'DELETE FROM onboarding_surveys WHERE user_id = ?',
      [toUserId],
    );
    await _database.customStatement(
      'UPDATE onboarding_surveys SET user_id = ?, needs_upload = 1 '
      'WHERE user_id = ?',
      [toUserId, fromUserId],
    );
  }

  // ========================================================================
  // Read path
  // ========================================================================

  @visibleForTesting
  Future<OnboardingSurveyEntry?> getSurveyRow(String userId) {
    return (_database.select(_database.onboardingSurveysTable)
          ..where((t) => t.userId.equals(userId))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Decoded survey lists for [userId] (unknown dbValues are skipped —
  /// forward-compat with newer clients' enum additions).
  Future<
    ({
      List<OnboardingSport> sports,
      List<OnboardingGoal> goals,
      List<OnboardingPitfall> pitfalls,
      Map<String, dynamic> payload,
    })?
  >
  getSurvey(String userId) async {
    final row = await getSurveyRow(userId);
    if (row == null) return null;
    return (
      sports: _decodeList(row.sports, OnboardingSport.fromDbValue),
      goals: _decodeList(row.goals, OnboardingGoal.fromDbValue),
      pitfalls: _decodeList(row.pitfalls, OnboardingPitfall.fromDbValue),
      payload: row.surveyPayload == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(row.surveyPayload!) as Map),
    );
  }

  // ========================================================================
  // Private helpers
  // ========================================================================

  void _scheduleImmediateUpload(String userId) {
    unawaited(() async {
      try {
        final result = await uploadDirtyRecords(userId);
        if (!result.success) {
          // uploadDirtyRecords swallows exceptions into UploadResult.failed —
          // per the repo-wide rule, always check and report the result.
          unawaited(
            _report.degraded(
              Exception(result.error ?? 'unknown upload failure'),
              area: 'network',
              tags: {'method': 'UPSERT'},
              extra: {'url': 'supabase:onboarding_surveys:immediate'},
            ),
          );
        }
      } catch (e, stackTrace) {
        _report.degraded(
          e,
          stackTrace: stackTrace,
          area: 'onboarding',
          extra: {'userId': userId},
          message: 'Immediate survey upload failed; row stays dirty for retry',
        );
      }
    }());
  }

  OnboardingSurveysTableCompanion _mapSupabaseJsonToCompanion(
    Map<String, dynamic> json,
  ) {
    return OnboardingSurveysTableCompanion.insert(
      userId: json['user_id'] as String,
      sports: jsonEncode(json['sports'] ?? const []),
      goals: jsonEncode(json['goals'] ?? const []),
      pitfalls: jsonEncode(json['pitfalls'] ?? const []),
      surveyPayload: Value(
        json['survey_payload'] == null
            ? null
            : jsonEncode(json['survey_payload']),
      ),
      completedAt: DateTime.parse(json['completed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      needsUpload: const Value(false),
      localUpdatedAt: Value(DateTime.now()),
    );
  }

  Map<String, dynamic> _toSupabaseJson(OnboardingSurveyEntry row) {
    return {
      'user_id': row.userId,
      'sports': jsonDecode(row.sports),
      'goals': jsonDecode(row.goals),
      'pitfalls': jsonDecode(row.pitfalls),
      'survey_payload': row.surveyPayload == null
          ? null
          : jsonDecode(row.surveyPayload!),
      'completed_at': row.completedAt.toUtc().toIso8601String(),
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
    };
  }

  List<T> _decodeList<T>(String json, T? Function(String?) parse) {
    final raw = jsonDecode(json) as List<dynamic>;
    return [
      for (final v in raw)
        if (parse(v as String?) case final T parsed) parsed,
    ];
  }
}

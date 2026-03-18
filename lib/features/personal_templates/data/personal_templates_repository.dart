import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/data/syncable_repository.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../domain/personal_template.dart';

part 'personal_templates_repository.g.dart';

@riverpod
PersonalTemplatesRepository personalTemplatesRepository(Ref ref) {
  final deps = ref.read(appExternalDepsProvider);
  return PersonalTemplatesRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    sentry: deps.sentry,
  );
}

/// Repository for personal nutrition plan templates
/// Implements SyncableRepository for offline-first sync
class PersonalTemplatesRepository with SyncableRepository {
  const PersonalTemplatesRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required SentryReporter sentry,
  }) : _supabase = supabase,
       _database = database,
       _logger = logger,
       _sentry = sentry;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final SentryReporter _sentry;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'personal_templates';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      _logger.info(
        'Syncing personal templates from Supabase',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        data: {'userId': userId},
      );

      final response = await _supabase
          .from('personal_templates')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final templates = response as List<dynamic>;
      final syncedCount = await _upsertRemoteTemplatesPreservingDirty(
        templates,
      );

      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Successfully synced personal templates from Supabase',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        data: {'userId': userId, 'count': syncedCount},
      );

      return SyncResult.successful(syncedCount);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync personal templates from Supabase',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return SyncResult.failed(e.toString());
    }
  }

  Future<int> _upsertRemoteTemplatesPreservingDirty(
    List<dynamic> remoteTemplates,
  ) async {
    final remoteById = <String, Map<String, dynamic>>{};

    for (final item in remoteTemplates) {
      if (item is! Map) continue;
      final mapped = Map<String, dynamic>.from(item);
      final id = mapped['id']?.toString();
      if (id == null || id.isEmpty) continue;
      remoteById[id] = mapped;
    }

    if (remoteById.isEmpty) return 0;

    final remoteIds = remoteById.keys.toList(growable: false);
    final dirtyRows =
        await (_database.select(_database.personalTemplatesTable)..where(
              (tbl) => tbl.id.isIn(remoteIds) & tbl.needsUpload.equals(true),
            ))
            .get();
    final dirtyIds = dirtyRows.map((row) => row.id).toSet();

    var upsertedCount = 0;
    await _database.batch((batch) {
      for (final entry in remoteById.entries) {
        if (dirtyIds.contains(entry.key)) continue;

        final companion = _mapSupabaseJsonToCompanion(entry.value);
        batch.insert(
          _database.personalTemplatesTable,
          companion,
          mode: InsertMode.insertOrReplace,
        );
        upsertedCount++;
      }
    });

    if (dirtyIds.isNotEmpty) {
      _logger.warning(
        'Skipped remote template overwrite for dirty local rows',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        data: {
          'skippedCount': dirtyIds.length,
          'totalRemote': remoteById.length,
        },
      );
    }

    return upsertedCount;
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      _logger.info(
        'Uploading dirty personal templates to Supabase',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        data: {'userId': userId},
      );

      final dirtyRecords =
          await (_database.select(_database.personalTemplatesTable)..where(
                (t) => t.needsUpload.equals(true) & t.userId.equals(userId),
              ))
              .get();

      if (dirtyRecords.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      _logger.debug(
        'Found dirty personal templates to upload',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        data: {'count': dirtyRecords.length},
      );

      final templatesToUpload = dirtyRecords.map((record) {
        return PersonalTemplate.fromDriftEntry(record).toSupabaseJson();
      }).toList();

      // CRITICAL: Use onConflict: 'id' to avoid PostgREST partial index issues
      await _supabase
          .from('personal_templates')
          .upsert(templatesToUpload, onConflict: 'id');

      // Clear dirty flags
      await _database.batch((batch) {
        for (final record in dirtyRecords) {
          batch.update(
            _database.personalTemplatesTable,
            const PersonalTemplatesTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(record.id),
          );
        }
      });

      _logger.info(
        'Successfully uploaded dirty personal templates',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        data: {'count': dirtyRecords.length},
      );

      return UploadResult.successful(dirtyRecords.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty personal templates',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return UploadResult.failed(e.toString());
    }
  }

  // ========================================================================
  // CRUD Methods
  // ========================================================================

  /// Get all templates for a user, sorted by updatedAt desc
  Future<List<PersonalTemplate>> getTemplatesForUser(String userId) async {
    try {
      final query = _database.select(_database.personalTemplatesTable)
        ..where((tbl) => tbl.userId.lower().equals(userId.toLowerCase()))
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);

      final entries = await query.get();
      return entries.map(PersonalTemplate.fromDriftEntry).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get templates for user',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get templates filtered by sport type
  Future<List<PersonalTemplate>> getTemplatesForSport(
    String userId,
    String activityType,
  ) async {
    try {
      final query = _database.select(_database.personalTemplatesTable)
        ..where(
          (tbl) =>
              tbl.userId.lower().equals(userId.toLowerCase()) &
              tbl.activityType.equals(activityType),
        )
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);

      final entries = await query.get();
      return entries.map(PersonalTemplate.fromDriftEntry).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get templates for sport',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get brick templates matching exact segment order
  Future<List<PersonalTemplate>> getTemplatesForBrick(
    String userId,
    List<String> segmentOrder,
  ) async {
    try {
      final encodedOrder = jsonEncode(segmentOrder);
      final query = _database.select(_database.personalTemplatesTable)
        ..where(
          (tbl) =>
              tbl.userId.lower().equals(userId.toLowerCase()) &
              tbl.activityType.equals('brick') &
              tbl.brickSegmentOrder.equals(encodedOrder),
        )
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);

      final entries = await query.get();
      return entries.map(PersonalTemplate.fromDriftEntry).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get templates for brick',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get a single template by ID
  Future<PersonalTemplate?> getTemplateById(String id) async {
    try {
      final query = _database.select(_database.personalTemplatesTable)
        ..where((tbl) => tbl.id.equals(id));

      final entry = await query.getSingleOrNull();
      return entry != null ? PersonalTemplate.fromDriftEntry(entry) : null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get template by ID',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a new template (offline-first)
  Future<PersonalTemplate> createTemplate(PersonalTemplate template) async {
    try {
      final templateWithDirtyFlag = template.copyWith(
        needsUpload: true,
        localUpdatedAt: DateTime.now(),
      );

      final companion = templateWithDirtyFlag.toDriftCompanion();
      final insertedRow = await _database
          .into(_database.personalTemplatesTable)
          .insertReturning(companion);

      _logger.info(
        'Created personal template',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        data: {'templateId': insertedRow.id, 'name': template.name},
      );

      final created = PersonalTemplate.fromDriftEntry(insertedRow);

      // Attempt immediate upload (non-blocking)
      unawaited(() async {
        try {
          await _supabase
              .from('personal_templates')
              .upsert(created.toSupabaseJson(), onConflict: 'id');
          await _clearDirtyFlag(created.id);
        } catch (e, stackTrace) {
          _logger.warning(
            'Immediate upload failed; template stays dirty for retry',
            context: 'PERSONAL_TEMPLATES_REPOSITORY',
            error: e,
            stackTrace: stackTrace,
            data: {'templateId': created.id},
          );
          _sentry.reportNetworkError(
            e,
            url: 'supabase:personal_templates:create',
            method: 'UPSERT',
            stackTrace: stackTrace,
          );
        }
      }());

      return created;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create personal template',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update a template's name (offline-first)
  Future<void> updateTemplateName(String id, String newName) async {
    try {
      await (_database.update(
        _database.personalTemplatesTable,
      )..where((tbl) => tbl.id.equals(id))).write(
        PersonalTemplatesTableCompanion(
          name: Value(newName),
          updatedAt: Value(DateTime.now()),
          needsUpload: const Value(true),
          localUpdatedAt: Value(DateTime.now()),
        ),
      );

      _logger.info(
        'Updated personal template name',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        data: {'templateId': id, 'newName': newName},
      );

      // Attempt immediate upload (non-blocking)
      unawaited(() async {
        try {
          final template = await getTemplateById(id);
          if (template != null) {
            await _supabase
                .from('personal_templates')
                .upsert(template.toSupabaseJson(), onConflict: 'id');
            await _clearDirtyFlag(id);
          }
        } catch (e, stackTrace) {
          _logger.warning(
            'Immediate upload failed; template stays dirty for retry',
            context: 'PERSONAL_TEMPLATES_REPOSITORY',
            error: e,
            stackTrace: stackTrace,
            data: {'templateId': id},
          );
        }
      }());
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update personal template name',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a template (hard delete locally + Supabase)
  Future<void> deleteTemplate(String id, String userId) async {
    try {
      // Hard delete from Drift
      await (_database.delete(
        _database.personalTemplatesTable,
      )..where((tbl) => tbl.id.equals(id))).go();

      _logger.info(
        'Deleted personal template locally',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        data: {'templateId': id},
      );

      // Attempt Supabase deletion (non-blocking)
      unawaited(() async {
        try {
          await _supabase
              .from('personal_templates')
              .delete()
              .eq('id', id)
              .eq('user_id', userId);
        } catch (e, stackTrace) {
          _logger.warning(
            'Failed to delete template from Supabase',
            context: 'PERSONAL_TEMPLATES_REPOSITORY',
            error: e,
            stackTrace: stackTrace,
            data: {'templateId': id},
          );
          _sentry.reportNetworkError(
            e,
            url: 'supabase:personal_templates:delete',
            method: 'DELETE',
            stackTrace: stackTrace,
          );
        }
      }());
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete personal template',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get template count for a user (for enforcing 10-template limit)
  Future<int> getTemplateCount(String userId) async {
    try {
      final query = _database.select(_database.personalTemplatesTable)
        ..where((tbl) => tbl.userId.lower().equals(userId.toLowerCase()));

      final entries = await query.get();
      return entries.length;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get template count',
        context: 'PERSONAL_TEMPLATES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ========================================================================
  // Private Helpers
  // ========================================================================

  Future<void> _clearDirtyFlag(String templateId) async {
    await (_database.update(
      _database.personalTemplatesTable,
    )..where((tbl) => tbl.id.equals(templateId))).write(
      const PersonalTemplatesTableCompanion(needsUpload: Value(false)),
    );
  }

  PersonalTemplatesTableCompanion _mapSupabaseJsonToCompanion(
    Map<String, dynamic> json,
  ) {
    // plan_data comes as Map from Supabase JSONB, encode to string for Drift
    String planDataStr;
    final rawPlan = json['plan_data'];
    if (rawPlan is Map || rawPlan is List) {
      planDataStr = jsonEncode(rawPlan);
    } else if (rawPlan is String) {
      planDataStr = rawPlan;
    } else {
      planDataStr = '{}';
    }

    // brick_segment_order comes as List from Supabase array, encode to string for Drift
    String? segmentOrderStr;
    final rawSegments = json['brick_segment_order'];
    if (rawSegments is List) {
      segmentOrderStr = jsonEncode(rawSegments);
    }

    return PersonalTemplatesTableCompanion.insert(
      id: Value(json['id'] as String),
      userId: json['user_id'] as String,
      name: json['name'] as String,
      activityType: json['activity_type'] as String,
      originalDurationMinutes: Value(json['original_duration_minutes'] as int?),
      originalDistance: Value((json['original_distance'] as num?)?.toDouble()),
      originalActivityTitle: Value(json['original_activity_title'] as String?),
      planData: planDataStr,
      totalCarbsG: Value(json['total_carbs_g'] as int?),
      totalProteinG: Value(json['total_protein_g'] as int?),
      totalFatG: Value(json['total_fat_g'] as int?),
      totalSodiumMg: Value(json['total_sodium_mg'] as int?),
      totalFluidsMl: Value(json['total_fluids_ml'] as int?),
      totalCalories: Value(json['total_calories'] as int?),
      brickSegmentOrder: Value(segmentOrderStr),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      needsUpload: const Value(false),
      localUpdatedAt: Value(DateTime.now()),
    );
  }
}

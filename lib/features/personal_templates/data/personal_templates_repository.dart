import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/data/syncable_repository.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../domain/personal_template.dart';
import '../../../shared/services/report/decode_issue_report.dart';
import '../../../shared/services/report/report.dart';

part 'personal_templates_repository.g.dart';

@riverpod
PersonalTemplatesRepository personalTemplatesRepository(Ref ref) {
  return PersonalTemplatesRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    report: ref.read(reportProvider),
  );
}

/// Repository for personal nutrition plan templates
/// Implements SyncableRepository for offline-first sync
class PersonalTemplatesRepository with SyncableRepository {
  const PersonalTemplatesRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required Report report,
  }) : _supabase = supabase,
       _database = database,
       _report = report;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final Report _report;

  /// Drift row → domain, reporting a malformed JSON column as Degraded.
  PersonalTemplate _fromEntry(PersonalTemplateEntry entry) =>
      PersonalTemplate.fromDriftEntry(
        entry,
        onIssue: _report.decodeIssue('personal_templates'),
      );

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
      _report.info(
        'Syncing personal templates from Supabase',
        area: 'personal_templates',
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

      _report.info(
        'Successfully synced personal templates from Supabase',
        area: 'personal_templates',
        data: {'userId': userId, 'count': syncedCount},
      );

      return SyncResult.successful(syncedCount);
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'personal_templates',
        extra: {'userId': userId},
        message: 'Failed to sync personal templates from Supabase',
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
      _report.degraded(
        LoggedFault(
          'Skipped remote template overwrite for dirty local rows',
          context: 'PERSONAL_TEMPLATES_REPOSITORY',
        ),
        area: 'personal_templates',
        extra: {
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
      _report.info(
        'Uploading dirty personal templates to Supabase',
        area: 'personal_templates',
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

      _report.debug(
        'Found dirty personal templates to upload',
        area: 'personal_templates',
        data: {'count': dirtyRecords.length},
      );

      final templatesToUpload = dirtyRecords.map((record) {
        return _fromEntry(record).toSupabaseJson();
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

      _report.info(
        'Successfully uploaded dirty personal templates',
        area: 'personal_templates',
        data: {'count': dirtyRecords.length},
      );

      return UploadResult.successful(dirtyRecords.length);
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'personal_templates',
        extra: {'userId': userId},
        message: 'Failed to upload dirty personal templates',
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
      return entries.map(_fromEntry).toList();
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'personal_templates',
        message: 'Failed to get templates for user',
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
      return entries.map(_fromEntry).toList();
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'personal_templates',
        message: 'Failed to get templates for sport',
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
      return entries.map(_fromEntry).toList();
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'personal_templates',
        message: 'Failed to get templates for brick',
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
      return entry != null ? _fromEntry(entry) : null;
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'personal_templates',
        message: 'Failed to get template by ID',
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

      _report.info(
        'Created personal template',
        area: 'personal_templates',
        data: {'templateId': insertedRow.id, 'name': template.name},
      );

      final created = _fromEntry(insertedRow);

      // Attempt immediate upload (non-blocking)
      unawaited(() async {
        try {
          await _supabase
              .from('personal_templates')
              .upsert(created.toSupabaseJson(), onConflict: 'id');
          await _clearDirtyFlag(created.id);
        } catch (e, stackTrace) {
          _report.degraded(
            e,
            stackTrace: stackTrace,
            area: 'personal_templates',
            extra: {'templateId': created.id},
            message: 'Immediate upload failed; template stays dirty for retry',
          );
          _report.degraded(
            e,
            stackTrace: stackTrace,
            area: 'network',
            tags: {'method': 'UPSERT'},
            extra: {'url': 'supabase:personal_templates:create'},
          );
        }
      }());

      return created;
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'personal_templates',
        message: 'Failed to create personal template',
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

      _report.info(
        'Updated personal template name',
        area: 'personal_templates',
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
          _report.degraded(
            e,
            stackTrace: stackTrace,
            area: 'personal_templates',
            extra: {'templateId': id},
            message: 'Immediate upload failed; template stays dirty for retry',
          );
        }
      }());
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'personal_templates',
        message: 'Failed to update personal template name',
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

      _report.info(
        'Deleted personal template locally',
        area: 'personal_templates',
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
          _report.degraded(
            e,
            stackTrace: stackTrace,
            area: 'personal_templates',
            extra: {'templateId': id},
            message: 'Failed to delete template from Supabase',
          );
          _report.degraded(
            e,
            stackTrace: stackTrace,
            area: 'network',
            tags: {'method': 'DELETE'},
            extra: {'url': 'supabase:personal_templates:delete'},
          );
        }
      }());
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'personal_templates',
        message: 'Failed to delete personal template',
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
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'personal_templates',
        message: 'Failed to get template count',
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

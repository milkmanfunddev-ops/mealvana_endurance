import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/data/syncable_repository.dart';
import 'carb_loading_mapper.dart';

part 'carb_loading_repository.g.dart';

class _CarbLoadingUpsertCount {
  const _CarbLoadingUpsertCount({required this.plans, required this.days});

  final int plans;
  final int days;

  int get total => plans + days;
}

@riverpod
CarbLoadingRepository carbLoadingRepository(Ref ref) {
  final deps = ref.read(appExternalDepsProvider);
  return CarbLoadingRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    sentry: deps.sentry,
  );
}

/// Repository for managing carb loading plans and days following FOA pattern
/// Implements SyncableRepository for new sync architecture
class CarbLoadingRepository with SyncableRepository {
  const CarbLoadingRepository({
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
  String get repositoryKey => 'carb_loading_plans';

  @override
  List<String> get dependencies => ['users', 'events'];

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      _logger.info(
        'Syncing carb loading data from Supabase',
        context: 'CARB_LOADING_REPOSITORY',
        data: {'userId': userId},
      );

      // 1. Sync carb_loading_plans for this user
      // Note: carb_loading_plans has no created_at column - use start_date for ordering
      final plansResponse = await _supabase
          .from('carb_loading_plans')
          .select('*')
          .eq('user_id', userId)
          .order('start_date', ascending: false);

      final plans = plansResponse as List<dynamic>;

      if (plans.isEmpty) {
        await setLastSyncTime(DateTime.now());
        _logger.info(
          'No carb loading plans to sync',
          context: 'CARB_LOADING_REPOSITORY',
          data: {'userId': userId},
        );
        return SyncResult.successful(0);
      }

      // 2. Get all plan IDs to query for days
      final planIds = plans.map((p) => p['id'] as String).toList();

      // 3. Sync carb_loading_days for those plans
      final daysResponse = await _supabase
          .from('carb_loading_days')
          .select('*')
          .inFilter('carb_loading_plan_id', planIds)
          .order('day_number', ascending: true);

      final days = daysResponse as List<dynamic>;

      final upsertCount = await _upsertRemoteCarbLoadingPreservingDirty(
        plans: plans,
        days: days,
      );

      // 5. Update last sync timestamp
      await setLastSyncTime(DateTime.now());

      final totalCount = upsertCount.total;

      _logger.info(
        'Successfully synced carb loading data',
        context: 'CARB_LOADING_REPOSITORY',
        data: {
          'userId': userId,
          'plans': upsertCount.plans,
          'days': upsertCount.days,
          'total': totalCount,
        },
      );

      return SyncResult.successful(totalCount);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync carb loading data from Supabase',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return SyncResult.failed(e.toString());
    }
  }

  Future<_CarbLoadingUpsertCount> _upsertRemoteCarbLoadingPreservingDirty({
    required List<dynamic> plans,
    required List<dynamic> days,
  }) async {
    final plansById = <String, Map<String, dynamic>>{};
    for (final item in plans) {
      if (item is! Map) continue;
      final mapped = Map<String, dynamic>.from(item);
      final id = mapped['id']?.toString();
      if (id == null || id.isEmpty) continue;
      plansById[id] = mapped;
    }

    final daysById = <String, Map<String, dynamic>>{};
    for (final item in days) {
      if (item is! Map) continue;
      final mapped = Map<String, dynamic>.from(item);
      final id = mapped['id']?.toString();
      if (id == null || id.isEmpty) continue;
      daysById[id] = mapped;
    }

    final planIds = plansById.keys.toList(growable: false);
    final dayIds = daysById.keys.toList(growable: false);

    final dirtyPlanIds = planIds.isEmpty
        ? <String>{}
        : (await (_database.select(_database.carbLoadingPlansTable)..where(
                    (tbl) =>
                        tbl.id.isIn(planIds) & tbl.needsUpload.equals(true),
                  ))
                  .get())
              .map((row) => row.id)
              .toSet();

    final dirtyDayIds = dayIds.isEmpty
        ? <String>{}
        : (await (_database.select(_database.carbLoadingDaysTable)..where(
                    (tbl) => tbl.id.isIn(dayIds) & tbl.needsUpload.equals(true),
                  ))
                  .get())
              .map((row) => row.id)
              .toSet();

    var planUpserts = 0;
    var dayUpserts = 0;
    await _database.transaction(() async {
      for (final entry in plansById.entries) {
        if (dirtyPlanIds.contains(entry.key)) {
          continue;
        }

        final companion = CarbLoadingMapper.mapPlanJsonToCompanion(entry.value);
        await _database
            .into(_database.carbLoadingPlansTable)
            .insert(companion, mode: InsertMode.insertOrReplace);
        planUpserts++;
      }

      for (final entry in daysById.entries) {
        if (dirtyDayIds.contains(entry.key)) {
          continue;
        }

        final companion = CarbLoadingMapper.mapDayJsonToCompanion(entry.value);
        await _database
            .into(_database.carbLoadingDaysTable)
            .insert(companion, mode: InsertMode.insertOrReplace);
        dayUpserts++;
      }
    });

    if (dirtyPlanIds.isNotEmpty || dirtyDayIds.isNotEmpty) {
      _logger.warning(
        'Skipped remote carb loading overwrite for dirty local rows',
        context: 'CARB_LOADING_REPOSITORY',
        data: {
          'skippedPlans': dirtyPlanIds.length,
          'skippedDays': dirtyDayIds.length,
        },
      );
    }

    return _CarbLoadingUpsertCount(plans: planUpserts, days: dayUpserts);
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      _logger.info(
        'Uploading dirty carb loading records to Supabase',
        context: 'CARB_LOADING_REPOSITORY',
        data: {'userId': userId},
      );

      // 1. Query dirty plans
      final dirtyPlans =
          await (_database.select(_database.carbLoadingPlansTable)..where(
                (t) => t.needsUpload.equals(true) & t.userId.equals(userId),
              ))
              .get();

      // 2. Query dirty days belonging to this user's plans
      if (dirtyPlans.isEmpty) {
        // Early exit if no dirty plans - also no dirty days need uploading
        return UploadResult.nothingToUpload();
      }

      final userPlanIds = dirtyPlans.map((p) => p.id).toList();

      // Get all days for these plans that are dirty
      final dirtyDays =
          await (_database.select(_database.carbLoadingDaysTable)..where(
                (t) =>
                    t.needsUpload.equals(true) &
                    t.carbLoadingPlanId.isIn(userPlanIds),
              ))
              .get();

      if (dirtyPlans.isEmpty && dirtyDays.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      _logger.debug(
        'Found dirty carb loading records to upload',
        context: 'CARB_LOADING_REPOSITORY',
        data: {'plans': dirtyPlans.length, 'days': dirtyDays.length},
      );

      // 3. Upload plans
      if (dirtyPlans.isNotEmpty) {
        final plansToUpload = dirtyPlans
            .map((plan) => CarbLoadingMapper.mapPlanToSupabaseJson(plan))
            .toList();
        await _supabase.from('carb_loading_plans').upsert(plansToUpload);
      }

      // 4. Upload days
      if (dirtyDays.isNotEmpty) {
        final daysToUpload = dirtyDays
            .map((day) => CarbLoadingMapper.mapDayToSupabaseJson(day))
            .toList();
        await _supabase.from('carb_loading_days').upsert(daysToUpload);
      }

      // 5. Clear dirty flags using batch operations
      await _database.batch((batch) {
        for (final plan in dirtyPlans) {
          batch.update(
            _database.carbLoadingPlansTable,
            const CarbLoadingPlansTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(plan.id),
          );
        }
        for (final day in dirtyDays) {
          batch.update(
            _database.carbLoadingDaysTable,
            const CarbLoadingDaysTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(day.id),
          );
        }
      });

      final totalCount = dirtyPlans.length + dirtyDays.length;

      _logger.info(
        'Successfully uploaded dirty carb loading records',
        context: 'CARB_LOADING_REPOSITORY',
        data: {
          'plans': dirtyPlans.length,
          'days': dirtyDays.length,
          'total': totalCount,
        },
      );

      return UploadResult.successful(totalCount);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty carb loading records',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return UploadResult.failed(e.toString());
    }
  }

  // ========================================================================
  // Existing Methods
  // ========================================================================

  /// Create a carb loading plan (offline-first: save to Drift first, background upload)
  Future<CarbLoadingPlan> createCarbLoadingPlan({
    required String deviceId,
    required String userId,
    String? eventId,
    required int protocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) async {
    try {
      // OFFLINE-FIRST: Calculate and save to Drift IMMEDIATELY
      final bodyWeightKg = bodyWeightPounds * 0.453592;
      final startDate = raceDate.subtract(Duration(days: protocolDays));
      final endDate = raceDate.subtract(const Duration(days: 1));

      // Calculate average daily carb target for the plan
      double totalCarbs = 0;
      for (int dayOffset = 0; dayOffset < protocolDays; dayOffset++) {
        final daysBeforeRace = protocolDays - dayOffset;
        final carbProtocol = _getCarbProtocolForDay(
          protocolDays: protocolDays,
          daysBeforeRace: daysBeforeRace,
        );
        totalCarbs += carbProtocol * bodyWeightKg;
      }
      final avgDailyCarbs = (totalCarbs / protocolDays).round();

      // Create the plan locally with dirty flag (UUID generated automatically)
      final planCompanion = CarbLoadingPlansTableCompanion.insert(
        eventId: eventId != null ? Value(eventId) : const Value.absent(),
        userId: userId,
        totalDays: protocolDays,
        startDate: startDate,
        endDate: endDate,
        dailyCarbTargetGrams: avgDailyCarbs,
        generatedAt: DateTime.now(),
        needsUpload: const Value(true),
        localUpdatedAt: Value(DateTime.now()),
      );

      final planId = await _database
          .into(_database.carbLoadingPlansTable)
          .insertReturning(planCompanion)
          .then((row) => row.id);

      // Generate carb loading day records locally with dirty flags
      for (int dayOffset = 0; dayOffset < protocolDays; dayOffset++) {
        final dayDate = startDate.add(Duration(days: dayOffset));
        final daysBeforeRace = protocolDays - dayOffset;

        final carbProtocolGPerKg = _getCarbProtocolForDay(
          protocolDays: protocolDays,
          daysBeforeRace: daysBeforeRace,
        );

        final targetCarbsGrams = carbProtocolGPerKg * bodyWeightKg;

        final carbDayCompanion = CarbLoadingDaysTableCompanion.insert(
          carbLoadingPlanId: planId,
          planDate: dayDate,
          dayNumber: dayOffset + 1,
          carbTargetGrams: targetCarbsGrams.round(),
          carbProtocolGPerKg: Value(carbProtocolGPerKg),
          needsUpload: const Value(true),
          localUpdatedAt: Value(DateTime.now()),
        );

        await _database
            .into(_database.carbLoadingDaysTable)
            .insert(carbDayCompanion);
      }

      // Get the created plan
      final createdPlan = await getCarbLoadingPlanById(planId);
      if (createdPlan == null) {
        throw Exception('Failed to retrieve created carb loading plan');
      }

      // Attempt background upload (non-blocking)
      unawaited(() async {
        try {
          await _uploadCarbLoadingPlanToSupabase(planId: planId);
        } catch (e, stackTrace) {
          _logger.warning(
            'Immediate upload failed; record stays dirty for retry',
            context: 'CARB_LOADING_REPOSITORY',
            error: e, stackTrace: stackTrace,
            data: {'operation': 'create', 'recordId': planId},
          );
          _sentry.reportNetworkError(e, url: 'supabase:carb_loading_plans:create', method: 'UPSERT', stackTrace: stackTrace);
        }
      }());

      return createdPlan;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create carb loading plan',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update a carb loading day (offline-first: save to Drift first, background upload)
  Future<CarbLoadingDay> updateCarbLoadingDay({
    required String deviceId,
    required String carbLoadingDayId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      // OFFLINE-FIRST: Update locally IMMEDIATELY with dirty flag
      final companion = CarbLoadingDaysTableCompanion(
        carbTargetGrams: updates.containsKey('carbTargetGrams')
            ? Value(updates['carbTargetGrams'] as int)
            : const Value.absent(),
        carbProtocolGPerKg: updates.containsKey('carbProtocolGPerKg')
            ? Value((updates['carbProtocolGPerKg'] as num).toDouble())
            : const Value.absent(),
        breakfastPercent: updates.containsKey('breakfastPercent')
            ? Value((updates['breakfastPercent'] as num).toDouble())
            : const Value.absent(),
        morningSnackPercent: updates.containsKey('morningSnackPercent')
            ? Value((updates['morningSnackPercent'] as num).toDouble())
            : const Value.absent(),
        lunchPercent: updates.containsKey('lunchPercent')
            ? Value((updates['lunchPercent'] as num).toDouble())
            : const Value.absent(),
        afternoonSnackPercent: updates.containsKey('afternoonSnackPercent')
            ? Value((updates['afternoonSnackPercent'] as num).toDouble())
            : const Value.absent(),
        dinnerPercent: updates.containsKey('dinnerPercent')
            ? Value((updates['dinnerPercent'] as num).toDouble())
            : const Value.absent(),
        eveningSnackPercent: updates.containsKey('eveningSnackPercent')
            ? Value((updates['eveningSnackPercent'] as num).toDouble())
            : const Value.absent(),
        completed: updates.containsKey('completed')
            ? Value(updates['completed'] as bool)
            : const Value.absent(),
        loggedCarbsGrams: updates.containsKey('loggedCarbsGrams')
            ? Value(updates['loggedCarbsGrams'] as int)
            : const Value.absent(),
        loggedCalories: updates.containsKey('loggedCalories')
            ? Value(updates['loggedCalories'] as int)
            : const Value.absent(),
        needsUpload: const Value(true),
        localUpdatedAt: Value(DateTime.now()),
      );

      await (_database.update(
        _database.carbLoadingDaysTable,
      )..where((tbl) => tbl.id.equals(carbLoadingDayId))).write(companion);

      final updatedDay = await getCarbLoadingDayById(carbLoadingDayId);
      if (updatedDay == null) {
        throw Exception('Failed to retrieve updated carb loading day');
      }

      // Attempt background upload (non-blocking)
      unawaited(() async {
        try {
          await _uploadCarbLoadingDayToSupabase(
            carbLoadingDayId: carbLoadingDayId,
          );
        } catch (e, stackTrace) {
          _logger.warning(
            'Immediate upload failed; record stays dirty for retry',
            context: 'CARB_LOADING_REPOSITORY',
            error: e, stackTrace: stackTrace,
            data: {'operation': 'update_day', 'recordId': carbLoadingDayId},
          );
          _sentry.reportNetworkError(e, url: 'supabase:carb_loading_days:update', method: 'UPSERT', stackTrace: stackTrace);
        }
      }());

      return updatedDay;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update carb loading day',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteCarbLoadingPlan({
    required String deviceId,
    required String planId,
  }) async {
    try {
      await _database.transaction(() async {
        final carbLoadingDays = await (_database.select(
          _database.carbLoadingDaysTable,
        )..where((tbl) => tbl.carbLoadingPlanId.equals(planId))).get();

        for (final day in carbLoadingDays) {
          await (_database.delete(
            _database.carbLoadingDayMealsTable,
          )..where((tbl) => tbl.carbLoadingDayId.equals(day.id))).go();
        }

        await (_database.delete(
          _database.carbLoadingDaysTable,
        )..where((tbl) => tbl.carbLoadingPlanId.equals(planId))).go();

        await (_database.delete(
          _database.carbLoadingPlansTable,
        )..where((tbl) => tbl.id.equals(planId))).go();
      });

      unawaited(() async {
        try {
          await _uploadCarbLoadingPlanDeletion(planId: planId);
        } catch (e, stackTrace) {
          _logger.warning(
            'Immediate upload failed; record stays dirty for retry',
            context: 'CARB_LOADING_REPOSITORY',
            error: e, stackTrace: stackTrace,
            data: {'operation': 'delete', 'recordId': planId},
          );
          _sentry.reportNetworkError(e, url: 'supabase:carb_loading_plans:delete', method: 'DELETE', stackTrace: stackTrace);
        }
      }());
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete carb loading plan',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete carb loading plan by event ID (cascade delete for event deletion)
  /// This handles the cascade since Drift doesn't enforce FK constraints like PostgreSQL
  Future<void> deleteCarbLoadingPlanByEventId({
    required String deviceId,
    required String eventId,
  }) async {
    try {
      // Find the plan for this event
      final plan = await getCarbLoadingPlanForEvent(eventId);
      if (plan == null) {
        _logger.debug(
          'No carb loading plan found for event $eventId - nothing to delete',
          context: 'CARB_LOADING_REPOSITORY',
        );
        return;
      }

      // Use the existing delete method which handles full cascade
      await deleteCarbLoadingPlan(deviceId: deviceId, planId: plan.id);

      _logger.info(
        'Cascade deleted carb loading plan ${plan.id} for event $eventId',
        context: 'CARB_LOADING_REPOSITORY',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to cascade delete carb loading plan for event $eventId',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - event deletion should still proceed
      // The Supabase CASCADE will clean up the server side
    }
  }

  /// Get carb loading plan by ID
  Future<CarbLoadingPlan?> getCarbLoadingPlanById(String planId) async {
    try {
      final query = _database.select(_database.carbLoadingPlansTable)
        ..where((tbl) => tbl.id.equals(planId));

      return await query.getSingleOrNull();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get carb loading plan by ID',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get carb loading plan for an event
  Future<CarbLoadingPlan?> getCarbLoadingPlanForEvent(String eventId) async {
    try {
      final query = _database.select(_database.carbLoadingPlansTable)
        ..where((tbl) => tbl.eventId.equals(eventId));

      return await query.getSingleOrNull();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get carb loading plan for event',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get carb loading days for a plan
  Future<List<CarbLoadingDay>> getCarbLoadingDaysForPlan(String planId) async {
    try {
      final query = _database.select(_database.carbLoadingDaysTable)
        ..where((tbl) => tbl.carbLoadingPlanId.equals(planId))
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.dayNumber)]);

      return await query.get();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get carb loading days for plan',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get carb loading day by ID
  Future<CarbLoadingDay?> getCarbLoadingDayById(String dayId) async {
    try {
      final query = _database.select(_database.carbLoadingDaysTable)
        ..where((tbl) => tbl.id.equals(dayId));

      return await query.getSingleOrNull();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get carb loading day by ID',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get carb loading days for a date range, scoped to a specific user
  ///
  /// IMPORTANT: This method joins through carb_loading_plans to ensure
  /// only days belonging to the specified user are returned.
  Future<List<CarbLoadingDay>> getCarbLoadingDaysForDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Join carb_loading_days with carb_loading_plans to filter by user_id
      final query =
          _database.select(_database.carbLoadingDaysTable).join([
              innerJoin(
                _database.carbLoadingPlansTable,
                _database.carbLoadingPlansTable.id.equalsExp(
                  _database.carbLoadingDaysTable.carbLoadingPlanId,
                ),
              ),
            ])
            ..where(
              _database.carbLoadingPlansTable.userId.equals(userId) &
                  _database.carbLoadingDaysTable.planDate.isBiggerOrEqualValue(
                    startDate,
                  ) &
                  _database.carbLoadingDaysTable.planDate.isSmallerOrEqualValue(
                    endDate,
                  ),
            )
            ..orderBy([
              OrderingTerm.asc(_database.carbLoadingDaysTable.planDate),
            ]);

      final results = await query.get();
      return results
          .map((row) => row.readTable(_database.carbLoadingDaysTable))
          .toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get carb loading days for date range',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      rethrow;
    }
  }

  /// Get the carb protocol (g/kg) for a specific day
  double _getCarbProtocolForDay({
    required int protocolDays,
    required int daysBeforeRace,
  }) {
    if (protocolDays == 2) {
      // 2-day protocol
      if (daysBeforeRace == 2) {
        return 9.0; // Day -2: 9g/kg
      } else {
        return 11.0; // Day -1: 11g/kg
      }
    } else if (protocolDays == 3) {
      // 3-day protocol
      if (daysBeforeRace == 3 || daysBeforeRace == 2) {
        return 8.0; // Day -3 and -2: 8g/kg
      } else {
        return 10.0; // Day -1: 10g/kg
      }
    }

    // Default fallback
    return 8.0;
  }

  Future<void> _uploadCarbLoadingPlanToSupabase({
    required String planId,
  }) async {
    // Get the plan from Drift
    final plan = await getCarbLoadingPlanById(planId);
    if (plan == null) {
      throw Exception('Plan not found: $planId');
    }

    final planPayload = {
      'id': plan.id, // UUID is stable - no rekeying needed
      'event_id': plan.eventId,
      'user_id': plan.userId,
      'total_days': plan.totalDays,
      'start_date': plan.startDate.toIso8601String().split('T')[0],
      'end_date': plan.endDate.toIso8601String().split('T')[0],
      'daily_carb_target_grams': plan.dailyCarbTargetGrams,
      'generated_at': plan.generatedAt.toIso8601String(),
      'algorithm_version': plan.algorithmVersion,
      'adherence_score': plan.adherenceScore,
      'completed_at': plan.completedAt?.toIso8601String(),
      'local_updated_at': DateTime.now().toIso8601String(),
    };

    // Simple upsert - UUID is stable so no rekeying needed
    await _supabase.from('carb_loading_plans').upsert(planPayload);

    // Get all days for this plan
    final days =
        await (_database.select(_database.carbLoadingDaysTable)
              ..where((tbl) => tbl.carbLoadingPlanId.equals(plan.id))
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.dayNumber)]))
            .get();

    // Upsert all days
    for (final day in days) {
      final dayPayload = {
        'id': day.id, // UUID is stable - no rekeying needed
        'carb_loading_plan_id': day.carbLoadingPlanId,
        'plan_date': day.planDate.toIso8601String().split('T')[0],
        'day_number': day.dayNumber,
        'carb_target_grams': day.carbTargetGrams,
        'carb_protocol_g_per_kg': day.carbProtocolGPerKg,
        'meal_count': day.mealCount,
        'breakfast_percent': day.breakfastPercent,
        'morning_snack_percent': day.morningSnackPercent,
        'lunch_percent': day.lunchPercent,
        'afternoon_snack_percent': day.afternoonSnackPercent,
        'dinner_percent': day.dinnerPercent,
        'evening_snack_percent': day.eveningSnackPercent,
        'logged_carbs_grams': day.loggedCarbsGrams,
        'logged_calories': day.loggedCalories,
        'completed': day.completed,
        'local_updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('carb_loading_days').upsert(dayPayload);
    }

    // Clear dirty flags
    await _clearPlanDirtyFlag(plan.id);
    for (final day in days) {
      await _clearDayDirtyFlag(day.id);
    }
  }

  Future<void> _uploadCarbLoadingDayToSupabase({
    required String carbLoadingDayId,
  }) async {
    // Get the day from Drift to get complete data
    final day = await getCarbLoadingDayById(carbLoadingDayId);
    if (day == null) {
      throw Exception('Carb loading day not found: $carbLoadingDayId');
    }

    final payload = {
      'id': day.id, // UUID is stable - no rekeying needed
      'carb_loading_plan_id': day.carbLoadingPlanId,
      'plan_date': day.planDate.toIso8601String().split('T')[0],
      'day_number': day.dayNumber,
      'carb_target_grams': day.carbTargetGrams,
      'carb_protocol_g_per_kg': day.carbProtocolGPerKg,
      'meal_count': day.mealCount,
      'breakfast_percent': day.breakfastPercent,
      'morning_snack_percent': day.morningSnackPercent,
      'lunch_percent': day.lunchPercent,
      'afternoon_snack_percent': day.afternoonSnackPercent,
      'dinner_percent': day.dinnerPercent,
      'evening_snack_percent': day.eveningSnackPercent,
      'logged_carbs_grams': day.loggedCarbsGrams,
      'logged_calories': day.loggedCalories,
      'completed': day.completed,
      'local_updated_at': DateTime.now().toIso8601String(),
    };

    // Simple upsert - UUID is stable so no rekeying needed
    await _supabase.from('carb_loading_days').upsert(payload);

    // Clear dirty flag
    await _clearDayDirtyFlag(day.id);
  }

  Future<void> _uploadCarbLoadingPlanDeletion({required String planId}) async {
    // Delete days first (cascade handled by database, but doing explicitly for clarity)
    await _supabase
        .from('carb_loading_days')
        .delete()
        .eq('carb_loading_plan_id', planId);

    // Delete the plan
    await _supabase.from('carb_loading_plans').delete().eq('id', planId);
  }

  Future<void> _clearPlanDirtyFlag(String planId) async {
    try {
      await (_database.update(
        _database.carbLoadingPlansTable,
      )..where((tbl) => tbl.id.equals(planId))).write(
        const CarbLoadingPlansTableCompanion(needsUpload: Value(false)),
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to clear plan dirty flag',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _clearDayDirtyFlag(String dayId) async {
    try {
      await (_database.update(
        _database.carbLoadingDaysTable,
      )..where((tbl) => tbl.id.equals(dayId))).write(
        const CarbLoadingDaysTableCompanion(needsUpload: Value(false)),
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to clear day dirty flag',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

}

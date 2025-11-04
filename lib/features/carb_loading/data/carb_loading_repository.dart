import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';

part 'carb_loading_repository.g.dart';

@riverpod
CarbLoadingRepository carbLoadingRepository(Ref ref) {
  return CarbLoadingRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Repository for managing carb loading plans and days following FOA pattern
/// Prepares for server-authoritative sync with edge functions
class CarbLoadingRepository {
  const CarbLoadingRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

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
      // Generate plan ID upfront
      final planId = _generateId();

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

      // Create the plan locally with dirty flag
      final planCompanion = CarbLoadingPlansTableCompanion.insert(
        id: planId,
        eventId: eventId != null && eventId.isNotEmpty
            ? Value(eventId)
            : const Value.absent(),
        userId: userId,
        totalDays: protocolDays,
        startDate: startDate,
        endDate: endDate,
        dailyCarbTargetGrams: avgDailyCarbs,
        generatedAt: DateTime.now(),
        needsUpload: const Value(true),
        localUpdatedAt: Value(DateTime.now()),
      );

      await _database.into(_database.carbLoadingPlansTable).insert(planCompanion);

      // Generate carb loading day records locally with dirty flags
      for (int dayOffset = 0; dayOffset < protocolDays; dayOffset++) {
        final dayDate = startDate.add(Duration(days: dayOffset));
        final daysBeforeRace = protocolDays - dayOffset;

        final carbProtocolGPerKg = _getCarbProtocolForDay(
          protocolDays: protocolDays,
          daysBeforeRace: daysBeforeRace,
        );

        final targetCarbsGrams = carbProtocolGPerKg * bodyWeightKg;

        final carbDayId = _generateId();
        final carbDayCompanion = CarbLoadingDaysTableCompanion.insert(
          id: carbDayId,
          carbLoadingPlanId: planId,
          planDate: dayDate,
          dayNumber: dayOffset + 1,
          carbTargetGrams: targetCarbsGrams.round(),
          carbProtocolGPerKg: carbProtocolGPerKg,
          needsUpload: const Value(true),
          localUpdatedAt: Value(DateTime.now()),
        );

        await _database.into(_database.carbLoadingDaysTable).insert(carbDayCompanion);
      }

      // Get the created plan
      final createdPlan = await getCarbLoadingPlanById(planId);
      if (createdPlan == null) {
        throw Exception('Failed to retrieve created carb loading plan');
      }

      // Attempt background upload (non-blocking)
      unawaited(_uploadCarbLoadingPlanToSupabase(
        deviceId: deviceId,
        planId: planId,
        eventId: eventId,
        protocolDays: protocolDays,
        raceDate: raceDate,
        bodyWeightPounds: bodyWeightPounds,
      ));

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
        breakfastPercent: updates.containsKey('breakfastPercent')
            ? Value(updates['breakfastPercent'] as double)
            : const Value.absent(),
        morningSnackPercent: updates.containsKey('morningSnackPercent')
            ? Value(updates['morningSnackPercent'] as double)
            : const Value.absent(),
        lunchPercent: updates.containsKey('lunchPercent')
            ? Value(updates['lunchPercent'] as double)
            : const Value.absent(),
        afternoonSnackPercent: updates.containsKey('afternoonSnackPercent')
            ? Value(updates['afternoonSnackPercent'] as double)
            : const Value.absent(),
        dinnerPercent: updates.containsKey('dinnerPercent')
            ? Value(updates['dinnerPercent'] as double)
            : const Value.absent(),
        eveningSnackPercent: updates.containsKey('eveningSnackPercent')
            ? Value(updates['eveningSnackPercent'] as double)
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

      await (_database.update(_database.carbLoadingDaysTable)
            ..where((tbl) => tbl.id.equals(carbLoadingDayId)))
          .write(companion);

      final updatedDay = await getCarbLoadingDayById(carbLoadingDayId);
      if (updatedDay == null) {
        throw Exception('Failed to retrieve updated carb loading day');
      }

      // Attempt background upload (non-blocking)
      unawaited(_uploadCarbLoadingDayToSupabase(
        deviceId: deviceId,
        carbLoadingDayId: carbLoadingDayId,
        updates: updates,
      ));

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
        final carbLoadingDays = await (_database.select(_database.carbLoadingDaysTable)
              ..where((tbl) => tbl.carbLoadingPlanId.equals(planId)))
            .get();

        for (final day in carbLoadingDays) {
          await (_database.delete(_database.carbLoadingDayMealsTable)
                ..where((tbl) => tbl.carbLoadingDayId.equals(day.id)))
              .go();
        }

        await (_database.delete(_database.carbLoadingDaysTable)
              ..where((tbl) => tbl.carbLoadingPlanId.equals(planId)))
            .go();

        await (_database.delete(_database.carbLoadingPlansTable)
              ..where((tbl) => tbl.id.equals(planId)))
            .go();
      });

      unawaited(_uploadCarbLoadingPlanDeletion(deviceId: deviceId, planId: planId));
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

  /// Get carb loading days for a date range
  Future<List<CarbLoadingDay>> getCarbLoadingDaysForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final query = _database.select(_database.carbLoadingDaysTable)
        ..where((tbl) =>
            tbl.planDate.isBiggerOrEqualValue(startDate) &
            tbl.planDate.isSmallerOrEqualValue(endDate))
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.planDate)]);

      return await query.get();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get carb loading days for date range',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
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

  /// Generate a UUID
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond % 1000}';
  }

  Future<void> _uploadCarbLoadingPlanToSupabase({
    required String deviceId,
    required String planId,
    String? eventId,
    required int protocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'save-carb-loading-plan',
        body: {
          'device_id': deviceId,
          'operation': 'create',
          'plan': {
            'id': planId,
            'eventId': eventId,
            'protocolDays': protocolDays,
            'raceDate': raceDate.toIso8601String(),
            'bodyWeightPounds': bodyWeightPounds,
          },
        },
      );

      if (response.status >= 200 && response.status < 300) {
        await _clearPlanDirtyFlag(planId);
      } else {
        _logger.warning(
          'Failed to upload carb loading plan, will retry on next sync',
          context: 'CARB_LOADING_REPOSITORY',
          data: {'planId': planId, 'status': response.status},
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error uploading carb loading plan, will retry on next sync',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _uploadCarbLoadingDayToSupabase({
    required String deviceId,
    required String carbLoadingDayId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'save-carb-loading-plan',
        body: {
          'device_id': deviceId,
          'operation': 'update_day',
          'carb_loading_day_id': carbLoadingDayId,
          'updates': updates,
        },
      );

      if (response.status >= 200 && response.status < 300) {
        await _clearDayDirtyFlag(carbLoadingDayId);
      } else {
        _logger.warning(
          'Failed to upload carb loading day, will retry on next sync',
          context: 'CARB_LOADING_REPOSITORY',
          data: {'dayId': carbLoadingDayId, 'status': response.status},
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error uploading carb loading day, will retry on next sync',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _uploadCarbLoadingPlanDeletion({
    required String deviceId,
    required String planId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'save-carb-loading-plan',
        body: {
          'device_id': deviceId,
          'operation': 'delete',
          'plan_id': planId,
        },
      );

      if (response.status < 200 || response.status >= 300) {
        _logger.warning(
          'Failed to upload carb loading plan deletion',
          context: 'CARB_LOADING_REPOSITORY',
          data: {'planId': planId, 'status': response.status},
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error uploading carb loading plan deletion',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _clearPlanDirtyFlag(String planId) async {
    try {
      await (_database.update(_database.carbLoadingPlansTable)
            ..where((tbl) => tbl.id.equals(planId)))
          .write(const CarbLoadingPlansTableCompanion(
        needsUpload: Value(false),
      ));
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
      await (_database.update(_database.carbLoadingDaysTable)
            ..where((tbl) => tbl.id.equals(dayId)))
          .write(const CarbLoadingDaysTableCompanion(
        needsUpload: Value(false),
      ));
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

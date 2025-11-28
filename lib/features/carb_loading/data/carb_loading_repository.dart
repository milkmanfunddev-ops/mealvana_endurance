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
    int? eventId,
    required int protocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) async {
    try {
      // Auto-increment will generate plan ID
      late int planId;

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

      planId = await _database.into(_database.carbLoadingPlansTable).insert(planCompanion);

      // Generate carb loading day records locally with dirty flags
      for (int dayOffset = 0; dayOffset < protocolDays; dayOffset++) {
        final dayDate = startDate.add(Duration(days: dayOffset));
        final daysBeforeRace = protocolDays - dayOffset;

        final carbProtocolGPerKg = _getCarbProtocolForDay(
          protocolDays: protocolDays,
          daysBeforeRace: daysBeforeRace,
        );

        final targetCarbsGrams = carbProtocolGPerKg * bodyWeightKg;

        // Auto-increment will generate day ID
        final carbDayCompanion = CarbLoadingDaysTableCompanion.insert(
          carbLoadingPlanId: planId,
          planDate: dayDate,
          dayNumber: dayOffset + 1,
          carbTargetGrams: targetCarbsGrams.round(),
          carbProtocolGPerKg: Value(carbProtocolGPerKg),
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
    required int carbLoadingDayId,
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
    required int planId,
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
  Future<CarbLoadingPlan?> getCarbLoadingPlanById(int planId) async {
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
  Future<CarbLoadingPlan?> getCarbLoadingPlanForEvent(int eventId) async {
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
  Future<List<CarbLoadingDay>> getCarbLoadingDaysForPlan(int planId) async {
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
  Future<CarbLoadingDay?> getCarbLoadingDayById(int dayId) async {
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

  Future<void> _uploadCarbLoadingPlanToSupabase({
    required String deviceId,
    required int planId,
    int? eventId,
    required int protocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) async {
    try {
      // Get the plan from Drift
      final plan = await getCarbLoadingPlanById(planId);
      if (plan == null) {
        throw Exception('Plan not found: $planId');
      }

      // DIRECT FIX: Use userId from plan directly (unified with deviceId)
      // Skip unnecessary and fragile user lookup
      final userId = plan.userId;

      final planPayload = {
        'event_id': plan.eventId,
        'user_id': userId,
        'total_days': plan.totalDays,
        'start_date': plan.startDate.toIso8601String().split('T')[0],
        'end_date': plan.endDate.toIso8601String().split('T')[0],
        'daily_carb_target_grams': plan.dailyCarbTargetGrams,
        'generated_at': plan.generatedAt.toIso8601String(),
        'algorithm_version': plan.algorithmVersion,
        'adherence_score': plan.adherenceScore,
        'completed_at': plan.completedAt?.toIso8601String(),
        'local_updated_at': DateTime.now().toIso8601String(),
        // 'needs_upload': false, // Local-only field
        // 'local_updated_at': DateTime.now().toIso8601String(), // Local-only field
      };

      Map<String, dynamic>? updateResponse;
      try {
        updateResponse = await _supabase
            .from('carb_loading_plans')
            .update(planPayload)
            .eq('id', plan.id)
            .eq('user_id', userId)
            .select('id')
            .maybeSingle();
      } catch (e) {
        _logger.debug(
          'Plan update failed, will insert a new server ID',
          context: 'CARB_LOADING_REPOSITORY',
          data: {'planId': plan.id, 'error': e.toString()},
        );
      }

      int serverPlanId;
      if (updateResponse != null && updateResponse['id'] != null) {
        serverPlanId = updateResponse['id'] as int;
      } else {
        // If update returned no rows, check for an existing plan by event/user to avoid duplicate key collisions
        Map<String, dynamic>? existingPlan;
        if (plan.eventId != null) {
          existingPlan = await _supabase
              .from('carb_loading_plans')
              .select('id')
              .eq('user_id', userId)
              .eq('event_id', plan.eventId!)
              .maybeSingle();
        }

        if (existingPlan != null && existingPlan['id'] != null) {
          serverPlanId = existingPlan['id'] as int;
        } else {
          final insertResponse = await _supabase
              .from('carb_loading_plans')
              .insert(planPayload)
              .select('id')
              .single();
          serverPlanId = insertResponse['id'] as int;
        }
      }

      if (serverPlanId != plan.id) {
        await _rekeyPlanLocally(plan.id, serverPlanId);
      }

      // Insert all days directly to Supabase (using upsert for idempotency)
      final updatedDays = await (_database.select(_database.carbLoadingDaysTable)
            ..where((tbl) => tbl.carbLoadingPlanId.equals(serverPlanId))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.dayNumber)]))
          .get();

      for (final day in updatedDays) {
        final dayPayload = {
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
          // 'needs_upload': false, // Local-only field
          // 'local_updated_at': DateTime.now().toIso8601String(), // Local-only field
        };

        Map<String, dynamic>? dayUpdate;
        try {
          dayUpdate = await _supabase
              .from('carb_loading_days')
              .update(dayPayload)
              .eq('id', day.id)
              .eq('carb_loading_plan_id', serverPlanId)
              .select('id')
              .maybeSingle();
        } catch (e) {
          _logger.debug(
            'Day update failed, inserting with server ID',
            context: 'CARB_LOADING_REPOSITORY',
            data: {'dayId': day.id, 'error': e.toString()},
          );
        }

        int serverDayId;
        if (dayUpdate != null && dayUpdate['id'] != null) {
          serverDayId = dayUpdate['id'] as int;
        } else {
          final insertDayResponse = await _supabase
              .from('carb_loading_days')
              .insert(dayPayload)
              .select('id')
              .single();
          serverDayId = insertDayResponse['id'] as int;
        }

        if (serverDayId != day.id) {
          await _rekeyDayLocally(day.id, serverDayId);
        }
      }

      // Clear dirty flags
      await _clearPlanDirtyFlag(serverPlanId);
      for (final day in updatedDays) {
        await _clearDayDirtyFlag(day.id);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error uploading carb loading plan, will retry on next sync',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - will retry on next sync
    }
  }

  Future<void> _uploadCarbLoadingDayToSupabase({
    required String deviceId,
    required int carbLoadingDayId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      // Get the day from Drift to get complete data
      final day = await getCarbLoadingDayById(carbLoadingDayId);
      if (day == null) {
        throw Exception('Carb loading day not found: $carbLoadingDayId');
      }

      final payload = {
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
        // 'needs_upload': false, // Local-only field
        // 'local_updated_at': DateTime.now().toIso8601String(), // Local-only field
      };

      Map<String, dynamic>? updateResponse;
      try {
        updateResponse = await _supabase
            .from('carb_loading_days')
            .update(payload)
            .eq('id', day.id)
            .eq('carb_loading_plan_id', day.carbLoadingPlanId)
            .select('id')
            .maybeSingle();
      } catch (e) {
        _logger.debug(
          'Day update failed, will insert new server ID',
          context: 'CARB_LOADING_REPOSITORY',
          data: {'dayId': day.id, 'error': e.toString()},
        );
      }

      int serverDayId;
      if (updateResponse != null && updateResponse['id'] != null) {
        serverDayId = updateResponse['id'] as int;
      } else {
        final insertResponse = await _supabase
            .from('carb_loading_days')
            .insert(payload)
            .select('id')
            .single();
        serverDayId = insertResponse['id'] as int;
      }

      if (serverDayId != day.id) {
        await _rekeyDayLocally(day.id, serverDayId);
      }

      // Clear dirty flag
      await _clearDayDirtyFlag(serverDayId);
    } catch (e, stackTrace) {
      _logger.error(
        'Error uploading carb loading day, will retry on next sync',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - will retry on next sync
    }
  }

  Future<void> _uploadCarbLoadingPlanDeletion({
    required String deviceId,
    required int planId,
  }) async {
    try {
      // Delete days first (cascade handled by database, but doing explicitly for clarity)
      await _supabase
          .from('carb_loading_days')
          .delete()
          .eq('carb_loading_plan_id', planId);

      // Delete the plan
      await _supabase
          .from('carb_loading_plans')
          .delete()
          .eq('id', planId);
    } catch (e, stackTrace) {
      _logger.error(
        'Error uploading carb loading plan deletion',
        context: 'CARB_LOADING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - deletion already succeeded locally
    }
  }

  Future<void> _rekeyPlanLocally(int oldId, int newId) async {
    await _database.transaction(() async {
      // Update child tables first
      await _database.customStatement(
        'UPDATE carb_loading_days SET carb_loading_plan_id = ? WHERE carb_loading_plan_id = ?',
        [newId, oldId],
      );
      await _database.customStatement(
        'UPDATE carb_loading_plans SET id = ? WHERE id = ?',
        [newId, oldId],
      );
    });

    _logger.info(
      'Rekeyed carb loading plan ID to match Supabase',
      context: 'CARB_LOADING_REPOSITORY',
      data: {'oldId': oldId, 'newId': newId},
    );
  }

  Future<void> _rekeyDayLocally(int oldId, int newId) async {
    await _database.transaction(() async {
      await _database.customStatement(
        'UPDATE carb_loading_day_meals SET carb_loading_day_id = ? WHERE carb_loading_day_id = ?',
        [newId, oldId],
      );
      await _database.customStatement(
        'UPDATE carb_loading_days SET id = ? WHERE id = ?',
        [newId, oldId],
      );
    });

    _logger.info(
      'Rekeyed carb loading day ID to match Supabase',
      context: 'CARB_LOADING_REPOSITORY',
      data: {'oldId': oldId, 'newId': newId},
    );
  }

  Future<void> _clearPlanDirtyFlag(int planId) async {
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

  Future<void> _clearDayDirtyFlag(int dayId) async {
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

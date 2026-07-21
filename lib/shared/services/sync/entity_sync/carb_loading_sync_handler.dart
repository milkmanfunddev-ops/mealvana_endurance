import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../database/app_database.dart';
import '../../../database/database_provider.dart';
import '../../../utils/sync_type_converters.dart';
import '../../logging_service.dart';

part 'carb_loading_sync_handler.g.dart';

@Riverpod(keepAlive: true)
CarbLoadingSyncHandler carbLoadingSyncHandler(Ref ref) {
  return CarbLoadingSyncHandler(
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Handles sync operations for CarbLoadingPlan and CarbLoadingDay entities.
class CarbLoadingSyncHandler {
  const CarbLoadingSyncHandler({
    required AppDatabase database,
    required AppLogger logger,
  }) : _database = database,
       _logger = logger;

  final AppDatabase _database;
  final AppLogger _logger;

  /// Upsert a carb loading plan from remote data.
  Future<void> upsertCarbLoadingPlan(Map<String, dynamic> data) async {
    try {
      final planId = SyncTypeConverters.toRequiredStringId(
        data['id'],
        'carb_loading_plan.id',
      );
      final existingPlan = await (_database.select(
        _database.carbLoadingPlansTable,
      )..where((tbl) => tbl.id.equals(planId))).getSingleOrNull();

      final remoteUpdatedAt = (data['local_updated_at'] as String?) != null
          ? DateTime.parse(data['local_updated_at'] as String)
          : null;

      // Only upsert if we don't have it locally or the server copy is newer
      final shouldUpsert =
          existingPlan == null ||
          (remoteUpdatedAt != null &&
              remoteUpdatedAt.isAfter(existingPlan.localUpdatedAt));

      if (shouldUpsert) {
        final companion = CarbLoadingPlansTableCompanion.insert(
          id: Value(planId),
          eventId: Value(SyncTypeConverters.toStringId(data['event_id'])),
          userId: SyncTypeConverters.toRequiredStringId(
            data['user_id'],
            'carb_loading_plan.user_id',
          ),
          totalDays: data['total_days'] as int,
          startDate: DateTime.parse(data['start_date'] as String),
          endDate: DateTime.parse(data['end_date'] as String),
          dailyCarbTargetGrams: data['daily_carb_target_grams'] as int,
          dailyCalorieTarget: Value(data['daily_calorie_target'] as int?),
          generatedAt: DateTime.parse(data['generated_at'] as String),
          algorithmVersion: Value(
            data['algorithm_version'] as String? ?? 'v1.0',
          ),
          adherenceScore: Value((data['adherence_score'] as num?)?.toDouble()),
          completedAt: Value(
            data['completed_at'] != null
                ? DateTime.parse(data['completed_at'] as String)
                : null,
          ),
          needsUpload: const Value(false),
          localUpdatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
        );

        await _database
            .into(_database.carbLoadingPlansTable)
            .insert(companion, mode: InsertMode.insertOrReplace);

        // CRITICAL FIX: Update the linked event's has_carb_loading flag
        // This ensures event.hasCarbLoading is true even if it wasn't synced correctly from server
        final eventId = SyncTypeConverters.toStringId(data['event_id']);
        if (eventId != null) {
          final totalDays = data['total_days'] as int;
          final startDate = DateTime.parse(data['start_date'] as String);

          await (_database.update(
            _database.eventsTable,
          )..where((tbl) => tbl.id.equals(eventId))).write(
            EventsTableCompanion(
              hasCarbLoading: const Value(true),
              carbLoadingDays: Value(totalDays),
              carbLoadingStartDate: Value(startDate),
              // Don't mark as needsUpload since we're syncing FROM server
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upsert carb loading plan',
        context: 'CARB_LOADING_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'planId': data['id']},
      );
    }
  }

  /// Upsert a carb loading day from remote data.
  Future<void> upsertCarbLoadingDay(Map<String, dynamic> data) async {
    try {
      final dayId = SyncTypeConverters.toRequiredStringId(
        data['id'],
        'carb_loading_day.id',
      );
      final existingDay = await (_database.select(
        _database.carbLoadingDaysTable,
      )..where((tbl) => tbl.id.equals(dayId))).getSingleOrNull();

      final remoteUpdatedAt = (data['local_updated_at'] as String?) != null
          ? DateTime.parse(data['local_updated_at'] as String)
          : null;

      final shouldUpsert =
          existingDay == null ||
          (remoteUpdatedAt != null &&
              remoteUpdatedAt.isAfter(existingDay.localUpdatedAt));

      if (shouldUpsert) {
        final companion = CarbLoadingDaysTableCompanion.insert(
          id: Value(dayId),
          carbLoadingPlanId: SyncTypeConverters.toRequiredStringId(
            data['carb_loading_plan_id'],
            'carb_loading_day.carb_loading_plan_id',
          ),
          planDate: DateTime.parse(data['plan_date'] as String),
          dayNumber: data['day_number'] as int,
          carbTargetGrams: data['carb_target_grams'] as int,
          carbProtocolGPerKg: Value(
            (data['carb_protocol_g_per_kg'] as num?)?.toDouble() ?? 8.0,
          ),
          calorieTarget: Value(data['calorie_target'] as int?),
          mealCount: Value(data['meal_count'] as int? ?? 6),
          breakfastPercent: Value(
            (data['breakfast_percent'] as num?)?.toDouble() ?? 0.25,
          ),
          morningSnackPercent: Value(
            (data['morning_snack_percent'] as num?)?.toDouble() ?? 0.10,
          ),
          lunchPercent: Value(
            (data['lunch_percent'] as num?)?.toDouble() ?? 0.25,
          ),
          afternoonSnackPercent: Value(
            (data['afternoon_snack_percent'] as num?)?.toDouble() ?? 0.15,
          ),
          dinnerPercent: Value(
            (data['dinner_percent'] as num?)?.toDouble() ?? 0.20,
          ),
          eveningSnackPercent: Value(
            (data['evening_snack_percent'] as num?)?.toDouble() ?? 0.05,
          ),
          loggedCarbsGrams: Value(data['logged_carbs_grams'] as int? ?? 0),
          loggedCalories: Value(data['logged_calories'] as int? ?? 0),
          completed: Value(data['completed'] as bool? ?? false),
          needsUpload: const Value(false),
          localUpdatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
        );

        await _database
            .into(_database.carbLoadingDaysTable)
            .insert(companion, mode: InsertMode.insertOrReplace);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upsert carb loading day',
        context: 'CARB_LOADING_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'dayId': data['id']},
      );
    }
  }

  /// Sync multiple athlete carb loading plans (for coach view).
  Future<void> syncAthleteCarbLoadingPlans(List<dynamic> plans) async {
    try {
      for (final planData in plans) {
        final planMap = planData as Map<String, dynamic>;
        await upsertCarbLoadingPlan(planMap);
      }

      _logger.info(
        'Synced ${plans.length} athlete carb loading plans',
        context: 'CARB_LOADING_SYNC',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync athlete carb loading plans',
        context: 'CARB_LOADING_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - continue with other syncs
    }
  }

  /// Convert CarbLoadingPlan entity to JSON for edge function upload.
  Map<String, dynamic> carbLoadingPlanToJson(CarbLoadingPlan plan) {
    return {
      'id': plan.id,
      'user_id': plan.userId,
      'event_id': plan.eventId,
      'start_date': plan.startDate.toIso8601String(),
      'end_date': plan.endDate.toIso8601String(),
      'total_days': plan.totalDays,
      'daily_carb_target_grams': plan.dailyCarbTargetGrams,
      'daily_calorie_target': plan.dailyCalorieTarget,
      'generated_at': plan.generatedAt.toIso8601String(),
      'algorithm_version': plan.algorithmVersion,
      'adherence_score': plan.adherenceScore,
      'completed_at': plan.completedAt?.toIso8601String(),
      'local_updated_at': plan.localUpdatedAt.toIso8601String(),
    };
  }

  /// Convert CarbLoadingDay entity to JSON for edge function upload.
  Map<String, dynamic> carbLoadingDayToJson(CarbLoadingDay day) {
    return {
      'id': day.id,
      'carb_loading_plan_id': day.carbLoadingPlanId,
      'day_number': day.dayNumber,
      'plan_date': day.planDate.toIso8601String(),
      'carb_target_grams': day.carbTargetGrams,
      'carb_protocol_g_per_kg': day.carbProtocolGPerKg,
      'calorie_target': day.calorieTarget,
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
      'local_updated_at': day.localUpdatedAt.toIso8601String(),
    };
  }
}

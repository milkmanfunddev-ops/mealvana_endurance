import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/report/report.dart';
import '../../activities/data/activities_repository.dart';
import '../../calendar/application/calendar_service.dart';
import '../application/food_data_transformation_service.dart';
import '../domain/nutrition_plan.dart' as domain;
import 'nutrition_plan_mapper.dart';

part 'nutrition_plan_repository.g.dart';

/// Repository for nutrition plan operations using Supabase Edge Functions
/// Includes local caching with Drift database to replace nutrition_plan_local_cache
class NutritionPlanRepository {
  NutritionPlanRepository({
    required this.supabase,
    required this.database,
    required this.report,
    required this.transformationService,
    required this.calendarService,
    required this.activitiesRepository,
  });

  static const String _area = 'nutrition_plan';

  final SupabaseClient supabase;
  final AppDatabase database;
  final Report report;
  final CalendarService calendarService;
  final FoodDataTransformationService transformationService;
  final ActivitiesRepository activitiesRepository;

  Future<Activity?> _getActivityRowWithPlan(String activityId) async {
    final activity = await database.activityDao.getActivityByIdLocal(
      activityId,
    );
    if (activity == null || activity.nutritionPlanData == null) {
      return null;
    }
    return activity;
  }

  Map<String, dynamic> _decodePlanJson(String rawPlanData) {
    try {
      final decoded = jsonDecode(rawPlanData);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e, stackTrace) {
      // The caller gets an empty map and the mapper fails from there; this
      // is the one place that knows the stored plan itself was unreadable.
      report.degraded(
        e,
        stackTrace: stackTrace,
        area: _area,
        message: 'Stored nutrition plan JSON unreadable; treated as empty',
      );
    }
    return {};
  }

  /// Cache nutrition plan locally in Drift database
  Future<void> cachePlanLocally(
    String userId,
    domain.NutritionPlan plan,
  ) async {
    try {
      final activityId = plan.activityId;
      if (activityId == null) {
        await report.note(
          'Plan not cached locally: no activityId',
          area: _area,
          data: {'planId': plan.id},
        );
        return;
      }

      DebugLogger.info(
        '💾 Caching plan locally: planId=${plan.id}, userId=$userId, activityId=$activityId',
      );

      final planJson = json.encode(plan.toJson());
      await database.activityDao.setActivityNutritionPlan(
        activityId: activityId,
        planData: planJson,
      );
      DebugLogger.info('✅ Plan cached on activity row');
    } catch (e, stackTrace) {
      await report.fault(
        e,
        stackTrace: stackTrace,
        area: _area,
        message: 'Caching nutrition plan on the activity row failed',
        extra: {
          'operation': 'setActivityNutritionPlan',
          'table': 'activities',
          'planId': plan.id,
        },
      );
    }
  }

  /// Get nutrition plan by activity ID
  ///
  /// Retrieves nutrition plan from activity's embedded nutrition_plan_data JSON
  Future<domain.NutritionPlan?> getNutritionPlanByActivityId(
    String userId,
    String activityId,
  ) async {
    DebugLogger.info(
      '🔍 Getting nutrition plan for activityId: $activityId, userId: $userId',
    );

    try {
      // Get activity with nutrition plan data
      final activity = await _getActivityRowWithPlan(activityId);
      if (activity == null) {
        DebugLogger.info('No nutrition plan found for activity $activityId');
        return null;
      }

      // Parse and return the nutrition plan
      final planJson = _decodePlanJson(activity.nutritionPlanData!);
      return NutritionPlanMapper.fromJson(planJson);
    } catch (e, stackTrace) {
      await report.fault(
        e,
        stackTrace: stackTrace,
        area: _area,
        message: 'Reading the nutrition plan for an activity failed',
        extra: {'activityId': activityId},
      );
      return null;
    }
  }

  /// Get latest nutrition plan (local activities only)
  Future<domain.NutritionPlan?> getLatestNutritionPlan(String userId) async {
    DebugLogger.info('🔍 Getting latest nutrition plan for userId: $userId');
    return await getLatestCachedPlan(userId);
  }

  /// Get nutrition plans for a user
  Future<List<domain.NutritionPlan>> getNutritionPlans(String userId) async {
    return await getUserNutritionPlans(userId);
  }

  /// Delete nutrition plan data for an activity (soft delete)
  Future<bool> deleteNutritionPlanForActivity(String activityId) async {
    try {
      DebugLogger.info('🗑️ Clearing nutrition plan for activity $activityId');

      await database.activityDao.clearActivityNutritionPlan(activityId);

      return true;
    } catch (e, stackTrace) {
      await report.fault(
        e,
        stackTrace: stackTrace,
        area: _area,
        message: 'Clearing the nutrition plan on an activity failed',
        extra: {'activityId': activityId},
      );
      return false;
    }
  }

  /// Get latest cached plan (local only)
  Future<domain.NutritionPlan?> getLatestCachedPlan(String userId) async {
    try {
      final activity = await database.activityDao
          .getLatestActivityWithNutritionPlan(userId);
      if (activity?.nutritionPlanData == null) {
        return null;
      }
      final planData =
          json.decode(activity!.nutritionPlanData!) as Map<String, dynamic>;
      return NutritionPlanMapper.fromJson(planData);
    } catch (e, stackTrace) {
      await report.fault(
        e,
        stackTrace: stackTrace,
        area: _area,
        message: 'Reading the latest cached nutrition plan failed',
      );
      return null;
    }
  }

  /// Update plan run date/time (store in JSON planData since runDateTime field doesn't exist)
  Future<void> updatePlanRunDateTimeForActivity(
    String activityId,
    DateTime runDateTime,
  ) async {
    try {
      final activity = await _getActivityRowWithPlan(activityId);
      if (activity == null) {
        throw Exception('Plan not found for activity $activityId');
      }

      final planJson = _decodePlanJson(activity.nutritionPlanData!);
      planJson['runDateTime'] = runDateTime.toIso8601String();

      await database.activityDao.setActivityNutritionPlan(
        activityId: activity.id,
        planData: jsonEncode(planJson),
      );

      DebugLogger.info(
        '✅ Plan run date updated: activityId=$activityId, runDateTime=$runDateTime',
      );
    } catch (e) {
      // The error propagates; the caller owns the report.
      report.info(
        'Updating the plan run date failed: $e',
        area: _area,
        data: {'activityId': activityId},
      );
      rethrow;
    }
  }

  /// Get plans pending feedback (past run date with no rating)
  ///
  /// Returns activities that:
  /// - Have nutrition plan data
  /// - Are completed (or past scheduled date)
  /// - Don't have a completion rating yet
  Future<List<domain.NutritionPlan>> getPlansPendingFeedback(
    String userId,
  ) async {
    DebugLogger.info('🔍 Getting plans pending feedback for userId: $userId');

    try {
      final now = DateTime.now();

      // Query activities with nutrition plan data and no rating
      final activities =
          await (database.select(database.activitiesTable)
                ..where((tbl) => tbl.userId.equals(userId))
                ..where((tbl) => tbl.nutritionPlanData.isNotNull())
                ..where((tbl) => tbl.completionRating.isNull())
                ..orderBy([(tbl) => OrderingTerm.desc(tbl.scheduledDateTime)]))
              .get();

      // Filter to past activities and parse nutrition plans
      final plans = <domain.NutritionPlan>[];
      for (final activity in activities) {
        // Only include if scheduled date is in the past
        if (activity.scheduledDateTime.isAfter(now)) {
          continue;
        }

        try {
          if (activity.nutritionPlanData != null) {
            final planJson = _decodePlanJson(activity.nutritionPlanData!);
            plans.add(NutritionPlanMapper.fromJson(planJson));
          }
        } catch (e, stackTrace) {
          await report.degraded(
            e,
            stackTrace: stackTrace,
            area: _area,
            message: 'Stored plan did not parse; left out of feedback list',
            extra: {'activityId': activity.id},
          );
        }
      }

      DebugLogger.info('Found ${plans.length} plans pending feedback');
      return plans;
    } catch (e, stackTrace) {
      await report.fault(
        e,
        stackTrace: stackTrace,
        area: _area,
        message: 'Listing plans pending feedback failed',
      );
      return [];
    }
  }

  /// Get all nutrition plans for a user
  ///
  /// Returns all activities with nutrition plan data
  Future<List<domain.NutritionPlan>> getUserNutritionPlans(
    String userId,
  ) async {
    DebugLogger.info('🔍 Getting all nutrition plans for userId: $userId');

    try {
      // Query all activities with nutrition plan data
      final activities =
          await (database.select(database.activitiesTable)
                ..where((tbl) => tbl.userId.equals(userId))
                ..where((tbl) => tbl.nutritionPlanData.isNotNull())
                ..orderBy([(tbl) => OrderingTerm.desc(tbl.scheduledDateTime)]))
              .get();

      // Parse nutrition plans from activity rows
      final plans = <domain.NutritionPlan>[];
      for (final activity in activities) {
        try {
          if (activity.nutritionPlanData != null) {
            final planJson = _decodePlanJson(activity.nutritionPlanData!);
            plans.add(NutritionPlanMapper.fromJson(planJson));
          }
        } catch (e, stackTrace) {
          await report.degraded(
            e,
            stackTrace: stackTrace,
            area: _area,
            message: 'Stored plan did not parse; left out of plan list',
            extra: {'activityId': activity.id},
          );
        }
      }

      DebugLogger.info('Found ${plans.length} nutrition plans');
      return plans;
    } catch (e, stackTrace) {
      await report.fault(
        e,
        stackTrace: stackTrace,
        area: _area,
        message: 'Listing the user\'s nutrition plans failed',
      );
      return [];
    }
  }
}

/// Result class for nutrition plan creation
class CreateNutritionPlanResult {
  final bool success;
  final domain.NutritionPlan? plan;
  final Map<String, dynamic>? calculations;
  final String? message;
  final List<String>? warnings;
  final dynamic details;

  CreateNutritionPlanResult({
    required this.success,
    this.plan,
    this.calculations,
    this.message,
    this.warnings,
    this.details,
  });
}

/// Riverpod provider for NutritionPlanRepository
@riverpod
Future<NutritionPlanRepository> nutritionPlanRepository(Ref ref) async {
  final database = ref.watch(appDatabaseProvider);
  final report = ref.watch(reportProvider);
  final transformationService = ref.watch(
    foodDataTransformationServiceProvider,
  );
  final calendarService = ref.watch(calendarServiceProvider);
  final activitiesRepository = ref.watch(activitiesRepositoryProvider);
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;

  return NutritionPlanRepository(
    supabase: supabase,
    database: database,
    report: report,
    transformationService: transformationService,
    calendarService: calendarService,
    activitiesRepository: activitiesRepository,
  );
}

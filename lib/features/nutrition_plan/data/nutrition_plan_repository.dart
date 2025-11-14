import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../activities/data/activities_repository.dart';
import '../../calendar/application/calendar_service.dart';
import '../application/food_data_transformation_service.dart';
import '../domain/food_item_data.dart';
import '../domain/nutrition_plan.dart' as domain;

part 'nutrition_plan_repository.g.dart';

/// Repository for nutrition plan operations using Supabase Edge Functions
/// Includes local caching with Drift database to replace nutrition_plan_local_cache
class NutritionPlanRepository {
  NutritionPlanRepository({
    required this.supabase,
    required this.database,
    required this.sentry,
    required this.transformationService,
    required this.calendarService,
    required this.activitiesRepository,
  });

  final SupabaseClient supabase;
  final AppDatabase database;
  final SentryReporter sentry;
  final CalendarService calendarService;
  final FoodDataTransformationService transformationService;
  final ActivitiesRepository activitiesRepository;

  Future<Activity?> _getActivityRowWithPlan(int activityId) async {
    final activity = await database.getActivityByIdLocal(activityId);
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
    } catch (_) {
      // Ignore parse errors and fall back to empty map.
    }
    return {};
  }

  /// Create a new nutrition plan via new run-plan Edge Function
  Future<CreateNutritionPlanResult> createNutritionPlanV2({
    required String deviceId,
    required double weightKg,
    required int durationMin,
    int? preWindowMin,
    String? gutTraining,
    String? giSensitivity,
    double? tempF,
    double? humidity,
    String? sweatRate,
    bool? allowHighCarbRun,
    int? intervalMinutes,
    double? paceMinPerKm,
    bool debug = false,
  }) async {
    final startTime = DateTime.now();
    
    try {
      // Prepare request payload for new run-plan Edge Function
      final requestBody = <String, dynamic>{
        'deviceId': deviceId,
        'weightKg': weightKg,
        'durationMin': durationMin,
        'debug': debug,
      };
      
      // Add optional parameters
      if (preWindowMin != null) requestBody['preWindowMin'] = preWindowMin;
      if (gutTraining != null) requestBody['gutTraining'] = gutTraining;
      if (giSensitivity != null) requestBody['giSensitivity'] = giSensitivity;
      if (tempF != null) requestBody['tempF'] = tempF;
      if (humidity != null) requestBody['humidity'] = humidity;
      if (sweatRate != null) requestBody['sweatRate'] = sweatRate;
      if (allowHighCarbRun != null) requestBody['allowHighCarbRun'] = allowHighCarbRun;
      if (intervalMinutes != null) requestBody['intervalMinutes'] = intervalMinutes;
      if (paceMinPerKm != null) requestBody['paceMinPerKm'] = paceMinPerKm;

      // Add breadcrumb for Edge Function call
      sentry.addBreadcrumb(
        message: 'Calling run-plan Edge Function',
        category: 'edge_function',
        data: {
          'device_id': deviceId,
          'weight_kg': weightKg.toString(),
          'duration_min': durationMin.toString(),
        },
      );

      // Call new run-plan Edge Function
      final response = await supabase.functions.invoke(
        'run-plan',
        body: requestBody,
      );

      final responseTime = DateTime.now().difference(startTime);

      // Handle response
      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>;
        
        // The new edge function doesn't return a success flag, it returns plan directly
        if (data.containsKey('plan')) {
          // Convert new format to existing NutritionPlan format
          final convertedPlan = await _convertNewPlanFormat(data, deviceId);
          
          // Cache the plan locally
          await cachePlanLocally(deviceId, convertedPlan);
          
          // Success breadcrumb
          sentry.addBreadcrumb(
            message: 'Nutrition plan created successfully with run-plan',
            category: 'edge_function',
            data: {
              'plan_id': convertedPlan.id,
              'response_time_ms': responseTime.inMilliseconds.toString(),
              'warnings': data['warnings']?.length?.toString() ?? '0',
            },
          );
          
          return CreateNutritionPlanResult(
            success: true,
            plan: convertedPlan,
            calculations: data['targets'], // New format uses targets instead of calculations
            message: 'Nutrition plan created successfully',
            warnings: List<String>.from(data['warnings'] ?? []),
          );
        } else if (data.containsKey('error')) {
          // Edge Function returned an error
          await sentry.reportEdgeFunctionError(
            'run-plan',
            Exception('Edge Function returned error: ${data['error']}'),
            responseTime: responseTime,
            statusCode: response.status,
          );
          
          return CreateNutritionPlanResult(
            success: false,
            message: data['error'],
            details: data['details'],
          );
        } else {
          return CreateNutritionPlanResult(
            success: false,
            message: 'Invalid response format from run-plan Edge Function',
          );
        }
      } else {
        // HTTP error
        await sentry.reportEdgeFunctionError(
          'run-plan',
          Exception('Edge Function HTTP error: ${response.status}'),
          responseTime: responseTime,
          statusCode: response.status,
        );
        
        return CreateNutritionPlanResult(
          success: false,
          message: 'Edge Function call failed with status ${response.status}',
        );
      }
    } catch (e, stackTrace) {
      final responseTime = DateTime.now().difference(startTime);
      
      await sentry.reportEdgeFunctionError(
        'run-plan',
        e,
        responseTime: responseTime,
        stackTrace: stackTrace,
      );
      
      return CreateNutritionPlanResult(
        success: false,
        message: 'Failed to create nutrition plan: $e',
      );
    }
  }

  /// Cache nutrition plan locally in Drift database
  Future<void> cachePlanLocally(String userId, domain.NutritionPlan plan) async {
    try {
      final activityId = plan.activityId;
      if (activityId == null) {
        DebugLogger.warning('⚠️ Cannot cache plan ${plan.id} without activityId');
        return;
      }

      DebugLogger.info(
        '💾 Caching plan locally: planId=${plan.id}, userId=$userId, activityId=$activityId',
      );

      final planJson = json.encode(plan.toJson());
      await database.setActivityNutritionPlan(
        activityId: activityId,
        planData: planJson,
      );
      DebugLogger.info('✅ Plan cached on activity row');

      try {
        await calendarService.updateEventNutritionPlanFlag(
          activityId: activityId,
          hasNutritionPlan: true,
        );
      } catch (e) {
        DebugLogger.error('⚠️ Failed to update event nutrition plan flag', error: e);
      }
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Error caching plan locally', error: e, stackTrace: stackTrace);
      await sentry.reportDatabaseError(
        e,
        operation: 'setActivityNutritionPlan',
        table: 'activities',
        stackTrace: stackTrace,
      );
    }
  }

  // TODO: DEPRECATED - Remove temp plan system in favor of activity-owned plans
  // These methods are kept temporarily for backward compatibility but do nothing
  Future<void> saveTempPlan(String deviceId, domain.NutritionPlan plan) async {
    DebugLogger.warning('⚠️ saveTempPlan called but is deprecated - plans should be activity-owned');
    // No-op: Plans are now saved immediately with activity ID
  }

  Future<domain.NutritionPlan?> getTempPlan(String deviceId) async {
    DebugLogger.warning('⚠️ getTempPlan called but is deprecated - plans should be activity-owned');
    return null; // Always return null - no temp plans
  }

  Future<void> clearTempPlan(String deviceId) async {
    DebugLogger.warning('⚠️ clearTempPlan called but is deprecated - plans should be activity-owned');
    // No-op: No temp plans to clear
  }

  /// Get nutrition plan by activity ID
  ///
  /// Retrieves nutrition plan from activity's embedded nutrition_plan_data JSON
  Future<domain.NutritionPlan?> getNutritionPlanByActivityId(
    String userId,
    int activityId,
  ) async {
    DebugLogger.info('🔍 Getting nutrition plan for activityId: $activityId, userId: $userId');

    try {
      // Get activity with nutrition plan data
      final activity = await _getActivityRowWithPlan(activityId);
      if (activity == null) {
        DebugLogger.info('No nutrition plan found for activity $activityId');
        return null;
      }

      // Parse and return the nutrition plan
      final planJson = _decodePlanJson(activity.nutritionPlanData!);
      return domain.NutritionPlan.fromJson(planJson);
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to get nutrition plan for activity $activityId', error: e);
      DebugLogger.debug(stackTrace.toString());
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
  Future<bool> deleteNutritionPlanForActivity(int activityId) async {
    try {
      DebugLogger.info('🗑️ Clearing nutrition plan for activity $activityId');

      await database.clearActivityNutritionPlan(activityId);
      try {
        await calendarService.updateEventNutritionPlanFlag(
          activityId: activityId,
          hasNutritionPlan: false,
        );
      } catch (e) {
        DebugLogger.warning('⚠️ Failed to update event flag during plan delete: $e');
      }

      return true;
    } catch (e, stackTrace) {
      DebugLogger.error('Error deleting nutrition plan', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Clear all nutrition plans for a user (primarily for testing)
  Future<bool> clearAllNutritionPlans(String userId) async {
    try {
      final activities = await database.getActivitiesWithNutritionPlans(userId);
      for (final activity in activities) {
        await database.clearActivityNutritionPlan(activity.id);
      }
      return true;
    } catch (e, stackTrace) {
      DebugLogger.error('Error clearing nutrition plans', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get latest cached plan (local only)
  Future<domain.NutritionPlan?> getLatestCachedPlan(String userId) async {
    try {
      final activity = await database.getLatestActivityWithNutritionPlan(userId);
      if (activity?.nutritionPlanData == null) {
        return null;
      }
      final planData = json.decode(activity!.nutritionPlanData!) as Map<String, dynamic>;
      return domain.NutritionPlan.fromJson(planData);
    } catch (e, stackTrace) {
      DebugLogger.error('Error getting cached plan', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Clear local cache only
  Future<void> clearLocalCache() async {
    try {
      await database.clearAllData();
    } catch (e, stackTrace) {
      DebugLogger.error('Error clearing local cache', error: e, stackTrace: stackTrace);
    }
  }

  /// Convert new edge function format to existing NutritionPlan format
  /// Now handles food_id + quantity format with database lookups
  Future<domain.NutritionPlan> _convertNewPlanFormat(Map<String, dynamic> data, String deviceId) async {
    final plan = data['plan'] as Map<String, dynamic>;
    final targets = data['targets'] as Map<String, dynamic>?;

    // Generate plan ID using UUID to match Supabase schema
    final planId = const Uuid().v4();

    // Convert before section - transform each item using the service
    final beforeData = plan['before'] as Map<String, dynamic>?;
    final beforeItems = <FoodItemData>[];
    if (beforeData != null && beforeData['items'] is List) {
      for (final item in beforeData['items'] as List<dynamic>) {
        final itemMap = item as Map<String, dynamic>;
        final foodItemData = await transformationService.transformEdgeFunctionItem(itemMap);
        beforeItems.add(foodItemData);
      }
    }

    // Convert during section - handle events array
    final duringData = plan['during'] as Map<String, dynamic>?;
    final duringItems = <FoodItemData>[];
    if (duringData != null && duringData['events'] is List) {
      for (final event in duringData['events'] as List<dynamic>) {
        final eventMap = event as Map<String, dynamic>;
        // Add timing information for during-run items
        eventMap['timing'] = 'At ${eventMap['at_min']} minutes';
        final foodItemData = await transformationService.transformEdgeFunctionItem(eventMap);
        duringItems.add(foodItemData);
      }
    }

    // Convert after section
    final afterData = plan['after'] as Map<String, dynamic>?;
    final afterItems = <FoodItemData>[];
    if (afterData != null && afterData['items'] is List) {
      for (final item in afterData['items'] as List<dynamic>) {
        final itemMap = item as Map<String, dynamic>;
        final foodItemData = await transformationService.transformEdgeFunctionItem(itemMap);
        afterItems.add(foodItemData);
      }
    }

    // Calculate macro targets if available
    domain.PlanMacroSummary? macroTargets;
    if (targets != null) {
      final beforeTargets = targets['before'] as Map<String, dynamic>?;
      final duringTargets = targets['during'] as Map<String, dynamic>?;
      final afterTargets = targets['after'] as Map<String, dynamic>?;

      if (beforeTargets != null && duringTargets != null && afterTargets != null) {
        final totalCarbs = (beforeTargets['carbs_g'] as num? ?? 0).toDouble() +
                          (duringTargets['carbs_g_total'] as num? ?? 0).toDouble() +
                          (afterTargets['carbs_g'] as num? ?? 0).toDouble();

        // Calculate total sodium and fluids
        final beforeSodium = beforeTargets['sodium_mg'] as num? ?? 0;
        final duringSodium = duringTargets['sodium_mg_per_h'] as num? ?? 0;
        final afterSodium = afterTargets['sodium_mg'] as num? ?? 0;

        final beforeFluids = beforeTargets['fluid_ml'] as num? ?? 0;
        final duringFluidsPerH = duringTargets['fluid_ml_per_h'] as num? ?? 0;
        final afterFluids = afterTargets['fluid_ml'] as num? ?? 0;

        // Estimate duration (fallback to reasonable default)
        final durationH = 2.0; // Default 2 hours if not provided

        // Convert fluids from ml to oz (1 ml = 0.033814 oz)
        final mlToOz = 0.033814;
        final totalFluidsOz = (beforeFluids + (duringFluidsPerH * durationH) + afterFluids) * mlToOz;
        final totalSodiumMg = beforeSodium + (duringSodium * durationH) + afterSodium;

        macroTargets = domain.PlanMacroSummary(
          calories: 0, // Will be calculated from food items
          carbs: totalCarbs.round(),
          protein: (afterTargets['protein_g'] as num? ?? 0).toDouble().round(),
          fat: 0, // Not provided in current format
          sodium: totalSodiumMg.round(),
          fluids: totalFluidsOz.round(),
          carbsRange: '80-90%',
          proteinRange: '10-15%',
          fatRange: '5-10%',
        );
      }
    }

    return domain.NutritionPlan(
      id: planId,
      name: 'Personalized Nutrition Plan',
      totalCalories: null, // Calculate from food items if needed
      macroTargets: macroTargets,
      sections: [
        domain.PlanSection.withDefaults(
          id: 'before-run',
          title: 'Before Run',
          subtitle: 'Fuel your performance',
          timing: '2h before',
          foodItems: beforeItems,
        ),
        domain.PlanSection.withDefaults(
          id: 'during-run',
          title: 'During Run',
          subtitle: 'Maintain energy',
          timing: 'Every 30min',
          foodItems: duringItems,
        ),
        domain.PlanSection.withDefaults(
          id: 'after-run',
          title: 'After Run',
          subtitle: 'Recover strong',
          timing: '30min after',
          foodItems: afterItems,
        ),
      ],
      notes: 'Generated using AI-powered nutrition planning',
      createdAt: DateTime.now(),
    );
  }

  /// Update plan feedback (rating and journal notes) by activity ID.
  Future<void> updatePlanFeedbackForActivity({
    required int activityId,
    int? rating,
    String? notes,
  }) async {
    try {
      final activity = await _getActivityRowWithPlan(activityId);
      if (activity == null) {
        throw Exception('Plan not found for activity $activityId');
      }

      final planJson = _decodePlanJson(activity.nutritionPlanData!);
      if (rating != null) planJson['planRating'] = rating;
      if (notes != null) planJson['journalNotes'] = notes;
      planJson.remove('runDateTime');

      await database.setActivityNutritionPlan(
        activityId: activity.id,
        planData: jsonEncode(planJson),
      );

      DebugLogger.info(
        '✅ Plan feedback updated for activity $activityId (rating=$rating, notes=$notes)',
      );
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to update plan feedback', error: e, stackTrace: stackTrace);
      await sentry.reportDatabaseError(e, stackTrace: stackTrace, operation: 'updatePlanFeedback');
      rethrow;
    }
  }

  /// Update plan run date/time (store in JSON planData since runDateTime field doesn't exist)
  Future<void> updatePlanRunDateTimeForActivity(int activityId, DateTime runDateTime) async {
    try {
      final activity = await _getActivityRowWithPlan(activityId);
      if (activity == null) {
        throw Exception('Plan not found for activity $activityId');
      }

      final planJson = _decodePlanJson(activity.nutritionPlanData!);
      planJson['runDateTime'] = runDateTime.toIso8601String();

      await database.setActivityNutritionPlan(
        activityId: activity.id,
        planData: jsonEncode(planJson),
      );

      DebugLogger.info('✅ Plan run date updated: activityId=$activityId, runDateTime=$runDateTime');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to update plan run date: $e');
      await sentry.reportDatabaseError(e, stackTrace: stackTrace, operation: 'updatePlanRunDateTime');
      rethrow;
    }
  }

  /// Get plans pending feedback (past run date with no rating)
  ///
  /// Returns activities that:
  /// - Have nutrition plan data
  /// - Are completed (or past scheduled date)
  /// - Don't have a completion rating yet
  Future<List<domain.NutritionPlan>> getPlansPendingFeedback(String userId) async {
    DebugLogger.info('🔍 Getting plans pending feedback for userId: $userId');

    try {
      final now = DateTime.now();

      // Query activities with nutrition plan data and no rating
      final activities = await (database.select(database.activitiesTable)
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
            plans.add(domain.NutritionPlan.fromJson(planJson));
          }
        } catch (e) {
          DebugLogger.warning('Failed to parse plan for activity ${activity.id}: $e');
        }
      }

      DebugLogger.info('Found ${plans.length} plans pending feedback');
      return plans;
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to get plans pending feedback', error: e);
      DebugLogger.debug(stackTrace.toString());
      return [];
    }
  }

  /// Get all nutrition plans for a user
  ///
  /// Returns all activities with nutrition plan data
  Future<List<domain.NutritionPlan>> getUserNutritionPlans(String userId) async {
    DebugLogger.info('🔍 Getting all nutrition plans for userId: $userId');

    try {
      // Query all activities with nutrition plan data
      final activities = await (database.select(database.activitiesTable)
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
            plans.add(domain.NutritionPlan.fromJson(planJson));
          }
        } catch (e) {
          DebugLogger.warning('Failed to parse plan for activity ${activity.id}: $e');
        }
      }

      DebugLogger.info('Found ${plans.length} nutrition plans');
      return plans;
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to get user nutrition plans', error: e);
      DebugLogger.debug(stackTrace.toString());
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
  final sentry = ref.watch(sentryReporterProvider);
  final transformationService = ref.watch(foodDataTransformationServiceProvider);
  final calendarService = ref.watch(calendarServiceProvider);
  final activitiesRepository = ref.watch(activitiesRepositoryProvider);
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;

  return NutritionPlanRepository(
    supabase: supabase,
    database: database,
    sentry: sentry,
    transformationService: transformationService,
    calendarService: calendarService,
    activitiesRepository: activitiesRepository,
  );
}

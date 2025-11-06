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
  });

  final SupabaseClient supabase;
  final AppDatabase database;
  final SentryReporter sentry;
  final CalendarService calendarService;
  final FoodDataTransformationService transformationService;

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

  /// Create a new nutrition plan via Edge Function (Legacy)
  Future<CreateNutritionPlanResult> createNutritionPlan({
    required String deviceId,
    required double distanceMiles,
    required double paceMinutesPerMile,
    double timeBeforeRunHours = 2.0,
    String? gutTrainingLevel, // Override user's default
  }) async {
    final startTime = DateTime.now();
    
    try {
      // Prepare request payload
      final requestBody = {
        'device_id': deviceId,
        'distance_miles': distanceMiles,
        'pace_minutes_per_mile': paceMinutesPerMile,
        'time_before_run_hours': timeBeforeRunHours,
        if (gutTrainingLevel != null) 'gut_training_level': gutTrainingLevel,
      };

      // Add breadcrumb for Edge Function call
      sentry.addBreadcrumb(
        message: 'Calling create-nutrition-plan Edge Function',
        category: 'edge_function',
        data: {
          'device_id': deviceId,
          'distance_miles': distanceMiles.toString(),
          'pace_minutes_per_mile': paceMinutesPerMile.toString(),
        },
      );

      // Call Edge Function
      final response = await supabase.functions.invoke(
        'create-nutrition-plan',
        body: requestBody,
      );

      final responseTime = DateTime.now().difference(startTime);

      // Handle response
      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>;
        
        if (data['success'] == true) {
          final plan = domain.NutritionPlan.fromJson(data['plan']);
          
          // Cache the plan locally
          await cachePlanLocally(deviceId, plan);
          
          // Success breadcrumb
          sentry.addBreadcrumb(
            message: 'Nutrition plan created successfully',
            category: 'edge_function',
            data: {
              'plan_id': plan.id,
              'response_time_ms': responseTime.inMilliseconds.toString(),
            },
          );
          
          return CreateNutritionPlanResult(
            success: true,
            plan: plan,
            calculations: data['calculations'],
            message: data['message'],
          );
        } else {
          // Edge Function returned an error
          await sentry.reportEdgeFunctionError(
            'create-nutrition-plan',
            Exception('Edge Function returned error: ${data['message']}'),
            responseTime: responseTime,
            statusCode: response.status,
          );
          
          return CreateNutritionPlanResult(
            success: false,
            message: data['message'] ?? 'Unknown error occurred',
          );
        }
      } else {
        // HTTP error
        await sentry.reportEdgeFunctionError(
          'create-nutrition-plan',
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
        'create-nutrition-plan',
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
  Future<void> cachePlanLocally(String deviceId, domain.NutritionPlan plan) async {
    try {
      DebugLogger.info('💾 Caching plan locally: planId=${plan.id}, deviceId=$deviceId, name=${plan.name}, activityId=${plan.activityId}');
      final planJson = json.encode(plan.toJson());
      DebugLogger.info('📄 Plan JSON length: ${planJson.length} characters');
      await database.saveNutritionPlan(
        id: plan.id,
        deviceId: deviceId,
        planId: plan.id,
        planName: plan.name,
        planData: planJson,
        totalCalories: plan.totalCalories,
        notes: plan.notes,
        activityId: plan.activityId, // Link to calendar activity
      );
      DebugLogger.info('✅ Plan cached successfully in Drift database');

      // Update event's has_nutrition_plan flag if this plan is linked to an event
      if (plan.activityId != null) {
        try {
          await calendarService.updateEventNutritionPlanFlag(
            activityId: plan.activityId!,
            hasNutritionPlan: true,
          );
          DebugLogger.info('✅ Updated event nutrition plan flag for activity: ${plan.activityId}');
        } catch (e) {
          DebugLogger.error('⚠️ Failed to update event nutrition plan flag', error: e);
          // Don't throw - flag update failure shouldn't break the main flow
        }
      }
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Error caching plan locally', error: e, stackTrace: stackTrace);
      await sentry.reportDatabaseError(
        e,
        operation: 'saveNutritionPlan',
        table: 'nutrition_plans',
        stackTrace: stackTrace,
      );
      // Don't throw - caching failure shouldn't break the main flow
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

  /// Get nutrition plan by activity ID (local cache first, then remote)
  Future<domain.NutritionPlan?> getNutritionPlanByActivityId(String deviceId, String activityId) async {
    DebugLogger.info('🔍 Getting nutrition plan for activityId: $activityId, deviceId: $deviceId');
    
    try {
      // First try local cache
      DebugLogger.info('📱 Checking local Drift cache...');
      final cachedPlanEntry = await database.getNutritionPlanByActivityId(deviceId, activityId);

      if (cachedPlanEntry != null && cachedPlanEntry.planData.isNotEmpty) {
        DebugLogger.info('✅ Found cached plan for activity, parsing JSON...');
        try {
          final planData = json.decode(cachedPlanEntry.planData);
          final plan = domain.NutritionPlan.fromJson(planData);
          DebugLogger.info('✅ Successfully parsed cached plan: ${plan.name} with ${plan.sections.length} sections');
          return plan;
        } catch (e, stackTrace) {
          DebugLogger.error('❌ Error parsing cached nutrition plan', error: e, stackTrace: stackTrace);
        }
      } else {
        DebugLogger.info('📭 No cached plan found for activity, checking remote...');
      }

      // Fall back to remote
      DebugLogger.info('☁️ Checking Supabase for activity_id: $activityId');
      final response = await supabase
          .from('nutrition_plans')
          .select('*')
          .eq('device_id', deviceId)
          .eq('activity_id', activityId)
          .eq('is_deleted', false)
          .maybeSingle();

      if (response != null) {
        DebugLogger.info('✅ Found remote plan for activity, parsing Supabase response...');
        try {
          final plan = domain.NutritionPlan.fromSupabaseJson(response);
          DebugLogger.info('✅ Successfully parsed remote plan: ${plan.name} with ${plan.sections.length} sections');
          
          // Cache it locally for next time
          DebugLogger.info('💾 Caching plan locally...');
          await cachePlanLocally(deviceId, plan);
          DebugLogger.info('✅ Plan cached successfully');
          
          return plan;
        } catch (e, stackTrace) {
          DebugLogger.error('❌ Error parsing Supabase nutrition plan', error: e, stackTrace: stackTrace);
          return null;
        }
      } else {
        DebugLogger.info('📭 No remote plan found for activity');
      }
      return null;
    } catch (e, stackTrace) {
      DebugLogger.error('Error fetching nutrition plan by activity ID', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Update the activity ID for a nutrition plan (links plan to activity)
  Future<bool> updatePlanActivityId(String deviceId, String planId, String activityId) async {
    DebugLogger.info('🔗 Linking nutrition plan $planId to activity $activityId');
    
    try {
      // Update in local cache
      await database.updateNutritionPlanActivityId(deviceId, planId, activityId);
      DebugLogger.info('✅ Updated local plan with activity ID');

      // Update in remote (Supabase)
      try {
        await supabase
            .from('nutrition_plans')
            .update({
              'activity_id': activityId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('device_id', deviceId)
            .eq('plan_id', planId);
        DebugLogger.info('✅ Updated remote plan with activity ID');
      } catch (e) {
        DebugLogger.warning('⚠️ Failed to update remote plan (offline mode?): $e');
        // Don't fail if remote update fails - local update is sufficient
      }

      return true;
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Error updating plan activity ID', error: e, stackTrace: stackTrace);
      await sentry.reportDatabaseError(
        e,
        operation: 'updatePlanActivityId',
        table: 'nutrition_plans',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Get latest nutrition plan (try cache first, then remote)
  Future<domain.NutritionPlan?> getLatestNutritionPlan(String deviceId) async {
    DebugLogger.info('🔍 Getting latest nutrition plan for deviceId: $deviceId');
    
    try {
      // First try local cache
      DebugLogger.info('📱 Checking local Drift cache...');
      final cachedPlanEntry = await database.getLatestNutritionPlan(deviceId);

      if (cachedPlanEntry != null && cachedPlanEntry.planData.isNotEmpty) {
        DebugLogger.info('✅ Found cached plan, parsing JSON...');
        try {
          final planData = json.decode(cachedPlanEntry.planData);
          final plan = domain.NutritionPlan.fromJson(planData);
          DebugLogger.info('✅ Successfully parsed cached plan: ${plan.name} with ${plan.sections.length} sections');
          return plan;
        } catch (e, stackTrace) {
          DebugLogger.error('❌ Error parsing cached nutrition plan', error: e, stackTrace: stackTrace);
          // Clear corrupted cache and continue to remote fetch
          await database.clearAllData();
        }
      } else {
        DebugLogger.info('📭 No cached plan found, checking remote...');
      }

      // Fall back to remote
      DebugLogger.info('☁️ Checking Supabase for device_id: $deviceId');
      final response = await supabase
          .from('nutrition_plans')
          .select('*')
          .eq('device_id', deviceId)
          .eq('is_deleted', false)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        DebugLogger.info('✅ Found remote plan, parsing Supabase response...');
        try {
          final plan = domain.NutritionPlan.fromSupabaseJson(response);
          DebugLogger.info('✅ Successfully parsed remote plan: ${plan.name} with ${plan.sections.length} sections');
          
          // Cache it locally for next time
          DebugLogger.info('💾 Caching plan locally...');
          await cachePlanLocally(deviceId, plan);
          DebugLogger.info('✅ Plan cached successfully');
          
          return plan;
        } catch (e, stackTrace) {
          DebugLogger.error('❌ Error parsing Supabase nutrition plan', error: e, stackTrace: stackTrace);
          DebugLogger.info('📊 Raw response: $response');
          // Return null if parsing fails
          return null;
        }
      } else {
        DebugLogger.info('📭 No remote plan found');
      }
      return null;
    } catch (e, stackTrace) {
      DebugLogger.error('Error fetching latest nutrition plan', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get nutrition plans for a user (remote only for now)
  Future<List<domain.NutritionPlan>> getNutritionPlans(String deviceId) async {
    try {
      final response = await supabase
          .from('nutrition_plans')
          .select('*')
          .eq('device_id', deviceId)
          .eq('is_deleted', false)
          .order('updated_at', ascending: false);

      return response.map<domain.NutritionPlan>((json) => domain.NutritionPlan.fromSupabaseJson(json)).toList();
    } catch (e) {
      DebugLogger.error('Error fetching nutrition plans: $e');
      return [];
    }
  }

  /// Get a specific nutrition plan by ID
  Future<domain.NutritionPlan?> getNutritionPlan(String deviceId, String planId) async {
    try {
      final response = await supabase
          .from('nutrition_plans')
          .select('*')
          .eq('device_id', deviceId)
          .eq('plan_id', planId)
          .eq('is_deleted', false)
          .maybeSingle();

      if (response != null) {
        return domain.NutritionPlan.fromSupabaseJson(response);
      }
      return null;
    } catch (e, stackTrace) {
      DebugLogger.error('Error fetching nutrition plan', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Update a nutrition plan (re-create via Edge Function for consistency)
  Future<CreateNutritionPlanResult> updateNutritionPlan({
    required String deviceId,
    required double distanceMiles,
    required double paceMinutesPerMile,
    double timeBeforeRunHours = 2.0,
    String? gutTrainingLevel,
  }) async {
    // For updates, we just call the create function again
    // The Edge Function will handle versioning and conflicts
    return await createNutritionPlan(
      deviceId: deviceId,
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      timeBeforeRunHours: timeBeforeRunHours,
      gutTrainingLevel: gutTrainingLevel,
    );
  }

  /// Delete a nutrition plan (soft delete)
  Future<bool> deleteNutritionPlan(String deviceId, String planId) async {
    try {
      await supabase
          .from('nutrition_plans')
          .update({
            'is_deleted': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('device_id', deviceId)
          .eq('plan_id', planId);

      return true;
    } catch (e, stackTrace) {
      DebugLogger.error('Error deleting nutrition plan', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Clear all nutrition plans for a user (for testing)
  Future<bool> clearAllNutritionPlans(String deviceId) async {
    try {
      // Clear from remote
      await supabase
          .from('nutrition_plans')
          .update({'is_deleted': true})
          .eq('device_id', deviceId);

      // Clear from local cache
      await database.clearAllData();

      return true;
    } catch (e, stackTrace) {
      DebugLogger.error('Error clearing nutrition plans', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get latest cached plan (local only)
  Future<domain.NutritionPlan?> getLatestCachedPlan(String deviceId) async {
    try {
      final cachedPlanEntry = await database.getLatestNutritionPlan(deviceId);
      if (cachedPlanEntry != null) {
        final planData = json.decode(cachedPlanEntry.planData);
        return domain.NutritionPlan.fromJson(planData);
      }
      return null;
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
    domain.MacroTargets? macroTargets;
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

        macroTargets = domain.MacroTargets(
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

  /// Update plan feedback (rating and journal notes)
  Future<void> updatePlanFeedback(String planId, int? rating, String? notes) async {
    try {
      await database.transaction(() async {
        // Get the existing plan data
        final existingPlan = await (database.select(database.nutritionPlans)
          ..where((plan) => plan.id.equals(planId)))
          .getSingleOrNull();
        
        if (existingPlan == null) {
          throw Exception('Plan not found: $planId');
        }

        // Update the plan JSON data to include feedback
        Map<String, dynamic> planJson = {};
        final existingPlanData = existingPlan.planData;
        if (existingPlanData.isNotEmpty) {
          try {
            planJson = jsonDecode(existingPlanData) as Map<String, dynamic>;
          } catch (e) {
            DebugLogger.warning('Could not parse existing plan data JSON: $e');
            planJson = {};
          }
        }
        
        // Update JSON with feedback
        if (rating != null) planJson['planRating'] = rating;
        if (notes != null) planJson['journalNotes'] = notes;
        
        // Clear the runDateTime so feedback won't be requested again
        planJson.remove('runDateTime');
        
        final updatedPlanData = jsonEncode(planJson);

        // Update the plan with new feedback
        await (database.update(database.nutritionPlans)
          ..where((plan) => plan.id.equals(planId)))
          .write(NutritionPlansCompanion(
            planData: Value(updatedPlanData), // Update JSON data with feedback
            updatedAt: Value(DateTime.now()),
          ));
      });
      
      DebugLogger.info('✅ Plan feedback updated: planId=$planId, rating=$rating, notes=$notes');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to update plan feedback', error: e, stackTrace: stackTrace);
      await sentry.reportDatabaseError(e, stackTrace: stackTrace, operation: 'updatePlanFeedback');
      rethrow;
    }
  }

  /// Update plan run date/time (store in JSON planData since runDateTime field doesn't exist)
  Future<void> updatePlanRunDateTime(String planId, DateTime runDateTime) async {
    try {
      await database.transaction(() async {
        // Get the existing plan to update the JSON data
        final existingPlan = await (database.select(database.nutritionPlans)
          ..where((plan) => plan.id.equals(planId))).getSingleOrNull();

        if (existingPlan != null) {
          // Update the JSON data to include runDateTime
          final planJson = jsonDecode(existingPlan.planData) as Map<String, dynamic>;
          planJson['runDateTime'] = runDateTime.toIso8601String();

          await (database.update(database.nutritionPlans)
            ..where((plan) => plan.id.equals(planId)))
            .write(NutritionPlansCompanion(
              planData: Value(jsonEncode(planJson)),
              updatedAt: Value(DateTime.now()),
            ));
        }
      });

      DebugLogger.info('✅ Plan run date updated: planId=$planId, runDateTime=$runDateTime');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to update plan run date: $e');
      await sentry.reportDatabaseError(e, stackTrace: stackTrace, operation: 'updatePlanRunDateTime');
      rethrow;
    }
  }

  /// Get plans pending feedback (past run date with no rating)
  Future<List<domain.NutritionPlan>> getPlansPendingFeedback(String deviceId) async {
    try {
      final now = DateTime.now();
      final query = database.select(database.nutritionPlans)
        ..where((plan) =>
          plan.deviceId.equals(deviceId) &
          plan.isDeleted.equals(false))
        ..orderBy([(plan) => OrderingTerm.desc(plan.updatedAt)])
        ..limit(10); // Get recent plans and filter for pending feedback in code

      final results = await query.get();
      final plans = <domain.NutritionPlan>[];

      for (final row in results) {
        try {
          final planData = jsonDecode(row.planData) as Map<String, dynamic>;

          // Check if plan has runDateTime but no rating (pending feedback)
          final runDateTime = planData['runDateTime'] as String?;
          final planRating = planData['planRating'] as int?;

          if (runDateTime != null && planRating == null) {
            final runDate = DateTime.parse(runDateTime);
            if (runDate.isBefore(now)) {
              final plan = domain.NutritionPlan.fromJson(planData);
              plans.add(plan);
            }
          }
        } catch (e) {
          DebugLogger.error('❌ Failed to parse plan ${row.id}: $e');
          // Skip invalid plans
          continue;
        }
      }
      
      DebugLogger.info('✅ Found ${plans.length} plans pending feedback');
      return plans;
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to get plans pending feedback: $e');
      await sentry.reportDatabaseError(e, stackTrace: stackTrace, operation: 'getPlansPendingFeedback');
      return [];
    }
  }

  /// Get all nutrition plans for a user
  Future<List<domain.NutritionPlan>> getUserNutritionPlans(String deviceId) async {
    try {
      final query = database.select(database.nutritionPlans)
        ..where((plan) => plan.deviceId.equals(deviceId) & plan.isDeleted.equals(false))
        ..orderBy([(plan) => OrderingTerm.desc(plan.createdAt)]);

      final results = await query.get();
      final plans = <domain.NutritionPlan>[];

      for (final row in results) {
        try {
          final planData = jsonDecode(row.planData) as Map<String, dynamic>;
          final plan = domain.NutritionPlan.fromJson(planData);
          plans.add(plan);
        } catch (e) {
          DebugLogger.error('❌ Failed to parse plan ${row.id}: $e');
          // Skip invalid plans
          continue;
        }
      }
      
      DebugLogger.info('✅ Retrieved ${plans.length} nutrition plans for user $deviceId');
      return plans;
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to get user nutrition plans: $e');
      await sentry.reportDatabaseError(e, stackTrace: stackTrace, operation: 'getUserNutritionPlans');
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
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;

  return NutritionPlanRepository(
    supabase: supabase,
    database: database,
    sentry: sentry,
    transformationService: transformationService,
    calendarService: calendarService,
  );
}

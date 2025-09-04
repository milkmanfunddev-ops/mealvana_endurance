import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/nutrition_plan.dart' as domain;
import '../domain/food_item_data.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/sentry_service.dart';
import 'dart:convert';

part 'nutrition_plan_repository.g.dart';

/// Repository for nutrition plan operations using Supabase Edge Functions
/// Includes local caching with Drift database to replace nutrition_plan_local_cache
class NutritionPlanRepository {
  NutritionPlanRepository({
    required this.supabase,
    required this.database,
    required this.sentryService,
  });
  
  final SupabaseClient supabase;
  final AppDatabase database;
  final SentryService sentryService;

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
      sentryService.addBreadcrumb(
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
          final convertedPlan = _convertNewPlanFormat(data, deviceId);
          
          // Cache the plan locally
          await cachePlanLocally(deviceId, convertedPlan);
          
          // Success breadcrumb
          sentryService.addBreadcrumb(
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
          await sentryService.reportEdgeFunctionError(
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
        await sentryService.reportEdgeFunctionError(
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
      
      await sentryService.reportEdgeFunctionError(
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
      sentryService.addBreadcrumb(
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
          sentryService.addBreadcrumb(
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
          await sentryService.reportEdgeFunctionError(
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
        await sentryService.reportEdgeFunctionError(
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
      
      await sentryService.reportEdgeFunctionError(
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
      print('💾 Caching plan locally: planId=${plan.id}, deviceId=$deviceId, name=${plan.name}');
      final planJson = json.encode(plan.toJson());
      print('📄 Plan JSON length: ${planJson.length} characters');
      await database.saveNutritionPlan(plan.id, deviceId, planJson);
      print('✅ Plan cached successfully in Drift database');
    } catch (e, stackTrace) {
      print('❌ Error caching plan locally: $e');
      await sentryService.reportDatabaseError(
        e,
        operation: 'saveNutritionPlan',
        table: 'nutrition_plans',
        stackTrace: stackTrace,
      );
      // Don't throw - caching failure shouldn't break the main flow
    }
  }

  /// Get latest nutrition plan (try cache first, then remote)
  Future<domain.NutritionPlan?> getLatestNutritionPlan(String deviceId) async {
    print('🔍 Getting latest nutrition plan for deviceId: $deviceId');
    
    try {
      // First try local cache
      print('📱 Checking local Drift cache...');
      final cachedPlanJson = await database.getLatestNutritionPlan(deviceId);
      
      if (cachedPlanJson != null && cachedPlanJson.isNotEmpty) {
        print('✅ Found cached plan, parsing JSON...');
        try {
          final planData = json.decode(cachedPlanJson);
          final plan = domain.NutritionPlan.fromJson(planData);
          print('✅ Successfully parsed cached plan: ${plan.name} with ${plan.sections.length} sections');
          return plan;
        } catch (e) {
          print('❌ Error parsing cached nutrition plan: $e');
          // Clear corrupted cache and continue to remote fetch
          await database.clearAllData();
        }
      } else {
        print('📭 No cached plan found, checking remote...');
      }

      // Fall back to remote
      print('☁️ Checking Supabase for device_id: $deviceId');
      final response = await supabase
          .from('nutrition_plans')
          .select('*')
          .eq('device_id', deviceId)
          .eq('is_deleted', false)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        print('✅ Found remote plan, parsing Supabase response...');
        try {
          final plan = domain.NutritionPlan.fromSupabaseJson(response);
          print('✅ Successfully parsed remote plan: ${plan.name} with ${plan.sections.length} sections');
          
          // Cache it locally for next time
          print('💾 Caching plan locally...');
          await cachePlanLocally(deviceId, plan);
          print('✅ Plan cached successfully');
          
          return plan;
        } catch (e) {
          print('❌ Error parsing Supabase nutrition plan: $e');
          print('📊 Raw response: $response');
          // Return null if parsing fails
          return null;
        }
      } else {
        print('📭 No remote plan found');
      }
      return null;
    } catch (e) {
      print('Error fetching latest nutrition plan: $e');
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
      print('Error fetching nutrition plans: $e');
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
    } catch (e) {
      print('Error fetching nutrition plan: $e');
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
    } catch (e) {
      print('Error deleting nutrition plan: $e');
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
    } catch (e) {
      print('Error clearing nutrition plans: $e');
      return false;
    }
  }

  /// Get latest cached plan (local only)
  Future<domain.NutritionPlan?> getLatestCachedPlan(String deviceId) async {
    try {
      final cachedPlanJson = await database.getLatestNutritionPlan(deviceId);
      if (cachedPlanJson != null) {
        final planData = json.decode(cachedPlanJson);
        return domain.NutritionPlan.fromJson(planData);
      }
      return null;
    } catch (e) {
      print('Error getting cached plan: $e');
      return null;
    }
  }

  /// Clear local cache only
  Future<void> clearLocalCache() async {
    try {
      await database.clearAllData();
    } catch (e) {
      print('Error clearing local cache: $e');
    }
  }

  /// Convert new run-plan format to existing NutritionPlan format
  domain.NutritionPlan _convertNewPlanFormat(Map<String, dynamic> data, String deviceId) {
    final plan = data['plan'] as Map<String, dynamic>;
    final targets = data['targets'] as Map<String, dynamic>;
    final inputs = data['inputs'] as Map<String, dynamic>;
    
    // Generate plan ID
    final planId = 'plan-${DateTime.now().millisecondsSinceEpoch}-${deviceId.substring(deviceId.length - 4)}';
    
    // Convert before section
    final beforeData = plan['before'] as Map<String, dynamic>;
    final beforeItems = (beforeData['items'] as List<dynamic>).map((item) {
      final itemMap = item as Map<String, dynamic>;
      return FoodItemData(
        id: itemMap['name'].toString().toLowerCase().replaceAll(' ', '_'),
        name: itemMap['name'],
        quantity: '${itemMap['servings']} serving${itemMap['servings'] == 1 ? '' : 's'}',
        imageAddress: itemMap['image_address'] as String?,
        description: '',
        nutritionalInfo: NutritionalInfo(
          calories: 0,
          carbs: (itemMap['carbs_g'] as num).round(),
          protein: 0,
          fat: 0,
          sodium: 0,
          fluids: 0.0,
        ),
      );
    }).toList();

    // Convert during section
    final duringData = plan['during'] as Map<String, dynamic>;
    final duringEvents = duringData['events'] as List<dynamic>;
    final duringItems = duringEvents.map((event) {
      final eventMap = event as Map<String, dynamic>;
      return FoodItemData(
        id: eventMap['item'].toString().toLowerCase().replaceAll(' ', '_'),
        name: eventMap['item'],
        quantity: '${eventMap['servings']} serving${eventMap['servings'] == 1 ? '' : 's'}',
        imageAddress: eventMap['image_address'] as String?,
        description: 'At ${eventMap['at_min']} minutes',
        nutritionalInfo: NutritionalInfo(
          calories: 0,
          carbs: (eventMap['carbs_g'] as num).round(),
          protein: 0,
          fat: 0,
          sodium: (eventMap['sodium_mg'] as num).round(),
        ),
      );
    }).toList();

    // Convert after section
    final afterData = plan['after'] as Map<String, dynamic>;
    final afterItems = (afterData['items'] as List<dynamic>).map((item) {
      final itemMap = item as Map<String, dynamic>;
      return FoodItemData(
        id: itemMap['name'].toString().toLowerCase().replaceAll(' ', '_'),
        name: itemMap['name'],
        quantity: '${itemMap['servings']} serving${itemMap['servings'] == 1 ? '' : 's'}',
        imageAddress: itemMap['image_address'] as String?,
        description: '',
        nutritionalInfo: NutritionalInfo(
          calories: 0,
          carbs: (itemMap['carbs_g'] as num).round(),
          protein: (itemMap['protein_g'] as num).round(),
          fat: 0,
          sodium: (itemMap['sodium_mg'] as num).round(),
        ),
      );
    }).toList();

    // Calculate macro targets from targets
    final beforeTargets = targets['before'] as Map<String, dynamic>;
    final duringTargets = targets['during'] as Map<String, dynamic>;
    final afterTargets = targets['after'] as Map<String, dynamic>;
    
    final totalCarbs = (beforeTargets['carbs_g'] as num).toDouble() + 
                      (duringTargets['carbs_g_total'] as num).toDouble() + 
                      (afterTargets['carbs_g'] as num).toDouble();

    // Calculate total sodium and fluids
    final beforeSodium = beforeTargets['sodium_mg'] as num?;
    final duringSodium = duringTargets['sodium_mg_per_h'] as num?;
    final afterSodium = afterTargets['sodium_mg'] as num?;
    
    final beforeFluids = beforeTargets['fluid_ml'] as num?;
    final duringFluidsPerH = duringTargets['fluid_ml_per_h'] as num?;
    final afterFluids = afterTargets['fluid_ml'] as num?;
    final durationH = (inputs['durationMin'] as num).toDouble() / 60.0;
    
    // Convert fluids from ml to oz (1 ml = 0.033814 oz)
    final mlToOz = 0.033814;
    final totalFluidsOz = ((beforeFluids ?? 0) + 
                          ((duringFluidsPerH ?? 0) * durationH) + 
                          (afterFluids ?? 0)) * mlToOz;
    
    final totalSodiumMg = (beforeSodium ?? 0) + 
                         ((duringSodium ?? 0) * durationH) + 
                         (afterSodium ?? 0);

    return domain.NutritionPlan(
      id: planId,
      name: 'Personalized Nutrition Plan',
      totalCalories: null, // Not provided in new format
      macroTargets: domain.MacroTargets(
        calories: 0, // Not calculated in new format
        carbs: totalCarbs.round(),
        protein: (afterTargets['protein_g'] as num).toDouble().round(),
        fat: 0, // Not provided in new format
        sodium: totalSodiumMg.round(),
        fluids: totalFluidsOz.round(),
        carbsRange: '80-90%',
        proteinRange: '10-15%',
        fatRange: '5-10%',
      ),
      sections: [
        domain.PlanSection(
          id: 'before-run',
          title: 'Before Run',
          subtitle: 'Fueling window: ${inputs['preWindowMin'] ?? 120} minutes before',
          timing: '${inputs['preWindowMin'] ?? 120}min before',
          foodItems: beforeItems,
        ),
        domain.PlanSection(
          id: 'during-run',
          title: 'During Run',
          subtitle: 'Every ${inputs['intervalMinutes'] ?? 30} minutes',
          timing: 'Every ${inputs['intervalMinutes'] ?? 30}min',
          foodItems: duringItems,
        ),
        domain.PlanSection(
          id: 'after-run',
          title: 'After Run',
          subtitle: 'Within 30 minutes',
          timing: '30min',
          foodItems: afterItems,
        ),
      ],
      notes: 'Generated using enhanced run-plan algorithm',
      createdAt: DateTime.now(),
    );
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
  final database = await ref.watch(databaseProvider.future);
  final sentryService = ref.watch(sentryServiceProvider);
  
  return NutritionPlanRepository(
    supabase: Supabase.instance.client,
    database: database,
    sentryService: sentryService,
  );
}
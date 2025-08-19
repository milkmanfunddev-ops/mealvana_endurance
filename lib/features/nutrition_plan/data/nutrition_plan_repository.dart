import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/nutrition_plan.dart';

/// Repository for nutrition plan operations using Supabase Edge Functions
/// Replaces complex client-side calculations and direct database access
class NutritionPlanRepository {
  NutritionPlanRepository(this._supabase);
  
  final SupabaseClient _supabase;

  /// Create a new nutrition plan via Edge Function
  Future<CreateNutritionPlanResult> createNutritionPlan({
    required String deviceId,
    required double distanceMiles,
    required double paceMinutesPerMile,
    double timeBeforeRunHours = 2.0,
    String? gutTrainingLevel, // Override user's default
  }) async {
    try {
      // Prepare request payload
      final requestBody = {
        'device_id': deviceId,
        'distance_miles': distanceMiles,
        'pace_minutes_per_mile': paceMinutesPerMile,
        'time_before_run_hours': timeBeforeRunHours,
        if (gutTrainingLevel != null) 'gut_training_level': gutTrainingLevel,
      };

      // Call Edge Function
      final response = await _supabase.functions.invoke(
        'create-nutrition-plan',
        body: requestBody,
      );

      // Handle response
      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>;
        
        if (data['success'] == true) {
          return CreateNutritionPlanResult(
            success: true,
            plan: NutritionPlan.fromJson(data['plan']),
            calculations: data['calculations'],
            message: data['message'],
          );
        } else {
          return CreateNutritionPlanResult(
            success: false,
            message: data['message'] ?? 'Unknown error occurred',
          );
        }
      } else {
        return CreateNutritionPlanResult(
          success: false,
          message: 'Edge Function call failed with status ${response.status}',
        );
      }
    } catch (e) {
      print('Error calling create-nutrition-plan Edge Function: $e');
      return CreateNutritionPlanResult(
        success: false,
        message: 'Failed to create nutrition plan: $e',
      );
    }
  }

  /// Get nutrition plans for a user (direct database call since it's simple)
  Future<List<NutritionPlan>> getNutritionPlans(String deviceId) async {
    try {
      final response = await _supabase
          .from('nutrition_plans')
          .select('*')
          .eq('device_id', deviceId)
          .eq('is_deleted', false)
          .order('updated_at', ascending: false);

      return response.map<NutritionPlan>((json) => NutritionPlan.fromSupabaseJson(json)).toList();
    } catch (e) {
      print('Error fetching nutrition plans: $e');
      return [];
    }
  }

  /// Get latest nutrition plan for a user
  Future<NutritionPlan?> getLatestNutritionPlan(String deviceId) async {
    try {
      final response = await _supabase
          .from('nutrition_plans')
          .select('*')
          .eq('device_id', deviceId)
          .eq('is_deleted', false)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return NutritionPlan.fromSupabaseJson(response);
      }
      return null;
    } catch (e) {
      print('Error fetching latest nutrition plan: $e');
      return null;
    }
  }

  /// Get a specific nutrition plan by ID
  Future<NutritionPlan?> getNutritionPlan(String deviceId, String planId) async {
    try {
      final response = await _supabase
          .from('nutrition_plans')
          .select('*')
          .eq('device_id', deviceId)
          .eq('plan_id', planId)
          .eq('is_deleted', false)
          .maybeSingle();

      if (response != null) {
        return NutritionPlan.fromSupabaseJson(response);
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
      await _supabase
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

  /// Get nutrition plan statistics for a user
  Future<Map<String, dynamic>> getNutritionPlanStatistics(String deviceId) async {
    try {
      final plans = await getNutritionPlans(deviceId);
      
      if (plans.isEmpty) {
        return {
          'totalPlans': 0,
          'averageDistance': 0.0,
          'averageDuration': 0.0,
          'averagePace': 0.0,
          'averageCarbs': 0.0,
          'averageCalories': 0.0,
        };
      }

      final totalPlans = plans.length;
      final totalCalories = plans.fold<int>(0, (sum, plan) => sum + (plan.totalCalories ?? 0));
      final totalCarbs = plans.fold<int>(0, (sum, plan) => sum + (plan.macroTargets?.carbs ?? 0));

      return {
        'totalPlans': totalPlans,
        'averageDistance': 0.0, // Distance info not stored in plans anymore (Edge Function handles it)
        'averageCalories': totalCalories / totalPlans,
        'averageCarbs': totalCarbs / totalPlans,
      };
    } catch (e) {
      print('Error calculating nutrition plan statistics: $e');
      return {
        'totalPlans': 0,
        'averageDistance': 0.0,
        'averageDuration': 0.0,
        'averagePace': 0.0,
        'averageCarbs': 0.0,
        'averageCalories': 0.0,
      };
    }
  }

  /// Clear all nutrition plans for a user (for testing)
  Future<bool> clearAllNutritionPlans(String deviceId) async {
    try {
      await _supabase
          .from('nutrition_plans')
          .update({'is_deleted': true})
          .eq('device_id', deviceId);

      return true;
    } catch (e) {
      print('Error clearing nutrition plans: $e');
      return false;
    }
  }
}

/// Result class for nutrition plan creation
class CreateNutritionPlanResult {
  final bool success;
  final NutritionPlan? plan;
  final Map<String, dynamic>? calculations;
  final String? message;

  CreateNutritionPlanResult({
    required this.success,
    this.plan,
    this.calculations,
    this.message,
  });
}

/// Riverpod provider for NutritionPlanRepository
final nutritionPlanRepositoryProvider = Provider<NutritionPlanRepository>((ref) {
  return NutritionPlanRepository(Supabase.instance.client);
});
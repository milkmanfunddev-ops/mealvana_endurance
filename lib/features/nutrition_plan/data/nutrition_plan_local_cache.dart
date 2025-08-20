import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/nutrition_plan.dart';
import 'dart:convert';

/// Local cache for nutrition plans using Hive
/// Provides offline access and quick loading of plans
class NutritionPlanLocalCache {
  static const String _boxName = 'nutrition_plans';
  static const String _latestPlanKey = 'latest_plan';
  static const String _allPlansKey = 'all_plans';
  
  late Box _box;
  bool _isInitialized = false;
  
  /// Initialize the cache
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _box = await Hive.openBox(_boxName);
      _isInitialized = true;
    } catch (e) {
      print('Error initializing nutrition plan cache: $e');
      // Try to delete corrupted box and recreate
      await Hive.deleteBoxFromDisk(_boxName);
      _box = await Hive.openBox(_boxName);
      _isInitialized = true;
    }
  }
  
  /// Save the latest nutrition plan
  Future<void> saveLatestPlan(NutritionPlan plan) async {
    if (!_isInitialized) await initialize();
    
    try {
      // Convert plan to JSON and save
      final jsonString = json.encode(plan.toJson());
      await _box.put(_latestPlanKey, jsonString);
      
      // Also update in all plans list
      await _updateAllPlans(plan);
    } catch (e) {
      print('Error saving latest plan to cache: $e');
    }
  }
  
  /// Get the latest cached nutrition plan
  Future<NutritionPlan?> getLatestPlan() async {
    if (!_isInitialized) await initialize();
    
    try {
      final jsonString = _box.get(_latestPlanKey);
      if (jsonString != null) {
        final jsonData = json.decode(jsonString);
        return NutritionPlan.fromJson(jsonData);
      }
    } catch (e) {
      print('Error getting latest plan from cache: $e');
      // Clear corrupted data
      await _box.delete(_latestPlanKey);
    }
    
    return null;
  }
  
  /// Save all nutrition plans
  Future<void> saveAllPlans(List<NutritionPlan> plans) async {
    if (!_isInitialized) await initialize();
    
    try {
      // Convert plans to JSON array
      final jsonList = plans.map((p) => p.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _box.put(_allPlansKey, jsonString);
      
      // Update latest plan if we have any plans
      if (plans.isNotEmpty) {
        await saveLatestPlan(plans.first);
      }
    } catch (e) {
      print('Error saving all plans to cache: $e');
    }
  }
  
  /// Get all cached nutrition plans
  Future<List<NutritionPlan>> getAllPlans() async {
    if (!_isInitialized) await initialize();
    
    try {
      final jsonString = _box.get(_allPlansKey);
      if (jsonString != null) {
        final jsonList = json.decode(jsonString) as List;
        return jsonList.map((json) => NutritionPlan.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error getting all plans from cache: $e');
      // Clear corrupted data
      await _box.delete(_allPlansKey);
    }
    
    return [];
  }
  
  /// Update all plans list with a new/updated plan
  Future<void> _updateAllPlans(NutritionPlan plan) async {
    try {
      final allPlans = await getAllPlans();
      
      // Check if plan already exists
      final existingIndex = allPlans.indexWhere((p) => p.id == plan.id);
      
      if (existingIndex >= 0) {
        // Update existing plan
        allPlans[existingIndex] = plan;
      } else {
        // Add new plan at the beginning
        allPlans.insert(0, plan);
      }
      
      // Save updated list
      final jsonList = allPlans.map((p) => p.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _box.put(_allPlansKey, jsonString);
    } catch (e) {
      print('Error updating all plans in cache: $e');
    }
  }
  
  /// Delete a plan from cache
  Future<void> deletePlan(String planId) async {
    if (!_isInitialized) await initialize();
    
    try {
      final allPlans = await getAllPlans();
      allPlans.removeWhere((p) => p.id == planId);
      await saveAllPlans(allPlans);
      
      // If we deleted the latest plan, update it
      final latestPlan = await getLatestPlan();
      if (latestPlan?.id == planId) {
        if (allPlans.isNotEmpty) {
          await saveLatestPlan(allPlans.first);
        } else {
          await _box.delete(_latestPlanKey);
        }
      }
    } catch (e) {
      print('Error deleting plan from cache: $e');
    }
  }
  
  /// Clear all cached plans
  Future<void> clearCache() async {
    if (!_isInitialized) await initialize();
    
    try {
      await _box.clear();
    } catch (e) {
      print('Error clearing nutrition plan cache: $e');
    }
  }
  
  /// Check if cache has data
  Future<bool> hasCache() async {
    if (!_isInitialized) await initialize();
    
    return _box.containsKey(_latestPlanKey) || _box.containsKey(_allPlansKey);
  }
}

/// Provider for nutrition plan local cache
final nutritionPlanLocalCacheProvider = Provider<NutritionPlanLocalCache>((ref) {
  return NutritionPlanLocalCache();
});
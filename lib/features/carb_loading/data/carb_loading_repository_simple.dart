// import 'dart:convert';
// import 'package:drift/drift.dart';
// import '../../../shared/database/app_database.dart';
// import '../../../shared/services/logging_service.dart';
// import '../domain/carb_loading_plan_simple.dart';

// /// Repository for simplified carb loading plans (carbs-only tracking)
// class CarbLoadingRepositorySimple {
//   final AppDatabase _database;
//   final LoggingService _logger;

//   CarbLoadingRepositorySimple({
//     required AppDatabase database,
//     LoggingService? logger,
//   }) : _database = database,
//         _logger = logger ?? AppLogger.instance;

//   /// Save a carb loading plan
//   Future<void> savePlan(CarbLoadingPlan plan) async {
//     try {
//       await _database.into(_database.carbLoadingSimpleTable).insertOnConflictUpdate(
//         CarbLoadingSimpleTableCompanion.insert(
//           id: plan.id,
//           userId: plan.userId,
//           raceDate: plan.raceDate,
//           raceDistance: plan.raceDistance.value,
//           trainingVolume: plan.trainingVolume.value,
//           dailyCarbTargetG: plan.dailyCarbTargetG,
//           dailyServingsTarget: plan.dailyServingsTarget,
//           bodyWeightKg: plan.bodyWeightKg,
//           carbsPerKgTarget: plan.carbsPerKgTarget,
//           daySelectionsJson: jsonEncode(_daySelectionsToMap(plan.daySelections)),
//           createdAt: plan.createdAt,
//           updatedAt: plan.updatedAt,
//           isActive: Value(plan.isActive),
//         ),
//       );

//       _logger.database('Saved carb loading plan',
//         operation: 'save_plan',
//         data: {
//           'plan_id': plan.id,
//           'user_id': plan.userId,
//           'race_date': plan.raceDate.toIso8601String(),
//           'daily_carb_target': plan.dailyCarbTargetG,
//         }
//       );
//     } catch (e) {
//       _logger.error('Failed to save carb loading plan',
//         context: 'CARB_LOADING_REPOSITORY',
//         error: e
//       );
//       rethrow;
//     }
//   }

//   /// Get current active plan for user
//   Future<CarbLoadingPlan?> getCurrentPlan(String userId) async {
//     try {
//       final query = _database.select(_database.carbLoadingSimpleTable)
//         ..where((p) => p.userId.equals(userId) & p.isActive.equals(true))
//         ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)])
//         ..limit(1);

//       final results = await query.get();
//       if (results.isEmpty) return null;

//       return _entryToPlan(results.first);
//     } catch (e) {
//       _logger.error('Failed to get current plan',
//         context: 'CARB_LOADING_REPOSITORY',
//         error: e
//       );
//       return null;
//     }
//   }

//   /// Get plan by ID
//   Future<CarbLoadingPlan?> getPlanById(String planId) async {
//     try {
//       final query = _database.select(_database.carbLoadingSimpleTable)
//         ..where((p) => p.id.equals(planId));

//       final result = await query.getSingleOrNull();
//       if (result == null) return null;

//       return _entryToPlan(result);
//     } catch (e) {
//       _logger.error('Failed to get plan by ID',
//         context: 'CARB_LOADING_REPOSITORY',
//         error: e
//       );
//       return null;
//     }
//   }

//   /// Get all plans for user
//   Future<List<CarbLoadingPlan>> getAllPlans(String userId) async {
//     try {
//       final query = _database.select(_database.carbLoadingSimpleTable)
//         ..where((p) => p.userId.equals(userId))
//         ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]);

//       final results = await query.get();
//       return results.map(_entryToPlan).toList();
//     } catch (e) {
//       _logger.error('Failed to get all plans',
//         context: 'CARB_LOADING_REPOSITORY',
//         error: e
//       );
//       return [];
//     }
//   }

//   /// Update plan food selections
//   Future<void> updatePlanFoodSelections(String planId, Map<int, DayFoodSelections> daySelections) async {
//     try {
//       await (_database.update(_database.carbLoadingSimpleTable)
//         ..where((p) => p.id.equals(planId))
//       ).write(CarbLoadingSimpleTableCompanion(
//         daySelectionsJson: Value(jsonEncode(_daySelectionsToMap(daySelections))),
//         updatedAt: Value(DateTime.now()),
//       ));

//       _logger.database('Updated plan food selections',
//         operation: 'update_food_selections',
//         data: {
//           'plan_id': planId,
//           'total_days': daySelections.length,
//         }
//       );
//     } catch (e) {
//       _logger.error('Failed to update plan food selections',
//         context: 'CARB_LOADING_REPOSITORY',
//         error: e
//       );
//       rethrow;
//     }
//   }

//   /// Add food to meal
//   Future<void> addFoodToMeal(String planId, int day, String mealName, String foodName) async {
//     try {
//       final plan = await getPlanById(planId);
//       if (plan == null) {
//         throw Exception('Plan not found');
//       }

//       final updatedDaySelections = Map<int, DayFoodSelections>.from(plan.daySelections);
//       final daySelection = updatedDaySelections[day] ?? DayFoodSelections.empty();
//       final meal = daySelection.meals[mealName] ?? MealFoods.empty();

//       final updatedMeal = meal.addFood(foodName);
//       final updatedDaySelection = daySelection.updateMeal(mealName, updatedMeal);
//       updatedDaySelections[day] = updatedDaySelection;

//       await updatePlanFoodSelections(planId, updatedDaySelections);

//       _logger.database('Added food to meal',
//         operation: 'add_food',
//         data: {
//           'plan_id': planId,
//           'day': day,
//           'meal': mealName,
//           'food': foodName,
//         }
//       );
//     } catch (e) {
//       _logger.error('Failed to add food to meal',
//         context: 'CARB_LOADING_REPOSITORY',
//         error: e
//       );
//       rethrow;
//     }
//   }

//   /// Remove food from meal
//   Future<void> removeFoodFromMeal(String planId, int day, String mealName, String foodName) async {
//     try {
//       final plan = await getPlanById(planId);
//       if (plan == null) {
//         throw Exception('Plan not found');
//       }

//       final updatedDaySelections = Map<int, DayFoodSelections>.from(plan.daySelections);
//       final daySelection = updatedDaySelections[day] ?? DayFoodSelections.empty();
//       final meal = daySelection.meals[mealName] ?? MealFoods.empty();

//       final updatedMeal = meal.removeFood(foodName);
//       final updatedDaySelection = daySelection.updateMeal(mealName, updatedMeal);
//       updatedDaySelections[day] = updatedDaySelection;

//       await updatePlanFoodSelections(planId, updatedDaySelections);

//       _logger.database('Removed food from meal',
//         operation: 'remove_food',
//         data: {
//           'plan_id': planId,
//           'day': day,
//           'meal': mealName,
//           'food': foodName,
//         }
//       );
//     } catch (e) {
//       _logger.error('Failed to remove food from meal',
//         context: 'CARB_LOADING_REPOSITORY',
//         error: e
//       );
//       rethrow;
//     }
//   }

//   /// Update food quantity in meal
//   Future<void> updateFoodQuantity(String planId, int day, String mealName, String foodName, int quantity) async {
//     try {
//       final plan = await getPlanById(planId);
//       if (plan == null) {
//         throw Exception('Plan not found');
//       }

//       final updatedDaySelections = Map<int, DayFoodSelections>.from(plan.daySelections);
//       final daySelection = updatedDaySelections[day] ?? DayFoodSelections.empty();
//       final meal = daySelection.meals[mealName] ?? MealFoods.empty();

//       final updatedMeal = meal.updateFoodQuantity(foodName, quantity);
//       final updatedDaySelection = daySelection.updateMeal(mealName, updatedMeal);
//       updatedDaySelections[day] = updatedDaySelection;

//       await updatePlanFoodSelections(planId, updatedDaySelections);

//       _logger.database('Updated food quantity',
//         operation: 'update_quantity',
//         data: {
//           'plan_id': planId,
//           'day': day,
//           'meal': mealName,
//           'food': foodName,
//           'quantity': quantity,
//         }
//       );
//     } catch (e) {
//       _logger.error('Failed to update food quantity',
//         context: 'CARB_LOADING_REPOSITORY',
//         error: e
//       );
//       rethrow;
//     }
//   }

//   /// Delete plan
//   Future<bool> deletePlan(String planId) async {
//     try {
//       final deletedRows = await (_database.delete(_database.carbLoadingSimpleTable)
//         ..where((p) => p.id.equals(planId))
//       ).go();

//       _logger.database('Deleted carb loading plan',
//         operation: 'delete_plan',
//         data: {'plan_id': planId}
//       );

//       return deletedRows > 0;
//     } catch (e) {
//       _logger.error('Failed to delete plan',
//         context: 'CARB_LOADING_REPOSITORY',
//         error: e
//       );
//       return false;
//     }
//   }

//   /// Convert database entry to domain model
//   CarbLoadingPlan _entryToPlan(CarbLoadingSimpleEntry entry) {
//     final daySelectionsMap = _mapToDaySelections(
//       jsonDecode(entry.daySelectionsJson) as Map<String, dynamic>
//     );

//     return CarbLoadingPlan(
//       id: entry.id,
//       userId: entry.userId,
//       raceDate: entry.raceDate,
//       raceDistance: RaceDistance.values.firstWhere(
//         (d) => d.value == entry.raceDistance,
//         orElse: () => RaceDistance.marathon,
//       ),
//       trainingVolume: TrainingVolume.values.firstWhere(
//         (v) => v.value == entry.trainingVolume,
//         orElse: () => TrainingVolume.moderate,
//       ),
//       dailyCarbTargetG: entry.dailyCarbTargetG,
//       dailyServingsTarget: entry.dailyServingsTarget,
//       bodyWeightKg: entry.bodyWeightKg,
//       carbsPerKgTarget: entry.carbsPerKgTarget,
//       daySelections: daySelectionsMap,
//       createdAt: entry.createdAt,
//       updatedAt: entry.updatedAt,
//       isActive: entry.isActive,
//     );
//   }

//   /// Convert day selections to JSON map
//   Map<String, dynamic> _daySelectionsToMap(Map<int, DayFoodSelections> daySelections) {
//     final map = <String, dynamic>{};
//     for (final entry in daySelections.entries) {
//       map[entry.key.toString()] = entry.value.toJson();
//     }
//     return map;
//   }

//   /// Convert JSON map to day selections
//   Map<int, DayFoodSelections> _mapToDaySelections(Map<String, dynamic> map) {
//     final daySelections = <int, DayFoodSelections>{};
//     for (final entry in map.entries) {
//       final day = int.parse(entry.key);
//       daySelections[day] = DayFoodSelections.fromJson(entry.value as Map<String, dynamic>);
//     }
//     return daySelections;
//   }
// }
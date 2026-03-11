import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/nutrition_plan.dart';
import '../domain/food_item_data.dart';
import '../domain/macro_targets.dart' as targets;
import 'food_data_transformation_service.dart';
import '../../activities/domain/brick_metadata.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/app_external_deps.dart';

/// Service for parsing LLM edge function responses into NutritionPlan objects
class LLMResponseParser {
  LLMResponseParser(this.ref);
  final Ref ref;

  FoodDataTransformationService get _transformationService =>
      ref.read(foodDataTransformationServiceProvider);
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  /// Convert LLM response format to our NutritionPlan domain model
  /// Made public to allow reuse for algorithmic fallback responses
  ///
  /// [inputMacroTargets] - Optional MacroTargets from the Adjust Macros screen.
  /// When provided, these values are used directly for section targets instead of
  /// parsing from the edge function response (which may have field name mismatches).
  Future<NutritionPlan> convertLLMResponseToPlan(
    Map<String, dynamic> data,
    String userId, {
    String? activityId,
    targets.MacroTargets? inputMacroTargets,
    BrickMetadata? brickMetadata,
  }) async {
    // Check if this is a brick workout response
    // Primary: edge function returns activity_type: 'brick'
    // Fallback: inputMacroTargets or brickMetadata indicate brick
    final activityType = data['activity_type'] as String?;
    final isBrick = activityType == 'brick' ||
        inputMacroTargets?.activityType == ActivityType.brick ||
        brickMetadata != null;
    if (isBrick) {
      return _convertBrickResponseToPlan(
        data,
        userId,
        activityId: activityId,
        inputMacroTargets: inputMacroTargets,
        brickMetadata: brickMetadata,
      );
    }

    final planData = data['plan'] as Map<String, dynamic>;
    final macroTargets = data['macro_targets'] as Map<String, dynamic>;
    final detailedMessage = data['detailed_message'] as String? ?? 'AI-generated nutrition plan';
    final planId = data['plan_id'] as String? ??
                   'llm-plan-${DateTime.now().millisecondsSinceEpoch}';

    final beforeItems = <FoodItemData>[];
    for (final item in planData['before'] as List<dynamic>) {
      final itemMap = item as Map<String, dynamic>;

      // Use transformation service for proper nutrition calculation
      final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
      beforeItems.add(transformedFoodItem);
    }

    // Validation logging: Track sodium and fluids for before section
    final beforeSodiumTotal = beforeItems.fold<int>(0, (sum, item) => sum + (item.nutritionalInfo?.sodium ?? 0));
    final beforeFluidsTotal = beforeItems.fold<double>(0.0, (sum, item) => sum + (item.nutritionalInfo?.fluids ?? 0.0));

    final duringItems = <FoodItemData>[];
    for (final item in planData['during'] as List<dynamic>) {
      final itemMap = item as Map<String, dynamic>;

      // Use transformation service for proper nutrition calculation
      final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
      duringItems.add(transformedFoodItem);
    }

    // Validation logging: Track sodium and fluids for during section
    final duringSodiumTotal = duringItems.fold<int>(0, (sum, item) => sum + (item.nutritionalInfo?.sodium ?? 0));
    final duringFluidsTotal = duringItems.fold<double>(0.0, (sum, item) => sum + (item.nutritionalInfo?.fluids ?? 0.0));

    final afterItems = <FoodItemData>[];
    for (final item in planData['after'] as List<dynamic>) {
      final itemMap = item as Map<String, dynamic>;

      // Use transformation service for proper nutrition calculation
      final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
      afterItems.add(transformedFoodItem);
    }

    // Validation logging: Track sodium and fluids for after section
    final afterSodiumTotal = afterItems.fold<int>(0, (sum, item) => sum + (item.nutritionalInfo?.sodium ?? 0));
    final afterFluidsTotal = afterItems.fold<double>(0.0, (sum, item) => sum + (item.nutritionalInfo?.fluids ?? 0.0));


    // Calculate total macros from phase targets (using correct field names)
    final preRun = macroTargets['pre_run'] as Map<String, dynamic>;
    final duringRun = macroTargets['during_run'] as Map<String, dynamic>;
    final postRun = macroTargets['post_run'] as Map<String, dynamic>;

    // Use the correct field names that match the edge function response
    final preRunCarbs = (preRun['carbs_g'] as num).toInt();
    final preRunProtein = (preRun['protein_g'] as num).toInt();
    final preRunFat = (preRun['fat_g'] as num).toInt();

    final postRunCarbs = (postRun['carbs_g'] as num).toInt();
    final postRunProtein = (postRun['protein_g'] as num).toInt();
    final postRunFat = (postRun['fat_g'] as num).toInt();

    final duringRunCarbs = (duringRun['carbs_total_g'] as num).toInt();

    // Calculate totals (estimate calories if not provided)
    final totalCarbs = preRunCarbs + duringRunCarbs + postRunCarbs;
    final totalProtein = preRunProtein + postRunProtein;
    final totalFat = preRunFat + postRunFat;
    final totalCalories = (totalCarbs * 4) + (totalProtein * 4) + (totalFat * 9); // Rough calorie calculation

    // Extract macro target values for sodium and fluids
    final preRunSodium = (preRun['sodium_mg'] as num?)?.toInt() ?? 0;
    final duringRunSodium = (duringRun['sodium_total_mg'] as num?)?.toInt() ?? 0;
    final postRunSodium = (postRun['sodium_mg'] as num?)?.toInt() ?? 0;
    final totalTargetSodium = preRunSodium + duringRunSodium + postRunSodium;

    final preRunFluids = (preRun['water_ml'] as num?)?.toDouble() ?? 0.0;
    final duringRunFluids = (duringRun['water_total_ml'] as num?)?.toDouble() ?? 0.0;
    final postRunFluids = (postRun['water_ml'] as num?)?.toDouble() ?? 0.0;
    final totalTargetFluids = preRunFluids + duringRunFluids + postRunFluids;

    // Calculate actual food item totals across all phases
    final totalFoodItemSodium = beforeSodiumTotal + duringSodiumTotal + afterSodiumTotal;
    final totalFoodItemFluids = beforeFluidsTotal + duringFluidsTotal + afterFluidsTotal;
    final totalFoodItemCarbs = beforeItems.fold<int>(0, (sum, item) => sum + (item.nutritionalInfo?.carbs ?? 0)) +
                              duringItems.fold<int>(0, (sum, item) => sum + (item.nutritionalInfo?.carbs ?? 0)) +
                              afterItems.fold<int>(0, (sum, item) => sum + (item.nutritionalInfo?.carbs ?? 0));

    // CRITICAL VALIDATION: Log the discrepancy between macro targets and food item totals
    _logger.error('LLM Response Validation: Food Items vs Macro Targets Comparison',
      context: 'LLMResponseParser',
      data: {
        'macro_targets': {
          'total_sodium_mg': totalTargetSodium,
          'total_fluids_ml': totalTargetFluids,
          'total_carbs_g': totalCarbs,
        },
        'food_items_actual': {
          'total_sodium_mg': totalFoodItemSodium,
          'total_fluids_ml': totalFoodItemFluids,
          'total_carbs_g': totalFoodItemCarbs,
        },
        'discrepancies': {
          'sodium_difference_mg': totalFoodItemSodium - totalTargetSodium,
          'fluids_difference_ml': totalFoodItemFluids - totalTargetFluids,
          'carbs_difference_g': totalFoodItemCarbs - totalCarbs,
        },
        'percentage_match': {
          'sodium_percentage': totalTargetSodium > 0 ? (totalFoodItemSodium / totalTargetSodium * 100).round() : 0,
          'fluids_percentage': totalTargetFluids > 0 ? (totalFoodItemFluids / totalTargetFluids * 100).round() : 0,
          'carbs_percentage': totalCarbs > 0 ? (totalFoodItemCarbs / totalCarbs * 100).round() : 0,
        }
      },
    );

    // Use inputMacroTargets directly when available (from Adjust Macros screen)
    // This ensures the targets displayed match exactly what the user saw/edited
    // Fall back to parsing from response only when inputMacroTargets is not provided
    final preRunSodiumTarget = inputMacroTargets?.preRun.sodiumMg ??
        (preRun['sodium_mg'] as num? ?? 200).toDouble();
    final preRunFluidsTarget = inputMacroTargets?.preRun.fluidsMl ??
        (preRun['water_ml'] as num? ?? 500).toDouble();
    final preRunCarbsTarget = inputMacroTargets?.preRun.carbsG ?? preRunCarbs.toDouble();
    final preRunProteinTarget = inputMacroTargets?.preRun.proteinG ?? preRunProtein.toDouble();
    final preRunFatTarget = inputMacroTargets?.preRun.fatCapG ??
        (preRun['fat_g'] as num? ?? 5).toDouble();

    final duringRunSodiumTarget = inputMacroTargets?.duringRun.sodiumTotalMg ??
        (duringRun['sodium_total_mg'] as num? ?? 250).toDouble();
    final duringRunFluidsTarget = inputMacroTargets?.duringRun.fluidTotalMl ??
        (duringRun['water_total_ml'] as num? ?? 600).toDouble();
    final duringRunCarbsTarget = inputMacroTargets?.duringRun.carbTotalG ?? duringRunCarbs.toDouble();

    final postRunSodiumTarget = inputMacroTargets?.postRun.sodiumMg ??
        (postRun['sodium_mg'] as num? ?? 300).toDouble();
    final postRunFluidsTarget = inputMacroTargets?.postRun.fluidsMl ??
        (postRun['water_ml'] as num?)?.toDouble() ?? (duringRunFluidsTarget * 1.25);
    final postRunCarbsTarget = inputMacroTargets?.postRun.carbsG ?? postRunCarbs.toDouble();
    final postRunProteinTarget = inputMacroTargets?.postRun.proteinG ?? postRunProtein.toDouble();

    // Get activity type from macro targets, defaulting to running
    final planActivityType = inputMacroTargets?.activityType ?? ActivityType.running;

    // Create the nutrition plan
    final plan = NutritionPlan(
      id: planId,
      name: 'AI-Generated Nutrition Plan',
      totalCalories: totalCalories,
      activityId: activityId, // Link to calendar activity
      sections: [
        PlanSection(
          id: 'before-run',
          title: planActivityType.getSectionTitle('before'),
          subtitle: '${preRunCarbsTarget.round()}g carbs, ${preRunProteinTarget.round()}g protein, ${preRunSodiumTarget.round()}mg sodium',
          timing: 'Before',
          foodItems: beforeItems,
          carbsTarget: preRunCarbsTarget,
          proteinTarget: preRunProteinTarget,
          fatTarget: preRunFatTarget,
          sodiumTarget: preRunSodiumTarget,
          fluidsTarget: preRunFluidsTarget,
        ),
        PlanSection(
          id: 'during-run',
          title: planActivityType.getSectionTitle('during'),
          subtitle: 'Total: ${duringRunCarbsTarget.round()}g carbs, ${duringRunFluidsTarget.round()}ml fluids',
          timing: 'During',
          foodItems: duringItems,
          carbsTarget: duringRunCarbsTarget,
          proteinTarget: 0.0,
          fatTarget: 0.0,
          sodiumTarget: duringRunSodiumTarget,
          fluidsTarget: duringRunFluidsTarget,
        ),
        PlanSection(
          id: 'after-run',
          title: planActivityType.getSectionTitle('after'),
          subtitle: 'Recovery (${postRunCarbsTarget.round()}g carbs, ${postRunProteinTarget.round()}g protein)',
          timing: 'Within 30min',
          foodItems: afterItems,
          carbsTarget: postRunCarbsTarget,
          proteinTarget: postRunProteinTarget,
          fatTarget: (postRun['fat_g'] as num? ?? 10).toDouble(),
          sodiumTarget: postRunSodiumTarget,
          fluidsTarget: postRunFluidsTarget,
        ),
      ],
      macroTargets: PlanMacroSummary(
        calories: totalCalories,
        carbs: totalCarbs,
        protein: totalProtein,
        fat: totalFat,
        sodium: (duringRun['sodium_total_mg'] as num?)?.toInt(),
        fluids: (duringRun['water_total_ml'] as num?)?.toInt(),
        // Store phase-specific data in ranges for display (using adjusted values)
        carbsRange: 'Pre: ${preRunCarbs}g | During: ${duringRunCarbs}g total | Post: ${postRunCarbs}g',
        proteinRange: 'Pre: ${preRunProtein}g | Post: ${postRunProtein}g',
        fatRange: 'Pre: ${preRunFat}g | Post: ${postRunFat}g',
      ),
      notes: detailedMessage, // Store only the detailed message
      createdAt: DateTime.now(),
    );

    _logger.nutritionPlan('Nutrition plan creation completed',
      planId: plan.id,
      data: {
        'totalFoodItems': beforeItems.length + duringItems.length + afterItems.length,
        'beforeItems': beforeItems.length,
        'duringItems': duringItems.length,
        'afterItems': afterItems.length,
      },
    );

    return plan;
  }

  /// Convert brick workout response to NutritionPlan
  /// Handles the multi-phase structure: before, during_segments, transitions, after
  Future<NutritionPlan> _convertBrickResponseToPlan(
    Map<String, dynamic> data,
    String userId, {
    String? activityId,
    targets.MacroTargets? inputMacroTargets,
    BrickMetadata? brickMetadata,
  }) async {
    final planData = data['plan'] as Map<String, dynamic>;
    final detailedMessage = data['detailed_message'] as String? ?? 'Brick workout nutrition plan';
    final planId = data['plan_id'] as String? ??
                   'brick-plan-${DateTime.now().millisecondsSinceEpoch}';

    final sections = <PlanSection>[];

    // Parse per-segment and per-transition macro targets from the edge function response
    // The edge function passes through macro_targets.phases which contains:
    // - during_segments: [{segment_order, carbs_g, sodium_mg, water_ml}, ...]
    // - transitions: [{transition_name, carbs_g, sodium_mg, water_ml}, ...]
    final macroTargetsData = data['macro_targets'] as Map<String, dynamic>?;
    final phasesTargets = macroTargetsData?['phases'] as Map<String, dynamic>?;
    final segmentTargetsList = phasesTargets?['during_segments'] as List<dynamic>? ?? [];
    final transitionTargetsList = phasesTargets?['transitions'] as List<dynamic>? ?? [];

    // Build lookup maps for quick access by segment order / transition name
    final segmentTargetsMap = <int, Map<String, dynamic>>{};
    for (final seg in segmentTargetsList) {
      if (seg is Map<String, dynamic>) {
        final order = seg['segment_order'] as int?;
        if (order != null) {
          segmentTargetsMap[order] = seg;
        }
      }
    }

    final transitionTargetsMap = <String, Map<String, dynamic>>{};
    for (final trans in transitionTargetsList) {
      if (trans is Map<String, dynamic>) {
        final name = trans['transition_name'] as String?;
        if (name != null) {
          transitionTargetsMap[name] = trans;
        }
      }
    }

    // 1. Before section
    final beforeItems = <FoodItemData>[];
    final beforeList = planData['before'] as List<dynamic>? ?? [];
    for (final item in beforeList) {
      final itemMap = item as Map<String, dynamic>;
      final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
      beforeItems.add(transformedFoodItem);
    }
    sections.add(PlanSection(
      id: 'before',
      title: 'Before Brick',
      subtitle: '1-4 hours before your workout',
      foodItems: beforeItems,
      carbsTarget: inputMacroTargets?.preRun.carbsG,
      proteinTarget: inputMacroTargets?.preRun.proteinG,
      sodiumTarget: inputMacroTargets?.preRun.sodiumMg,
      fluidsTarget: inputMacroTargets?.preRun.fluidsMl,
    ));

    // 2. During segments (keyed by segment order: "1", "2", "3")
    final duringSegmentsData = planData['during_segments'] as Map<String, dynamic>? ?? {};

    // Build sport name map from macroTargets.brickSegments if available,
    // falling back to brickMetadata.segments for sport name resolution
    final sportNameMap = <int, String>{};
    if (inputMacroTargets?.brickSegments != null) {
      for (final segment in inputMacroTargets!.brickSegments!) {
        sportNameMap[segment.order] = _getSportDisplayName(segment.sport);
      }
    }
    if (sportNameMap.isEmpty && brickMetadata != null) {
      for (final segment in brickMetadata.segments) {
        sportNameMap[segment.order] = _getSportDisplayName(segment.sport);
      }
    }

    int segmentIndex = 0;
    for (final entry in duringSegmentsData.entries) {
      final segmentOrder = entry.key;
      final segmentItems = entry.value as List<dynamic>? ?? [];

      final foodItems = <FoodItemData>[];
      for (final item in segmentItems) {
        final itemMap = item as Map<String, dynamic>;
        final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
        foodItems.add(transformedFoodItem);
      }

      // Use actual sport name from segments, or fallback to generic name
      final orderInt = int.tryParse(segmentOrder) ?? (segmentIndex + 1);
      final sportName = sportNameMap[orderInt] ?? 'Segment $segmentOrder';

      // Look up per-segment macro targets from the edge function response
      final segTargets = segmentTargetsMap[orderInt];

      sections.add(PlanSection(
        id: 'during_segment_$segmentOrder',
        title: 'During $sportName',
        subtitle: null,
        foodItems: foodItems,
        carbsTarget: segTargets != null ? (segTargets['carbs_g'] as num?)?.toDouble() : null,
        sodiumTarget: segTargets != null ? (segTargets['sodium_mg'] as num?)?.toDouble() : null,
        fluidsTarget: segTargets != null ? (segTargets['water_ml'] as num?)?.toDouble() : null,
      ));

      // Add transition after each segment (except the last)
      final transitionsData = planData['transitions'] as Map<String, dynamic>? ?? {};
      final transitionKey = 'T${segmentIndex + 1}';
      if (transitionsData.containsKey(transitionKey)) {
        final transitionItems = transitionsData[transitionKey] as List<dynamic>? ?? [];
        final transitionFoodItems = <FoodItemData>[];
        for (final item in transitionItems) {
          final itemMap = item as Map<String, dynamic>;
          final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
          transitionFoodItems.add(transformedFoodItem);
        }

        // Look up per-transition macro targets from the edge function response
        final transTargets = transitionTargetsMap[transitionKey];

        sections.add(PlanSection(
          id: transitionKey,
          title: 'Transition ($transitionKey)',
          subtitle: 'Quick refuel between segments',
          foodItems: transitionFoodItems,
          carbsTarget: transTargets != null ? (transTargets['carbs_g'] as num?)?.toDouble() : null,
          sodiumTarget: transTargets != null ? (transTargets['sodium_mg'] as num?)?.toDouble() : null,
          fluidsTarget: transTargets != null ? (transTargets['water_ml'] as num?)?.toDouble() : null,
        ));
      }

      segmentIndex++;
    }

    // 3. After section
    final afterItems = <FoodItemData>[];
    final afterList = planData['after'] as List<dynamic>? ?? [];
    for (final item in afterList) {
      final itemMap = item as Map<String, dynamic>;
      final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
      afterItems.add(transformedFoodItem);
    }
    sections.add(PlanSection(
      id: 'after',
      title: 'After Brick',
      subtitle: 'Within 30-60 minutes post-workout',
      foodItems: afterItems,
      carbsTarget: inputMacroTargets?.postRun.carbsG,
      proteinTarget: inputMacroTargets?.postRun.proteinG,
      sodiumTarget: inputMacroTargets?.postRun.sodiumMg,
      fluidsTarget: inputMacroTargets?.postRun.fluidsMl,
    ));

    // Calculate total calories from food items
    int totalCalories = 0;

    for (final section in sections) {
      for (final food in section.foodItems) {
        if (food.nutritionalInfo != null) {
          totalCalories += food.nutritionalInfo!.calories ?? 0;
        }
      }
    }

    return NutritionPlan(
      id: planId,
      name: 'Brick Workout Nutrition Plan',
      sections: sections,
      totalCalories: totalCalories,
      notes: detailedMessage,
      activityId: activityId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Get display name for a sport type
  String _getSportDisplayName(String sport) {
    switch (sport) {
      case 'swimming':
        return 'Swim';
      case 'cycling':
        return 'Bike';
      case 'running':
        return 'Run';
      default:
        return sport.substring(0, 1).toUpperCase() + sport.substring(1);
    }
  }
}

/// Provider for LLMResponseParser
final llmResponseParserProvider = Provider<LLMResponseParser>((ref) {
  return LLMResponseParser(ref);
});

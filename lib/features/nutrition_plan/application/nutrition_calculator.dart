import '../domain/nutrition_plan.dart';
import '../domain/food_item_data.dart';
import '../../auth/domain/user_preferences.dart';
import '../data/food_database.dart';
import '../domain/food_item.dart';

/// Service for calculating nutrition requirements for endurance athletes
/// Based on evidence-based research documented in docs/business_logic/nutrition_algorithms.md
class NutritionCalculator {
  /// Calculate carbohydrate requirements per hour
  /// 
  /// Formula based on duration and body weight:
  /// - Short events (<3 hours): 30-60g carbs/hour
  /// - Long events (3+ hours): 60-90g carbs/hour
  /// - Body weight adjustments: +5g for >180lbs, -5g for <140lbs
  static double calculateCarbsPerHour(double durationHours, double bodyWeightLbs) {
    // Base carb rate based on duration
    double baseCarbs;
    if (durationHours < 3.0) {
      baseCarbs = 45; // Middle of 30-60g range
    } else {
      baseCarbs = 75; // Middle of 60-90g range
    }
    
    // Body weight adjustments
    if (bodyWeightLbs > 180) {
      baseCarbs += 5;
    } else if (bodyWeightLbs < 140) {
      baseCarbs -= 5;
    }
    
    return baseCarbs.clamp(30, 90); // Keep within safe ranges
  }

  /// Calculate sodium requirements per hour
  /// 
  /// Formula based on sweat rate and duration:
  /// - Standard recommendation: 200-500mg sodium per hour
  /// - High sweat rate athletes: 500-700mg per hour
  /// - Default target: 400mg sodium per hour (middle range)
  static double calculateSodiumPerHour(double durationHours, bool runsWithWaterBottle) {
    double baseSodium = 400; // mg per hour
    
    // Adjustment for longer events (more sweat loss)
    if (durationHours > 3.0) {
      baseSodium += 100;
    }
    
    // Adjustment for hydration habits (proxy for sweat rate awareness)
    if (!runsWithWaterBottle) {
      baseSodium += 50; // May be a heavier sweater who needs water bottle
    }
    
    return baseSodium.clamp(200, 700); // Keep within recommended ranges
  }

  /// Calculate fluid requirements per hour
  /// 
  /// Formula based on body weight and duration:
  /// - Standard recommendation: 400-800mL (13-27 fl oz) per hour
  /// - Target range: 16-24 fl oz per hour for most athletes
  /// - Body weight adjustment: Larger athletes need more fluids
  static double calculateFluidsPerHour(double bodyWeightLbs, double durationHours) {
    // Base fluid requirement in fl oz
    double baseFluidOz = 20; // Middle of 13-27 oz range
    
    // Body weight adjustment
    if (bodyWeightLbs > 180) {
      baseFluidOz += 3;
    } else if (bodyWeightLbs < 140) {
      baseFluidOz -= 2;
    }
    
    // Longer events may need slightly more due to cumulative losses
    if (durationHours > 4.0) {
      baseFluidOz += 2;
    }
    
    return baseFluidOz.clamp(13, 27); // Keep within research recommendations
  }

  /// Main nutrition plan calculation
  /// 
  /// Takes user profile and run parameters to generate complete nutrition plan
  static NutritionPlan calculateNutritionPlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
    required UserProfile userProfile,
    String? planId,
    List<String>? likedFoods,
  }) {
    // Calculate total duration
    double durationHours = (distanceMiles * paceMinutesPerMile) / 60.0;
    
    // DEBUG: Print calculation details
    print('🏃‍♀️ NUTRITION CALCULATOR DEBUG:');
    print('📏 Distance: ${distanceMiles} miles');
    print('⏱️ Pace: ${paceMinutesPerMile} min/mile');
    print('🕐 Duration: ${durationHours.toStringAsFixed(1)} hours');
    print('👤 User weight: ${userProfile.weightPounds} lbs');
    print('💧 Runs with water: ${userProfile.runsWithWaterBottle}');
    print('❤️ Liked foods: ${likedFoods?.length ?? 0} foods');
    
    // Calculate hourly requirements
    double carbsPerHour = calculateCarbsPerHour(durationHours, userProfile.weightPounds);
    double sodiumPerHour = calculateSodiumPerHour(durationHours, userProfile.runsWithWaterBottle);
    double fluidsPerHour = calculateFluidsPerHour(userProfile.weightPounds, durationHours);
    
    // DEBUG: Print nutritional requirements
    print('🍞 Carbs per hour: ${carbsPerHour.toStringAsFixed(1)}g');
    print('🧂 Sodium per hour: ${sodiumPerHour.toStringAsFixed(1)}mg');
    print('💧 Fluids per hour: ${fluidsPerHour.toStringAsFixed(1)}oz');
    
    // Calculate total requirements
    double totalCarbs = carbsPerHour * durationHours;
    
    // Create the new nutrition plan structure with sections
    final plan = NutritionPlan(
      id: planId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Personalized Nutrition Plan',
      totalCalories: (totalCarbs * 4).round(), // Rough estimation: 4 calories per carb gram
      notes: 'Plan generated for ${distanceMiles.toStringAsFixed(1)} miles at ${paceMinutesPerMile.toStringAsFixed(1)} min/mile pace',
      macroTargets: MacroTargets(
        calories: (totalCarbs * 4).round(),
        carbs: totalCarbs.round(),
        protein: (totalCarbs * 0.1).round(), // Rough 10% protein
        fat: (totalCarbs * 0.05).round(), // Rough 5% fat
        carbsRange: '85-90%',
        proteinRange: '5-10%',
        fatRange: '5-10%',
      ),
      sections: _createPlanSections(
        carbsPerHour: carbsPerHour,
        sodiumPerHour: sodiumPerHour, 
        fluidsPerHour: fluidsPerHour,
        durationHours: durationHours,
        userProfile: userProfile,
        likedFoods: likedFoods ?? [],
      ),
    );
    
    // DEBUG: Print the created plan details
    print('📋 CREATED PLAN:');
    print('🆔 Plan ID: ${plan.id}');
    print('📊 Sections: ${plan.sections.length}');
    for (var i = 0; i < plan.sections.length; i++) {
      final section = plan.sections[i];
      print('📂 Section ${i + 1}: ${section.title} (${section.foodItems.length} foods)');
      for (var j = 0; j < section.foodItems.length; j++) {
        final food = section.foodItems[j];
        print('   🍎 ${food.name}: ${food.quantity} (${food.nutritionalInfo?.carbs ?? 0}g carbs)');
      }
    }
    
    return plan;
  }

  /// Calculate pre-run nutrition timing and requirements
  /// 
  /// Based on timing guidelines:
  /// - 1-3 hours before: 1-4g carbs per kg body weight
  /// - Focus on easily digestible carbs
  static Map<String, dynamic> calculatePreRunNutrition(UserProfile userProfile, double durationHours) {
    // Convert weight from lbs to kg
    double bodyWeightKg = userProfile.weightPounds * 0.453592;
    
    // Calculate carb needs: 1-4g per kg body weight
    double preRunCarbsMin = bodyWeightKg * 1.0;
    double preRunCarbsMax = bodyWeightKg * 4.0;
    double preRunCarbsTarget = bodyWeightKg * 2.5; // Middle range
    
    return {
      'carbsMinGrams': preRunCarbsMin,
      'carbsMaxGrams': preRunCarbsMax,
      'carbsTargetGrams': preRunCarbsTarget,
      'timingMinutes': durationHours > 2 ? -180 : -120, // 3 hours for long runs, 2 for shorter
      'recommendations': [
        'Focus on easily digestible carbohydrates',
        'Avoid high fiber, high fat, or new foods',
        'Include small amount of caffeine if desired',
      ],
    };
  }

  /// Calculate post-run recovery nutrition
  /// 
  /// Based on recovery guidelines:
  /// - Carbohydrates: 1-1.2g per kg body weight
  /// - Protein: 0.25-0.3g per kg body weight  
  /// - Fluids: 1.2-1.5L per kg body weight lost
  static Map<String, dynamic> calculatePostRunNutrition(UserProfile userProfile) {
    // Convert weight from lbs to kg
    double bodyWeightKg = userProfile.weightPounds * 0.453592;
    
    double postRunCarbs = bodyWeightKg * 1.1; // Middle of 1-1.2g range
    double postRunProtein = bodyWeightKg * 0.275; // Middle of 0.25-0.3g range
    
    return {
      'carbsGrams': postRunCarbs,
      'proteinGrams': postRunProtein,
      'fluidReplacement': 'Drink 1.2-1.5L per kg of body weight lost',
      'timingMinutes': 30, // Within 30-60 minutes
      'recommendations': [
        'Consume within 30-60 minutes post-run',
        'Combine carbohydrates with protein',
        'Prioritize hydration and electrolyte replacement',
      ],
    };
  }

  /// Helper method to create plan sections with foods based on user preferences
  static List<PlanSection> _createPlanSections({
    required double carbsPerHour,
    required double sodiumPerHour,
    required double fluidsPerHour,
    required double durationHours,
    required UserProfile userProfile,
    required List<String> likedFoods,
  }) {
    // Calculate nutrition needs
    final bodyWeightKg = userProfile.weightPounds * 0.453592;
    final preRunCarbsTarget = bodyWeightKg * 2.5; // Middle range
    
    // Get preferred foods from database
    final allFoods = FoodDatabase.getAllFoods();
    final preRunFoods = _selectFoodsForSection(allFoods, likedFoods, FoodCategory.preRun, preRunCarbsTarget);
    final duringRunFoods = _selectFoodsForSection(allFoods, likedFoods, FoodCategory.duringRun, carbsPerHour * durationHours);
    final postRunFoods = _selectFoodsForSection(allFoods, likedFoods, FoodCategory.postRun, bodyWeightKg * 1.1);

    return [
      PlanSection(
        id: 'before-run',
        title: 'Before Run',
        subtitle: '2-3 hours pre-run',
        timing: '2-3h',
        foodItems: preRunFoods,
      ),
      PlanSection(
        id: 'during-run',
        title: 'During Run',
        subtitle: 'Every 45-60 minutes',
        timing: '45-60min',
        foodItems: duringRunFoods,
      ),
      PlanSection(
        id: 'after-run',
        title: 'After Run',
        subtitle: 'Within 30 minutes',
        timing: '30min',
        foodItems: postRunFoods,
      ),
    ];
  }

  /// Select foods for a specific section based on user preferences and nutritional needs
  static List<FoodItemData> _selectFoodsForSection(
    List<FoodItem> allFoods,
    List<String> likedFoods,
    FoodCategory category,
    double carbTarget,
  ) {
    print('🎯 FOOD SELECTION for ${category.name}:');
    print('📊 Target carbs: ${carbTarget.toStringAsFixed(1)}g');
    print('❤️ User liked foods: $likedFoods');
    
    // Filter foods by category
    final categoryFoods = allFoods.where((food) => food.category == category).toList();
    print('📂 Available ${category.name} foods: ${categoryFoods.map((f) => f.id).toList()}');
    
    // First: Look for liked foods in this category
    final preferredInCategory = categoryFoods.where((food) => likedFoods.contains(food.id)).toList();
    
    // Second: If no liked foods in this category, get liked foods from ANY category
    final allLikedFoods = allFoods.where((food) => likedFoods.contains(food.id)).toList();
    final likedFromOtherCategories = allLikedFoods.where((food) => food.category != category).toList();
    
    // Combine: preferred foods in category first, then liked foods from other categories
    final allPreferredFoods = [...preferredInCategory, ...likedFromOtherCategories];
    
    // Other foods in this category (not liked)
    final otherFoods = categoryFoods.where((food) => !likedFoods.contains(food.id)).toList();
    
    print('✅ Liked foods in ${category.name}: ${preferredInCategory.map((f) => f.id).toList()}');
    print('💝 Liked foods from other categories: ${likedFromOtherCategories.map((f) => '${f.id}(${f.category.name})').toList()}');
    print('⚪ Other ${category.name} foods: ${otherFoods.map((f) => f.id).toList()}');
    
    // Combine preferred foods first, then others
    final orderedFoods = [...allPreferredFoods, ...otherFoods];
    
    // Select foods to meet carb target - allow unlimited quantities for ultra-distances
    final selectedFoods = <FoodItemData>[];
    double totalCarbs = 0;
    
    // For during-run: prioritize user preferences first, then calculate realistic quantities
    if (category == FoodCategory.duringRun) {
      // Try to meet carb target using only preferred foods first
      if (allPreferredFoods.isNotEmpty) {
        print('🎯 Trying to meet target with preferred foods only...');
        double preferredCarbs = 0;
        
        for (final food in allPreferredFoods) {
          final maxFromThisFood = carbTarget * 0.8; // Max 80% from any one food for variety
          final quantityNeeded = (maxFromThisFood / food.nutrition.carbs).clamp(1.0, 100.0);
          
          selectedFoods.add(_convertToFoodItemData(food, quantityNeeded));
          preferredCarbs += food.nutrition.carbs * quantityNeeded;
          totalCarbs += food.nutrition.carbs * quantityNeeded;
          
          print('❤️ ${food.name}: ${quantityNeeded.toStringAsFixed(0)} ${food.servingUnit} (${(food.nutrition.carbs * quantityNeeded).toStringAsFixed(0)}g carbs)');
          
          if (preferredCarbs >= carbTarget * 0.8) break; // Got enough from preferences
        }
        
        // If preferred foods don't meet 80% of target, supplement with other foods
        if (totalCarbs < carbTarget * 0.8) {
          print('⚪ Need to supplement with non-preferred foods...');
          final remainingTarget = carbTarget - totalCarbs;
          
          for (final food in otherFoods.take(2)) { // Limit to 2 additional foods
            final quantityNeeded = (remainingTarget * 0.5 / food.nutrition.carbs).clamp(1.0, 50.0);
            selectedFoods.add(_convertToFoodItemData(food, quantityNeeded));
            totalCarbs += food.nutrition.carbs * quantityNeeded;
            
            print('⚪ ${food.name}: ${quantityNeeded.toStringAsFixed(0)} ${food.servingUnit} (${(food.nutrition.carbs * quantityNeeded).toStringAsFixed(0)}g carbs)');
            
            if (totalCarbs >= carbTarget * 0.9) break;
          }
        }
      } else {
        // No preferred foods in this category, use standard algorithm
        print('⚪ No preferred foods in category, using defaults...');
        final gels = otherFoods.where((f) => f.id.contains('gel')).toList();
        final chews = otherFoods.where((f) => f.id.contains('chew')).toList();
        final drinks = otherFoods.where((f) => f.id.contains('drink')).toList();
        
        if (gels.isNotEmpty) {
          final gel = gels.first;
          final gelsNeeded = (carbTarget * 0.6 / gel.nutrition.carbs);
          selectedFoods.add(_convertToFoodItemData(gel, gelsNeeded));
          totalCarbs += gel.nutrition.carbs * gelsNeeded;
          print('🍯 ${gel.name}: ${gelsNeeded.toStringAsFixed(0)} packets (${(gel.nutrition.carbs * gelsNeeded).toStringAsFixed(0)}g carbs)');
        }
        
        if (chews.isNotEmpty && totalCarbs < carbTarget * 0.8) {
          final chew = chews.first;
          final chewsNeeded = ((carbTarget - totalCarbs) * 0.5 / chew.nutrition.carbs);
          selectedFoods.add(_convertToFoodItemData(chew, chewsNeeded));
          totalCarbs += chew.nutrition.carbs * chewsNeeded;
          print('🍭 ${chew.name}: ${chewsNeeded.toStringAsFixed(0)} pieces (${(chew.nutrition.carbs * chewsNeeded).toStringAsFixed(0)}g carbs)');
        }
      }
    } else {
      // For pre-run and post-run: normal portion calculations
      for (final food in orderedFoods.take(3)) {
        final remainingCarbs = carbTarget - totalCarbs;
        if (remainingCarbs <= 0) break;
        
        final quantity = remainingCarbs / food.nutrition.carbs;
        final reasonableQuantity = quantity.clamp(0.5, 4.0); // Keep portions reasonable
        
        selectedFoods.add(_convertToFoodItemData(food, reasonableQuantity));
        totalCarbs += food.nutrition.carbs * reasonableQuantity;
        
        if (totalCarbs >= carbTarget * 0.9) break; // Stop when we reach 90% of target
      }
    }
    
    print('✅ Total carbs selected: ${totalCarbs.toStringAsFixed(1)}g (target: ${carbTarget.toStringAsFixed(1)}g)');
    return selectedFoods.isNotEmpty ? selectedFoods : [_getDefaultFoodForCategory(category)];
  }

  /// Calculate optimal quantity to meet nutritional needs
  static double _calculateOptimalQuantity(FoodItem food, double carbTarget, double currentCarbs) {
    final remainingCarbs = carbTarget - currentCarbs;
    if (remainingCarbs <= 0) return 0;
    
    final baseQuantity = remainingCarbs / food.nutrition.carbs;
    return (baseQuantity * food.servingAmount).clamp(0.5, 3.0); // Keep portions reasonable
  }

  /// Convert FoodItem to FoodItemData for plan display
  static FoodItemData _convertToFoodItemData(FoodItem food, double quantity) {
    final adjustedNutrition = NutritionalInfo(
      calories: (food.nutrition.calories * quantity).round(),
      carbs: (food.nutrition.carbs * quantity).round(),
      protein: (food.nutrition.protein * quantity).round(),
      fat: (food.nutrition.fat * quantity).round(),
      sodium: food.nutrition.sodium != null ? (food.nutrition.sodium! * quantity).round() : null,
    );

    return FoodItemData(
      id: food.id,
      name: food.name,
      quantity: '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} ${food.servingUnit}',
      iconPath: 'assets/images/${food.id}.png',
      description: food.additionalInfo ?? food.description,
      nutritionalInfo: adjustedNutrition,
    );
  }

  /// Get default food for category when no preferences match
  static FoodItemData _getDefaultFoodForCategory(FoodCategory category) {
    switch (category) {
      case FoodCategory.preRun:
        return FoodItemData(
          id: 'oatmeal',
          name: 'Oatmeal',
          quantity: '1 cup',
          iconPath: 'assets/images/oatmeal.png',
          description: 'Complex carbohydrates for sustained energy',
          nutritionalInfo: const NutritionalInfo(calories: 150, carbs: 27, protein: 5, fat: 3),
        );
      case FoodCategory.duringRun:
        return FoodItemData(
          id: 'gels',
          name: 'Energy Gels',
          quantity: '2',
          iconPath: 'assets/images/gels.png',
          description: 'Fast-absorbing energy',
          nutritionalInfo: const NutritionalInfo(calories: 200, carbs: 50, protein: 0, fat: 0),
        );
      case FoodCategory.postRun:
        return FoodItemData(
          id: 'recovery-drink',
          name: 'Recovery Drink',
          quantity: '1 serving',
          iconPath: 'assets/images/protein_bar.png',
          description: 'Protein and carbs for recovery',
          nutritionalInfo: const NutritionalInfo(calories: 200, carbs: 30, protein: 15, fat: 3),
        );
    }
  }

  /// Safety check for nutrition plan values
  /// 
  /// Ensures all calculated values are within safe limits
  static bool validateNutritionPlan(NutritionPlan plan) {
    // Check for valid plan structure
    if (plan.sections.isEmpty) return false;
    if (plan.macroTargets == null) return false;
    
    // Check macro targets are reasonable
    final macros = plan.macroTargets!;
    if (macros.calories <= 0) return false;
    if (macros.carbs <= 0) return false;
    
    return true;
  }

  /// Get nutrition recommendations based on plan values
  /// 
  /// Provides user-friendly feedback about their nutrition plan
  static List<String> getNutritionRecommendations(NutritionPlan plan, UserProfile userProfile) {
    List<String> recommendations = [];
    
    // General recommendations based on plan structure
    if (plan.sections.length >= 3) {
      recommendations.add('Follow the timing guidelines for optimal performance');
    }
    
    // Macro-based recommendations
    if (plan.macroTargets != null) {
      final macros = plan.macroTargets!;
      
      if (macros.carbs > 150) {
        recommendations.add('High carb plan - practice during training to avoid GI issues');
      }
      
      if (macros.calories > 1000) {
        recommendations.add('High calorie plan - break into smaller portions throughout');
      }
    }
    
    // Section-specific recommendations
    final duringSection = plan.sections.where((s) => s.title.contains('During')).firstOrNull;
    if (duringSection != null && duringSection.foodItems.isNotEmpty) {
      recommendations.add('Start fueling within the first 30-45 minutes of your run');
    }
    
    // Hydration recommendations
    recommendations.add('Monitor hydration levels and adjust intake based on conditions');
    
    // Personal recommendations
    if (!userProfile.runsWithWaterBottle) {
      recommendations.add('Consider carrying a water bottle for adequate hydration');
    }
    
    return recommendations;
  }

  /// Legacy method for backward compatibility
  @Deprecated('Use calculateNutritionPlan with RunParameters instead') 
  static NutritionPlan calculateNutritionPlanLegacy({
    required double distanceMiles,
    required double paceMinutesPerMile,
    required UserProfile userProfile,
    String? planId,
  }) {
    // For now, use simplified calculation until UI is updated
    double durationHours = (distanceMiles * paceMinutesPerMile) / 60.0;
    double carbsPerHour = durationHours < 3.0 ? 45 : 75;
    double totalCarbs = carbsPerHour * durationHours;
    
    return NutritionPlan(
      id: planId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Personalized Nutrition Plan',
      totalCalories: (totalCarbs * 4).round(),
      notes: 'Legacy plan for ${distanceMiles.toStringAsFixed(1)} miles',
      macroTargets: MacroTargets(
        calories: (totalCarbs * 4).round(),
        carbs: totalCarbs.round(),
        protein: (totalCarbs * 0.1).round(),
        fat: (totalCarbs * 0.05).round(),
        carbsRange: '85-90%',
        proteinRange: '5-10%',
        fatRange: '5-10%',
      ),
      sections: [],
    );
  }
}
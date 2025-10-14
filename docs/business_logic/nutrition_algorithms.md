# Nutrition Calculation Algorithms

## Overview
Evidence-based nutrition calculation formulas for endurance athletes, specifically for running events. These algorithms are implemented in the Mealvana Endurance app using an **AI-first architecture** with intelligent fallback to algorithmic calculations. The system generates personalized nutrition plans based on scientific research, acute fueling strategies, and advanced optimization techniques.

## Research Sources
- ACSM's Guidelines for Exercise Testing and Prescription
- Journal of Sports Science Research: "Nutrition for endurance sports: Marathon, triathlon, and road cycling"
- PMC Studies: "Nutritional Intake and Timing of Marathon Runners" 
- TrainingPeaks: "A Complete Guide to Proper Marathon Nutrition"
- Precision Fuel & Hydration: Performance nutrition research

## Implementation Architecture

### **AI-First Dual-System Approach**
The Mealvana Endurance app implements a sophisticated dual-system architecture:

**Primary System: AI-Powered Linear Programming**
- **LLM Integration**: Natural language understanding for personalized requirements
- **Linear Programming Solver**: Multi-objective optimization using JavaScript solver
- **Advanced Personalization**: Context-aware recommendations based on individual history
- **Constraint Optimization**: Simultaneous optimization of carbs, protein, fat, sodium, and hydration

**Fallback System: Evidence-Based Algorithmic**  
- **Fast Response**: Sub-second deterministic calculations using ACSM formulas
- **Reliable**: No external dependencies, pure TypeScript implementation
- **Evidence-Based**: Follows the core calculation formulas detailed below
- **Preference-Aware**: Integrates user food preferences with scoring system

## AI System: Linear Programming Optimization

### **Multi-Objective Constraint Solving**
The AI-powered system uses advanced linear programming to simultaneously optimize multiple nutritional objectives:

```typescript
const CONSTRAINT_PRIORITY = {
  carbs_g: 2.0,     // HIGH priority - primary fuel source
  sodium_mg: 1.8,   // High priority for performance
  water_ml: 1.5,    // High priority for hydration
  protein_g: 0.3,   // Lower priority for most phases
  fat_g: 0.3        // Lower priority for most phases
};
```

### **Food Selection Scoring Matrix**
Advanced preference and phase-specific scoring:
```typescript
const SCORING_CONFIG = {
  preference: {
    like: 20,           // Strong preference bonus
    willing_to_try: 5,  // Moderate preference bonus
    dislike: 0          // Excluded from selection
  },
  phase_bonuses: {
    aid_station_bonus: 12,      // Race-practical foods
    carb_density_bonus: 120,    // Efficient carb sources
    gi_sensitive_penalty: 20    // Digestibility concerns
  }
};
```

### **Constraint Tolerances**
Tight tolerances for critical nutrients, relaxed for optional macros:
```typescript
const DEFAULT_TOL = {
  carbs_g: 5,       // ±5g precision for primary fuel
  sodium_mg: 25,    // ±25mg precision for electrolytes
  water_ml: 50,     // ±50ml precision for hydration
  protein_g: 15,    // ±15g relaxed for optional macro
  fat_g: 10         // ±10g relaxed for optional macro
};
```

### **Performance Optimizations**
- **Food Candidate Limiting**: Max 8-12 foods per phase to reduce solver complexity
- **Serving Granularity**: 0.25-0.5 serving increments for precise targeting
- **Penalty Functions**: Unique item penalties to minimize complexity

## Core Calculation Formulas (Algorithmic Fallback)

### 1. Energy Expenditure

**Net Calorie Formula (running-specific):**
```
Net calories = ~1 kcal × body weight (kg) × distance (km)
```

**Gross Calorie Formula (total energy expenditure):**
```
Gross calories = MET × body weight (kg) × duration (hours)
MET = VO₂ / 3.5
VO₂ (mL/kg/min) = 0.2 × speed (m/min) + 3.5  (ACSM running equation, level)
```

Where:
- Speed (m/min) = miles per hour × 26.8224
- Miles per hour = 60 / pace (min/mile)

### 2. Pre-Run Carbohydrate Requirements

**Time-Based Carbohydrate Loading (Evidence-Based Guidelines):**
```
if time_available ≥ 2 hours:   carbs = min(4.0, time_available) × 1.0 g/kg  (1-4g/kg scaling)
if 1 ≤ time_available < 2h:     carbs = 1.0 g/kg
if 0.25 ≤ time_available < 1h:  carbs = 0.5 g/kg
if time_available < 0.25h:      carbs = 0.25 g/kg (small top-up)
```

**Implementation Logic:**
- **2-4 hours before**: 1-4g per kg body weight (scales with available time)
- **1-2 hours before**: 1g per kg body weight  
- **15-60 minutes before**: 0.5g per kg body weight  
- **<15 minutes before**: Small top-up (0.25g per kg)
- **Focus**: Easily digestible carbohydrates
- **Avoid**: High fiber, high fat, or unfamiliar foods

### 3. During-Run Carbohydrate Requirements

**Duration-Based Total Carbohydrate Needs:**
```
For runs < 60 minutes:     0g total (hydration only)
For runs 60-90 minutes:    20-40g total for entire run
For runs > 90 minutes:     30-60g total based on gut training

Gut training multipliers:
- Low gut training:    30g total maximum
- Moderate gut training: 45g total maximum  
- High gut training:    60g total maximum
```

**Implementation Logic:**
- **Short runs (<60 min)**: No carbohydrate supplementation needed
- **Medium runs (60-90 min)**: Modest total carbohydrate intake
- **Long runs (>90 min)**: Higher totals based on gut training capacity
- **Individual variation**: Gut training determines maximum absorption
- **Safety**: Always calculate totals, never hourly rates

### 4. Hydration Requirements

**Pre-Run Hydration:**
```
if time_before_run ≥ 2h: 6 mL/kg (middle of 5-7 mL/kg range)
if 1h ≤ time_before_run < 2h: 4 mL/kg
if time_before_run < 1h: 2 mL/kg (minimal intake)
```

**During-Run Total Hydration Needs:**
```
For runs ≤ 60 min:     150-300 mL total
For runs 60-90 min:    400-600 mL total  
For runs > 90 min:     600-800 mL total

Intensity adjustments:
if MET ≥ 8.0: use upper range (high intensity)
if MET ≥ 6.0: use middle range (moderate intensity)  
else: use lower range (easy pace)
```

### 5. Sodium Requirements

**Pre-Run Sodium:**
```
if time_before_run ≥ 2h: 500 mg (moderate pre-loading)
else: 200 mg (minimal if close to run time)
```

**During-Run Total Sodium Needs:**
```
For runs ≤ 60 min:     0 mg total (no supplementation needed)
For runs 60-90 min:    150-300 mg total
For runs > 90 min:     300-600 mg total
```

## Current Implementation Architecture

### **Dual-System Service Layer (Dart/Flutter)**
```dart
// lib/features/nutrition_plan/application/nutrition_plan_service.dart
Future<NutritionPlan> generateNutritionPlan() async {
  try {
    // PRIMARY: AI-powered linear programming optimization
    final llmPlan = await _llmService.generateLLMNutritionPlan(
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      timeBeforeRunHours: timeBeforeRunHours,
      sweatRate: sweatRate,
    );

    if (llmPlan != null) {
      // Track AI success and cache locally
      await _analytics.trackPlanGenerated(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
        totalCalories: llmPlan.totalCalories ?? 0,
        totalCarbs: llmPlan.macroTargets?.carbs ?? 0,
        beforeRunItems: _countItems(llmPlan.sections, 'Before Run'),
        duringRunItems: _countItems(llmPlan.sections, 'During Run'),
        afterRunItems: _countItems(llmPlan.sections, 'After Run'),
        isFirstPlan: await _isFirstPlan(),
      );
      return llmPlan;
    }

    // FALLBACK: Fast algorithmic Edge Function
    final algorithmicPlan = await _repository.createNutritionPlanV2(
      deviceId: user.id,
      weightKg: weightKg,
      durationMin: durationMin,
      gutTraining: gutTraining,
    );
    
    await _analytics.trackPlanGenerated(
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      totalCalories: algorithmicPlan.plan?.totalCalories ?? 0,
      totalCarbs: algorithmicPlan.plan?.macroTargets?.carbs ?? 0,
      beforeRunItems: _countItems(algorithmicPlan.plan?.sections, 'Before Run'),
      duringRunItems: _countItems(algorithmicPlan.plan?.sections, 'During Run'),
      afterRunItems: _countItems(algorithmicPlan.plan?.sections, 'After Run'),
      isFirstPlan: await _isFirstPlan(),
    );
    return algorithmicPlan.plan!;
    
  } catch (e) {
    await _analytics.trackPlanGenerationFailed(
      errorMessage: e.toString(),
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
    );
    rethrow;
  }
}
```

> Helper function `_countItems` is shorthand for counting plan sections (see `NutritionPlanService` for the real implementation).

### **AI System: Linear Programming (TypeScript)**
```typescript
// supabase/functions/generate-ai-nutrition-plan/index.ts
const constraints = {
  // Multi-objective optimization with priority weighting
  carbs_target: {
    min: targetCarbs * (1 - tolerance_carbs / targetCarbs),
    max: targetCarbs * (1 + tolerance_carbs / targetCarbs),
    weight: CONSTRAINT_PRIORITY.carbs_g
  },
  sodium_target: {
    min: targetSodium * (1 - tolerance_sodium / targetSodium),  
    max: targetSodium * (1 + tolerance_sodium / targetSodium),
    weight: CONSTRAINT_PRIORITY.sodium_mg
  }
  // ... additional constraints for protein, fat, hydration
};

// Use JavaScript LP solver for optimization
const solution = solver.Solve(model);
```

### **Algorithmic Fallback: ACSM Calculations (TypeScript)**
```typescript  
// supabase/functions/run-plan/index.ts
function calculateNutritionTargets(request: RunPlanRequest) {
  // Energy expenditure using ACSM equations
  const speedMph = 60.0 / (request.duration_min / request.distance_miles);
  const speedMPerMin = speedMph * 26.8224;
  const vo2 = 0.2 * speedMPerMin + 3.5;
  const met = vo2 / 3.5;
  const grossCalories = met * request.weight_kg * (request.duration_min / 60);
  
  // Time-sensitive pre-run carbs
  const timeAvailableHours = request.pre_window_min / 60.0;
  let preCarbs: number;
  if (timeAvailableHours >= 1.0) {
    preCarbs = Math.min(4.0, timeAvailableHours) * request.weight_kg;
  } else if (timeAvailableHours >= 0.25) {
    preCarbs = 0.5 * request.weight_kg;  
  } else {
    preCarbs = 0.25 * request.weight_kg;
  }
  
  return { met, grossCalories, preCarbs, /* ... */ };
}
```

## Key Features of Current System

### 1. **AI-Powered Personalization (Primary System)**
- **Advanced Optimization**: Linear programming for multi-objective constraint solving
- **Context Understanding**: LLM integration for nuanced user requirements
- **Preference Learning**: Sophisticated scoring for food likes, dislikes, and willingness to try
- **Environmental Adaptation**: Weather, race conditions, and individual history consideration

### 2. **Evidence-Based Reliability (Fallback System)**
- **ACSM Precision**: Uses ACSM running equation for accurate energy expenditure
- **Time-Sensitive Strategies**: Implements evidence-based pre-run carbohydrate timing
- **Gut Training Integration**: Accounts for individual carbohydrate absorption capacity
- **Fast Performance**: Sub-second response times with deterministic calculations

### 3. **Physiological Safety (Both Systems)**
- **Absorption Limits**: Respects digestive constraints (30-60g carbs/hour, up to 90g with dual-source)
- **Hydration Safety**: Prevents over-hydration with intensity-based fluid rates
- **Electrolyte Balance**: Evidence-based sodium supplementation for runs >1 hour
- **Individual Scaling**: Body weight scaling for all nutritional requirements

### 4. **Advanced Personalization Features**
- **Three-Tier Preferences**: Like (+20 pts) > Willing-to-try (+5 pts) > Neutral (0 pts)
- **Phase Intelligence**: Specific food selection rules for pre/during/after run phases
- **GI Sensitivity**: Adjustments for individual digestive tolerance
- **Environmental Factors**: Temperature, humidity, and sweat rate considerations

## Safety Considerations

### Maximum Safe Limits
- **Carbohydrates**: 60g per hour (GI tolerance limit)
- **Fluids**: 800 mL per hour maximum (hyponatremia prevention)
- **Sodium**: 250 mg per hour for runs >1 hour

### Individual Variations
- **Gut training status**: Affects carbohydrate absorption capacity
- **Body weight**: Scales all nutritional requirements
- **Exercise intensity**: Influences fluid and energy needs
- **Timing constraints**: Determines pre-run nutrition strategy

## Implementation & Performance

### **Dual-System Error Handling**
**AI System Resilience:**
- Graceful degradation to algorithmic fallback when AI unavailable
- Constraint violation handling with penalty functions
- Linear programming solver timeout protection

**Algorithmic System Reliability:**
- Always clamp values to physiological safe ranges
- Robust fallback calculations for edge cases
- Conservative recommendations when data uncertain

### **Performance Monitoring**
**Response Time Tracking:**
- AI System: Typically 2-5 seconds (includes optimization solving)
- Algorithmic Fallback: <1 second (optimized for speed)
- Analytics tracking of system usage patterns and success rates

**Quality Assurance:**
- Cross-reference both systems with established sports nutrition guidelines
- Continuous validation against real-world athlete feedback
- A/B testing of AI vs algorithmic recommendations for quality comparison

### **System Selection Logic**
```dart
// Intelligent system selection based on availability and requirements
Future<NutritionPlan> generatePlan() async {
  final startTime = DateTime.now();
  
  try {
    // Try AI system first for complex personalization
    final aiPlan = await generateAIPlan();
    trackResponseTime('ai_success', startTime);
    return aiPlan;
  } catch (aiError) {
    // Fallback to fast, reliable algorithmic system
    final algorithmicPlan = await generateAlgorithmicPlan();  
    trackResponseTime('algorithmic_fallback', startTime);
    return algorithmicPlan;
  }
}
```

### **Continuous Improvement**
- **AI Model Updates**: Regular improvements to LLM understanding and constraint solving
- **Algorithm Refinement**: Evidence-based updates to ACSM calculations and safety limits
- **User Feedback Integration**: Plan rating and usage data to improve both systems
- **Performance Optimization**: Ongoing tuning of constraint tolerances and food candidate limits

This dual-system architecture provides sophisticated AI-powered personalization while maintaining reliability through evidence-based algorithmic fallback, ensuring users always receive high-quality nutrition guidance regardless of system availability.

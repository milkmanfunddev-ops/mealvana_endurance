# Nutrition Calculation Algorithms

## Overview
Evidence-based nutrition calculation formulas for endurance athletes, specifically for running events. These algorithms are implemented in the Mealvana Endurance app to generate personalized nutrition plans.

## Research Sources
- Journal of Sports Science Research: "Nutrition for endurance sports: Marathon, triathlon, and road cycling"
- PMC Studies: "Nutritional Intake and Timing of Marathon Runners" 
- TrainingPeaks: "A Complete Guide to Proper Marathon Nutrition"
- Precision Fuel & Hydration: Performance nutrition research

## Core Calculation Formulas

### 1. Carbohydrate Requirements

**Base Formula:**
```
Carbs per hour = Base carb rate + Duration adjustment + Body weight adjustment
```

**Implementation Logic:**
- **Short events (<3 hours)**: 30-60g carbs/hour
- **Long events (3+ hours)**: 60-90g carbs/hour
- **Target range for most athletes**: 50-70g carbs/hour
- **Body weight adjustment**: +5g/hour for athletes >180lbs, -5g/hour for athletes <140lbs

**Code Implementation:**
```dart
double calculateCarbsPerHour(double durationHours, double bodyWeightLbs) {
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
```

### 2. Sodium Requirements

**Base Formula:**
```
Sodium per hour = Base sodium rate + Sweat rate adjustment + Duration adjustment
```

**Implementation Logic:**
- **Standard recommendation**: 200-500mg sodium per hour
- **High sweat rate athletes**: 500-700mg per hour
- **"Salty sweaters"**: Up to 1000mg per hour
- **Default target**: 400mg sodium per hour (middle range)

**Code Implementation:**
```dart
double calculateSodiumPerHour(double durationHours, bool runsWithWaterBottle) {
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
```

### 3. Fluid Requirements

**Base Formula:**
```
Fluids per hour = Base fluid rate + Body weight adjustment + Environmental adjustment
```

**Implementation Logic:**
- **Standard recommendation**: 400-800mL (13-27 fl oz) per hour
- **Stomach capacity limit**: ~24-28 fl oz per hour maximum
- **Target range**: 16-24 fl oz per hour for most athletes
- **Body weight adjustment**: Larger athletes need more fluids

**Code Implementation:**
```dart
double calculateFluidsPerHour(double bodyWeightLbs, double durationHours) {
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
```

### 4. Total Plan Calculation

**Main Planning Algorithm:**
```dart
NutritionPlan calculateNutritionPlan({
  required double distanceMiles,
  required double paceMinutesPerMile,
  required double bodyWeightLbs,
  required bool runsWithWaterBottle,
}) {
  // Calculate total duration
  double durationHours = (distanceMiles * paceMinutesPerMile) / 60.0;
  
  // Calculate hourly requirements
  double carbsPerHour = calculateCarbsPerHour(durationHours, bodyWeightLbs);
  double sodiumPerHour = calculateSodiumPerHour(durationHours, runsWithWaterBottle);
  double fluidsPerHour = calculateFluidsPerHour(bodyWeightLbs, durationHours);
  
  // Calculate total requirements
  double totalCarbs = carbsPerHour * durationHours;
  double totalSodium = sodiumPerHour * durationHours;
  double totalFluids = fluidsPerHour * durationHours;
  
  return NutritionPlan(
    totalCarbs: totalCarbs,
    totalSodium: totalSodium,
    totalFluids: totalFluids,
    durationHours: durationHours,
    carbsPerHour: carbsPerHour,
    sodiumPerHour: sodiumPerHour,
    fluidsPerHour: fluidsPerHour,
  );
}
```

## Timing Guidelines

### Pre-Run Nutrition (1-3 hours before)
- **Carbohydrates**: 1-4g per kg body weight (focus on easily digestible carbs)
- **Timing**: Larger meals 3-4 hours before, smaller snacks 1-2 hours before
- **Avoid**: High fiber, high fat, or new foods

### During-Run Nutrition
- **Start early**: Begin fueling within 30-45 minutes of starting
- **Frequency**: Every 15-20 minutes for consistent energy
- **Focus**: Easily absorbed carbs + electrolytes

### Post-Run Recovery (within 30-60 minutes)
- **Carbohydrates**: 1-1.2g per kg body weight
- **Protein**: 0.25-0.3g per kg body weight  
- **Fluids**: 1.2-1.5L per kg body weight lost

## Safety Considerations

### Maximum Safe Limits
- **Carbohydrates**: Do not exceed 90g per hour (GI distress risk)
- **Sodium**: Do not exceed 1000mg per hour without medical guidance
- **Fluids**: Do not exceed 28 fl oz per hour (hyponatremia risk)

### Individual Variations
- **GI tolerance**: Some athletes need lower amounts
- **Heat acclimatization**: Affects sweat rate and sodium losses
- **Training status**: More trained athletes may handle higher amounts
- **Personal preference**: Food preferences affect compliance

## Implementation Notes

### Error Handling
- Always clamp values to safe ranges
- Provide warnings for extreme inputs
- Default to conservative recommendations when in doubt

### User Feedback Integration
- Track user feedback on plan amounts (too much/too little)
- Adjust base recommendations based on user responses
- Learn user-specific patterns over time

This algorithm framework provides the foundation for generating personalized, evidence-based nutrition plans for endurance athletes while maintaining safety and efficacy standards.
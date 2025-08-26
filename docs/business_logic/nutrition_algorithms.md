# Nutrition Calculation Algorithms

## Overview
Evidence-based nutrition calculation formulas for endurance athletes, specifically for running events. These algorithms are implemented in the Mealvana Endurance app to generate personalized nutrition plans based on scientific research and acute fueling strategies.

## Research Sources
- ACSM's Guidelines for Exercise Testing and Prescription
- Journal of Sports Science Research: "Nutrition for endurance sports: Marathon, triathlon, and road cycling"
- PMC Studies: "Nutritional Intake and Timing of Marathon Runners" 
- TrainingPeaks: "A Complete Guide to Proper Marathon Nutrition"
- Precision Fuel & Hydration: Performance nutrition research

## Core Calculation Formulas

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

## Complete Algorithm Implementation

```python
def compute_run_fueling(input_params):
    # Convert units and calculate kinematics
    weight_kg = to_kg(weight, weight_unit)
    distance_mi = to_miles(distance, distance_unit)
    pace_min_per_mile = parse_pace_to_min_per_mile(pace, pace_unit)
    duration_h = distance_mi * pace_min_per_mile / 60.0
    speed_mph = 60.0 / pace_min_per_mile
    
    # Energy expenditure
    MET = met_from_pace_min_per_mile(pace_min_per_mile)
    calories_net = weight_kg * distance_km  # ~1 kcal/kg/km
    calories_gross = MET * weight_kg * duration_h
    
    # Pre-run carbohydrates
    time_available_h = time_before_run_min / 60.0
    if time_available_h >= 1.0:
        pre_carbs = min(4.0, time_available_h) * 1.0 * weight_kg
    elif time_available_h >= 0.25:
        pre_carbs = 0.5 * weight_kg
    else:
        pre_carbs = 0.25 * weight_kg
    
    # During-run carbohydrates (total amounts, not hourly rates)
    if duration_h < 1.0:
        total_during_carbs = 0  # No carbs needed for short runs
    elif duration_h <= 1.5:
        total_during_carbs = min(40, 20 + (duration_h - 1.0) * 40)  # 20-40g total
    else:
        gut_multiplier = {"low": 30, "moderate": 45, "high": 60}[gut_training]
        total_during_carbs = gut_multiplier  # Total grams, not per hour
    
    # Hydration and sodium calculations
    pre_water = calc_pre_run_hydration(weight_kg, time_available_h)
    during_water_rate = calc_during_run_hydration_rate(duration_h, MET)
    pre_sodium = calc_pre_run_sodium(time_available_h)
    during_sodium_rate = calc_during_run_sodium_rate(duration_h)
    
    return FuelOutput(...)
```

## Key Features of Updated Algorithm

### 1. Evidence-Based Precision
- Uses ACSM running equation for accurate energy expenditure
- Implements time-sensitive pre-run carbohydrate strategies
- Accounts for individual gut training levels

### 2. Physiological Constraints
- Respects digestive absorption limits (30-60g carbs/hour)
- Prevents over-hydration with intensity-based fluid rates
- Eliminates sodium supplementation for short runs (≤1 hour)

### 3. Personalization Factors
- Body weight scaling for all calculations
- Gut training level consideration for carb absorption
- Time-sensitive pre-run nutrition strategies
- Intensity-based hydration adjustments

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

## Implementation Notes

### Error Handling
- Always clamp values to physiological safe ranges
- Provide fallback calculations for edge cases
- Default to conservative recommendations when uncertain

### Algorithm Validation
- Cross-reference with established sports nutrition guidelines
- Test edge cases (very short/long runs, extreme body weights)
- Validate against real-world athlete feedback

This updated algorithm framework provides a more precise, evidence-based foundation for generating personalized nutrition plans while maintaining safety and accounting for individual physiological differences.
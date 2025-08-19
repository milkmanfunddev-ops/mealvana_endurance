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

**Time-Based Carbohydrate Loading:**
```
if time_available ≥ 1 hour:    carbs = min(4 hours, time_available) × 1.0 g/kg
if 0.25 ≤ time_available < 1h: carbs = 0.5 g/kg
if time_available < 0.25h:     carbs = ~0.25 g/kg (small top-up)
```

**Implementation Logic:**
- **1-4 hours before**: 1-4g per kg body weight (capped at 4g/kg)
- **15-60 minutes before**: 0.5g per kg body weight  
- **<15 minutes before**: Small top-up (~0.25g per kg)
- **Focus**: Easily digestible carbohydrates
- **Avoid**: High fiber, high fat, or unfamiliar foods

### 3. During-Run Carbohydrate Requirements

**Mass-Normalized Rate Formula:**
```
Base rate = gut_training_level × body weight (kg)
gut_training_levels: {low: 0.7, moderate: 0.8, high: 1.0} g/kg/h
```

**Absorption-Limited Rate:**
```
Final rate = clamp(base_rate, 30, 60) g/h
Total during-run carbs = final_rate × duration (hours)
```

**Implementation Logic:**
- **Gut training consideration**: Athletes with trained guts can absorb more
- **Physiological limits**: 30-60g per hour absorption capacity
- **Personalization**: Higher rates for larger, gut-trained athletes
- **Safety**: Always clamp to digestive capacity limits

### 4. Hydration Requirements

**Pre-Run Hydration:**
```
if time_before_run ≥ 2h: 6 mL/kg (middle of 5-7 mL/kg range)
if 1h ≤ time_before_run < 2h: 4 mL/kg
if time_before_run < 1h: 2 mL/kg (minimal intake)
```

**During-Run Hydration Rate:**
```
Base rate: 500 mL/h
if duration ≤ 1h: 400 mL/h (80% of base)
if MET ≥ 8.0: 800 mL/h (high intensity)
if MET ≥ 6.0: 600 mL/h (moderate intensity)
else: 500 mL/h (easy pace)
```

### 5. Sodium Requirements

**Pre-Run Sodium:**
```
if time_before_run ≥ 2h: 500 mg (moderate pre-loading)
else: 200 mg (minimal if close to run time)
```

**During-Run Sodium Rate:**
```
if duration ≤ 1h: 0 mg/h (no supplementation needed)
else: 250 mg/h (typical sports drink concentration)
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
    
    # During-run carbohydrates
    gut_multiplier = {"low": 0.7, "moderate": 0.8, "high": 1.0}[gut_training]
    mass_norm_rate = gut_multiplier * weight_kg
    final_rate = clamp(mass_norm_rate, 30.0, 60.0)
    total_during_carbs = final_rate * duration_h
    
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
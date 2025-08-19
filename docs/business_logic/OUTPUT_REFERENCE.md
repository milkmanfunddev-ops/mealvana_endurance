# Nutrition Planning Tool - Output Reference

This document explains all output fields from the run fueling calculator.

## Output Structure

The tool returns a comprehensive `FuelOutput` object with the following sections:

### Kinematics
- **`duration_min`**: Total run duration in minutes
- **`duration_h`**: Total run duration in hours (decimal)
- **`speed_mph`**: Average running speed in miles per hour
- **`distance_mi`**: Run distance in miles
- **`distance_km`**: Run distance in kilometers

### Energy Expenditure
- **`calories_net_kcal`**: Net calories burned (excluding resting metabolic rate)
- **`calories_gross_kcal`**: Gross calories burned (including resting metabolic rate)
- **`MET`**: Metabolic Equivalent of Task - intensity multiplier relative to resting metabolism

### Pre-Run Nutrition (2+ hours before)
- **`pre_run_carbs_g`**: Recommended carbohydrate intake in grams
- **`pre_run_carbs_rule`**: Dosing rule used (e.g., "1-4 g/kg body weight")
- **`pre_run_protein_g_optional`**: Optional protein intake in grams
- **`pre_run_fat_g_cap`**: Maximum fat intake in grams (to avoid GI distress)

### During-Run Fueling
- **`during_rate_g_per_h`**: Actual recommended carb rate (g/h), clamped to absorption limits
- **`during_total_g`**: Total carbohydrates for entire run duration
- **`during_mass_norm_rate_g_per_h`**: Unclamped rate based on body weight and gut training
- **`during_abs_clamp_range_g_per_h`**: Physiological absorption limits (30-60 g/h)
- **`during_mass_norm_total_range_g`**: Personalized total intake range based on 0.7-1.0 g/kg/h

### Hydration
- **`pre_run_water_ml`**: Recommended water intake before run (2-6 mL/kg based on timing)
- **`during_water_rate_ml_per_h`**: Fluid intake rate during run (400-800 mL/h based on intensity)
- **`during_water_total_ml`**: Total fluid intake for entire run duration

### Sodium
- **`pre_run_sodium_mg`**: Recommended sodium intake before run (200-500 mg based on timing)
- **`during_sodium_rate_mg_per_h`**: Sodium intake rate during run (0 for ≤1h runs, 250 mg/h for longer)
- **`during_sodium_total_mg`**: Total sodium intake for entire run duration

## Key Differences

### Absorption vs Mass-Normalized Limits
- **Absorption clamp**: Universal digestive capacity (30-60 g/h for all athletes)
- **Mass-normalized**: Personalized recommendations based on body weight and gut training level

### Net vs Gross Calories
- **Net calories**: Energy cost above resting metabolism
- **Gross calories**: Total energy expenditure including baseline metabolism

## Gut Training Levels
The tool accounts for different carbohydrate absorption capacities:
- Untrained gut: Lower absorption rates
- Trained gut: Higher absorption rates up to physiological limits

## Units
All outputs use standard units:
- Distance: miles and kilometers
- Weight/Mass: grams
- Time: minutes and hours
- Energy: kilocalories (kcal)
- Rate: grams per hour (g/h)
- Fluid volume: milliliters (mL)
- Sodium: milligrams (mg)
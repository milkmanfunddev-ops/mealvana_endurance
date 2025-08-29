"""
run_fueling_lee.py — Running-focused fueling calculator with macro, hydration, and sodium calculations.

Inputs: athlete parameters (age, gender, weight, height) and running parameters (pace, distance, pre-run timing) via dict.
Outputs: duration, pace, distance (mi/km), calories (net & gross), and pre/during macro targets.

Core formulas (evidence-based, acute fueling):

RUNNING:
- Time (h): t_h = distance(mi) * pace(min/mi) / 60
- Net kcal (running): ~1 kcal * kg * km  (cost of transport, net of rest)
- Gross kcal: MET * kg * h
    MET from ACSM running VO₂ (level): VO2 (mL/kg/min) = 0.2 * v + 3.5  with v in m/min

FUELING:
- Pre-run carbohydrate:
    if 0.25h ≤ h < 1h: 0.5 g/kg
    if 1h ≤ h ≤ 4h:   h * 1.0 g/kg  (cap at 4 g/kg)
    if h < 0.25h:     small top-up ≈ 0.25 g/kg
- During-run carbohydrate:
    mass-normalized rate r = {0.7, 0.8, 1.0} g/kg/h (gut training)
    clamp absolute rate to [30, 60] g/h for running
- Hydration & sodium adjusted by running intensity and duration
"""

from dataclasses import dataclass, asdict
from typing import Literal, Tuple, Union, Optional

Gender = Literal["female", "male", "other"]
PaceUnit = Literal["min_per_mile", "min_per_km"]
DistanceUnit = Literal["mi", "km"]
WeightUnit = Literal["kg", "lb"]
HeightUnit = Literal["cm", "in"]
GutTraining = Literal["low", "moderate", "high"]

LB_TO_KG = 0.45359237
IN_TO_CM = 2.54
MI_TO_KM = 1.60934
MPH_TO_M_PER_MIN = 26.8224

def to_kg(weight: float, unit: WeightUnit) -> float:
    return weight if unit == "kg" else weight * LB_TO_KG

def to_cm(height: float, unit: HeightUnit) -> float:
    return height if unit == "cm" else height * IN_TO_CM

def to_miles(distance: float, unit: DistanceUnit) -> float:
    return distance if unit == "mi" else distance / MI_TO_KM

def parse_pace_to_min_per_mile(pace: Union[str, float], pace_unit: PaceUnit = "min_per_mile") -> float:
    def as_minutes(v: Union[str, float]) -> float:
        if isinstance(v, (int, float)):
            return float(v)
        parts = [p.strip() for p in v.split(":")]
        if len(parts) == 1:
            return float(parts[0])
        mm = float(parts[0] or 0)
        ss = float(parts[1] or 0)
        return mm + ss/60.0
    p = as_minutes(pace)
    return p if pace_unit == "min_per_mile" else p * MI_TO_KM

def met_from_pace_min_per_mile(pace_min_per_mile: float) -> float:
    mph = 60.0 / pace_min_per_mile
    v_m_per_min = mph * MPH_TO_M_PER_MIN
    VO2 = 0.2 * v_m_per_min + 3.5  # ACSM running, level ground
    return VO2 / 3.5

def clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))

def gut_rate(gut: GutTraining = "high") -> float:
    return {"low": 0.7, "moderate": 0.8, "high": 1.0}[gut]

def calc_pre_run_hydration(weight_kg: float, time_before_h: float) -> int:
    base_rate = 5  # ml/kg for running
    if time_before_h >= 2.0:
        return int(weight_kg * base_rate)
    elif time_before_h >= 1.0:
        return int(weight_kg * 4)
    else:
        return int(weight_kg * 2)

def calc_during_run_hydration_rate(duration_h: float, intensity: float) -> int:
    """Calculate hydration rate based on running intensity (MET)."""
    base_rate = 500
    if duration_h <= 1.0:
        return int(base_rate * 0.8)
    elif intensity >= 8.0:
        return int(base_rate * 1.6)
    elif intensity >= 6.0:
        return int(base_rate * 1.2)
    else:
        return base_rate

def calc_pre_run_sodium(time_before_h: float) -> int:
    base = 400
    if time_before_h >= 2.0:
        return base
    else:
        return 200

def calc_during_run_sodium_rate(duration_h: float) -> int:
    if duration_h <= 1.0:
        return 0
    else:
        return 250

@dataclass
class RunFuelInput:
    age: int
    gender: Gender
    weight: float
    weight_unit: WeightUnit
    height: float
    height_unit: HeightUnit
    run_pace: Union[str, float]
    run_distance: float
    run_pace_unit: PaceUnit = "min_per_mile"
    run_distance_unit: DistanceUnit = "mi"
    time_before_run_min: float = 120.0
    gut_training: GutTraining = "high"

@dataclass
class RunFuelOutput:
    duration_min: float
    duration_h: float
    pace_min_per_mile: float
    speed_mph: float
    distance_mi: float
    distance_km: float
    calories_net_kcal: int
    calories_gross_kcal: int
    MET: float
    pre_run_carbs_g: int
    pre_run_carbs_rule: str
    pre_run_protein_g_optional: int
    pre_run_fat_g_cap: float
    during_rate_g_per_h: float
    during_total_g: int
    during_mass_norm_rate_g_per_h: float
    during_abs_clamp_range_g_per_h: Tuple[int, int]
    during_mass_norm_total_range_g: Tuple[int, int]
    pre_run_water_ml: int
    during_water_rate_ml_per_h: int
    during_water_total_ml: int
    pre_run_sodium_mg: int
    during_sodium_rate_mg_per_h: int
    during_sodium_total_mg: int

def compute_run_fueling(params: dict) -> RunFuelOutput:
    """Main entry point function that takes parameters as a dict."""
    inp = RunFuelInput(**params)
    
    weight_kg = to_kg(inp.weight, inp.weight_unit)
    
    distance_mi = to_miles(inp.run_distance, inp.run_distance_unit)
    pace_min_per_mile = parse_pace_to_min_per_mile(inp.run_pace, inp.run_pace_unit)
    duration_min = distance_mi * pace_min_per_mile
    duration_h = duration_min / 60.0
    speed_mph = 60.0 / pace_min_per_mile
    distance_km = distance_mi * MI_TO_KM
    
    # Energy
    calories_net = weight_kg * distance_km
    MET = met_from_pace_min_per_mile(pace_min_per_mile)
    calories_gross = MET * weight_kg * duration_h
    
    # Pre-run nutrition
    h_avail = max(0.0, inp.time_before_run_min / 60.0)
    if h_avail >= 1.0:
        h_eff = min(4.0, h_avail)
        pre_carbs_g = h_eff * 1.0 * weight_kg
        pre_rule = f"{h_eff:.2f} h × 1 g/kg"
    elif h_avail >= 0.25:
        pre_carbs_g = 0.5 * weight_kg
        pre_rule = "0.5 g/kg (15–60 min window)"
    else:
        pre_carbs_g = 0.25 * weight_kg
        pre_rule = "<15 min → ~0.25 g/kg top-up"
    
    pre_protein_g_opt = 0.2 * weight_kg
    pre_fat_cap = (0.2 if h_avail > 2.0 else 0.1) * weight_kg
    
    # During-run nutrition
    mass_norm_rate = gut_rate(inp.gut_training) * weight_kg
    rate_abs_clamped = clamp(mass_norm_rate, 30.0, 60.0)
    total_during_g = rate_abs_clamped * duration_h
    mass_norm_total_min = 0.7 * weight_kg * duration_h
    mass_norm_total_max = 1.0 * weight_kg * duration_h
    
    # Hydration & sodium
    pre_water_ml = calc_pre_run_hydration(weight_kg, h_avail)
    during_water_rate_ml_h = calc_during_run_hydration_rate(duration_h, MET)
    during_water_total_ml = during_water_rate_ml_h * duration_h
    
    pre_sodium_mg = calc_pre_run_sodium(h_avail)
    during_sodium_rate_mg_h = calc_during_run_sodium_rate(duration_h)
    during_sodium_total_mg = during_sodium_rate_mg_h * duration_h
    
    return RunFuelOutput(
        duration_min=round(duration_min, 2),
        duration_h=round(duration_h, 4),
        pace_min_per_mile=round(pace_min_per_mile, 2),
        speed_mph=round(speed_mph, 3),
        distance_mi=round(distance_mi, 3),
        distance_km=round(distance_km, 3),
        
        calories_net_kcal=int(round(calories_net)),
        calories_gross_kcal=int(round(calories_gross)),
        MET=round(MET, 2),
        
        pre_run_carbs_g=int(round(pre_carbs_g)),
        pre_run_carbs_rule=pre_rule,
        pre_run_protein_g_optional=int(round(pre_protein_g_opt)),
        pre_run_fat_g_cap=round(pre_fat_cap, 1),
        
        during_rate_g_per_h=round(rate_abs_clamped, 1),
        during_total_g=int(round(total_during_g)),
        during_mass_norm_rate_g_per_h=round(mass_norm_rate, 1),
        during_abs_clamp_range_g_per_h=(30, 60),
        during_mass_norm_total_range_g=(
            int(round(mass_norm_total_min)),
            int(round(mass_norm_total_max)),
        ),
        
        pre_run_water_ml=pre_water_ml,
        during_water_rate_ml_per_h=during_water_rate_ml_h,
        during_water_total_ml=int(round(during_water_total_ml)),
        
        pre_run_sodium_mg=pre_sodium_mg,
        during_sodium_rate_mg_per_h=during_sodium_rate_mg_h,
        during_sodium_total_mg=int(round(during_sodium_total_mg)),
    )

if __name__ == '__main__':
    # Test with sample values
    test_params = {
        "age": 30,
        "gender": "female",
        "weight": 60,
        "weight_unit": "kg",
        "height": 165,
        "height_unit": "cm",
        "run_pace": "8:00",
        "run_pace_unit": "min_per_mile",
        "run_distance": 10,
        "run_distance_unit": "mi",
        "time_before_run_min": 120.0,
        "gut_training": "high"
    }
    
    result = compute_run_fueling(test_params)
    print("Running Fueling Results:")
    print(f"Duration: {result.duration_min:.1f} min ({result.duration_h:.2f} h)")
    print(f"Pace: {result.pace_min_per_mile:.2f} min/mile")
    print(f"Distance: {result.distance_mi} mi ({result.distance_km:.1f} km)")
    print(f"Calories: {result.calories_net_kcal} net, {result.calories_gross_kcal} gross")
    print(f"MET: {result.MET}")
    print()
    print("Pre-run nutrition:")
    print(f"  Carbs: {result.pre_run_carbs_g}g ({result.pre_run_carbs_rule})")
    print(f"  Protein (optional): {result.pre_run_protein_g_optional}g")
    print(f"  Fat cap: {result.pre_run_fat_g_cap}g")
    print(f"  Water: {result.pre_run_water_ml}ml")
    print(f"  Sodium: {result.pre_run_sodium_mg}mg")
    print()
    print("During-run nutrition:")
    print(f"  Carbs: {result.during_rate_g_per_h}g/h (total: {result.during_total_g}g)")
    print(f"  Water: {result.during_water_rate_ml_per_h}ml/h (total: {result.during_water_total_ml}ml)")
    print(f"  Sodium: {result.during_sodium_rate_mg_per_h}mg/h (total: {result.during_sodium_total_mg}mg)")
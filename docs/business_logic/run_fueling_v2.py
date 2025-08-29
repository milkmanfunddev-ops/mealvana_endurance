# run_fueling_env_sweat_v4.py
# Fueling & hydration planner for endurance running
# Includes: ACSM MET (walk/run switch), gross kcal, CHO bands (absolute g/h) with nudges & caps,
#           macro targets (pre/during/after), sodium + fluids, sweat-rate & environment inputs.
#
# Key references (summarized in docstrings/comments):
# - ACSM Metabolic Calculations Handbook; ACSM Guidelines 10e (running/walking equations; MET → kcal)
# - Jeukendrup AE (2004, 2011): Multiple transportable carbohydrates; exogenous CHO oxidation caps
# - Burke LM et al. (2011/2018): IOC/consensus on fueling amounts & timing
# - Thomas DT et al. (2016, JAND): Sports nutrition recommendations
# - NATA/ACSM hydration: limit body-mass loss <2–3%; avoid overdrinking
#
from dataclasses import dataclass
from enum import Enum
from typing import Dict, Tuple, Optional

MI_TO_KM = 1.60934
MPH_TO_M_PER_MIN = 26.8224

class GutTraining(str, Enum):
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"

class CarbSource(str, Enum):
    GLUCOSE_ONLY = "glucose_only"   # single-transporter fueling (SGLT1)
    DUAL = "dual"                   # glucose + fructose (SGLT1 + GLUT5)

class SweatSodium(str, Enum):
    LOW = "low"       # ~400 mg/L
    MEDIUM = "medium" # ~800 mg/L
    HIGH = "high"     # ~1200 mg/L

class SweatRateCat(str, Enum):
    LIGHT = "light"    # ~0.3–0.5 L/h
    MEDIUM = "medium"  # ~0.6–0.9 L/h
    HEAVY = "heavy"    # ~1.0–1.2 L/h (running practical upper bound)

@dataclass
class RunInput:
    distance_miles: float
    pace_min_per_mile: float
    weight_kg: float
    gut_training: GutTraining = GutTraining.MODERATE
    carb_source: CarbSource = CarbSource.DUAL
    time_before_run_min: int = 120
    # Hydration & electrolytes
    sweat_sodium: SweatSodium = SweatSodium.MEDIUM
    drink_sodium_mg_per_l: int = 500
    optional_sweat_rate_lph: Optional[float] = None
    sweat_rate_category: SweatRateCat = SweatRateCat.MEDIUM
    # Environment (°C and %RH). If None, defaults to "moderate".
    temp_c: Optional[float] = None
    humidity_pct: Optional[float] = None
    # Anthropometrics (unused unless you later model BMR)
    age: Optional[int] = None
    sex: Optional[str] = None
    height_cm: Optional[float] = None
    
    def __post_init__(self):
        """Validate input parameters."""
        # Distance validation
        if self.distance_miles <= 0 or self.distance_miles > 200:
            raise ValueError(f"Distance must be between 0 and 200 miles, got {self.distance_miles}")
        
        # Pace validation (reasonable range: 4:00 to 20:00 min/mile)
        if self.pace_min_per_mile < 4.0 or self.pace_min_per_mile > 20.0:
            raise ValueError(f"Pace must be between 4:00 and 20:00 min/mile, got {self.pace_min_per_mile:.2f}")
        
        # Weight validation
        if self.weight_kg <= 30 or self.weight_kg > 150:
            raise ValueError(f"Weight must be between 30 and 150 kg, got {self.weight_kg}")
        
        # Time before run validation
        if self.time_before_run_min < 0 or self.time_before_run_min > 480:
            raise ValueError(f"Time before run must be between 0 and 480 minutes, got {self.time_before_run_min}")
        
        # Drink sodium validation
        if self.drink_sodium_mg_per_l < 0 or self.drink_sodium_mg_per_l > 2000:
            raise ValueError(f"Drink sodium must be between 0 and 2000 mg/L, got {self.drink_sodium_mg_per_l}")
        
        # Optional sweat rate validation
        if self.optional_sweat_rate_lph is not None:
            if self.optional_sweat_rate_lph < 0.1 or self.optional_sweat_rate_lph > 4.0:
                raise ValueError(f"Sweat rate must be between 0.1 and 4.0 L/h, got {self.optional_sweat_rate_lph}")
        
        # Temperature validation
        if self.temp_c is not None:
            if self.temp_c < -20 or self.temp_c > 50:
                raise ValueError(f"Temperature must be between -20 and 50°C, got {self.temp_c}")
        
        # Humidity validation
        if self.humidity_pct is not None:
            if self.humidity_pct < 0 or self.humidity_pct > 100:
                raise ValueError(f"Humidity must be between 0 and 100%, got {self.humidity_pct}")
        
        # Age validation
        if self.age is not None:
            if self.age < 10 or self.age > 100:
                raise ValueError(f"Age must be between 10 and 100, got {self.age}")
        
        # Height validation
        if self.height_cm is not None:
            if self.height_cm < 100 or self.height_cm > 250:
                raise ValueError(f"Height must be between 100 and 250 cm, got {self.height_cm}")

# ---------------- Energy & intensity ----------------

def met_from_pace(min_per_mile: float) -> float:
    """ACSM level-ground equations with a walk/run switch.
       Running (>= ~4.0 mph): VO2 = 0.2*v + 3.5
       Walking (< ~4.0 mph):  VO2 = 0.1*v + 3.5
       where v is m/min; MET = VO2/3.5
    """
    # Bounds check (pace should be validated in RunInput, but double-check)
    if min_per_mile <= 0:
        raise ValueError(f"Invalid pace: {min_per_mile} min/mile")
    
    mph = 60.0 / min_per_mile
    v = mph * MPH_TO_M_PER_MIN
    vo2 = (0.2*v + 3.5) if mph >= 4.0 else (0.1*v + 3.5)
    
    # Sanity check MET value (typical range 2-20)
    met = vo2 / 3.5
    if met < 1 or met > 25:
        raise ValueError(f"Calculated MET value {met:.1f} is outside reasonable range")
    
    return met

def gross_kcal(weight_kg: float, duration_min: float, met: float) -> float:
    """Exact ACSM: kcal/min = (MET * 3.5 * kg) / 200; multiply by minutes."""
    return (met * 3.5 * weight_kg / 200.0) * duration_min

def net_kcal_transport_cost(weight_kg: float, distance_miles: float) -> float:
    """Running cost of transport (net, excludes resting): ~1.0 kcal·kg⁻¹·km⁻¹ * mass * km."""
    return 1.0 * weight_kg * (distance_miles * MI_TO_KM)

def duration_hours(distance_miles: float, pace_min_per_mile: float) -> float:
    return (distance_miles * pace_min_per_mile) / 60.0

# ---------------- Carbohydrate targeting ----------------

def carbs_band_by_duration(duration_h: float) -> Tuple[int, int]:
    """Absolute CHO bands (g/h) by duration (absorption-limited).
       <=1.0h: 0–30; 1.0–2.0h: 30–45; 2.0–3.0h: 45–60; 3.0–4.0h: 60–75; >4.0h: 75–90.
    """
    if duration_h <= 1.0: return (0, 30)
    if duration_h <= 2.0: return (30, 45)
    if duration_h <= 3.0: return (45, 60)
    if duration_h <= 4.0: return (60, 75)
    return (75, 90)

def absorption_cap_gph(gut: GutTraining, source: CarbSource) -> int:
    """Caps: glucose-only ~60–65 g/h; dual ~90 g/h typical; up to ~100 g/h (running)."""
    if source == CarbSource.GLUCOSE_ONLY:
        return 65 if gut == GutTraining.HIGH else 60
    return 80 if gut == GutTraining.LOW else (90 if gut == GutTraining.MODERATE else 100)

def intensity_nudge_from_met(met: float) -> int:
    """Small nudge inside the band by intensity."""
    return -5 if met < 7 else (5 if met > 9 else 0)

def mass_tilt_within_band(weight_kg: float, low: int, high: int) -> int:
    """Lean small athletes to low end; large to high; mid otherwise."""
    return low if weight_kg < 50 else (high if weight_kg > 80 else round((low + high) / 2))

def recommend_carbs_per_hour(duration_h: float, met: float, weight_kg: float,
                             gut: GutTraining, source: CarbSource) -> Dict[str, float]:
    """Pick band by duration, nudge by MET/gut/mass, cap by absorption limits.
       Enforce floor: if duration > 1.1h and MET > 8 → low bound becomes at least 30 g/h.
    """
    low, high = carbs_band_by_duration(duration_h)
    # Floor condition for moderate duration + high intensity
    if duration_h > 1.1 and met > 8 and low < 30:
        low = 30
    raw = max(low, min(high, mass_tilt_within_band(weight_kg, low, high) +
                        intensity_nudge_from_met(met) + {"low":-5,"moderate":0,"high":5}[gut.value]))
    cap = absorption_cap_gph(gut, source)
    return {"gph_low": low, "gph_high": high, "gph_cap": cap, "gph_raw": raw, "gph_final": min(raw, cap)}

# ---------------- Environment & hydration/sodium ----------------

def env_multiplier(temp_c: Optional[float], humidity_pct: Optional[float]) -> Tuple[float, str]:
    """Coarse environment multiplier for fluid needs and a label for UI."""
    if temp_c is None and humidity_pct is None:
        return 1.0, "moderate"
    t = temp_c if temp_c is not None else 20.0
    h = humidity_pct if humidity_pct is not None else 60.0
    if t <= 10: return 0.85, "cool"
    if 10 < t <= 20 and h <= 60: return 1.0, "temperate"
    if (20 < t <= 25) or (60 < h <= 75): return 1.1, "warm"
    if (25 < t <= 30) or (75 < h <= 85): return 1.2, "hot"
    return 1.3, "very_hot"

def fluid_band_lph(weight_kg: float, met: float, temp_c: Optional[float], humidity_pct: Optional[float]) -> Tuple[float, float, float, str]:
    """Base 0.4–0.8 L/h band, tilt by mass & MET, then scale by environment multiplier."""
    low, high = 0.4, 0.8
    if weight_kg < 50: high -= 0.1
    elif weight_kg > 80: low += 0.1
    if met > 9: low += 0.05; high += 0.05
    if met < 7: low -= 0.05; high -= 0.05
    mult, label = env_multiplier(temp_c, humidity_pct)
    low *= mult; high *= mult
    # Running practicality clamps
    low = max(0.3, min(low, 1.0))
    high = max(low + 0.05, min(high, 1.2))
    return round(low,2), round(high,2), mult, label

def typical_sweat_rate_from_category(cat: SweatRateCat) -> float:
    return 0.45 if cat == SweatRateCat.LIGHT else (0.75 if cat == SweatRateCat.MEDIUM else 1.1)

def sodium_concentration_from_category(sweat_sodium: SweatSodium) -> int:
    return 400 if sweat_sodium == SweatSodium.LOW else (800 if sweat_sodium == SweatSodium.MEDIUM else 1200)

def pre_run_hydration(weight_kg: float, minutes_before: int, sweat_cat: SweatSodium, env_label: str) -> Dict[str, float]:
    """Pre-run fluids/sodium with small upshift in heat."""
    main_ml_per_kg = 6.0 if minutes_before >= 150 else 4.0
    if env_label in ("hot","very_hot"): main_ml_per_kg += 1.0
    main_ml = main_ml_per_kg * weight_kg
    topoff_ml = 300.0 if env_label in ("hot","very_hot") else (250.0 if minutes_before >= 45 else 150.0)
    pre_na = 300 if sweat_cat == SweatSodium.LOW else (450 if sweat_cat == SweatSodium.MEDIUM else 600)
    if env_label in ("hot","very_hot"): pre_na += 100
    return {"main_ml": round(main_ml,0), "topoff_ml": round(topoff_ml,0), "sodium_mg": pre_na}

def sodium_target_dynamic(sweat_sodium_cat: SweatSodium,
                          sweat_rate_lph: Optional[float],
                          env_label: str) -> Tuple[int,int,int,str]:
    """If sweat-rate known: target 50–70% of hourly Na loss; else use category bands with heat bump."""
    if sweat_rate_lph is not None:
        conc = sodium_concentration_from_category(sweat_sodium_cat)
        loss_mgph = conc * sweat_rate_lph
        low = int(max(300, round(loss_mgph * 0.5)))
        high = int(min(1200, round(loss_mgph * 0.7)))
        target = int(min(high, max(low, round(loss_mgph * 0.6))))
        return low, high, target, "measured"
    # Category-based
    base_low, base_high, base_target = (300,500,400) if sweat_sodium_cat==SweatSodium.LOW else ((500,800,650) if sweat_sodium_cat==SweatSodium.MEDIUM else (800,1200,1000))
    bump = 0
    if env_label=="warm": bump=50
    elif env_label=="hot": bump=100
    elif env_label=="very_hot": bump=150
    low = base_low + bump; high = base_high + bump; target = base_target + bump
    high = min(high, 1200); target = min(target, 1200)
    return low, high, target, "category"

def during_run_hydration(weight_kg: float, met: float, duration_h: float, 
                         sweat_cat: SweatSodium, drink_na_mg_per_l: int,
                         temp_c: Optional[float], humidity_pct: Optional[float],
                         sweat_rate_lph: Optional[float],
                         sweat_rate_category: SweatRateCat) -> Dict[str, float]:
    low_lph, high_lph, mult, env_label = fluid_band_lph(weight_kg, met, temp_c, humidity_pct)
    plan_lph = round((low_lph + high_lph)/2, 2)

    # If athlete has a sweat rate: plan ~70% of sweat rate, within band (avoid overdrinking while running)
    if sweat_rate_lph is None:
        est_rate = typical_sweat_rate_from_category(sweat_rate_category) * mult
        plan_lph = max(low_lph, min(high_lph, round(est_rate * 0.8, 2)))
        used_sweat_rate = None
        sweat_method = "category_estimate"
    else:
        plan_lph = max(low_lph, min(high_lph, round(sweat_rate_lph * 0.7, 2)))
        used_sweat_rate = round(sweat_rate_lph, 2)
        sweat_method = "measured"

    # Sodium target (dynamic)
    na_low, na_high, na_target, na_method = sodium_target_dynamic(sweat_cat, used_sweat_rate, env_label)
    na_from_drink = int(round(plan_lph * drink_na_mg_per_l))
    na_gap = max(0, na_target - na_from_drink)

    return {
        "environment": env_label, "env_multiplier": mult,
        "fluid_lph_low": low_lph, "fluid_lph_high": high_lph, "fluid_lph_plan": plan_lph,
        "sweat_rate_lph_used": used_sweat_rate, "sweat_rate_method": sweat_method,
        "drink_na_mg_per_l": drink_na_mg_per_l,
        "sodium_method": na_method,
        "sodium_mgph_low": na_low, "sodium_mgph_high": na_high, "sodium_mgph_target": na_target,
        "sodium_from_drink_mgph": na_from_drink, "sodium_gap_mgph": na_gap
    }

def after_run_rehydration(duration_h: float, during_lph: float, sweat_rate_lph: Optional[float], drink_na_mg_per_l: int) -> Dict[str,float]:
    """Post-run: if sweat-rate known, replace ~125% of fluid deficit; else default ~1.25 L with 500–700 mg/L Na."""
    if sweat_rate_lph is not None:
        deficit_l = max(0.0, (sweat_rate_lph - during_lph) * duration_h)
        replace_l = round(deficit_l * 1.25, 2)
        sodium_mg = round(replace_l * max(500, min(700, drink_na_mg_per_l)))
        return {"deficit_l": round(deficit_l,2), "rehydration_l": replace_l, "rehydration_sodium_mg": sodium_mg}
    default_l = 1.25
    sodium_mg = round(default_l * max(500, min(700, drink_na_mg_per_l)))
    return {"rehydration_l": default_l, "rehydration_sodium_mg": sodium_mg}

# ---------------- Macros ----------------

def pre_run_macros(weight_kg: float, time_before_min: int) -> Dict[str, float]:
    """Pre-run macros: CHO by clock time; modest protein/fat for satiety; keep fiber/fat lower close to gun time."""
    hours = min(time_before_min / 60.0, 4.0)
    cho_per_kg = min(3.0, max(0.5, hours))
    carbs_g = cho_per_kg * weight_kg
    if time_before_min <= 60: protein_g, fat_g = 0.15*weight_kg, 0.1*weight_kg
    elif time_before_min <= 90: protein_g, fat_g = 0.2*weight_kg, 0.15*weight_kg
    else: protein_g, fat_g = 0.25*weight_kg, 0.2*weight_kg
    return {"carb_g": round(carbs_g,1), "protein_g": round(protein_g,1), "fat_g": round(fat_g,1)}

def during_run_macros(duration_h: float, met: float, weight_kg: float,
                      gut: GutTraining, source: CarbSource) -> Dict[str, float]:
    """During-run macros: CHO from absolute g/h; protein/fat ~0 g/h for ≤3.5 h (ultras can add small amounts)."""
    c = recommend_carbs_per_hour(duration_h, met, weight_kg, gut, source)
    protein_per_h = 0.0 if duration_h <= 3.5 else 3.0
    fat_per_h = 0.0 if duration_h <= 3.5 else 2.0
    return {"carb_per_h_g": c["gph_final"], "protein_per_h_g": protein_per_h, "fat_per_h_g": fat_per_h,
            "band_low": c["gph_low"], "band_high": c["gph_high"], "cap": c["gph_cap"], "raw": c["gph_raw"]}

def after_run_macros(weight_kg: float, duration_h: float) -> Dict[str, float]:
    """0–60 min post: CHO 1.0–1.2 g/kg (use 1.2 if >2 h), protein ~0.3 g/kg, fat ~0.2 g/kg."""
    cho_per_kg = 1.2 if duration_h > 2 else 1.0
    return {"carb_g": round(cho_per_kg * weight_kg,1),
            "protein_g": round(0.3 * weight_kg,1),
            "fat_g": round(0.2 * weight_kg,1)}

# ---------------- Orchestrator ----------------

def plan_run(input: RunInput) -> Dict[str, Dict[str, float]]:
    # Core intensity/energy
    dur_h = duration_hours(input.distance_miles, input.pace_min_per_mile)
    met = met_from_pace(input.pace_min_per_mile)
    gross = gross_kcal(input.weight_kg, dur_h * 60.0, met)
    netk = net_kcal_transport_cost(input.weight_kg, input.distance_miles)

    # Macros
    pre = pre_run_macros(input.weight_kg, input.time_before_run_min)
    dur_mac = during_run_macros(dur_h, met, input.weight_kg, input.gut_training, input.carb_source)
    aft = after_run_macros(input.weight_kg, dur_h)

    # Hydration & sodium
    low_lph, high_lph, mult, env_label = fluid_band_lph(input.weight_kg, met, input.temp_c, input.humidity_pct)
    pre_hyd = pre_run_hydration(input.weight_kg, input.time_before_run_min, input.sweat_sodium, env_label)
    dur_hyd = during_run_hydration(input.weight_kg, met, dur_h, input.sweat_sodium, input.drink_sodium_mg_per_l,
                                   input.temp_c, input.humidity_pct, input.optional_sweat_rate_lph, input.sweat_rate_category)
    aft_hyd = after_run_rehydration(dur_h, dur_hyd["fluid_lph_plan"], input.optional_sweat_rate_lph, input.drink_sodium_mg_per_l)

    return {
        "summary": {"duration_h": round(dur_h,2), "met": round(met,2),
                    "gross_kcal": round(gross), "net_kcal_transport": round(netk)},
        "environment": {"temp_c": input.temp_c, "humidity_pct": input.humidity_pct, "env_multiplier": mult, "label": env_label},
        "pre_run": pre,
        "pre_run_hydration": pre_hyd,
        "during_run": {**{k: round(v,2) if isinstance(v, float) else v for k,v in dur_mac.items()},
                       "total_carb_g": round(dur_mac["carb_per_h_g"] * dur_h,1),
                       "total_protein_g": round(dur_mac["protein_per_h_g"] * dur_h,1),
                       "total_fat_g": round(dur_mac["fat_per_h_g"] * dur_h,1)},
        "during_run_hydration": {k: round(v,2) if isinstance(v, float) else v for k,v in dur_hyd.items()},
        "after_run": aft,
        "after_run_hydration": aft_hyd
    }


if __name__ == '__main__':
    import json
    
    # Test case: 16 mile run at 9:00 pace with high gut training
    test_input = RunInput(
        distance_miles=16.0,
        pace_min_per_mile=9.0,  # 9:00 min/mile
        weight_kg=75.0,  # Example weight
        gut_training=GutTraining.HIGH,
        sweat_rate_category=SweatRateCat.MEDIUM,
        temp_c=22.8,  # 73°F = 22.8°C
        humidity_pct=60.0,
        age=30,  # Example values
        sex='male',
        height_cm=180.0
    )
    
    print("=== Run Fueling v2 Test Case ===")
    print(f"Distance: {test_input.distance_miles} miles")
    print(f"Pace: {test_input.pace_min_per_mile:.1f} min/mile")
    print(f"Temperature: {test_input.temp_c}°C ({test_input.temp_c * 9/5 + 32:.0f}°F)")
    print(f"Humidity: {test_input.humidity_pct}%")
    print(f"Gut Training: {test_input.gut_training}")
    print(f"Sweat Rate Category: {test_input.sweat_rate_category}")
    print()
    
    # Run the algorithm
    result = plan_run(test_input)
    
    # Print results in a readable format
    print("=== Results ===")
    print(f"Duration: {result['summary']['duration_h']:.2f} hours")
    print(f"MET: {result['summary']['met']:.1f}")
    print(f"Net Calories: {result['summary']['net_kcal_transport']} kcal")
    print(f"Gross Calories: {result['summary']['gross_kcal']} kcal")
    print()
    
    print("Pre-Run Nutrition:")
    print(f"  Carbs: {result['pre_run']['carb_g']}g")
    print(f"  Protein: {result['pre_run']['protein_g']}g")
    print(f"  Fat: {result['pre_run']['fat_g']}g")
    print(f"  Water: {result['pre_run_hydration']['main_ml'] + result['pre_run_hydration']['topoff_ml']:.0f}ml")
    print(f"  Sodium: {result['pre_run_hydration']['sodium_mg']}mg")
    print()
    
    print("During-Run Nutrition:")
    print(f"  Carb Rate: {result['during_run']['carb_per_h_g']}g/h")
    print(f"  Total Carbs: {result['during_run']['total_carb_g']}g")
    print(f"  Water Rate: {result['during_run_hydration']['fluid_lph_plan'] * 1000:.0f}ml/h")
    print(f"  Sodium Rate: {result['during_run_hydration']['sodium_mgph_target']}mg/h")
    print()
    
    print("Post-Run Recovery:")
    print(f"  Carbs: {result['after_run']['carb_g']}g")
    print(f"  Protein: {result['after_run']['protein_g']}g")
    print(f"  Water: {result['after_run_hydration']['rehydration_l'] * 1000:.0f}ml")
    print(f"  Sodium: {result['after_run_hydration']['rehydration_sodium_mg']}mg")
    print()
    
    print("=== Full JSON Output ===")
    print(json.dumps(result, indent=2))

# Endurance Run Fueling & Hydration Planner

A lightweight Python module for **race-day fueling and hydration** planning that combines:
- ACSM metabolic equations (walk/run switch) → **MET** → **gross kcal**
- **Absolute carbohydrate g/h bands** with adjustments (gut training, intensity, body mass) and **absorption caps**
- **Pre / During / After** macro guidance (carbs, protein, fat)
- **Fluids & sodium** for **before / during / after**, with
  - **Sweat-rate**: use a measured value or pick a category (`light | medium | heavy`)
  - **Environment**: temperature (°C) & humidity (%) to scale fluid needs

> ⚠️ This tool supports education and planning. It’s **not medical advice**. Individual tolerances vary; practice changes in training.

---

## Features

- **Walk vs run**: switches to the ACSM **walking** VO₂ equation below ~4.0 mph (~15:00/mi) to avoid overestimated MET.
- **Energy**: exact ACSM gross kcal (`kcal/min = (MET*3.5*kg)/200`) + **net transport** kcal (~1.0 kcal·kg⁻¹·km⁻¹).
- **Carb fueling**: updated duration-based **bands**: 0–30 (≤1.0h), 30–45 (1.0–2.0h), 45–60 (2.0–3.0h), 60–75 (3.0–4.0h), 75–90 (>4.0h) g/h with nudges from **MET**, **gut training**, **body mass**, a high‑intensity floor (if duration >1.1h and MET >8, low end ≥30 g/h), and **absorption caps** (60–65 g/h glucose-only; ~90–100 g/h dual-source).
- **Hydration**: running-friendly **fluid band** (0.4–0.8 L/h) adjusted for **mass**, **intensity**, and **environment** (scaled 0.85–1.30), clamped for gut comfort.
- **Sodium**: targets from **measured loss** (50–70% of hourly loss) or **category bands** (300–1200 mg/h) with heat bumps.
- **Pre/During/After**: macros + fluid & sodium recommendations for each phase.

---

## Install

Copy the module into your project, or import from the path where you saved it (e.g., `run_fueling_env_sweat_v4.py`).

```bash
# Example: place next to your script
your_project/
├─ run_fueling_env_sweat_v4.py
└─ your_script.py
```

---

## Quick Start

```python
from run_fueling_env_sweat_v4 import RunInput, plan_run, GutTraining, CarbSource, SweatSodium, SweatRateCat

inputs = RunInput(
    distance_miles=20.0,
    pace_min_per_mile=9 + 39/60,      # 9:39/mi
    weight_kg=48.0,
    gut_training=GutTraining.MODERATE,
    carb_source=CarbSource.DUAL,
    time_before_run_min=120,
    # Hydration & sodium
    sweat_sodium=SweatSodium.MEDIUM,
    drink_sodium_mg_per_l=700,
    # Sweat rate: pick one
    optional_sweat_rate_lph=None,             # or e.g., 0.9 if measured
    sweat_rate_category=SweatRateCat.HEAVY,   # used when measured is None
    # Environment (optional; defaults to moderate if omitted)
    temp_c=24.0,
    humidity_pct=70.0
)

plan = plan_run(inputs)
print(plan["summary"])
print(plan["during_run"])
print(plan["during_run_hydration"])
```

---

## API Reference

### `RunInput` (dataclass)

| Field | Type | Default | Notes |
|---|---|---|---|
| `distance_miles` | `float` | — | Total distance of the run |
| `pace_min_per_mile` | `float` | — | Pace in **min/mile** |
| `weight_kg` | `float` | — | Body mass in kg |
| `gut_training` | `GutTraining` | `MODERATE` | `LOW` / `MODERATE` / `HIGH` |
| `carb_source` | `CarbSource` | `DUAL` | `GLUCOSE_ONLY` vs `DUAL` (glucose+fructose) |
| `time_before_run_min` | `int` | `120` | Minutes before start for substantial pre-run feeding |
| `sweat_sodium` | `SweatSodium` | `MEDIUM` | Low/Medium/High sweater sodium concentration (≈400/800/1200 mg/L) |
| `drink_sodium_mg_per_l` | `int` | `500` | Sodium in your sports drink (mg per liter) |
| `optional_sweat_rate_lph` | `Optional[float]` | `None` | **Measured** sweat rate (L/h). If provided, used for planning & post-run deficit |
| `sweat_rate_category` | `SweatRateCat` | `MEDIUM` | Used when measured rate is not provided. Maps to ~0.45/0.75/1.10 L/h and is environment-adjusted |
| `temp_c` | `Optional[float]` | `None` | Ambient temperature in °C (used to scale fluids) |
| `humidity_pct` | `Optional[float]` | `None` | Relative humidity in % (used to scale fluids) |
| `age, sex, height_cm` | Optional | `None` | Currently **not used** (reserved if you later add BMR) |

### `plan_run(input: RunInput) -> dict`

Returns a nested dictionary with these top-level keys:

- `summary` → `duration_h`, `met`, `gross_kcal`, `net_kcal_transport`
- `environment` → `temp_c`, `humidity_pct`, `env_multiplier`, `label`
- `pre_run` → `carb_g`, `protein_g`, `fat_g`
- `pre_run_hydration` → `main_ml`, `topoff_ml`, `sodium_mg`
- `during_run` → `carb_per_h_g`, `protein_per_h_g`, `fat_per_h_g`, `band_low`, `band_high`, `cap`, `raw`, `total_carb_g`, `total_protein_g`, `total_fat_g`
- `during_run_hydration` → `environment`, `env_multiplier`, `fluid_lph_low`, `fluid_lph_high`, `fluid_lph_plan`, `sweat_rate_lph_used`, `sweat_rate_method`, `drink_na_mg_per_l`, `sodium_method`, `sodium_mgph_low`, `sodium_mgph_high`, `sodium_mgph_target`, `sodium_from_drink_mgph`, `sodium_gap_mgph`
- `after_run` → `carb_g`, `protein_g`, `fat_g`
- `after_run_hydration` → If measured sweat-rate: `deficit_l`, `rehydration_l`, `rehydration_sodium_mg`; else `rehydration_l`, `rehydration_sodium_mg`

### Helper functions (optional to use)

- `met_from_pace(min_per_mile)` → MET (walk/run switch per ACSM)
- `gross_kcal(weight_kg, duration_min, met)` → exact ACSM gross kcal
- `net_kcal_transport_cost(weight_kg, distance_miles)` → net kcal via cost-of-transport
- `recommend_carbs_per_hour(duration_h, met, weight_kg, gut_training, carb_source)` → dict with band/target/cap

---

## Output Format — Band vs Target

- **Pre-run**: carbs (**target g**), protein (**target g**), fat (**target g**), fluids (**target mL** main + top-off), sodium (**target mg**).  
- **During-run**:
  - carbs: **band (g/h)** + **target (g/h)**; also shows **cap**, **raw** pick, and any **floor adjustment** (implicit when high-intensity short-mid duration pushes low end to ≥30 g/h).
  - protein: **target (g/h)** (0 for ≤3.5 h)
  - fat: **target (g/h)** (0 for ≤3.5 h)
  - fluids: **band (L/h)** + **target plan (L/h)**
  - sodium: **band (mg/h)** + **target (mg/h)**; also **from drink (mg/h)** and **gap (mg/h)**
- **After-run**: carbs (**target g**), protein (**target g**), fat (**target g**), rehydration fluids (**target L**), sodium (**target mg**).

---

## Physiology & Assumptions (short version)

- **ACSM equations** (level ground):  
  - Running: `VO2 = 0.2·v + 3.5`; Walking: `VO2 = 0.1·v + 3.5` (v in m/min). `MET = VO2/3.5`.  
  - Gross kcal: `kcal/min = (MET·3.5·kg)/200`.
- **Net transport** energy: ~`1.0 kcal·kg⁻¹·km⁻¹` (rule-of-thumb for running).
- **Carb g/h bands** now include an intermediate 30–45 g/h bracket for ~1–2 h events; high-intensity safeguard ensures ≥30 g/h when duration >1.1 h and MET >8.
- **Hydration**: base **0.4–0.8 L/h** for running, tilted by mass/intensity; scaled 0.85–1.30 by **environment**; clamped to **0.3–1.2 L/h** for GI practicality while running.
- **Sodium**: either from **measured loss** (50–70% of hourly loss) or **category** bands (300–1200 mg/h) with heat bumps (+50/100/150 mg/h for warm/hot/very hot).

---

## Examples

**A. Measured sweat-rate, hot/humid**

```python
plan = plan_run(RunInput(distance_miles=20.0, pace_min_per_mile=9.65, weight_kg=60,
                         optional_sweat_rate_lph=1.0,  # measured
                         drink_sodium_mg_per_l=900,
                         temp_c=28.0, humidity_pct=70.0))
print(plan["during_run_hydration"])
```

**B. Category-based, warm**

```python
plan = plan_run(RunInput(distance_miles=12.0, pace_min_per_mile=8.5, weight_kg=72,
                         sweat_rate_category=SweatRateCat.HEAVY, 
                         temp_c=22.0, humidity_pct=65.0))
print(plan["during_run_hydration"])
```

---

## Notes & Limits

- Flat level-ground ACSM equations (no grade or wind).  
- Designed for **running**; cyclists can often tolerate higher fluids/CHO caps.  
- Always **practice** your plan in training before race day.  
- If using aggressive CHO targets (>90 g/h), use **dual-source** fuels and **gut training**.

---

## License

Specify your preferred license (e.g., MIT, Apache-2.0).

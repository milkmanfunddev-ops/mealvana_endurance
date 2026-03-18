# Algorithm Research Notes

## Rachel & Xuan Corrections (V2/V3 -> V4/Current)

Rachel and Xuan identified 4 errors in the original algorithm. Both experts are fully aligned.

### Correction 1: Pre-Workout Carbs
- **Before**: Cumulative windows (meal + snack + top-up added together = 2.5-7 g/kg)
- **After**: Linear formula: 1 g/kg per hour (e.g., 3h = 3 g/kg)
- **Research**: ISSN Position Stand (Kerksick 2017) - "1-4 g/kg for 1-4 hours"

### Correction 2: Intensity Does NOT Affect Carb Amount
- **Before**: Zone-weighted multipliers changed the g/kg value
- **After**: Intensity only affects the SUGGESTED timing window, not the g/kg calculation
- **Research**: No evidence that intensity changes pre-workout carb needs

### Correction 3: During Carbs Are NOT Body-Weight Dependent
- **Before**: Body weight was factored into during-workout carb targets
- **After**: Absolute g/hr ranges from research (Table 1 bands)
- **Research**: Jeukendrup 2014 - "independent of body weight"

### Correction 4: Gut Training Uses Multipliers, Not Hard Caps
- **Before**: Fixed caps (e.g., 70/90/110 g/hr) that flattened the band
- **After**: Multipliers (0.7x / 1.0x / 1.2x) that scale the entire band
- **Research**: Jeukendrup 2017, Costa 2019 - gut training improves tolerance

---

## Changes Made (2026-03-11)

### Brick Penalty Added
- **What**: 20% carb reduction for run segments that follow a bike segment
- **Why**: GI blood diversion after cycling reduces absorption capacity
- **Source**: Blog reference: "20-30% reduction in run carb targets after bike leg"
- **Implementation**: Conservative 20% (factor of 0.80 applied to run carb rate)

### Weight-Based Transition Carbs
- **What**: Replaced fixed carb values with weight-based (T1: 0.3 g/kg, T2: 0.35 g/kg)
- **Why**: Fixed values don't scale for different athlete sizes
- **Source**: Original v2/v3 spec
- **Scope**: Carbs only - sodium and hydration remain as fixed duration-based values

---

## Pre-Workout Sodium: Range-Based Approach (2026-03-13)

### The "Dead Zone" Discovery

Research review revealed that pre-workout sodium falls into three evidence-based zones:

| Zone | Range | Evidence |
|------|-------|----------|
| Normal dietary | 200-500mg | Adequate for most athletes from food alone |
| Dead zone | 500-2500mg | **No evidence of benefit** over normal dietary |
| Loading protocol | 3000-4500mg | Proven hyperhydration benefit (Sims 2007) |

Our previous algorithm calculated targets in the 300-1250mg range (based on sweat sodium and environment) — squarely in the dead zone. These targets were:
- Too precise for a metric that has no single "correct" value
- Impossible to hit accurately because high-carb foods bring variable sodium (0-380mg/serving)
- Not supported by research as beneficial compared to normal dietary sodium

### New Approach

Replaced fixed targets with floor+ceiling ranges by meal type:
- Full meal (>=2.5h): 200-2000mg (accommodates heavy athletes needing 250-330g carbs)
- Snack (1.0-2.5h): 100-1000mg
- Top-up (<1.0h): 0-400mg

### Key Insight

Pre-workout sodium is a **byproduct of carb delivery**, not a target in its own right. The algorithm's job is to deliver carbs; as long as the sodium that comes along with the food falls in a safe range, it's acceptable.

During-exercise sodium is where precision matters — sweat sodium varies 200-2000 mg/L across athletes and replacement rate impacts performance. Pre-workout sodium is just food sodium.

### Sources
- Sims et al. 2007: Sodium loading (3000-4500mg) with glycerol for hyperhydration
- Baker 2016, 2017: Sweat sodium variability (230-1840 mg/L in 506 athletes) — relevant for during-exercise, not pre-exercise
- ACSM Position Stand: Pre-exercise sodium for hyperhydration only, not general recommendation
- Neither Rachel nor Xuan corrected our pre-workout sodium formulas — likely because precise pre-workout sodium isn't a clinical priority

---

## Version History

| Version | Status | Key Change |
|---------|--------|------------|
| V2 | Deprecated | Original spec, cumulative pre-workout, hard gut caps |
| V3 | Deprecated | Added personas/examples, same formula errors as V2 |
| V4 | Implemented | Rachel/Xuan corrections applied |
| V4+ | Live | + brick penalty + weight-based transitions |
| V4++ (current) | Test suite | + range-based sodium/hydration |

---

## Key Research Citations

| Citation | What It Validates |
|----------|------------------|
| Kerksick 2017 (ISSN) | Pre-workout 1-4 g/kg for 1-4 hours |
| Jeukendrup 2014 | During carbs NOT weight-dependent |
| Baker 2017 | Sweat sodium 200-2000 mg/L (506 athletes) |
| Cox 2010 | Gut training adaptation |
| Moore 2009 | Protein 20g plateau for MPS |
| Van Wijck 2012 | Splanchnic blood flow 80% reduction during exercise |
| Sims 2007 | Sodium loading (3000-4500mg) for pre-exercise hyperhydration |

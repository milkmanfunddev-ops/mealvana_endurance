---
title: ""
---

# Mealvana Macro Algorithm V3

**Edge Function:** `generate-macros-v3/index.ts` | **March 2026** | Rachel/Xuan corrected

---

## 1. BEFORE Workout

**Carbs** = `weight_kg x min(hours_before, 4.0)` g/kg, minimum 0.5 g/kg [<a href="#rachel-1">R1</a>, <a href="#ref-kerksick">Kerksick 2017</a>]. Minimum 0.5 floor: <span style="color:#c0392b">**NO JUSTIFICATION**</span>

Intensity does NOT change the g/kg -- it only suggests an ideal timing window. [<a href="#rachel-2">R2</a>]

| Hours Before | Type | Carbs | Protein | Fat | Hydration |
|---|---|---|---|---|---|
| >= 2.5h | Full Meal | wt x hrs g/kg [<a href="#rachel-1">R1</a>] | wt x 0.25 g/kg <span style="color:#c0392b">**NO JUST.**</span> | wt x 0.4 g/kg [<a href="#blog-pre-workout">Blog</a>: 0.3-0.5] | wt x 6.5 ml/kg [<a href="#ref-sawka">Sawka 07</a>: 5-7] |
| 1.0-2.5h | Snack | wt x hrs g/kg [<a href="#rachel-1">R1</a>] | wt x 0.15 g/kg <span style="color:#c0392b">**NO JUST.**</span> | 5g [<a href="#blog-pre-workout">Blog</a>: <10g] | wt x 5.5 ml/kg <span style="color:#c0392b">**NO JUST.**</span> |
| < 1.0h | Top-up | wt x hrs g/kg [<a href="#rachel-1">R1</a>] | 0g | 0g | 250 ml <span style="color:#c0392b">**NO JUST.**</span> |
| Fasted | None | 0g | 0g | 0g | 0 |

**Pre-workout sodium** <span style="color:#c0392b">**-- NO JUSTIFICATION for this entire section. No research source supports these specific values or formulas. [<a href="#ref-baker">Baker 2017</a>] provides sweat sodium concentration ranges (200-2000 mg/L) during exercise, but no guidance on pre-workout sodium intake amounts.**</span>

Base by sweat category: Low=300, Med=450, High=600 mg. Hot environment adds +100mg.

| Window | Sodium | Included When |
|---|---|---|
| Meal | base + env_bump | Full meal only |
| Snack | (base + env_bump) x 0.5 | Snack + Full meal |
| Top-up | env_bump + 100 | All types |

Total = sum of included windows. Accumulates because athlete eats multiple times.

---

## 2. DURING Workout

### Carbohydrates

**Step 1** -- Duration band (absolute g/hr, NOT body-weight dependent) [<a href="#rachel-3">R3</a>, <a href="#ref-jeukendrup-2014">Jeukendrup 2014</a>]:

| Duration | Band (g/hr) | | Duration | Band (g/hr) |
|---|---|---|---|---|
| < 60 min | 0 - 30 | | 150 - 240 min | 60 - 90 |
| 60 - 90 min | 30 - 60 | | > 240 min | 80 - 100 |
| 90 - 150 min | 45 - 60 | | | |

These bands appear in our [<a href="#blog-carb-bands">Blog Table</a>] and are informed by [<a href="#ref-jeukendrup-2014">Jeukendrup 2014</a>] and [<a href="#ref-kerksick">Kerksick 2017</a>], but **the exact breakpoint values (why 45-60 and not 40-65, etc.) are Mealvana's own creation.** The underlying research gives general guidelines (e.g., "30-60 g/hr", "up to 90 g/hr") which we synthesized into these specific 5-band ranges.

**Step 2** -- Multiply entire band by gut training factor [<a href="#rachel-4">R4</a>, <a href="#ref-jeukendrup-2017">Jeukendrup 2017</a>, <a href="#ref-costa">Costa 2019</a>]:
Low = 0.7x | Moderate = 1.0x | High = 1.2x

**Step 3** -- Target = midpoint of scaled band. <span style="color:#c0392b">**NO JUSTIFICATION**</span> -- [<a href="#rachel-4">Rachel</a>] recommended displaying as a range; we chose midpoint for our food selection algorithm.

**Step 4** -- Cap at sport ceiling [<a href="#blog-sport-ceilings">Blog</a>, <a href="#ref-pfeiffer">Pfeiffer 2012</a>]:

| Sport | Ceiling | Why Different from Running | Source |
|---|---|---|---|
| Running | 70 g/hr | Baseline. Vertical impact causes mechanical GI jostling, limiting tolerance. | [<a href="#blog-sport-ceilings">Blog</a>: 50-70, <a href="#ref-pfeiffer">Pfeiffer 2012</a>] |
| Cycling | 120 g/hr | Stable seated position eliminates impact-related GI stress; athletes can tolerate ~70% more carbohydrate. | [<a href="#blog-sport-ceilings">Blog</a>: 80-120, <a href="#ref-pfeiffer">Pfeiffer 2012</a>] |
| Swimming | 0 g/hr | Cannot eat or drink during the activity. All fueling shifts to before-phase or brick transitions (§4). | [<a href="#blog-sport-ceilings">Blog</a>] |

Steps 1-3 are identical for all three sports — same duration bands, same gut training multipliers, same midpoint selection. The sport ceiling is the **only** differentiator. This means gut-trained cyclists on long rides can realize carb rates that would be capped for runners.

*Example (run): 2hr run, moderate gut* -- Band 45-60 x 1.0 = 45-60, midpoint 52.5, cap 70 → **52.5 g/hr x 2h = 105g**
*Example (cycle): 3hr ride, high gut* -- Band 60-90 x 1.2 = 72-108, midpoint 90, cap 120 → **90 g/hr x 3h = 270g**
*Example (swim): 45min swim, any gut* -- Ceiling = 0 → **0g during** (fuel in before-phase)

### Hydration & Sodium

**Sweat rate** [<a href="#ref-baker">Baker 2017</a>]: Light=0.75, Medium=1.25, Heavy=2.0 L/hr. <span style="color:#c0392b">**NO JUSTIFICATION for exact tier values**</span> -- Baker provides continuous data, not these tiers.

**Temp adjustment**: `adjusted = base x (1.0 + max(0, (temp_C - 20) x 0.04))`. <span style="color:#c0392b">**NO JUSTIFICATION**</span> for 0.04 coefficient.

**Sodium concentration** [<a href="#ref-baker">Baker 2016</a>]: Low=550, Med=925, High=1150 mg/L. <span style="color:#c0392b">**NO JUSTIFICATION for exact tier values**</span> -- Baker provides continuous distribution (200-2000 mg/L), not these tiers.

| Formula | Rate | Source |
|---|---|---|
| Sodium | sweat_rate x sodium_conc x **0.60** | [<a href="#blog-sodium">Blog</a>]: 50-80% range. 60% is our choice. |
| Hydration | sweat_rate x 1000 x **0.75** | [<a href="#ref-sawka">Sawka 2007</a>]: ~80%. 75% is our choice. |

**Sport applicability:** Hydration and sodium formulas above apply identically to running and cycling — sweat rate categories, environmental adjustments, and replacement percentages (75% hydration, 60% sodium) are not sport-differentiated. <span style="color:#c0392b">**NO JUSTIFICATION**</span> for using identical hydration parameters across running and cycling — [<a href="#ref-baker">Baker 2017</a>] studied 506 athletes across sports but does not validate sport-agnostic application of our specific tier values. Swimming receives **0 ml hydration and 0 mg sodium** during the activity (physically impossible to drink while swimming).

---

## 3. AFTER Workout

| Macro | Formula | Source |
|---|---|---|
| Carbs | wt x 1.0 g/kg (< 2h) or 1.2 g/kg (>= 2h) | [<a href="#blog-post-workout">Blog</a>, <a href="#ref-kerksick">Kerksick 2017</a>]: 1.0-1.2 g/kg/hr |
| Carbs (fasted) | x1.2 boost | <span style="color:#c0392b">**NO JUSTIFICATION**</span> |
| Protein | wt x 0.30 g/kg (fed) or 0.35 g/kg (fasted) | [<a href="#blog-post-workout">Blog</a>, <a href="#ref-moore">Moore 2009</a>]: 0.25-0.4 g/kg |
| Fat | wt x 0.20 g/kg | <span style="color:#c0392b">**NO JUSTIFICATION**</span> |

**Post-workout hydration:**

| Macro | Formula | Source |
|---|---|---|
| Sodium | clamp(deficit x 0.50, 300, 700) mg | <span style="color:#c0392b">**NO JUSTIFICATION**</span> for 50% factor and 300-700 clamp |
| Hydration | max(500, deficit x 1.50) ml | [<a href="#ref-shirreffs">Shirreffs 1996</a>]: 150% of losses. 500ml min: <span style="color:#c0392b">**NO JUST.**</span> |

---

## 4. BRICK Workouts (Multi-Sport)

All Before/During/After formulas apply per-segment. Additional rules:

**Brick penalty**: Run after bike = carb rate x **0.80** (20% reduction) [<a href="#blog-brick">Blog</a>: 20-30%, <a href="#rachel-5">R5: Van Wijck 2012</a>]

**Transitions** -- <span style="color:#c0392b">**NO JUSTIFICATION for transition values. T1/T2 carb rates and all duration thresholds are Mealvana's own.**</span>

| Total Duration | T1 Carbs | T2 Carbs | Na (T1/T2) | Water (T1/T2) |
|---|---|---|---|---|
| < 90 min | 0 | 0 | 0 / 0 | 0 / 0 |
| 90-180 min | 0 | 0 | 0 / 0 | 50 / 50 |
| 180-420 min | wt x 0.30 | wt x 0.35 | 150 / 100 | 150 / 100 |
| 420+ min | wt x 0.30 | wt x 0.35 | 200 / 150 | 200 / 150 |

**Swimming**: 0 nutrition during (cannot eat/drink). [<a href="#blog-sport-ceilings">Blog</a>]

---

## 5. Energy & Environment

**Running MET** (ACSM): `VO2 = 0.2 x speed_m/min + 3.5` (run) or `0.1 x speed + 3.5` (walk). `MET = VO2 / 3.5` [<a href="#ref-acsm">ACSM</a>]

**Gross kcal** = `MET x 3.5 x weight_kg / 200 x duration_min` [<a href="#ref-acsm">ACSM</a>]

**Net kcal**: Running = `1.0 x wt x dist_km` [<a href="#ref-margaria">Margaria 1963</a>] | Cycling = `wt x dist x 0.3-0.5` <span style="color:#c0392b">**NO JUST.**</span> | Swimming = `3.5 x wt x dist_km` <span style="color:#c0392b">**NO JUST.**</span>

**Environment** -- <span style="color:#c0392b">**NO JUSTIFICATION for exact breakpoints and multiplier values. Informed by [<a href="#ref-sawka">Sawka 2007</a>] and [<a href="#ref-baker">Baker 2017</a>] but tiers are Mealvana's own.**</span>

| Condition | Multiplier | | Condition | Multiplier |
|---|---|---|---|---|
| <= 10C | 0.85 (cool) | | <= 30C or 75-85% | 1.2 (hot) |
| <= 20C, <= 60% | 1.0 (temperate) | | > 30C or > 85% | 1.3 (very hot) |
| <= 25C or 60-75% | 1.1 (warm) | | | |

---

<div style="page-break-before: always;"></div>

# APPENDIX A: Rachel's Consultation Notes

<a id="rachel-1"></a>

## Rachel Note #1: Pre-Workout Carb Calculation

**Recommendation:** x g/kg for x hours of pre-workout window (e.g., 3-hour window = 3 g/kg total)

**Key clarification:** The total amount scales with time, but gets *distributed* across eating opportunities -- not stacked/cumulated at each window.

**Implementation:** Pre-workout carb calculation is directly linked to pre-workout window length (app already does this correctly). **v3 error:** Calculated each sub-window separately and added them together, resulting in excessive carb recommendations. Should be one total distributed across windows.

---

<a id="rachel-2"></a>

## Rachel Note #2: Intensity Affects Window, Not g/kg

**Recommendation:** Harder/longer workouts -> longer ideal pre-workout window -> more total carbs (because more hours). But g/kg per hour stays constant at ~1.

**Example:** If you wake up 30 min before a hard workout, the recommendation is still just ~0.5 g/kg top-off -- intensity doesn't change that math.

**Implementation:** Suggest an ideal pre-workout window based on intensity/duration, clearly marked as "(ideal)". Allow user to select a different window based on their schedule. Calculate carbs based on the window they choose. **v3 error:** Used intensity as a multiplier in the carb calculation. Remove this -- intensity only influences the suggested window, not the g/kg formula.

---

<a id="rachel-3"></a>

## Rachel Note #3: During Carbs Are Absolute, Not Body-Weight Dependent

**Recommendation:** Use g/hr bands based on workout duration, not body weight. Gut absorption capacity doesn't scale with body mass.

**Research-based bands (for moderate gut training):** Refer to v3 Table 1

**Implementation:** Remove any body-weight scaling from during-workout carb calculations. These bands represent the 1.0x baseline for moderately gut-trained athletes.

---

<a id="rachel-4"></a>

## Rachel Note #4: Gut Training Multipliers

**Recommendation:** Gut training level scales the entire band up or down -- not just where you fall within a fixed band.

**Multipliers:**

| Level | Factor | Effect |
|---|---|---|
| Low gut training | 0.7x | Reduced capacity, scale band down |
| Moderate gut training | 1.0x | Baseline, use research bands as-is |
| High gut training | 1.2x | Expanded capacity, scale band up |

**Example for 120-min workout (base band: 45-60 g/hr):**

| Level | Factor | Result |
|---|---|---|
| Low gut | 0.7x | 31-42 g/hr |
| Moderate | 1.0x | 45-60 g/hr |
| High gut | 1.2x | 54-72 g/hr |

**Implementation:** Apply multiplier to both ends of the band, preserving the range. Rachel suggested display as a range (e.g., "54-72 g/hr") not a single number; however, we may need to use the target for now. **v3 error:** Used hard caps instead of multipliers. Remove caps; use scaled ranges.

---

<a id="rachel-5"></a>

## Rachel Note #5: Blood Diverts from Gut During Exercise

Van Wijck et al. (2012): "The redistribution of blood flow... significantly reduces blood flow to the gut, leading to hypoperfusion and gastrointestinal compromise."

Ter Steege & Kolkman (2012): "With prolonged duration and/or intensity, the splanchnic blood flow may be decreased by 80% or more."

**Mechanism:** Sympathetic nervous system activation during exercise causes vasoconstriction in splanchnic organs. Blood redirected to working muscles, heart, lungs, skin. Splanchnic blood flow can decrease 43-80% during maximal exercise.

**Algorithm Implication:** Supports longer pre-workout windows for high-intensity exercise and the brick penalty (run after bike absorption is reduced).

---

<a id="rachel-research"></a>

## Rachel's Research Literature Verification

### 1. Pre-Workout Carb Timing: 1-4 g/kg for 1-4 Hours -- VERIFIED

ISSN Position Stand confirms: "glycogen levels are best maintained or increased by consuming high carbohydrate (1-4 g/kg/day) meals or snacks for several hours before commencement of training or competition."

Multiple sources support linear relationship: 1 g/kg at 1 hour, 2 g/kg at 2 hours, up to 4 g/kg at 3-4 hours.

**Key Source:** Kerksick et al. (2017). ISSN Position Stand: Nutrient Timing.

### 2. During-Exercise Carbs NOT Body-Weight Dependent -- STRONGLY VERIFIED

Jeukendrup (2014): "Carbohydrate intake advice is independent of body weight as well as training status." "There appears to be no correlation between BW and exogenous carbohydrate oxidation. The reason for this lack of correlation is probably that the limiting factor is carbohydrate absorption and absorption is largely independent of BW." "These results clearly show that there is no rationale for expressing carbohydrate recommendations for athletes per kilogram of BW."

**Key Source:** Jeukendrup A. (2014). "A Step Towards Personalized Sports Nutrition." Sports Medicine, 44(S1), 25-33.

### 3. Cannot Replenish Glycogen During Exercise -- VERIFIED

Recent review (Endocrine Reviews, 2025): "CHO ingestion reduces liver glycogenolysis, preserves blood glucose, and paradoxically accelerates muscle glycogen breakdown."

Consumed carbs during exercise: maintain blood glucose, spare liver glycogen, do NOT replenish muscle glycogen stores.

### 4. Gut Training Improves Tolerance -- VERIFIED

Jeukendrup & colleagues (2022): "While the concept of training with high carbohydrate intakes to improve tolerance seems warranted, it remains to be established whether such practice leads to improved absorption."

Human studies show: "The gut is indeed adaptable and this can be used as a practical method to increase exogenous carbohydrate oxidation."

**Key Sources:** Jeukendrup (2017). "Training the Gut for Athletes." Costa et al. (2019). "Gut-training: impact of two weeks repetitive gut-challenge."

### 5. Glycogen Storage Requires Water -- VERIFIED

Fernandez-Elias et al. (2015): "Each gram of glycogen is stored in human muscle with at least 3 g of water."

### 6. Avoid Glycogen-Based Predictions -- VALIDATED

High individual variability. Cannot measure real-time glycogen during exercise. Rachel's recommendation to use research-based ranges instead of glycogen predictions is well-supported.

---

<div style="page-break-before: always;"></div>

# APPENDIX B: Xuan's Notes

<a id="xuan-notes"></a>

There are the main points:

1. **Pre-Workout Carb Calculation: 1 g/kg per Hour of Pre-Workout Window** -- Recommendation: x g/kg for x hours of pre-workout window (e.g., 3-hour window = 3 g/kg total). Key clarification: The total amount scales with time, but gets distributed across eating opportunities -- not stacked/cumulated at each window. v3 error: Calculated each sub-window separately and added them together, resulting in excessive carb recommendations.

2. **Intensity Affects Pre-Workout Window, Not g/kg Directly** -- Harder/longer workouts -> longer ideal pre-workout window -> more total carbs (because more hours). But g/kg per hour stays constant at ~1. v3 error: Used intensity as a multiplier in the carb calculation. Remove this.

3. **During-Workout Carbs: Absolute Ranges, Not Body-Weight Dependent** -- Use g/hr bands based on workout duration, not body weight. Gut absorption capacity doesn't scale with body mass. Refer to v3 Table 1.

4. **During-Workout Carbs: Gut Training Applies Multipliers to the Band** -- Gut training level scales the entire band up or down. Low (0.7x), Moderate (1.0x), High (1.2x). v3 error: Used hard caps instead of multipliers.

---

<div style="page-break-before: always;"></div>

# APPENDIX C: Mealvana Blog Post

<a id="blog-post"></a>

**"How Mealvana Calculates Your Fueling: The Science Behind Your Personalized Nutrition Plan"**
Published: January 21, 2026 | URL: https://endurance.mealvana.io/blog/2026/01/21/how-mealvana-calculates-race-fueling/

---

<a id="blog-carb-bands"></a>

## Duration-Based Carbohydrate Targets

| Duration | Target | Rationale |
|---|---|---|
| <60 min | 0-30 g total | Mouth rinse sufficient |
| 60-90 min | 30-60 g/hr | Maintain blood glucose |
| 90 min - 2.5 hr | 45-60 g/hr | Delay glycogen depletion |
| 2.5 - 4 hr | 60-90 g/hr | Multiple transportable carbs required |
| 4+ hr | 80-100+ g/hr | Maximum sustainable with real food |

<a id="blog-pre-workout"></a>

## Pre-Workout Timing Windows

| Timing | Carbs (g/kg) | Fat | Fiber | Notes |
|---|---|---|---|---|
| 3-4 hr before | 1-4 | 0.3-0.5 g/kg | Moderate | Full gastric emptying |
| 1-2 hr before | 1-2 | <10g | Low | Snack window |
| 30-60 min before | 0.5-1 | 0g | 0g | Simple carbs only |
| <30 min before | Not recommended | 0g | 0g | Emergency only (25-50g) |

<a id="blog-sport-ceilings"></a>

## Sport-Specific Differences

| Sport | Practical Carb Ceiling | Pre-Workout Buffer | Rationale |
|---|---|---|---|
| Running | 50-70 g/hr | 3-4 hours minimum | GI jostling, vertical impact |
| Cycling | 80-120 g/hr | 2-3 hours acceptable | Stable platform, no impact |
| Swimming | Pre/post only | 2-3 hours minimum | Horizontal position, no during-activity fueling |

<a id="blog-sodium"></a>

## Sodium Personalization

Sweat sodium concentration ranges from 200-2,000 mg/L (10x variation). Sodium Loss (mg/hr) = Sweat Rate (L/hr) x Sodium Concentration (mg/L). Target 50-80% replacement during exercise. Hot conditions: 300-600 mg/hr minimum.

<a id="blog-post-workout"></a>

## Post-Workout Recovery

| Goal | Timing | Target | Evidence |
|---|---|---|---|
| Glycogen resynthesis | 0-30 min, then hourly | 1.0-1.2 g/kg/hr | Maximal 4 hours post |
| Muscle protein synthesis | Within 2 hours | 0.25-0.4 g/kg (20-40g) | ~3g leucine threshold |
| Rehydration | 2-4 hours | 150% of fluid losses | With 500-700 mg/L sodium |

<a id="blog-brick"></a>

## Brick Workouts

> "20-30% reduction in run carb targets after bike leg"

## Key Quotes

On carbohydrate absorption: "Single carbohydrate sources max out at ~60 g/hr due to SGLT1 transporter saturation." "Glucose + fructose (using GLUT5 transporter) enables 90-120 g/hr absorption."

On intensity: "Duration, intensity (TSS/IF), sport type, environmental conditions, personal tolerance, and training context all influence recommendations simultaneously."

On gut training: "Athletes who consistently practice high carbohydrate intake during training upregulate intestinal transporters (SGLT1 and GLUT5), enabling higher absorption rates."

---

<div style="page-break-before: always;"></div>

# APPENDIX D: Published Research References

<a id="ref-kerksick"></a>

## Kerksick et al. (2017) -- ISSN Position Stand: Nutrient Timing

International Society of Sports Nutrition Position Stand. Confirms pre-workout 1-4 g/kg for 1-4 hours. Post-workout 1.0-1.2 g/kg/hr for glycogen resynthesis.
PubMed: https://pubmed.ncbi.nlm.nih.gov/28919842/

<a id="ref-jeukendrup-2014"></a>

## Jeukendrup (2014) -- Personalized Sports Nutrition

"A Step Towards Personalized Sports Nutrition: Carbohydrate Intake During Exercise." Sports Medicine, 44(S1), 25-33. Establishes that during-exercise carbohydrate recommendations are independent of body weight.
PubMed: https://pubmed.ncbi.nlm.nih.gov/24791914/

<a id="ref-jeukendrup-2004"></a>

## Jeukendrup (2004) -- Carbohydrate Intake During Exercise

Established the 60 g/hr ceiling for single carbohydrate sources via SGLT1 transporter.
PubMed: https://pubmed.ncbi.nlm.nih.gov/15212750/

<a id="ref-jeukendrup-2017"></a>

## Jeukendrup (2017) -- Training the Gut for Athletes

"Training the Gut for Athletes." Sports Medicine, 47(S1), 101-110. Evidence that gut is adaptable and gut training can increase exogenous carbohydrate oxidation.
PubMed: https://pubmed.ncbi.nlm.nih.gov/28508671/

<a id="ref-costa"></a>

## Costa et al. (2019) -- Gut Training

"Gut-training: impact of two weeks repetitive gut-challenge." 2-week gut training protocols show measurable improvements in tolerance.

<a id="ref-baker"></a>

## Baker et al. (2016-2017) -- Sweat Sodium Variability

Studied 506 athletes. Sweat sodium concentration: 230-1,840 mg/L. Established the wide individual variation in sweat composition.
PubMed: https://pubmed.ncbi.nlm.nih.gov/26553489/ (2016), https://pubmed.ncbi.nlm.nih.gov/28332114/ (2017)

<a id="ref-sawka"></a>

## Sawka et al. (2007) -- ACSM Position Stand: Exercise and Fluid Replacement

ACSM Position Stand. Recommends 5-7 ml/kg pre-exercise hydration 4 hours before. During exercise: match ~80% of sweat losses.
PubMed: https://pubmed.ncbi.nlm.nih.gov/17277604/

<a id="ref-moore"></a>

## Moore et al. (2009) -- Protein Dose-Response

Established 20g protein plateau for muscle protein synthesis. Supports 0.25-0.4 g/kg range for recovery.
PubMed: https://pubmed.ncbi.nlm.nih.gov/19056590/

<a id="ref-shirreffs"></a>

## Shirreffs et al. (1996) -- Post-Exercise Rehydration

Established that 150% of fluid losses needed for complete rehydration due to ongoing renal losses.
PubMed: https://pubmed.ncbi.nlm.nih.gov/8897382/

<a id="ref-pfeiffer"></a>

## Pfeiffer et al. (2012) -- GI Problems in Endurance Sports

Documented gastrointestinal problems vary by sport type. Running has higher GI distress than cycling due to mechanical jostling.
PubMed: https://pubmed.ncbi.nlm.nih.gov/21775906/

<a id="ref-van-wijck"></a>

## Van Wijck et al. (2012) -- Splanchnic Hypoperfusion

"Physiology and pathophysiology of splanchnic hypoperfusion and intestinal injury during exercise." Splanchnic blood flow reduced up to 80% during intense exercise.
PubMed: https://pubmed.ncbi.nlm.nih.gov/22253445/

<a id="ref-margaria"></a>

## Margaria et al. (1963) -- Running Energy Cost

Established running energy cost of approximately 1 kcal/kg/km, independent of speed.

<a id="ref-acsm"></a>

## ACSM Metabolic Equations

Standard ACSM metabolic equations for exercise prescription. Running VO2: 0.2 x speed (m/min) + 3.5. Walking VO2: 0.1 x speed (m/min) + 3.5. Gross kcal: MET x 3.5 x weight / 200 x duration.

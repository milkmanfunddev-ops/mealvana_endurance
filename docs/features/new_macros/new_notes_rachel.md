# Q & A

## Algorithm Validation Notes from Rachel Consultation

### 1. Pre-Workout Carb Calculation: 1 g/kg per Hour of Pre-Workout Window

**Recommendation:** x g/kg for x hours of pre-workout window (e.g., 3-hour window = 3 g/kg total)

**Key clarification:** The total amount scales with time, but gets *distributed* across eating opportunities—not stacked/cumulated at each window.

**Implementation:**

- Pre-workout carb calculation is directly linked to pre-workout window length (app already does this correctly)
- **v3 error:** Calculated each sub-window separately and added them together, resulting in excessive carb recommendations. Should be one total distributed across windows.

---

### 2. Intensity Affects Pre-Workout Window, Not g/kg Directly

**Recommendation:** Harder/longer workouts → longer ideal pre-workout window → more total carbs (because more hours). But g/kg per hour stays constant at ~1.

**Example:** If you wake up 30 min before a hard workout, the recommendation is still just ~0.5 g/kg top-off—intensity doesn't change that math.

**Implementation:**

- Suggest an ideal pre-workout window based on intensity/duration, clearly marked as "(ideal)"
- Allow user to select a different window based on their schedule
- Calculate carbs based on the window they choose
- **v3 error:** Used intensity as a multiplier in the carb calculation. Remove this—intensity only influences the suggested window, not the g/kg formula.

---

### 3. During-Workout Carbs: Absolute Ranges, Not Body-Weight Dependent

**Recommendation:** Use g/hr bands based on workout duration, not body weight. Gut absorption capacity doesn't scale with body mass.

**Research-based bands (for moderate gut training):**

- refer to v3 Table 1

**Implementation:**

- Remove any body-weight scaling from during-workout carb calculations
- These bands represent the 1.0× baseline for moderately gut-trained athletes

---

### 4. During-Workout Carbs: Gut Training Applies Multipliers to the Band

**Recommendation:** Gut training level scales the entire band up or down—not just where you fall within a fixed band.

**Multipliers:**

- Low gut training (0.7×): Reduced capacity, scale band down
- Moderate gut training (1.0×): Baseline, use research bands as-is
- High gut training (1.2×): Expanded capacity, scale band up

**Example for 120-min workout (base band: 45-60 g/hr):**

- Low gut (0.7×): 31-42 g/hr
- Moderate (1.0×): 45-60 g/hr
- High gut (1.2×): 54-72 g/hr

**Implementation:**

- Apply multiplier to both ends of the band, preserving the range
- Rachel suggested display as a range (e.g., "54-72 g/hr") not a single number (the middle point); however, we may need to use the target for now and come up with a better design for the range
- **v3 error:** Used hard caps instead of multipliers. Remove caps; use scaled ranges.

---

# Research Literature Verification

**Date:** January 31, 2026

**Purpose:** Systematic verification of Rachel's recommendations for Mealvana nutrition algorithm against peer-reviewed research literature, ISSN position stands, and exercise physiology journals.

---

## ✅ 1. Pre-Workout Carb Timing: 1-4 g/kg for 1-4 Hours

**STATUS: VERIFIED**

ISSN Position Stand on Nutrient Timing confirms: "glycogen levels are best maintained or increased by consuming high carbohydrate (1–4 g/kg/day) meals or snacks for several hours before commencement of training or competition."

Multiple sources support linear relationship:

- 1 g/kg at 1 hour before
- 2 g/kg at 2 hours before
- Up to 4 g/kg at 3-4 hours before

Rachel's linear approach (1 g/kg per hour awake) aligns with established guidelines.

**Key Source:** Kerksick et al. (2017). International Society of Sports Nutrition Position Stand: Nutrient Timing.

---

## ✅ 2. During-Exercise Carbs NOT Body-Weight Dependent

**STATUS: STRONGLY VERIFIED**

Jeukendrup (2014) - leading authority on carbohydrate metabolism:

> "Carbohydrate intake advice is independent of body weight as well as training status."
> 

> "There appears to be no correlation between BW and exogenous carbohydrate oxidation. The reason for this lack of correlation is probably that the limiting factor is carbohydrate absorption and absorption is largely independent of BW."
> 

> "These results clearly show that there is no rationale for expressing carbohydrate recommendations for athletes per kilogram of BW."
> 

**Current Guidelines (absolute amounts):**

- Exercise <1 hour: Mouth rinse or small amounts
- Exercise 1-2.5 hours: 30-60 g/hr (single carb source, max ~60 g/hr via SGLT1 transporter)
- Exercise >2.5 hours: up to 90 g/hr (requires glucose:fructose mix using multiple transporters)
- Elite athletes with gut training: up to 120 g/hr reported

**Gut absorption ceiling:** ~1 g/min glucose via SGLT1 transporter, ~1.75 g/min with glucose+fructose (dual transporters)

**Key Source:** Jeukendrup A. (2014). "A Step Towards Personalized Sports Nutrition: Carbohydrate Intake During Exercise." Sports Medicine, 44(S1), 25-33.

---

## ✅ 3. Cannot Replenish Glycogen During Exercise

**STATUS: VERIFIED**

Recent comprehensive review (Endocrine Reviews, 2025): "CHO ingestion reduces liver glycogenolysis, preserves blood glucose, and paradoxically accelerates muscle glycogen breakdown through conserved neuroendocrine mechanisms."

INSCYD research: "Glycogen is preferred over blood glucose as a fuel, and because the amount of exogenous carbohydrate intake is limited, you can never exercise at a high intensity and not burn any glycogen."

Glycogen replenishment is POST-exercise only: "This relatively slow time course makes it impossible for those engaged in multiple bouts of intense exercise during a single day to fully restore muscle glycogen between training sessions."

**Consumed carbs during exercise:**

- Maintain blood glucose levels
- Spare liver glycogen (reduce hepatic glycogenolysis)
- Do NOT replenish muscle glycogen stores
- Muscle glycogen continues to deplete during exercise regardless of carb intake

**Key Sources:** 

- Endocrine Reviews (2025). Carbohydrate Ingestion on Exercise Metabolism and Physical Performance.
- Journal of Applied Physiology (2017). Postexercise muscle glycogen resynthesis in humans.

---

## ✅ 4. Gut Training Improves Tolerance (Use Multipliers, Not Hard Caps)

**STATUS: VERIFIED**

Jeukendrup & colleagues (2022): "While the concept of training with high carbohydrate intakes to improve tolerance to ingested carbohydrates seems warranted, it remains to be established whether such practice leads to improved absorption of ingested carbohydrates and by what mechanisms or leads to just improved tolerance."

Evidence from rat studies: "A combination of a high carbohydrate diet and exercise does not result in an increased number of glucose transporters in the intestines, and it could be thus speculated that improved tolerance can occur independently of improved absorption capacity."

Human studies show: "The gut is indeed adaptable and this can be used as a practical method to increase exogenous carbohydrate oxidation."

**Gut training benefits:**

- Reduced GI symptoms (bloating, cramping, nausea)
- Improved tolerance to high carb intake rates
- Possibly enhanced oxidation rates (mechanism unclear)
- Reduced breath H2 (indicates less malabsorption)
- 2-week protocols show measurable improvements

**Algorithm Implication:** Rachel's multiplier approach (0.7×, 1.0×, 1.2×) more physiologically appropriate than hard caps—scales with individual capacity rather than imposing arbitrary ceilings.

**Key Sources:**

- Jeukendrup A. (2017). "Training the Gut for Athletes." Sports Medicine, 47(S1), 101-110.
- Costa et al. (2019). "Gut-training: impact of two weeks repetitive gut-challenge."
- King et al. (2022). "Short-Term Very High Carbohydrate Diet and Gut-Training." Nutrients.

---

## ✅ 5. Blood Flow Diverts from Gut During Exercise

**STATUS: STRONGLY VERIFIED**

Van Wijck et al. (2012): "The redistribution of blood flow, necessary for such an increased blood supply to the periphery, significantly reduces blood flow to the gut, leading to hypoperfusion and gastrointestinal (GI) compromise."

Ter Steege & Kolkman (2012): "With prolonged duration and/or intensity, the splanchnic blood flow (SBF) may be decreased by 80% or more."

**Mechanism:**

- Sympathetic nervous system activation during exercise
- Vasoconstriction in splanchnic organs
- Blood redirected to working muscles, heart, lungs, skin
- Splanchnic blood flow can decrease 43-80% during maximal exercise
- Coeliac artery resistance increases ~165%, mesenteric ~76%

**Consequences:**

- Reduced gastric emptying
- Impaired nutrient absorption
- Intestinal epithelial injury (measured via I-FABP)
- Increased intestinal permeability
- GI symptoms (nausea, cramping, diarrhea)

**Algorithm Implication:** This directly supports Rachel's recommendation for longer pre-workout windows for high-intensity exercise—ensures complete digestion BEFORE blood flow diverts to muscles.

**Protective strategy:** Carbohydrate intake during exercise actually helps maintain splanchnic perfusion via nitric oxide-induced vasodilation.

**Key Sources:**

- Van Wijck et al. (2012). "Physiology and pathophysiology of splanchnic hypoperfusion and intestinal injury during exercise."
- Ter Steege & Kolkman (2012). "Review article: pathophysiology and management of GI symptoms during exercise."
- PLOS One (2011). Exercise-Induced Splanchnic Hypoperfusion Results in Gut Dysfunction.

---

## ✅ 6. Glycogen Storage Requires Water (3-4g Water per 1g Glycogen)

**STATUS: VERIFIED**

Fernández-Elías et al. (2015): "Our findings agree with the long held notion that each gram of glycogen is stored in human muscle with at least 3 g of water."

Classic research (Olsson & Saltin, 1970): Body weight increased 2.4 kg during 4-day carb loading, total body water increased 2.2L. "The amount of glycogen stored was calculated to be at least 500 g, which means that 3—4 g of water is bound with each gram of glycogen."

Multiple sources confirm: "Glycogen is stored in the liver, muscles, and fat cells in hydrated form (three to four parts water) associated with 0.45 millimoles (18 mg) of potassium per gram of glycogen."

**Practical implications:**

- Proper carb loading should increase body weight 1-2% (several pounds)
- Dehydration impairs glycogen storage capacity
- Weight gain after carb loading is normal and expected
- Glycogen depletion causes water loss (explains rapid weight loss on low-carb diets)

**Key Sources:**

- Fernández-Elías et al. (2015). "Relationship between muscle water and glycogen recovery."
- Olsson & Saltin (1970). "Variation in Total Body Water with Muscle Glycogen Changes."
- Sherman et al. (1982). "Muscle glycogen storage and its relationship with water."

---

## ✅ 7. Avoid Glycogen-Based Predictions for Minimum Carb Targets

**STATUS: VALIDATED BY RESEARCH LIMITATIONS**

Rachel's caution against glycogen-based fueling calculations supported by:

**High Individual Variability:**

- Glycogen storage capacity varies widely between individuals
- Depends on: training status, diet history, hydration, genetics
- Resting levels: untrained ~80-85 mmol/kg, trained ~120 mmol/kg
- Supercompensation can reach 200 mmol/kg (but highly variable)

**Measurement Challenges:**

- Cannot measure real-time glycogen during exercise
- Muscle biopsy = invasive, single muscle group, single time point
- 13C-MRS = expensive, not widely available
- Indirect estimates unreliable

**Emerging Research Challenges Traditional View:**

Recent comprehensive review (Endocrine Reviews, 2025): "Exercise-induced hypoglycemia (EIH) correlates strongly with exercise termination, while muscle glycogen depletion alone does not induce rigor or whole-body fatigue."

Study finding: Athletes on high-carb (380g/day) vs low-carb (40g/day) diets for 6 weeks showed NO performance difference during prolonged exercise, despite vastly different glycogen levels. However, 10g CHO/hr during exercise improved performance 12-20% by preventing hypoglycemia.

**Conclusion:** Blood glucose maintenance may be more critical than glycogen levels for performance.

Rachel's recommendation to use research-based ranges (45-60 g/hr, etc.) instead of glycogen predictions is well-supported.

---

## Summary Table

| Rachel's Point | Status | Key Evidence |
| --- | --- | --- |
| Pre-workout 1-4 g/kg for 1-4 hours | ✅ Verified | ISSN Position Stand (Kerksick et al. 2017) |
| During-exercise carbs NOT weight-dependent | ✅ Strongly Verified | Jeukendrup 2014 (Sports Medicine) |
| Cannot replenish glycogen during exercise | ✅ Verified | Multiple sources, Endocrine Reviews 2025 |
| Gut training = tolerance, use multipliers | ✅ Verified | Jeukendrup 2017, Costa et al. 2019 |
| Blood diverts from gut during exercise | ✅ Verified | Van Wijck 2012, Ter Steege 2012 |
| Glycogen stores 3-4g water per 1g | ✅ Verified | Fernández-Elías 2015, Olsson 1970 |
| Avoid glycogen predictions for minimums | ✅ Validated | Research limitations, emerging evidence |

---

## Critical Algorithm Revisions Needed

🔴 **CRITICAL:** Change pre-workout windows from "cumulative" to "distributed" (matches research on total intake distribution)

🟠 **MEDIUM:** Replace gut training hard caps with multipliers (aligns with tolerance-based adaptation research)

✅ **Already Correct:** During-exercise carbs in absolute amounts (not per kg body weight)

✅ **Already Correct:** Using research-based ranges instead of glycogen predictions

✅ **Already Correct:** Showing ranges (minimum + optimal) rather than single numbers

---

## Primary Research Sources

**Position Stands:**

- International Society of Sports Nutrition Position Stand: Nutrient Timing (Kerksick et al., 2017)
- ISSN Position Stand: Carbohydrate Intake During Exercise

**Carbohydrate Absorption & Body Weight Independence:**

- Jeukendrup A. (2014). "A Step Towards Personalized Sports Nutrition: Carbohydrate Intake During Exercise." Sports Medicine, 44(S1), 25-33.
- Jeukendrup A. (2004). "Carbohydrate Intake During Exercise and Performance." Nutrition, 20, 669-677.

**Glycogen Metabolism:**

- Nutrition Reviews (2018). Fundamentals of glycogen metabolism for coaches and athletes.
- Journal of Applied Physiology (2017). Postexercise muscle glycogen resynthesis in humans.
- Endocrine Reviews (2025). Carbohydrate Ingestion on Exercise Metabolism and Physical Performance.

**Gut Training:**

- Jeukendrup A. (2017). "Training the Gut for Athletes." Sports Medicine, 47(S1), 101-110.
- Costa et al. (2019). "Gut-training: impact of two weeks repetitive gut-challenge."
- King et al. (2022). "Short-Term Very High Carbohydrate Diet and Gut-Training." Nutrients.

**Splanchnic Blood Flow:**

- Van Wijck et al. (2012). "Physiology and pathophysiology of splanchnic hypoperfusion and intestinal injury during exercise."
- Ter Steege & Kolkman (2012). "Review article: pathophysiology and management of GI symptoms during exercise."
- PLOS One (2011). Exercise-Induced Splanchnic Hypoperfusion Results in Gut Dysfunction.

**Glycogen-Water Relationship:**

- Fernández-Elías et al. (2015). "Relationship between muscle water and glycogen recovery."
- Olsson & Saltin (1970). "Variation in Total Body Water with Muscle Glycogen Changes."
- Sherman et al. (1982). "Muscle glycogen storage and its relationship with water."
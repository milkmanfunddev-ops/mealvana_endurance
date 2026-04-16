# Post-Workout Recovery Templates — Research, Plan & Deliverables

**Date:** April 8, 2026
**Author:** Mealvana Team + Claude Research
**Status:** Implementation Plan
**Follows pattern of:** `during_workout_templates` (table + seed migration)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Elite Athlete Recovery Practices](#elite-athlete-recovery-practices)
3. [Sports Science Guidelines](#sports-science-guidelines)
4. [Coach & Dietitian Recommendations](#coach--dietitian-recommendations)
5. [Community Insights (Reddit, Forums)](#community-insights)
6. [Recovery Product Landscape](#recovery-product-landscape)
7. [Template Design Decisions](#template-design-decisions)
8. [Post-Workout Templates (Full Catalog)](#post-workout-templates-full-catalog)
9. [New Foods Required](#new-foods-required)
10. [Database Schema](#database-schema)
11. [Deliverables Checklist](#deliverables-checklist)

---

## 1. Executive Summary

Post-workout recovery nutrition is the third pillar of Mealvana's template system (after pre-workout and during-workout). The science is clear: consuming the right combination of carbohydrates and protein within 0–60 minutes post-exercise accelerates glycogen resynthesis, muscle protein synthesis, and reduces inflammation.

### Key Numbers
- **Carbohydrate target:** 1.0–1.2 g/kg body weight
- **Protein target:** 20–40g (0.25–0.4 g/kg), with ≥3g leucine
- **Carb:Protein ratio:** 3:1 to 4:1 for endurance; 2:1 to 3:1 for shorter/strength sessions
- **Timing:** 0–30 min optimal, 30–60 min still highly effective, >2 hr = 50% less effective
- **Rehydration:** 150% of fluid losses, with 500–700 mg/L sodium

### Template Categories
We define **two timing windows** for post-workout templates:

| Window | Name | Description | Food Form |
|--------|------|-------------|-----------|
| 0–30 min | Immediate Recovery | Liquid/easy-to-consume, minimal prep | Shakes, smoothies, chocolate milk, parfaits |
| 30–120 min | Recovery Meal | Full meals, can be eaten at home/restaurant | Bowls, burritos, sandwiches, plates |

### Deliverables
1. ✅ Research document (this file)
2. ✅ `post_workout_template_foods.json` — new foods for template_foods catalog
3. ✅ SQL migration: `post_workout_templates` table + RLS + seed 20 templates
4. ✅ SQL migration: new template_foods entries for recovery-specific foods
5. ✅ Updated `templates_database.md` with finalized post-workout section

---

## 2. Elite Athlete Post-Workout Recovery Practices

> Only includes athletes where specific post-workout meals, timing, or recovery protocols are documented. General diet or during-workout fueling excluded.

### Lucy Charles-Barclay (Ironman World Champion 2023)
- **Post-workout protocol:**
  - Protein shake within 30 minutes of finishing ANY session — team member has shake waiting at finish line for races
  - Pre-cooks chicken and rice BEFORE training so a real meal is ready the moment she returns
  - Post-race sequence: protein shake immediately → rehydration during anti-doping formalities → full protein+carb dinner
- **Documented post-workout meals:**
  - Rice bowls with chicken or fish + vegetables (pre-prepared, her go-to)
  - Smoothies with banana, berries, protein powder
- **Key insight:** Zero-delay recovery. Pre-cook meals before sessions so there's no gap between finishing and eating.
- **Sources:**
  - https://www.polar.com/blog/triathlon-recovery-lucy-charles-go-to-methods/
  - https://www.220triathlon.com/training/nutrition-training/lucy-charles-barclay-on-triathlon-nutrition

### Jan Frodeno (3x Ironman World Champion)
- **Post-workout smoothie recipe (his stated favorite):**
  - Banana + protein powder + raw milk + peanut butter + maca powder (equal parts)
- **Post-race protocol:** Physio waits at finish line with chocolate-flavored protein powder shake for immediate liquid recovery. Then allows himself a beer with friends for psychological decompression.
- **Day-after recovery:** Active recovery swim (not rest) to maintain circulation.
- **Key insight:** Simplicity + enjoyment. His smoothie recipe is 5 ingredients, repeatable daily, and he genuinely likes it.
- **Sources:**
  - https://themagic5.com/blogs/news/exploring-the-jan-frodeno-diet-nutrition-secrets-of-a-triathlon-champion
  - https://sportcoaching.co.nz/jan-frodeno-training-diet-nutrition/

### Lionel Sanders (Professional Long Course Triathlete)
- **Post-workout practices (current, reformed 2025):**
  - Post-swim: high-carbohydrate recovery drink
  - Post-run: hydration-focused recovery drink
  - Post-long-ride: large pasta meal
  - Travel/convenience: Core Power protein shakes
  - Home recovery: smoothie bowls with protein, fruit, granola
- **CAUTIONARY TALE:** Consumed 500-600g carbs after workouts for 14 years. November 2024 blood work: HbA1c 5.9% (pre-diabetic) despite world-class fitness. Now reformed — moving to whole-food carbs with fats and proteins, not pure sugar.
- **Key insight:** Post-workout recovery must be intensity-matched. Maximum carb recovery after every session is harmful long-term.
- **Sources:**
  - https://www.tri247.com/triathlon-news/elite/lionel-sanders-relative-energy-deficiency-update-august-2025
  - https://triathlonmagazine.ca/news/lionel-sanders-admits-himself-to-sugar-rehab/
  - https://triathlon.mx/blogs/triathlon-news/what-a-pro-triathlete-eats-in-a-day-lionel-sanders-nutrition-breakdown

### Sam Long (Professional Long Course Triathlete)
- **Post-workout practices:**
  - Post-swim: high-carbohydrate drinks
  - Post-run: hydration-focused recovery drink
  - Eggs are his #1 recovery food — "the single food item he could not live without" (leucine-rich, complete protein)
- **Key insight:** Routine matters. Same recovery foods repeatedly so there's no decision fatigue.
- **Sources:**
  - https://www.tri247.com/triathlon-news/elite/t100-singapore-triathlon-2025-sam-long-reaction
  - https://sur.co/blogs/athletes/catching-up-with-sam-long

### Sam Laidlow (Ironman World Championship Runner-Up 2022)
- **Post-workout practice:**
  - Immediate: Nduranz Regen recovery drink to replenish energy stores and reduce muscle damage
- **Key insight:** Uses a commercial recovery drink as a structured bridge to a full meal, not a replacement for one.
- **Sources:**
  - https://nduranz.com/blogs/feed/nutritional-strategy-that-earns-you-the-title-of-ironman-world-championship-runner-up

### Cody Beals (Professional Long Course Triathlete, Plant-Based)
- **Documented post-workout meals (from "What I Eat in a Day"):**
  - After 6-hour ride: plant-based stir fry with soy curls, vegetables, white rice
  - After swim/run: Vega Sport protein bar immediately, then avocado toast with eggs within 1 hour
  - Date square as quick recovery snack
  - Homemade lemon-ginger kombucha as recovery beverage
- **Key insight:** Plant-based athletes can hit recovery targets with creative combinations. Recovery begins within minutes of finishing.
- **Sources:**
  - https://www.codybeals.com/2020/01/my-pro-triathlon-diet/

### Daniela Ryf (4x Ironman World Champion)
- **Post-workout recovery scaled by session intensity (Fuelin color-coded system):**
  - **Red** (rest days): under 30g carbs per meal
  - **Yellow** (easy sessions): ~50g carbs per meal
  - **Green** (hard training): over 100g carbs per meal
- **Key insight:** Not every workout gets the same recovery nutrition. Periodize recovery carbs by session intensity.
- **Sources:**
  - https://en.triatlonnoticias.com/nutricion-deportiva/daniela-ryf-plan-nutricional-ironman/
  - https://fuelin.com/triathlon-daniela-ryf

### Gustav Iden (Ironman World Champion)
- **Post-workout approach:**
  - Chocolate milk as quick calorie source after sessions
  - Stays in a "kitchen rhythm" — gets calories in quickly after training by having food ready
  - Prioritizes speed of caloric intake over food optimization
- **Key insight:** Norwegian method summarized as "Train, eat, sleep, repeat." The eat part happens fast.
- **Sources:**
  - https://tri-today.com/2022/03/gustav-iden-at-altitude-preparing-for-st-george-train-eat-sleep-repeat-video/
  - https://www.maurten.com/magazine/maurten-meets-gustav-iden

### Taylor Knibb (T100 World Champion)
- **Post-workout practice:**
  - Dairy-free protein shake within 90 minutes post-workout (eliminated dairy in 2025 to address GI issues)
- **Key insight:** GI issues drive dietary elimination for recovery. App must support dairy-free recovery templates with equivalent nutritional profiles.
- **Sources:**
  - https://www.tri247.com/triathlon-news/elite/taylor-knibb-major-diet-change-gi-issues-t100-san-francisco-2025

### Tour de France Recovery (EF Pro Cycling, nutritionist Will Girling)
- **Immediately post-stage:** Gummy bears + tart cherry juice (fast carbs + concentrated anti-inflammatory polyphenols)
- **On team bus within 1 hour:** Rice plate with lean protein
- **Evening meal:** Rice, pasta, or potato dishes + lean meats + egg omelets
- **Key insight:** Even at the highest professional level, post-workout recovery is simple whole foods + strategic cherry juice for inflammation.
- **Sources:**
  - https://www.efprocycling.com/tips-recipes/tour-de-france-recovery-fueling/

---

## 3. Sports Science Guidelines

### ACSM (American College of Sports Medicine)
- **Carbohydrates:** 1.0–1.5 g/kg within first 30 min, continuing hourly for 4 hours if training again within 24 hr
- **Protein:** 15–25g high-quality protein post-exercise
- **Fluid:** Replace 150% of body weight lost; include sodium (500–700 mg/L)
- **Source:** Sawka et al., 2007; Thomas et al., 2016

### ISSN (International Society of Sports Nutrition)
- **Protein timing:** 20–40g protein per feeding, every 3–4 hours
- **Leucine threshold:** ≥3g leucine per serving to maximize MPS
- **Carb-protein co-ingestion:** Enhances glycogen resynthesis when carb intake is suboptimal (<1.2 g/kg/hr)
- **Protein type:** Whey superior to casein/soy for acute MPS (faster leucine delivery)
- **Source:** Kerksick et al., 2017 (ISSN Position Stand); Jäger et al., 2017

### IOC (International Olympic Committee)
- **Recovery nutrition priority:** Carbohydrate first, protein second
- **Practical window:** "As soon as practical after exercise"
- **Multi-session days:** Recovery nutrition CRITICAL between sessions
- **Anti-inflammatory:** Omega-3, tart cherry, polyphenol-rich foods recommended
- **Source:** Maughan et al., 2018 (IOC Consensus Statement)

### Key Research Findings (2024–2026)

**Protein needs higher than previously thought:**
Current evidence suggests endurance athletes need 1.8–2.0+ g/kg/day total (not just the older 1.2–1.6 g/kg recommendation). Recovery windows contribute significantly to daily totals.

**Chocolate milk meta-analysis validated:**
20+ studies confirm low-fat chocolate milk provides similar or superior results to commercial recovery drinks. Natural 3–4:1 carb:protein ratio, plus fluid, electrolytes, and calcium.
- Source: European Journal of Clinical Nutrition, 2018

**Tart cherry juice anti-inflammatory effect:**
Anthocyanins reduce inflammation markers (CRP) by up to 49%. Most effective when "pre-loaded" for 7–10 days before heavy training blocks. Dose: 8–16 oz/day.
- Source: JISSN, 2010; Howatson et al., 2010

**Leucine threshold confirmed at ~3g:**
30g of high-quality protein (whey, eggs, chicken) provides ~3g leucine, which maximizes muscle protein synthesis signaling.
- Source: Witard et al., 2014; Moore et al., 2015

**Recovery window wider than once believed:**
While 0–30 min is optimal for glycogen resynthesis rates, muscle protein synthesis benefits extend several hours post-exercise. The window matters most when training multiple times per day. When adequate protein is consumed BEFORE exercise, the urgency of immediate post-exercise protein is diminished.
- Source: Schoenfeld et al., 2013; Aragon & Schoenfeld, 2013

**Pre-sleep casein protein (UNDERUTILIZED):**
20–40g casein protein ~30 min before sleep increases overnight mitochondrial protein synthesis by 22–37% above placebo. Both whey and casein show benefit, but casein's slower digestion sustains amino acid availability overnight. Practical vehicles: cottage cheese, Greek yogurt, casein shake. Particularly relevant for evening training sessions.
- Source: PMC 7451833, PMC 10289916

**Lionel Sanders cautionary tale:**
14 years of 500-600g sugar/day led to HbA1c 5.9% (pre-diabetic) despite world-class fitness. Post-workout templates should be INTENSITY-MATCHED, not always maximum carb. Bob Seebohar's metabolic efficiency concept: easy sessions don't need aggressive refueling.
- Source: TRI247, Triathlon Magazine Canada

---

## 4. Coach & Dietitian Recommendations

### Joe Friel (Author, "The Triathlete's Training Bible")
- **Recovery priority order:** Hydrate → Carbohydrate → Protein
- **Immediate post-workout (within 30 min, HARD sessions only):** 200-500 calories depending on body size/intensity, primarily LIQUID form, fruit juice or chocolate milk or commercial drink
- **Protein:** ~10g (40 kcal) is adequate in immediate window — less than many recommend
- **Recommended ratio:** 4.5:1 carb:protein (higher carb than typical 4:1). Partnered with Infinit Nutrition on 5:1 "Recover" product.
- **First post-workout meal (starch focus):** Potato, sweet potato, yam preferred > bread/bagels/cereal/rice. "Vegetables are richer in micronutrients" than grains.
- **Key principle:** Recovery intensity should match training intensity — easy day = light recovery, hard day = aggressive refueling. The 30-min window is for hard/long sessions ONLY.
- **Accompanying recovery:** Leg elevation, 30-60 min nap, early bedtime
- **Source:** joefrieltraining.com, "The Triathlete's Training Bible"

### Asker Jeukendrup (Sports Nutrition Researcher, mysportscience.com)
- **Carbohydrate recommendations post-exercise:**
  - 1.0–1.2 g/kg/hr for first 4 hours when rapid recovery needed
  - High GI carbs preferred for faster glycogen resynthesis
  - Adding protein (0.3–0.4 g/kg) when carb intake is suboptimal
- **Practical application:** "The type of food matters less than hitting the targets"
- **Key insight:** Individualization > rigid protocols

### Allen Lim / Skratch Labs
- **Philosophy:** "Sports nutrition is about what you do in your kitchen, not on the bike"
- **Recovery staples from "The Feed Zone Cookbook" (co-authored with chef Biju Thomas):**
  - Rice cakes (savory, with eggs/bacon/cheese — Tour de France team food)
  - Beet juice for nitric oxide + recovery
  - Sweet potato + chicken bowls
  - Fresh fruit smoothies (uses Greek yogurt for protein, not powder)
- **Skratch Recovery Mix:** Updated to 5:1 carb:protein ratio (up from industry-standard 4:1). Uses complete milk protein (casein + whey blend, not isolate). Real fruit flavoring, probiotics + lactase for digestion. Non-GMO, GF, kosher.
- **Key insight:** Palatability matters — athletes won't eat what they don't enjoy. "Bridge to your next real meal from scratch."
- **Source:** skratchlabs.com, Pinkbike interview, Feed Zone Cookbook

### Bob Seebohar (Sports Dietitian, Metabolic Efficiency)
- **Recovery approach:** Depends on training phase
  - **Base/aerobic phase:** Lower carb recovery, emphasize protein + healthy fats
  - **Build/race phase:** Higher carb recovery, aggressive glycogen restoration
- **Metabolic efficiency concept:** Don't always need to aggressively refuel after easy sessions
- **Key insight:** Not every workout needs a 4:1 carb:protein recovery meal

### Precision Fuel & Hydration
- **Post-exercise rehydration:** Replace 150% of sweat losses
- **Sodium replacement:** Critical for sessions >60 min or heavy sweaters
- **Practical tip:** Salty foods (pretzels, broth, electrolyte drinks) alongside recovery meals
- **Carb recommendations:** 1.0–1.2 g/kg in first 30 min, then normal meals

### TrainerRoad (Ask a Cycling Coach Podcast)
- **Practical advice:** Build post-workout nutrition into routine — consistency beats optimization
- **Recovery drink recommendation:** 4:1 carb:protein immediately after every workout
- **Follow-up:** Normal meal within 1–2 hours
- **Key insight:** "The sooner you consume it, the sooner glycogen stores rebuild"

---

## 5. Community Insights

### Reddit r/triathlon
- **Most popular recovery foods mentioned:**
  1. Chocolate milk (overwhelmingly #1)
  2. Protein smoothies (banana + PB + protein powder + milk)
  3. Greek yogurt with granola and berries
  4. Bagel with peanut butter
  5. Eggs + toast after morning workouts
- **Common debate:** Engineered recovery products vs. whole foods
- **Consensus:** Whole foods preferred for daily training; engineered products for convenience/travel

### Reddit r/running
- **Most popular post-run recovery foods:**
  1. Chocolate milk
  2. Banana + peanut butter
  3. Overnight oats with protein
  4. PB&J sandwiches
  5. Greek yogurt parfaits
- **Long run specific:** Many runners crave salty foods (pretzels, ramen, pizza) after 2+ hour runs
- **Budget tip:** "Chocolate milk is $3 and works as well as any $40 recovery powder"

### Reddit r/cycling
- **Post-ride favorites:**
  1. Rice + chicken bowl
  2. Protein smoothie
  3. Burrito bowl
  4. Chocolate milk + banana
  5. Pasta with protein
- **Century ride recovery:** Emphasized need for both immediate liquid recovery AND a full meal within 2 hours

### Slowtwitch Forum
- **Triathlon-specific insights:**
  - Many long-course athletes use Core Power protein shakes (gas station convenient)
  - Debate between 3:1 vs 4:1 carb:protein ratios
  - Tart cherry juice gaining popularity among age-group athletes
  - Beef jerky + trail mix common for ultra-distance post-race
- **Key quote:** "The best recovery food is the one you'll actually eat consistently"

### TrainerRoad Forum
- **Cycling-specific:**
  - Recovery drinks immediately, followed by a real meal
  - Many athletes prep recovery smoothie bags (frozen) before rides
  - Emphasis on not skipping recovery nutrition even after easy rides

---

## 6. Recovery Product Landscape

### Recovery Drink Mixes
| Product | Carb:Protein | Carbs | Protein | Key Feature |
|---------|-------------|-------|---------|-------------|
| Skratch Recovery | 4:1 | 39g | 10g | Real fruit, clean ingredients |
| Hammer Recoverite | 3:1 | 32g | 10g | L-glutamine added |
| Tailwind Rebuild | 2:1 | 36g | 20g | Complete protein, vegan option |
| SiS REGO Rapid | 3:1 | 23g | 20g | Fast-absorbing whey isolate |
| Momentous Recovery | 2:1 | 25g | 20g | NSF Certified for Sport |

### Ready-to-Drink
| Product | Carbs | Protein | Key Feature |
|---------|-------|---------|-------------|
| Core Power Elite | 40g | 42g | Ultra-filtered milk, widely available |
| Core Power 26g | 26g | 26g | Lower calorie option |
| Fairlife | 13g | 30g | High protein, lactose-free |
| OWYN Plant Protein | 10g | 20g | Vegan, allergen-free |

### Classic Recovery Foods (Cost per serving)
| Food | Cost | Carbs | Protein | Notes |
|------|------|-------|---------|-------|
| Chocolate milk (16oz) | $1.50 | 52g | 16g | Best value recovery drink |
| Greek yogurt + granola | $2.50 | 45g | 25g | High protein, probiotics |
| PB&J + milk | $2.00 | 65g | 25g | Universal, portable |
| Banana + protein shake | $2.50 | 40g | 30g | Quick, minimal prep |

---

## 7. Template Design Decisions

### Architecture: Follows `during_workout_templates` Pattern

The `post_workout_templates` table mirrors the `during_workout_templates` schema:

```
post_workout_templates
├── template_number (INTEGER, UNIQUE) — sequential ID
├── name (TEXT) — human-readable name
├── formula (TEXT) — food combination description
├── recovery_window (TEXT) — 'immediate' (0-30 min) or 'meal' (30-120 min)
├── recovery_type (TEXT) — 'shake', 'smoothie', 'bowl', 'sandwich', 'snack', 'meal'
├── activity_types (TEXT[]) — running, cycling, swimming, triathlon
├── workout_intensity (TEXT[]) — easy, moderate, hard, race
├── component_food_names (TEXT[]) — references template_foods.name
├── component_ratios (JSONB) — maps food names to portions
├── target_carb_protein_ratio (TEXT) — '4:1', '3:1', '2:1'
├── allergens (TEXT[])
├── excluded_diets (TEXT[])
├── notes (TEXT)
├── is_active (BOOLEAN)
├── created_at, updated_at (TIMESTAMPTZ)
```

### Why This Schema (vs. Pre-Workout Pattern)

The `pre_workout_templates` table was designed for a solver algorithm — it defines food components that get scaled by body weight. Post-workout templates are more similar to `during_workout_templates`: they're **formula templates** that define food combinations for specific contexts.

Key additions vs. during_workout:
- `recovery_window` replaces `duration_brackets` — recovery is about time AFTER workout, not during
- `recovery_type` — categorizes the physical form of the recovery meal
- `workout_intensity` — recovery needs scale with workout intensity
- `target_carb_protein_ratio` — explicit ratio target for the template

### Template Selection Logic

```
Input: workout_type, workout_duration, workout_intensity, 
       time_available, dietary_restrictions, location

Step 1: Determine recovery window
  if time_available <= 30 min → immediate
  else → meal

Step 2: Calculate macro targets
  carb_target = body_weight_kg × intensity_multiplier
    easy: 0.8 g/kg | moderate: 1.0 g/kg | hard: 1.2 g/kg
  protein_target = max(20g, body_weight_kg × 0.3)
  cap protein at 40g

Step 3: Filter templates by window, diet, allergens

Step 4: Score templates by macro proximity + user preferences

Step 5: Return top 3 recommendations
```

---

## 8. Post-Workout Templates (Full Catalog)

### Immediate Recovery (0–30 Minutes) — Templates 1–10

#### Template 1: Classic Chocolate Milk
| Field | Value |
|-------|-------|
| **Formula** | Low-fat chocolate milk |
| **Recovery Window** | Immediate (0–30 min) |
| **Recovery Type** | Shake |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Easy, Moderate, Hard |
| **Component Foods** | `{chocolate_milk}` |
| **Component Ratios** | `{"chocolate_milk": 1.0}` |
| **Target Ratio** | 3:1 |
| **Allergens** | `{dairy}` |
| **Excluded Diets** | `{vegan, paleo}` |
| **Notes** | Most research-validated recovery drink. 20+ studies confirm equal/superior to commercial products. Natural 3:1 carb:protein ratio. Budget-friendly (~$1.50). Available everywhere. Endorsed by: Sam Long, countless community athletes. |

---

#### Template 2: Banana Berry Protein Smoothie
| Field | Value |
|-------|-------|
| **Formula** | Banana + Mixed Berries + Whey Protein + Greek Yogurt |
| **Recovery Window** | Immediate (0–30 min) |
| **Recovery Type** | Smoothie |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Moderate, Hard |
| **Component Foods** | `{banana, mixed_berries, whey_protein_powder, greek_yogurt}` |
| **Component Ratios** | `{"banana": 0.35, "mixed_berries": 0.20, "whey_protein_powder": 0.05, "greek_yogurt": 0.10}` |
| **Target Ratio** | 2:1 |
| **Allergens** | `{dairy}` |
| **Excluded Diets** | `{vegan}` |
| **Notes** | Antioxidant-rich from berries. Whey provides rapid leucine delivery (~3g). Greek yogurt adds casein (slow-release protein). Banana provides potassium + quick carbs. Used by: Frodeno, Lionel Sanders (smoothie bowl variant). Prep tip: freeze banana + berries in bags, blend in 60 sec. |

---

#### Template 3: Tart Cherry Recovery Shake
| Field | Value |
|-------|-------|
| **Formula** | Tart Cherry Juice + Whey Protein |
| **Recovery Window** | Immediate (0–30 min) |
| **Recovery Type** | Shake |
| **Activity Types** | Running, Cycling, Triathlon |
| **Workout Intensity** | Hard, Race |
| **Component Foods** | `{tart_cherry_juice, whey_protein_powder}` |
| **Component Ratios** | `{"tart_cherry_juice": 0.85, "whey_protein_powder": 0.15}` |
| **Target Ratio** | 2:1 |
| **Allergens** | `{dairy}` |
| **Excluded Diets** | `{vegan}` |
| **Notes** | Anti-inflammatory powerhouse. Anthocyanins reduce CRP by up to 49%. Best for hard sessions/race recovery. Most effective with 7–10 day pre-loading. Gaining popularity among age-group triathletes (Slowtwitch). Research: JISSN 2010, Howatson et al. 2010. |

---

#### Template 4: Recovery Protein Shake (Commercial)
| Field | Value |
|-------|-------|
| **Formula** | Recovery Drink Mix + Water/Milk |
| **Recovery Window** | Immediate (0–30 min) |
| **Recovery Type** | Shake |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Easy, Moderate, Hard |
| **Component Foods** | `{recovery_drink_mix, water}` |
| **Component Ratios** | `{"recovery_drink_mix": 1.0}` |
| **Target Ratio** | 3:1 to 4:1 |
| **Allergens** | `{dairy}` (varies by brand) |
| **Excluded Diets** | varies |
| **Notes** | Precise macros, pre-measured. Brands: Skratch Recovery (4:1), Hammer Recoverite (3:1), Tailwind Rebuild (2:1 vegan). Portable powder for travel/races. Consistent recommendation from TrainerRoad podcast. Used when time/facilities limited. |

---

#### Template 5: Greek Yogurt Parfait
| Field | Value |
|-------|-------|
| **Formula** | Greek Yogurt + Granola + Berries + Honey |
| **Recovery Window** | Immediate (0–30 min) |
| **Recovery Type** | Snack |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Easy, Moderate |
| **Component Foods** | `{greek_yogurt, granola, mixed_berries, honey}` |
| **Component Ratios** | `{"greek_yogurt": 0.15, "granola": 0.45, "mixed_berries": 0.25, "honey": 0.15}` |
| **Target Ratio** | 2.5:1 |
| **Allergens** | `{dairy, gluten}` |
| **Excluded Diets** | `{vegan}` |
| **Notes** | Solid food option for athletes who don't like liquid recovery. Greek yogurt = leucine-rich (17g protein per cup). Berries = antioxidants. Make-ahead in mason jar. Used by: Daniela Ryf (bircher muesli variant), Gustav Iden (skyr variant). Reddit favorite. |

---

#### Template 6: Bagel + Nut Butter + Banana
| Field | Value |
|-------|-------|
| **Formula** | Bagel + Peanut Butter + Banana + Milk |
| **Recovery Window** | Immediate (0–30 min) |
| **Recovery Type** | Snack |
| **Activity Types** | Running, Cycling, Triathlon |
| **Workout Intensity** | Moderate, Hard |
| **Component Foods** | `{bagel_large, peanut_butter, banana, milk_lowfat}` |
| **Component Ratios** | `{"bagel_large": 0.50, "peanut_butter": 0.05, "banana": 0.25, "milk_lowfat": 0.20}` |
| **Target Ratio** | 3:1 |
| **Allergens** | `{gluten, peanuts, dairy}` |
| **Excluded Diets** | `{vegan}` |
| **Notes** | Dense carb source (60g+ per bagel). Solid food for athletes who prefer chewing. Portable (eat driving home). Triathlete Magazine recommended: "475 calories, ideal ratio." Slowtwitch forum staple. Lower-fat variant: use PB2 powder. |

---

#### Template 7: Core Power Shake (Grab-and-Go)
| Field | Value |
|-------|-------|
| **Formula** | Core Power Elite Protein Shake |
| **Recovery Window** | Immediate (0–30 min) |
| **Recovery Type** | Shake |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Moderate, Hard |
| **Component Foods** | `{core_power_shake}` |
| **Component Ratios** | `{"core_power_shake": 1.0}` |
| **Target Ratio** | 1:1 (higher protein) |
| **Allergens** | `{dairy}` |
| **Excluded Diets** | `{vegan, paleo}` |
| **Notes** | Zero prep required. Available at gas stations, convenience stores. Ultra-filtered milk protein (42g). Perfect for travel/race morning. Used by: Lionel Sanders, many age-group athletes (Slowtwitch consensus). Long shelf life for stockpiling. |

---

#### Template 8: Oatmeal + Protein + Fruit
| Field | Value |
|-------|-------|
| **Formula** | Oatmeal + Whey Protein + Banana + Honey |
| **Recovery Window** | Immediate (0–30 min) |
| **Recovery Type** | Snack |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Moderate, Hard |
| **Component Foods** | `{oatmeal, whey_protein_powder, banana, honey}` |
| **Component Ratios** | `{"oatmeal": 0.40, "whey_protein_powder": 0.05, "banana": 0.35, "honey": 0.20}` |
| **Target Ratio** | 3:1 |
| **Allergens** | `{gluten, dairy}` |
| **Excluded Diets** | `{vegan}` |
| **Notes** | Dual carb source: complex (oats) + simple (banana, honey). Warming comfort food. Can use Kodiak cups for convenience. Gustav Iden reportedly uses porridge as recovery staple. After morning swim sessions particularly popular. |

---

#### Template 9: Plant-Based Recovery Smoothie
| Field | Value |
|-------|-------|
| **Formula** | Banana + Mixed Berries + Plant Protein + Oat Milk |
| **Recovery Window** | Immediate (0–30 min) |
| **Recovery Type** | Smoothie |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Moderate, Hard |
| **Component Foods** | `{banana, mixed_berries, plant_protein_powder, oat_milk}` |
| **Component Ratios** | `{"banana": 0.35, "mixed_berries": 0.20, "plant_protein_powder": 0.10, "oat_milk": 0.35}` |
| **Target Ratio** | 2:1 |
| **Allergens** | `{}` |
| **Excluded Diets** | `{paleo}` |
| **Notes** | Fully vegan/plant-based option. Pea+rice protein blend provides complete amino acid profile. Cody Beals uses Vega Sport protein for recovery. Oat milk adds carbs + creamy texture. May need slightly more total protein (30–35g) due to lower leucine density in plant protein. |

---

#### Template 10: PB&J + Milk (Classic)
| Field | Value |
|-------|-------|
| **Formula** | Whole Wheat Bread + Peanut Butter + Jam + Milk |
| **Recovery Window** | Immediate (0–30 min) |
| **Recovery Type** | Snack |
| **Activity Types** | Running, Cycling, Triathlon |
| **Workout Intensity** | Easy, Moderate, Hard |
| **Component Foods** | `{whole_wheat_bread, peanut_butter, jam, milk_lowfat}` |
| **Component Ratios** | `{"whole_wheat_bread": 0.30, "peanut_butter": 0.10, "jam": 0.15, "milk_lowfat": 0.45}` |
| **Target Ratio** | 3:1 |
| **Allergens** | `{gluten, peanuts, dairy}` |
| **Excluded Diets** | `{vegan}` |
| **Notes** | Universally available, budget-friendly (~$2). Reddit r/running #5 most popular. Allen Lim / Skratch Labs frequently references PB&J as "the perfect real food recovery." Comfort factor after hard workouts. Can eat half immediately, save half for later. |

---

### Recovery Meals (30–120 Minutes) — Templates 11–20

#### Template 11: Chicken Sweet Potato Bowl
| Field | Value |
|-------|-------|
| **Formula** | Grilled Chicken + Sweet Potato + Rice + Broccoli |
| **Recovery Window** | Meal (30–120 min) |
| **Recovery Type** | Bowl |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Moderate, Hard |
| **Component Foods** | `{grilled_chicken, sweet_potato, white_rice_cooked, broccoli}` |
| **Component Ratios** | `{"grilled_chicken": 0.05, "sweet_potato": 0.25, "white_rice_cooked": 0.40, "broccoli": 0.05}` |
| **Target Ratio** | 2:1 |
| **Allergens** | `{}` |
| **Excluded Diets** | `{vegan, vegetarian}` |
| **Notes** | Complete meal, ideal for dinner recovery. Meal-prep friendly (cook Sunday, portion containers). Chicken = lean, high leucine. Sweet potato + rice = dual carb sources. Used by: Lucy Charles (rice bowl variant), many pro triathletes. Allen Lim's Feed Zone staple. |

---

#### Template 12: Salmon Rice Bowl
| Field | Value |
|-------|-------|
| **Formula** | Salmon + Rice + Avocado + Vegetables |
| **Recovery Window** | Meal (30–120 min) |
| **Recovery Type** | Bowl |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Hard, Race |
| **Component Foods** | `{salmon, white_rice_cooked, avocado, mixed_vegetables}` |
| **Component Ratios** | `{"salmon": 0.05, "white_rice_cooked": 0.45, "avocado": 0.10, "mixed_vegetables": 0.05}` |
| **Target Ratio** | 2:1 |
| **Allergens** | `{fish}` |
| **Excluded Diets** | `{vegan, vegetarian}` |
| **Notes** | Anti-inflammatory focus — omega-3 EPA/DHA from salmon. Blumenfeld and Iden eat salmon 3–4x/week. Avocado adds healthy fats + potassium. Best for hard sessions where inflammation reduction is priority. Budget variant: canned salmon or tuna. |

---

#### Template 13: Breakfast Burrito
| Field | Value |
|-------|-------|
| **Formula** | Whole Wheat Tortilla + Scrambled Eggs + Black Beans + Cheese |
| **Recovery Window** | Meal (30–120 min) |
| **Recovery Type** | Sandwich |
| **Activity Types** | Running, Cycling, Triathlon |
| **Workout Intensity** | Moderate, Hard |
| **Component Foods** | `{whole_wheat_tortilla, scrambled_eggs, black_beans, cheddar_cheese}` |
| **Component Ratios** | `{"whole_wheat_tortilla": 0.30, "scrambled_eggs": 0.10, "black_beans": 0.30, "cheddar_cheese": 0.05}` |
| **Target Ratio** | 2:1 |
| **Allergens** | `{gluten, eggs, dairy}` |
| **Excluded Diets** | `{vegan}` |
| **Notes** | Perfect for morning workout recovery. Eggs = complete protein + leucine. Black beans = complex carbs + additional protein. Freezer-friendly: batch-make 5–7, wrap in foil, freeze. Microwave 2–3 min from frozen. Portable for on-the-go athletes. |

---

#### Template 14: Burrito Bowl (Chipotle-Style)
| Field | Value |
|-------|-------|
| **Formula** | Rice + Chicken/Steak + Black Beans + Vegetables + Salsa |
| **Recovery Window** | Meal (30–120 min) |
| **Recovery Type** | Bowl |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Moderate, Hard |
| **Component Foods** | `{white_rice_cooked, grilled_chicken, black_beans, salsa}` |
| **Component Ratios** | `{"white_rice_cooked": 0.45, "grilled_chicken": 0.05, "black_beans": 0.25, "salsa": 0.05}` |
| **Target Ratio** | 2:1 |
| **Allergens** | `{}` |
| **Excluded Diets** | `{vegan, vegetarian}` (with chicken) |
| **Notes** | Available at Chipotle/Qdoba/similar nationwide. Customizable macros (double protein, extra rice). No cooking required. Popular post-race meal — easy to find near finish lines. Reddit r/triathlon frequent recommendation. Order: rice, chicken, black beans, fajita veggies, mild salsa. |

---

#### Template 15: Pasta + Lean Protein
| Field | Value |
|-------|-------|
| **Formula** | Pasta + Marinara + Grilled Chicken + Side Salad |
| **Recovery Window** | Meal (30–120 min) |
| **Recovery Type** | Meal |
| **Activity Types** | Running, Cycling, Triathlon |
| **Workout Intensity** | Hard, Race |
| **Component Foods** | `{pasta_cooked, marinara_sauce, grilled_chicken}` |
| **Component Ratios** | `{"pasta_cooked": 0.55, "marinara_sauce": 0.10, "grilled_chicken": 0.05}` |
| **Target Ratio** | 3:1 |
| **Allergens** | `{gluten}` |
| **Excluded Diets** | `{vegan, vegetarian}` (with chicken) |
| **Notes** | Classic endurance athlete recovery meal. Lionel Sanders documented pasta as post-long-ride staple. Dense carbohydrate source for aggressive glycogen restoration. Marinara provides lycopene (antioxidant). Easy to meal-prep in bulk. |

---

#### Template 16: Recovery Beef Jerky + Trail Mix
| Field | Value |
|-------|-------|
| **Formula** | Beef Jerky + Trail Mix + Sports Drink |
| **Recovery Window** | Meal (30–120 min) |
| **Recovery Type** | Snack |
| **Activity Types** | Running, Cycling, Triathlon |
| **Workout Intensity** | Hard, Race |
| **Component Foods** | `{beef_jerky, trail_mix, sports_drink}` |
| **Component Ratios** | `{"beef_jerky": 0.05, "trail_mix": 0.55, "sports_drink": 0.40}` |
| **Target Ratio** | 2:1 |
| **Allergens** | `{tree_nuts}` |
| **Excluded Diets** | `{vegan, vegetarian}` |
| **Notes** | Portable, no refrigeration needed. Salty — replaces sodium lost through sweat. High leucine from jerky. Popular with ultra-marathon and ultra-triathlon athletes. Slowtwitch forum recommendation for post-race when no kitchen available. Dark chocolate chips in trail mix add antioxidants. |

---

#### Template 17: Eggs + Toast + Fruit
| Field | Value |
|-------|-------|
| **Formula** | Scrambled Eggs + Toast + Orange Juice |
| **Recovery Window** | Meal (30–120 min) |
| **Recovery Type** | Meal |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Easy, Moderate |
| **Component Foods** | `{scrambled_eggs, toast, orange_juice}` |
| **Component Ratios** | `{"scrambled_eggs": 0.05, "toast": 0.35, "orange_juice": 0.50}` |
| **Target Ratio** | 3:1 |
| **Allergens** | `{eggs, gluten}` |
| **Excluded Diets** | `{vegan}` |
| **Notes** | Simple breakfast recovery after morning workouts. Eggs = complete protein. OJ = fast carbs + vitamin C + potassium. Toast = additional carbs + sodium. Easy to prepare (10 min). Reddit r/running community favorite for post-morning-run breakfast. |

---

#### Template 18: Rice + Stir-Fry Vegetables + Tofu (Vegan)
| Field | Value |
|-------|-------|
| **Formula** | Rice + Stir-Fry Vegetables + Tofu + Soy Sauce |
| **Recovery Window** | Meal (30–120 min) |
| **Recovery Type** | Bowl |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Moderate, Hard |
| **Component Foods** | `{white_rice_cooked, mixed_vegetables, tofu, soy_sauce}` |
| **Component Ratios** | `{"white_rice_cooked": 0.55, "mixed_vegetables": 0.10, "tofu": 0.15, "soy_sauce": 0.01}` |
| **Target Ratio** | 2:1 |
| **Allergens** | `{soy}` |
| **Excluded Diets** | `{paleo}` |
| **Notes** | Fully vegan/plant-based recovery meal. Cody Beals documented eating plant-based stir fry with soy curls + rice after 6-hour ride. Tofu provides complete plant protein. Soy sauce adds sodium for electrolyte replacement. Meal-prep friendly. Can substitute tempeh for higher protein. |

---

#### Template 19: Avocado Toast + Eggs
| Field | Value |
|-------|-------|
| **Formula** | Whole Grain Toast + Avocado + Eggs + Everything Seasoning |
| **Recovery Window** | Meal (30–120 min) |
| **Recovery Type** | Meal |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Easy, Moderate |
| **Component Foods** | `{whole_wheat_bread, avocado, scrambled_eggs}` |
| **Component Ratios** | `{"whole_wheat_bread": 0.35, "avocado": 0.20, "scrambled_eggs": 0.10}` |
| **Target Ratio** | 2:1 |
| **Allergens** | `{gluten, eggs}` |
| **Excluded Diets** | `{vegan}` |
| **Notes** | Trendy but nutritionally sound. Avocado = healthy fats + potassium. Eggs = complete protein + leucine. Cody Beals documented as post-swim/run recovery. Everything seasoning adds sodium. Good for lighter/easier sessions where aggressive carb loading isn't needed. Bob Seebohar's metabolic efficiency approach. |

---

#### Template 20: Overnight Oats + Protein (Make-Ahead)
| Field | Value |
|-------|-------|
| **Formula** | Overnight Oats + Protein Powder + Berries + Nut Butter |
| **Recovery Window** | Meal (30–120 min) |
| **Recovery Type** | Snack |
| **Activity Types** | Running, Cycling, Swimming, Triathlon |
| **Workout Intensity** | Easy, Moderate, Hard |
| **Component Foods** | `{oatmeal, whey_protein_powder, mixed_berries, almond_butter}` |
| **Component Ratios** | `{"oatmeal": 0.40, "whey_protein_powder": 0.05, "mixed_berries": 0.20, "almond_butter": 0.10}` |
| **Target Ratio** | 3:1 |
| **Allergens** | `{gluten, dairy, tree_nuts}` |
| **Excluded Diets** | `{vegan}` (with whey) |
| **Notes** | Zero post-workout prep — assemble night before, grab from fridge. Oats provide beta-glucan for sustained energy. Berries = antioxidants. Popular in TrainerRoad forum: "prep smoothie bags before rides." Can make in mason jar for portability. |

---

## 9. New Foods Required

Foods already in `template_foods` that we'll reuse:
- `banana`, `mixed_berries`, `greek_yogurt`, `granola`, `honey`
- `oatmeal`, `peanut_butter`, `almond_butter`, `jam`
- `bagel_large`, `whole_wheat_bread` (or `toast`)
- `white_rice_cooked`, `pasta_cooked`, `sweet_potato`
- `scrambled_eggs`, `orange_juice`, `sports_drink`, `water`
- `chocolate_milk`, `protein_shake`, `plant_protein_shake`
- `marinara_sauce`, `pretzels`

### New foods to add to `template_foods`:

| name | display_name | serving_size | calories | carbs | protein | fat | sodium | fluid | allergens | digestion | notes |
|------|-------------|-------------|----------|-------|---------|-----|--------|-------|-----------|-----------|-------|
| whey_protein_powder | Whey Protein Powder | 1 scoop (30g) | 120 | 3 | 25 | 1.5 | 130 | 0 | dairy | fast | ~3g leucine per scoop |
| plant_protein_powder | Plant Protein Powder | 1 scoop (35g) | 130 | 5 | 22 | 2.5 | 300 | 0 | — | medium | Pea+rice blend, ~2g leucine |
| tart_cherry_juice | Tart Cherry Juice | 1 cup (8 oz) | 140 | 33 | 1 | 0 | 15 | 230 | — | fast | 100% pure, not cocktail. Anti-inflammatory. |
| recovery_drink_mix | Recovery Drink Mix | 1 serving (mix in 16oz) | 200 | 40 | 15 | 1 | 200 | 475 | dairy | fast | Generic 3:1 recovery powder |
| core_power_shake | Core Power Elite Shake | 1 bottle (14 oz) | 230 | 16 | 42 | 4.5 | 260 | 400 | dairy | medium | Ultra-filtered milk protein RTD |
| grilled_chicken | Grilled Chicken Breast | 4 oz (113g) | 130 | 0 | 26 | 3 | 60 | 0 | — | slow | Lean, high leucine (~2.5g) |
| salmon | Salmon (cooked) | 4 oz (113g) | 210 | 0 | 23 | 12 | 60 | 0 | fish | slow | Rich in omega-3 EPA/DHA |
| avocado | Avocado | 1/2 medium | 120 | 6 | 1.5 | 11 | 5 | 55 | — | slow | Healthy fats + potassium (345mg) |
| black_beans | Black Beans (canned) | 1/2 cup | 110 | 20 | 7 | 0.5 | 460 | 0 | — | medium | Complex carbs + plant protein |
| whole_wheat_tortilla | Whole Wheat Tortilla | 1 large (10") | 210 | 36 | 6 | 5 | 540 | 0 | gluten | medium | Burrito base |
| cheddar_cheese | Cheddar Cheese | 1 oz (28g) | 115 | 0.5 | 7 | 9.5 | 180 | 0 | dairy | slow | Adds protein + calcium + sodium |
| broccoli | Broccoli (steamed) | 1 cup | 55 | 11 | 4 | 0.5 | 65 | 130 | — | medium | Vitamins, fiber, micronutrients |
| mixed_vegetables | Mixed Vegetables (stir-fry) | 1 cup | 60 | 12 | 3 | 0.5 | 45 | 120 | — | medium | Generic mixed veg |
| tofu | Tofu (firm) | 4 oz (113g) | 90 | 2 | 10 | 5 | 15 | 0 | soy | medium | Complete plant protein |
| salsa | Salsa | 2 tbsp | 10 | 2 | 0 | 0 | 200 | 25 | — | fast | Low cal, adds sodium + flavor |
| soy_sauce | Soy Sauce | 1 tbsp | 10 | 1 | 1 | 0 | 900 | 15 | soy, gluten | fast | High sodium condiment |
| beef_jerky | Beef Jerky | 1 oz (28g) | 80 | 5 | 13 | 1 | 590 | 0 | — | slow | High leucine, very salty, portable |
| trail_mix | Trail Mix | 1/4 cup (35g) | 175 | 15 | 5 | 12 | 55 | 0 | tree_nuts | medium | Nuts + dried fruit + chocolate |
| milk_lowfat | Low-Fat Milk (1%) | 1 cup (8 oz) | 105 | 13 | 8.5 | 2.5 | 110 | 220 | dairy | medium | Classic recovery beverage base |
| oat_milk | Oat Milk | 1 cup (8 oz) | 120 | 16 | 3 | 5 | 100 | 220 | gluten | medium | Vegan milk alternative |

---

## 10. Database Schema

### `post_workout_templates` Table

```sql
CREATE TABLE IF NOT EXISTS public.post_workout_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_number INTEGER NOT NULL UNIQUE,
  name TEXT NOT NULL,
  formula TEXT NOT NULL,
  recovery_window TEXT NOT NULL CHECK (recovery_window IN ('immediate', 'meal')),
  recovery_type TEXT NOT NULL CHECK (recovery_type IN ('shake', 'smoothie', 'bowl', 'sandwich', 'snack', 'meal')),
  activity_types TEXT[] NOT NULL DEFAULT '{}',
  workout_intensity TEXT[] NOT NULL DEFAULT '{}',
  component_food_names TEXT[] NOT NULL DEFAULT '{}',
  component_ratios JSONB,
  target_carb_protein_ratio TEXT,
  allergens TEXT[] NOT NULL DEFAULT '{}',
  excluded_diets TEXT[] NOT NULL DEFAULT '{}',
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### Indexes
```sql
CREATE INDEX idx_pwt_active ON post_workout_templates (is_active) WHERE is_active = true;
CREATE INDEX idx_pwt_activity_types ON post_workout_templates USING GIN (activity_types);
CREATE INDEX idx_pwt_recovery_window ON post_workout_templates (recovery_window);
CREATE INDEX idx_pwt_template_number ON post_workout_templates (template_number);
```

### RLS (same pattern as during_workout_templates)
- SELECT: public (true) — templates are not user-specific
- INSERT/UPDATE/DELETE: service_role only

---

## 11. Deliverables Checklist

- [x] Research document with elite athlete data (this file)
- [ ] `post_workout_template_foods.json` — new foods JSON
- [ ] SQL migration: `YYYYMMDD_post_workout_templates.sql` — table + seed
- [ ] SQL migration: `YYYYMMDD_post_workout_template_foods.sql` — new foods
- [ ] Updated `templates_database.md` — add post-workout section

---

## Research Sources

### Peer-Reviewed
1. Sawka et al., 2007 — ACSM Position Stand on Exercise and Fluid Replacement
2. Thomas et al., 2016 — Academy/ACSM/DC Position on Nutrition and Athletic Performance
3. Kerksick et al., 2017 — ISSN Position Stand on Nutrient Timing
4. Maughan et al., 2018 — IOC Consensus Statement on Sports Nutrition
5. Schoenfeld et al., 2013 — Nutrient Timing Revisited (meta-analysis)
6. Witard et al., 2014 — Protein dose-response for MPS
7. Moore et al., 2015 — Protein requirements for older and younger adults
8. Howatson et al., 2010 — Tart cherry juice and muscle recovery
9. European Journal of Clinical Nutrition, 2018 — Chocolate milk meta-analysis

### Expert/Coach Sources
10. Joe Friel — The Triathlete's Training Bible
11. Asker Jeukendrup — mysportscience.com
12. Allen Lim — Feed Zone Cookbook, Skratch Labs
13. Bob Seebohar — Metabolic Efficiency Training
14. Precision Fuel & Hydration — Post-exercise carbohydrate recommendations
15. TrainerRoad — Ask a Cycling Coach podcast

### Community Sources
16. Reddit r/triathlon — post-workout nutrition threads
17. Reddit r/running — recovery food discussions
18. Reddit r/cycling — post-ride meal recommendations
19. Slowtwitch Forum — Post workout nutrition threads
20. TrainerRoad Forum — Recovery nutrition discussions

### Athlete Sources
21. Lucy Charles-Barclay — Redbull, 220 Triathlon
22. Kristian Blumenfeld — Norwegian media, World Triathlon
23. Sam Laidlow — D3 Multisport podcast
24. Sam Long — Triathlete Magazine
25. Lionel Sanders — YouTube channel
26. Jan Frodeno — Autobiography, triathlon media
27. Daniela Ryf — Ironman features
28. Gustav Iden — Norwegian media
29. Cody Beals — YouTube, That Triathlon Life
30. Taylor Knibb — Team USA profiles

---

**End of Document**

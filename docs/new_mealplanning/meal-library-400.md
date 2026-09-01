# Meal library — 400 meals endurance athletes actually eat

_Assembled 2026-08-26. 100 breakfasts · 100 lunches · 100 dinners · 100 snacks, selected from ~970 candidates
gathered by 17 parallel research passes (pro-triathlete "day on a plate" features, sports dietitians and
endurance cookbooks, TrainerRoad/Slowtwitch/Reddit threads, Substacks and podcasts, plus dedicated hunts for
vegan/vegetarian, gluten-free/dairy-free/low-FODMAP, multi-allergen-safe, paleo/keto/low-carb/Mediterranean,
international food cultures, and rest-day/race-week/recovery contexts). Raw research with every source URL is in
[`meal-library-research/`](meal-library-research/); the machine-readable version is
[`mealplanning-prototype/packages/web/data/meal-library-400.json`](mealplanning-prototype/packages/web/data/meal-library-400.json)._

## What this is

The everyday-food counterpart to the pre/during/post-workout formulas. Where a formula is a deterministic
fuelling prescription, a **meal** here is a real plate — component-style ("chicken, jasmine rice & roasted
broccoli with teriyaki"), athlete-sized, mostly batch-cookable — that a working amateur triathlete looks at and
says *"yes, that's what I'd eat, and it looks like what a good triathlete eats."* Selection favoured:

- meals with a **named attribution** (a pro's reported day of eating, a sports dietitian's prescription, a
  team chef's cookbook, or a heavily-upvoted forum thread) over generic recipes;
- **component-first staples** over recipes, because 6 of 8 interviewed athletes eat from a rotation
  (`synthesis-and-recommendations.md` finding #4);
- **batch-friendly** dishes, because cooking sessions × servings is the plan unit (finding #3);
- explicit **rest-day** entries, because rest-day guidance is the biggest unaddressed gap (finding #5);
- **race-week / carb-load / recovery / pre-session** entries so the planner can pin by context.

## How each entry is tagged (mirrors the app)

| Field | Values | Notes |
|---|---|---|
| `diets_ok` | `omnivore` `vegetarian` `pescatarian` `vegan` `mediterranean` `paleo` `keto` `low_carb` | Exactly `DietaryPreference` (`lib/features/onboarding/domain/dietary_preference.dart`). Judged **as written**, before swaps. Vegan ⊂ vegetarian ⊂ pescatarian ⊂ omnivore is applied, so a vegan dal lists all four. |
| `allergens` | `dairy` `eggs` `fish` `gluten` `peanuts` `sesame` `shellfish` `soy` `tree_nuts` | Exactly `Allergy` (`lib/features/onboarding/domain/allergy.dart`). Oats count as `gluten` unless certified-GF; soy sauce = `soy`+`gluten`, tamari = `soy`. |
| `excluded_diets` (JSON only) | complement of `diets_ok` | Same shape as `allergens text[]` + `excluded_diets text[]` on `pre/during/post_workout_templates` and `foods`, so the library can drop into the existing enforcement path unchanged. |
| `context` | `everyday` `pre-session` `recovery` `rest-day` `race-week` `carb-load` `travel` | When the planner should offer it. |
| `cuisine` | free token | For variety and for users who eat from a particular food culture. |
| `batch` | yes / no | Scales to 4–6 servings and reheats / keeps. |
| `swaps` | free text | The one-line ingredient swap that changes the diet/allergen profile — ingredient-level swap was an unprompted user ask (finding #9). |
| `approx_macros` | ~kcal · C · P · F | Rough, per athlete serving; portion anchors were ~80–150 g carbs / 25–40 g protein for main meals on training days. **Not catalog-grounded** — see caveats. |

## Caveats (read before shipping)

1. **Macros are estimates**, not `foods`-table lookups. R6 in the synthesis ("ground everything in the
   catalog") still applies: before these become plates in the app, each ingredient line needs to resolve to
   catalog `food_id`s and the numbers recomputed. The library is content, not nutrition truth.
2. **Attributions are as-found.** Several publisher sites (triathlete.com, 220triathlon.com, Outside) block
   automated fetching; entries citing them were reconstructed from search snippets and are marked as such in
   the research files. Reddit was only reachable via a live browser session (`17-reddit-retry.md`).
3. **Allergen tags are ingredient-level, not manufacturing-level.** "May contain" cross-contamination is out
   of scope, as it is for the formula templates.
4. **Keto/paleo/low-carb entries are rest-day/easy-day framed.** They exist because those diets are options
   in onboarding, not because the evidence base favours them for endurance performance.
5. `diets_ok` was judged by the selection pass from the ingredient list; a human sports-dietitian review
   (Dr. Mitchell) is the right next gate before any of this is user-facing.

## Coverage matrix (computed from the entries below)

| Coverage | Breakfast | Lunch | Dinner | Snack | All 400 |
|---|---|---|---|---|---|
| diet:keto | 4 | 6 | 6 | 14 | **30** |
| diet:low_carb | 8 | 8 | 11 | 18 | **45** |
| diet:mediterranean | 36 | 37 | 32 | 44 | **149** |
| diet:omnivore | 100 | 100 | 100 | 100 | **400** |
| diet:paleo | 9 | 8 | 13 | 19 | **49** |
| diet:pescatarian | 91 | 64 | 52 | 91 | **298** |
| diet:vegan | 29 | 35 | 26 | 48 | **138** |
| diet:vegetarian | 84 | 52 | 38 | 89 | **263** |
| free-of:dairy | 61 | 75 | 79 | 68 | **283** |
| free-of:eggs | 69 | 88 | 92 | 85 | **334** |
| free-of:fish | 93 | 90 | 86 | 98 | **367** |
| free-of:gluten | 54 | 65 | 69 | 68 | **256** |
| free-of:peanuts | 93 | 96 | 100 | 89 | **378** |
| free-of:sesame | 94 | 85 | 91 | 95 | **365** |
| free-of:shellfish | 100 | 98 | 98 | 100 | **396** |
| free-of:soy | 87 | 81 | 81 | 95 | **344** |
| free-of:tree_nuts | 90 | 93 | 97 | 84 | **364** |
| free of dairy+eggs+peanuts+tree_nuts | 36 | 60 | 72 | 45 | **213** |
| free of ≥6 of 9 allergens | 96 | 98 | 98 | 97 | **389** |
| allergen-free as written | 17 | 29 | 39 | 28 | **113** |
| context:everyday | 56 | 92 | 85 | 71 | **304** |
| context:pre-session | 44 | 20 | 14 | 50 | **128** |
| context:recovery | 43 | 46 | 39 | 36 | **164** |
| context:rest-day | 38 | 30 | 26 | 33 | **127** |
| context:race-week | 23 | 12 | 17 | 14 | **66** |
| context:carb-load | 6 | 5 | 22 | 8 | **41** |
| context:travel | 28 | 27 | 9 | 41 | **105** |
| batch-friendly | 53 | 73 | 67 | 43 | **236** |
| named attribution | 88 | 94 | 70 | 94 | **346** |

Cuisine spread: general 170, american 84, british 19, mediterranean 17, mexican 17, middle-eastern 13, italian 12, japanese 11, indian 9, kenyan 9, nordic 6, brazilian 5, chinese 4, thai 4, eastern-european 3, colombian 3, korean 3, vietnamese 3, spanish 2, greek 2, french 1, australian 1, swiss 1, ethiopian 1


---

## Breakfast (100)

### B-001 · Porridge with banana, peanut butter & honey
- **Context:** everyday, pre-session · **Cuisine:** british · **Prep:** 5 min · **Batch:** no
- **Ingredients:** rolled oats 80g, water 300ml, banana 1, peanut butter 1 tbsp, honey 1 tbsp, pinch salt
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** gluten, peanuts
- **Swaps:** water→milk or Greek yogurt stirred in (+10g protein, Taylor Knibb's daily version); peanut butter→sunflower seed butter (peanut-free); oats→certified GF oats (gluten-free, Caroline Gregory's version)
- **Approx:** ~520 kcal · 85g C · 15g P · 14g F
- **Source:** Jonny Brownlee's regular breakfast (220triathlon.com "Jonny Brownlee: what does he eat?"); the most-repeated pre-long-run breakfast on r/AdvancedRunning (https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/); Alex Yee's version adds walnuts and dried fruit (lmtless.substack.com)
- **Why:** the single most common pro-triathlete breakfast — high-carb, familiar, enough fat to hold you through a 2h session

### B-002 · Toast with peanut butter, banana & honey
- **Context:** everyday, pre-session, race-week · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** bread 2 slices, peanut butter 1.5 tbsp, banana 1, honey 1 tsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** gluten, peanuts
- **Swaps:** peanut butter→almond butter + hemp seeds (Paula Findlay's version, tree_nuts); peanut butter→sunflower seed butter (peanut- and nut-free); bread→GF bread (gluten-free); honey→maple syrup (vegan)
- **Approx:** ~450 kcal · 68g C · 13g P · 14g F
- **Source:** "toast with nut butter and honey" was the single most common answer in active.com's pro-triathlete breakfast survey (https://www.active.com/triathlon/articles/what-do-pro-triathletes-eat-for-breakfast); Paula Findlay's 7am breakfast (triathlonmagazine.ca)
- **Why:** the default pre-key-session breakfast across the sport — fast, low-fibre, no cooking

### B-003 · White toast with jam
- **Context:** carb-load, pre-session, race-week · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** white bread 3 slices, jam 3 tbsp, black coffee or tea
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** jam→honey + a banana (r/AdvancedRunning race-morning variant); bread→GF white bread (gluten-free); toast→English muffin (same profile)
- **Approx:** ~420 kcal · 88g C · 8g P · 3g F
- **Source:** Tim O'Donnell's Ironman race-morning meal (ucan.co); Alistair Brownlee's Ironman-debut race morning was toast, butter and jam with tea (220triathlon.com)
- **Why:** as low-fat, low-fibre and high-carb as a solid race-morning breakfast gets — deliberately boring

### B-004 · Bagel with jam, banana & orange juice
- **Context:** carb-load, race-week · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** plain bagel 1, jam 2 tbsp, honey 1 tbsp, banana 1, orange juice 250ml
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** gluten
- **Swaps:** honey→extra jam (vegan); bagel→GF bagel (gluten-free); orange juice→sports drink (same carbs, more sodium)
- **Approx:** ~600 kcal · 130g C · 12g P · 3g F
- **Source:** Precision Fuel & Hydration carb-loading protocol — refined carbs deliberately chosen over wholegrain to hit 10–12 g/kg without fibre (https://www.precisionhydration.com/performance-advice/nutrition/how-to-carb-load-before-a-race/)
- **Why:** almost pure fast carbohydrate — the textbook carb-load breakfast in the 48h before a race

### B-005 · Bagel with almond butter & honey
- **Context:** everyday, pre-session · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** bagel 1, almond butter 1.5 tbsp, honey 1 tsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** gluten, tree_nuts
- **Swaps:** eat half the bagel 60–90 min before a hard session (Meb's portion); almond butter→sunflower seed butter (nut-free); bagel→cinnamon-raisin bagel + peanut butter (r/triathlon race-morning favourite, peanuts)
- **Approx:** ~450 kcal · 62g C · 14g P · 16g F
- **Source:** Meb Keflezighi, Boston Marathon champion — half a bagel with honey and almond butter before a hard workout (https://www.rei.com/blog/run/what-runners-eat-before-they-run); Beth Walsh's race-morning version is GF cinnamon-raisin toast + peanut butter (active.com)
- **Why:** minimal-volume, fast-digesting bagel breakfast for an early key session

### B-006 · Bagel with peanut butter & a protein shake
- **Context:** everyday, recovery · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** bagel 1, peanut butter 2 tbsp, protein powder 1 scoop shaken with milk 300ml, coffee
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten, peanuts
- **Swaps:** milk + whey→water + plant protein (dairy-free, vegan); peanut butter→cream cheese (the classic Ironman-pro bagel, dairy); bagel→GF bagel (gluten-free)
- **Approx:** ~600 kcal · 70g C · 38g P · 20g F
- **Source:** top comment in r/Ultramarathon "What do you eat day-to-day?" (https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/); bagel + peanut butter + cream cheese is a commonly reported Ironman-pro breakfast (active.com)
- **Why:** the fastest post-morning-session breakfast that actually hits 30g+ protein and 70g carbs

### B-007 · Rice, banana & avocado
- **Context:** pre-session, race-week · **Cuisine:** general · **Prep:** 5 min · **Batch:** yes
- **Ingredients:** cooked white rice 200g, banana 1, avocado ½, pinch salt
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** avocado→honey 2 tbsp (near-zero fat, 95g carbs — the ultra-low-residue version); rice→cooked the night before and reheated (5 min morning)
- **Approx:** ~480 kcal · 85g C · 7g P · 11g F
- **Source:** Flora Duffy's race-day breakfast — "always eats the same thing before a race" (Well+Good triathlon-breakfast feature); white rice + banana + honey is the standard low-residue race-morning strategy for celiac athletes (beyondceliac.org)
- **Why:** an Olympic champion's exact pre-race meal — allergen-free, low-fibre, low-fat

### B-008 · Rice with tamari & nori, onigiri-style
- **Context:** pre-session, race-week, travel · **Cuisine:** japanese · **Prep:** 5 min · **Batch:** yes
- **Ingredients:** cooked short-grain rice 200g, tamari 1 tsp, nori 1 sheet, pinch salt, sesame seeds 1 tsp
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** sesame, soy
- **Swaps:** shape into onigiri with tinned tuna (pescatarian, fish, +20g protein); omit sesame (sesame-free); tamari→soy sauce (adds gluten)
- **Approx:** ~330 kcal · 70g C · 7g P · 2g F
- **Source:** reported pre-session fuel among triathletes who prefer rice to bread before hard efforts (commonly reported, r/triathlon race-morning threads); traditional Japanese onigiri (justonecookbook.com)
- **Why:** very low fat and fibre, gluten-free, and it travels — the wheat-free race-morning option

### B-009 · Rice cereal with milk & banana
- **Context:** carb-load, pre-session, race-week · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** puffed rice cereal 70g, milk 250ml, banana 1, honey 1 tbsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** milk→lactose-free milk (Kate Scarlata's low-FODMAP carb-load version, still dairy); milk→oat milk (dairy-free, vegan with maple); honey→nut butter 1 tbsp (Chrissie Wellington's version)
- **Approx:** ~440 kcal · 88g C · 12g P · 5g F
- **Source:** Charisa Wernick's race-week breakfast and Chrissie Wellington's rice cereal + honey + nut butter (active.com pro-breakfast round-up; 33fuel.com); Kate Scarlata RDN low-FODMAP carb-loading (blog.katescarlata.com)
- **Why:** the lowest-fibre cereal breakfast there is — safe race-week fuel that needs zero cooking

### B-010 · Cereal, milk, banana & toast with jam
- **Context:** everyday, pre-session · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** wholegrain cereal or muesli 50g, milk 250ml, banana 1, wholegrain toast 1 slice, jam 1 tbsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** add blueberries + chia + almonds (r/AdvancedRunning training-day version, tree_nuts); milk→oat milk (dairy-free, vegan); cereal→cornflakes (lower fibre before a key session)
- **Approx:** ~500 kcal · 92g C · 15g P · 7g F
- **Source:** the balanced-breakfast template in Nancy Clark's Sports Nutrition Guidebook (cereal + milk + fruit + toast); r/AdvancedRunning "What do YOU eat in a day?" OP breakfast
- **Why:** textbook sports-dietitian breakfast — high-carb, moderate protein, five minutes

### B-011 · Peanut butter & jam rice cakes with cereal
- **Context:** pre-session, race-week · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** white rice cakes 3, peanut butter 1.5 tbsp, jam 1.5 tbsp, puffed corn cereal 1 cup, almond milk 200ml
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** peanuts, tree_nuts
- **Swaps:** almond milk→oat or rice milk (nut-free); peanut butter→sunflower seed butter (peanut-free); rice cakes→GF cinnamon-raisin toast (Beth Walsh's version)
- **Approx:** ~470 kcal · 82g C · 11g P · 12g F
- **Source:** Jesse Thomas, 3x Wildflower champion (active.com "What Do Pro Triathletes Eat for Breakfast?")
- **Why:** gluten-free, no-cook, low-fibre — a pro's early race-morning combo from pantry staples

### B-012 · Jam sandwich & a chicken sandwich
- **Context:** pre-session, race-week · **Cuisine:** french · **Prep:** 5 min · **Batch:** yes
- **Ingredients:** bread 4 slices, jam 2 tbsp, cooked chicken breast 80g, coffee
- **Diets OK:** omnivore
- **Allergens:** gluten
- **Swaps:** chicken→boiled egg (vegetarian, eggs); bread→GF bread (gluten-free); jam→honey
- **Approx:** ~560 kcal · 75g C · 32g P · 10g F
- **Source:** Romain Guillaume, French pro triathlete — one sandwich with jam, one with chicken, race morning (https://www.triathlete.com/nutrition/race-fueling/race-breakfasts-around-the-world/)
- **Why:** a pro's race-morning split of carbs and protein into two easy-to-eat sandwiches

### B-013 · Bread with cream cheese, feta & quince jelly
- **Context:** everyday, race-week · **Cuisine:** brazilian · **Prep:** 5 min · **Batch:** no
- **Ingredients:** bread 2 slices, cream cheese 2 tbsp, feta 20g, quince jelly or fruit jam 1 tbsp, black coffee
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** quince jelly→guava paste (goiabada, the Brazilian original); bread→GF bread (gluten-free); cheeses→dairy-free spread (dairy-free)
- **Approx:** ~430 kcal · 52g C · 14g P · 17g F
- **Source:** Ezequiel Morales, Brazilian pro triathlete, race-morning breakfast (https://www.triathlete.com/nutrition/race-fueling/race-breakfasts-around-the-world/)
- **Why:** a named pro's sweet-and-salty race breakfast — the Brazilian answer to toast and jam

### B-014 · Sweet rice cake with jam
- **Context:** pre-session, race-week, travel · **Cuisine:** american · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** cooked short-grain rice 200g, egg 1, milk 50ml, strawberry jam 2 tbsp, sugar 1 tsp, pinch salt (makes 4)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs
- **Swaps:** omit egg, milk→water (vegan, egg- and dairy-free sticky rice cake); jam→honey + cinnamon; jam→Nutella (tree_nuts, dairy)
- **Approx:** ~400 kcal · 78g C · 9g P · 5g F
- **Source:** Allen Lim / Feed Zone Portables sweet rice cake, EF Pro Cycling team recipe (https://efprocycling.com/tips-recipes/team-recipe-on-the-bike-rice-cakes/); "honey on rice cakes" as pre-ride breakfast (styrkr.com)
- **Why:** pro-peloton pocket food that doubles as a race-morning breakfast — very low fibre, mostly simple carbs

### B-015 · Feed Zone rice cakes with egg & bacon
- **Context:** pre-session, race-week, travel · **Cuisine:** american · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** cooked sushi rice 200g, eggs 2 scrambled, bacon 2 rashers, tamari 1 tbsp, brown sugar 1 tsp (makes 4)
- **Diets OK:** omnivore
- **Allergens:** eggs, soy
- **Swaps:** bacon→smoked tofu (vegetarian, soy); tamari→liquid aminos (soy-free); bacon→turkey bacon (lower fat)
- **Approx:** ~460 kcal · 55g C · 22g P · 15g F
- **Source:** Allen Lim, The Feed Zone Cookbook — "undeniably a great portable for race day" (https://www.skratchlabs.com/products/feed-zone-portables); EF Pro Cycling team recipe
- **Why:** the canonical pro-cyclist savoury rice breakfast — easy on the stomach, portable, salty

### B-016 · Millet porridge with dried apricots & honey
- **Context:** pre-session, race-week, rest-day · **Cuisine:** eastern-european · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** millet 80g, water 300ml, dried apricots 30g chopped, cinnamon, honey 1 tbsp, pinch salt
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** none
- **Swaps:** honey→maple syrup (vegan); water→oat or rice milk (creamier, still allergen-free); apricots→diced apple (Pretty Bee's version)
- **Approx:** ~390 kcal · 78g C · 9g P · 4g F
- **Source:** Eastern European pro-triathlete porridge tradition — "oats, millet, semolina, buckwheat or rice with milk" (https://www.triathlete.com/nutrition/race-fueling/race-breakfasts-around-the-world/); The Pretty Bee top-9-allergen-free meal plan, Day 4
- **Why:** naturally gluten-free, allergen-free, gentle low-residue carbs — the oat-free race-week porridge

### B-017 · Quinoa porridge with berries & banana
- **Context:** everyday, pre-session · **Cuisine:** general · **Prep:** 20 min · **Batch:** yes
- **Ingredients:** quinoa 80g dry, water or oat milk 300ml, banana 1, mixed berries 80g, maple syrup 1 tbsp, cinnamon
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** cook a 4-serving batch and reheat (5 min mornings); water→almond milk (tree_nuts); add 1 scoop plant protein (+20g P)
- **Approx:** ~450 kcal · 82g C · 14g P · 7g F
- **Source:** Luke Mathews, age-group Ironman, 4am pre-ride breakfast (gulfnews.com "I burn 8,000 calories"); triathlete.com quinoa breakfast cereal
- **Why:** the gluten-free complete-protein alternative to porridge — same job before an early session

### B-018 · Buckwheat kasha with honey & berries
- **Context:** everyday, rest-day · **Cuisine:** eastern-european · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** buckwheat groats 80g, water 250ml, honey 1 tbsp, berries 80g, pinch salt
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** none
- **Swaps:** honey→maple syrup (vegan); water→milk (creamier, dairy); add walnuts (tree_nuts, rest-day fat)
- **Approx:** ~390 kcal · 78g C · 11g P · 3g F
- **Source:** Eastern European pro-triathlete porridge tradition (https://www.triathlete.com/nutrition/race-fueling/race-breakfasts-around-the-world/)
- **Why:** naturally gluten-free, higher-fibre grain for easy days when you want variety from oats

### B-019 · Overnight rice pudding with cinnamon & berries
- **Context:** carb-load, everyday, race-week · **Cuisine:** general · **Prep:** overnight · **Batch:** yes
- **Ingredients:** cooked white rice 200g, milk 300ml, honey 2 tbsp, cinnamon, mixed berries 80g (makes 3)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** milk→oat milk + maple (vegan, dairy-free, allergen-free); berries→omit (ultra-low-residue race-eve); add whey/plant protein (+20g P)
- **Approx:** ~500 kcal · 92g C · 13g P · 7g F
- **Source:** reported carb-loading breakfast in Feed Zone-adjacent content and r/AdvancedRunning / r/triathlon carb-load threads (commonly reported); The Pretty Bee-style oat-free rice pudding
- **Why:** soft, low-fibre, oat-free way to load carbs when a bagel doesn't appeal

### B-020 · White rice & scrambled eggs
- **Context:** pre-session, race-week · **Cuisine:** general · **Prep:** 10 min · **Batch:** yes
- **Ingredients:** cooked white rice 200g, eggs 2, olive oil 1 tsp, salt, tamari few drops
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs
- **Swaps:** rice→oats 80g (Chelsea Sodaro's race-morning oatmeal + scrambled eggs, gluten); eggs→egg whites 4 (lower fat); add furikake
- **Approx:** ~460 kcal · 72g C · 20g P · 12g F
- **Source:** r/AdvancedRunning race-morning meal, "zero stomach issues" (https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/); Chelsea Sodaro's oatmeal + scrambled eggs race breakfast (triathlete.com Breakfast with Bob)
- **Why:** GI-tested race morning meal — plain carbs plus a little protein, nothing to upset a nervous stomach

### B-021 · Idli with sambar & coconut chutney
- **Context:** everyday, pre-session, recovery · **Cuisine:** indian · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** idli (steamed rice-lentil cakes) 4, sambar (lentil-vegetable stew) 250ml, coconut chutney 2 tbsp (makes 4)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** store-bought idli batter (15 min steam, no fermenting); idli→dosa from the same batter (crisp crepe); chutney→check for cashews (tree_nuts)
- **Approx:** ~420 kcal · 74g C · 15g P · 6g F
- **Source:** South Indian breakfast staple, reported as a favoured light pre-training breakfast among Indian runners (commonly reported; https://en.wikipedia.org/wiki/Idli)
- **Why:** fermented, naturally gluten-free, low-fat and high-carb — a genuinely different pre-session breakfast

### B-022 · Poha with peanuts & peas
- **Context:** everyday, pre-session · **Cuisine:** indian · **Prep:** 15 min · **Batch:** no
- **Ingredients:** poha (flattened rice) 100g, peanuts 1 tbsp, onion ½, peas 50g, mustard seeds, curry leaves, turmeric, oil 1 tsp, lime
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** peanuts
- **Swaps:** peanuts→omit (allergen-free); add boiled potato (more carbs); add a fried egg on top (eggs, +6g P)
- **Approx:** ~380 kcal · 68g C · 9g P · 9g F
- **Source:** everyday North/Central Indian breakfast, commonly reported as a light pre-run breakfast in Indian running-community write-ups
- **Why:** quick, low-fat, gluten-free rice carbs with a bit of crunch — better than toast for a lot of stomachs

### B-023 · Upma with vegetables
- **Context:** everyday, rest-day · **Cuisine:** indian · **Prep:** 15 min · **Batch:** no
- **Ingredients:** semolina (rava) 100g, oil 1 tbsp, mustard seeds, onion ½, carrot ½, peas 50g, green chilli, curry leaves, water 300ml
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** oil→ghee (traditional, dairy); rava→rice rava (gluten-free); add cashews (tree_nuts)
- **Approx:** ~420 kcal · 66g C · 11g P · 13g F
- **Source:** South Indian breakfast staple, commonly reported among Indian endurance athletes in "what I eat" threads
- **Why:** savoury, veg-forward carb breakfast for athletes bored of sweet bowls

### B-024 · Chapati & sweet chai
- **Context:** pre-session, race-week · **Cuisine:** kenyan · **Prep:** 15 min · **Batch:** no
- **Ingredients:** chapati 2, chai (black tea, whole milk 200ml, sugar 2–3 tsp), banana 1
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** milk→oat milk (vegan, dairy-free); chapati→white bread (Kenyan camp everyday version); add peanut butter on the chapati (peanuts)
- **Approx:** ~480 kcal · 85g C · 13g P · 10g F
- **Source:** Mary Keitany's race-morning meal; the standard breakfast at Kenyan training camps (https://www.traininkenya.com/2018/08/08/diet-of-kenyan-runners/)
- **Why:** the low-fibre, high-simple-carb pre-race breakfast sports science recommends — arrived at independently by Kenyan running culture

### B-025 · Uji with milk & sugar
- **Context:** everyday, pre-session, recovery · **Cuisine:** kenyan · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** millet or maize flour 80g, water 400ml, milk 100ml, sugar 1–2 tbsp, pinch salt, lemon squeeze
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** milk→omit (vegan, allergen-free); sugar→honey; add peanut butter 1 tbsp (peanuts, Kenyan camp version)
- **Approx:** ~400 kcal · 78g C · 10g P · 5g F
- **Source:** the post-run porridge at Kenyan training camps, commonly reported alongside chai and bread (https://www.traininkenya.com/2018/08/08/diet-of-kenyan-runners/; olympics.com on Eliud Kipchoge's camp diet)
- **Why:** what the best distance runners in the world eat after a morning run — thin, warm, quick carbs, naturally gluten-free

### B-026 · Beans on toast
- **Context:** everyday, pre-session, travel · **Cuisine:** british · **Prep:** 5 min · **Batch:** no
- **Ingredients:** baked beans 1 tin (400g), wholegrain toast 2 slices, black pepper
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** add grated cheddar (vegetarian, dairy); bread→GF bread (gluten-free); add a fried egg (eggs, +6g P)
- **Approx:** ~500 kcal · 88g C · 20g P · 5g F
- **Source:** r/AdvancedRunning pre-long-run breakfast (https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/); commonly reported UK triathlete staple (220triathlon.com reader features)
- **Why:** cheap, fast, high-carb, low-fat — a genuinely British pre-session breakfast

### B-027 · Weet-Bix with milk & banana
- **Context:** everyday, pre-session · **Cuisine:** australian · **Prep:** no-cook · **Batch:** no
- **Ingredients:** Weet-Bix 4, milk 250ml, banana 1, honey 1 tsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** milk→oat milk (dairy-free, vegan with maple); Weet-Bix→GF wholegrain biscuits (gluten-free); add Greek yogurt (+10g P)
- **Approx:** ~450 kcal · 82g C · 15g P · 6g F
- **Source:** the Australian/NZ endurance-athlete everyday breakfast, commonly reported (https://en.wikipedia.org/wiki/Weet-Bix)
- **Why:** what every Aus/NZ triathlete grew up eating before training — three minutes, high carb, low fat

### B-028 · Bircher muesli
- **Context:** everyday, pre-session, travel · **Cuisine:** swiss · **Prep:** overnight · **Batch:** yes
- **Ingredients:** rolled oats 80g, apple juice or milk 150ml, plain yogurt 150g, apple 1 grated, sultanas 20g, cinnamon, honey 1 tbsp
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** yogurt→coconut yogurt, honey→maple (vegan, dairy-free); oats→certified GF oats (gluten-free, Triathlete's celiac race-week version with dried apricot); add chopped almonds (tree_nuts, Hannah Grant's version)
- **Approx:** ~500 kcal · 82g C · 16g P · 9g F
- **Source:** Jonny Brownlee's winter routine, made the night before and taken to morning swim sessions (220triathlon.com); Hannah Grant, Eat Race Win, WorldTour travel-breakfast staple (https://hannahgrant.com/)
- **Why:** no-cook, made in a hotel room with no kitchen — the pro cyclist's travel and swim-morning breakfast

### B-029 · Plain porridge with stewed apple
- **Context:** pre-session, race-week, travel · **Cuisine:** british · **Prep:** 15 min · **Batch:** no
- **Ingredients:** rolled oats 70g, water 300ml, peeled stewed apple ½ cup, cinnamon, honey 1 tsp, pinch salt
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** gluten
- **Swaps:** honey→maple (vegan); travel→instant oat packet + banana, kettle only (Tisseyre/hotel-room version); oats→certified GF oats (gluten-free)
- **Approx:** ~380 kcal · 72g C · 9g P · 5g F
- **Source:** Laura Philipp's race-day porridge — same as training but cooked with water and no raw fruit to cut fibre (know-how.mnstry.com); Taryn Richardson's race-morning porridge with golden syrup (dietitianapproved.com)
- **Why:** same base meal as training, with the fibre stripped out — the race-morning version of your everyday oats

### B-030 · High-protein overnight oats
- **Context:** everyday, pre-session, recovery, travel · **Cuisine:** american · **Prep:** overnight · **Batch:** yes
- **Ingredients:** rolled oats 80g, Greek yogurt 150g, milk 150ml, protein powder ½ scoop, honey 1 tbsp, berries 80g (makes 5 jars)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** yogurt/milk→soy milk + chia, protein→pea (vegan, dairy-free, soy); oats→certified GF oats (gluten-free); add mashed sweet potato + dates (r/TrainerRoad daily version, no protein powder)
- **Approx:** ~520 kcal · 72g C · 32g P · 10g F
- **Source:** Alex Larson RDN (alexlarsonnutrition.com); Jan Frodeno's race-day "big bowl of overnight oats"; Kristian Blummenfelt preps overnight oats with yogurt and nuts the day before (vo2master.com Norwegian Method interview)
- **Why:** make five jars on Sunday and breakfast is solved for every pre-dawn session that week

### B-031 · Gluten-free pancakes with maple syrup
- **Context:** pre-session, race-week, recovery · **Cuisine:** american · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** GF pancake mix 120g (or rice flour 50g + oat flour 50g), eggs 2, milk 200ml, maple syrup 3 tbsp, butter 1 tsp, banana 1 (makes 8 pancakes)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs
- **Swaps:** milk→oat milk, eggs→flax egg (vegan, dairy- and egg-free); GF mix→wheat flour (gluten, the standard race-morning pancake); freeze extras and toast to reheat
- **Approx:** ~550 kcal · 92g C · 13g P · 14g F
- **Source:** Luke McKenzie, 6x Ironman champion — gluten-free pancakes and syrup as his go-to (active.com); Hannah Grant's GF pancakes with fruit salad for pro cycling teams (bikeradar.com Tour de France recipes)
- **Why:** proof that a treat-shaped carb breakfast is a legitimate pro pre-race choice — and this one is GF as written

### B-032 · Buckwheat pancakes with honey & berries
- **Context:** carb-load, pre-session, rest-day · **Cuisine:** general · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** 100% buckwheat flour 100g, eggs 2, rice milk 150ml, honey 2 tbsp, mixed berries 100g, baking powder ½ tsp
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** eggs
- **Swaps:** eggs→flax egg + baking powder (vegan); honey→maple (vegan); check the flour is 100% buckwheat — many blends are cut with wheat (gluten)
- **Approx:** ~500 kcal · 88g C · 15g P · 8g F
- **Source:** trigirl.co.uk GF/DF triathlete breakfast list ("buckwheat pancakes with honey and berries")
- **Why:** naturally gluten- and dairy-free wholegrain pancakes that still deliver a high-carb pre-session breakfast

### B-033 · Banana-oat pancakes, egg-free
- **Context:** everyday, pre-session, recovery · **Cuisine:** general · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** certified GF rolled oats 100g blended to flour, banana 2 mashed, oat milk 120ml, baking powder 1 tsp, cinnamon, plant protein 1 scoop optional
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add plant protein 1 scoop (+20g P, the vegan recovery version); top with peanut butter (peanuts); oats→standard rolled oats (gluten)
- **Approx:** ~450 kcal · 78g C · 12g P · 7g F
- **Source:** standard flourless banana-oat pancake, widely cross-referenced in egg-free breakfast round-ups (Healthy Green Kitchen); vegan protein-pancake format from plant-based endurance content (veganeasy.org)
- **Why:** pancakes with no egg, dairy or nuts — the one pancake almost every restricted-diet athlete can eat

### B-034 · Freezer waffles with Greek yogurt & berries
- **Context:** everyday, recovery, rest-day · **Cuisine:** american · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** waffle batter (flour 150g, eggs 2, buttermilk 200ml, baking powder 1 tsp — makes 6), Greek yogurt 150g, mixed berries 100g, maple syrup 2 tbsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten
- **Swaps:** batter→blended oats + Greek yogurt + protein powder (protein waffles, 30g P); flour→GF blend (gluten-free); yogurt→coconut yogurt (dairy-free)
- **Approx:** ~560 kcal · 80g C · 22g P · 15g F
- **Source:** commonly reported weekend recovery breakfast among endurance athletes (marathonhandbook.com); "waffles with eggs, OJ and toast" post-workout in an age-group triathlete Substack (triplethreatlife.substack.com)
- **Why:** make a batch Sunday, toast one Tuesday — a treat-shaped recovery breakfast that takes two minutes on a weekday

### B-035 · Gluten-free French toast with maple & berries
- **Context:** everyday, recovery, travel · **Cuisine:** american · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** GF bread 3 slices, eggs 2, rice milk 100ml, cinnamon, maple syrup 2 tbsp, berries 80g, oil for the pan (makes 2)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs
- **Swaps:** eggs→mashed banana batter (vegan, egg-free — The Pretty Bee's French-toast sticks); GF bread→sourdough (gluten); cook a batch, freeze, toast to reheat
- **Approx:** ~500 kcal · 75g C · 17g P · 13g F
- **Source:** runtothefinish.com gluten-free runner meal plan ("GF French toast, freezer-friendly"); studentathletenutrition.com GF recovery breakfast
- **Why:** a freezer-friendly recovery breakfast that reloads glycogen and stays gluten- and dairy-free as written

### B-036 · Mango, spinach & oat-milk protein smoothie
- **Context:** pre-session, recovery, travel · **Cuisine:** general · **Prep:** 5 min · **Batch:** yes
- **Ingredients:** frozen mango 150g, banana 1, oat milk 300ml, spinach handful, plant protein 1 scoop
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** plant protein→whey (dairy); oat milk→almond milk (tree_nuts); freeze fruit in bags Sunday for five grab-and-blend mornings
- **Approx:** ~420 kcal · 68g C · 24g P · 6g F
- **Source:** commonly reported liquid pre-session breakfast for gut-sensitive athletes (https://www.triathlete.com/nutrition/race-fueling/); runtothefinish.com "protein green smoothie"
- **Why:** blended and low-residue — the breakfast for a 5am session when solid food won't go down

### B-037 · Rich Roll's green smoothie
- **Context:** everyday, pre-session · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** kale or spinach 2 cups, beetroot 1 small, banana 2, mixed berries ½ cup, coconut water 300ml, chia 1 tbsp, hemp seeds 1 tbsp, flax 1 tbsp
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add plant protein 1 scoop (+20g P); beetroot→omit (milder, less fibre before a hard session); coconut water→water + pinch salt
- **Approx:** ~430 kcal · 82g C · 12g P · 9g F
- **Source:** Rich Roll, vegan ultra-endurance athlete — his standard pre-workout green smoothie (https://www.richroll.com/blog/morning-pre-race-nutrition/; livekindly.com)
- **Why:** the plant-based ultra athlete's daily foundation — allergen-free, carb-heavy, drinkable

### B-038 · Scott Jurek's blueberry smoothie
- **Context:** pre-session, recovery · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** banana 1, frozen blueberries 1 cup, soaked almonds ¼ cup, dates 2, vegan protein 1 scoop, flax or omega oil 1 tbsp, pinch salt, water 300ml
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** tree_nuts
- **Swaps:** almonds→sunflower seeds (nut-free); omit protein powder (pre-session, lighter); dates→maple syrup
- **Approx:** ~480 kcal · 62g C · 22g P · 18g F
- **Source:** Scott Jurek, Eat & Run — his training smoothie during Western States/Badwater prep (https://runningmagazine.ca/health-nutrition/nutrition-get-real-whole-foods-for-runners/)
- **Why:** an ultrarunning legend's real pre-long-run fuel — calorie-dense and drinkable

### B-039 · Smoothie bowl with hemp seeds & seed granola
- **Context:** recovery, rest-day · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** frozen banana 2, frozen berries 100g, oat milk 150ml, hemp seeds 3 tbsp, seed-based GF granola 40g, sliced fruit to top
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add plant protein 1 scoop (+20g P); granola→any granola (usually gluten, tree_nuts); hemp→peanut butter (peanuts)
- **Approx:** ~520 kcal · 82g C · 18g P · 15g F
- **Source:** commonly reported recovery-breakfast format (220triathlon.com energy-breakfast recipes); hemp as a soy-free, nut-free complete protein (Sunwarrior)
- **Why:** a nut-free, soy-free, egg-free recovery bowl with real protein from seeds

### B-040 · Açaí bowl with banana & granola
- **Context:** recovery, rest-day · **Cuisine:** brazilian · **Prep:** 5 min · **Batch:** no
- **Ingredients:** frozen açaí packs 2 (200g), banana 2 (1 blended, 1 sliced), guaraná syrup or honey 1 tbsp, seed-based GF granola 40g
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** none
- **Swaps:** honey→maple (vegan); add plant or whey protein (+20g P); granola→standard granola (gluten, tree_nuts)
- **Approx:** ~520 kcal · 85g C · 10g P · 14g F
- **Source:** Brazilian everyday breakfast/post-training staple, commonly reported among Brazilian triathletes and surfers (frozen açaí packs are sold in most supermarkets)
- **Why:** the Brazilian recovery bowl — cold, carb-heavy and fast after a hot morning session

### B-041 · Crunchy cereal with milk & Nutella
- **Context:** everyday · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** crunchy oat-cluster cereal 70g, milk 250ml, Nutella 1 tbsp, banana 1
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten, soy, tree_nuts
- **Swaps:** milk→oat milk (dairy-free); Nutella→jam (nut-free); add an energy bar on the side (McDonald's actual version)
- **Approx:** ~560 kcal · 90g C · 14g P · 16g F
- **Source:** Chris McDonald, 6x Ironman champion — cereal bowl with Nutella and a Bonk Breaker (active.com pro-breakfast round-up)
- **Why:** a six-time Ironman champion eats boxed cereal with Nutella — permission that simple is fine

### B-042 · Rye bread with brunost & jam
- **Context:** everyday, rest-day, travel · **Cuisine:** nordic · **Prep:** no-cook · **Batch:** no
- **Ingredients:** wholegrain rye bread 3 slices, brunost (brown cheese) 40g thin slices, strawberry jam 1 tbsp, butter thin scrape, cucumber
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** brunost→cheese + jam (same idea); bread→GF crispbread (gluten-free); add a boiled egg (eggs, +6g P)
- **Approx:** ~450 kcal · 62g C · 14g P · 16g F
- **Source:** standard Norwegian everyday breakfast behind the Norwegian Method cohort's carb-forward, dairy-rich diet (vo2master.com Norwegian Method series on Blummenfelt/Iden); commonly eaten
- **Why:** how Norwegian endurance athletes actually eat day to day — open sandwiches, no fuss

### B-043 · Rye bread with boiled egg & smoked salmon
- **Context:** everyday, recovery, rest-day · **Cuisine:** nordic · **Prep:** 10 min · **Batch:** no
- **Ingredients:** rye bread 2 slices, boiled egg 1, smoked salmon 60g, dill, cucumber, lemon
- **Diets OK:** mediterranean, omnivore, pescatarian
- **Allergens:** eggs, fish, gluten
- **Swaps:** rye→wholegrain toast + avocado (the triathlete.com smoked-salmon-avocado-toast version); bread→rice cakes (gluten-free); omit egg (egg-free)
- **Approx:** ~420 kcal · 42g C · 26g P · 15g F
- **Source:** Scandinavian open-sandwich breakfast consistent with the Norwegian Method cohort's everyday diet (vo2master.com); smoked salmon avocado toast in triathlete.com's 7-day plan
- **Why:** omega-3 and 26g protein on a slice of bread — a recovery breakfast that takes ten minutes

### B-044 · Pan con tomate y jamón
- **Context:** everyday, pre-session, travel · **Cuisine:** spanish · **Prep:** 5 min · **Batch:** no
- **Ingredients:** crusty bread 3 slices, ripe tomato 1 grated, olive oil 1 tbsp, jamón serrano 40g, salt, coffee
- **Diets OK:** mediterranean, omnivore
- **Allergens:** gluten
- **Swaps:** omit jamón (vegan); bread→GF bread (gluten-free); jamón→tinned tuna (pescatarian, fish)
- **Approx:** ~480 kcal · 60g C · 18g P · 18g F
- **Source:** classic Spanish breakfast, commonly reported as the everyday breakfast of Spanish pro cyclists alongside toast and coffee
- **Why:** the Mediterranean toast-and-coffee breakfast — fast, salty, no bowl required

### B-045 · Bagel with cream cheese & lox
- **Context:** recovery, rest-day, travel · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** bagel 1, cream cheese 2 tbsp, smoked salmon 60g, red onion, capers, lemon
- **Diets OK:** omnivore, pescatarian
- **Allergens:** dairy, fish, gluten
- **Swaps:** bagel→GF bagel (gluten-free); cream cheese→dairy-free spread (dairy-free); add sliced tomato and cucumber
- **Approx:** ~500 kcal · 58g C · 26g P · 17g F
- **Source:** commonly reported runner/triathlete weekend breakfast, easy to buy on the road (therunningchannel.com best breakfasts for runners)
- **Why:** protein and omega-3 on a bagel, available at any airport — a reliable travel and recovery breakfast

### B-046 · Avocado toast with chilli & lime
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** wholegrain or sourdough toast 2 slices, avocado 1, lime, chilli flakes, sea salt, olive oil drizzle
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** add sliced tomato (r/cycling pre-ride version); add 2 poached eggs (eggs, +12g P); bread→GF bread (gluten-free, allergen-free)
- **Approx:** ~420 kcal · 42g C · 9g P · 24g F
- **Source:** commonly reported athlete rest-day breakfast (marathonhandbook.com); r/cycling pre-ride pantry list
- **Why:** fat- and fibre-forward — the breakfast that belongs on the easy day, not before the long ride

### B-047 · Chickpea & avocado toast
- **Context:** everyday, recovery, rest-day · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** wholegrain toast 2 slices, chickpeas 150g mashed, avocado ½, lemon, chilli flakes, olive oil 1 tsp, salt
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** bread→GF bread (gluten-free, allergen-free); chickpeas→hummus 3 tbsp (sesame); add feta (vegetarian, dairy)
- **Approx:** ~480 kcal · 58g C · 18g P · 20g F
- **Source:** eatthis.com "28 High-Protein Breakfast Recipes Without Eggs" — eggless avocado toast with chickpeas
- **Why:** avocado toast with actual protein — egg-free, nut-free, dairy-free and cheap

### B-048 · Sourdough with cottage cheese, tomato & olive oil
- **Context:** everyday, recovery, rest-day · **Cuisine:** mediterranean · **Prep:** 5 min · **Batch:** no
- **Ingredients:** sourdough 2 slices, cottage cheese 200g, tomato 1 sliced, olive oil 1 tbsp, black pepper, basil
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** cottage cheese→ricotta (same profile); bread→GF sourdough (gluten-free); add smoked salmon (pescatarian, fish)
- **Approx:** ~450 kcal · 48g C · 28g P · 16g F
- **Source:** commonly reported Mediterranean-style athlete rest-day breakfast (220triathlon.com energy-breakfast recipes)
- **Why:** 28g protein from cottage cheese with no cooking — a savoury, lighter rest-day breakfast

### B-049 · Greek yogurt with honey, walnuts & figs
- **Context:** everyday, rest-day · **Cuisine:** mediterranean · **Prep:** no-cook · **Batch:** no
- **Ingredients:** Greek yogurt 250g, honey 1 tbsp, walnuts 25g, fresh figs 2 (or dried figs 3), cinnamon
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, tree_nuts
- **Swaps:** figs→banana or berries; walnuts→pumpkin seeds (nut-free); yogurt→coconut yogurt + maple (vegan, dairy-free)
- **Approx:** ~450 kcal · 45g C · 24g P · 20g F
- **Source:** classic Greek breakfast plate, commonly reported across Mediterranean-diet-for-athletes plans (nutritionheartbeat.com)
- **Why:** the Mediterranean yogurt breakfast — protein-dense, no cooking, real fruit and nuts on an easy day

### B-050 · Greek yogurt, granola & berries jar
- **Context:** everyday, recovery, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** yes
- **Ingredients:** Greek yogurt 250g, granola 60g, mixed berries 100g, honey 1 tbsp (makes 5 jars)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten, tree_nuts
- **Swaps:** yogurt→skyr (Nordic, higher protein); granola→certified GF seed granola (gluten- and nut-free); yogurt→coconut yogurt + maple (vegan, dairy-free)
- **Approx:** ~520 kcal · 68g C · 26g P · 15g F
- **Source:** Fuelin post-workout Greek yogurt bowl (fuelin.com); the 13-year desk-worker post-swim staple on r/triathlon; "best performances off Greek yogurt and coffee" on r/AdvancedRunning; Taylor Knibb's daily oats + Greek yogurt (tri247.com)
- **Why:** the office-fridge recovery breakfast — hits 25g protein 30 minutes after a pre-work session

### B-051 · Full-fat Greek yogurt with chia, almonds & a few berries
- **Context:** rest-day · **Cuisine:** mediterranean · **Prep:** no-cook · **Batch:** no
- **Ingredients:** full-fat Greek yogurt 250g, chia seeds 1 tbsp, almonds 25g, blueberries 40g, cinnamon
- **Diets OK:** keto, low_carb, mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, tree_nuts
- **Swaps:** add matcha and a scoop of collagen (r/Ultramarathon version); almonds→pumpkin seeds (nut-free); yogurt→coconut yogurt (vegan, dairy-free, paleo)
- **Approx:** ~450 kcal · 18g C · 24g P · 30g F
- **Source:** commonly reported low-carb/Mediterranean rest-day breakfast (nutritionheartbeat.com; Racing Weight-style lean-day guidance)
- **Why:** the genuinely low-carb rest-day breakfast — full protein, no glycogen load you don't need

### B-052 · Coconut yogurt with seed granola & mango
- **Context:** recovery, rest-day, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** coconut yogurt 250g, certified GF seed-based granola 50g, mango 120g, chia 1 tbsp, maple syrup 1 tsp
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add pea protein 1 scoop (+20g P); granola→nut granola (tree_nuts); coconut yogurt→soy yogurt (higher protein, soy)
- **Approx:** ~480 kcal · 62g C · 9g P · 20g F
- **Source:** The Pretty Bee top-9-allergen-free meal plan, Day 2 (https://theprettybee.com/top-9-allergen-free-meal-plan/); trigirl.co.uk GF/DF breakfasts
- **Why:** a yogurt-and-granola bowl that is free of all nine allergens as written — the multi-allergy fallback

### B-053 · Amaranth bowl with berries & seeds
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** 20 min · **Batch:** yes
- **Ingredients:** amaranth 70g dry, water 250ml, mixed berries 100g, chia 1 tbsp, hemp seeds 2 tbsp, pumpkin seeds 1 tbsp, maple syrup 1 tbsp
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** amaranth→quinoa or millet (same job); add plant milk (creamier); seeds→peanut butter (peanuts)
- **Approx:** ~480 kcal · 66g C · 16g P · 16g F
- **Source:** r/veganfitness meal breakdown (https://old.reddit.com/r/veganfitness/); commonly reported
- **Why:** a gluten-free grain bowl that gets to 16g protein from seeds alone — no soy, no nuts, no dairy

### B-054 · Superhero muffins
- **Context:** everyday, recovery, travel · **Cuisine:** american · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** almond meal 200g, rolled oats 60g, walnuts 60g, currants 60g, eggs 3, grated zucchini 1 cup, grated carrot 1 cup, butter 4 tbsp, maple syrup ½ cup, cinnamon (makes 12; 2 muffins + a banana per serving)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten, tree_nuts
- **Swaps:** butter→coconut oil, eggs→flax eggs (vegan); oats→certified GF oats (gluten-free); walnuts→pumpkin seeds (still tree_nuts from almond meal)
- **Approx:** ~520 kcal · 52g C · 15g P · 30g F
- **Source:** Shalane Flanagan & Elyse Kopecky, Run Fast Eat Slow — the cookbook's signature recipe (https://run.outsideonline.com/nutrition-and-health/recipes/shalane-flanagans-superhero-muffin-recipe/)
- **Why:** a two-time Olympian's veg-packed grab-and-go muffin — bake Sunday, freeze, eat in the car

### B-055 · Chia pudding with mango
- **Context:** race-week, rest-day, travel · **Cuisine:** general · **Prep:** overnight · **Batch:** yes
- **Ingredients:** chia seeds 40g, coconut or oat milk 300ml, mango 120g, maple syrup 1 tbsp, vanilla (makes 3)
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** mango→frozen cherries (The Pretty Bee Day 3); add pea protein (+20g P); stir in cooked white rice 100g (more carbs, still allergen-free)
- **Approx:** ~420 kcal · 50g C · 10g P · 20g F
- **Source:** The Pretty Bee top-9-allergen-free meal plan; staple no-cook breakfast in vegan-athlete meal-prep guides (Great Vegan Athletes)
- **Why:** free of all nine allergens, no cooking, no fridge drama — the hotel-room breakfast for vegan and paleo athletes alike

### B-056 · Peanut butter baked oatmeal
- **Context:** everyday, recovery · **Cuisine:** american · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** rolled oats 250g, eggs 3, milk 800ml, peanut butter 60g, peanut butter powder 90g, maple syrup 80ml, chia 1 tbsp, vanilla, baking powder ½ tsp (makes 6)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten, peanuts
- **Swaps:** peanut butter→sunflower seed butter (peanut-free); milk→oat milk (dairy-free); make it cinnamon-roll style with mashed banana and no nut butter (Featherstone's other version)
- **Approx:** ~400 kcal · 50g C · 21g P · 14g F
- **Source:** Meghann Featherstun RD, Featherstone Nutrition (https://www.featherstonenutrition.com/peanut-butter-baked-oatmeal/), framed as a post-workout breakfast; baked oatmeal squares are a common r/triathlon meal-prep format
- **Why:** the one oats recipe you bake once and eat all week — 21g protein a slice, reheats in a minute

### B-057 · Savoury oats with fried egg & avocado
- **Context:** everyday, rest-day · **Cuisine:** american · **Prep:** 15 min · **Batch:** no
- **Ingredients:** rolled oats 70g, chicken or veg stock 300ml, fried egg 1, avocado ¼, olive oil 1 tsp, everything-bagel seasoning, hot sauce
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs, gluten, sesame
- **Swaps:** egg→poached eggs 2 (Hannah Grant's winter team breakfast); add sautéed spinach and cheddar (dairy); oats→certified GF oats (gluten-free)
- **Approx:** ~450 kcal · 45g C · 16g P · 22g F
- **Source:** Stephanie Howe PhD, Western States champion and sports nutritionist (https://www.outsideonline.com/health/nutrition/oatmeal-recipe-stephanie-howe-runner/); Bob Seebohar's savoury lower-glycemic easy-day breakfast approach
- **Why:** Seebohar-style rest-day eating — the oats are there, but the fat and protein lead

### B-058 · Eggs & avocado on toast, big-breakfast style
- **Context:** everyday, recovery, rest-day · **Cuisine:** american · **Prep:** 15 min · **Batch:** no
- **Ingredients:** toast 3 slices, avocado 1 mashed with salt and pepper, poached or scrambled eggs 3, feta 20g, spinach handful
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten
- **Swaps:** eggs→boiled eggs 2 on 2 slices (lighter version); toast→GF bread (gluten-free); omit feta (dairy-free); toast→English muffin (r/triathlon weekday version)
- **Approx:** ~650 kcal · 55g C · 30g P · 35g F
- **Source:** Gwen Jorgensen, Olympic champion — "front-loading our day with calories, so breakfast and lunch are our biggest meals" (ESPNW What Athletes Eat, https://www.espn.com/espnw/athletes-life/article/12826161/); Nancy Clark's scrambled-eggs-and-toast template
- **Why:** an Olympic champion's deliberately big breakfast — carbs from bread, protein from eggs, fat from avocado

### B-059 · Mushroom & spinach omelette with orange juice
- **Context:** pre-session, race-week, rest-day · **Cuisine:** british · **Prep:** 10 min · **Batch:** no
- **Ingredients:** eggs 3, mushrooms 80g, spinach handful, olive oil 1 tsp, salt, orange juice 250ml
- **Diets OK:** low_carb, omnivore, pescatarian, vegetarian
- **Allergens:** eggs
- **Swaps:** add ham 2 slices (Team Sky pre-stage omelette, omnivore); eggs→egg whites 5 + feta (lower fat, dairy); add toast 2 slices (gluten, +30g C)
- **Approx:** ~420 kcal · 28g C · 24g P · 24g F
- **Source:** r/triathlon "What's your go-to breakfast before a race?" OP, 112-comment thread; Henrik Orre's Team Sky ham & cheese omelette (https://www.cyclist.co.uk/in-depth/865/team-sky-recipes-for-cycling-success)
- **Why:** the protein half of the pro-cycling breakfast — pair with rice or toast depending on how long the session is

### B-060 · Shakshuka with bread
- **Context:** recovery, rest-day · **Cuisine:** middle-eastern · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** eggs 3, tinned tomatoes 400g, onion ½, red pepper ½, garlic, cumin 1 tsp, paprika 1 tsp, feta 30g, olive oil 1 tbsp, crusty bread 2 slices (sauce makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten
- **Swaps:** omit feta (dairy-free); bread→rice or GF bread (gluten-free); add chickpeas to the sauce (+8g P)
- **Approx:** ~520 kcal · 45g C · 26g P · 26g F
- **Source:** commonly eaten North African/Middle Eastern breakfast in Mediterranean-diet athlete plans (nutritionheartbeat.com); make the sauce Sunday, poach eggs fresh
- **Why:** a savoury, vegetable-heavy rest-day breakfast whose sauce batch-cooks and freezes

### B-061 · Sausage & spinach egg muffins
- **Context:** everyday, rest-day, travel · **Cuisine:** american · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** eggs 8, breakfast sausage 150g cooked and crumbled, spinach 1 cup, salt, pepper (makes 12; 3 per serving)
- **Diets OK:** keto, low_carb, omnivore, paleo
- **Allergens:** eggs
- **Swaps:** sausage→diced sweet potato + kale (The Paleo Diet's "targeted carb" version, vegetarian); check sausage for gluten fillers; add cheddar (dairy)
- **Approx:** ~540 kcal · 4g C · 36g P · 42g F
- **Source:** commonly reported keto/paleo meal-prep staple (r/ketoendurance); Sweet Potato & Kale Egg Muffins, The Paleo Diet athlete recipes (https://thepaleodiet.com/recipes/paleo-recipes-for-athletes/)
- **Why:** the grab-and-go low-carb breakfast — bake Sunday, reheat or eat cold in the car

### B-062 · Breakfast burrito with eggs, black beans & cheese
- **Context:** everyday, recovery, travel · **Cuisine:** mexican · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** large flour tortilla 1, eggs 2, black beans 100g, cheddar 30g, salsa 2 tbsp, avocado ¼, pepper and onion sauté (makes 6, freeze)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten
- **Swaps:** add bacon (omnivore, the higher-calorie training-day version); tortilla→corn tortillas 2 (gluten-free); omit cheese (dairy-free)
- **Approx:** ~560 kcal · 58g C · 28g P · 22g F
- **Source:** standard freezer recovery burrito (incredibleegg.org spicy black bean breakfast burrito; danawhitenutrition.com recovery burrito); r/Ultramarathon tracked-day breakfast wrap
- **Why:** the freezer-to-microwave recovery breakfast — carbs and protein in one hand on the way to work

### B-063 · Egg & cheese English muffin
- **Context:** everyday, pre-session, travel · **Cuisine:** american · **Prep:** 10 min · **Batch:** yes
- **Ingredients:** wholewheat English muffin 1, eggs 2, cheddar 30g, spinach, tomato slice
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten
- **Swaps:** eggs→tofu scramble (vegan, soy); muffin→GF muffin (gluten-free); assemble 5 Sunday, wrap and freeze
- **Approx:** ~450 kcal · 40g C · 26g P · 18g F
- **Source:** standard vegetarian endurance-athlete breakfast sandwich (220triathlon.com vegetarian triathlete guide; therunningchannel.com)
- **Why:** the fast-food breakfast sandwich, made at home — complete protein plus carbs before a session

### B-064 · Chimichurri steak & eggs
- **Context:** recovery, rest-day · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** skirt steak 150g, eggs 2 fried, chimichurri (parsley, garlic, olive oil, vinegar) 2 tbsp, lettuce leaves or grain-free wrap
- **Diets OK:** keto, low_carb, omnivore, paleo
- **Allergens:** eggs
- **Swaps:** add roasted potatoes 200g (+40g C, the training-day version); steak→leftover chicken; wrap→flour tortilla (gluten)
- **Approx:** ~540 kcal · 5g C · 44g P · 38g F
- **Source:** Chimichurri Steak Breakfast Burrito, The Paleo Diet athlete recipes (https://thepaleodiet.com/recipes/paleo-recipes-for-athletes/)
- **Why:** a named paleo-athlete recipe — the protein-heavy rest-day breakfast for people who don't want a sweet bowl

### B-065 · Sweet potato & sausage skillet
- **Context:** recovery, rest-day · **Cuisine:** american · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** sweet potato 250g diced, breakfast sausage (GF, no fillers) 120g, red pepper ½, onion ½, olive oil 1 tbsp, paprika (makes 3)
- **Diets OK:** low_carb, omnivore, paleo
- **Allergens:** none
- **Swaps:** add 2 fried eggs (eggs, the classic paleo hash); sausage→check label for gluten/dairy fillers; sausage→black beans (vegan)
- **Approx:** ~520 kcal · 48g C · 24g P · 26g F
- **Source:** The Pretty Bee top-9-allergen-free meal plan, Day 7; commonly reported paleo athlete weekend breakfast (r/paleo)
- **Why:** egg-free, nut-free, grain-free and still carries real carbs from sweet potato — a rest-day breakfast that reheats for days

### B-066 · Sweet potato "toast" with avocado & egg
- **Context:** pre-session, rest-day · **Cuisine:** american · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** sweet potato 250g sliced lengthways and roasted, avocado ½ mashed, fried egg 1, everything-bagel seasoning
- **Diets OK:** low_carb, omnivore, paleo, pescatarian, vegetarian
- **Allergens:** eggs, sesame
- **Swaps:** omit egg (vegan, allergen-free); omit sesame seasoning (sesame-free); roast the slices Sunday, toast to reheat
- **Approx:** ~420 kcal · 45g C · 11g P · 22g F
- **Source:** Avocado Sweet Potato Toast, The Paleo Diet athlete recipes, pre-workout category (https://thepaleodiet.com/recipes/paleo-recipes-for-athletes/)
- **Why:** bread swapped for sweet potato rounds — a real trend among paleo athletes, not a gimmick

### B-067 · Baked sweet potato with almond butter & banana
- **Context:** everyday, pre-session · **Cuisine:** general · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** sweet potato 300g baked (microwave 8 min), almond butter 1.5 tbsp, banana 1, cinnamon, pinch salt
- **Diets OK:** omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** tree_nuts
- **Swaps:** almond butter→sunflower seed butter (nut-free, allergen-free); add Greek yogurt (dairy, +10g P); bake 4 Sunday and reheat
- **Approx:** ~480 kcal · 78g C · 9g P · 15g F
- **Source:** commonly reported paleo/whole-food pre-ride breakfast in Feed Zone-adjacent real-food content; not tied to a named athlete
- **Why:** the paleo answer to porridge and banana — 78g of grain-free carbs before a session

### B-068 · Ground beef & sweet potato hash
- **Context:** recovery, rest-day · **Cuisine:** american · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** lean ground beef 300g, sweet potato 300g diced, onion 1, red pepper 1, paprika, olive oil 1 tbsp (makes 3)
- **Diets OK:** low_carb, omnivore, paleo
- **Allergens:** none
- **Swaps:** beef→ground turkey (leaner); add a fried egg (eggs); sweet potato→white potato (cheaper, same job)
- **Approx:** ~540 kcal · 38g C · 34g P · 26g F
- **Source:** standard paleo/Whole30-style breakfast hash, widely reported in endurance-athlete real-food rotations (Feed Zone-adjacent); commonly reported
- **Why:** free of all nine allergens and reheats for three mornings — real protein for athletes who can't face another sweet bowl

### B-069 · Natto gohan
- **Context:** everyday, recovery · **Cuisine:** japanese · **Prep:** 5 min · **Batch:** yes
- **Ingredients:** cooked short-grain rice 200g, natto 1 pack (45g) with its tare, tamari 1 tsp, scallion 1 chopped, nori strips
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** soy
- **Swaps:** add a raw or soft-boiled egg yolk (traditional, eggs); tamari→soy sauce (gluten); add kimchi (fish unless vegan kimchi)
- **Approx:** ~430 kcal · 68g C · 18g P · 8g F
- **Source:** traditional Japanese breakfast staple (https://www.justonecookbook.com/traditional-japanese-breakfast-at-home/); commonly reported as an everyday breakfast of Japanese endurance athletes
- **Why:** rice carbs plus 18g fermented-soy protein in five minutes, no cooking if the rice is batch-made

### B-070 · Tamagoyaki, rice & miso soup
- **Context:** everyday, rest-day · **Cuisine:** japanese · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** eggs 3, kombu dashi 2 tbsp, tamari 1 tsp, sugar 1 tsp, cooked rice 200g, miso soup (miso 1 tbsp, kombu dashi 250ml, tofu 50g, wakame)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs, soy
- **Swaps:** kombu dashi→bonito dashi (traditional, fish); add pickles (tsukemono); tamari→soy sauce (gluten)
- **Approx:** ~520 kcal · 66g C · 28g P · 15g F
- **Source:** the standard Japanese breakfast set — rice, protein, soup (https://www.justonecookbook.com/traditional-japanese-breakfast-at-home/); commonly reported
- **Why:** a balanced, low-fat savoury breakfast where the rice and soup batch ahead and only the omelette is made fresh

### B-071 · Congee with shredded chicken & scallion
- **Context:** race-week, recovery, travel · **Cuisine:** chinese · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** white rice 80g dry, chicken stock 800ml, cooked shredded chicken 100g, ginger, scallion, tamari 1 tsp, white pepper (makes 3)
- **Diets OK:** omnivore
- **Allergens:** soy
- **Swaps:** chicken→soft tofu or a soft-boiled egg (vegetarian; soy/eggs); add sesame oil (sesame); stock→water + salt (allergen-free)
- **Approx:** ~380 kcal · 55g C · 26g P · 5g F
- **Source:** classic Chinese breakfast and convalescence food (https://en.wikipedia.org/wiki/Congee); commonly reported gentle recovery meal among East Asian endurance athletes
- **Why:** the lowest-residue warm breakfast there is — race-week, post-illness, or the morning after a very big day

### B-072 · Rice, greens & fried egg bowl
- **Context:** everyday, recovery · **Cuisine:** chinese · **Prep:** 10 min · **Batch:** yes
- **Ingredients:** cooked rice 200g, bok choy or spinach 150g sautéed, fried egg 1, leftover cooked chicken 80g, tamari 1 tbsp, sesame oil few drops
- **Diets OK:** omnivore
- **Allergens:** eggs, sesame, soy
- **Swaps:** omit chicken, add a second egg (vegetarian, Feed Zone "baked eggs with rice and greens"); omit sesame oil (sesame-free); rice→brown rice (rest-day fibre)
- **Approx:** ~520 kcal · 62g C · 34g P · 14g F
- **Source:** the "leftover dinner becomes breakfast" pattern common among triathletes eating from a staples rotation; Feed Zone Cookbook baked eggs with rice and greens (https://feedzonecookbook.com/)
- **Why:** batch-cooked rice and chicken from last night, greens and an egg — component eating at its most honest

### B-073 · Kedgeree
- **Context:** recovery, rest-day · **Cuisine:** british · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** basmati rice 100g dry, smoked or poached salmon 120g, hard-boiled eggs 2, curry powder 1 tsp, onion ½, olive oil 1 tbsp, rocket 30g, lemon (makes 2)
- **Diets OK:** mediterranean, omnivore, pescatarian
- **Allergens:** eggs, fish
- **Swaps:** salmon→smoked haddock (the British original); omit eggs (egg-free); make with yesterday's rice (10 min)
- **Approx:** ~600 kcal · 68g C · 38g P · 18g F
- **Source:** trigirl.co.uk GF/DF triathlete recovery-meal list ("kedgeree, made with rice, salmon, hard-boiled egg and rocket")
- **Why:** a rice-based recovery breakfast with 38g protein and omega-3, naturally free of gluten and dairy

### B-074 · Chilaquiles verdes with egg
- **Context:** recovery, rest-day · **Cuisine:** mexican · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** corn tortilla chips 80g, salsa verde 200ml, fried egg 1, queso fresco 30g, black beans 100g, onion, coriander (salsa makes 4)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs
- **Swaps:** omit queso (dairy-free); omit egg (vegan, allergen-free); add shredded chicken (omnivore, +20g P)
- **Approx:** ~560 kcal · 66g C · 22g P · 22g F
- **Source:** everyday Mexican breakfast, popular weekend rest-day choice in athlete food-culture round-ups; commonly reported
- **Why:** corn-based and naturally gluten-free — batch the salsa, and it's a 15-minute weekend breakfast

### B-075 · Frijoles, arroz & huevo
- **Context:** everyday, recovery · **Cuisine:** mexican · **Prep:** 10 min · **Batch:** yes
- **Ingredients:** cooked black beans 150g, cooked white rice 150g, fried egg 1, corn tortilla 1, salsa 2 tbsp, avocado ¼
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** eggs
- **Swaps:** omit egg (vegan, allergen-free); add queso fresco (dairy); reheat yesterday's rice and beans together (calentado-style, 5 min)
- **Approx:** ~560 kcal · 85g C · 22g P · 14g F
- **Source:** everyday Latin American breakfast pattern, commonly reported across Mexican, Central American and Colombian households
- **Why:** cheap, batch-ready, complete protein from beans and rice — a real cultural staple, not a Western oats default

### B-076 · Tofu & black bean breakfast burrito
- **Context:** everyday, recovery, travel · **Cuisine:** mexican · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** corn tortillas 2 large, firm tofu 150g scrambled with turmeric, black beans 100g, avocado ¼, salsa 2 tbsp, coriander (makes 6, freeze)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** soy
- **Swaps:** tofu→chickpea-flour scramble (soy-free, allergen-free); corn→flour tortilla (gluten); add vegan cheese
- **Approx:** ~460 kcal · 55g C · 22g P · 16g F
- **Source:** 220triathlon.com vegan recipe round-up (breakfast tacos with marinated tofu, beans and avocado); standard vegan adaptation of the athlete recovery burrito
- **Why:** vegan, gluten-free and freezer-batchable — the plant-based recovery burrito

### B-077 · Arepa with cheese & eggs
- **Context:** everyday, pre-session · **Cuisine:** colombian · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** arepa (pre-cooked corn flour 100g, water, salt) 1 large, mozzarella or queso fresco 40g, scrambled eggs 2, avocado slices
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs
- **Swaps:** omit eggs, cheese→black beans (vegan, allergen-free); make 6 arepas Sunday and reheat in a pan
- **Approx:** ~520 kcal · 58g C · 24g P · 20g F
- **Source:** Colombian/Venezuelan national breakfast, commonly reported as the everyday carb base of Colombian cycling culture
- **Why:** naturally gluten-free corn carbs and filling — the Colombian climber's bread

### B-078 · Tapioca crepe with cheese
- **Context:** everyday, pre-session · **Cuisine:** brazilian · **Prep:** 5 min · **Batch:** no
- **Ingredients:** hydrated tapioca starch (goma) 80g, mozzarella or queijo coalho 40g, banana ½ sliced, butter thin scrape for the pan
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** cheese→banana + cinnamon only (vegan, allergen-free); add shredded chicken (omnivore, +20g P); serve two for a long session
- **Approx:** ~420 kcal · 68g C · 12g P · 11g F
- **Source:** classic Brazilian breakfast/street staple, commonly reported as an everyday naturally gluten-free breakfast among Brazilian endurance athletes
- **Why:** a five-minute gluten-free starch that isn't rice, oats or bread — fast carbs before a session

### B-079 · Tofu scramble with roasted potatoes
- **Context:** recovery, rest-day · **Cuisine:** american · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** firm tofu 200g, turmeric ½ tsp, nutritional yeast 1 tbsp, red pepper ½, spinach 1 cup, potatoes 250g roasted, olive oil 1 tbsp, black salt
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** soy
- **Swaps:** tofu→chickpea-flour scramble (soy-free); add black beans + toast + jam (r/Ultramarathon vegan training-day version, gluten); roast the potatoes Sunday
- **Approx:** ~500 kcal · 55g C · 26g P · 18g F
- **Source:** Forks Over Knives tofu veggie scramble with roasted potatoes (https://www.forksoverknives.com/); the standard egg-free breakfast protein swap
- **Why:** the vegan scrambled-eggs-and-potatoes — 26g protein and real carbs on an easy day

### B-080 · Chickpea flour scramble with spinach & tomato
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** chickpea (besan) flour 100g, water 150ml, nutritional yeast 1 tbsp, turmeric, black salt, tomato 1 diced, spinach 1 cup, olive oil 1 tbsp
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** serve on wholegrain toast (gluten, +30g C); cook as a besan chilla (Indian pancake form); add mushrooms
- **Approx:** ~450 kcal · 52g C · 22g P · 15g F
- **Source:** standard vegan chickpea-flour omelette technique, cross-referenced in soy-free vegan protein guides (Nadura Foods; Vegan Richa-style); commonly reported
- **Why:** the only scramble that is egg-free and soy-free at once — the multi-allergy protein breakfast

### B-081 · Tempeh, spinach & carrot pita
- **Context:** everyday, pre-session, travel · **Cuisine:** american · **Prep:** 10 min · **Batch:** yes
- **Ingredients:** tempeh 100g pan-fried, wholewheat pitas 2, spinach handful, grated carrot, mustard, pickle
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, soy
- **Swaps:** pita→GF wrap (gluten-free); tempeh→hummus (sesame, lighter); assemble the night before
- **Approx:** ~480 kcal · 58g C · 26g P · 14g F
- **Source:** TrainerRoad forum "What do you eat during any given day?" — a weight-cutting athlete's 7am breakfast sandwich (https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/16)
- **Why:** a plant-protein breakfast sandwich you make the night before and eat on the way out

### B-082 · Muffin, banana & coffee
- **Context:** everyday, travel · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** bran or oat muffin 1, banana 1, coffee, Greek yogurt pot 150g
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten
- **Swaps:** muffin→GF muffin (gluten-free); yogurt→soy yogurt (dairy-free, soy); muffin→superhero muffin (homemade, see B-054)
- **Approx:** ~520 kcal · 78g C · 18g P · 15g F
- **Source:** Magali Tisseyre, 11x 70.3 champion (active.com pro-breakfast round-up)
- **Why:** the realistic no-time, airport-or-car breakfast — a pro does it too

### B-083 · Cottage cheese with pineapple & toast
- **Context:** recovery, rest-day · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** cottage cheese 250g, pineapple chunks 150g, wholegrain toast 2 slices, honey 1 tsp
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** pineapple→peaches or berries; toast→rice cakes (gluten-free); cottage cheese→dairy-free cottage cheese (dairy-free)
- **Approx:** ~480 kcal · 60g C · 32g P · 8g F
- **Source:** commonly reported high-protein rest-day breakfast in sports-dietitian content (therunningchannel.com best breakfasts for runners)
- **Why:** 32g protein for zero cooking — the highest protein-to-effort breakfast in the list

### B-084 · Rice, egg & salmon griddle cakes
- **Context:** pre-session, recovery · **Cuisine:** american · **Prep:** 15 min · **Batch:** no
- **Ingredients:** cooked rice 200g, eggs 2, tinned salmon 100g flaked, scallion, tamari 1 tsp, oil for the pan
- **Diets OK:** omnivore, pescatarian
- **Allergens:** eggs, fish, soy
- **Swaps:** salmon→crumbled tofu (vegetarian, soy); tamari→coconut aminos (soy-free); serve with a fried egg on top
- **Approx:** ~520 kcal · 55g C · 32g P · 18g F
- **Source:** Feed Zone Cookbook griddle-cakes chapter concept (https://www.skratchlabs.com/products/feed-zone-portables)
- **Why:** a savoury Feed Zone pre-ride breakfast that uses tinned salmon and yesterday's rice

### B-085 · Gluten-free cereal with pecan butter & blueberries
- **Context:** everyday · **Cuisine:** british · **Prep:** no-cook · **Batch:** no
- **Ingredients:** GF sorghum or rice cereal 90g, pecan or almond butter 1 tbsp, blueberries handful, hazelnut or oat milk 250ml
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** tree_nuts
- **Swaps:** nut butter→sunflower seed butter, milk→oat milk (nut-free, allergen-free); add banana (+25g C)
- **Approx:** ~480 kcal · 72g C · 12g P · 16g F
- **Source:** Amy Kilpin, age-group Ironman triathlete, Sundried "What I Eat In A Day" (https://www.sundried.com/blogs/nutrition/what-i-eat-in-a-day-amy-kilpin-ironman-triathlete)
- **Why:** a real age-grouper's everyday breakfast that is gluten- and dairy-free without trying

### B-086 · Hotel buffet plate: eggs, toast, porridge & banana
- **Context:** race-week, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** scrambled eggs 2, white toast 2 slices, small bowl of porridge, banana 1, orange juice 250ml
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten
- **Swaps:** skip the eggs on race morning (lower fat, the O'Donnell toast-and-jam plate); ask for water-cooked porridge (dairy-free); toast→GF bread if the buffet has it
- **Approx:** ~600 kcal · 88g C · 24g P · 14g F
- **Source:** standard "what to eat at the race hotel" guidance — build a familiar plate from buffet staples, never try anything new (nutritionbymandy.com hotel-room food ideas; consummateathlete.com)
- **Why:** the realistic race-morning breakfast when you can't control the kitchen — only universally available, low-risk items

### B-087 · Peanut butter & banana tortilla wrap
- **Context:** everyday, pre-session, travel · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** large wholewheat tortilla 1, peanut butter 2 tbsp, banana 1, honey 1 tsp, cinnamon
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** gluten, peanuts
- **Swaps:** honey→omit (vegan); peanut butter→sunflower seed butter (nut-free); tortilla→corn tortillas 2 (gluten-free)
- **Approx:** ~480 kcal · 62g C · 13g P · 20g F
- **Source:** r/Ultramarathon "What do you eat day-to-day?" — a 50K runner's daily pre-run wrap (https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/)
- **Why:** the no-toaster, eat-in-the-car pre-run carb hit

### B-088 · Cold quinoa bowl with blueberries & oat milk
- **Context:** everyday, rest-day, travel · **Cuisine:** american · **Prep:** no-cook · **Batch:** yes
- **Ingredients:** cooked quinoa 200g cold, blueberries 100g, oat milk 150ml, chia 1 tbsp, maple syrup 1 tbsp, pumpkin seeds 1 tbsp (cook 4 servings)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** oat milk→almond milk (Rich Roll's version, tree_nuts); add plant protein (+20g P); blueberries→any frozen fruit
- **Approx:** ~480 kcal · 72g C · 16g P · 12g F
- **Source:** Rich Roll's cold quinoa breakfast bowl on hungrier days (livekindly.com "What vegan ultra-endurance athlete Rich Roll eats")
- **Why:** cook quinoa Sunday, eat it cold from the fridge — the gluten-free "overnight oats" that needs no soaking

### B-089 · Boiled potatoes, bread & fried eggs
- **Context:** everyday, recovery · **Cuisine:** kenyan · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** boiled potatoes 250g, white bread 2 slices, eggs 2 fried, banana 1, sweet chai
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten
- **Swaps:** omit eggs (vegan-adjacent, the everyday camp breakfast); bread→ugali or rice (gluten-free); chai→black tea (dairy-free)
- **Approx:** ~650 kcal · 95g C · 24g P · 18g F
- **Source:** the hard-training-day breakfast at Eliud Kipchoge's Kaptagat camp, three days a week (https://www.olympics.com/en/news/what-olympic-marathon-hero-eliud-kipchoge-eats)
- **Why:** what the marathon GOAT eats after a hard session — starch-heavy, cheap, with eggs only on the days that need repair

### B-090 · Smoked salmon, avocado & spinach plate
- **Context:** rest-day, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** smoked salmon 100g, avocado 1, baby spinach 2 cups, cucumber ½, olive oil 1 tbsp, lemon, capers
- **Diets OK:** keto, low_carb, mediterranean, omnivore, paleo, pescatarian
- **Allergens:** fish
- **Swaps:** add 2 boiled eggs (eggs, +12g P — the r/AdvancedRunning rest-day plate); salmon→bacon 3 rashers (Zach Bitter's recovery-day breakfast, omnivore); add rye toast (gluten, +30g C)
- **Approx:** ~520 kcal · 10g C · 28g P · 42g F
- **Source:** commonly reported low-carb rest-day breakfast pattern (Racing Weight-style lean-day guidance); Zach Bitter's bacon, eggs and spinach recovery-day breakfast (https://www.mensjournal.com/health-fitness/zach-bitter-100-mile-american-record-holder-he-also-eats-almost-no-carbs)
- **Why:** the keto/paleo rest-day breakfast that doesn't depend on eggs — no cooking, 28g protein, omega-3

### B-091 · Semolina porridge with honey
- **Context:** pre-session, race-week · **Cuisine:** eastern-european · **Prep:** 15 min · **Batch:** no
- **Ingredients:** fine semolina 80g, milk 400ml, honey 1 tbsp, pinch salt, butter 1 tsp, banana 1
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** semolina→cream of rice (gluten-free, even lower residue); milk→oat milk, honey→maple (vegan); add cinnamon and raisins
- **Approx:** ~520 kcal · 92g C · 15g P · 9g F
- **Source:** Eastern European pro-triathlete porridge tradition — "oats, millet, semolina, buckwheat or rice with milk" (https://www.triathlete.com/nutrition/race-fueling/race-breakfasts-around-the-world/)
- **Why:** the smoothest, lowest-fibre hot cereal you can make — the race-week alternative to oats

### B-092 · Ful medames with pita
- **Context:** everyday, recovery · **Cuisine:** middle-eastern · **Prep:** 10 min · **Batch:** yes
- **Ingredients:** tinned fava beans 400g, olive oil 2 tbsp, cumin 1 tsp, garlic, lemon, tomato 1 diced, parsley, pita 2
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** add a boiled egg (eggs, traditional); pita→rice or GF flatbread (gluten-free); add tahini (sesame)
- **Approx:** ~560 kcal · 82g C · 24g P · 15g F
- **Source:** everyday Egyptian and Levantine breakfast, eaten by millions daily; commonly reported, not tied to a named athlete
- **Why:** the Middle Eastern beans-on-toast — cheap, vegan, 24g protein and slow carbs

### B-093 · Labneh, cucumber, tomato, olives & pita
- **Context:** everyday, rest-day · **Cuisine:** middle-eastern · **Prep:** no-cook · **Batch:** no
- **Ingredients:** labneh or thick Greek yogurt 200g, olive oil 1 tbsp, za'atar, cucumber ½, tomato 1, olives 30g, wholewheat pita 2
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten, sesame
- **Swaps:** labneh→hummus (vegan, sesame); pita→GF flatbread (gluten-free); za'atar→omit (sesame-free); add a boiled egg (eggs)
- **Approx:** ~520 kcal · 62g C · 22g P · 20g F
- **Source:** standard Levantine/Turkish breakfast plate, commonly reported in Mediterranean-diet athlete content
- **Why:** a savoury, vegetable-forward rest-day plate you assemble in five minutes with no stove

### B-094 · Kimchi fried rice with fried egg
- **Context:** recovery, rest-day · **Cuisine:** korean · **Prep:** 10 min · **Batch:** yes
- **Ingredients:** day-old cooked rice 200g, kimchi 100g, scallion, tamari 1 tsp, sesame oil 1 tsp, oil 1 tsp, fried egg 1, nori
- **Diets OK:** omnivore, pescatarian
- **Allergens:** eggs, fish, sesame, soy
- **Swaps:** kimchi→vegan kimchi (no fish sauce; vegetarian); add leftover chicken or pork (omnivore, +20g P); omit sesame (sesame-free)
- **Approx:** ~500 kcal · 68g C · 16g P · 16g F
- **Source:** everyday Korean home dish, commonly reported as the leftover-rice breakfast in Korean households; not tied to a named athlete
- **Why:** yesterday's rice, a jar of kimchi and an egg — ten minutes, probiotic, and it uses up leftovers

### B-095 · Molletes
- **Context:** everyday, recovery · **Cuisine:** mexican · **Prep:** 10 min · **Batch:** yes
- **Ingredients:** bolillo or crusty roll 1 large halved, refried beans 200g, cheese 40g, pico de gallo 4 tbsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** cheese→omit or vegan cheese (vegan); add chorizo (omnivore); roll→GF baguette (gluten-free)
- **Approx:** ~560 kcal · 78g C · 26g P · 16g F
- **Source:** everyday Mexican breakfast, commonly eaten across Mexican households; not tied to a named athlete
- **Why:** the Mexican beans-on-toast — batch the beans, and it's a 10-minute high-carb, high-protein breakfast

### B-096 · Grilled salmon, rice & miso soup
- **Context:** recovery, rest-day · **Cuisine:** japanese · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** salmon fillet 120g grilled with salt, cooked rice 200g, miso soup (miso 1 tbsp, dashi 250ml, tofu, wakame), pickles, nori
- **Diets OK:** omnivore, pescatarian
- **Allergens:** fish, soy
- **Swaps:** salmon→tinned mackerel (cheaper, no grilling); dashi→kombu dashi (still fish from salmon); add a soft egg (eggs)
- **Approx:** ~580 kcal · 66g C · 36g P · 16g F
- **Source:** the classic Japanese breakfast set (shiozake) — grilled salted salmon, rice, miso soup, pickles (https://www.justonecookbook.com/traditional-japanese-breakfast-at-home/); commonly reported
- **Why:** a recovery breakfast with 36g protein, omega-3 and rice, naturally free of gluten and dairy

### B-097 · Sweet potato, cottage cheese & small oats
- **Context:** pre-session, race-week · **Cuisine:** american · **Prep:** 10 min · **Batch:** yes
- **Ingredients:** roasted sweet potato 150g, cottage cheese 150g, rolled oats 40g cooked in water, cinnamon, pinch salt
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** oats→omit and double the sweet potato (gluten-free); cottage cheese→dairy-free yogurt (dairy-free); add honey
- **Approx:** ~420 kcal · 62g C · 24g P · 6g F
- **Source:** Linsey Corbin, 3x Ironman champion — her race-morning breakfast (pro-triathlete race-morning round-ups; active.com)
- **Why:** a pro's race-morning plate that proves the carbs don't have to be toast or oats — roast the sweet potato the night before

### B-098 · Veggie cooked breakfast: beans, tomatoes, mushrooms & toast
- **Context:** recovery, rest-day · **Cuisine:** british · **Prep:** 15 min · **Batch:** no
- **Ingredients:** baked beans 200g, tomatoes 2 halved and grilled, mushrooms 150g fried in olive oil, wholegrain toast 2 slices, spinach handful
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** add 2 poached eggs (eggs, +12g P); add halloumi (dairy); toast→GF bread (gluten-free, allergen-free)
- **Approx:** ~480 kcal · 72g C · 20g P · 12g F
- **Source:** the vegetarian version of the British weekend cooked breakfast; commonly reported UK-athlete rest-day breakfast (220triathlon.com reader features)
- **Why:** a proper weekend cooked breakfast that is vegan as written and still 20g protein

### B-099 · Pasta with olive oil & parmesan, pre-stage style
- **Context:** carb-load, pre-session · **Cuisine:** italian · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** pasta 120g dry, olive oil 1 tbsp, parmesan 20g, salt, black pepper
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** pasta→white rice 200g cooked (Team Sky's shorter-stage option, gluten-free); omit parmesan (vegan); add a ham omelette on the side (Orre's full pre-stage breakfast, eggs)
- **Approx:** ~620 kcal · 92g C · 20g P · 20g F
- **Source:** pro-peloton pre-stage breakfast — Henrik Orre (Team Sky chef, Velochef) pairs omelette with rice or pasta by stage length (https://www.cyclist.co.uk/in-depth/865/team-sky-recipes-for-cycling-success)
- **Why:** pasta for breakfast is exactly what the WorldTour eats before a 200 km stage — the biggest low-fibre carb load you can make in 15 minutes

### B-100 · Pão de queijo with fruit
- **Context:** pre-session, travel · **Cuisine:** brazilian · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** pão de queijo (tapioca starch 250g, milk 120ml, oil 60ml, eggs 2, grated cheese 150g — makes 20; 5 per serving), banana 1, coffee
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs
- **Swaps:** buy frozen and bake 15 min (the everyday Brazilian way); add ham (omnivore); serve with tapioca crepe for a long session
- **Approx:** ~500 kcal · 60g C · 14g P · 22g F
- **Source:** Brazilian breakfast staple, commonly reported among Brazilian endurance athletes and sold frozen in most supermarkets; not tied to a named athlete
- **Why:** naturally gluten-free cheese bread that freezes and bakes from frozen — grab-and-go carbs with a bit of protein


---

## Lunch (100)

### L-001 · Chicken, jasmine rice & broccoli with teriyaki
- **Context:** everyday, recovery · **Cuisine:** american · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** chicken breast 150g grilled, jasmine rice 200g cooked, broccoli 150g steamed, teriyaki sauce 2 tbsp, sesame seeds 1 tsp (makes 4)
- **Diets OK:** omnivore
- **Allergens:** sesame, soy
- **Swaps:** teriyaki→coconut aminos (soy-free, gluten-free); chicken→salmon (pescatarian, adds fish); frozen veg + microwave rice (5-min version)
- **Approx:** ~620 kcal · 75g C · 45g P · 12g F
- **Source:** The Kitchn "A Triathlete's Sunday Meal Prep Routine" (https://www.thekitchn.com/a-triathletes-sunday-meal-prep-routine-235207); Triathlete.com meal-prep guide (https://www.triathlete.com/nutrition/the-busy-triathletes-guide-to-meal-prepping/); u/ahm911 marathon meal prep, r/MealPrepSunday (https://old.reddit.com/r/MealPrepSunday/)
- **Why:** the canonical triathlete meal-prep lunch — protein, rice, veg, sauce, cooked once for the week

### L-002 · Chicken, brown rice, roasted veg & avocado
- **Context:** everyday, recovery · **Cuisine:** american · **Prep:** batch — 30 min, 4 servings · **Batch:** yes
- **Ingredients:** chicken breast 150g, brown rice 180g cooked, roasted mixed veg 150g, avocado 1/2, olive oil 1 tbsp, lemon (makes 4)
- **Diets OK:** mediterranean, omnivore
- **Allergens:** none
- **Swaps:** chicken→chickpeas or tofu (vegan); brown rice→quinoa (same carbs, faster); add lemon-dijon vinaigrette (Featherstone build-a-bowl style)
- **Approx:** ~580 kcal · 65g C · 40g P · 18g F
- **Source:** Fuelin coached-athlete meal template (https://fuelin.com/articles/race-ready-your-nutrition-playbook-for-endurance-success); Meghann Featherstun RD "Build-a-Bowl" (https://featherstonenutrition.com/build-a-bowl-lemon-dijon-vinaigrette/); trigirl.co.uk GF/DF recovery-meal list
- **Why:** dairy-free, gluten-free, zero allergens — the bowl every RD tells athletes to build

### L-003 · Rotisserie chicken, rice, slaw & edamame with tamari-hoisin
- **Context:** everyday, recovery · **Cuisine:** american · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** rotisserie chicken 150g shredded, microwave rice 200g cooked, coleslaw mix 1.5 cups, edamame 1/2 cup, cucumber, green onion, tamari 2 tbsp, hoisin 1 tbsp, chili crunch 1 tsp (makes 4)
- **Diets OK:** omnivore
- **Allergens:** sesame, soy
- **Swaps:** tamari/hoisin→coconut aminos (soy-free); chicken→baked tofu (vegetarian)
- **Approx:** ~510 kcal · 52g C · 44g P · 16g F
- **Source:** Meghann Featherstun RD, "Runner Rotisserie Chicken Salad — 15-minute meal" (https://featherstonenutrition.com/runner-rotisserie-chicken-salad-15-minute-meal/)
- **Why:** 44g protein in 12 minutes using shop shortcuts — the realistic busy-week lunch

### L-004 · White rice, grilled chicken & steamed carrots
- **Context:** pre-session, race-week · **Cuisine:** general · **Prep:** 20 min · **Batch:** yes
- **Ingredients:** white rice 200g cooked, chicken breast 150g grilled, carrots 1 cup peeled and well-cooked, olive oil 1 tsp, salt
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** chicken→white fish (pescatarian, adds fish); carrots→courgette (lower fibre still)
- **Approx:** ~600 kcal · 75g C · 40g P · 10g F
- **Source:** TriWorldHub "Race Week Meal Plan for Endurance Athletes" (https://triworldhub.com/race-week-meal-plan-for-endurance-athletes/)
- **Why:** low-residue, familiar, zero allergens — the race-week lunch that won't surprise your gut

### L-005 · Chicken, white rice & steamed veg with a banana-milk shake
- **Context:** recovery · **Cuisine:** general · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** chicken breast 150g, white rice 200g cooked, steamed mixed veg 1 cup, side shake: banana 1, milk 300ml, whey 1 scoop
- **Diets OK:** omnivore
- **Allergens:** dairy
- **Swaps:** milk/whey→oat milk + pea protein (dairy-free); chicken→tofu (vegetarian, adds soy)
- **Approx:** ~750 kcal · 95g C · 55g P · 12g F
- **Source:** Precision Fuel & Hydration recovery guidance, 1–1.2 g/kg carb + 20–40g protein within 1–2 h (https://www.precisionhydration.com/performance-advice/nutrition/nutrition-endurance-performance/)
- **Why:** the post-lunchtime-session lunch — hits recovery carb and protein numbers with one plate and one glass

### L-006 · Chicken, rice & black bean burrito bowl
- **Context:** everyday, recovery · **Cuisine:** mexican · **Prep:** batch — 30 min, 5 servings · **Batch:** yes
- **Ingredients:** white rice 200g cooked, black beans 1 cup, grilled chicken 120g, salsa 3 tbsp, sweetcorn 1/2 cup, guacamole 2 tbsp, lime (makes 5)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** chicken→ground turkey (runtothefinish version); chicken→extra beans (vegan); add cheese (adds dairy)
- **Approx:** ~650 kcal · 85g C · 38g P · 16g F
- **Source:** Triathlete.com meal-prep guide (https://www.triathlete.com/nutrition/the-busy-triathletes-guide-to-meal-prepping/); runtothefinish.com GF runner meal plan; "burrito after the group ride" pattern commonly reported on Slowtwitch / r/triathlon
- **Why:** the post-long-ride lunch — huge carb flexibility and no allergens as written

### L-007 · Salmon, brown rice & roasted veg
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — 30 min, 4 servings · **Batch:** yes
- **Ingredients:** salmon fillet 150g baked, brown rice 180g cooked, roasted courgette/pepper/carrot 150g, olive oil 1 tbsp, lemon (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian
- **Allergens:** fish
- **Swaps:** fresh salmon→canned wild salmon (cheaper batch); brown rice→white rice (lower fibre pre-session)
- **Approx:** ~600 kcal · 65g C · 40g P · 18g F
- **Source:** Triathlete.com "The Busy Triathlete's Guide to Meal Prepping" (https://www.triathlete.com/nutrition/the-busy-triathletes-guide-to-meal-prepping/)
- **Why:** omega-3s plus complex carbs — the go-to recovery-lunch formula

### L-008 · Miso-glazed salmon, white rice & pickled cucumber
- **Context:** everyday, recovery · **Cuisine:** japanese · **Prep:** batch — 25 min, 4 servings · **Batch:** yes
- **Ingredients:** salmon fillet 150g, miso 1 tbsp, mirin 1 tbsp, tamari 1 tbsp, white rice 180g cooked, cucumber quick-pickled in rice vinegar, steamed greens (makes 4)
- **Diets OK:** omnivore, pescatarian
- **Allergens:** fish, soy
- **Swaps:** miso glaze→teriyaki (u/Prudent_Exercise_471's version, soy sauce adds gluten); salmon→tofu (vegan)
- **Approx:** ~600 kcal · 65g C · 38g P · 18g F
- **Source:** commonly reported Japanese-style batch lunch; salmon teriyaki rice bowl from u/Prudent_Exercise_471 (40–60 mpw runner), r/Ultramarathon "What do you eat day-to-day?" (https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/)
- **Why:** gluten-free with tamari, reheats well, and a real change of flavour from chicken-rice

### L-009 · Poke bowl — tuna, sushi rice, edamame & avocado
- **Context:** everyday, race-week, recovery · **Cuisine:** japanese · **Prep:** 15 min · **Batch:** no
- **Ingredients:** sushi rice 200g cooked, sashimi-grade tuna 120g cubed (or cooked salmon), edamame 1/2 cup, avocado 1/2, cucumber, tamari 1 tbsp, sesame seeds 1 tsp
- **Diets OK:** omnivore, pescatarian
- **Allergens:** fish, sesame, soy
- **Swaps:** raw tuna→cooked salmon on 250g rice (chirashi-style race-week version); omit sesame (sesame-free); tuna→marinated tofu (vegan)
- **Approx:** ~620 kcal · 80g C · 32g P · 16g F
- **Source:** poke/chirashi widely reported as a warm-weather and carb-load lunch among coastal triathletes and runners (community-reported, r/triathlon "what I eat race week")
- **Why:** big low-fibre carb hit from the rice, moderate protein, easy on digestion

### L-010 · California rolls, miso soup & edamame
- **Context:** everyday, pre-session, travel · **Cuisine:** japanese · **Prep:** no-cook · **Batch:** no
- **Ingredients:** California rolls 8 pieces (store-bought), miso soup 1 cup, edamame 1/2 cup, tamari 1 tbsp
- **Diets OK:** omnivore, pescatarian
- **Allergens:** shellfish, soy
- **Swaps:** California roll→salmon nigiri x6 (shellfish-free, adds fish); →cucumber-avocado roll (vegan)
- **Approx:** ~500 kcal · 75g C · 20g P · 10g F
- **Source:** sushi widely reported as a grab lunch among triathletes in urban training hubs (community-reported); supermarket sushi is a common pre-afternoon-session choice
- **Why:** high-carb, low-fat, bought in two minutes — fine even close to an afternoon session

### L-011 · Rice, black beans, guac & hot sauce
- **Context:** everyday, recovery, rest-day · **Cuisine:** mexican · **Prep:** batch — 30 min, 5 servings · **Batch:** yes
- **Ingredients:** brown rice 200g cooked (or half quinoa), black beans 1 cup, guacamole 3 tbsp, salsa 2 tbsp, hot sauce, nutritional yeast 1 tbsp (makes 5)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** black beans→lentils + corn (220 Triathlon "Mexican rice bowl"); add rotisserie chicken (higher protein, omnivore); add cheese (adds dairy)
- **Approx:** ~650 kcal · 95g C · 20g P · 18g F
- **Source:** Rich Roll's "One Bowl", The Plantpower Way (https://www.livekindly.com/what-vegan-ultra-endurance-athlete-rich-roll-eats/); Sangamon on TrainerRoad forum, weekly Sunday-prep work lunch (https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/5)
- **Why:** cheap, plant-forward, allergen-free, batch-cookable — the vegan ultra-runner's staple that ordinary athletes already eat

### L-012 · Rice, black beans & roasted plantain
- **Context:** carb-load, everyday · **Cuisine:** colombian · **Prep:** batch — 25 min, 4 servings · **Batch:** yes
- **Ingredients:** white rice 200g cooked, black or red beans 1 cup, ripe plantain 1 roasted, avocado 1/4, lime, coriander (makes 4)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add a fried egg (bandeja-paisa-style, adds eggs); beans→shredded chicken (omnivore)
- **Approx:** ~600 kcal · 100g C · 16g P · 12g F
- **Source:** the everyday plate of Latin American and Colombian cyclists, commonly reported as the cultural food base of the Bernal/Quintana generation; standard rice-and-beans component lunch across allergen-safe meal-prep content
- **Why:** 100g of carbs with zero allergens — a carb-load lunch that isn't pasta

### L-013 · Sweet potato, black bean & quinoa bowl with cumin-lime dressing
- **Context:** everyday, rest-day · **Cuisine:** american · **Prep:** batch — 30 min, 4 servings · **Batch:** yes
- **Ingredients:** roasted sweet potato 200g, black beans 150g, quinoa 100g cooked, avocado 1/4, cumin-lime dressing 2 tbsp (olive oil, lime, cumin) (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** black beans→brown lentils + pumpkin seeds (allergen-safe lentil bowl); add feta (adds dairy)
- **Approx:** ~550 kcal · 85g C · 18g P · 16g F
- **Source:** Forks Over Knives "How to Make a Buddha Bowl" component format (https://www.forksoverknives.com/); FARE-adjacent allergen-safe athlete roundups (lentil/quinoa bowls)
- **Why:** fully allergen-clean, fibre-rich rest-day bowl that still carries real carbs

### L-014 · Sweet potato, roasted tofu, veg & avocado bowl
- **Context:** everyday · **Cuisine:** american · **Prep:** batch — 35 min, 4 servings · **Batch:** yes
- **Ingredients:** sweet potato 200g roasted, firm tofu 150g roasted, mixed roasted veg 1 cup, avocado 1/2, tamari 1 tbsp (makes 4)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** soy
- **Swaps:** tofu→tempeh + brown rice (tempeh stir-fry version); tofu→chickpeas (soy-free)
- **Approx:** ~550 kcal · 60g C · 25g P · 20g F
- **Source:** r/veganfitness "Full day of eating on a Vegan Diet", u/ConsciouslivwithALI (707 pts) (https://old.reddit.com/r/veganfitness/); tempeh stir-fry from 220 Triathlon "best vegan recipes for triathletes" (https://www.220triathlon.com/news/best-vegan-recipes-for-triathletes)
- **Why:** the highest-upvoted vegan athlete component bowl — roast Sunday, assemble daily

### L-015 · Rice, tofu, veg & seeds bowl
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** 10 min · **Batch:** yes
- **Ingredients:** white or brown rice 250g cooked, tofu 120g, mixed vegetables 1.5 cups, pumpkin seeds 1 tbsp, hemp seeds 1 tbsp, tamari 1 tbsp
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** soy
- **Swaps:** add a fried egg (Yee's optional add, adds eggs); tofu→chicken (omnivore)
- **Approx:** ~650 kcal · 90g C · 30g P · 16g F
- **Source:** Alex Yee's typical lunch, lmtless.substack.com (Olympic champion, mostly plant-based)
- **Why:** a world champion's everyday lunch is a rice bowl — cook rice ahead, assemble in 10 minutes

### L-016 · Bibimbap — rice, namul veg, beef & fried egg with gochujang
- **Context:** everyday, recovery, travel · **Cuisine:** korean · **Prep:** batch — 30 min, 4 servings · **Batch:** yes
- **Ingredients:** white rice 250g cooked, sautéed spinach, carrot, bean sprouts, mushroom 200g total, lean beef strips 120g, fried egg 1, gochujang 1 tbsp, sesame oil 1 tsp (makes 4)
- **Diets OK:** omnivore
- **Allergens:** eggs, sesame, soy
- **Swaps:** beef→marinated tofu and omit egg (vegan); gochujang→tamari + chili (gluten-free)
- **Approx:** ~700 kcal · 95g C · 35g P · 18g F
- **Source:** Korean national dish (https://en.wikipedia.org/wiki/Bibimbap); bibimbap called out as holding up well as a make-ahead bento lunch (https://www.jansfoodsteps.com/simple-korean-bibimbap-bento-lunch-box-recipe/)
- **Why:** five vegetables plus rice and protein in one box, and it travels at room temperature

### L-017 · Soba noodles, baked tofu & edamame with sesame-ginger dressing
- **Context:** everyday, travel · **Cuisine:** japanese · **Prep:** batch — 20 min, 4 servings · **Batch:** yes
- **Ingredients:** soba noodles 100g dry, baked tofu 150g, edamame 1/2 cup, shredded carrot and cabbage, spring onion, sesame-ginger-tamari dressing 3 tbsp (makes 4)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, sesame, soy
- **Swaps:** soba→100% buckwheat soba or rice noodles (gluten-free); dressing→peanut-ginger (adds peanuts)
- **Approx:** ~540 kcal · 70g C · 28g P · 16g F
- **Source:** common vegan endurance-athlete packed lunch across greenletes.com and r/veganfitness meal-prep content; 220 Triathlon vegan recipes (https://www.220triathlon.com/news/best-vegan-recipes-for-triathletes)
- **Why:** eaten cold from a box — the vegan packed lunch that doesn't need a microwave

### L-018 · Chicken, rice vermicelli & herbs with lime-ginger dressing
- **Context:** everyday, pre-session, travel · **Cuisine:** vietnamese · **Prep:** batch — 20 min, 4 servings · **Batch:** yes
- **Ingredients:** poached chicken 150g shredded, rice vermicelli 100g dry, shredded carrot, cucumber, mint, coriander, dressing: lime 1, ginger, olive oil 1 tbsp, salt (makes 4)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** dressing→fish sauce-lime (classic, adds fish); dressing→peanut sauce (adds peanuts); chicken→tofu (vegan, adds soy)
- **Approx:** ~480 kcal · 60g C · 36g P · 10g F
- **Source:** standard nut-free version of the Vietnamese noodle salad, widely reported as a warm-weather training lunch (community-reported)
- **Why:** light, allergen-free as written, carb-adequate — ideal after a lunchtime swim in summer

### L-019 · Rice-paper rolls with shrimp, vermicelli & veg
- **Context:** everyday, pre-session, travel · **Cuisine:** vietnamese · **Prep:** 15 min · **Batch:** no
- **Ingredients:** rice paper wrappers 6, cooked shrimp 120g, rice vermicelli 60g, carrot and cucumber julienne, lettuce, mint, tamari-lime dip 2 tbsp
- **Diets OK:** omnivore, pescatarian
- **Allergens:** shellfish, soy
- **Swaps:** shrimp→sliced turkey breast (shellfish-free); tamari→coconut aminos (soy-free); skip peanut sauce (keeps nut-free)
- **Approx:** ~420 kcal · 55g C · 24g P · 8g F
- **Source:** rice-paper and rice-vermicelli cited as naturally GF carb bases across GF endurance-athlete guidance; nut-allergy blogs' standard "skip the peanut sauce" swap (commonly reported)
- **Why:** light, low-fat, packs cold — different from the rice-bowl rotation

### L-020 · Beef & broccoli stir-fry with rice
- **Context:** everyday, recovery · **Cuisine:** chinese · **Prep:** batch — 20 min, 4 servings · **Batch:** yes
- **Ingredients:** beef strips 150g, broccoli 1.5 cups, garlic, ginger, tamari 2 tbsp, jasmine rice 180g cooked (makes 4)
- **Diets OK:** omnivore
- **Allergens:** soy
- **Swaps:** beef→shrimp (leftover shrimp stir-fry, adds shellfish); beef→tofu (vegan); tamari→coconut aminos (soy-free)
- **Approx:** ~600 kcal · 65g C · 38g P · 15g F
- **Source:** stir-fry-with-rice is the most common dinner-to-lunch carry-over reported in triathlete meal-prep guides; T_Field on TrainerRoad forum (leftover shrimp stir-fry) (https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/15)
- **Why:** cook once at dinner, eat three more times — gluten-free with tamari

### L-021 · Egg fried rice with veg
- **Context:** everyday, race-week, recovery · **Cuisine:** chinese · **Prep:** 15 min · **Batch:** no
- **Ingredients:** day-old rice 250g cooked, eggs 2, frozen peas/carrots 1 cup, tamari 2 tbsp, spring onion, sesame oil 1 tsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs, sesame, soy
- **Swaps:** race-week: use 300g rice, skip the veg (lower fibre); add shrimp or chicken (more protein); eggs→tofu (vegan)
- **Approx:** ~550 kcal · 80g C · 20g P · 14g F
- **Source:** Eat For Endurance RD "5 Easy Make-Ahead Lunch Recipes" fried-rice bowl (https://www.eatforendurance.com/post/make-ahead-lunch-recipes); commonly cited post-long-run and carb-load meal in triathlete "what I eat" content
- **Why:** the classic way to turn Sunday's rice into a fast, cheap, high-carb lunch

### L-022 · Tofu & broccoli pad see ew
- **Context:** everyday · **Cuisine:** thai · **Prep:** batch — 20 min, 4 servings · **Batch:** yes
- **Ingredients:** wide rice noodles 100g dry, firm tofu 150g, broccoli 1.5 cups, tamari 2 tbsp, garlic, a little sugar (makes 4)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** soy
- **Swaps:** add an egg (classic, adds eggs); tofu→chicken (omnivore)
- **Approx:** ~550 kcal · 75g C · 22g P · 14g F
- **Source:** Thai takeout turned batch cook, widely reported among endurance athletes (community-reported)
- **Why:** gluten-free noodle lunch that reheats well — leftover variety beyond Western staples

### L-023 · Beef pho
- **Context:** everyday, pre-session, recovery · **Cuisine:** vietnamese · **Prep:** batch — 60 min broth, 6 servings; 10 min to assemble · **Batch:** yes
- **Ingredients:** beef broth 500ml (batch-made), rice noodles 100g dry, thin-sliced beef 100g, bean sprouts, basil, lime, chilli (makes 6 broth)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** beef→chicken (chicken pho); check broth for fish sauce (adds fish)
- **Approx:** ~500 kcal · 65g C · 28g P · 10g F
- **Source:** pho widely reported as a batch-broth lunch among endurance athletes who freeze broth in portions (community-reported)
- **Why:** gluten-free, easy-digesting, rice-noodle carbs — good before an afternoon session too

### L-024 · Dal, rice & spinach
- **Context:** everyday, recovery, rest-day · **Cuisine:** indian · **Prep:** batch — 30 min, 6 servings, freezes well · **Batch:** yes
- **Ingredients:** red lentil dal 1.5 cups (red lentils, onion, tomato, cumin, turmeric, oil 1 tsp), basmati rice 180g cooked, sautéed spinach 1 cup (makes 6)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** oil→ghee (adds dairy); add a boiled egg (adds eggs); rice→roti (adds gluten)
- **Approx:** ~550 kcal · 90g C · 22g P · 10g F
- **Source:** widely reported endurance-athlete staple among South Asian and vegetarian/vegan runners (community-reported, r/AdvancedRunning, r/veganfitness)
- **Why:** naturally vegan and allergen-free, high-carb, cheap — the cleanest batch lunch there is

### L-025 · Chana masala with rice
- **Context:** everyday, rest-day · **Cuisine:** indian · **Prep:** batch — 30 min, 5 servings, freezes well · **Batch:** yes
- **Ingredients:** chickpeas 1.5 cups, tomato-onion masala (onion, tomato, garlic, ginger, garam masala, oil 1 tsp), basmati rice 180g cooked, coriander (makes 5)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add naan (adds gluten); add yogurt (adds dairy)
- **Approx:** ~550 kcal · 90g C · 18g P · 10g F
- **Source:** widely reported South Asian vegetarian/vegan endurance-athlete lunch staple (community-reported)
- **Why:** chickpeas in a big pot — high-carb, freezer-friendly, no allergens

### L-026 · Chickpea & sweet potato coconut curry with rice
- **Context:** everyday, rest-day · **Cuisine:** indian · **Prep:** batch — 35 min, 5 servings, freezes well · **Batch:** yes
- **Ingredients:** chickpeas 1.5 cups, sweet potato 200g cubed, coconut milk 1/2 cup, curry paste or powder 1 tbsp, spinach 1 cup, basmati rice 180g cooked (makes 5)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** chickpeas→chicken thigh (omnivore); sweet potato→butternut squash
- **Approx:** ~600 kcal · 90g C · 18g P · 16g F
- **Source:** 220 Triathlon "best vegan recipes for triathletes" (https://www.220triathlon.com/news/best-vegan-recipes-for-triathletes)
- **Why:** one pot on Sunday gives five allergen-free, high-carb lunches

### L-027 · Chicken tikka masala with rice
- **Context:** everyday, recovery · **Cuisine:** indian · **Prep:** batch — 35 min, 4 servings · **Batch:** yes
- **Ingredients:** chicken breast 150g, tikka masala sauce 1 cup (tomato, cream, spices), basmati rice 180g cooked, coriander (makes 4)
- **Diets OK:** omnivore
- **Allergens:** dairy
- **Swaps:** cream→coconut milk (dairy-free); chicken→paneer (vegetarian) or chickpeas (vegan with coconut milk)
- **Approx:** ~650 kcal · 75g C · 40g P · 18g F
- **Source:** widely reported UK/US takeout-turned-batch-cook staple among endurance athletes (community-reported)
- **Why:** dinner leftovers that everyone actually wants to eat the next day — gluten-free as written

### L-028 · Tandoori chicken, chickpea-lentil mix, peas & yogurt
- **Context:** everyday, pre-session · **Cuisine:** indian · **Prep:** batch — marinate and cook chicken Sunday, 15 min assembly · **Batch:** yes
- **Ingredients:** chicken breast 150g marinated in tandoori paste, pre-cooked chickpea and lentil mix 1 cup, peas 1/2 cup, spinach 1 cup, plain yogurt 1/2 cup, grapes 1 cup
- **Diets OK:** omnivore
- **Allergens:** dairy
- **Swaps:** yogurt→coconut yogurt (dairy-free); chicken→paneer (vegetarian)
- **Approx:** ~620 kcal · 65g C · 45g P · 15g F
- **Source:** Megan Powell (triathlete, medical student), "What I Eat In A Day", Sundried (https://www.sundried.com/blogs/nutrition/what-i-eat-in-a-day-by-megan-powell-triathlete)
- **Why:** a named athlete's double-session-day lunch — high protein with legume carbs and fruit

### L-029 · Curd rice
- **Context:** race-week, recovery, travel · **Cuisine:** indian · **Prep:** 10 min · **Batch:** no
- **Ingredients:** white rice 250g cooked, plain yogurt 150g, tempering: mustard seeds, curry leaves, ginger, oil 1 tsp, pomegranate or grapes 1/2 cup
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** yogurt→coconut yogurt (vegan); add a boiled egg (more protein, adds eggs)
- **Approx:** ~450 kcal · 75g C · 14g P · 8g F
- **Source:** South Indian everyday comfort food, commonly reported as a race-eve and travel meal among South Indian endurance athletes for its gentleness on digestion
- **Why:** low-fibre, low-fat, probiotic and cooling — a genuine race-week lunch, not a Western imitation

### L-030 · Injera with misir wat & boiled egg
- **Context:** everyday, recovery · **Cuisine:** ethiopian · **Prep:** batch — 40 min stew, 4 servings · **Batch:** yes
- **Ingredients:** teff injera 150g, red lentil stew (misir wat) 200g, hard-boiled egg 1, cooked cabbage and carrot side (makes 4 stew)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs
- **Swaps:** omit egg (vegan); injera→rice (if no teff)
- **Approx:** ~500 kcal · 85g C · 20g P · 10g F
- **Source:** staple pattern of Ethiopian training-camp meals associated with the Bekele/Gebrselassie generation of distance runners (commonly reported cultural staple)
- **Why:** spiced lentils over fermented flatbread — plant-protein heavy and gluten-free with 100% teff injera

### L-031 · Githeri — maize & bean stew
- **Context:** everyday, rest-day · **Cuisine:** kenyan · **Prep:** batch — 40 min, 4 servings · **Batch:** yes
- **Ingredients:** boiled maize kernels 150g, cooked beans 150g, tomato 1, onion 1/2, bell pepper 1/2, oil 1 tsp (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add chopped kale or spinach; add avocado (more calories)
- **Approx:** ~450 kcal · 85g C · 18g P · 5g F
- **Source:** traditional Kenyan running-camp dish — RunnersConnect (https://runnersconnect.net/diet-of-kenyan-runners/), Enda (https://www.endasportswear.com/blogs/news/eat-like-a-kenyan-to-run-like-a-kenyan)
- **Why:** the one-pot staple Kenyan camps run on — cheap, complete protein by combination, reheats all week

### L-032 · Ugali, lean beef stew & managu
- **Context:** everyday, recovery · **Cuisine:** kenyan · **Prep:** batch — stew ahead, ugali fresh 15 min · **Batch:** yes
- **Ingredients:** ugali (maize meal) 200g, lean beef stew 120g (beef, tomato, onion), managu or spinach/collard greens 1 cup (makes 4 stew)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** beef→beans (vegan); ugali→rice
- **Approx:** ~650 kcal · 80g C · 35g P · 15g F
- **Source:** Eliud Kipchoge's reported everyday lunch/dinner — Olympics.com (https://www.olympics.com/en/news/what-olympic-marathon-hero-eliud-kipchoge-eats)
- **Why:** the greatest marathoner's lunch is maize, greens and a bit of meat — simple, high-carb, allergen-free

### L-033 · Rice, beans & bread post-long-run plate
- **Context:** carb-load, recovery · **Cuisine:** kenyan · **Prep:** 10 min · **Batch:** yes
- **Ingredients:** white rice 150g cooked, cooked beans 100g, white bread 2 slices, small ugali 100g, sweet chai 1 cup
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** bread→GF bread (gluten-free); chai with milk (adds dairy)
- **Approx:** ~700 kcal · 140g C · 22g P · 6g F
- **Source:** reported post-long-run recovery spread at the Kaptagat camp — traininkenya.com / Sweat Elite
- **Why:** three carb sources, almost no fat — glycogen refill the way Kaptagat does it

### L-034 · Pasta with tomato sauce & parmesan
- **Context:** everyday, pre-session, travel · **Cuisine:** italian · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** spaghetti or penne 100g dry, olive oil 1 tbsp, garlic 1 clove, canned tomatoes 1 cup, parmesan 2 tbsp, basil
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** add capers + olives (puttanesca, pro-cyclist version); pasta→GF pasta (gluten-free); omit parmesan (vegan); add frozen veg + berries on the side (office meal-prep version)
- **Approx:** ~520 kcal · 85g C · 15g P · 10g F
- **Source:** Kipchoge's go-to when travelling without ugali (https://www.olympics.com/en/news/what-olympic-marathon-hero-eliud-kipchoge-eats); Rob Krar "partial to pasta for lunch" (https://www.outsideonline.com/running/training/running-101/why-you-should-eat-like-an-elite/); puttanesca as pro-cyclist lunch, Cyclist.co.uk (https://www.cyclist.co.uk/in-depth/best-food-for-cycling-how-to-eat-like-a-pro)
- **Why:** two elite runners independently name plain pasta as their lunch — it's the pre-session default for a reason

### L-035 · Pasta al tonno
- **Context:** everyday, pre-session, race-week · **Cuisine:** italian · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** pasta 120g dry, canned tuna in olive oil 120g, cherry tomatoes 1 cup, olive oil 1 tbsp, garlic, parsley
- **Diets OK:** mediterranean, omnivore, pescatarian
- **Allergens:** fish, gluten
- **Swaps:** pasta→GF pasta (gluten-free); tuna→chickpeas (vegan)
- **Approx:** ~700 kcal · 100g C · 35g P · 18g F
- **Source:** archetypal pro-cyclist team-bus/hotel lunch across Italian and Spanish WorldTour teams, per team-chef reporting incl. Hannah Grant's "Eat Race Win" (commonly reported pattern)
- **Why:** tinned fish, pasta, olive oil — done in 15 minutes and it's what the peloton eats

### L-036 · Spaghetti bolognese (leftover portion)
- **Context:** everyday, pre-session, recovery · **Cuisine:** italian · **Prep:** batch — 40 min sauce, 4 servings · **Batch:** yes
- **Ingredients:** spaghetti 100g dry, lean beef or turkey mince 120g, tomato sauce 1 cup, onion, carrot, celery, parmesan 1 tbsp (makes 4 sauce)
- **Diets OK:** omnivore
- **Allergens:** dairy, gluten
- **Swaps:** pasta→GF pasta (gluten-free); omit parmesan (dairy-free); mince→lentils (vegan, see L-037)
- **Approx:** ~620 kcal · 80g C · 32g P · 16g F
- **Source:** pasta named repeatedly as a training-table staple by pro cyclists and ultrarunners (Cyclist.co.uk https://www.cyclist.co.uk/in-depth/best-food-for-cycling-how-to-eat-like-a-pro; Outside on Rob Krar)
- **Why:** the classic dinner-to-lunch carry-over — reliably high-carb and familiar before hard sessions

### L-037 · Lentil bolognese with gluten-free pasta
- **Context:** everyday, recovery · **Cuisine:** italian · **Prep:** batch — 30 min, 5 servings, freezes well · **Batch:** yes
- **Ingredients:** brown lentils 1.5 cups cooked, marinara 1.5 cups, GF pasta 100g dry, nutritional yeast 1 tbsp, basil (makes 5)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** GF pasta→wheat pasta (adds gluten); add parmesan (adds dairy)
- **Approx:** ~550 kcal · 90g C · 24g P · 6g F
- **Source:** 220 Triathlon "best vegan recipes for triathletes" (https://www.220triathlon.com/news/best-vegan-recipes-for-triathletes)
- **Why:** vegan and gluten-free in one filling pasta lunch — no allergens at all as written

### L-038 · Baked ziti (leftover portion)
- **Context:** carb-load, everyday, pre-session · **Cuisine:** italian · **Prep:** batch — 50 min, 6 servings · **Batch:** yes
- **Ingredients:** ziti 100g dry, marinara 1 cup, ricotta 1/4 cup, mozzarella 30g, turkey mince 100g optional (makes 6 tray)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** pasta→GF pasta (gluten-free); omit turkey (vegetarian as written)
- **Approx:** ~600 kcal · 75g C · 28g P · 18g F
- **Source:** pasta bakes widely reported as a carb-load and everyday batch dish among endurance athletes (community-reported; consistent with pasta-forward pro-cycling pattern, GCN https://www.globalcyclingnetwork.com/video/pro-cycling-nutrition-what-do-riders-eat-in-a-race)
- **Why:** one tray, six lunches, and it reheats perfectly — the carb-load week workhorse

### L-039 · Pasta with pesto, chicken & sun-dried tomato
- **Context:** everyday, recovery · **Cuisine:** italian · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** fusilli 100g dry, grilled chicken 120g, basil pesto 2 tbsp, sun-dried tomato 4, parmesan 1 tbsp, mixed veg 1 cup
- **Diets OK:** mediterranean, omnivore
- **Allergens:** dairy, gluten, tree_nuts
- **Swaps:** pesto→nut-free basil-oil pesto (nut-free); pasta→GF pasta (gluten-free); add Greek yogurt + protein powder on the side (u/rightkneebutter's version)
- **Approx:** ~600 kcal · 70g C · 38g P · 18g F
- **Source:** Hannah Grant (Tinkoff-Saxo chef, "Eat Race Win") pesto-and-protein pasta as a team lunch staple (https://roadcyclinguk.com/how-to/how-to-fuel-like-a-pro-cycling-with-tinkoff-saxo-chef-hannah-grant.html); u/rightkneebutter, r/Ultramarathon (https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/)
- **Why:** pro-team chef's lunch and a reddit runner's "same thing every day" — the same dish

### L-040 · Chicken & cherry tomato pasta salad
- **Context:** everyday, race-week, recovery, travel · **Cuisine:** italian · **Prep:** batch — 15 min, 4 servings · **Batch:** yes
- **Ingredients:** fusilli 100g dry, grilled chicken 120g, cherry tomatoes 1 cup, cucumber, olive oil 1 tbsp, parmesan 2 tbsp, basil (makes 4)
- **Diets OK:** mediterranean, omnivore
- **Allergens:** dairy, gluten
- **Swaps:** omit parmesan (dairy-free); pasta→GF pasta (gluten-free); omit chicken (vegetarian)
- **Approx:** ~600 kcal · 70g C · 40g P · 15g F
- **Source:** pasta salad named as the standard post-race team-bus lunch in GCN "Pro Cycling Nutrition" (https://www.globalcyclingnetwork.com/video/pro-cycling-nutrition-what-do-riders-eat-in-a-race); commonly made the night before for race-trip drives (r/triathlon)
- **Why:** eaten cold from a tub on the team bus or in the car on the way to a race

### L-041 · Thai peanut lentil-pasta salad
- **Context:** everyday, race-week, travel · **Cuisine:** thai · **Prep:** batch — 20 min, 4 servings · **Batch:** yes
- **Ingredients:** lentil pasta 100g dry, shredded carrot, bell pepper, broccoli, red cabbage 1.5 cups total, peanut butter 2 tbsp, tamari 1 tbsp, rice vinegar, lime, ginger, garlic (makes 4)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** peanuts, soy
- **Swaps:** peanut butter→sunflower seed butter (peanut-free); tamari→coconut aminos (soy-free); add chicken or tofu (more protein)
- **Approx:** ~560 kcal · 72g C · 30g P · 20g F
- **Source:** Meghann Featherstun RD, Featherstone Nutrition (https://featherstonenutrition.com/thai-peanut-pasta-salad/)
- **Why:** cold pasta salad that travels and keeps — an RD's race-week/travel lunch, vegan and gluten-free

### L-042 · Plain white pasta with olive oil & salt
- **Context:** carb-load, pre-session, race-week · **Cuisine:** italian · **Prep:** 15 min · **Batch:** no
- **Ingredients:** white pasta 120g dry, olive oil 1 tbsp, salt, black pepper
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** add parmesan (adds dairy); pasta→GF white rice pasta (gluten-free)
- **Approx:** ~500 kcal · 90g C · 14g P · 10g F
- **Source:** commonly reported pre-key-session and race-week lunch; consistent with TriWorldHub race-week guidance (https://triworldhub.com/race-week-meal-plan-for-endurance-athletes/)
- **Why:** minimal fibre, maximal familiar carbs — the lunch before an afternoon key workout

### L-043 · Minestrone with parmesan & bread
- **Context:** everyday, recovery, rest-day · **Cuisine:** italian · **Prep:** batch — 40 min, 6 servings, freezes well · **Batch:** yes
- **Ingredients:** mixed veg (carrot, celery, courgette, tomato) 2 cups, cannellini beans 1 cup, small pasta 50g dry, vegetable stock, parmesan 15g, bread 1 slice (makes 6)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** pasta→GF pasta and GF bread (gluten-free); omit parmesan (vegan)
- **Approx:** ~450 kcal · 60g C · 16g P · 10g F
- **Source:** classic Italian training-table soup, commonly reported rest-day staple in Mediterranean-diet-for-athletes coverage (Cyclist.co.uk https://www.cyclist.co.uk/in-depth/best-food-for-cycling-how-to-eat-like-a-pro)
- **Why:** fibre, carbs and protein in one pot — the rest-day lunch that still feeds you

### L-044 · Lentil & vegetable soup with bread
- **Context:** everyday, rest-day, travel · **Cuisine:** mediterranean · **Prep:** batch — 30 min, 6 servings, freezes well · **Batch:** yes
- **Ingredients:** red or green lentils 100g dry, carrot, celery, onion, tomato, vegetable stock, olive oil 1 tbsp, wholegrain bread 2 slices (makes 6)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** bread→GF bread (gluten-free); add a poached egg (adds eggs)
- **Approx:** ~480 kcal · 75g C · 22g P · 8g F
- **Source:** staple batch-cook rest-day lunch across r/triathlon and r/AdvancedRunning meal-prep threads; dietitianapproved.com "Eat Plants, Train Hard" vegan triathlete guide
- **Why:** cheap, iron-rich, freezer-friendly — the boring-but-good winter training lunch

### L-045 · Butternut squash & chickpea soup
- **Context:** everyday, race-week, rest-day · **Cuisine:** general · **Prep:** batch — 30 min, 4 servings, freezes well · **Batch:** yes
- **Ingredients:** butternut squash 400g, canned chickpeas 200g, vegetable stock, coconut milk 100ml, ginger, cumin, rice 100g cooked on the side (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add bread (adds gluten); add shredded chicken (omnivore)
- **Approx:** ~500 kcal · 80g C · 16g P · 12g F
- **Source:** allergen-safe soup format cited in FARE-adjacent recipe roundups (gruballergy.com "Allergen-Free Recipes & Meal Ideas"); commonly reported
- **Why:** low-residue and free of all nine allergens — race-week or rest-day when digestibility matters

### L-046 · Chicken, rice & vegetable soup
- **Context:** everyday, race-week, recovery, rest-day · **Cuisine:** american · **Prep:** batch — 30 min, 4 servings, freezes well · **Batch:** yes
- **Ingredients:** roast chicken 150g shredded, rice 60g dry, carrot, celery, onion, chicken stock 500ml, parsley (makes 4)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** rice→egg noodles (chicken noodle soup, adds gluten and eggs); serve with a wholegrain roll (adds gluten)
- **Approx:** ~450 kcal · 50g C · 32g P · 8g F
- **Source:** classic chicken-and-rice soup, documented as allergen-safe comfort food across allergy-cooking resources; Nancy Clark-style "rest and recover" comfort meal guidance (commonly reported)
- **Why:** gentle, low-residue, protein-forward — race week, rest day, or when you're fighting a cold

### L-047 · Jacket potato with tuna & sweetcorn
- **Context:** everyday, recovery, travel · **Cuisine:** british · **Prep:** 45 min bake or 10 min microwave — batch-bake potatoes Sunday · **Batch:** yes
- **Ingredients:** baking potato 300g, canned tuna 120g, sweetcorn 1/2 cup, Greek yogurt 2 tbsp, chives, side salad
- **Diets OK:** omnivore, pescatarian
- **Allergens:** dairy, fish
- **Swaps:** yogurt→olive oil + lemon (dairy-free); tuna→chickpeas (vegan); microwave the potato (10 min)
- **Approx:** ~500 kcal · 80g C · 35g P · 8g F
- **Source:** classic British athlete lunch, commonly reported in UK triathlon and running features (220triathlon.com, tri247.com); trigirl.co.uk GF/DF recovery-meal list
- **Why:** a whole potato is a huge, low-fat carb source British athletes already default to

### L-048 · Jacket potato with chili & cheese
- **Context:** everyday, recovery · **Cuisine:** british · **Prep:** batch — chili frozen in portions, potato baked fresh · **Batch:** yes
- **Ingredients:** baking potato 300g, beef or turkey chili 1 cup (from L-079), cheddar 30g, spring onion
- **Diets OK:** omnivore
- **Allergens:** dairy
- **Swaps:** omit cheese (dairy-free); bean chili (vegan)
- **Approx:** ~650 kcal · 85g C · 35g P · 18g F
- **Source:** jacket-potato-with-topping lunch widely reported as a UK/Ireland training-lunch staple (community-reported)
- **Why:** big recovery-sized carb-plus-protein hit from a freezer portion and one potato

### L-049 · Jacket potato with baked beans
- **Context:** everyday, recovery, rest-day · **Cuisine:** british · **Prep:** 10 min microwave · **Batch:** no
- **Ingredients:** baking potato 300g, baked beans 1 can (400g), olive oil 1 tsp, side salad
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add grated cheddar (adds dairy); add a fried egg (adds eggs); check beans label for GF sauce
- **Approx:** ~550 kcal · 105g C · 22g P · 5g F
- **Source:** trigirl.co.uk GF/DF triathlete recovery-meal list ("Baked white or sweet potato with baked beans or tuna"); classic UK student/athlete lunch
- **Why:** three ingredients, 100g of carbs, no allergens — as cheap as an athlete lunch gets

### L-050 · Baked sweet potato with black beans & avocado
- **Context:** everyday, rest-day · **Cuisine:** mexican · **Prep:** batch — bake potatoes Sunday, 5 min assembly · **Batch:** yes
- **Ingredients:** sweet potato 300g baked, black beans 1 cup, avocado 1/2, salsa 3 tbsp, pumpkin seeds 1 tbsp, lime, coriander
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** black beans→homemade refried beans + hot sauce (TrainerRoad version); add cheese (adds dairy)
- **Approx:** ~520 kcal · 85g C · 16g P · 14g F
- **Source:** "stuffed sweet potatoes" named as an allergen-safe athlete meal in FARE-adjacent roundups (gruballergy.com); ssmith1187 on TrainerRoad forum (https://www.trainerroad.com/forum/t/canned-corn-and-black-beans-my-cheap-but-effective-training-fuel-source/13689/9); 220 Triathlon vegan recipes
- **Why:** free of all nine allergens, batch-bakeable, and enough carbs for a training day

### L-051 · New potato salad with poached salmon
- **Context:** everyday, recovery · **Cuisine:** british · **Prep:** 25 min · **Batch:** yes
- **Ingredients:** new potatoes 300g boiled, salmon fillet 150g poached, mixed leaves 60g, olive oil 1 tbsp, lemon, dill
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian
- **Allergens:** fish
- **Swaps:** salmon→grilled chicken (fish-free); salmon→chickpeas (vegan)
- **Approx:** ~520 kcal · 45g C · 35g P · 20g F
- **Source:** trigirl.co.uk GF/DF triathlete main-meal list ("New potato salad with poached salmon")
- **Why:** naturally gluten-free and dairy-free, potatoes as the carb — a real carb salad, not leaves

### L-052 · Potato salad with olives, herbs & pumpkin seeds
- **Context:** everyday, recovery, rest-day · **Cuisine:** mediterranean · **Prep:** batch — 30 min, 4 servings, keeps 4 days · **Batch:** yes
- **Ingredients:** baby potatoes 300g boiled, dill and parsley, pitted olives 8, pumpkin seeds 2 tbsp, olive oil 1 tbsp, lemon, dijon mustard 1 tsp (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add a chopped hard-boiled egg + cornichons (German-style, adds eggs); add white beans (more protein)
- **Approx:** ~420 kcal · 55g C · 10g P · 18g F
- **Source:** Rich Roll & Julie Piatt, The Plantpower Way potato salad (https://www.bluezones.com/recipe/the-plantpower-way-potato-salad/); boiled potatoes as real-food endurance carbs per Precision Fuel & Hydration
- **Why:** Roll's training-week staple — whole-food carbs, no mayo, no allergens

### L-053 · Three-bean salad with olive oil & herbs
- **Context:** everyday, rest-day, travel · **Cuisine:** mediterranean · **Prep:** no-cook · **Batch:** yes
- **Ingredients:** kidney beans, chickpeas, cannellini beans 1 cup each (canned), red onion 1/2, parsley, olive oil 2 tbsp, red wine vinegar 2 tbsp (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add tuna (pescatarian, adds fish); add feta (adds dairy); serve with pita (adds gluten)
- **Approx:** ~420 kcal · 55g C · 20g P · 12g F
- **Source:** bean salad widely reported as a no-cook batch lunch among endurance athletes (community-reported, r/EatCheapAndHealthy)
- **Why:** three cans and a jar — keeps five days, no cooking, no allergens

### L-054 · Tuna, white bean & olive oil salad
- **Context:** everyday, travel · **Cuisine:** mediterranean · **Prep:** no-cook · **Batch:** no
- **Ingredients:** canned tuna 120g, cannellini beans 1 cup, red onion 1/4, parsley, olive oil 1 tbsp, lemon, crusty bread 1 slice
- **Diets OK:** mediterranean, omnivore, pescatarian
- **Allergens:** fish, gluten
- **Swaps:** skip bread (gluten-free); tuna→canned sardines + quinoa (omega-3 version); tuna→chickpeas (vegan)
- **Approx:** ~500 kcal · 55g C · 35g P · 12g F
- **Source:** classic Mediterranean-diet athlete lunch, consistent with Precision Fuel & Hydration everyday nutrition guidance (https://www.precisionhydration.com/performance-advice/nutrition/nutrition-endurance-performance/); sardine variant via runner-lunch roundups
- **Why:** shelf-stable, zero-cook, high-protein — the desk lunch you can keep in a drawer

### L-055 · Quinoa tabbouleh with chickpeas
- **Context:** everyday, race-week, rest-day · **Cuisine:** middle-eastern · **Prep:** batch — 20 min, 4 servings, keeps 4 days · **Batch:** yes
- **Ingredients:** quinoa 150g cooked, chickpeas 200g, parsley 1 cup, mint, tomato, cucumber, lemon 1, olive oil 2 tbsp (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add feta (adds dairy); quinoa→bulgur (classic, adds gluten); add grilled chicken (omnivore)
- **Approx:** ~480 kcal · 65g C · 18g P · 16g F
- **Source:** dietitianapproved.com "Eat Plants, Train Hard" vegan triathlete guide; standard quinoa-for-bulgur GF swap in meal-prep content
- **Why:** grain plus legume complete protein, gluten-free and sesame-free — works cold all week

### L-056 · Quinoa, black bean, kale & feta recovery salad
- **Context:** everyday, recovery · **Cuisine:** american · **Prep:** batch — 30 min, 6 servings, keeps 4 days · **Batch:** yes
- **Ingredients:** quinoa 1 cup cooked, black beans 1 cup, kale 2 cups chopped, red pepper 1/2, red onion, coriander, lime 1, olive oil 1.5 tbsp, avocado 1/2, toasted pumpkin seeds 2 tbsp, feta or cotija 30g (makes 6)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** omit feta (vegan); kale→beet greens + cashews (Molly Huddle's version, adds tree_nuts)
- **Approx:** ~520 kcal · 60g C · 18g P · 22g F
- **Source:** Shalane Flanagan & Elyse Kopecky, Run Fast. Eat Slow. — Flanagan's go-to post-hard-run meal (https://www.womensrunning.com/health/food/fuel-recovery-quinoa-salad/); Molly Huddle's quinoa, black bean & beet-green salad, ESPN (https://www.espn.com/espnw/life-style/story/_/id/23092614/what-athletes-eat-boston-marathoner-molly-huddle-quinoa-salad-quick-recovery)
- **Why:** two Olympians independently eat this as a post-run lunch — complete protein, keeps all week

### L-057 · Thai quinoa bowl with edamame, cabbage & peanut-lime dressing
- **Context:** everyday, recovery, travel · **Cuisine:** thai · **Prep:** batch — 25 min, 4 servings · **Batch:** yes
- **Ingredients:** quinoa 1 cup cooked, red cabbage 1 cup, carrot 1, edamame 3/4 cup, coriander, peanuts 2 tbsp, dressing: peanut butter 1 tbsp, lime, tamari 1 tbsp, sesame oil 1 tsp (makes 4)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** peanuts, sesame, soy
- **Swaps:** peanuts/PB→sunflower seeds and seed butter (peanut-free); add chicken (omnivore)
- **Approx:** ~500 kcal · 60g C · 22g P · 18g F
- **Source:** Run Fast Cook Fast Eat Slow, Shalane Flanagan & Elyse Kopecky (https://consummateathlete.com/try-this-inflammation-fighting-thai-quinoa-salad-recipe-from-run-fast-cook-fast-eat-slow/)
- **Why:** cookbook recovery bowl built for training blocks — plant protein, eaten cold from a box

### L-058 · Couscous, roasted veg & chickpeas with lemon-herb dressing
- **Context:** everyday, rest-day · **Cuisine:** mediterranean · **Prep:** batch — 30 min, 4 servings · **Batch:** yes
- **Ingredients:** couscous 150g cooked, chickpeas 1 cup, roasted aubergine/courgette/pepper 1.5 cups, parsley, lemon 1, olive oil 1 tbsp (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** couscous→quinoa (gluten-free); add feta or grilled halloumi (adds dairy); couscous→farro + olives (Greek-bowl version)
- **Approx:** ~520 kcal · 80g C · 16g P · 12g F
- **Source:** "Greek bowls" named as a flexible triathlete lunch base in Triathlete.com meal-prep guide (https://www.triathlete.com/nutrition/the-busy-triathletes-guide-to-meal-prepping/); PusherMan on TrainerRoad forum, summer couscous lunch rotation (https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/13)
- **Why:** roast a tray of veg on Sunday and the grain does the rest — vegan, Mediterranean, one swap to GF

### L-059 · Chicken, quinoa & chopped veg bowl with lemon-olive oil
- **Context:** everyday, rest-day · **Cuisine:** mediterranean · **Prep:** batch — 20 min, 4 servings · **Batch:** yes
- **Ingredients:** grilled chicken breast 120g, quinoa 150g cooked, cucumber, tomato, bell pepper 1.5 cups, mixed greens 1 cup, olive oil 1 tbsp, lemon (makes 4)
- **Diets OK:** mediterranean, omnivore
- **Allergens:** none
- **Swaps:** chicken→chickpeas (vegan); quinoa→farro (adds gluten)
- **Approx:** ~480 kcal · 45g C · 35g P · 15g F
- **Source:** u/ElderberryNo5595 "fourth meal" template, r/Ultramarathon (https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/); staple across r/triathlon meal-prep threads
- **Why:** protein and carbs both athlete-sized without being heavy midday — no allergens, no reheating

### L-060 · Falafel, quinoa & leafy greens with tahini
- **Context:** everyday · **Cuisine:** middle-eastern · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** falafel 4 pieces, quinoa 100g cooked, watercress/rocket/spinach 2 cups, tomato, beetroot, cucumber, tahini dressing 2 tbsp, dark chocolate 2 squares
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, sesame
- **Swaps:** falafel→lentils (gluten-free, sesame-free with lemon-oil dressing); falafel→hummus (Kilpin's other rotation)
- **Approx:** ~520 kcal · 65g C · 20g P · 18g F
- **Source:** Amy Kilpin (vegetarian Ironman triathlete), "What I Eat In A Day", Sundried (https://www.sundried.com/)
- **Why:** a named age-grouper's rotating "protein of the day" lunch — leaves plus a real carb and a legume

### L-061 · Cobb salad with chicken
- **Context:** everyday, rest-day · **Cuisine:** american · **Prep:** 15 min · **Batch:** no
- **Ingredients:** romaine and mixed greens 3 cups, grilled chicken 150g, hard-boiled egg 1, bacon 2 slices, avocado 1/2, blue cheese 30g, olive oil vinaigrette 2 tbsp
- **Diets OK:** keto, low_carb, omnivore
- **Allergens:** dairy, eggs
- **Swaps:** omit blue cheese (paleo, dairy-free); add a small potato (moderate-carb rest day)
- **Approx:** ~620 kcal · 8g C · 45g P · 42g F
- **Source:** Zach Bitter's reported low-carb lunch pattern, Men's Journal (https://www.mensjournal.com/health-fitness/zach-bitter-100-mile-american-record-holder-he-also-eats-almost-no-carbs)
- **Why:** the 100-mile record holder's rest-day lunch — protein target hit, carbs near zero

### L-062 · Salmon & avocado greens bowl
- **Context:** everyday, rest-day · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** leftover salmon 150g, mixed greens 2 cups, avocado 1/2, walnuts 20g, olive oil 1 tbsp, lemon
- **Diets OK:** keto, low_carb, mediterranean, omnivore, paleo, pescatarian
- **Allergens:** fish, tree_nuts
- **Swaps:** walnuts→pumpkin seeds (nut-free); salmon→sliced leftover steak (Sisson's other version)
- **Approx:** ~560 kcal · 9g C · 34g P · 40g F
- **Source:** Mark Sisson's described everyday Primal lunch, Thrive Market (https://thrivemarket.com/blog/mark-sissons-daily-routine-from-breakfast-to-dinner)
- **Why:** leftover protein over greens — the Primal Endurance founder's actual daily plate

### L-063 · Greek salad with grilled chicken & feta
- **Context:** everyday, rest-day · **Cuisine:** mediterranean · **Prep:** 15 min · **Batch:** no
- **Ingredients:** cucumber 1, tomato 2, red onion 1/4, kalamata olives 8, feta 40g, grilled chicken breast 150g, olive oil 1.5 tbsp, oregano
- **Diets OK:** low_carb, mediterranean, omnivore
- **Allergens:** dairy
- **Swaps:** omit feta (dairy-free, paleo); add pita (training-day carbs, adds gluten); chicken→chickpeas (vegetarian)
- **Approx:** ~460 kcal · 14g C · 38g P · 28g F
- **Source:** commonly reported Mediterranean-athlete lunch; Mediterranean-diet-and-endurance review, PMC (https://pmc.ncbi.nlm.nih.gov/articles/PMC10375324/)
- **Why:** the archetypal Greek lunch — protein-forward, olive oil, low fibre load

### L-064 · Ham & pepper omelette with side salad
- **Context:** everyday, pre-session, rest-day · **Cuisine:** british · **Prep:** 15 min · **Batch:** no
- **Ingredients:** eggs 3, ham 50g, bell pepper 1/2 diced, olive oil 1 tsp, side salad (leaves, tomato, cucumber)
- **Diets OK:** keto, low_carb, omnivore, paleo
- **Allergens:** eggs
- **Swaps:** ham→mushrooms + feta (vegetarian, adds dairy); add toast (training-day carbs, adds gluten)
- **Approx:** ~380 kcal · 8g C · 30g P · 24g F
- **Source:** Jonny Brownlee's lunch, 220triathlon.com
- **Why:** an Olympic medallist's low-fibre, protein-forward lunch that won't sit heavy before an afternoon session

### L-065 · Eggs & chicken breast with greens
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** eggs 4 fried, chicken breast 150g grilled, mixed greens 2 cups, olive oil 1 tbsp
- **Diets OK:** keto, low_carb, omnivore, paleo
- **Allergens:** eggs
- **Swaps:** add sweet potato (moderate-carb version); chicken→salmon (adds fish)
- **Approx:** ~560 kcal · 3g C · 55g P · 34g F
- **Source:** Mike McKnight's post-run meal, Diet Doctor (https://www.dietdoctor.com/low-carb-improves-ultra-runners-performance-and-health)
- **Why:** a fat-adapted ultrarunner's recovery plate — two protein sources, nothing else

### L-066 · Tuna salad lettuce wraps
- **Context:** everyday, travel · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** canned tuna 2 cans (170g), mayo 2 tbsp, celery 1 stalk diced, lemon, romaine or butter lettuce leaves 4
- **Diets OK:** keto, low_carb, omnivore, paleo, pescatarian
- **Allergens:** eggs, fish
- **Swaps:** mayo→mashed avocado (egg-free); add crackers (training-day carbs, adds gluten)
- **Approx:** ~420 kcal · 4g C · 40g P · 26g F
- **Source:** commonly reported low-carb travel/office lunch (r/ketoendurance)
- **Why:** shelf-stable protein, zero prep — the low-carb lunch on the road

### L-067 · Turkey & avocado lettuce wraps
- **Context:** everyday, rest-day, travel · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** sliced turkey breast 150g, large lettuce leaves 6, avocado 1/2, cucumber, mustard
- **Diets OK:** keto, low_carb, omnivore, paleo
- **Allergens:** none
- **Swaps:** lettuce→rice-paper wrappers + vermicelli (training-day carbs); add cheese (adds dairy)
- **Approx:** ~360 kcal · 8g C · 32g P · 20g F
- **Source:** commonly reported paleo/low-carb travel lunch (r/paleo, r/ketoendurance); nut-free rice-paper version from allergy-cooking blogs
- **Why:** the paleo answer to a sandwich — free of all nine allergens as written

### L-068 · Curried chicken salad lettuce cups
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** shredded chicken 150g, coconut yogurt 2 tbsp, curry powder 1 tsp, raisins 2 tbsp, celery 1 stalk, lettuce cups 4
- **Diets OK:** low_carb, omnivore, paleo
- **Allergens:** none
- **Swaps:** coconut yogurt→mayo (adds eggs); serve over rice (training-day carbs)
- **Approx:** ~420 kcal · 14g C · 34g P · 24g F
- **Source:** "Bombay Curry Chicken Salad", The Paleo Diet post-workout recovery recipes (https://thepaleodiet.com/recipes/paleo-recipes-for-athletes/)
- **Why:** a named paleo recovery recipe with real flavour — batch the chicken, assemble daily

### L-069 · Chicken thigh, roasted sweet potato & spinach with tahini
- **Context:** everyday, recovery · **Cuisine:** middle-eastern · **Prep:** batch — 35 min, 4 servings · **Batch:** yes
- **Ingredients:** chicken thigh 150g roasted, sweet potato 200g roasted cubes, spinach 2 cups wilted, tahini 1 tbsp, lemon (makes 4)
- **Diets OK:** mediterranean, omnivore, paleo
- **Allergens:** sesame
- **Swaps:** tahini→olive oil + lemon (sesame-free); chicken→chickpeas (vegan)
- **Approx:** ~580 kcal · 55g C · 40g P · 20g F
- **Source:** component-bowl lunch pattern across triathlete meal-prep guides (Triathlete.com https://www.triathlete.com/nutrition/the-busy-triathletes-guide-to-meal-prepping/)
- **Why:** paleo, gluten-free and dairy-free without trying — a sheet-pan lunch that batches cleanly

### L-070 · Chicken shawarma bowl with rice & tahini
- **Context:** everyday, recovery · **Cuisine:** middle-eastern · **Prep:** batch — 30 min, 4 servings · **Batch:** yes
- **Ingredients:** chicken thigh 150g in shawarma spices, basmati rice 180g cooked, chopped salad (tomato, cucumber, onion), pickles, tahini sauce 2 tbsp (makes 4)
- **Diets OK:** omnivore
- **Allergens:** sesame
- **Swaps:** tahini→garlic yogurt (adds dairy); chicken→falafel (vegan, adds gluten)
- **Approx:** ~650 kcal · 80g C · 40g P · 15g F
- **Source:** shawarma-bowl format widely reported as a fast-casual training lunch (community-reported)
- **Why:** the fast-casual bowl athletes already buy, batched at home — gluten-free, big carbs and protein

### L-071 · Mezze plate — hummus, falafel, tabbouleh & pita
- **Context:** everyday, rest-day · **Cuisine:** middle-eastern · **Prep:** 5 min · **Batch:** yes
- **Ingredients:** hummus 1/2 cup, falafel 4 pieces, tabbouleh 1 cup (bulgur, parsley, tomato), pita 1, olives, cucumber
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, sesame
- **Swaps:** pita→GF flatbread and tabbouleh→quinoa (gluten-free); shop-bought everything (5-min rest-day version)
- **Approx:** ~600 kcal · 85g C · 18g P · 18g F
- **Source:** common vegetarian/vegan rest-day lunch across r/veganfitness and endurance-nutrition blogs; mezze/Greek-bowl pattern in Triathlete.com meal-prep coverage
- **Why:** naturally vegan and easy to buy pre-made — a higher-fibre rest-day plate that still hits carbs

### L-072 · Chicken souvlaki, lemon rice & tzatziki
- **Context:** everyday, recovery · **Cuisine:** greek · **Prep:** batch — 30 min, 4 servings · **Batch:** yes
- **Ingredients:** chicken skewers 150g, lemon rice 180g cooked, tzatziki 3 tbsp (yogurt, cucumber, garlic), Greek salad side (makes 4)
- **Diets OK:** mediterranean, omnivore
- **Allergens:** dairy
- **Swaps:** tzatziki→dairy-free yogurt version; add pita (adds gluten)
- **Approx:** ~600 kcal · 65g C · 42g P · 16g F
- **Source:** Greek-bowl pattern named in Triathlete.com meal-prep guide (https://www.triathlete.com/nutrition/the-busy-triathletes-guide-to-meal-prepping/); commonly reported Mediterranean athlete lunch
- **Why:** gluten-free, huge protein, and the marinade does the work while you train

### L-073 · Sheet-pan ratatouille with chickpeas
- **Context:** everyday, rest-day · **Cuisine:** mediterranean · **Prep:** batch — 40 min, 4 servings · **Batch:** yes
- **Ingredients:** red onion 1/2, garlic, courgette 1/2, aubergine 1/4, red pepper 1/2, cherry tomatoes 50g, rosemary, balsamic 1 tbsp, basil, lemon, canned chickpeas 1 cup, olive oil 1 tbsp (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** omit chickpeas and add chicken (paleo); serve over rice or with bread (training-day carbs)
- **Approx:** ~400 kcal · 50g C · 15g P · 14g F
- **Source:** Hannah Grant (Tour de France team chef) via BikeRadar (https://www.bikeradar.com/advice/nutrition/tour-de-france-recipes)
- **Why:** a Tour chef's explicit easy-day meal — more veg, fewer carbs, reheats well

### L-074 · Quinoa, roasted beetroot, sweet potato & cottage cheese
- **Context:** everyday, recovery · **Cuisine:** nordic · **Prep:** batch — 60 min, 4 servings · **Batch:** yes
- **Ingredients:** quinoa 75g dry, beetroot 75g roasted, sweet potato 1/4 large roasted, cottage cheese 50g, pistachios 6g, parsley, dill, olive oil 1 tsp (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, tree_nuts
- **Swaps:** cottage cheese→extra chickpeas (vegan); omit pistachios (nut-free)
- **Approx:** ~480 kcal · 60g C · 22g P · 15g F
- **Source:** Hannah Grant (Tour de France team chef) via BikeRadar (https://www.bikeradar.com/advice/nutrition/tour-de-france-recipes)
- **Why:** a pro-team recovery-day lunch — nitrate-rich beetroot with quinoa and dairy protein

### L-075 · Tortilla española with bread
- **Context:** everyday, recovery, travel · **Cuisine:** spanish · **Prep:** batch — 30 min, 4 servings, keeps 3 days · **Batch:** yes
- **Ingredients:** potatoes 300g sliced, eggs 4, onion 1/2, olive oil 2 tbsp, crusty bread 1 slice (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** eggs, gluten
- **Swaps:** skip bread (gluten-free); add peppers or peas (trigirl veg version)
- **Approx:** ~550 kcal · 55g C · 20g P · 22g F
- **Source:** staple Spanish cycling-team travel food, commonly reported in Vuelta/team-bus nutrition features; trigirl.co.uk GF/DF recovery-meal list
- **Why:** eaten warm or cold, safe at room temperature for hours — the race-trip lunch that travels in a lunchbox

### L-076 · Black bean & sweet potato tacos on corn tortillas
- **Context:** everyday, rest-day · **Cuisine:** mexican · **Prep:** batch — 25 min, 4 servings · **Batch:** yes
- **Ingredients:** corn tortillas 4, black beans 1 cup, roasted sweet potato 1 cup, avocado 1/2, cabbage slaw, lime, coriander, cumin (makes 4)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add cheese (adds dairy); add shredded chicken (omnivore)
- **Approx:** ~520 kcal · 85g C · 16g P · 12g F
- **Source:** Bob Seebohar, Metabolic Efficiency Recipe Book vegetarian recipes (https://www.enrgperformance.com/metabolic-efficiency-training); 220 Triathlon vegan recipes
- **Why:** a sports dietitian's rest-day vegetarian recipe — vegan and allergen-free on corn tortillas

### L-077 · Bean & cheese quesadilla with salsa
- **Context:** everyday · **Cuisine:** mexican · **Prep:** 10 min · **Batch:** yes
- **Ingredients:** flour tortillas 2, black beans 1/2 cup mashed, cheddar 40g, salsa 3 tbsp, sour cream 1 tbsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** tortilla→corn tortilla (gluten-free); cheese→mashed sweet potato + vegan cheese (vegan); add chicken (omnivore)
- **Approx:** ~550 kcal · 65g C · 22g P · 20g F
- **Source:** quesadilla widely reported as a quick vegetarian training lunch (community-reported); sweet potato & black bean variant across No Meat Athlete / Forks Over Knives content
- **Why:** five ingredients, ten minutes, freezes — the student lunch that still hits carbs and protein

### L-078 · Corn tortilla tacos with chicken, avocado & salsa
- **Context:** everyday, recovery · **Cuisine:** mexican · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** corn tortillas 3 (100% corn), grilled chicken 150g, avocado 1/2, salsa 3 tbsp, shredded cabbage 50g, lime
- **Diets OK:** mediterranean, omnivore
- **Allergens:** none
- **Swaps:** chicken→black beans (vegan); add cheese (adds dairy)
- **Approx:** ~520 kcal · 55g C · 38g P · 16g F
- **Source:** corn tortillas repeatedly cited as a naturally GF carb base in GF-athlete guidance (nutritionalanatalie.com, greenletes.com)
- **Why:** cheap, portable, gluten-free and dairy-free without a single substitution

### L-079 · Turkey chili with rice
- **Context:** everyday, recovery · **Cuisine:** american · **Prep:** batch — 40 min, 6 servings, freezes well · **Batch:** yes
- **Ingredients:** turkey mince 150g, kidney beans 1 cup, diced tomatoes 1 cup, onion, garlic, chili spices, rice 150g cooked (makes 6)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** turkey→lentils (vegan); serve on a jacket potato (L-048); add cheese (adds dairy)
- **Approx:** ~600 kcal · 70g C · 40g P · 12g F
- **Source:** chili as the most common batch-dinner-to-lunch staple in triathlete meal-prep guides (The Kitchn https://www.thekitchn.com/a-triathletes-sunday-meal-prep-routine-235207)
- **Why:** the textbook freezer-portion lunch — high protein, no allergens, reheats in three minutes

### L-080 · Chipotle peanut meal-prep bowls
- **Context:** everyday, rest-day · **Cuisine:** mexican · **Prep:** batch — 30 min, 5 servings · **Batch:** yes
- **Ingredients:** rice 200g cooked, chicken or tofu 120g, black beans 1/2 cup, sweetcorn 1/2 cup, bell pepper 1/2, sauce: peanut butter 1 tbsp, chipotle, lime, tamari 1 tsp (makes 5)
- **Diets OK:** omnivore
- **Allergens:** peanuts, soy
- **Swaps:** peanut sauce→sunflower seed butter sauce (peanut-free); chicken→tofu (vegan)
- **Approx:** ~560 kcal · 70g C · 32g P · 18g F
- **Source:** Meghann Featherstun RD, Featherstone Nutrition (https://www.featherstonenutrition.com/recipe/meal-prep-chipotle-peanut-bowls/)
- **Why:** built by a running RD specifically as a Sunday batch rotation meal

### L-081 · Canned black beans & sweetcorn bowl
- **Context:** everyday, pre-session, recovery · **Cuisine:** mexican · **Prep:** 5 min · **Batch:** yes
- **Ingredients:** canned black beans 1 can rinsed, canned sweetcorn 1 can, olive oil 1 tsp, lime, chili powder, corn tortillas 2
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** serve over 200g rice (bigger carb hit); add avocado; add cheese (adds dairy)
- **Approx:** ~500 kcal · 85g C · 22g P · 8g F
- **Source:** fasterthanever on TrainerRoad forum, "canned corn and black beans — my cheap but effective training fuel source" (https://www.trainerroad.com/forum/t/canned-corn-and-black-beans-my-cheap-but-effective-training-fuel-source/13689)
- **Why:** two cans and a lime — the cheapest real training fuel on the forum, eaten before and after workouts

### L-082 · Roast chicken & veg leftovers with gravy
- **Context:** everyday, recovery · **Cuisine:** british · **Prep:** batch — from Sunday roast, portioned · **Batch:** yes
- **Ingredients:** roast chicken 150g, roast potatoes 200g, green beans or carrots 1 cup, gravy 3 tbsp
- **Diets OK:** omnivore
- **Allergens:** gluten
- **Swaps:** gravy thickened with cornflour (gluten-free); chicken→roast beef or lamb
- **Approx:** ~600 kcal · 60g C · 40g P · 18g F
- **Source:** Sunday-roast-into-weekday-lunch widely reported as a UK/Irish batch pattern among triathletes (220triathlon.com-style coverage, community-reported)
- **Why:** real family food, not a diet meal — the lunch amateur athletes already have in the fridge

### L-083 · Turkey, hummus & veg wrap with apple
- **Context:** everyday, pre-session · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** whole-wheat tortilla 1, sliced turkey breast 100g, hummus 2 tbsp, spinach, tomato, cucumber, apple 1
- **Diets OK:** omnivore
- **Allergens:** gluten, sesame
- **Swaps:** tortilla→GF wrap (gluten-free); hummus→mashed avocado (sesame-free); turkey→chickpeas (vegan)
- **Approx:** ~480 kcal · 60g C · 30g P · 12g F
- **Source:** Paula Findlay's 11:30am lunch, triathlonmagazine.ca
- **Why:** a pro's between-sessions lunch — portable, balanced, five minutes, no cooking

### L-084 · Peanut butter & banana sandwich
- **Context:** everyday, pre-session · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** whole-grain bread 2 slices (or a multigrain bagel), peanut butter 2 tbsp, banana 1
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, peanuts
- **Swaps:** bread→GF bread (gluten-free); PB→sunflower seed butter (peanut-free); make two (RobertK's high-volume portion)
- **Approx:** ~500 kcal · 65g C · 15g P · 18g F
- **Source:** Nancy Clark RD, the "sports sandwich of champions" (https://nancyclarkrd.com/2024/11/12/sports-nutrition-on-a-budget/); RobertK on TrainerRoad forum, two PB-banana bagels as lunch (https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/16)
- **Why:** cheap, high-carb, low-fibre — the pre-session lunch that never upsets a stomach

### L-085 · Turkey & salad sandwich
- **Context:** everyday, pre-session · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** whole-grain bread 2 slices or sub roll, sliced turkey or ham 100g, lettuce, tomato, mustard, pretzels or fruit on the side
- **Diets OK:** omnivore
- **Allergens:** gluten
- **Swaps:** bread→GF bread (gluten-free); add cheese (adds dairy); add apple slices + cheddar (smoked-turkey variant)
- **Approx:** ~480 kcal · 55g C · 30g P · 10g F
- **Source:** Molly Huddle "usually eats a sandwich for lunch", Outside (https://www.outsideonline.com/running/training/running-101/why-you-should-eat-like-an-elite/); Nancy Clark RD sub-sandwich game-day lunch (https://nancyclarkrd.com/2024/11/12/sports-nutrition-on-a-budget/)
- **Why:** an American record holder's lunch is a plain sandwich — permission to keep it ordinary

### L-086 · Egg salad sandwich
- **Context:** everyday · **Cuisine:** american · **Prep:** 5 min · **Batch:** yes
- **Ingredients:** hard-boiled eggs 3, whole-grain bread 2 slices, mayo 1 tbsp, mustard, lettuce, fruit on the side
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs, gluten
- **Swaps:** bread→GF bread (gluten-free); mayo→sriracha mayo (u/dirtyStick84's version)
- **Approx:** ~480 kcal · 45g C · 25g P · 20g F
- **Source:** u/dirtyStick84 (sub-3 marathoner), r/AdvancedRunning "What do YOU eat in a day?"; plain-sandwich family per Outside's elite-runner lunches
- **Why:** boil eggs on Sunday, assemble in five — cheap protein you can pack the night before

### L-087 · Hummus & veg wrap
- **Context:** everyday, pre-session, travel · **Cuisine:** middle-eastern · **Prep:** 5 min · **Batch:** no
- **Ingredients:** whole-wheat tortilla 1, hummus 4 tbsp, shredded carrot 1/2 cup, cucumber, spinach, avocado 1/4
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, sesame
- **Swaps:** tortilla→GF wrap (gluten-free); hummus→white bean spread (sesame-free); add 4 falafel (bigger lunch)
- **Approx:** ~450 kcal · 60g C · 14g P · 18g F
- **Source:** Scott Jurek's reported refuel, Sierra Club "How Does Vegan Ultramarathoner Scott Jurek Do It?" (https://www.sierraclub.org/)
- **Why:** a vegan ultra legend's portable refuel — no cooking, no fridge needed for a few hours

### L-088 · Bean, rice & cheese freezer burrito
- **Context:** everyday, pre-session, travel · **Cuisine:** mexican · **Prep:** batch — 30 min, 8 burritos frozen, reheat 3 min · **Batch:** yes
- **Ingredients:** large flour tortilla 1, refried or black beans 1/2 cup, rice 1/2 cup cooked, cheddar 30g, salsa 2 tbsp (makes 8)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** omit cheese + add avocado (Jurek's vegan version); add scrambled egg (CTS 4-in-1, adds eggs); tortilla→GF tortilla (gluten-free)
- **Approx:** ~550 kcal · 75g C · 20g P · 14g F
- **Source:** CTS TrainRight "The 4-in-1 Burrito Recipe to Fuel Your Training Day" (https://trainright.com/weekend-reading-the-4-in-1-burrito-recipe-to-fuel-your-training-day/); Scott Jurek's staple bean-and-rice burrito, Sierra Club
- **Why:** coach-endorsed grab-from-freezer lunch — cheap and endlessly customisable

### L-089 · Rotisserie chicken, kale & cranberry wrap
- **Context:** everyday, travel · **Cuisine:** american · **Prep:** 10 min · **Batch:** yes
- **Ingredients:** whole-wheat tortilla 1 large, rotisserie chicken 120g shredded, kale 1 cup massaged, dried cranberries 2 tbsp, olive oil 1 tsp, lemon
- **Diets OK:** omnivore
- **Allergens:** gluten
- **Swaps:** tortilla→GF tortilla (gluten-free); dressing→Greek yogurt (adds dairy); chicken→scrambled egg + feta (breakfast-for-lunch wrap, adds eggs and dairy)
- **Approx:** ~480 kcal · 50g C · 32g P · 15g F
- **Source:** chicken-and-kale wrap named as a triathlete lunch option in Triathlete.com meal-prep coverage (https://www.triathlete.com/nutrition/the-busy-triathletes-guide-to-meal-prepping/)
- **Why:** no reheating, packed the night before — the desk lunch that uses shop-bought chicken

### L-090 · Caprese sandwich
- **Context:** everyday, travel · **Cuisine:** italian · **Prep:** no-cook · **Batch:** no
- **Ingredients:** whole-grain bread 2 slices or ciabatta, fresh mozzarella 60g, tomato 1, basil, olive oil 1 tsp, balsamic
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** bread→GF bread (gluten-free); add ham + pesto and press (GCN team-bag panini, adds tree_nuts)
- **Approx:** ~460 kcal · 48g C · 20g P · 20g F
- **Source:** commonly reported Italian athlete travel lunch; paninis named as a pro-cycling feed-bag staple in GCN (https://www.globalcyclingnetwork.com/video/pro-cycling-nutrition-what-do-riders-eat-in-a-race)
- **Why:** no cooking, travels well — the race-weekend sandwich

### L-091 · Tofu, sweet potato & veg wrap
- **Context:** everyday, rest-day · **Cuisine:** american · **Prep:** batch — roast Sunday, assemble night before, 4 servings · **Batch:** yes
- **Ingredients:** whole-wheat tortilla 1, quinoa 60g cooked, tofu 100g roasted, sweet potato 100g roasted, sweetcorn, peppers, onion (makes 4)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, soy
- **Swaps:** tortilla→corn tortillas (gluten-free); tofu→curried chickpeas (soy-free)
- **Approx:** ~450 kcal · 65g C · 18g P · 12g F
- **Source:** u/whammywombat (WFPB, fuelling like an ultra athlete), r/Ultramarathon "What do you eat day-to-day?" (https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/)
- **Why:** a plant-based worker-athlete's actual Sunday-prepped grab-and-go rotation

### L-092 · Cottage cheese, crackers, fruit & almonds
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** cottage cheese 1 cup, whole-grain crackers 10, apple or grapes 1 cup, almonds 15
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten, tree_nuts
- **Swaps:** crackers→rice cakes (gluten-free); almonds→sunflower seeds (nut-free)
- **Approx:** ~450 kcal · 45g C · 28g P · 14g F
- **Source:** NBC News "What 7 fitness experts eat for lunch" (https://www.nbcnews.com/better/lifestyle/what-7-fitness-experts-eat-lunch-ncna1120251)
- **Why:** zero effort, high protein, and it survives a few hours in a bag

### L-093 · Greek yogurt, granola & berries
- **Context:** everyday, recovery, rest-day · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** Greek yogurt 300g, granola 1/2 cup, mixed berries 1 cup, honey 1 tbsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** yogurt→cottage cheese + rolled oats (post-swim version); granola→GF granola (gluten-free); yogurt→soy yogurt (vegan, adds soy)
- **Approx:** ~500 kcal · 65g C · 28g P · 12g F
- **Source:** yogurt-bowl-as-lunch widely reported among busy training athletes; NBC News fitness-experts lunch roundup (https://www.nbcnews.com/better/lifestyle/what-7-fitness-experts-eat-lunch-ncna1120251)
- **Why:** fast recovery-window carbs and protein with nothing to cook — right after a lunchtime pool session

### L-094 · Superhero muffins, Greek yogurt & berries
- **Context:** everyday, recovery, travel · **Cuisine:** american · **Prep:** batch — muffins baked ahead and frozen, 2 min assembly · **Batch:** yes
- **Ingredients:** superhero muffins 2 (almond meal, oats, carrot, egg, honey), Greek yogurt 200g, mixed berries 1 cup
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten, tree_nuts
- **Swaps:** almond meal→oat flour (nut-free); certified GF oats (gluten-free); yogurt→coconut yogurt (dairy-free)
- **Approx:** ~550 kcal · 60g C · 20g P · 22g F
- **Source:** Shalane Flanagan & Elyse Kopecky, Run Fast. Eat Slow. Superhero Muffins (https://run.outsideonline.com/nutrition-and-health/recipes/shalane-flanagans-superhero-muffin-recipe/)
- **Why:** cookbook-attributed, batch-baked, grab-and-go — the desk lunch from the freezer

### L-095 · Snack-plate lunch — eggs, cheese, edamame, crackers, fruit & hummus
- **Context:** everyday, rest-day, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** hard-boiled eggs 2, cheese 40g, edamame 1/2 cup, whole-grain crackers 8, apple 1, carrot sticks, hummus 2 tbsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten, sesame, soy
- **Swaps:** crackers→rice cakes (gluten-free); cheese→turkey slices (dairy-free, omnivore); edamame→chickpeas (soy-free)
- **Approx:** ~520 kcal · 45g C · 30g P · 24g F
- **Source:** Eat For Endurance RD "adult lunchable" (https://www.eatforendurance.com/post/make-ahead-lunch-recipes)
- **Why:** an RD's answer for chaotic training days when a real meal isn't happening

### L-096 · Pita, hummus, nuts & dried fruit
- **Context:** everyday, travel · **Cuisine:** middle-eastern · **Prep:** no-cook · **Batch:** no
- **Ingredients:** whole-wheat pita 1, hummus 3 tbsp, mixed nuts 20g, apple 1, dried apricots 4
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, sesame, tree_nuts
- **Swaps:** pita→GF pita (gluten-free); nuts→roasted chickpeas (nut-free)
- **Approx:** ~500 kcal · 65g C · 15g P · 18g F
- **Source:** shelf-stable travel lunch widely reported among travelling triathletes/runners (community-reported; race-travel logistics, Triple Threat Life https://triplethreatlife.substack.com/p/long-ride-logistics-set-yourself)
- **Why:** no fridge, no cooking, vegan — the airport-day lunch you pack yourself

### L-097 · Canned salmon, crackers & apple
- **Context:** everyday, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** canned wild salmon 1 tin, whole-grain crackers 10, apple 1, olive oil sachet
- **Diets OK:** omnivore, pescatarian
- **Allergens:** fish, gluten
- **Swaps:** crackers→rice cakes (gluten-free); salmon→tuna
- **Approx:** ~450 kcal · 45g C · 30g P · 14g F
- **Source:** canned-fish travel lunch widely reported for race-travel and airport days (community-reported)
- **Why:** no refrigeration, high protein — works on a plane the day before a race

### L-098 · Rice, almond butter & bread travel plate
- **Context:** travel · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** white rice 250g cooked (travel rice cooker), almond butter 2 tbsp, bread 2 slices, banana 1
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, tree_nuts
- **Swaps:** almond butter→sunflower seed butter (nut-free); bread→GF bread (gluten-free)
- **Approx:** ~600 kcal · 100g C · 14g P · 16g F
- **Source:** Tim O'Donnell's stated race-travel staples, ucan.co
- **Why:** a Kona podium finisher's literal packed kit for racing abroad — rice cooker, nut butter, bread

### L-099 · Feed Zone rice cakes
- **Context:** pre-session, race-week, travel · **Cuisine:** american · **Prep:** batch — 30 min, 6 servings, wrap individually · **Batch:** yes
- **Ingredients:** sticky white rice 2 cups cooked, eggs 2 scrambled, parmesan 1/4 cup, ham or bacon 60g, tamari 1 tsp, wrapped in foil (makes 6)
- **Diets OK:** omnivore
- **Allergens:** dairy, eggs, soy
- **Swaps:** eggs and cheese→tofu scramble (vegan); nori wrap instead of foil
- **Approx:** ~450 kcal · 55g C · 18g P · 15g F
- **Source:** Allen Lim & Biju Thomas, The Feed Zone Cookbook / Feed Zone Portables (https://www.velopress.com/books/the-feed-zone-cookbook/)
- **Why:** designed by a physiologist as pro-cyclist pocket food — equally a packed pre-session lunch

### L-100 · White rice, banana & jam toast
- **Context:** carb-load, pre-session · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** white rice 250g cooked, banana 1, white bread 2 slices, jam 2 tbsp, salt pinch
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** bread→GF bread (gluten-free); jam→honey (not vegan); add a scoop of protein in milk (adds dairy)
- **Approx:** ~650 kcal · 140g C · 12g P · 3g F
- **Source:** rice-based carb-loading pattern rooted in Allen Lim's Feed Zone rice cakes (https://www.velopress.com/books/the-feed-zone-cookbook/) combined with standard carb-load guidance (commonly reported)
- **Why:** 140g of carbs with almost no fibre or fat — the carb-load lunch, fully vegan


---

## Dinner (100)

### D-001 · Chicken, jasmine rice & roasted broccoli with teriyaki
- **Context:** everyday, pre-session, race-week, recovery · **Cuisine:** general · **Prep:** batch — 30 min, 4 servings · **Batch:** yes
- **Ingredients:** chicken breast 200g, jasmine rice 100g dry, broccoli 200g, teriyaki sauce 2 tbsp, sesame oil 1 tsp (makes 4)
- **Diets OK:** omnivore
- **Allergens:** gluten, sesame, soy
- **Swaps:** teriyaki→tamari-based teriyaki (gluten-free); broccoli→peeled well-cooked carrots (race-week low-fibre); chicken→firm tofu (vegan)
- **Approx:** ~650 kcal · 90g C · 45g P · 12g F
- **Source:** Chris Lieto's stated dinner "chicken, broccoli, rice" — Triathlete.com "Fuel Like a Pro" https://www.triathlete.com/nutrition/race-fueling/fuel-like-a-pro/ ; Roadman Cycling meal-prep guide (4-minute reheat) https://roadmancycling.com/blog/cycling-weekly-meal-prep-guide
- **Why:** the archetypal triathlete plate — cook Sunday, reheat in 4 minutes after a ride

### D-002 · Chicken breast & white rice with salt (race-eve plate)
- **Context:** carb-load, everyday, race-week, travel · **Cuisine:** general · **Prep:** 20 min · **Batch:** yes
- **Ingredients:** chicken breast 180g, white rice 100g dry, olive oil 1 tsp, salt
- **Diets OK:** mediterranean, omnivore
- **Allergens:** none
- **Swaps:** add a banana for Ryf-style no-fibre carb-load (+25g C); chicken→firm tofu (vegan); rice→peeled mashed potato (same low-residue profile)
- **Approx:** ~600 kcal · 85g C · 42g P · 8g F
- **Source:** Mirinda Carfrae's fixed race-eve meal ("always has the same meal") — si.com "Behind the Body"; Daniela Ryf's carb-load protocol (no fibre 3 days out) — en.triatlonnoticias.com; beyondceliac.org celiac race-day plan ("white rice with grilled chicken and a drizzle of olive oil")
- **Why:** the textbook low-fibre, low-fat, high-carb race-eve dinner — boring on purpose

### D-003 · Salmon, jasmine rice & steamed greens with lemon
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** 25 min · **Batch:** yes
- **Ingredients:** salmon fillet 170g, jasmine rice 90g dry, broccoli or spinach 150g, lemon ½, olive oil 1 tbsp, salt
- **Diets OK:** mediterranean, omnivore, pescatarian
- **Allergens:** fish
- **Swaps:** salmon→chicken thigh (fish-free); rice→quinoa (more protein, GF)
- **Approx:** ~620 kcal · 75g C · 40g P · 18g F
- **Source:** Hannah Grant (WorldTour team chef) & Dr Stacy Sims, Eat Race Win — post-stage salmon, rice & greens https://hannahgrant.com/ ; https://sonyalooney.com/eat-race-win-with-professional-chef-hannah-grant/
- **Why:** what a Tour de France chef actually serves after a stage — omega-3s plus a proper carb refill

### D-004 · Grilled chicken, sweet potato & grilled veg with cottage cheese
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** 25 min · **Batch:** yes
- **Ingredients:** chicken breast 180g, sweet potato 250g, mixed grilled vegetables 200g, cottage cheese 100g, olive oil 1 tsp
- **Diets OK:** omnivore
- **Allergens:** dairy
- **Swaps:** cottage cheese→hummus (dairy-free, adds sesame); sweet potato 250g→150g (rest-day)
- **Approx:** ~600 kcal · 60g C · 52g P · 12g F
- **Source:** Linsey Corbin's reported smaller evening meal — Sundried "What I Eat In A Day" https://www.sundried.com/blogs/nutrition/
- **Why:** high protein, moderate carb — a pro's actual lighter-day dinner

### D-005 · Ground beef, rice & roasted broccoli-carrots with taco seasoning
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — 30 min, 4 servings · **Batch:** yes
- **Ingredients:** lean ground beef 150g, rice 90g dry, broccoli 100g, carrots 100g, taco seasoning 1 tbsp, olive oil 1 tbsp (makes 4)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** beef→ground turkey (leaner); beef→lentils 200g cooked (vegan); taco seasoning→soy-ginger sauce (adds soy, gluten)
- **Approx:** ~600 kcal · 65g C · 38g P · 20g F
- **Source:** Alex Larson, RDN (Alex Larson Nutrition, Endurance Eats podcast) — "fuel with more food, keep it simple" rotation dinner https://alexlarsonnutrition.com/ ; https://strengthrunning.com/2024/07/alex-larson/
- **Why:** one pan of protein, one pot of rice, one tray of veg — the simplest honest meal-prep dinner there is

### D-006 · Sheet-pan chicken thighs, sweet potato & broccoli
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** batch — 40 min, 4 servings · **Batch:** yes
- **Ingredients:** chicken thighs 2 bone-in (~250g), sweet potato 200g, broccoli 150g, olive oil 1 tbsp, paprika 1 tsp (makes 4)
- **Diets OK:** mediterranean, omnivore, paleo
- **Allergens:** none
- **Swaps:** sweet potato→white potato (cheaper); halve sweet potato and add extra broccoli (rest-day, low_carb)
- **Approx:** ~620 kcal · 45g C · 45g P · 26g F
- **Source:** commonly reported sheet-pan template across sports-dietitian content (Nancy Clark's Sports Nutrition Guidebook, "Lunch and Dinner: At Home, on the Run") https://nancyclarkrd.com/
- **Why:** one tray, four dinners, zero allergens — the whole-food default plate

### D-007 · Chicken thigh, new potato, pepper & courgette traybake
- **Context:** everyday, race-week, recovery · **Cuisine:** general · **Prep:** batch — 40 min, 4 servings · **Batch:** yes
- **Ingredients:** chicken thighs 200g, new potatoes 250g, red pepper 1, courgette 1, olive oil 1 tbsp, rosemary, garlic (makes 4)
- **Diets OK:** mediterranean, omnivore, paleo
- **Allergens:** none
- **Swaps:** peel potatoes and drop the pepper skin (race-week low-residue); chicken→chickpeas 200g (vegan)
- **Approx:** ~560 kcal · 50g C · 38g P · 22g F
- **Source:** Renee McGregor, RD, Fast Fuel — gut-friendly traybake dinners as the backbone of a runner's week https://veloforte.com/blogs/fuel-better/renee-mcgregor-qa-gut-healthy-nutrition-tips-cycling-running-performance
- **Why:** gut-friendly, low-processed, and it reheats — a dietitian's weeknight backbone

### D-008 · Steak, roasted baby potatoes & green beans
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** 30 min · **Batch:** no
- **Ingredients:** sirloin steak 200g, baby potatoes 300g, green beans 150g, olive oil 1 tbsp, garlic 2 cloves
- **Diets OK:** omnivore, paleo
- **Allergens:** none
- **Swaps:** potatoes→sweet potato 200g (targeted-carb paleo version); potatoes→cauliflower mash (keto, low_carb)
- **Approx:** ~650 kcal · 55g C · 45g P · 22g F
- **Source:** commonly reported across triathlete "what I eat" pieces (Triathlete.com "Fuel Like a Pro") https://www.triathlete.com/nutrition/race-fueling/fuel-like-a-pro/ ; u/dirtyStick84, r/AdvancedRunning "What do YOU eat in a day?"
- **Why:** iron-rich red meat and potatoes — the recovery dinner nobody needs a recipe for

### D-009 · Roast chicken legs, dairy-free mash & gravy
- **Context:** carb-load, everyday, recovery · **Cuisine:** general · **Prep:** batch — 50 min, 4 servings · **Batch:** yes
- **Ingredients:** chicken leg 1 (~250g), potatoes 300g, oat milk 60ml, olive oil 1 tbsp, chicken stock 150ml, cornstarch 1 tsp, garlic (makes 4)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** oat milk/olive oil→butter and milk (adds dairy); cornstarch gravy→standard flour gravy (adds gluten)
- **Approx:** ~650 kcal · 60g C · 42g P · 26g F
- **Source:** The Pretty Bee "Top 9 Allergen-Free Meal Plan", Day 7 dinner
- **Why:** the Sunday roast, built top-9-allergen-free without tasting like it

### D-010 · Lemon-honey chicken thighs with roasted new potatoes
- **Context:** everyday, pre-session · **Cuisine:** general · **Prep:** 30 min · **Batch:** yes
- **Ingredients:** chicken thighs 200g, new potatoes 250g, lemon 1, honey 1 tsp, rosemary, olive oil 1 tbsp, parsley
- **Diets OK:** mediterranean, omnivore
- **Allergens:** none
- **Swaps:** honey→omit (paleo-strict); add green beans 100g (more fibre on easy days)
- **Approx:** ~620 kcal · 50g C · 40g P · 26g F
- **Source:** reported pro-cyclist team dinner — Cyclist.co.uk "How to eat like a pro" https://www.cyclist.co.uk/in-depth/best-food-for-cycling-how-to-eat-like-a-pro
- **Why:** the archetypal Mediterranean team-hotel dinner — olive oil, lemon, potatoes, chicken

### D-011 · Rotisserie chicken, microwave rice & bagged salad
- **Context:** everyday, race-week, travel · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** store rotisserie chicken 250g, microwave white rice pouch 250g, pre-washed salad 100g, olive oil 1 tbsp
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** rice pouch→baguette ⅓ (adds gluten); salad→steamed broccoli 200g (if a microwave is all you have); check rotisserie brine for soy/gluten
- **Approx:** ~600 kcal · 55g C · 46g P · 18g F
- **Source:** commonly reported hotel-room / Airbnb race-trip dinner among age-group triathletes (r/triathlon travel threads); "lazy weeknight" staple across meal-prep content
- **Why:** a real cooked-tasting dinner with no kitchen — the race-trip standard

### D-012 · Chicken & sweet potato hash with peppers
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — 25 min, 4 servings · **Batch:** yes
- **Ingredients:** chicken breast 170g diced, sweet potato 250g diced, onion ½, red pepper 1, olive oil 1 tbsp, smoked paprika 1 tsp (makes 4)
- **Diets OK:** omnivore, paleo
- **Allergens:** none
- **Swaps:** top with a fried egg (adds eggs, +6g P); chicken→firm tofu (vegan, adds soy)
- **Approx:** ~520 kcal · 55g C · 38g P · 14g F
- **Source:** Bob Seebohar-style Metabolic Efficiency Recipe Book, 2:1 carb:protein post-long-session recovery dish https://www.enrgperformance.com/metabolic-efficiency-training
- **Why:** one-pan, roughly 2:1 carb-to-protein — the recovery ratio Seebohar's RDs label recipes with

### D-013 · Tandoori chicken, brown rice & mixed veg with yogurt
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — marinate ahead, 30 min, 4 servings · **Batch:** yes
- **Ingredients:** tandoori-marinated chicken 170g, brown rice 90g dry, mixed vegetables 150g, plain yogurt 100g, strawberries 100g (makes 4)
- **Diets OK:** omnivore
- **Allergens:** dairy
- **Swaps:** yogurt→coconut yogurt (dairy-free); brown rice→white rice (race-week low-fibre)
- **Approx:** ~650 kcal · 80g C · 45g P · 14g F
- **Source:** Megan Powell — Sundried "What I Eat In A Day" post-second-session dinner https://www.sundried.com/blogs/nutrition/what-i-eat-in-a-day-by-megan-powell-triathlete
- **Why:** batch-marinated chicken reused across the week — a real triathlete's two-a-day recovery plate

### D-014 · Chipotle chicken & potato bowls
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — slow cooker 4h, 5 min assembly, 6 servings · **Batch:** yes
- **Ingredients:** slow-cooker chipotle shredded chicken 150g, baby potatoes 250g smashed, romaine 1 cup, pico de gallo 2 tbsp, white cheddar 30g, chipotle-yogurt sauce 2 tbsp (makes 6)
- **Diets OK:** omnivore
- **Allergens:** dairy
- **Swaps:** cheddar + yogurt sauce→dairy-free versions (dairy-free); potatoes→rice (same carbs)
- **Approx:** ~560 kcal · 50g C · 38g P · 20g F
- **Source:** Meghann Featherstun, RD CSSD, Featherstone Nutrition https://www.featherstonenutrition.com/recipe/chipotle-chicken-potato-bowls/
- **Why:** potato-based protein bowl a marathon dietitian prescribes — slow-cooker protein reassembled all week

### D-015 · Broccoli, rice & ground beef with enchilada sauce
- **Context:** carb-load, everyday · **Cuisine:** general · **Prep:** batch — 45 min, 16 servings, ~$2 each · **Batch:** yes
- **Ingredients:** lean ground beef 130g, rice 100g cooked (≈200g cooked for athlete portion), frozen broccoli 100g, enchilada sauce 2 tbsp (makes 16)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** beef→ground turkey; beef→black beans 150g (vegan); check sauce for gluten/soy
- **Approx:** ~550 kcal · 65g C · 32g P · 15g F
- **Source:** u/kurisutarou, r/MealPrepSunday "16 meals for $2/serving" (429 pts) — prepping for an Olympic-distance triathlon https://old.reddit.com/r/MealPrepSunday/
- **Why:** the most-upvoted triathlon-specific batch prep on Reddit — cheap, boring, works

### D-016 · Potatoes or pasta, chicken breast & mixed veg with olive oil
- **Context:** carb-load, everyday, pre-session · **Cuisine:** general · **Prep:** 20 min · **Batch:** yes
- **Ingredients:** potatoes 350g boiled (or pasta 120g dry), chicken breast 170g, mixed vegetables 150g, olive oil 1 tbsp, parmesan 20g optional
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** potatoes→pasta (adds gluten); add parmesan (adds dairy); rice on rotation (Blummenfelt's fourth "long carb")
- **Approx:** ~720 kcal · 100g C · 42g P · 16g F
- **Source:** Kristian Blummenfelt's stated "long carbohydrate" base — oats, rice, potatoes, pasta rotated meal to meal — Nutri.it https://nutri.it.com/what-diet-does-kristian-blummenfelt-follow ; VO2 Master "The Norwegian Method" https://vo2master.com/blog/the-norwegian-method-s02-s06/
- **Why:** the double Olympic/Ironman champion's actual base — staple starches on rotation, no fad

### D-017 · Grilled white fish, boiled new potatoes & sautéed greens
- **Context:** everyday, pre-session, race-week, recovery · **Cuisine:** general · **Prep:** 25 min · **Batch:** no
- **Ingredients:** white fish fillet 180g, new potatoes 250g, spinach or chard 150g, olive oil 1 tbsp, lemon ½
- **Diets OK:** mediterranean, omnivore, pescatarian
- **Allergens:** fish
- **Swaps:** fish→chicken breast (fish-free); greens→peeled carrots (race-week low-fibre)
- **Approx:** ~540 kcal · 50g C · 40g P · 18g F
- **Source:** Hannah Grant's nightly WorldTour team dinner pattern — Triathlete.com profile of Eat. Race. Win. https://www.triathlete.com/nutrition/traveling-chef-hannah-grant-dishes-on-tour-de-france-in-new-series/ ; The Grand Tour Cookbook
- **Why:** the "boring but it works" plate Grand Tour chefs default to during a stage race

### D-018 · Chicken, celeriac & mango casserole over rice
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — 40 min, 4 servings · **Batch:** yes
- **Ingredients:** chicken thigh 170g, celeriac 150g, mango 80g, chopped tomatoes 200g, red pepper ½, apple juice 50ml, crème fraîche 1 tbsp, chilli, rice 90g dry (makes 4)
- **Diets OK:** omnivore
- **Allergens:** dairy
- **Swaps:** crème fraîche→coconut cream (dairy-free); rice→quinoa (GF either way, more protein)
- **Approx:** ~600 kcal · 80g C · 38g P · 12g F
- **Source:** Henrik Orre, Team Sky chef — Cyclist.co.uk "Team Sky recipes for cycling success" https://www.cyclist.co.uk/in-depth/865/team-sky-recipes-for-cycling-success
- **Why:** a Grand Tour team chef's high-protein, low-fat recovery stew — sweet, spicy and freezer-friendly

### D-019 · Baked cod, white rice & green beans
- **Context:** everyday, race-week · **Cuisine:** general · **Prep:** 25 min · **Batch:** no
- **Ingredients:** cod fillet 200g, white rice 90g dry, green beans 150g, lemon 1, olive oil 1 tbsp
- **Diets OK:** mediterranean, omnivore, pescatarian
- **Allergens:** fish
- **Swaps:** green beans→peeled carrots (lower fibre for race-eve); cod→chicken breast (fish-free)
- **Approx:** ~520 kcal · 70g C · 40g P · 8g F
- **Source:** commonly recommended low-residue race-week fish dinner in sports-dietitian guidance (Nancy Clark-style) https://nancyclarkrd.com/ ; STYRKR "What to eat the night before a race"
- **Why:** mild white fish and white rice — gentle on the gut, still 70g of carbs

### D-020 · Fiskekaker (fish cakes) with boiled potatoes & carrots
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — fish cakes freeze, potatoes 20 min · **Batch:** yes
- **Ingredients:** Norwegian fish cakes 3 (~200g), boiled potatoes 300g, carrots 150g, butter 1 tbsp (makes 4)
- **Diets OK:** omnivore, pescatarian
- **Allergens:** dairy, fish, gluten
- **Swaps:** butter→olive oil (dairy-free); fish cakes made with potato-starch binder (gluten-free)
- **Approx:** ~600 kcal · 75g C · 32g P · 16g F
- **Source:** staple Norwegian family dinner, consistent with the whole-food "normal food" fuelling reported for the Blummenfelt/Iden camp — Triathlete.com https://www.triathlete.com/culture/news/why-kristian-blummenfelt-counts-calories/
- **Why:** mild, high-carb fish-and-potatoes in the Norwegian squad's "eat normal food" spirit

### D-021 · Rice, black beans, farofa & grilled chicken thigh (arroz com feijão)
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — rice and beans Sunday, chicken grilled fresh, 4 servings · **Batch:** yes
- **Ingredients:** white rice 90g dry, black beans 150g cooked with broth, farofa 2 tbsp, chicken thigh 150g, tomato-onion salad (makes 4)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** chicken→extra beans + fried egg (vegetarian, adds eggs); chicken→black-eyed peas (vegan)
- **Approx:** ~700 kcal · 95g C · 38g P · 16g F
- **Source:** Brazil's everyday national plate, eaten daily by its endurance athletes — widely documented dietary pattern (no single athlete quote)
- **Why:** rice + beans + a grilled protein is dinner for an entire endurance-sport nation

### D-022 · Ugali with sukuma wiki & beef stew
- **Context:** carb-load, everyday, rest-day · **Cuisine:** general · **Prep:** batch — stew ahead, ugali fresh 15 min, 4 servings · **Batch:** yes
- **Ingredients:** maize flour 150g dry, sukuma wiki or collard greens 200g, beef stew meat 130g, onion 1, tomato 1, oil 1 tsp (makes 4)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** beef→kidney beans 200g (vegan); greens→kale or spinach (wherever you are)
- **Approx:** ~650 kcal · 90g C · 35g P · 15g F
- **Source:** reported nightly dinner for Eliud Kipchoge and Kaptagat/Iten camp runners — Olympics.com https://www.olympics.com/en/news/what-olympic-marathon-hero-eliud-kipchoge-eats ; traininkenya.com https://www.traininkenya.com/2018/08/08/diet-of-kenyan-runners/
- **Why:** the literal daily plate of the world's dominant distance-running culture — cheap, high-carb, GF

### D-023 · Ugali & beans with tomato-onion sauce
- **Context:** carb-load, everyday · **Cuisine:** general · **Prep:** batch — beans ahead, ugali fresh 15 min, 4 servings · **Batch:** yes
- **Ingredients:** maize flour 150g dry, red kidney beans 200g cooked, onion 1, tomato 2, oil 1 tsp (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add sukuma wiki 150g (more greens); ugali→white rice (same job)
- **Approx:** ~560 kcal · 105g C · 20g P · 6g F
- **Source:** reported as a common evening meal at Iten training camps — traininkenya.com https://www.traininkenya.com/2018/08/08/diet-of-kenyan-runners/ ; kenya-camp.com
- **Why:** the vegan Kenyan camp dinner — 100g+ of carbs for pennies, naturally allergen-free

### D-024 · Injera with shiro wot (spiced chickpea stew)
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** batch — shiro keeps 4 days, injera store-bought, 4 servings · **Batch:** yes
- **Ingredients:** injera (100% teff) 150g, chickpea/shiro flour 60g, onion 1, garlic 2 cloves, berbere 1 tbsp, oil 1 tbsp (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** confirm 100% teff injera (wheat-blended injera adds gluten); add misir wot (red lentils) for +8g P
- **Approx:** ~550 kcal · 90g C · 18g P · 12g F
- **Source:** staple of Ethiopian distance-running culture (Bekele/Gebrselassie-era camps) — commonly reported, ingredients per https://en.wikipedia.org/wiki/Injera
- **Why:** fermented-teff flatbread and legume stew — the Ethiopian running dynasty's everyday plate

### D-025 · Grilled salmon, rice, miso soup & pickles
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** 20 min · **Batch:** no
- **Ingredients:** salmon fillet 150g, white rice 90g dry, miso paste 1 tbsp, tofu 50g, wakame, pickled vegetables small side
- **Diets OK:** omnivore, pescatarian
- **Allergens:** fish, soy
- **Swaps:** salmon→mackerel with miso glaze (ekiden-camp version); salmon→grilled tofu (vegan, keep soy)
- **Approx:** ~650 kcal · 90g C · 40g P · 15g F
- **Source:** classic Japanese athlete recovery dinner — Metropolis Japan https://metropolisjapan.com/japanese-superfoods-for-peak-performance/ ; Marukome athlete-nutrition guide https://mag.marukome.co.jp/20230511/17723/
- **Why:** ichiju-sansai — one soup, rice, fish, veg — covers carbs, protein and sodium every night

### D-026 · Onigiri with umeboshi & miso soup
- **Context:** carb-load, pre-session, race-week, travel · **Cuisine:** general · **Prep:** 15 min · **Batch:** yes
- **Ingredients:** cooked white rice 300g, umeboshi 2, nori 2 sheets, miso paste 1 tbsp, kombu dashi 300ml, tofu 50g, salt
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** soy
- **Swaps:** kombu dashi→bonito dashi (adds fish, traditional); add salmon flake filling (+15g P, adds fish)
- **Approx:** ~520 kcal · 100g C · 14g P · 4g F
- **Source:** traditional pre-race carb-load of Japanese ekiden/marathon runners in place of pasta — freeradical.me https://freeradical.me/2013/09/19/onigiri-recipe-runners-alternative-energy-gels/ ; Scott Jurek's onigiri recipe, Eat & Run http://www.scottjurek.com/eat
- **Why:** salty, low-fat, low-fibre rice — a purpose-built race-eve meal that also packs for travel

### D-027 · Bibimbap (rice, bulgogi beef, veg & fried egg)
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** 30 min · **Batch:** yes
- **Ingredients:** cooked rice 250g, bulgogi beef 150g, spinach 50g, carrot 50g, bean sprouts 50g, egg 1, gochujang 1 tbsp, sesame oil 1 tsp
- **Diets OK:** omnivore
- **Allergens:** eggs, gluten, sesame, soy
- **Swaps:** gochujang→GF-labelled brand (gluten-free); beef + egg→marinated tofu (vegan)
- **Approx:** ~650 kcal · 75g C · 35g P · 20g F
- **Source:** recipe developed as a post-training recovery dinner by Katie Kirk, two-time Commonwealth Games athlete — Fast Running https://fastrunning.com/nutrition/recipes/korean-rice-bowl-bibimbap-by-katie-kirk/8434
- **Why:** a Commonwealth Games athlete's recovery bowl — rice, meat, five veg, one egg

### D-028 · Hainan-style poached chicken & jasmine rice with cucumber
- **Context:** carb-load, race-week · **Cuisine:** general · **Prep:** 30 min · **Batch:** yes
- **Ingredients:** chicken breast 180g, jasmine rice 90g dry cooked in the poaching broth, cucumber 80g, ginger, scallion greens, salt
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** keep scallion greens only, no onion/garlic (low-FODMAP); add chilli-ginger sauce on a normal night
- **Approx:** ~560 kcal · 70g C · 45g P · 10g F
- **Source:** commonly reported gut-friendly race-week dinner pattern aligned with Kate Scarlata RDN low-FODMAP athlete guidance and the Frontiers in Nutrition FODMAP/endurance review
- **Why:** the gentlest possible chicken and rice — poached, low-fat, low-FODMAP, night-before-the-big-race food

### D-029 · Abendbrot: rye bread, cheese, quark & cucumber
- **Context:** everyday, rest-day, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** dark rye bread 3 slices, Gouda or Emmental 40g, quark 200g, honey 1 tsp, cucumber and tomato slices
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** add sliced turkey (omnivore, +10g P); rye→GF bread (gluten-free); quark→skyr (same job, Nordic)
- **Approx:** ~580 kcal · 60g C · 38g P · 18g F
- **Source:** traditional German/Dutch cold evening meal, commonly reported across German-speaking cycling and running households
- **Why:** a real northern-European rest-day dinner — high-protein quark, dense bread, no cooking

### D-030 · Käsespätzle with side salad
- **Context:** carb-load, everyday · **Cuisine:** general · **Prep:** batch — 30 min, 4 servings · **Batch:** yes
- **Ingredients:** spätzle 250g cooked, Emmental 70g, fried onions 2 tbsp, mixed salad 100g, vinaigrette 1 tbsp (makes 4)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten
- **Swaps:** spätzle→GF pasta shape (gluten-free); Emmental 70g→40g (lighter fat)
- **Approx:** ~720 kcal · 90g C · 30g P · 26g F
- **Source:** classic South German/Swiss carb-load dinner, commonly reported as a training-camp and cycling-club staple in German-speaking Europe
- **Why:** an honest German carb-load — not pasta, not rice, still 90g of carbs

### D-031 · Mushroom risotto with parmesan
- **Context:** carb-load, everyday, pre-session · **Cuisine:** general · **Prep:** batch — 30 min, 4 servings · **Batch:** yes
- **Ingredients:** arborio rice 120g dry, mushrooms 150g, vegetable stock 500ml, parmesan 25g, butter 1 tsp, onion ½ (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** parmesan/butter→olive oil + nutritional yeast (vegan, dairy-free); add chicken or prawns 150g (+30g P, prawns add shellfish)
- **Approx:** ~640 kcal · 105g C · 18g P · 14g F
- **Source:** classic Italian pro-cycling team-hotel carb source, commonly reported in "what pros eat" team-chef features; trigirl.co.uk GF/DF list ("risotto with chicken or prawns, no cheese")
- **Why:** the peloton's rice-based alternative to pasta — naturally GF, 100g+ of carbs

### D-032 · Chickpea & vegetable tagine with couscous
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** batch — 30 min, 4 servings · **Batch:** yes
- **Ingredients:** chickpeas 200g canned, carrot 1, courgette 1, dried apricots 30g, chopped tomatoes 200g, ras el hanout 1 tsp, couscous 90g dry (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** couscous→quinoa (gluten-free); add chicken thigh 150g (omnivore, +30g P)
- **Approx:** ~600 kcal · 100g C · 20g P · 8g F
- **Source:** commonly reported North African plant-based batch dinner in endurance-nutrition "global cuisine" content
- **Why:** cheap, freezer-friendly, Mediterranean — a vegan stew that isn't a curry

### D-033 · Falafel wrap with hummus & salad
- **Context:** everyday, travel · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** baked falafel 6 (~150g), whole-wheat wrap 1 large, hummus 80g, cucumber, tomato, lettuce
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, sesame
- **Swaps:** wrap→GF wrap (gluten-free); hummus→tahini-free hummus (sesame-free); add a second wrap on a big day
- **Approx:** ~600 kcal · 75g C · 22g P · 22g F
- **Source:** commonly reported Mediterranean-diet athlete dinner; falafel is a standard grab-anywhere vegan option on race trips
- **Why:** plant protein in a wrap you can buy in any city — the vegan travel dinner

### D-034 · Red lentil dal with basmati rice
- **Context:** carb-load, everyday, recovery · **Cuisine:** general · **Prep:** batch — 30 min, 4 servings, freezes well · **Batch:** yes
- **Ingredients:** red lentils 120g dry, basmati rice 90g dry, onion 1, garlic 2 cloves, turmeric 1 tsp, cumin 1 tsp, tomato 1, spinach 100g (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add 2 roti (thali-style, adds gluten); add coconut milk 100ml (richer, +8g F); add ghee 1 tsp (adds dairy)
- **Approx:** ~600 kcal · 105g C · 26g P · 6g F
- **Source:** everyday Indian household staple and reported base diet of Indian marathoners (Indian running-community nutrition features); The Pretty Bee top-9-free plan (slow-cooker lentil curry); nutritional.asia "Endurance Fuel with Asian Foods"
- **Why:** the most reliable allergen-free, high-carb, cheap dinner in the library — dal and rice

### D-035 · Chana masala with basmati rice
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** batch — 25 min, 4 servings, freezes well · **Batch:** yes
- **Ingredients:** chickpeas 250g canned, onion 1, chopped tomatoes 200g, garlic 2 cloves, ginger 1 tbsp, garam masala 2 tsp, basmati rice 90g dry (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** chickpeas→chickpeas + diced sweet potato 150g with coconut milk (sweeter, +30g C); rice→naan (adds gluten, dairy)
- **Approx:** ~580 kcal · 95g C · 20g P · 8g F
- **Source:** commonly reported plant-based endurance-athlete staple — ZONE3 "Vegan recipes for triathletes" https://zone3.com/blogs/inside-zone3/vegan-recipes-for-triathletes ; Taryn Richardson, Dietitian Approved "Eat Plants, Train Hard"
- **Why:** tinned chickpeas, a tin of tomatoes and rice — vegan dinner for four for a few pounds

### D-036 · Paneer & vegetable curry with rice
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — 25 min, 4 servings · **Batch:** yes
- **Ingredients:** paneer 150g, mixed vegetables 200g, onion 1, chopped tomatoes 200g, curry spices 2 tsp, basmati rice 90g dry (makes 4)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** paneer→extra-firm tofu (vegan, adds soy); add cream 2 tbsp for tikka-style (more fat)
- **Approx:** ~620 kcal · 85g C · 28g P · 18g F
- **Source:** common lacto-vegetarian endurance-athlete dinner across South Asian vegetarian sports-nutrition content and 220triathlon.com vegetarian guides
- **Why:** paneer gives lacto-vegetarians a 28g-protein curry without tofu

### D-037 · Chicken tikka masala with basmati rice
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — 35 min, 4–6 servings, freezes well · **Batch:** yes
- **Ingredients:** chicken breast 200g, tomato sauce 200g, yogurt 2 tbsp, garam masala 2 tsp, garlic, ginger, basmati rice 90g dry (makes 4)
- **Diets OK:** omnivore
- **Allergens:** dairy
- **Swaps:** yogurt→coconut yogurt or coconut milk (dairy-free); rice→2 roti (adds gluten)
- **Approx:** ~650 kcal · 80g C · 42g P · 16g F
- **Source:** commonly reported UK-endurance-athlete "curry night" staple (220triathlon/tri247 readership); runtothefinish.com GF meal plan (tikka masala)
- **Why:** the British club-triathlete Friday dinner — batch it, freeze it, reheat it after the long ride

### D-038 · Thai green curry chicken with jasmine rice
- **Context:** everyday · **Cuisine:** general · **Prep:** batch — 25 min, 4 servings, sauce freezes · **Batch:** yes
- **Ingredients:** chicken thigh 180g, green curry paste 2 tbsp, coconut milk 150ml, green beans and pepper 150g, fish sauce 1 tsp, jasmine rice 90g dry (makes 4)
- **Diets OK:** omnivore
- **Allergens:** fish, shellfish
- **Swaps:** fish sauce→tamari (fish-free, adds soy); use a shrimp-paste-free curry paste (shellfish-free); chicken→tofu (vegan with the above)
- **Approx:** ~700 kcal · 80g C · 36g P · 26g F
- **Source:** commonly reported weeknight favourite among endurance athletes for its carb+protein+fat balance (GCN/GTN "what pros eat" style content); r/MealPrepSunday triathlete prep (beef with Thai curry sauce over rice)
- **Why:** high-calorie and fast — the dinner for a big-mileage week when a dry chicken breast won't cut it

### D-039 · Sushi selection with tamari & pickled ginger
- **Context:** pre-session, race-week, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** sushi rolls 10–12 pieces (salmon, tuna, cucumber, avocado), tamari 1 tbsp, pickled ginger, edamame 80g
- **Diets OK:** omnivore, pescatarian
- **Allergens:** fish, sesame, soy
- **Swaps:** fish rolls→cucumber/avocado/inari rolls (vegan); skip sesame-seeded rolls (sesame-free); confirm tamari is labelled GF
- **Approx:** ~600 kcal · 95g C · 28g P · 10g F
- **Source:** trigirl.co.uk GF/DF triathlete main-meal list ("Sushi selection, 6-8 pieces"), sized up for an athlete
- **Why:** rice-based, low-fat, low-fibre and available in every airport — the race-trip dinner that isn't pasta

### D-040 · Tacos de pollo with rice & black beans
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — chicken, beans and rice ahead, 4 servings · **Batch:** yes
- **Ingredients:** corn tortillas 4, grilled chicken breast 150g, black beans 100g, white rice 75g dry, salsa, lime, avocado ¼ (makes 4)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** chicken→extra beans + grilled portobello (vegan); corn→flour tortillas (adds gluten)
- **Approx:** ~650 kcal · 90g C · 40g P · 14g F
- **Source:** everyday Mexican/Latin-American plate, commonly reported in "what triathletes eat" threads; The Pretty Bee top-9-free plan (turkey tacos, corn tortillas)
- **Why:** naturally gluten-free, protein + two carbs + veg — and it tastes nothing like chicken-rice-broccoli

### D-041 · Shrimp tacos with cabbage slaw
- **Context:** everyday · **Cuisine:** general · **Prep:** 20 min · **Batch:** no
- **Ingredients:** shrimp 200g, cumin 1 tsp, chilli powder 1 tsp, corn tortillas 4, cabbage slaw 150g, avocado ½, lime, plain yogurt 2 tbsp
- **Diets OK:** mediterranean, omnivore, pescatarian
- **Allergens:** dairy, shellfish
- **Swaps:** yogurt→omit or coconut yogurt (dairy-free); shrimp→grilled chicken or black beans (shellfish-free)
- **Approx:** ~580 kcal · 60g C · 34g P · 20g F
- **Source:** pro triathlete Beth Gerdes' weeknight rotation — ESPNW "What Athletes Eat" https://www.espn.com/espnw/life-style/article/15447798/what-athletes-eat-triathlete-beth-gerdes-training-friendly-shrimp-tacos
- **Why:** a pro's actual under-30-minute weeknight dinner — light, fast, GF by default

### D-042 · Chicken fajitas with peppers, onions & tortillas
- **Context:** everyday · **Cuisine:** general · **Prep:** batch — chicken and peppers ahead, 4 servings · **Batch:** yes
- **Ingredients:** chicken breast 170g sliced, fajita seasoning 1 tbsp, bell peppers 2, onion 1, flour tortillas 3, salsa, side salad (makes 4)
- **Diets OK:** omnivore
- **Allergens:** gluten
- **Swaps:** flour→corn tortillas (gluten-free); add rice 75g dry (carb-load, +55g C)
- **Approx:** ~650 kcal · 70g C · 42g P · 18g F
- **Source:** Jonny Brownlee's dinner rotation (alternates with meatballs and pasta) — 220triathlon.com
- **Why:** an Olympic medallist's Tuesday dinner — one pan, everybody builds their own

### D-043 · Ground beef burritos with rice, beans & cheese
- **Context:** everyday · **Cuisine:** general · **Prep:** batch — one protein batch Sunday, reassembled nightly, 4 servings · **Batch:** yes
- **Ingredients:** ground beef 150g, large flour tortilla 1, black beans 100g, rice 75g dry, cheddar 30g, salsa 50g (makes 4)
- **Diets OK:** omnivore
- **Allergens:** dairy, gluten
- **Swaps:** tortilla→rice bowl (gluten-free); cheese→omit (dairy-free); rotate the same beef into tacos, salads and bowls across the week
- **Approx:** ~750 kcal · 85g C · 42g P · 26g F
- **Source:** GT7, TrainerRoad forum "What do you eat during any given day" — "rotate between cooking some beef or chicken and then using that over a few days" https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/18
- **Why:** one batch-cooked protein reassembled differently every night — the clearest real-world component pattern in the research

### D-044 · Dump-and-bake chicken burrito bowl
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — one dish, 60 min mostly hands-off, 6 servings · **Batch:** yes
- **Ingredients:** jasmine rice 75g dry, chicken breast 170g diced, black beans 100g, frozen corn 60g, red pepper ½, salsa 60g, taco seasoning 1 tsp, chicken stock 150ml (makes 6)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** chicken→extra beans (vegan); top with cheese (adds dairy); check taco seasoning for gluten/soy fillers
- **Approx:** ~600 kcal · 80g C · 42g P · 8g F
- **Source:** Meghann Featherstun, RD CSSD, Featherstone Nutrition https://www.featherstonenutrition.com/recipe/dump-n-bake-chicken-burrito-bowl/
- **Why:** everything in one dish, stir three times, six dinners — the lowest-effort batch bake there is

### D-045 · Rice, black beans, guacamole & hot sauce bowl
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — components keep 4–5 days · **Batch:** yes
- **Ingredients:** rice 100g dry (or rice + quinoa), black beans 200g, guacamole 80g, corn 80g, salsa 60g, hot sauce (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** guacamole→½ avocado + lime (same thing); add a fried egg (vegetarian, +6g P, adds eggs)
- **Approx:** ~680 kcal · 105g C · 22g P · 18g F
- **Source:** Rich Roll's reported go-to dinner "a huge bowl of rice and quinoa with black beans, guacamole and hot sauce" — The Chalkboard Mag https://thechalkboardmag.com/ultraman-rich-roll-vegan-athlete-daily-diet/ ; TrainingPeaks "3 Recipes for Increased Recovery" (rice and beans) https://www.trainingpeaks.com/blog/3-recipes-for-increased-recovery/
- **Why:** an Ultraman finisher's nightly bowl — complete protein, 100g of carbs, no cooking beyond a rice pot

### D-046 · Sweet potato, tofu & black bean tacos
- **Context:** everyday · **Cuisine:** general · **Prep:** batch — roast sweet potato and tofu ahead, 4 servings · **Batch:** yes
- **Ingredients:** sweet potato 200g diced, firm tofu 150g crumbled, chipotle in adobo 1 tbsp, black beans 100g, corn tortillas 3, avocado ¼, lime (makes 4)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** soy
- **Swaps:** tofu→extra black beans (soy-free); corn→flour tortillas (adds gluten)
- **Approx:** ~640 kcal · 85g C · 28g P · 20g F
- **Source:** Meghann Featherstun, RD CSSD, Featherstone Nutrition "High Protein Vegan Tacos" https://www.featherstonenutrition.com/recipe/high-protein-vegan-tacos/
- **Why:** a marathon dietitian's vegan taco with real protein density — tofu and beans, not just veg

### D-047 · Bean & cheese quesadillas with salsa
- **Context:** everyday, travel · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** flour tortillas 2, black or refried beans 150g, cheddar 60g, salsa 60g
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** flour→corn tortillas (gluten-free); cheese→dairy-free cheese (vegan); add leftover chicken (omnivore)
- **Approx:** ~620 kcal · 75g C · 28g P · 22g F
- **Source:** commonly reported quick travel / hotel-room dinner among endurance athletes — one pan, four ingredients
- **Why:** four shelf-stable ingredients and a frying pan — the Airbnb dinner

### D-048 · Marathon Bolognese over pasta
- **Context:** carb-load, everyday, pre-session · **Cuisine:** general · **Prep:** batch — 45 min, 6 servings, freezes well · **Batch:** yes
- **Ingredients:** ground beef 100g, carrot ½, celery 1 stalk, onion ¼, crushed tomatoes 200g, red wine splash, pasta 120g dry (makes 6)
- **Diets OK:** omnivore
- **Allergens:** gluten
- **Swaps:** pasta→GF pasta (gluten-free); pasta→wholemeal (more fibre for everyday, the Cyclist.co.uk pro-team version); beef→lentils (vegan)
- **Approx:** ~700 kcal · 95g C · 36g P · 18g F
- **Source:** Shalane Flanagan & Elyse Kopecky, "Run Fast. Cook Fast. Eat Slow." — a favourite during Flanagan's 2017 NYC Marathon build https://justcook.butcherbox.com/the-amazing-simple-marathon-bolognese-recipe-from-the-authors-of-run-fast-cook-fast-eat-slow/ ; Jonny Brownlee's meatballs-and-pasta rotation, 220triathlon.com
- **Why:** veg-loaded meat sauce over pasta — the night-before-a-long-run dinner a marathon champion cooked from

### D-049 · Lentil & mushroom "no meat" pasta
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — 25 min, 4 servings, sauce freezes · **Batch:** yes
- **Ingredients:** pasta 110g dry, brown lentils 150g cooked, mushrooms 100g, garlic 2 cloves, passata 200ml, olive oil 1 tbsp, basil (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** pasta→GF or red-lentil pasta (gluten-free, +protein); add parmesan (vegetarian, adds dairy)
- **Approx:** ~650 kcal · 110g C · 28g P · 12g F
- **Source:** "Lentil-Mushroom No Meat Pasta" — The No Meat Athlete Cookbook (Matt Frazier & Stepfanie Romine) nomeatathlete.com
- **Why:** the vegan ragu — lentils carry the protein, pasta carries 100g+ of carbs

### D-050 · Plain pasta with tomato sauce & parmesan (race-eve)
- **Context:** carb-load, race-week · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** white pasta 150g dry, passata 150g, parmesan 20g, olive oil 1 tbsp, salt
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** tomato sauce→olive oil + parmesan only (PF&H ultra-low-residue version); pasta→GF white pasta (gluten-free); parmesan→omit (vegan)
- **Approx:** ~700 kcal · 115g C · 22g P · 15g F
- **Source:** Precision Fuel & Hydration carb-loading guidance (Lexi Kelson RD and team) https://www.precisionhydration.com/performance-advice/nutrition/how-to-carb-load-before-a-race/ ; RunnersConnect pre-race nutrition https://runnersconnect.net/pre-race-marathon-nutrition/
- **Why:** the canonical night-before-the-race dinner — big, plain, low-fat, low-fibre

### D-051 · Vegan lasagne with cashew ricotta
- **Context:** carb-load, everyday, pre-session · **Cuisine:** general · **Prep:** batch — 60 min, 6 servings, freezes in portions · **Batch:** yes
- **Ingredients:** lasagne sheets 80g dry, cashew ricotta 80g, marinara 150g, spinach 50g, courgette ¼, lentils 60g cooked (makes 6)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, tree_nuts
- **Swaps:** cashew ricotta→tofu ricotta (tree-nut-free, adds soy); sheets→GF lasagne sheets (gluten-free)
- **Approx:** ~620 kcal · 85g C · 24g P · 20g F
- **Source:** Rich Roll's vegan lasagna from The Plantpower Way, reported as a large dinner — The Chalkboard Mag https://thechalkboardmag.com/ultraman-rich-roll-vegan-athlete-daily-diet/
- **Why:** a carb-load centrepiece from a named vegan ultra athlete's cookbook — bake once, eat all week

### D-052 · Pesto pasta with cherry tomatoes & grilled chicken
- **Context:** everyday, pre-session · **Cuisine:** general · **Prep:** 20 min · **Batch:** yes
- **Ingredients:** pasta 120g dry, basil pesto 30g, cherry tomatoes 100g, chicken breast 150g, parmesan 15g (makes 4)
- **Diets OK:** mediterranean, omnivore
- **Allergens:** dairy, gluten, tree_nuts
- **Swaps:** pesto→sunflower-seed pesto (tree-nut-free); pasta→GF pasta (gluten-free); chicken→white beans (vegetarian)
- **Approx:** ~700 kcal · 85g C · 42g P · 22g F
- **Source:** commonly reported staple across triathlete meal-prep blogs (practicalmealprep.substack.com) and the Feed Zone "carb + sauce + protein" template
- **Why:** jar of pesto, bag of pasta, leftover chicken — the 20-minute pre-long-ride dinner

### D-053 · Butternut squash "mac & cheese" (GF pasta, dairy-free)
- **Context:** carb-load, everyday · **Cuisine:** general · **Prep:** batch — 25 min, 4 servings · **Batch:** yes
- **Ingredients:** GF pasta 110g dry, butternut squash 200g, nutritional yeast 2 tbsp, olive oil 1 tbsp, garlic 1 clove, white beans 100g (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add cashew cream 2 tbsp (richer, adds tree_nuts); add real cheddar (vegetarian, adds dairy)
- **Approx:** ~600 kcal · 100g C · 20g P · 12g F
- **Source:** runtothefinish.com gluten-free meal plan for runners ("Butternut Squash Mac and Cheese, dairy-free")
- **Why:** comfort-food carb-load rebuilt gluten- and dairy-free — allergen-free as written

### D-054 · Vegan stuffed shells with tofu-hummus filling
- **Context:** carb-load, everyday · **Cuisine:** general · **Prep:** batch — filling ahead, 6 servings · **Batch:** yes
- **Ingredients:** jumbo pasta shells 6, tomato sauce 150g, firm tofu 120g crumbled, hummus 50g, spinach 60g, mushrooms 60g, garlic (makes 6)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, sesame, soy
- **Swaps:** shells→GF shells (gluten-free); hummus→tahini-free hummus (sesame-free)
- **Approx:** ~600 kcal · 75g C · 28g P · 20g F
- **Source:** Meghann Featherstun, RD CSSD, Featherstone Nutrition "Vegan Veggie Stuffed Shells" https://www.featherstonenutrition.com/recipe/vegan-veggie-stuffed-shells/
- **Why:** a dietitian's vegan pasta bake with 28g protein — tofu and hummus do the ricotta's job

### D-055 · Allen Lim's fried rice with egg & vegetables
- **Context:** everyday, race-week, recovery · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** day-old cooked rice 300g, eggs 2, carrot, peas and scallion 100g, soy sauce 1½ tbsp, garlic 1 clove, oil 1 tbsp, diced ham or chicken 80g optional
- **Diets OK:** omnivore
- **Allergens:** eggs, gluten, soy
- **Swaps:** soy sauce→tamari (gluten-free); meat→tofu (vegetarian); leave the egg out and add edamame (vegan, keeps soy)
- **Approx:** ~600 kcal · 80g C · 26g P · 18g F
- **Source:** Allen Lim (Feed Zone Cookbook) — his mother's fried rice, "a favorite for immediate post-race recovery" via Velo/Outside https://velo.outsideonline.com/road/road-training/learn-to-make-allen-lims-famous-rice-cakes/ ; egg-fried-rice format also in 220triathlon.com vegetarian guides
- **Why:** the sports scientist behind the Feed Zone eats this straight after races — leftover rice, two eggs, done

### D-056 · Tofu & vegetable fried rice
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — 20 min, 4 servings · **Batch:** yes
- **Ingredients:** day-old cooked rice 300g, firm tofu 200g, peas and carrots 150g, soy sauce 2 tbsp, sesame oil 1 tsp, scallions (makes 4)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, sesame, soy
- **Swaps:** soy sauce→tamari (gluten-free); sesame oil→olive oil (sesame-free); tofu→fava-bean tofu (same soy tag, different protein)
- **Approx:** ~580 kcal · 78g C · 26g P · 16g F
- **Source:** commonly reported vegan-athlete staple — One Green Planet endurance vegan menu https://www.onegreenplanet.org/vegan-food/weekly-meal-plan-endurance-athletes-vegan-menu/ ; the single most repeated dinner shape across r/veganfitness "day of eating" posts
- **Why:** rice + tofu + stir-fry veg is the most-repeated vegan dinner in the whole research — for a reason

### D-057 · Tempeh stir-fry with rice noodles
- **Context:** everyday, pre-session · **Cuisine:** general · **Prep:** 20 min · **Batch:** no
- **Ingredients:** tempeh 200g, rice noodles 100g dry, broccoli, carrot and snap peas 200g, tamari 2 tbsp, ginger, garlic
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** soy
- **Swaps:** tempeh→chickpeas + coconut aminos (soy-free); rice noodles→jasmine rice (same job)
- **Approx:** ~600 kcal · 85g C · 28g P · 14g F
- **Source:** format consistent with Nigel Mitchell's The Plant-Based Cyclist recipes (road.cc review) and general vegan-cyclist meal content
- **Why:** rice noodles are naturally GF and fast-digesting — a vegan night-before-a-key-session dinner

### D-058 · Beef & vegetable stir-fry with coconut aminos & rice
- **Context:** carb-load, everyday · **Cuisine:** general · **Prep:** batch — 20 min, 4 servings · **Batch:** yes
- **Ingredients:** beef strips 180g, jasmine rice 100g dry, broccoli, carrot and snap peas 200g, coconut aminos 3 tbsp, garlic, ginger (makes 4)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** coconut aminos→soy sauce (adds soy, gluten) or tamari (adds soy); beef→flank steak + cornstarch for takeout-style beef & broccoli
- **Approx:** ~640 kcal · 85g C · 42g P · 14g F
- **Source:** standard soy-free swap widely documented in allergy-cooking resources; beef & broccoli commonly reported in endurance-athlete weeknight rotations
- **Why:** takeout beef & broccoli made top-9-free — coconut aminos is neither soy nor gluten

### D-059 · Vegetable stir-fry with rice, poached egg & avocado
- **Context:** everyday · **Cuisine:** general · **Prep:** 20 min · **Batch:** no
- **Ingredients:** mixed stir-fry vegetables 200g, rice 90g dry, eggs 2 poached, avocado ½, soy sauce 1 tbsp, garlic, ginger
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs, gluten, soy
- **Swaps:** soy sauce→tamari (gluten-free) or coconut aminos (soy-free); eggs→tofu (vegan)
- **Approx:** ~600 kcal · 75g C · 22g P · 24g F
- **Source:** Stephanie Howe, PhD — her described "go-to dinner when lacking creativity" https://www.si.com/edge/2017/07/17/stephanie-howe-ultramarathoner-diet-nutrition-donuts
- **Why:** a champion ultrarunner and nutrition PhD's "can't be bothered" dinner — fridge veg, rice, two eggs

### D-060 · Sesame chicken skillet with rice & broccoli
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — 15 min, one skillet, 4 servings · **Batch:** yes
- **Ingredients:** ground chicken 150g, frozen broccoli 120g, rice 100g cooked (≈200g), soy sauce 1½ tbsp, brown sugar 1 tbsp, rice vinegar, ginger, garlic, sesame oil 1 tsp (makes 4)
- **Diets OK:** omnivore
- **Allergens:** gluten, sesame, soy
- **Swaps:** soy sauce→tamari (gluten-free); ground chicken→crumbled tofu (vegan); sesame oil→olive oil (sesame-free)
- **Approx:** ~560 kcal · 70g C · 34g P · 14g F
- **Source:** Meghann Featherstun, RD CSSD, Featherstone Nutrition "Sesame Chicken Skillet" https://www.featherstonenutrition.com/recipe/sesame-chicken-skillet/
- **Why:** a 15-minute one-skillet dinner a marathon dietitian wrote for training-day carb targets

### D-061 · Rice-noodle stir-fry with chicken & low-fibre veg (race-week)
- **Context:** carb-load, pre-session, race-week · **Cuisine:** general · **Prep:** 20 min · **Batch:** no
- **Ingredients:** rice noodles 150g dry, chicken breast 150g, courgette and carrot 100g peeled, tamari 2 tbsp, sesame oil 1 tsp, ginger
- **Diets OK:** omnivore
- **Allergens:** sesame, soy
- **Swaps:** tamari→coconut aminos (soy-free); sesame oil→omit (sesame-free); chicken→tofu (vegan)
- **Approx:** ~620 kcal · 95g C · 38g P · 10g F
- **Source:** commonly reported GF/DF race-week staple (rice noodles as the naturally-GF pasta substitute; trigirl.co.uk and Fuelin-style GF athlete guidance)
- **Why:** a carb-load stir-fry with the fibre engineered out — peeled veg, rice noodles, lean protein

### D-062 · Tofu & vegetable stir-fry, no rice (rest-day)
- **Context:** rest-day · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** firm tofu 250g, mixed stir-fry vegetables 300g, soy sauce 2 tbsp, garlic, ginger, oil 1 tbsp
- **Diets OK:** low_carb, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, soy
- **Swaps:** soy sauce→tamari (gluten-free); add rice 90g dry (training-day version, +70g C)
- **Approx:** ~420 kcal · 22g C · 30g P · 24g F
- **Source:** Amy Kilpin's rest-day dinner — Sundried "What I Eat In A Day"
- **Why:** a real triathlete's lower-carb rest-day dinner — same protein, no starch, more veg

### D-063 · Turkey chilli with quinoa
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — 45 min, 6 servings, freezes well · **Batch:** yes
- **Ingredients:** ground turkey 130g, quinoa 50g dry, kidney beans 100g, chopped tomatoes 150g, onion ¼, bell pepper ½, chilli powder and cumin (makes 6)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** turkey→extra beans and lentils (vegan); serve without quinoa (rest-day, −35g C)
- **Approx:** ~520 kcal · 55g C · 38g P · 14g F
- **Source:** Nancy Clark's Sports Nutrition Guidebook https://us.humankinetics.com/products/nancy-clarks-sports-nutrition-guidebook-6th-edition ; The Pretty Bee top-9-free plan (bean-based turkey chilli)
- **Why:** Nancy Clark's lean-protein-plus-whole-grain batch dinner — allergen-free and freezer-stackable

### D-064 · Beef chilli con carne with rice
- **Context:** carb-load, everyday · **Cuisine:** general · **Prep:** batch — slow cooker or 40 min stovetop, 6 servings, freezes 3 months · **Batch:** yes
- **Ingredients:** ground beef 130g, kidney beans 130g, chopped tomatoes 130g, onion ⅓, chilli powder 1 tsp, cumin, rice 90g dry (makes 6)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** rice→baked potato (same carbs, British version); rice→cauliflower rice (low_carb); top with cheese (adds dairy)
- **Approx:** ~650 kcal · 80g C · 42g P · 18g F
- **Source:** widely reported athlete batch-cooking staple ("tastes better with time") across meal-prep blogs and r/triathlon "what I eat" threads
- **Why:** the freezer-batch classic — six dinners from one pot

### D-065 · Minnesota winter chilli (vegan, two-bean)
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** batch — slow cooker or 40 min stovetop, 6 servings, freezes well · **Batch:** yes
- **Ingredients:** kidney beans 130g, black beans 130g, chopped tomatoes 130g, corn 50g, bell pepper ⅓, onion ⅓, chilli powder 1 tsp (makes 6)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** serve over rice 90g dry (training day, +70g C); add cornbread (adds gluten, usually dairy)
- **Approx:** ~500 kcal · 85g C · 22g P · 4g F
- **Source:** Scott Jurek's "Minnesota Winter Chili", Eat & Run http://www.scottjurek.com/eat ; runtothefinish.com GF meal plan ("Hearty Veggie Chili")
- **Why:** a seven-time Western States champion's freezer chilli — beans, tomatoes, spice, nothing else

### D-066 · Slow-cooker chicken & white bean chilli with rice
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — slow cooker 6–8 h, 6 servings · **Batch:** yes
- **Ingredients:** chicken breast 130g, white beans 100g, green chillies 30g, chicken stock 120ml, cumin 1 tsp, onion ¼, rice 75g dry (makes 6)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** skip the rice (rest-day); top with avocado and lime; confirm stock is GF-labelled
- **Approx:** ~580 kcal · 65g C · 45g P · 10g F
- **Source:** runtothefinish.com gluten-free meal plan for runners ("Spicy White Bean Chicken Chili"); commonly reported slow-cooker athlete staple
- **Why:** set it before the long ride, eat it after — lean protein, beans, no allergens

### D-067 · Paleo beef & sweet potato chilli (no beans)
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** batch — slow cooker or 40 min, 4–6 servings · **Batch:** yes
- **Ingredients:** ground beef 170g, sweet potato 150g diced, chopped tomatoes 200g, bell pepper ½, chilli powder 1 tsp, cumin (makes 4)
- **Diets OK:** low_carb, omnivore, paleo
- **Allergens:** none
- **Swaps:** add kidney beans (drops paleo, +10g P, +20g C); serve over rice for a training day
- **Approx:** ~520 kcal · 32g C · 38g P · 24g F
- **Source:** commonly reported paleo-athlete batch staple (r/paleo; Cordain & Friel "Paleo Diet for Athletes" no-legume framing) https://www.trainingpeaks.com/blog/a-quick-guide-to-the-paleo-diet-for-athletes/
- **Why:** chilli for the paleo athlete — sweet potato does the beans' job

### D-068 · Slow-cooker beef stew with potatoes & carrots
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** batch — slow cooker 6–8 h, 6 servings, freezes well · **Batch:** yes
- **Ingredients:** beef chuck 150g, potatoes 200g, carrots 100g, onion ¼, beef stock 200ml, thyme (makes 6)
- **Diets OK:** omnivore, paleo
- **Allergens:** none
- **Swaps:** potatoes→sweet potato (paleo pot-roast version); add pearl barley 40g (adds gluten, +30g C)
- **Approx:** ~520 kcal · 45g C · 38g P · 18g F
- **Source:** commonly reported cold-weather batch-cooking staple across triathlete/runner meal-prep threads (r/paleo pot-roast norm)
- **Why:** hands-off, high-satiety, freezes flat — the winter rest-day dinner

### D-069 · Chicken tortilla soup
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** batch — 30 min, 6 servings, freezes well · **Batch:** yes
- **Ingredients:** chicken breast 130g, black beans 80g, corn 60g, chopped tomatoes 150g, chicken stock 250ml, corn tortilla strips 30g, lime (makes 6)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** add rice 50g dry (training-day version); top with avocado; cheese on top (adds dairy)
- **Approx:** ~480 kcal · 50g C · 36g P · 12g F
- **Source:** commonly reported athlete-household soup staple, aligned with sports-dietitian "soup as batch dinner" guidance
- **Why:** high-volume, warming, portions cleanly — a rest-day dinner you can eat a lot of

### D-070 · Minestrone with cannellini beans & small pasta
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** batch — 35 min, 6 servings, freezes well · **Batch:** yes
- **Ingredients:** cannellini beans 130g, small pasta 60g dry, carrot, celery and courgette 150g, chopped tomatoes 130g, vegetable stock 250ml, olive oil 1 tbsp (makes 6)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** pasta→GF small pasta or rice (gluten-free); top with parmesan (vegetarian, adds dairy); add extra beans (+P)
- **Approx:** ~480 kcal · 75g C · 18g P · 8g F
- **Source:** commonly reported Mediterranean-style batch soup in endurance-nutrition guidance
- **Why:** a pot of vegetables, beans and pasta — the Mediterranean rest-day dinner, six portions

### D-071 · Chicken & rice-noodle soup (low-residue)
- **Context:** race-week, recovery · **Cuisine:** general · **Prep:** batch — 25 min, 4 servings · **Batch:** yes
- **Ingredients:** chicken breast 150g shredded, rice noodles 100g dry, chicken broth 500ml, carrot 50g, scallion greens, ginger (makes 4)
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** rice noodles→egg noodles (adds gluten, eggs — the classic chicken noodle soup); confirm broth is GF-labelled; salt + lime instead of fish sauce keeps it fish-free
- **Approx:** ~500 kcal · 60g C · 38g P · 8g F
- **Source:** commonly reported gut-friendly race-week dinner combining a rice-noodle GF staple with the low-FODMAP soup pattern (Frontiers FODMAP-athlete research context); r/Ultramarathon cold-weather recovery staple
- **Why:** warm, low-fibre, low-fat — the night-before-a-key-session soup, allergen-free as written

### D-072 · Post-long-run ramen with soft egg & greens
- **Context:** recovery · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** fresh ramen noodles 200g, broth 500ml, soft-boiled egg 1, bok choy 100g, sliced chicken or beef 120g, scallions
- **Diets OK:** omnivore
- **Allergens:** eggs, gluten, soy
- **Swaps:** ramen→rice noodles (gluten-free); egg + meat→tofu (vegan with veg broth)
- **Approx:** ~650 kcal · 80g C · 36g P · 16g F
- **Source:** u/ElderberryNo5595, r/Ultramarathon "What do you eat day-to-day?" — "my after run treat is typically a giant bowl of ramen, which I really look forward to all week" https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- **Why:** broth, salt, carbs, protein — the recovery bowl people look forward to all week

### D-073 · Almost-instant miso ramen with tofu (plant-based)
- **Context:** recovery, travel · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** ramen noodles 100g, firm tofu 120g, miso paste 1 tbsp, bok choy 80g, mushrooms 60g, scallion, soy sauce 1 tsp
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, soy
- **Swaps:** noodles→rice noodles (gluten-free); add edamame 60g (+8g P)
- **Approx:** ~560 kcal · 75g C · 26g P · 14g F
- **Source:** "Almost Instant Ramen" — The No Meat Athlete Cookbook, "Fuel & Recovery" section, nomeatathlete.com
- **Why:** kettle, miso, tofu — a warm vegan recovery dinner when appetite is low after a big session

### D-074 · Lentil & vegetable shepherd's pie (dairy-free mash)
- **Context:** everyday, recovery, rest-day · **Cuisine:** general · **Prep:** batch — 45 min, 4–5 servings, freezes well · **Batch:** yes
- **Ingredients:** green lentils 150g cooked, carrot, peas and onion 150g, tomato paste 1 tbsp, potatoes 250g, oat milk 40ml, olive oil 1 tbsp (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** lentils→ground lamb (omnivore); potato topping→sweet potato (paleo version with lamb)
- **Approx:** ~520 kcal · 80g C · 20g P · 12g F
- **Source:** standard vegan-athlete comfort staple, cross-referenced in FARE-adjacent allergen-free recipe roundups; commonly reported
- **Why:** batch-cookable, freezer-stable comfort food with zero allergens — one of the strongest anchors for multi-allergy users

### D-075 · Lentil & vegetable stew (rest-day, fibre-forward)
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** batch — 35 min, 4 servings · **Batch:** yes
- **Ingredients:** brown lentils 200g cooked, mixed vegetables 250g (carrot, celery, courgette, kale), chopped tomatoes 150g, vegetable stock 200ml, olive oil 1 tbsp (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add protein pasta 60g (training day, check GF); add a chicken thigh (omnivore)
- **Approx:** ~480 kcal · 65g C · 26g P · 10g F
- **Source:** u/Ultragirl50, r/Ultramarathon "What do you eat day-to-day?" (plant-based) https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- **Why:** a plant-based ultrarunner's rest-day dinner — fibre and veg up, starch down

### D-076 · Homemade margherita pizza
- **Context:** carb-load, everyday, pre-session · **Cuisine:** general · **Prep:** 30 min (store dough) · **Batch:** no
- **Ingredients:** pizza dough 250g, passata 100g, mozzarella 120g, basil, olive oil 1 tsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** dough→GF base (gluten-free); mozzarella→dairy-free mozzarella (vegan); add chicken or ham (+P)
- **Approx:** ~800 kcal · 100g C · 36g P · 26g F
- **Source:** Patrick Lange (vegetarian Ironman world champion) "eats a lot of pizza and pasta to make sure he gets enough carbs" — CNN; Gustav Iden's "normal food" approach, vo2master.com https://vo2master.com/blog/the-norwegian-method-s02-s06/
- **Why:** a Kona champion's carb-load — 100g of carbs the whole household will actually eat the night before a long ride

### D-077 · Turkey burger with sweet-potato fries
- **Context:** everyday · **Cuisine:** general · **Prep:** batch — patties and fries bake together, 4 servings · **Batch:** yes
- **Ingredients:** ground turkey 180g, burger bun 1, sweet potato 250g, olive oil 1 tbsp, lettuce, tomato (makes 4)
- **Diets OK:** omnivore
- **Allergens:** gluten
- **Swaps:** bun→GF bun (gluten-free) or lettuce wrap (low_carb); turkey→beef patty
- **Approx:** ~680 kcal · 75g C · 40g P · 22g F
- **Source:** commonly reported weeknight athlete-household staple; sweet-potato fries widely recommended by sports dietitians as the baked "fries upgrade"
- **Why:** burger and fries that still hit 75g of carbs and 40g of protein — bake the fries, don't fry them

### D-078 · Lentil-mushroom burgers with mashed potatoes
- **Context:** everyday · **Cuisine:** general · **Prep:** batch — patties freeze well, 4 servings · **Batch:** yes
- **Ingredients:** cooked lentils 200g, mushrooms 150g, breadcrumbs 50g, burger bun 1, potatoes 300g mashed with olive oil (makes 4)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** breadcrumbs and bun→GF versions (gluten-free); mash→sweet-potato fries
- **Approx:** ~620 kcal · 95g C · 22g P · 12g F
- **Source:** Scott Jurek's "Lentil Mushroom Burgers" and "Minnesota Mashed Potatoes", Eat & Run http://www.scottjurek.com/eat
- **Why:** a vegan ultra legend's burger night — lentils for protein, potatoes for the carbs

### D-079 · Beef burger with grilled corn & salad
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** 20 min · **Batch:** no
- **Ingredients:** beef patty 180g, burger bun 1, corn on the cob 1, mixed salad 100g, tomato, onion
- **Diets OK:** omnivore
- **Allergens:** gluten
- **Swaps:** bun→lettuce wrap (gluten-free, low_carb, paleo); add fries and a glass of wine (Carfrae's post-Kona version — recovery/treat)
- **Approx:** ~650 kcal · 60g C · 38g P · 28g F
- **Source:** commonly reported summer grill-night staple; Mirinda Carfrae's stated post-Kona recovery meal — "dirty burger and wine", si.com
- **Why:** even world champions eat a burger after the big one — protein, carbs, and a mental reset

### D-080 · Bunless bacon cheeseburger with side salad
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** beef patty 180g, cheddar 1 slice, bacon 2 rashers, lettuce leaves, tomato, side salad 150g with olive oil
- **Diets OK:** keto, low_carb, omnivore
- **Allergens:** dairy
- **Swaps:** cheese→omit (paleo, dairy-free); add sweet-potato fries 150g (paleo targeted-carb, +35g C)
- **Approx:** ~700 kcal · 8g C · 44g P · 52g F
- **Source:** commonly reported low-carb athlete staple (r/ketoendurance community norm; Volek & Phinney macro pattern)
- **Why:** the burger shape without the bun — a keto athlete's repeatable rest-day dinner

### D-081 · Tri-tip steak with roasted broccoli
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** 20 min · **Batch:** no
- **Ingredients:** tri-tip or sirloin steak 200g, broccoli 250g, olive oil 2 tbsp, garlic 2 cloves, salt
- **Diets OK:** keto, low_carb, omnivore, paleo
- **Allergens:** none
- **Swaps:** broccoli→asparagus or green beans; add sweet potato 200g (targeted carb before a long session)
- **Approx:** ~650 kcal · 12g C · 50g P · 42g F
- **Source:** Zach Bitter's reported favourite dinner (100-mile American record holder, low-carb) — Men's Journal https://www.mensjournal.com/health-fitness/zach-bitter-100-mile-american-record-holder-he-also-eats-almost-no-carbs
- **Why:** the low-carb ultrarunner's staple — steak and a green vegetable, nothing to overthink

### D-082 · Ground beef with sautéed kale & garlic
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** ground beef or steak 200g, kale or spinach 200g, olive oil 2 tbsp, garlic 2 cloves, salt
- **Diets OK:** keto, low_carb, omnivore, paleo
- **Allergens:** none
- **Swaps:** add roasted sweet potato 200g (paleo "protein bowl", recovery); beef→lamb
- **Approx:** ~600 kcal · 8g C · 45g P · 42g F
- **Source:** Mike McKnight's reported dinner pattern (low-carb 200-miler) — Diet Doctor https://www.dietdoctor.com/low-carb-improves-ultra-runners-performance-and-health
- **Why:** "beef and a green veg" is the recurring low-carb ultrarunner dinner — 15 minutes, one pan

### D-083 · Cauliflower-rice chicken stir-fry
- **Context:** rest-day · **Cuisine:** general · **Prep:** 20 min · **Batch:** no
- **Ingredients:** chicken thigh 200g, cauliflower rice 300g, mixed peppers 100g, coconut aminos 2 tbsp, sesame oil 1 tsp, garlic, ginger
- **Diets OK:** keto, low_carb, omnivore, paleo
- **Allergens:** sesame
- **Swaps:** sesame oil→olive oil (sesame-free); cauliflower rice→half rice, half cauliflower (moderate-carb day)
- **Approx:** ~480 kcal · 14g C · 42g P · 26g F
- **Source:** commonly reported low-carb/paleo takeout swap (r/ketoendurance, r/paleo norm; Bob Seebohar metabolic-efficiency framing)
- **Why:** the fried-rice craving on a rest day — same pan, same sauce, a tenth of the carbs

### D-084 · Roasted vegetable & halloumi traybake
- **Context:** rest-day · **Cuisine:** general · **Prep:** 30 min, mostly hands-off · **Batch:** yes
- **Ingredients:** halloumi 150g, courgette 1, red onion 1, bell peppers 2, cherry tomatoes 150g, olive oil 2 tbsp, oregano
- **Diets OK:** keto, low_carb, mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** halloumi→extra-firm tofu (vegan, adds soy); add couscous 60g dry (training day, adds gluten, +45g C)
- **Approx:** ~500 kcal · 22g C · 26g P · 34g F
- **Source:** commonly reported Mediterranean-style rest-day dinner in endurance-nutrition blog content
- **Why:** fat and veg are what training days squeeze out — a rest-day dinner that leans into both

### D-085 · Steak fajita salad with avocado
- **Context:** rest-day · **Cuisine:** general · **Prep:** 20 min · **Batch:** no
- **Ingredients:** sirloin steak 200g, mixed greens 150g, bell pepper 1, avocado ½, lime, olive oil 1 tbsp, cumin
- **Diets OK:** keto, low_carb, omnivore, paleo
- **Allergens:** none
- **Swaps:** add corn tortillas 3 (steak tacos, +45g C, still GF); steak→chicken thigh
- **Approx:** ~560 kcal · 15g C · 42g P · 34g F
- **Source:** commonly reported low-carb/keto athlete rest-day dinner; steak tacos with pico & guac from u/Prudent_Exercise_471, r/Ultramarathon
- **Why:** fajitas without the tortillas — keto on the rest day, tacos on the training day

### D-086 · Grilled branzino with lemon & grilled vegetables
- **Context:** everyday, race-week, rest-day · **Cuisine:** general · **Prep:** 20 min · **Batch:** no
- **Ingredients:** whole branzino or sea bass fillet 200g, lemon 1, olive oil 1 tbsp, courgette and peppers 200g grilled
- **Diets OK:** low_carb, mediterranean, omnivore, paleo, pescatarian
- **Allergens:** fish
- **Swaps:** add boiled potatoes 250g (training-day/race-eve carbs); fish→chicken thigh (fish-free)
- **Approx:** ~460 kcal · 10g C · 40g P · 26g F
- **Source:** commonly reported Greek/Italian triathlete dinner (Mediterranean-diet-for-athletes overviews) https://www.recoveryforathletes.com/blogs/recovery-for-athletes-blog/mediterranean-diet-for-athletes-boost-performance-health-and-longevity
- **Why:** low-residue, easily digested fish — Mediterranean on a rest day, race-eve with potatoes added

### D-087 · Salmon, roasted sweet potato & asparagus
- **Context:** pre-session, race-week, recovery · **Cuisine:** general · **Prep:** 30 min · **Batch:** no
- **Ingredients:** salmon fillet 170g, sweet potato 250g, asparagus 150g, olive oil 1 tbsp, lemon
- **Diets OK:** low_carb, mediterranean, omnivore, paleo, pescatarian
- **Allergens:** fish
- **Swaps:** add white rice 90g dry (Howe's pre-ultra version, +70g C); asparagus→steamed broccoli (Fuelin version); salmon→chicken thigh (fish-free)
- **Approx:** ~600 kcal · 45g C · 40g P · 26g F
- **Source:** Stephanie Howe, PhD — her reported pre-100-mile dinner (salmon, rice, sweet potato) https://www.si.com/edge/2017/07/17/stephanie-howe-ultramarathoner-diet-nutrition-donuts ; Fuelin coaching template https://fuelin.com/articles/race-ready-your-nutrition-playbook-for-endurance-success
- **Why:** a champion ultrarunner's pre-race dinner — proof that carb-loading doesn't have to be pasta

### D-088 · Ground beef & sweet potato bowl with greens
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — 30 min, 4 servings · **Batch:** yes
- **Ingredients:** ground beef 200g, sweet potato 250g roasted, spinach or kale 100g, olive oil 1 tbsp, salt (makes 4)
- **Diets OK:** low_carb, omnivore, paleo
- **Allergens:** none
- **Swaps:** beef→ground turkey; add a fried egg (adds eggs); sweet potato→white potato (cheaper)
- **Approx:** ~640 kcal · 40g C · 42g P · 32g F
- **Source:** "Ground Beef Protein Bowls" — The Paleo Diet, "post-workout recovery" recipes https://thepaleodiet.com/recipes/paleo-recipes-for-athletes/
- **Why:** a named paleo recovery recipe — ~1g/kg carbs and 40g protein without grains or dairy

### D-089 · Olive-oil roasted vegetables with white beans & feta
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** batch — roast a tray, 4 servings · **Batch:** yes
- **Ingredients:** courgette, aubergine, bell pepper and red onion 350g, olive oil 2 tbsp, cannellini beans 200g, feta 40g (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** feta→omit (vegan, dairy-free); add crusty bread (training day, adds gluten)
- **Approx:** ~500 kcal · 50g C · 20g P · 24g F
- **Source:** commonly reported Mediterranean rest-day dinner (Mediterranean-diet-for-athletes overviews, high-plant-food pattern)
- **Why:** veg and legumes forward, moderate carbs — the Mediterranean "more veg on easy days" plate

### D-090 · Eggs, cheese & fried potatoes
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** 15 min · **Batch:** no
- **Ingredients:** eggs 3, potatoes 250g diced and fried, cheddar 30g, spinach 100g, olive oil 1 tbsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs
- **Swaps:** cheese→omit (dairy-free); potatoes→toast (adds gluten); scale potatoes to the day's training
- **Approx:** ~600 kcal · 45g C · 30g P · 32g F
- **Source:** THowe, TrainerRoad forum "What do you eat during any given day" — dinner scaled to that day's training volume https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/9
- **Why:** five ingredients, fifteen minutes, portion the potatoes to the day — the cheapest real dinner here

### D-091 · Brown rice with fried eggs & sriracha
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** 10 min · **Batch:** no
- **Ingredients:** brown rice 90g dry, eggs 3 fried, sriracha 1 tbsp, scallions, oil 1 tsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs
- **Swaps:** add edamame 80g (+8g P, adds soy); brown→white rice (race-week); add kimchi
- **Approx:** ~580 kcal · 72g C · 26g P · 20g F
- **Source:** BCM, TrainerRoad forum https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095/4
- **Why:** three ingredients — the definition of the repeatable, student-budget dinner

### D-092 · Brown rice, mixed pulses & steamed vegetables
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — 25 min, 4 servings · **Batch:** yes
- **Ingredients:** brown rice 90g dry, lentils and chickpeas 150g cooked, steamed vegetables 200g, olive oil 1 tbsp, salt, lemon (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** rice→pasta (adds gluten); pulses→tofu (adds soy); add tahini dressing (adds sesame)
- **Approx:** ~620 kcal · 100g C · 24g P · 12g F
- **Source:** Fiona Oakes' described post-race staple — "plenty of carbs, rice, pasta and pulses" — veganeasy.org, forksoverknives.com
- **Why:** a world-record vegan marathoner's minimalist plate — grain, pulse, veg, oil

### D-093 · Baked sweet potato with black beans, corn & hot sauce
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — bake 6 potatoes at once, top nightly · **Batch:** yes
- **Ingredients:** sweet potato 350g baked, black beans 200g, corn 80g, hot sauce, lime, avocado ¼
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add cashew cream 2 tbsp (adds tree_nuts); add cheese (vegetarian, adds dairy); top with leftover chicken (omnivore)
- **Approx:** ~560 kcal · 105g C · 20g P · 6g F
- **Source:** mattymurda, TrainerRoad forum "Canned corn and black beans, my cheap but effective training fuel" https://www.trainerroad.com/forum/t/canned-corn-and-black-beans-my-cheap-but-effective-training-fuel-source/13689/6
- **Why:** bake a tray of sweet potatoes Sunday, top differently all week — the clearest cheap component dinner in the research

### D-094 · Quinoa, baked tofu & roast veg bowl with avocado-lime dressing
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** batch — roast veg and cook quinoa ahead, 4 servings · **Batch:** yes
- **Ingredients:** quinoa 80g dry, baked tofu 150g, roasted sweet potato 150g, spinach, pepper and cucumber 150g, avocado-lime dressing 2 tbsp (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** soy
- **Swaps:** tofu→grilled chicken (omnivore, soy-free); tofu→balsamic-roasted tempeh (Kylee Van Horn's version, keeps soy)
- **Approx:** ~620 kcal · 80g C · 30g P · 20g F
- **Source:** Paula Findlay's 7pm dinner — triathlonmagazine.ca ; Kylee Van Horn, RDN (FlyNutrition) balsamic tempeh bowl https://flynutrition.org/about
- **Why:** a pro triathlete's grain + protein + roast veg + dressing bowl — batch the parts, assemble in 5 minutes

### D-095 · Sheet-pan tofu, sweet potato & broccoli
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** batch — 30 min, one tray, 4 servings · **Batch:** yes
- **Ingredients:** firm tofu 200g cubed, sweet potato 200g, broccoli 150g, bell pepper 1, olive oil 1 tbsp, tamari 1 tbsp, garlic powder (makes 4)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** soy
- **Swaps:** tofu→large white beans + coconut aminos (soy-free); add rice 90g dry (training day, +70g C)
- **Approx:** ~520 kcal · 55g C · 28g P · 20g F
- **Source:** "sheet pan meals with veggies and tofu" — The No Meat Athlete Cookbook, nomeatathlete.com
- **Why:** the vegan version of the sheet-pan default — one tray, four dinners, minimal washing-up

### D-096 · Salmon fish cakes with red cabbage & apple slaw
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** batch — 35 min, 4 servings, fish cakes freeze · **Batch:** yes
- **Ingredients:** salmon 100g, egg ½, flour 1 tbsp, spring onion, ginger, lime zest; slaw: red cabbage 80g, apple ¼, red pepper ¼, mint, pistachios 6g, honey, olive oil 1 tsp; boiled potatoes 250g (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian
- **Allergens:** eggs, fish, gluten, tree_nuts
- **Swaps:** flour→GF flour (gluten-free); pistachios→omit (tree-nut-free); tinned salmon works
- **Approx:** ~600 kcal · 55g C · 36g P · 26g F
- **Source:** Hannah Grant, Tour de France team chef — BikeRadar "Fuel like Tour de France riders" https://www.bikeradar.com/advice/nutrition/tour-de-france-recipes
- **Why:** a Grand Tour chef's recovery dinner — omega-3 protein and a fibre-rich slaw, potatoes for the carbs

### D-097 · Miso salmon with soba noodles & bok choy
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** 25 min · **Batch:** no
- **Ingredients:** salmon fillet 170g, white miso 1 tbsp, soba noodles 120g dry, bok choy 150g, scallions
- **Diets OK:** omnivore, pescatarian
- **Allergens:** fish, gluten, soy
- **Swaps:** soba→100% buckwheat soba (gluten-free); salmon→miso-glazed tofu (vegan)
- **Approx:** ~640 kcal · 75g C · 42g P · 18g F
- **Source:** commonly reported Japanese-style recovery dinner in endurance-nutrition content pairing omega-3 fish with buckwheat noodles
- **Why:** a 25-minute recovery dinner on a non-Western noodle base

### D-098 · Oven-baked fish & chips
- **Context:** everyday · **Cuisine:** general · **Prep:** 35 min · **Batch:** no
- **Ingredients:** white fish fillet 200g, breadcrumbs 50g, potatoes 350g cut and baked, olive oil 1 tbsp, peas 100g, lemon
- **Diets OK:** omnivore, pescatarian
- **Allergens:** fish, gluten
- **Swaps:** breadcrumbs→GF breadcrumbs or polenta crust (gluten-free); add tartare (adds eggs)
- **Approx:** ~650 kcal · 80g C · 40g P · 16g F
- **Source:** commonly reported British/Irish endurance-athlete comfort dinner (220triathlon/tri247 readership staple)
- **Why:** Friday fish and chips, baked not fried — 80g of carbs and a proper hit of protein

### D-099 · Microwave rice, tinned tuna & sweetcorn (hotel-room dinner)
- **Context:** carb-load, race-week, travel · **Cuisine:** general · **Prep:** 3 min, microwave · **Batch:** no
- **Ingredients:** microwave white rice pouch 250g, tinned tuna 1 can (~120g drained), sweetcorn 80g, olive oil sachet, salt
- **Diets OK:** omnivore, pescatarian
- **Allergens:** fish
- **Swaps:** tuna→tinned chickpeas (vegan); add a soy sauce sachet (adds soy, gluten); add a tinned-tuna second can on a big day
- **Approx:** ~520 kcal · 75g C · 32g P · 8g F
- **Source:** commonly reported minimal-equipment race-trip meal (hotel microwave or kettle) in triathlon travel-logistics threads
- **Why:** no kitchen, no fridge you trust — the realistic race-trip dinner that still hits carb-load numbers

### D-100 · Baked white fish with peeled mashed potato (race-eve)
- **Context:** carb-load, race-week · **Cuisine:** general · **Prep:** 25 min · **Batch:** no
- **Ingredients:** cod or haddock fillet 200g, potatoes 350g peeled and mashed, butter 1 tbsp, salt, well-cooked carrots 80g
- **Diets OK:** omnivore, pescatarian
- **Allergens:** dairy, fish
- **Swaps:** butter→olive oil (dairy-free); fish→poached chicken (fish-free); skip the carrots (ultra-low-residue)
- **Approx:** ~580 kcal · 70g C · 40g P · 14g F
- **Source:** STYRKR "What to eat the night before a race" https://styrkr.com/en-us/blogs/training-and-nutrition-hub/what-to-eat-the-night-before-a-race ; marathonhandbook.com pre-marathon guidance ("peeled potatoes digest quickly")
- **Why:** the race-eve dinner for someone who has had race-morning GI trouble before — bland, peeled, low-fat


---

## Snack (100)

### S-001 · Banana with almond butter
- **Context:** everyday, pre-session, travel · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** banana 1 medium, almond butter 2 tbsp
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** tree_nuts
- **Swaps:** almond butter→peanut butter (cheaper, peanuts, not paleo); almond butter→sunflower seed butter (nut-free); add honey drizzle (more carbs, not vegan)
- **Approx:** ~300 kcal · 33g C · 8g P · 18g F
- **Source:** Olympic triathlete Sarah Groff's "true triathlon training snack", ESPNW https://www.espn.com/espnw/athletes-life/article/12376803/sarah-groff-true-triathlon-training-snack; also the default staple across marathonhandbook.com and r/triathlon
- **Why:** the cheapest pre-session carb hit with enough fat to hold you 90 minutes — what pros and amateurs both actually eat

### S-002 · Apple with peanut butter
- **Context:** everyday, pre-session, rest-day · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** apple 1, peanut butter 1.5 tbsp
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** peanuts
- **Swaps:** peanut butter→almond butter (paleo, tree_nuts); peanut butter→sunflower seed butter (nut-free); apple→pear (same effect)
- **Approx:** ~250 kcal · 30g C · 7g P · 13g F
- **Source:** the most-repeated snack across three separate TrainerRoad forum threads https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095 and https://www.trainerroad.com/forum/t/your-favorite-snacks/7464; also triplethreatlife.substack.com and r/Ultramarathon
- **Why:** fibre plus fat keeps it a desk snack rather than a sugar spike — the default rest-day or mid-afternoon top-up

### S-003 · Toast with honey
- **Context:** carb-load, everyday, pre-session, race-week · **Cuisine:** british · **Prep:** 5 min · **Batch:** no
- **Ingredients:** white or sourdough bread 2 slices, honey 2 tbsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** gluten
- **Swaps:** bread→gluten-free bread (gluten-free); honey→jam (vegan); add orange juice 300ml (carb-load, +34g C)
- **Approx:** ~280 kcal · 55g C · 6g P · 3g F
- **Source:** low-fibre pre-session pattern in Triathlete.com https://www.triathlete.com/nutrition/race-fueling/go-breakfast-options-busy-athletes/ and the 220 Triathlon carb-load guide https://www.220triathlon.com/gear/nutrition/how-to-carb-load
- **Why:** low-fibre, low-fat, fast carbs — the 60–90-min-before-a-session classic

### S-004 · Toast with peanut butter, banana & coffee
- **Context:** everyday, pre-session · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** bread 2 slices, peanut butter 1.5 tbsp, banana 1, coffee 1 cup
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, peanuts
- **Swaps:** bread→gluten-free bread (gluten-free); peanut butter→sunflower seed butter (peanut-free); coffee→oat-milk cappuccino (Paula Findlay's version)
- **Approx:** ~350 kcal · 55g C · 10g P · 12g F
- **Source:** Paula Findlay's 2pm snack, triathlonmagazine.ca; the single most-repeated pre-long-run answer on r/AdvancedRunning https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/
- **Why:** carbs, caffeine and a little fat — the pre-long-run breakfast in snack form

### S-005 · White bread with chocolate hazelnut spread
- **Context:** pre-session · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** white bread 2 slices, chocolate hazelnut spread 2 tbsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten, soy, tree_nuts
- **Swaps:** bread→gluten-free bread (gluten-free); spread→honey (nut-free, dairy-free); spread→jam (vegan)
- **Approx:** ~350 kcal · 50g C · 7g P · 14g F
- **Source:** Gustav Iden's stated pre-session snack, vo2master.com "The Norwegian Method"; also reported at https://nutri.it.com/what-diet-does-kristian-blummenfelt-follow
- **Why:** a world champion eats bread and Nutella before sessions — quick, palatable simple carbs, nothing clinical about it

### S-006 · Half bagel with honey & banana
- **Context:** pre-session · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** white bagel 1/2, honey 1 tbsp, banana 1
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** gluten
- **Swaps:** bagel→gluten-free bagel (gluten-free); honey→butter 1 tbsp (more fat, dairy); whole bagel (+30g C for a long session)
- **Approx:** ~220 kcal · 48g C · 5g P · 1g F
- **Source:** Fuelin RD sample pre-workout structure https://fuelin.com/articles/race-ready-your-nutrition-playbook-for-endurance-success; bagel + banana also triplethreatlife.substack.com
- **Why:** textbook low-fat, low-fibre, fast-digesting pre-session carbs from a coaching dietitian protocol

### S-007 · Rice cakes with jam
- **Context:** carb-load, pre-session, race-week, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** plain rice cakes 3, strawberry jam 2 tbsp
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** jam→sunflower seed butter + jam (+8g F, still nut-free); add banana slices (+27g C)
- **Approx:** ~200 kcal · 45g C · 2g P · 1g F
- **Source:** low-residue race-week carb source in the 220 Triathlon carb-load guide https://www.220triathlon.com/gear/nutrition/how-to-carb-load; commonly reported last-hour pre-session top-up
- **Why:** naturally free of all nine allergens, zero fibre, zero fat — the safest race-eve or last-hour top-up there is

### S-008 · White bread with jam
- **Context:** carb-load, race-week · **Cuisine:** british · **Prep:** no-cook · **Batch:** no
- **Ingredients:** white bread 2 slices, strawberry jam 3 tbsp
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** bread→gluten-free white bread (gluten-free); jam→honey (not vegan)
- **Approx:** ~260 kcal · 55g C · 5g P · 2g F
- **Source:** named directly as a race-eve carb-load snack in 220 Triathlon "White carbs, Haribo and practice" https://www.220triathlon.com/gear/nutrition/how-to-carb-load
- **Why:** low-residue, high-simple-carb, familiar — the textbook carb-load filler between meals

### S-009 · Salted pretzels
- **Context:** carb-load, pre-session, race-week, travel · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** mini pretzels 60g
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** pretzels→gluten-free pretzels (gluten-free); add hummus 40g (+7g P, sesame)
- **Approx:** ~230 kcal · 48g C · 5g P · 2g F
- **Source:** 220 Triathlon carb-load guide https://www.220triathlon.com/gear/nutrition/how-to-carb-load; Marathon Handbook travel snacks https://marathonhandbook.com/best-snacks-for-runners/
- **Why:** salty, low-fat, low-fibre — carb-loads and covers the salt craving without upsetting the stomach

### S-010 · Glass of fruit juice
- **Context:** carb-load, pre-session, race-week · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** 100% apple or orange juice 300ml
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** juice→coconut water (fewer carbs, more potassium); dilute 50/50 with water (gentler)
- **Approx:** ~140 kcal · 34g C · 1g P · 0g F
- **Source:** listed alongside pretzels as a simple pre-race carb option, Runners Connect https://runnersconnect.net/healthy-eating-travel/; dietitian carb-load protocols use juice as fibre-free liquid carbs
- **Why:** fibre-free liquid carbs for the carb-load day when you cannot face more solid food

### S-011 · Plain rice crackers
- **Context:** carb-load, everyday, race-week, travel · **Cuisine:** japanese · **Prep:** no-cook · **Batch:** no
- **Ingredients:** plain salted rice crackers 40g
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** avoid soy-sauce-glazed senbei (adds soy, gluten); pair with cottage cheese 100g (+12g P, dairy)
- **Approx:** ~150 kcal · 33g C · 2g P · 1g F
- **Source:** rice-based crackers recommended for low-residue race-week carb loading, ROUVY https://rouvy.com/blog/best-carb-sources-triathletes and 220triathlon.com
- **Why:** gluten-free, low-fat, low-fibre crunch that is gentle on race-eve digestion

### S-012 · Applesauce pouch
- **Context:** carb-load, pre-session, race-week, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** unsweetened applesauce pouch 2 x 113g
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** applesauce→mashed banana pouch (same effect); one pouch only (lighter, 90 kcal)
- **Approx:** ~180 kcal · 44g C · 0g P · 0g F
- **Source:** named alongside pretzels and chocolate milk as stomach-friendly pre-race carbs, Marathon Handbook https://marathonhandbook.com/best-snacks-for-runners/
- **Why:** TSA-friendly, ultra-low-fibre carbs for travel days and race mornings when solid food feels risky

### S-013 · Dried mango
- **Context:** carb-load, pre-session, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** dried mango 50g
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** mango→dried apricots or raisins (cheaper, same carbs); add 20g roasted almonds (+fat, tree_nuts)
- **Approx:** ~170 kcal · 42g C · 1g P · 0g F
- **Source:** recommended for carry-on packing on race travel, Marathon Handbook https://marathonhandbook.com/best-snacks-for-runners/
- **Why:** dense, shelf-stable carbs that survive a flight or a jersey pocket without refrigeration

### S-014 · Medjool dates
- **Context:** everyday, pre-session, travel · **Cuisine:** middle-eastern · **Prep:** no-cook · **Batch:** no
- **Ingredients:** Medjool dates 4
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** stuff with almond butter 1 tbsp (+9g F, tree_nuts, Rich Roll style); stuff with a walnut half (tree_nuts)
- **Approx:** ~270 kcal · 72g C · 2g P · 0g F
- **Source:** Rich Roll and Scott Jurek both report dates as their go-to fast-carb snack (livekindly.com; sierraclub.org); dates are also the base of most endurance energy-bite recipes
- **Why:** nature's pre-wrapped gel — 18g of carbs per date, no prep, works in a glovebox or a jersey pocket

### S-015 · Soy latte with a banana
- **Context:** everyday, pre-session · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** soy milk 250ml, espresso 1 shot, banana 1
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** soy
- **Swaps:** soy milk→oat milk (soy-free, less protein); soy milk→dairy milk (dairy, +2g P)
- **Approx:** ~220 kcal · 40g C · 8g P · 4g F
- **Source:** commonly reported pre-session combo across vegan endurance-athlete routines (220triathlon.com vegan triathlete nutrition); caffeine + quick carb pattern
- **Why:** caffeine plus 40g of easy carbs an hour before a key session, dairy-free by default

### S-016 · Pretzels with hummus
- **Context:** everyday, pre-session · **Cuisine:** mediterranean · **Prep:** no-cook · **Batch:** no
- **Ingredients:** mini pretzels 40g, hummus 40g
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, sesame
- **Swaps:** pretzels→gluten-free pretzels (gluten-free); hummus→guacamole or white bean dip (sesame-free)
- **Approx:** ~250 kcal · 35g C · 7g P · 8g F
- **Source:** triplethreatlife.substack.com "Fuel for the Finish Line"; GF-pretzel version common in trimarni.blogspot.com guidance
- **Why:** salty carbs plus a bit of protein 1–2 h before an evening session — lives at a desk drawer easily

### S-017 · Cereal bowl with milk & banana
- **Context:** everyday, pre-session · **Cuisine:** american · **Prep:** no-cook · **Batch:** no
- **Ingredients:** whole-grain or oat cereal 60g, milk 200ml, banana 1/2
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** milk→oat or soy milk (vegan, dairy-free); cereal→certified GF cornflakes or rice cereal (gluten-free)
- **Approx:** ~320 kcal · 55g C · 12g P · 6g F
- **Source:** BCM on TrainerRoad forum "if I NEED more carbs" https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095/4; universal cheap athlete staple
- **Why:** the cheapest carb-plus-protein combo in the house — an honest top-up when training volume is up

### S-018 · Cornflakes with honey after a big ride
- **Context:** recovery · **Cuisine:** british · **Prep:** no-cook · **Batch:** no
- **Ingredients:** cornflakes 120g, milk 250ml, honey 1 tbsp
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** cornflakes→certified GF cornflakes (gluten-free — standard ones contain barley malt); milk→soy milk (dairy-free)
- **Approx:** ~600 kcal · 120g C · 16g P · 4g F
- **Source:** RCC on TrainerRoad "big days" thread https://www.trainerroad.com/forum/t/what-do-you-eat-on-your-big-days/87821/5 — eaten straight after a 1500–2000 kcal ride, dinner later as normal
- **Why:** unglamorous, immediate glycogen refill after a big session — real athletes reach for cereal, not a curated recovery bowl

### S-019 · PB&J sandwich, quartered
- **Context:** pre-session, recovery, travel · **Cuisine:** american · **Prep:** no-cook · **Batch:** yes
- **Ingredients:** white bread 2 slices, peanut butter 2 tbsp, jam 1 tbsp
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, peanuts
- **Swaps:** jam→banana + honey (camp-week version, not vegan); bread→gluten-free bread (gluten-free); peanut butter→sunflower seed butter (nut-free); pair with chocolate milk 350ml for post-session (+dairy, +16g P)
- **Approx:** ~350 kcal · 45g C · 10g P · 14g F
- **Source:** Active.com "Why Cyclists Should Forget the Rice Cake and Bring a Sandwich Instead" https://www.active.com/cycling/articles/why-cyclists-should-forget-the-rice-cake-and-bring-a-sandwich-instead; betterathleteclub.substack.com pairs it with chocolate milk post-race
- **Why:** cheap, familiar, easy to chew on a long ride — make 4 on Sunday and freeze; thaws in a jersey pocket

### S-020 · Ham & cheese roll, quartered
- **Context:** pre-session, recovery, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** yes
- **Ingredients:** small baguette or white roll 1, sliced ham 40g, cheese 20g, butter 1 tsp
- **Diets OK:** omnivore
- **Allergens:** dairy, gluten
- **Swaps:** ham→turkey breast (same); roll→gluten-free roll (gluten-free); ham + cheese→hummus + roasted veg (vegan, sesame); add an apple post-session (+25g C)
- **Approx:** ~320 kcal · 35g C · 15g P · 11g F
- **Source:** "filled paninis" as classic musette contents, Cyclist.co.uk https://www.cyclist.co.uk/in-depth/best-food-for-cycling-how-to-eat-like-a-pro; the turkey-sandwich-plus-fruit version is the club-athlete post-race bag staple
- **Why:** savoury real food for when sweetness fatigue hits on a long stage, and a carb-plus-protein recovery bite straight out of the bag

### S-021 · Rice cakes with peanut butter & banana
- **Context:** everyday, pre-session · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** plain rice cakes 2, peanut butter 1.5 tbsp, banana 1/2
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** peanuts
- **Swaps:** peanut butter→sunflower seed butter (allergen-free); add honey drizzle (+15g C, not vegan)
- **Approx:** ~270 kcal · 38g C · 7g P · 10g F
- **Source:** Skratch Labs rice-cake guide https://www.skratchlabs.com/blogs/blog/the-ultimate-rice-cake-guide; repeated across r/cycling long-ride threads and GF-athlete guidance (runtothefinish.com)
- **Why:** the gluten-free take on banana-and-PB, low-fibre enough for 1–2 h before an evening session

### S-022 · Allen Lim's savoury rice cakes
- **Context:** everyday, pre-session, race-week, travel · **Cuisine:** american · **Prep:** batch — 30 min, 8 servings · **Batch:** yes
- **Ingredients:** cooked sushi rice 90g, egg 1/2 scrambled, grated parmesan 1 tbsp, salt pinch, olive oil 1 tsp (makes 8)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs
- **Swaps:** add chopped bacon 20g per cake (original Feed Zone version, omnivore); parmesan→nutritional yeast (dairy-free); cheese + egg→jamón serrano + a maple drizzle (Sarah Groff's version)
- **Approx:** ~200 kcal · 32g C · 7g P · 5g F
- **Source:** Allen Lim & Biju Thomas, The Feed Zone Cookbook / Feed Zone Portables https://feedzonecookbook.com/; Velo walkthrough https://velo.outsideonline.com/road/road-training/learn-to-make-allen-lims-famous-rice-cakes/; Sarah Groff's adaptation, ESPNW
- **Why:** the canonical pro-peloton real food instead of gels — sticky rice transports and digests well mid-ride

### S-023 · Cinnamon apple rice cakes
- **Context:** everyday, pre-session, travel · **Cuisine:** american · **Prep:** batch — 30 min, 8 servings · **Batch:** yes
- **Ingredients:** cooked sushi rice 90g, grated apple 1/4, cinnamon pinch, brown sugar 1 tsp, egg 1/4 as binder (makes 8)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs
- **Swaps:** egg→flax egg (vegan); apple→mashed sweet potato 40g (the sweet-potato rice-bite variant)
- **Approx:** ~220 kcal · 42g C · 5g P · 2g F
- **Source:** Allen Lim & Biju Thomas, Feed Zone Portables, excerpted on Triathlete.com https://www.triathlete.com/nutrition/recipes/feed-zone-portables-cinnamon-apple-rice-cakes/
- **Why:** the sweet version of the peloton rice cake — nearly fat-free carbs that sit fine at threshold

### S-024 · Denver rice cakes
- **Context:** everyday, pre-session · **Cuisine:** american · **Prep:** batch — 30 min, 8 servings · **Batch:** yes
- **Ingredients:** cooked sushi rice 90g, diced ham 25g, bell pepper 15g, onion 10g, egg 1/2, cheddar 15g (makes 8)
- **Diets OK:** omnivore
- **Allergens:** dairy, eggs
- **Swaps:** ham→sautéed mushrooms (vegetarian); cheddar→dairy-free cheese (dairy-free); ham + pepper→spinach + roasted red pepper + jack cheese (Feed Zone's other savoury variant)
- **Approx:** ~260 kcal · 30g C · 12g P · 9g F
- **Source:** Allen Lim & Biju Thomas, Feed Zone Portables, excerpted on Triathlete.com https://www.triathlete.com/nutrition/recipes/feed-zone-portables-denver-rice-cake/
- **Why:** the savoury omelette-in-a-rice-cake for riders who cannot face another sugary snack mid-ride

### S-025 · Maple rice cakes, EF Pro Cycling style
- **Context:** everyday, pre-session · **Cuisine:** american · **Prep:** batch — 30 min, 8 servings · **Batch:** yes
- **Ingredients:** cooked white rice 90g, maple syrup 1 tbsp, egg 1/4 as binder, salt pinch, chopped dark chocolate 10g (makes 8)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs
- **Swaps:** egg→flax egg (vegan); chocolate + maple→blueberries 50g + honey (Team Sky / Chris Froome version via Vélochef)
- **Approx:** ~230 kcal · 42g C · 5g P · 3g F
- **Source:** EF Pro Cycling team recipe https://www.efprocycling.com/tips-recipes/team-recipe-on-the-bike-rice-cakes/; Team Sky blueberry version via Henrik Orre reported at https://www.welovecycling.com/wide/2017/08/17/famous-cyclists-recipes-rice-cakes/
- **Why:** directly attributed WorldTour team recipe — Froome called rice cakes his "secret weapon" because high-GI white rice is gentle mid-ride

### S-026 · Team Sky in-ride rice bar
- **Context:** pre-session, travel · **Cuisine:** british · **Prep:** batch — 30 min, 20 servings · **Batch:** yes
- **Ingredients:** cooked risotto rice 60g, coconut oil 1 tsp, coconut palm sugar 1 tbsp, cream cheese 1 tsp, agave syrup 1 tsp, cinnamon (makes 20)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** cream cheese→dairy-free cream cheese (vegan, dairy-free); palm sugar→brown sugar (same)
- **Approx:** ~120 kcal · 25g C · 2g P · 2g F
- **Source:** Henrik Orre, Team Sky chef, Vélochef — https://www.cyclist.co.uk/in-depth/865/team-sky-recipes-for-cycling-success
- **Why:** ~25g carbs per bar matches per-bite fuelling guidance — the WorldTour's real in-race carb source, egg-free

### S-027 · Coconut rice cakes
- **Context:** everyday, pre-session, travel · **Cuisine:** general · **Prep:** batch — 40 min, 8 servings · **Batch:** yes
- **Ingredients:** pudding rice 100g, coconut milk 200ml, brown sugar 2 tbsp, cinnamon — baked and cut into squares (makes 8)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** brown sugar→maple syrup (same); add raisins 30g (+20g C)
- **Approx:** ~220 kcal · 40g C · 3g P · 6g F
- **Source:** reported pro-cyclist on-bike snack, Cyclist.co.uk https://www.cyclist.co.uk/in-depth/best-food-for-cycling-how-to-eat-like-a-pro
- **Why:** the egg-free, dairy-free, nut-free rice cake — free of all nine allergens and still the pro-peloton format

### S-028 · Hannah Grant's race cakes with cherries
- **Context:** pre-session, race-week · **Cuisine:** nordic · **Prep:** batch — 40 min, 12 servings · **Batch:** yes
- **Ingredients:** baked sweet potato 25g, egg 1/3, oats 5g, almond flour 1 tsp, dates 1/2, honey 1/2 tsp, melted butter 6g, cherries 5g, cardamom, lemon zest, baking soda (makes 12)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten, tree_nuts
- **Swaps:** oats→certified GF oats (gluten-free); butter→coconut oil (dairy-free); almond flour→oat flour (nut-free)
- **Approx:** ~180 kcal · 25g C · 5g P · 7g F
- **Source:** Hannah Grant, Grand Tour team chef, via BikeRadar https://www.bikeradar.com/advice/nutrition/tour-de-france-recipes
- **Why:** a team chef's sweet-potato answer to Allen Lim's rice cakes — a weekend bake that fuels a week of long rides

### S-029 · Sticky bites (peanut butter oat balls)
- **Context:** everyday, pre-session, travel · **Cuisine:** american · **Prep:** batch — 15 min, 4–5 servings · **Batch:** yes
- **Ingredients:** rolled oats 25g, peanut butter 2 tbsp, honey 1 tbsp, ground flax 1 tsp, dried fruit 1 tbsp (makes 4 x 2 balls)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** gluten, peanuts
- **Swaps:** peanut butter→sunflower seed butter (nut-free); oats→certified GF oats (gluten-free); honey→maple syrup (vegan)
- **Approx:** ~300 kcal · 36g C · 10g P · 14g F
- **Source:** Feed Zone Portables "sticky bites" chapter, Allen Lim & Biju Thomas https://www.skratchlabs.com/products/feed-zone-portables; same no-bake template on r/EatCheapAndHealthy athlete threads
- **Why:** no-cook, five ingredients, a week of pocket fuel for under a fiver

### S-030 · Plantpower date & almond energy bars
- **Context:** pre-session, travel · **Cuisine:** american · **Prep:** batch — 15 min, 8 servings · **Batch:** yes
- **Ingredients:** pitted dates 40g, rolled oats 20g, almonds 12g, chia seeds 1 tsp, cocoa powder 1 tsp, sea salt (makes 8)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, tree_nuts
- **Swaps:** almonds→pumpkin seeds (nut-free); oats→certified GF oats (gluten-free)
- **Approx:** ~180 kcal · 28g C · 4g P · 7g F
- **Source:** Rich Roll & Julie Piatt, The Plantpower Way — the book's energy bars https://richroll.com/books/the-plantpower-way-signed/; same template at https://www.eatingbirdfood.com/date-energy-balls/
- **Why:** what an ultra-distance vegan athlete actually carries on long training days — press, chill, cut

### S-031 · Salted peanut protein energy bites
- **Context:** everyday, pre-session, recovery · **Cuisine:** american · **Prep:** batch — 15 min, 9 servings · **Batch:** yes
- **Ingredients:** Medjool dates 2, dry-roasted peanuts 1 tbsp, salted cashews 1 tbsp, unflavoured whey 1 tbsp, powdered peanut butter 1 tbsp, vanilla (makes 9 x 2 bites)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, peanuts, tree_nuts
- **Swaps:** whey→pea protein (vegan, dairy-free); peanuts + cashews→sunflower seeds + pepitas (nut-free)
- **Approx:** ~220 kcal · 32g C · 10g P · 8g F
- **Source:** Meghann Featherstun RD, Featherstone Nutrition https://www.featherstonenutrition.com/salted-peanut-protein-energy-bites/
- **Why:** a running dietitian's answer to store-bought protein bars — freezer-stable, salty, and actually has protein

### S-032 · Pumpkin seed & date energy bites (nut-free)
- **Context:** pre-session, race-week, travel · **Cuisine:** general · **Prep:** batch — 15 min, 6 servings · **Batch:** yes
- **Ingredients:** pitted dates 40g, pumpkin seeds 20g, sunflower seeds 10g, cocoa powder 1 tsp, salt pinch (makes 6 x 2 bites)
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add puffed rice 10g (lighter texture); add dried apricots 20g (more carbs); cocoa→cinnamon (same)
- **Approx:** ~230 kcal · 30g C · 6g P · 10g F
- **Source:** nut-free date-ball template from gononuts.com and The Dizzy Cook, cross-referenced with smnutritionrd.com "Allergy Friendly Snacks for Athletes"; commonly reported
- **Why:** free of all nine allergens and paleo as written — the energy bite for a team or household with nut allergies

### S-033 · Oat flapjack
- **Context:** everyday, pre-session, travel · **Cuisine:** british · **Prep:** batch — 30 min, 12 servings · **Batch:** yes
- **Ingredients:** rolled oats 35g, butter 15g, golden syrup 15g, brown sugar 8g (makes 12)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** butter→coconut oil (vegan, dairy-free); oats→certified GF oats (gluten-free); add raisins 10g per bar (+8g C)
- **Approx:** ~220 kcal · 30g C · 3g P · 9g F
- **Source:** "flapjacks" named as classic musette real food alongside rice cakes, Cyclist.co.uk https://www.cyclist.co.uk/in-depth/best-food-for-cycling-how-to-eat-like-a-pro
- **Why:** the British cycling-club staple — four ingredients, a tray, and a week of dense jersey-pocket carbs

### S-034 · Date & hazelnut brownie squares
- **Context:** everyday, pre-session, rest-day · **Cuisine:** mediterranean · **Prep:** batch — 15 min, 12 servings · **Batch:** yes
- **Ingredients:** dates 35g, hazelnuts 17g, cocoa powder 1 tsp, orange juice splash, salt pinch — blended and pressed (makes 12)
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** tree_nuts
- **Swaps:** hazelnuts→sunflower seeds (nut-free); hazelnuts→walnuts (same)
- **Approx:** ~180 kcal · 24g C · 3g P · 8g F
- **Source:** reported pro-cyclist snack, Cyclist.co.uk https://www.cyclist.co.uk/in-depth/best-food-for-cycling-how-to-eat-like-a-pro; same idea as Featherstone Nutrition's no-bake recovery brownies
- **Why:** a whole-food sweet fix instead of a wrapped bar — no oven, no oats, two main ingredients

### S-035 · Carrot cake energy balls
- **Context:** everyday, pre-session, travel · **Cuisine:** american · **Prep:** batch — 15 min, 6 servings · **Batch:** yes
- **Ingredients:** grated carrot 2 tbsp, dates 2, walnuts 2 tbsp, shredded coconut 1 tbsp, cinnamon — blended and rolled (makes 6 x 2 balls)
- **Diets OK:** omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** tree_nuts
- **Swaps:** walnuts→sunflower seeds (nut-free); coconut→extra dates (more carbs)
- **Approx:** ~300 kcal · 30g C · 5g P · 12g F
- **Source:** "No-Bake Carrot Cake Energy Balls", The Paleo Diet athlete recipes https://thepaleodiet.com/recipes/paleo-recipes-for-athletes/
- **Why:** a grain-free pre-session ball that still delivers real carbs from dates — the paleo athlete's energy bar

### S-036 · Homemade fig bars
- **Context:** everyday, pre-session, travel · **Cuisine:** american · **Prep:** batch — 30 min, 8 servings · **Batch:** yes
- **Ingredients:** dried figs 20g, whole-wheat flour 12g, honey 1 tsp, water (makes 8)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** gluten
- **Swaps:** flour→gluten-free flour blend (gluten-free); honey→maple syrup (vegan); buy a box of fig bars (same use, check label for gluten)
- **Approx:** ~150 kcal · 30g C · 3g P · 2g F
- **Source:** fig bars as a long-standing cycling snack in Cyclist.co.uk "eat like a pro" https://www.cyclist.co.uk/in-depth/best-food-for-cycling-how-to-eat-like-a-pro; fig bars pre-workout via batwood14 on TrainerRoad https://www.trainerroad.com/forum/t/your-favorite-snacks/7464/6
- **Why:** low-fat, naturally sweetened, sits well before a session — the real-food version of the bar everyone already buys

### S-037 · Single superhero muffin (snack portion)
- **Context:** pre-session, recovery, travel · **Cuisine:** american · **Prep:** batch — 40 min, 12 servings · **Batch:** yes
- **Ingredients:** almond flour 20g, rolled oats 10g, grated carrot 2 tbsp, egg 1/4, melted butter 8g, maple syrup 2 tsp, raisins 1 tsp, cinnamon, baking soda (makes 12)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten, tree_nuts
- **Swaps:** butter→coconut oil (dairy-free); oats→certified GF oats (gluten-free); almond flour→sunflower-seed meal (nut-free)
- **Approx:** ~250 kcal · 24g C · 7g P · 15g F
- **Source:** Shalane Flanagan & Elyse Kopecky, Run Fast. Eat Slow. — reprinted at https://www.dinneralovestory.com/shalane-flanagans-superhero-muffins/ and https://run.outsideonline.com/nutrition-and-health/recipes/shalane-flanagans-superhero-muffin-recipe/
- **Why:** the most-cited recipe in the running-cookbook genre — hidden-veg muffins that freeze and travel

### S-038 · Nancy Clark's peanut butter chocolate chip muffins
- **Context:** everyday, pre-session · **Cuisine:** american · **Prep:** batch — 30 min, 12 servings · **Batch:** yes
- **Ingredients:** whole-wheat flour 15g, peanut butter 1 tbsp, mashed banana 1/12, egg 1/6, honey 1 tsp, dark chocolate chips 1 tsp, baking soda (makes 12)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs, gluten, peanuts
- **Swaps:** peanut butter→sunflower seed butter (peanut-free); flour→GF blend (gluten-free); egg→flax egg (egg-free)
- **Approx:** ~260 kcal · 32g C · 7g P · 11g F
- **Source:** Nancy Clark's Sports Nutrition Guidebook https://us.humankinetics.com/products/nancy-clarks-sports-nutrition-guidebook-6th-edition
- **Why:** the sports-dietitian standard portable carb-plus-protein muffin — bake once, freeze, grab

### S-039 · Egg-free pumpkin spice muffins
- **Context:** everyday, race-week, travel · **Cuisine:** american · **Prep:** batch — 30 min, 12 servings · **Batch:** yes
- **Ingredients:** certified GF oat flour or GF flour 17g, pumpkin purée 20g, flax egg 1/6, maple syrup 8g, oat milk 1 tsp, baking soda, pumpkin spice (makes 12)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** pumpkin→mashed sweet potato (same); add dried cranberries 1 tsp (+5g C)
- **Approx:** ~180 kcal · 30g C · 4g P · 5g F
- **Source:** standard flax-egg technique from egg-allergy baking blogs; pumpkin-muffin format from runtothefinish.com GF runner meal plan; commonly reported
- **Why:** free of all nine allergens as written — the muffin a whole club can share

### S-040 · Chocolate chip oat cookies
- **Context:** everyday, pre-session · **Cuisine:** american · **Prep:** batch — 30 min, 6 servings · **Batch:** yes
- **Ingredients:** rolled oats 60g, whole-wheat flour 40g, coconut oil 2 tbsp, maple syrup 2 tbsp, dark chocolate chips 30g (makes 12; 2 per serving)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** flour→oat flour from certified GF oats (gluten-free); coconut oil→butter (dairy)
- **Approx:** ~260 kcal · 38g C · 4g P · 10g F
- **Source:** reported snack of pro triathlete Tamara Jewett, triathlonmagazine.ca "What vegetarian pro triathlete Tamara Jewett eats in a day"
- **Why:** a pro's actual batch-bake — a cookie is fine pre-session when it is mostly oats and sugar

### S-041 · Paleo chocolate chip cookies
- **Context:** everyday, recovery, rest-day · **Cuisine:** american · **Prep:** batch — 25 min, 6 servings · **Batch:** yes
- **Ingredients:** almond flour 17g, coconut oil 5g, honey 7g, dark chocolate chips 7g, egg 1/12 (makes 12; 2 per serving)
- **Diets OK:** omnivore, paleo, pescatarian, vegetarian
- **Allergens:** eggs, tree_nuts
- **Swaps:** almond flour→sunflower seed flour (nut-free); honey→maple syrup (same)
- **Approx:** ~300 kcal · 28g C · 6g P · 18g F
- **Source:** Amanda Brooks, RunToTheFinish gluten-free meal plan for runners ("Paleo Chocolate Chip Cookies") https://www.runtothefinish.com/
- **Why:** the GF/DF post-long-run treat — grain-free, so a paleo athlete still gets a cookie

### S-042 · Sweet potato & black bean hand pies
- **Context:** pre-session, recovery, travel · **Cuisine:** mexican · **Prep:** batch — 45 min, 8 servings · **Batch:** yes
- **Ingredients:** whole-wheat pie dough 50g, mashed sweet potato 60g, black beans 30g, cumin, salt (makes 8)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** dough→gluten-free pastry (gluten-free); black beans→shredded chicken (omnivore, +8g P)
- **Approx:** ~220 kcal · 35g C · 6g P · 6g F
- **Source:** Feed Zone Cookbook "two-bite pies" chapter, Allen Lim & Biju Thomas https://feedzonecookbook.com/
- **Why:** a savoury pocket pie in the Feed Zone tradition — bake, freeze, and thaw in a jersey pocket

### S-043 · Salted boiled potatoes
- **Context:** everyday, pre-session, race-week · **Cuisine:** american · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** baby potatoes 300g boiled, salt 1/2 tsp, olive oil 1 tsp
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** mash with butter 1 tbsp and bag it (drop-bag pouch, dairy); olive oil→omit (fat-free)
- **Approx:** ~250 kcal · 50g C · 6g P · 4g F
- **Source:** ultramarathoner Tara Dower's potato habit, Washington Post https://www.washingtonpost.com/food/2025/05/06/potatoes-endurance-athletes-nutrition-ultramarathoners/
- **Why:** gentle-on-the-gut carbs plus sodium, free of every allergen — the ultrarunner's gel alternative

### S-044 · Baked sweet potato with cinnamon
- **Context:** everyday, recovery, rest-day · **Cuisine:** american · **Prep:** batch — 45 min, 4–5 servings · **Batch:** yes
- **Ingredients:** sweet potato 1 medium, cinnamon 1/2 tsp, coconut oil 1 tsp
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** coconut oil→butter (dairy); add cottage cheese 100g (+12g P, dairy)
- **Approx:** ~180 kcal · 38g C · 3g P · 3g F
- **Source:** Primal Endurance's sweet-potato "add carbs back" guidance https://www.marksdailyapple.com/7-habits-of-highly-successful-primal-endurance-athletes/; recurs across rest-day nutrition guides
- **Why:** fibre and micronutrients on an easy day — bake a tray Sunday, reheat one when hungry

### S-045 · Roasted chickpeas with paprika
- **Context:** everyday, rest-day, travel · **Cuisine:** mediterranean · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** cooked chickpeas 150g, olive oil 1 tsp, smoked paprika 1/2 tsp, salt
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add roasted edamame 60g (+10g P, soy); paprika→cumin and chilli (same)
- **Approx:** ~200 kcal · 27g C · 9g P · 6g F
- **Source:** willball12 on TrainerRoad https://www.trainerroad.com/forum/t/your-favorite-snacks/7464/5 — built into a snack rotation while managing weight; smnutritionrd.com allergy-friendly list
- **Why:** crunchy, salty, fibre and protein — the rest-day answer to a bag of crisps

### S-046 · Veg sticks with hummus
- **Context:** everyday, rest-day · **Cuisine:** middle-eastern · **Prep:** no-cook · **Batch:** no
- **Ingredients:** carrot and cucumber sticks 150g, hummus 60g
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** sesame
- **Swaps:** add popcorn 30g + dark chocolate 20g (Tamara Jewett's snack plate, +25g C); hummus→white bean dip (sesame-free)
- **Approx:** ~180 kcal · 20g C · 6g P · 8g F
- **Source:** Tamara Jewett's mid-morning snack, triathlonmagazine.ca; also kenoll and eddie on TrainerRoad https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095/5 and ROUVY https://rouvy.com/blog/snack-for-triathlon
- **Why:** the classic rest-day snack — more veg and fibre than a training-day snack, which is exactly the point

### S-047 · Hummus, pita & apple
- **Context:** everyday, pre-session, travel · **Cuisine:** middle-eastern · **Prep:** no-cook · **Batch:** no
- **Ingredients:** hummus 60g, whole-wheat pita 1, apple 1
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, sesame
- **Swaps:** pita→gluten-free pita or rice crackers (gluten-free); apple→carrot and cucumber sticks (rest-day, fewer carbs)
- **Approx:** ~300 kcal · 50g C · 9g P · 9g F
- **Source:** Fuelin coaching sample snack https://fuelin.com/articles/race-ready-your-nutrition-playbook-for-endurance-success
- **Why:** balanced between-meal plate from a coaching RD rotation — travels in a lunchbox without a fridge

### S-048 · Hummus & roasted sweet potato wrap
- **Context:** everyday, recovery · **Cuisine:** mediterranean · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** small tortilla 1, hummus 40g, roasted sweet potato 100g, spinach handful
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, sesame
- **Swaps:** tortilla→corn tortilla (gluten-free); hummus→white bean dip (sesame-free); add feta 20g (dairy, +4g P)
- **Approx:** ~330 kcal · 50g C · 9g P · 10g F
- **Source:** cited as a 3:1 carb:protein recovery option, ROUVY https://rouvy.com/blog/snack-for-triathlon
- **Why:** a plant-based recovery snack that hits the carb:protein ratio — roast the sweet potato once, assemble all week

### S-049 · Scott Jurek's guacamole with corn chips
- **Context:** everyday, recovery, rest-day · **Cuisine:** mexican · **Prep:** 15 min · **Batch:** no
- **Ingredients:** avocado 1, lime juice, tomato 1/2, red onion 1 tbsp, coriander, jalapeño, salt, corn tortilla chips 30g
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** chips→veg sticks (paleo, keto); add black beans 60g (+6g P)
- **Approx:** ~330 kcal · 30g C · 5g P · 22g F
- **Source:** Scott Jurek & Steve Friedman, Eat & Run — "Holy Moly Guacamole" http://www.scottjurek.com/eat-run
- **Why:** the ultrarunner's fat-and-salt snack — real food, free of all nine allergens, and a weekend one worth the chopping

### S-050 · Black bean nachos with avocado
- **Context:** everyday, recovery · **Cuisine:** mexican · **Prep:** 15 min · **Batch:** no
- **Ingredients:** corn tortilla chips 60g, black beans 100g, salsa 3 tbsp, avocado 1/2, dairy-free cheese 30g
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** dairy-free cheese→cheddar (dairy); add shredded chicken 60g (omnivore, +15g P)
- **Approx:** ~420 kcal · 50g C · 12g P · 18g F
- **Source:** Amanda Brooks, RunToTheFinish gluten-free meal plan for runners ("Loaded Gluten Free Nachos") https://www.runtothefinish.com/
- **Why:** a post-run refuel that feels like a treat — corn chips are naturally gluten-free and beans add the protein

### S-051 · Edamame with sea salt
- **Context:** everyday, recovery, rest-day, travel · **Cuisine:** japanese · **Prep:** 5 min · **Batch:** yes
- **Ingredients:** frozen edamame in pod 150g, sea salt, lime wedge
- **Diets OK:** keto, low_carb, mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** soy
- **Swaps:** edamame→steamed peas (soy-free, less protein); add chilli flakes (same)
- **Approx:** ~150 kcal · 12g C · 13g P · 6g F
- **Source:** standard plant-based athlete protein snack across 220triathlon.com vegan nutrition guides and dietitianapproved.com; commonly reported
- **Why:** 13g of plant protein for 150 kcal — a rest-day snack that eats like a portion of veg

### S-052 · Bento box: rice, boiled egg, edamame & cucumber
- **Context:** everyday, travel · **Cuisine:** japanese · **Prep:** batch — 20 min, 4–5 servings · **Batch:** yes
- **Ingredients:** cooked rice 100g, boiled egg 1, edamame 50g, cucumber sticks 50g, tamari drizzle
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs, soy
- **Swaps:** egg→tofu 60g (vegan); tamari→salt (soy remains via edamame)
- **Approx:** ~280 kcal · 40g C · 14g P · 6g F
- **Source:** commonly reported desk and travel snack format among endurance athletes in packed-lunch guides and community threads
- **Why:** portion-controlled, protein-forward, needs no reheating — prep components Sunday, box one each morning

### S-053 · Vegetable kimbap
- **Context:** everyday, pre-session, travel · **Cuisine:** korean · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** cooked white rice 200g seasoned with sesame oil, nori 2 sheets, carrot, spinach, pickled radish, egg strip 1
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** eggs, sesame
- **Swaps:** omit egg (vegan); add tinned tuna (pescatarian, fish, +15g P)
- **Approx:** ~400 kcal · 70g C · 12g P · 8g F
- **Source:** Korean everyday portable food, commonly reported as a race-day travel snack among Korean runners and triathletes
- **Why:** a genuinely portable, no-reheat rice snack — 70g of carbs that eats like lunch on a travel day

### S-054 · Millet porridge, Kaptagat 5pm style
- **Context:** everyday, pre-session, recovery · **Cuisine:** kenyan · **Prep:** 5 min · **Batch:** no
- **Ingredients:** millet flour 40g, water 300ml, sugar 1 tbsp
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add a splash of milk (dairy); millet→uji maize meal (same)
- **Approx:** ~180 kcal · 35g C · 4g P · 2g F
- **Source:** reported 5pm porridge at Eliud Kipchoge's Kaptagat training camp — Sweat Elite https://articles.sweatelite.co/eliud-kipchoge-diet/
- **Why:** the Kenyan camp's between-session top-up — light, gluten-free carbs before an evening run

### S-055 · Fermented milk (mursik or kefir)
- **Context:** everyday, recovery, rest-day · **Cuisine:** kenyan · **Prep:** no-cook · **Batch:** no
- **Ingredients:** mursik or plain kefir 250ml
- **Diets OK:** low_carb, omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** kefir→water kefir or soy kefir (dairy-free, less protein); add banana (+27g C)
- **Approx:** ~180 kcal · 12g C · 9g P · 9g F
- **Source:** reported Kalenjin staple among Kenyan runners — traininkenya.com, kenyanathlete.com; kefir is the supermarket equivalent
- **Why:** a probiotic protein glass the Rift Valley drinks daily — nothing to cook, easy on a rest day

### S-056 · Mandazi & banana
- **Context:** everyday, pre-session · **Cuisine:** kenyan · **Prep:** batch — 30 min, 4–5 servings · **Batch:** yes
- **Ingredients:** mandazi 2 pieces, banana 1
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** mandazi→chapati (same); mandazi→gluten-free doughnut (gluten-free)
- **Approx:** ~350 kcal · 55g C · 6g P · 12g F
- **Source:** reported carb alongside chapati and sweet potato in Kenyan camps — RunnersConnect https://runnersconnect.net/diet-of-kenyan-runners/
- **Why:** fried dough and a banana — the simple high-glycaemic pre-session carb that Kenyan runners actually eat

### S-057 · Agua de panela with lime
- **Context:** pre-session, recovery · **Cuisine:** colombian · **Prep:** 5 min · **Batch:** no
- **Ingredients:** panela 30g dissolved in water 500ml, lime juice 1 tbsp, salt pinch
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** panela→brown sugar or honey (same, honey not vegan); serve hot with a slice of cheese (Colombian tradition, dairy)
- **Approx:** ~120 kcal · 30g C · 0g P · 0g F
- **Source:** traditional Colombian endurance drink used by Colombian cyclists long before commercial products, cited in Colombian cycling-culture nutrition features
- **Why:** a homemade 6% carb drink with a pinch of salt — the escarabajos' sports drink

### S-058 · Açaí bowl with granola & banana
- **Context:** everyday, recovery · **Cuisine:** brazilian · **Prep:** 5 min · **Batch:** no
- **Ingredients:** frozen açaí purée 150g, banana 1, granola 40g, agave 1 tsp
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, tree_nuts
- **Swaps:** granola→certified GF nut-free granola (gluten-free, nut-free); add Greek yogurt 100g (+10g P, dairy)
- **Approx:** ~450 kcal · 85g C · 6g P · 8g F
- **Source:** the Brazilian post-surf and post-training original, widely reported among Brazilian endurance athletes before the global bowl trend
- **Why:** 85g of carbs in a bowl you actually want after a hot session — add yogurt to make it a full recovery snack

### S-059 · Coconut rice pudding with mango
- **Context:** everyday, race-week, recovery · **Cuisine:** thai · **Prep:** batch — 20 min, 3 servings · **Batch:** yes
- **Ingredients:** cooked white rice 150g, coconut milk 200ml, maple syrup 1 tbsp, diced mango 100g, cardamom (makes 3)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** mango→banana (cheaper); coconut milk→dairy milk (dairy, less fat)
- **Approx:** ~340 kcal · 60g C · 4g P · 10g F
- **Source:** standard dairy-free rice pudding format, cross-referenced in allergen-free snack roundups; commonly reported
- **Why:** a sweet, low-residue race-week or recovery carb pot that is free of all nine allergens

### S-060 · Fig, prosciutto & rocket flatbread
- **Context:** everyday, rest-day · **Cuisine:** italian · **Prep:** 15 min · **Batch:** no
- **Ingredients:** whole-grain flatbread 1, prosciutto 40g, fresh figs 2, rocket handful, balsamic drizzle
- **Diets OK:** mediterranean, omnivore
- **Allergens:** gluten
- **Swaps:** flatbread→gluten-free flatbread (gluten-free); prosciutto→mozzarella 40g (vegetarian, dairy)
- **Approx:** ~360 kcal · 40g C · 16g P · 14g F
- **Source:** commonly reported Italian athlete-rotation snack in Mediterranean-diet-for-athletes overviews
- **Why:** the Mediterranean sweet-savoury snack — a weekend one, but five ingredients and no cooking

### S-061 · Cucumber, tomato & feta cups
- **Context:** rest-day · **Cuisine:** greek · **Prep:** 5 min · **Batch:** no
- **Ingredients:** cucumber 100g, cherry tomatoes 100g, feta 30g, olive oil 1 tsp, oregano
- **Diets OK:** keto, low_carb, mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** feta→olives 30g (vegan); add chickpeas 60g (+8g P, more carbs)
- **Approx:** ~140 kcal · 8g C · 5g P · 10g F
- **Source:** rest-day Mediterranean snack pattern in sports-dietitian easy-day guidance (Nancy Clark style); commonly reported
- **Why:** veg-first and low-carb on purpose — the rest-day snack that fills the fibre gap

### S-062 · Second breakfast: rice porridge with skyr, honey & berries
- **Context:** everyday, pre-session, recovery · **Cuisine:** nordic · **Prep:** batch — 20 min, 4–5 servings · **Batch:** yes
- **Ingredients:** cooked white rice 150g, milk 100ml, skyr 150g, honey 2 tbsp, mixed berries 80g
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** milk + skyr→oat milk + soy yogurt (vegan, dairy-free); honey→jam (same carbs)
- **Approx:** ~500 kcal · 75g C · 25g P · 8g F
- **Source:** the "second breakfast" pattern reported as core to the Norwegian training group (Blummenfelt/Iden) and Norwegian XC-ski culture — frequent small high-carb-plus-protein sittings; commonly reported
- **Why:** on a two-session morning, a second sitting after the first workout beats one huge GI-unfriendly breakfast

### S-063 · Second breakfast: eggs, avocado & toast
- **Context:** everyday, recovery · **Cuisine:** american · **Prep:** 15 min · **Batch:** no
- **Ingredients:** whole-grain toast 2 slices, avocado 1/2, poached or boiled eggs 2, chilli flakes
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** eggs, gluten
- **Swaps:** toast→gluten-free bread (gluten-free); add cheese 20g (Jorgensen's version, dairy); one egg + one slice (lighter, 250 kcal)
- **Approx:** ~430 kcal · 35g C · 20g P · 22g F
- **Source:** attributed to Gwen Jorgensen's training "power breakfast", ESPNW https://www.espn.com/espnw/athletes-life/article/12826161/gwen-jorgensen-triathlon-training-power-breakfast
- **Why:** the post-morning-session refuel before the workday — real protein and fat when a bar will not cut it

### S-064 · Hard-boiled eggs with salt
- **Context:** everyday, recovery, rest-day, travel · **Cuisine:** general · **Prep:** batch — 15 min, 4–5 servings · **Batch:** yes
- **Ingredients:** eggs 2, salt
- **Diets OK:** keto, low_carb, mediterranean, omnivore, paleo, pescatarian, vegetarian
- **Allergens:** eggs
- **Swaps:** add rice cakes 2 (+24g C, still nut-free and dairy-free); add an apple (+25g C)
- **Approx:** ~140 kcal · 1g C · 12g P · 10g F
- **Source:** ROUVY ideal triathlete snacks https://rouvy.com/blog/snack-for-triathlon; batwood14 on TrainerRoad calls them an underrated post-workout snack https://www.trainerroad.com/forum/t/your-favorite-snacks/7464/6
- **Why:** boil a dozen on Sunday — portable protein for a desk, a car or a rest day with no cooler needed for hours

### S-065 · Eggs, aged cheese & grapes
- **Context:** pre-session, rest-day · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** hard-boiled eggs 2, aged cheddar or Swiss 30g, grapes 80g
- **Diets OK:** low_carb, mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs
- **Swaps:** omit cheese (dairy-free); grapes→rice cakes 2 (low-FODMAP swap with more carbs)
- **Approx:** ~290 kcal · 18g C · 18g P · 15g F
- **Source:** Kate Scarlata RDN low-FODMAP athlete pre-exercise recommendations — "hard boiled egg, low-lactose cheese... 1–2 hours before"
- **Why:** a low-FODMAP dietitian's pre-session plate — aged cheese is nearly lactose-free, grapes are the safe fruit

### S-066 · Baked scotch eggs
- **Context:** pre-session, rest-day, travel · **Cuisine:** british · **Prep:** batch — 40 min, 4 servings · **Batch:** yes
- **Ingredients:** hard-boiled egg 1, sausage meat 75g, almond flour 1 tbsp — wrapped and baked (makes 4)
- **Diets OK:** keto, low_carb, omnivore, paleo
- **Allergens:** eggs, tree_nuts
- **Swaps:** almond flour→coconut flour (nut-free); sausage→turkey mince (leaner, -8g F)
- **Approx:** ~330 kcal · 3g C · 22g P · 26g F
- **Source:** "Baked Scotch Eggs", The Paleo Diet athlete recipes https://thepaleodiet.com/recipes/paleo-recipes-for-athletes/
- **Why:** a named paleo travel snack — protein and fat that keeps for days and needs no reheating

### S-067 · Cheese stick & apple
- **Context:** everyday, rest-day, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** string cheese 1 stick, apple 1
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** cheese→vegan cheese stick (vegan, dairy-free); apple + cheese→grapes 100g + cheddar 30g + crackers 4 (pre-evening top-up, gluten)
- **Approx:** ~180 kcal · 25g C · 8g P · 7g F
- **Source:** "cheese sticks" among ideal triathlete snacks, ROUVY https://rouvy.com/blog/snack-for-triathlon
- **Why:** no-fuss desk or bag snack — quick carbs with protein and fat, needs no fridge for a workday

### S-068 · Turkey & cheese roll-ups
- **Context:** everyday, rest-day · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** sliced turkey breast 100g, sliced cheese 40g, mustard
- **Diets OK:** keto, low_carb, mediterranean, omnivore
- **Allergens:** dairy
- **Swaps:** omit cheese (dairy-free, paleo); wrap around cucumber sticks (more volume, same macros)
- **Approx:** ~220 kcal · 2g C · 26g P · 12g F
- **Source:** Colorado State Extension "Quick and Easy Snacks for Athletes" https://foodsmartcolorado.colostate.edu/quick-and-easy-snacks-for-athletes; common low-carb athlete snack
- **Why:** a genuinely low-carb rest-day snack — 26g of protein, no bread, no prep

### S-069 · Smoked salmon & cream cheese cucumber roll-ups
- **Context:** everyday, rest-day, travel · **Cuisine:** nordic · **Prep:** 15 min · **Batch:** no
- **Ingredients:** smoked salmon 80g, cream cheese 2 tbsp, cucumber ribbons 1/2 cucumber, capers
- **Diets OK:** keto, low_carb, mediterranean, omnivore, pescatarian
- **Allergens:** dairy, fish
- **Swaps:** cream cheese→dairy-free cream cheese (dairy-free, paleo); serve on rice cakes 2 (+24g C, pre-session version)
- **Approx:** ~220 kcal · 3g C · 16g P · 16g F
- **Source:** commonly reported keto travel and office snack for fat-adapted athletes
- **Why:** no-cook protein and omega-3 for a rest day or a hotel room — fish that needs no kitchen

### S-070 · Avocado with sea salt & lime
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** avocado 1/2, sea salt pinch, lime squeeze
- **Diets OK:** keto, low_carb, mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add a boiled egg (eggs, +6g P); spread on rice cakes 2 (+24g C for a training day)
- **Approx:** ~160 kcal · 9g C · 2g P · 15g F
- **Source:** listed among ideal triathlete snacks, ROUVY https://rouvy.com/blog/snack-for-triathlon
- **Why:** a fat-and-fibre snack for an easy day when carb need drops — free of all nine allergens

### S-071 · Macadamia nuts, berries & cream
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** macadamia nuts 30g, mixed berries 80g, double cream 2 tbsp
- **Diets OK:** keto, low_carb, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, tree_nuts
- **Swaps:** cream→coconut cream (dairy-free, paleo); macadamias→walnuts (cheaper, same)
- **Approx:** ~320 kcal · 10g C · 4g P · 30g F
- **Source:** within Volek & Phinney's fruit-and-nut allowance in The Art and Science of Low Carbohydrate Performance, summarised at https://www.ketogains.com/2015/10/the-art-and-science-of-low-carbohydrate-performance-by-jeff-s-volek-and-stephen-d-phinney-a-summary/
- **Why:** matches the keto-endurance book's daily fruit and nut ceiling — a dessert-like rest-day snack under 10g carbs

### S-072 · Bone broth with shredded chicken
- **Context:** recovery, rest-day · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** bone broth 500ml, shredded rotisserie chicken 100g, salt
- **Diets OK:** keto, low_carb, omnivore, paleo
- **Allergens:** none
- **Swaps:** add cooked rice 100g (+40g C, training-day version); chicken→soft tofu 100g (vegan, soy)
- **Approx:** ~180 kcal · 2g C · 24g P · 6g F
- **Source:** Volek & Phinney's broth-based post-workout suggestion in The Art and Science of Low Carbohydrate Performance (summary link as above); commonly reported keto and paleo recovery snack
- **Why:** sodium, fluid and 24g of protein that goes down easily after a hard session — free of every allergen

### S-073 · Beef jerky, homemade or soy-free
- **Context:** everyday, rest-day, travel · **Cuisine:** american · **Prep:** batch — 4 h dehydrator, 4–5 servings · **Batch:** yes
- **Ingredients:** lean beef 250g raw, salt, black pepper, smoked paprika, coconut aminos 2 tbsp — dehydrated (makes 4)
- **Diets OK:** keto, low_carb, omnivore, paleo
- **Allergens:** none
- **Swaps:** buy a soy-free, gluten-free labelled jerky (same, check label — most commercial marinades are soy sauce); add an apple (+25g C, paleo travel combo)
- **Approx:** ~120 kcal · 3g C · 18g P · 3g F
- **Source:** dprimm on TrainerRoad "made fresh at home, lower cost, easy to store" https://www.trainerroad.com/forum/t/your-favorite-snacks/7464; ROUVY flags gluten-free jerkies https://rouvy.com/blog/snack-for-triathlon
- **Why:** shelf-stable protein that is neither a bar nor a gel — race-trip bags, flights, glove boxes

### S-074 · Jerky, dried mango & rice cakes
- **Context:** pre-session, race-week, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** plain beef jerky 40g, dried mango 40g, plain rice cakes 2
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** jerky→roasted chickpeas 60g (vegan); rice cakes→pretzels 30g (gluten)
- **Approx:** ~320 kcal · 45g C · 18g P · 4g F
- **Source:** "Beef Jerky + Dried Fruit" as an allergen-safe travel option, smnutritionrd.com "Allergy Friendly Snacks for Athletes"
- **Why:** a complete carb-plus-protein travel plate with no fridge and none of the nine allergens — check the jerky marinade

### S-075 · Rice crackers, turkey & cucumber
- **Context:** everyday, travel · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** plain rice crackers 8, sliced turkey breast 80g, cucumber slices 1/2 cucumber, yellow mustard
- **Diets OK:** omnivore
- **Allergens:** none
- **Swaps:** turkey→hummus 60g (vegan, sesame); rice crackers→rye crispbread (gluten)
- **Approx:** ~280 kcal · 30g C · 18g P · 6g F
- **Source:** standard travel-snack format in allergy-friendly travel blogs; commonly reported
- **Why:** the savoury allergen-free desk snack — most nut-free options are sweet, this one is not

### S-076 · Tuna pouch, crackers & pickles
- **Context:** everyday, recovery, travel · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** flavoured tuna pouch 85g, crackers 8, pickle spears 2
- **Diets OK:** mediterranean, omnivore, pescatarian
- **Allergens:** fish, gluten
- **Swaps:** crackers→rice crackers (gluten-free); tuna→tinned sardines (same, more omega-3)
- **Approx:** ~280 kcal · 25g C · 20g P · 8g F
- **Source:** scarrith on TrainerRoad https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095/6
- **Why:** shelf-stable 20g of protein that lives in a desk drawer — no fridge, no bar, no gel

### S-077 · Trail mix, nuts & seeds
- **Context:** everyday, rest-day, travel · **Cuisine:** general · **Prep:** batch — 5 min, 4–5 servings · **Batch:** yes
- **Ingredients:** mixed nuts (almonds, cashews, peanuts) 40g, sunflower and pumpkin seeds 20g
- **Diets OK:** keto, low_carb, mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** peanuts, tree_nuts
- **Swaps:** add raisins and dried apricots 40g (+30g C, training-day version); seeds only (allergen-free)
- **Approx:** ~360 kcal · 15g C · 12g P · 28g F
- **Source:** GarageLab on TrainerRoad "pretty much every day", Costco trail mix https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095/8; Rich Roll's constant almonds and walnuts, livekindly.com
- **Why:** calorie-dense and low-carb — a daily snack for an athlete managing intake, portion it out or it becomes 800 kcal

### S-078 · Seed & dried fruit mix, nut-free
- **Context:** pre-session, rest-day, travel · **Cuisine:** general · **Prep:** batch — 5 min, 4–5 servings · **Batch:** yes
- **Ingredients:** pumpkin seeds 30g, sunflower seeds 20g, dried cranberries 30g, dried apricots 30g
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add gluten-free pretzels 40g + dark chocolate chips 20g (smnutritionrd.com snack mix, +40g C); seeds→roasted almonds (tree_nuts)
- **Approx:** ~300 kcal · 38g C · 8g P · 13g F
- **Source:** nut-free trail-mix adaptation from smnutritionrd.com "Allergy Friendly Snacks for Athletes" and r/triathlon nut-allergy threads
- **Why:** the trail mix a nut-allergic teammate can share — free of all nine allergens, mixes carbs with fat for a long drive

### S-079 · Salted air-popped popcorn
- **Context:** everyday, rest-day, travel · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** air-popped popcorn 30g, salt, olive oil spray
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add nutritional yeast 1 tbsp (+3g P); add dark chocolate 20g (Tamara Jewett's snack plate)
- **Approx:** ~110 kcal · 22g C · 3g P · 2g F
- **Source:** cheap whole-grain snack cited alongside pretzels in endurance-nutrition roundups; part of Tamara Jewett's mid-day snack plate, triathlonmagazine.ca
- **Why:** bulk to graze on for 110 kcal — the rest-day snack that stops you eating a bar out of boredom

### S-080 · Chocolate peanut butter popcorn
- **Context:** everyday, travel · **Cuisine:** american · **Prep:** batch — 15 min, 6 servings · **Batch:** yes
- **Ingredients:** popcorn 1 cup, honey 1 tbsp, peanut butter 1 tbsp, oil 1/2 tsp, dark chocolate chips 1 tbsp, vanilla (makes 6)
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** peanuts
- **Swaps:** peanut butter→sunflower seed butter (nut-free); honey→maple syrup (vegan, use dairy-free chocolate)
- **Approx:** ~270 kcal · 33g C · 5g P · 14g F
- **Source:** Meghann Featherstun RD, Featherstone Nutrition https://www.featherstonenutrition.com/chocolate-peanut-butter-popcorn/
- **Why:** a running dietitian's sweet travel snack — carb-forward, portioned, and survives a car journey

### S-081 · Kiwi fruit before bed
- **Context:** everyday, rest-day · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** kiwi fruit 2
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add Greek yogurt 150g (pre-bed protein, dairy); add tart cherry juice 200ml (+25g C, same sleep angle)
- **Approx:** ~90 kcal · 22g C · 2g P · 1g F
- **Source:** kiwifruit and athlete sleep-quality research, NCBI review https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10220871/
- **Why:** the one pre-bed snack with actual sleep evidence behind it — allergen-free and 90 kcal

### S-082 · Frozen grapes
- **Context:** everyday, rest-day, travel · **Cuisine:** general · **Prep:** batch — 5 min, 4–5 servings · **Batch:** yes
- **Ingredients:** seedless grapes 150g, frozen
- **Diets OK:** mediterranean, omnivore, paleo, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** grapes→frozen banana slices (same); add cheese stick (dairy, +7g P)
- **Approx:** ~100 kcal · 26g C · 1g P · 0g F
- **Source:** commonly reported hot-weather athlete snack across sports-nutrition and cheap-snack roundups
- **Why:** a summer-block staple — freeze a bag Sunday, grab a handful after a hot session

### S-083 · Chocolate milk
- **Context:** recovery · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** low-fat chocolate milk 500ml
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** dairy→fortified soy chocolate milk (vegan, dairy-free, soy); add a banana (+27g C); add a granola bar (ROUVY combo, gluten)
- **Approx:** ~340 kcal · 52g C · 16g P · 8g F
- **Source:** Gustav Iden's easy recovery calories "while in Bergen", vo2master.com; the chocolate-milk recovery research summarised at https://www.onepeloton.com/blog/chocolate-milk-after-workout
- **Why:** the cheapest evidence-backed 3:1 recovery drink there is — a world champion names it as a go-to

### S-084 · Greek yogurt with granola & berries
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** Greek yogurt 200g, granola 40g, mixed berries 100g
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten, tree_nuts
- **Swaps:** yogurt→coconut or soy yogurt (vegan, dairy-free); granola→muesli 50g (Jonny Brownlee's lunchtime pudding); granola→certified GF nut-free granola (gluten-free, nut-free); eat it pre-bed without berries (Paula Findlay's version)
- **Approx:** ~380 kcal · 45g C · 24g P · 10g F
- **Source:** Paula Findlay's pre-bed yogurt and granola, triathlonmagazine.ca; Jonny Brownlee's yogurt and muesli, 220triathlon.com; Peloton post-run list https://www.onepeloton.com/blog/what-to-eat-after-a-run
- **Why:** hits the ~1g/kg carbs plus 20–40g protein recovery window with a spoon and no cooking

### S-085 · Greek yogurt with peanut butter & banana
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** Greek yogurt 200g, peanut butter 1 tbsp, banana 1, honey drizzle
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, peanuts
- **Swaps:** yogurt→soy yogurt and honey→maple (vegan, soy); peanut butter→sunflower seed butter (peanut-free)
- **Approx:** ~380 kcal · 45g C · 22g P · 12g F
- **Source:** Tamara Jewett's reported snack, triathlonmagazine.ca "What vegetarian pro triathlete Tamara Jewett eats in a day"
- **Why:** fast dairy protein and carbs after a session — a pro's actual recovery bowl, three ingredients

### S-086 · Soy yogurt parfait with granola & berries
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** soy yogurt 250g, granola 40g, mixed berries 80g, chopped walnuts 15g
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten, soy, tree_nuts
- **Swaps:** soy yogurt→coconut yogurt (soy-free, less protein); walnuts→pumpkin seeds (nut-free); granola→certified GF granola (gluten-free)
- **Approx:** ~420 kcal · 55g C · 16g P · 14g F
- **Source:** commonly reported vegan-athlete recovery snack format across greatveganathletes.com profiles and dietitianapproved.com
- **Why:** the dairy-free recovery parfait — soy yogurt is the only plant yogurt with real protein

### S-087 · Toaster waffles with maple syrup & Greek yogurt
- **Context:** recovery · **Cuisine:** american · **Prep:** 5 min · **Batch:** no
- **Ingredients:** frozen waffles 2, maple syrup 2 tbsp, Greek yogurt 100g
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy, eggs, gluten
- **Swaps:** waffles→gluten-free waffles (gluten-free); yogurt→coconut yogurt (dairy-free, less protein)
- **Approx:** ~450 kcal · 65g C · 15g P · 12g F
- **Source:** reported post-hard-session recovery treat in endurance-athlete "day of eating" content; commonly eaten
- **Why:** when a savoury recovery meal will not go down after a brick, a toaster and a fridge sort it in five minutes

### S-088 · Cottage cheese & pineapple
- **Context:** everyday, recovery, rest-day · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** cottage cheese 200g, pineapple chunks 150g
- **Diets OK:** low_carb, mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** pineapple→cinnamon and honey 1 tsp (pre-bed version, 12g C); add pumpkin seeds 1 tbsp (+3g P); add rice crackers 30g (+25g C)
- **Approx:** ~280 kcal · 25g C · 25g P · 5g F
- **Source:** SnackingInSneakers "Why Cottage Cheese Before Bed Can Help Athletes Recover Better" https://www.snackinginsneakers.com/cottage-cheese-before-bed/; repeated across r/Ultramarathon and sports-dietitian recovery content
- **Why:** 25g of slow casein protein for 280 kcal — a recovery or pre-bed snack that costs nothing to make

### S-089 · Cottage cheese with peanut butter & honey, pre-bed
- **Context:** everyday, recovery, rest-day · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** cottage cheese 200g, peanut butter 1 tbsp, honey 1 tsp
- **Diets OK:** low_carb, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, peanuts
- **Swaps:** add rolled oats 30g (+20g C on a camp week, gluten); peanut butter→sunflower seed butter (peanut-free); cottage cheese→soy yogurt (vegan, soy)
- **Approx:** ~330 kcal · 15g C · 27g P · 15g F
- **Source:** pre-sleep casein strategy recommended in ISSN-aligned sports-nutrition guidance for heavy training blocks; commonly reported camp-week habit
- **Why:** on a two-session day, slow protein before bed supports overnight repair — this is the standard version

### S-090 · Cottage cheese, cucumber & tomato with olive oil
- **Context:** rest-day · **Cuisine:** mediterranean · **Prep:** 5 min · **Batch:** no
- **Ingredients:** cottage cheese 200g, cucumber 1/2, cherry tomatoes 100g, olive oil 1 tsp, black pepper, pumpkin seeds 1 tbsp
- **Diets OK:** keto, low_carb, mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** cottage cheese→hummus 100g (vegan, sesame); add rye crispbread 2 (+20g C, gluten)
- **Approx:** ~250 kcal · 10g C · 24g P · 12g F
- **Source:** rest-day protein-first snack recommended in sports-dietitian guidance (Nancy Clark style); commonly reported
- **Why:** the savoury cottage cheese plate — protein-first and low-carb on purpose for a rest day

### S-091 · Casein shake before bed
- **Context:** everyday, recovery, rest-day · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** casein protein powder 30g, milk or water 300ml
- **Diets OK:** keto, low_carb, omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** casein→pea protein (vegan, dairy-free, faster digesting); milk→water (keto, 120 kcal)
- **Approx:** ~200 kcal · 10g C · 30g P · 4g F
- **Source:** pre-sleep milk-protein practice cross-referenced at https://www.snackinginsneakers.com/cottage-cheese-before-bed/; commonly recommended in ISSN-aligned guidance
- **Why:** the one-minute version of pre-bed protein for nights when cottage cheese does not appeal

### S-092 · Heavy-cream protein shake
- **Context:** everyday, recovery, rest-day · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** whey or collagen protein 1 scoop, double cream 60ml, water and ice, cocoa powder 1 tsp
- **Diets OK:** keto, low_carb, omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** cream→coconut cream (dairy-free, paleo with collagen); whey→collagen (paleo, dairy only from cream)
- **Approx:** ~350 kcal · 3g C · 25g P · 26g F
- **Source:** Mike McKnight's reported keto snack, Diet Doctor https://www.dietdoctor.com/low-carb-improves-ultra-runners-performance-and-health
- **Why:** a fat-adapted ultrarunner's between-meal shake — high fat, real protein, under 5g carbs

### S-093 · Banana, milk & protein powder recovery smoothie
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** banana 1, milk 300ml, whey protein 1 scoop, frozen berries 80g, spinach handful
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** milk + whey→oat milk + pea protein (vegan, dairy-free); add rolled oats 30g (+20g C, gluten); add peanut butter 1 tbsp (+8g F, peanuts)
- **Approx:** ~380 kcal · 50g C · 30g P · 5g F
- **Source:** cbounds on TrainerRoad "usually post ride" https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/11; named as a 3:1 recovery option by ROUVY https://rouvy.com/blog/snack-for-triathlon
- **Why:** drinkable recovery when appetite is gone after a hard ride — carbs and 30g of protein in two minutes

### S-094 · Almond butter, banana & date smoothie
- **Context:** recovery · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** almond milk 300ml, almond butter 1 tbsp, banana 1, dates 2, plant protein 1 scoop
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** tree_nuts
- **Swaps:** almond milk + butter→oat milk + sunflower seed butter (nut-free); dates→frozen berries 1 cup (Scott Jurek's post-run shake)
- **Approx:** ~380 kcal · 50g C · 25g P · 9g F
- **Source:** Paula Findlay's post-run smoothie, triathlonmagazine.ca; Scott Jurek's berry version, sierraclub.org
- **Why:** a named pro's dairy-free recovery shake — dates do the carb work, plant protein hits the 20–30g window

### S-095 · Wild blueberry & coconut milk recovery smoothie
- **Context:** recovery · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** frozen wild blueberries 1 cup, banana 1/2, coconut milk 1 cup, vanilla whey 1 scoop
- **Diets OK:** omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** whey→pea protein (vegan, dairy-free); add spinach and mint (TrainingPeaks green version)
- **Approx:** ~300 kcal · 42g C · 22g P · 8g F
- **Source:** TrainingPeaks blog "3 Recipes for Increased Recovery" https://www.trainingpeaks.com/blog/3-recipes-for-increased-recovery/
- **Why:** antioxidant-heavy carb-plus-protein smoothie sized as a recovery-window snack, not a meal

### S-096 · Strawberry, banana & lactose-free milk smoothie
- **Context:** everyday, recovery · **Cuisine:** general · **Prep:** 5 min · **Batch:** no
- **Ingredients:** firm banana 1, strawberries 100g, lactose-free milk 200ml, ice
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy
- **Swaps:** lactose-free milk→rice or almond milk (dairy-free, almond adds tree_nuts); add whey 1 scoop (+20g P)
- **Approx:** ~280 kcal · 55g C · 10g P · 2g F
- **Source:** Kate Scarlata RDN low-FODMAP athlete recommendations ("Low-FODMAP fruit smoothies")
- **Why:** the gut-friendly recovery smoothie from a low-FODMAP dietitian — for athletes whose stomach hates the usual shake

### S-097 · Chia pudding jar
- **Context:** everyday, recovery, rest-day · **Cuisine:** general · **Prep:** overnight · **Batch:** yes
- **Ingredients:** chia seeds 3 tbsp, oat milk 250ml, maple syrup 1 tbsp, berries 80g (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** add pea or hemp protein 1 scoop + cocoa 1 tbsp (+20g P, vegan protein pudding); oat milk→dairy milk (dairy)
- **Approx:** ~280 kcal · 32g C · 8g P · 12g F
- **Source:** Adub on TrainerRoad https://www.trainerroad.com/forum/t/your-favorite-snacks/7464/15; hemp-protein version via Sunwarrior soy-free vegan protein guide
- **Why:** make four jars Sunday — fibre, omega-3 and a protein-scoop option with none of the nine allergens

### S-098 · Overnight oats jar
- **Context:** everyday, pre-session, travel · **Cuisine:** general · **Prep:** overnight · **Batch:** yes
- **Ingredients:** rolled oats 60g, oat milk 150ml, chia seeds 1 tbsp, banana 1/2, maple syrup 1 tsp (makes 5)
- **Diets OK:** omnivore, pescatarian, vegan, vegetarian
- **Allergens:** gluten
- **Swaps:** oats→certified GF oats (gluten-free); oat milk→dairy milk + Greek yogurt 100g (+15g P, dairy); banana→berries (same)
- **Approx:** ~340 kcal · 55g C · 10g P · 8g F
- **Source:** Triathlete.com on-the-go breakfast options https://www.triathlete.com/nutrition/race-fueling/go-breakfast-options-busy-athletes/; commonly reported desk and travel staple
- **Why:** five jars Sunday covers every pre-evening-session top-up of the week straight from the fridge

### S-099 · White bean dip with veg sticks
- **Context:** everyday, rest-day · **Cuisine:** mediterranean · **Prep:** batch — 10 min, 4 servings · **Batch:** yes
- **Ingredients:** cannellini beans 150g blended with olive oil 1 tbsp, lemon juice, garlic, salt; carrot, cucumber and pepper sticks 150g (makes 4)
- **Diets OK:** mediterranean, omnivore, pescatarian, vegan, vegetarian
- **Allergens:** none
- **Swaps:** beans→chickpeas + tahini (hummus, sesame); serve with pita (+30g C, gluten)
- **Approx:** ~220 kcal · 26g C · 8g P · 8g F
- **Source:** standard sesame-allergy swap for hummus documented across allergy-blog dip roundups; commonly reported
- **Why:** hummus for the sesame-allergic — same use, same texture, free of all nine allergens

### S-100 · Fruit & cheese plate
- **Context:** everyday, pre-session · **Cuisine:** general · **Prep:** no-cook · **Batch:** no
- **Ingredients:** grapes 100g, cheddar 30g, whole-grain crackers 4
- **Diets OK:** mediterranean, omnivore, pescatarian, vegetarian
- **Allergens:** dairy, gluten
- **Swaps:** crackers→rice crackers (gluten-free); cheddar→vegan cheese (vegan, dairy-free); grapes→apple slices (same)
- **Approx:** ~280 kcal · 30g C · 9g P · 13g F
- **Source:** cheese-and-fruit pre-session pattern in cheap-and-easy athlete snack lists; commonly reported
- **Why:** carbs, fat and protein in balance 1–2 h before an evening session — assembled from staples in two minutes

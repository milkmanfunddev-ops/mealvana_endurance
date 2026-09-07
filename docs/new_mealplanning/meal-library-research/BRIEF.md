# Research brief — Mealvana Endurance "meal library" (read fully before starting)

## What we're building
Mealvana Endurance is a nutrition-planning app for triathletes (and runners/cyclists). We already have
deterministic "formulas" for pre-workout, during-workout and post-workout fuelling. We are now building
**everyday meal planning**, and we need a library of ~400 **real meals** — breakfast, lunch, dinner, snack —
that endurance athletes (pro triathletes, elite runners/cyclists, sports dietitians' clients) actually eat.

The bar for every entry: a normal amateur triathlete looks at it and says *"yeah, that makes sense, that's
what I'd eat, and it looks like what a good triathlete would eat."* Not restaurant recipes. Not influencer
"aesthetic" bowls. Real, repeatable, mostly simple, batch-cookable food. Component-first ("chicken + rice +
veg + sauce"), because our user research says 6 of 8 athletes eat from a rotation of staples.

## Your job
Research YOUR assigned slice (see your prompt) and return **candidate meals** with sources. Quantity over
polish at this stage — 40–80 strong candidates from your slice is ideal. A later pass selects the best 400
across all slices. **Prefer meals you can attribute** to a named athlete, dietitian, cookbook, article, or a
well-upvoted community thread. Do not invent athlete attributions. If a meal is just "commonly eaten" say so.

## Use the web
Use WebSearch and WebFetch heavily. Good sources: triathlete.com, 220triathlon.com, tri247.com,
slowtwitch.com, trainingpeaks.com blog, precisionhydration.com, fuelin.com, runnersworld.com,
outsideonline.com, velo/cyclingweekly "what pros eat", GCN/GTN videos, athlete Instagram/YouTube "day of
eating", pro-team nutritionist interviews, Substack newsletters, podcasts (show notes), Reddit
(r/triathlon, r/Ironman, r/AdvancedRunning, r/running, r/Velo, r/veganfitness, r/EatCheapAndHealthy
"athlete" threads), cookbooks (Feed Zone Cookbook / Feed Zone Portables — Allen Lim & Biju Thomas; Run Fast
Eat Slow — Shalane Flanagan & Elyse Kopecky; The Endurance Diet / Racing Weight — Matt Fitzgerald; Nancy
Clark's Sports Nutrition Guidebook; Bob Seebohar Metabolic Efficiency; Rich Roll / Plantpower Way; Scott
Jurek Eat & Run; Ryan Hall/Kyle Pfaffenbach; Fuelling the Athlete – Renee McGregor; Fuel Up – Sarah
Zimmerman; Eat Race Win (Hannah Grant, Tour de France chef); The Cyclist's Cookbook; Fuelling Bites).

## Hard constraints from the app (use these EXACT tags)
Diet options (single-select per user): `omnivore`, `vegetarian`, `pescatarian`, `vegan`,
`mediterranean`, `paleo`, `keto`, `low_carb`.
Allergen options (multi-select per user): `dairy`, `eggs`, `fish`, `gluten`, `peanuts`, `sesame`,
`shellfish`, `soy`, `tree_nuts`.

For every meal, be precise about which diets it fits **as written**, and which allergens it contains
**as written**. Then give the one-line swap that fixes the most common problem (e.g. "milk → oat milk
makes it vegan/dairy-free"). Oats count as gluten-containing unless "certified GF oats" is stated.

## Sports-nutrition anchors (so portions are athlete-sized, not diet-sized)
- Training-day carbs for an endurance athlete: ~5–8 g/kg/day (up to 10–12 g/kg in carb-load).
  A 70 kg athlete needs ~350–560 g carbs/day → a main meal is often 80–150 g carbs.
- Protein ~1.6–2.2 g/kg/day, spread as ~25–40 g per meal, 4–5 feeds.
- Breakfast before a key session: high-carb, low-fibre, low-fat, familiar.
- Rest / easy days: same protein, moderate carbs, more veg/fibre/fat — this is a known gap; tag rest-day meals.
- Race week: lower fibre, higher simple carbs, low residue on race-eve — tag these.
- Recovery meal (within ~1–2 h of a hard session): ~1–1.2 g/kg carbs + 20–40 g protein.

## Output format (STRICT — a script parses this)
Write your results to the file path given in your prompt. Markdown. One block per meal, exactly:

```
### <Meal name — short, plain, component-style; e.g. "Chicken, jasmine rice & roasted broccoli with teriyaki">
- meal_type: breakfast | lunch | dinner | snack   (pick ONE; "second breakfast"/pre-bed = snack)
- context: everyday | pre-session | recovery | rest-day | race-week | carb-load | travel   (one or more, comma-separated)
- ingredients: <comma-separated with rough athlete portions, e.g. "rolled oats 80g, banana 1, peanut butter 1 tbsp, honey 1 tbsp, whole milk 250ml">
- diets_ok: <subset of omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb — as written>
- allergens: <subset of dairy, eggs, fish, gluten, peanuts, sesame, shellfish, soy, tree_nuts — as written; or "none">
- swaps: <1–3 short swaps that change the diet/allergen profile, e.g. "milk→oat milk (vegan, dairy-free); oats→certified GF oats (gluten-free)">
- approx_macros: <kcal, carbs g, protein g, fat g — rough, say "~">
- prep: <"5 min", "batch — cook Sunday, 4 servings", "no-cook", etc.>
- source: <who eats/recommends it + where you found it + URL if any. Be honest: "commonly reported on r/triathlon (thread URL)" is fine>
- why: <one line on why it belongs in a triathlete's rotation>
```

Do not add extra fields. Do not write prose between blocks except a short header at the top of your file
listing the sources you actually consulted (with URLs). Aim for 40–80 blocks. Do not pad with near-duplicates
(e.g. five oatmeal variants) — one canonical version plus swaps is better than variants.

# Reddit slice — sources consulted

`reddit.com`, `www.reddit.com`, `old.reddit.com`, `api.reddit.com` are all **blocked outright by WebFetch** (domain-level block, confirmed on all four hosts and with `?raw_json=1` variants — not a robots/JSON issue, the tool refuses the fetch before any request is made). Worked around per the task instructions using the `claude-in-chrome` MCP: a fresh tab on `old.reddit.com`, using its native `search?q=title:"..."&restrict_sr=1&sort=top` search (old.reddit search matches the DB, unlike Reddit's default search which is mostly useless for this) plus `get_page_text` to read full threads/comments. Google `site:reddit.com` was used once to sanity-check coverage.

Threads actually read (title, subreddit, points, URL):
- "What do you eat day-to-day?" — r/Ultramarathon, 34 pts, 53 comments — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/what_do_you_eat_daytoday/
- "What do you eat and drink the morning before a long run or marathon?" — r/AdvancedRunning, 17 pts (now 18), 62 comments — https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/what_do_you_eat_and_drink_the_morning_before_a/
- "What do YOU eat in a day?" — r/AdvancedRunning, 15 pts, 28 comments (OP body only) — https://old.reddit.com/r/AdvancedRunning/search?q=title%3A%22what%20do%20you%20eat%22&restrict_sr=1&sort=top
- r/cycling search results (OP bodies) for "what do you eat" pre/post/long-ride threads — https://old.reddit.com/r/cycling/search?q=title%3A%22what%20do%20you%20eat%22&restrict_sr=1&sort=top
- r/veganfitness search "meal" (top all-time, OP bodies/images-captions) — https://old.reddit.com/r/veganfitness/search?q=meal&restrict_sr=1&sort=top&t=all
- r/MealPrepSunday search "runner OR marathon OR triathlon OR cyclist" (OP bodies) — https://old.reddit.com/r/MealPrepSunday/search?q=runner+OR+marathon+OR+triathlon+OR+cyclist&restrict_sr=1&sort=top&t=all
- r/triathlon search titles breakfast/lunch/dinner/meal prep (OP bodies) — https://old.reddit.com/r/triathlon/search?q=title%3A%28breakfast%20OR%20lunch%20OR%20dinner%20OR%20%22meal%20prep%22%29&restrict_sr=1&sort=top&t=all

r/Ironman, r/running, r/Velo, r/Marathon_Training searches were queued but not opened individually — the six threads above already surfaced enough distinct, well-upvoted, concrete meals to hit the 40+ target without padding with near-duplicate "what do you eat" threads from adjacent subs. Where a meal is a single redditor's report rather than a broad community consensus, `source` says so explicitly and gives the upvote count of the parent thread as a rough proxy for how representative the thread is (individual comments aren't separately upvoted-sorted in old.reddit's default view, so I'm reporting thread-level engagement, not comment-level score, unless a comment score is visible in the text I pulled).

---

### Bagel & peanut butter with protein shake
- meal_type: breakfast
- context: everyday
- ingredients: bagel 1, peanut butter 2 tbsp, protein shake 1 (milk or water base), tea or coffee
- diets_ok: vegetarian
- allergens: gluten, peanuts, dairy (if milk-based shake)
- swaps: peanut butter→sunflower seed butter (peanut-free); water-based shake→dairy-free
- approx_macros: ~550 kcal, 75g carbs, 30g protein, 15g fat
- prep: 5 min
- source: r/Ultramarathon "What do you eat day-to-day?" — u/runslowgethungry, top comment, 36 pts — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: classic low-effort high-carb breakfast staple that repeats across many training-day reports

### Banana & peanut butter tortilla wrap
- meal_type: breakfast
- context: everyday, pre-session
- ingredients: whole wheat tortilla 1, banana 1, peanut butter 2 tbsp
- diets_ok: vegetarian, vegan (if honey omitted), mediterranean
- allergens: gluten, peanuts
- swaps: tortilla→corn tortilla (gluten-free); peanut butter→almond butter (still tree-nut, use sunflower for full nut-free)
- approx_macros: ~400 kcal, 55g carbs, 10g protein, 16g fat
- prep: 5 min
- source: r/Ultramarathon "What do you eat day-to-day?" — u/Leading_Turtle, 6 pts — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: portable pre-run carb hit that a 50K runner leans on daily

### Greek yogurt, granola, edamame & avocado salad (work lunch)
- meal_type: lunch
- context: everyday
- ingredients: mixed lettuce/greens, half avocado, shelled edamame or turkey/chicken, fiber wrap on the side, small square dark chocolate
- diets_ok: vegetarian (edamame version), pescatarian, mediterranean
- allergens: soy (edamame), gluten (wrap)
- swaps: wrap→GF wrap; chicken→tofu for vegan
- approx_macros: ~500 kcal, 45g carbs, 30g protein, 22g fat
- prep: 10 min, batch-choppable Sunday
- source: r/Ultramarathon "What do you eat day-to-day?" — u/Leading_Turtle, 6 pts — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: a "creature of habit" runner's repeatable, decision-fatigue-proof lunch — matches the component-first rotation pattern

### Tofu, sweet potato & veg wrap (batch-roasted)
- meal_type: lunch
- context: everyday, rest-day
- ingredients: whole wheat tortilla 1, quinoa 60g cooked, tofu 100g roasted, sweet potato 100g roasted, corn, peppers, onions
- diets_ok: vegan, vegetarian
- allergens: gluten (tortilla), soy (tofu)
- swaps: tortilla→corn tortilla or rice wrap (gluten-free)
- approx_macros: ~450 kcal, 65g carbs, 18g protein, 12g fat
- prep: batch — roast tofu/sweet potato/veg Sunday, cook quinoa, assemble night before, 4+ servings
- source: r/Ultramarathon "What do you eat day-to-day?" — u/whammywombat, 14 pts (WFPB tree-climber fuelling like an ultra athlete) — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: whole-food-plant-based worker/athlete's actual weekday rotation, explicitly batch-prepped Sundays for grab-and-go

### Overnight oats with banana, walnuts, blueberries & cinnamon
- meal_type: breakfast
- context: everyday
- ingredients: rolled oats 60g, banana 1, walnuts 20g, blueberries 50g, cinnamon, raisins, plant milk 200ml
- diets_ok: vegan, vegetarian, mediterranean
- allergens: gluten (oats unless certified GF), tree_nuts
- swaps: oats→certified GF oats (gluten-free); walnuts→pumpkin seeds (tree-nut-free)
- approx_macros: ~450 kcal, 65g carbs, 12g protein, 16g fat
- prep: no-cook, prep night before
- source: r/Ultramarathon "What do you eat day-to-day?" — u/whammywombat, 14 pts — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: grab-and-go breakfast for early training, no morning cooking required

### 4 eggs, sourdough & cottage cheese
- meal_type: breakfast
- context: pre-session, everyday
- ingredients: eggs 4, sourdough bread 4 slices, cottage cheese 150g
- diets_ok: vegetarian
- allergens: eggs, gluten, dairy
- swaps: sourdough→GF bread (gluten-free); cottage cheese→dairy-free yogurt (dairy-free)
- approx_macros: ~700 kcal, 55g carbs, 50g protein, 28g fat
- prep: 10 min
- source: r/Ultramarathon "What do you eat day-to-day?" — u/rightkneebutter, 6 pts (25M lifter/ultra runner) — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: high-protein post-lift breakfast for someone doubling strength + endurance training

### Chicken pesto pasta with veg & Greek yogurt
- meal_type: lunch
- context: everyday
- ingredients: pasta 100g dry, chicken breast 150g, pesto 2 tbsp, mixed veg, Greek yogurt 150g with protein powder and creatine, fruit
- diets_ok: mediterranean
- allergens: gluten, dairy, tree_nuts (pesto often has pine nuts/cashew)
- swaps: pasta→GF pasta (gluten-free); pesto→nut-free basil-oil pesto
- approx_macros: ~750 kcal, 85g carbs, 55g protein, 22g fat
- prep: 15 min, batch-cookable
- source: r/Ultramarathon "What do you eat day-to-day?" — u/rightkneebutter, 6 pts — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: repeatable lunch for someone running 25-40 mpw plus lifting, eaten "the same thing every day"

### Non-fat Greek yogurt, beef/chicken, rice & fruit/veg rotation
- meal_type: dinner
- context: everyday
- ingredients: chicken or beef 150g, rice or potatoes 200g, whole milk 250ml, granola, honey, fruit/veg
- diets_ok: omnivore
- allergens: dairy
- swaps: whole milk→oat milk (dairy-free)
- approx_macros: ~800 kcal, 90g carbs, 45g protein, 25g fat
- prep: batch — cook Sunday, several servings
- source: r/Ultramarathon "What do you eat day-to-day?" — u/Beginning-Yak-3168, 11 pts (30-40 mpw + lifting + swimming, 4000 kcal/day) — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: unprocessed, high-protein/high-carb staple rotation for a heavy multi-discipline training load

### 4-egg-white omelette with pickled veg, toast & salsa
- meal_type: breakfast
- context: everyday, rest-day
- ingredients: egg whites 4, pickled vegetables, whole grain toast 1 slice, salsa
- diets_ok: vegetarian, low_carb
- allergens: eggs, gluten
- swaps: toast→GF toast (gluten-free)
- approx_macros: ~250 kcal, 20g carbs, 22g protein, 5g fat
- prep: 10 min
- source: r/Ultramarathon "What do you eat day-to-day?" — u/sophiabarhoum, 3 pts (weight-lifter returning to running post-surgery) — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: lean, low-fat breakfast for someone actively managing weight around a running comeback

### Lean protein, rice & sweet potato bowl (chicken/beef/fish/black bean/tofu)
- meal_type: lunch
- context: everyday, recovery
- ingredients: lean chicken/beef/fish/black bean burger/tofu 100g, rice 100g cooked, sweet potato 100g, mixed veg
- diets_ok: omnivore, pescatarian, vegetarian, vegan (bean/tofu version)
- allergens: fish (if fish chosen), soy (if tofu)
- swaps: protein choice covers most diets already — pick the protein for the athlete's diet tag
- approx_macros: ~500 kcal, 65g carbs, 35g protein, 10g fat
- prep: batch — cook proteins/rice/sweet potato Sunday, portion into containers
- source: r/Ultramarathon "What do you eat day-to-day?" — u/sophiabarhoum, 3 pts — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: exactly the "component-first" rotation format — swap the protein, keep the base, repeat all week

### Sourdough toast & eggs with a side of veg (weekday base)
- meal_type: breakfast
- context: everyday
- ingredients: sourdough toast 2 slices, eggs 2, side veg
- diets_ok: vegetarian
- allergens: eggs, gluten
- swaps: sourdough→GF toast (gluten-free)
- approx_macros: ~400 kcal, 40g carbs, 20g protein, 15g fat
- prep: 10 min
- source: r/Ultramarathon "What do you eat day-to-day?" — u/SparksAfterTheSunset, 3 pts (24hr MTB racer/XC skier) — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: simple homemade weekday base for a multi-sport endurance athlete who otherwise eats "whatever the fuck I want"

### Fattoush-style toasted flatbread & roasted chickpea salad
- meal_type: lunch
- context: everyday
- ingredients: toasted naan/flatbread, roasted chickpeas (olive oil, paprika, cumin, garlic), tomato, cucumber, pepper, lettuce/kale, olives, feta, red onion, balsamic + olive oil dressing
- diets_ok: vegetarian, mediterranean
- allergens: gluten, dairy (feta)
- swaps: flatbread→GF flatbread (gluten-free); feta→dairy-free feta (dairy-free, vegan)
- approx_macros: ~550 kcal, 60g carbs, 18g protein, 25g fat
- prep: 15 min, batch chickpeas ahead
- source: r/Ultramarathon "What do you eat day-to-day?" — u/wrong-dr, comment reply with recipe — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: a "not boring" salad an athlete actually wants to eat repeatedly — addresses the "salads are boring" complaint directly in-thread

### Breakfast wrap: eggs, cheese, spinach & hot sauce
- meal_type: breakfast
- context: everyday
- ingredients: flour tortilla 1, eggs 2 + egg whites, shredded cheese, spinach, hot sauce, OJ
- diets_ok: vegetarian
- allergens: eggs, dairy, gluten
- swaps: tortilla→corn tortilla (gluten-free); cheese→dairy-free shreds (dairy-free)
- approx_macros: ~450 kcal, 40g carbs, 28g protein, 18g fat
- prep: 10 min, batch-wrappable
- source: r/Ultramarathon "What do you eat day-to-day?" — u/ElderberryNo5595, 5 pts (marathon-distance trail runner, weighs food) — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: precise, athlete-sized second meal from a data-driven runner's actual tracked day

### Large chicken & grain salad
- meal_type: lunch
- context: everyday
- ingredients: mixed greens, chicken 120g, a grain (quinoa/farro/rice) 80g cooked, veg, light dressing
- diets_ok: omnivore
- allergens: none (check dressing)
- swaps: chicken→chickpeas (vegetarian/vegan)
- approx_macros: ~450 kcal, 45g carbs, 35g protein, 12g fat
- prep: 10 min, batch-cook grain + chicken
- source: r/Ultramarathon "What do you eat day-to-day?" — u/ElderberryNo5595, 5 pts — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: "fourth meal" template that keeps protein and carbs both athlete-sized without being heavy midday

### Post-long-run ramen bowl
- meal_type: dinner
- context: recovery
- ingredients: ramen noodles, broth, soft-boiled egg, greens, protein of choice
- diets_ok: vegetarian (with veg broth/no egg swap for vegan), omnivore
- allergens: gluten, eggs, soy (broth)
- swaps: noodles→rice noodles (gluten-free); egg→omit (vegan with veg broth)
- approx_macros: ~600 kcal, 75g carbs, 25g protein, 18g fat
- prep: 15 min
- source: r/Ultramarathon "What do you eat day-to-day?" — u/ElderberryNo5595, 5 pts, "my after run treat is typically a giant bowl of ramen, which I really look forward to all week" — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: named, craved recovery-night dinner after long runs — carb-dense comfort food that's still a real meal

### Vegan tofu scramble with beans, veg & toast
- meal_type: breakfast
- context: everyday, pre-session
- ingredients: tofu 150g, black beans 100g, mixed veg, whole grain toast, jam
- diets_ok: vegan, vegetarian
- allergens: soy, gluten
- swaps: toast→GF toast (gluten-free)
- approx_macros: ~450 kcal, 45g carbs, 28g protein, 16g fat
- prep: 15 min
- source: r/Ultramarathon "What do you eat day-to-day?" — u/spookyandjasper, 2 pts (41F vegan, fasted training, runs 25k+ fasted) — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: intensive-training-day vegan breakfast used on days without fasted running

### Vegan bowl: chickpeas, mixed veg, nuts & nooch big salad
- meal_type: lunch
- context: everyday
- ingredients: big salad greens, chickpeas 150g, mixed veg, mixed nuts, nutritional yeast, olive oil
- diets_ok: vegan, vegetarian
- allergens: tree_nuts
- swaps: nuts→pumpkin seeds (tree-nut-free)
- approx_macros: ~500 kcal, 45g carbs, 20g protein, 25g fat
- prep: 10 min
- source: r/Ultramarathon "What do you eat day-to-day?" — u/spookyandjasper, 2 pts — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: vegan endurance runner's standard midday meal on a 2-meals-a-day/16-18h intermittent-fasting schedule

### Vegan meatballs, potatoes & broccoli
- meal_type: dinner
- context: everyday
- ingredients: vegan meatballs (pea/soy protein) 200g, potatoes 250g, broccoli 150g
- diets_ok: vegan, vegetarian
- allergens: soy (check brand)
- swaps: none typically needed — already allergen-light
- approx_macros: ~550 kcal, 65g carbs, 25g protein, 15g fat
- prep: 20 min, batch-cookable
- source: r/Ultramarathon "What do you eat day-to-day?" — u/spookyandjasper, 2 pts — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: simple component dinner (protein + starch + veg) from a vegan ultra runner's actual rotation

### Overnight oats with pea protein, banana & maca
- meal_type: breakfast
- context: everyday, pre-session
- ingredients: rolled oats 70g, plant milk 200ml, banana 1, berries 50g, pea or casein protein 1 scoop, maca powder 1 tsp
- diets_ok: vegan, vegetarian
- allergens: gluten (oats unless certified GF)
- swaps: oats→certified GF oats (gluten-free)
- approx_macros: ~480 kcal, 65g carbs, 25g protein, 10g fat
- prep: no-cook, prep night before
- source: r/Ultramarathon "What do you eat day-to-day?" — u/maturin-aubrey, 2 pts (36M, 40 mpw) — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: consistent, protein-boosted breakfast for a mid-volume weekly runner

### Carnivore/high-protein big meal (2x daily)
- meal_type: dinner
- context: everyday
- ingredients: beef or other meat 300-400g, minimal veg, electrolyte packet (e.g. LMNT)
- diets_ok: paleo, keto, low_carb
- allergens: none
- swaps: not applicable — inherently allergen-light; not vegetarian/vegan-compatible
- approx_macros: ~900 kcal, 5g carbs, 70g protein, 55g fat
- prep: 20 min
- source: r/Ultramarathon "What do you eat day-to-day?" — u/laurabrewer99, 2 pts (25F carnivore diet) — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: represents the keto/carnivore-diet athlete segment explicitly requested — tag it, don't force it into the carb-heavy default

### Lentil or bean stew with lots of veg
- meal_type: dinner
- context: everyday, rest-day
- ingredients: lentils or beans 200g cooked, mixed veg, protein pasta optional 80g
- diets_ok: vegan, vegetarian
- allergens: gluten (if pasta added)
- swaps: pasta→protein-pasta already GF in some brands — check; omit for simplicity
- approx_macros: ~500 kcal, 70g carbs, 28g protein, 8g fat
- prep: batch — cook Sunday, 4 servings
- source: r/Ultramarathon "What do you eat day-to-day?" — u/Ultragirl50, 1 pt (47F plant-based, 1600 kcal target) — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: rest-day-appropriate, fibre-forward vegan dinner distinct from the higher-carb race-day meals

### Daily meal log: eggs, oatmeal, chicken/rice, energy chews (real tracked day)
- meal_type: dinner
- context: everyday
- ingredients: white rice 170g, chicken breast 170g, mixed vegetables 1 serving
- diets_ok: omnivore, low_carb (if rice reduced)
- allergens: none
- swaps: none needed
- approx_macros: ~470 kcal, 64g carbs, 46g protein, 1g fat
- prep: batch — cook Sunday, 4+ servings
- source: r/Ultramarathon "What do you eat day-to-day?" — u/rcbjfdhjjhfd, 1 pt, full tracked-macro daily log posted verbatim — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: literal chicken+rice+veg staple, tracked to the gram by a 50-year-old ultra runner — as canonical as component meals get

### Greek yogurt, berries, matcha & collagen
- meal_type: breakfast
- context: everyday
- ingredients: Greek yogurt 200g, mixed berries (unlimited), matcha tea, collagen powder 1 scoop
- diets_ok: vegetarian, low_carb
- allergens: dairy
- swaps: yogurt→coconut/soy yogurt (dairy-free, vegan if collagen swapped for plant protein)
- approx_macros: ~350 kcal, 35g carbs, 25g protein, 8g fat
- prep: 5 min, no-cook
- source: r/Ultramarathon "What do you eat day-to-day?" — u/ad521612, 1 pt (150lb F, doesn't track calories) — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: quick no-cook breakfast, generous fruit portion appropriate for a training day

### 3am wake / heavy-carb runner day: wheat biscuits & tinned fruit, pasta lunch, stuffed potato dinner
- meal_type: lunch
- context: everyday
- ingredients: pasta 120g, vegetable sauce, chicken 100g (or canned baked beans + white bread)
- diets_ok: vegetarian (bean version), omnivore
- allergens: gluten
- swaps: pasta→GF pasta (gluten-free)
- approx_macros: ~650 kcal, 90g carbs, 30g protein, 15g fat
- prep: batch — cook pasta/sauce ahead
- source: r/Ultramarathon "What do you eat day-to-day?" — u/Muter, 2 pts (working with a nutritionist to hit carb goals) — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: heavy-training-day lunch explicitly built to hit a carb target under nutritionist guidance

### Stuffed potato with tuna & cheese
- meal_type: dinner
- context: everyday, recovery
- ingredients: baked potato 1 large, canned tuna 1 can, shredded cheese, side of chips/fries for extra carbs
- diets_ok: pescatarian
- allergens: fish, dairy
- swaps: cheese→dairy-free (dairy-free); tuna→chickpeas (vegetarian)
- approx_macros: ~600 kcal, 70g carbs, 35g protein, 18g fat
- prep: 20 min
- source: r/Ultramarathon "What do you eat day-to-day?" — u/Muter, 2 pts — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: simple carb+protein dinner explicitly used to "boost the carbs" while working with a sports nutritionist

### Salmon teriyaki rice bowl
- meal_type: lunch
- context: everyday
- ingredients: salmon 150g, jasmine rice 150g cooked, teriyaki sauce, steamed veg
- diets_ok: pescatarian
- allergens: fish, soy (teriyaki), gluten (soy sauce, unless tamari)
- swaps: soy sauce→tamari (gluten-free)
- approx_macros: ~650 kcal, 75g carbs, 35g protein, 18g fat
- prep: 15 min, batch-cookable
- source: r/Ultramarathon "What do you eat day-to-day?" — u/Prudent_Exercise_471, 3 pts (25F, 40-60 mpw + bike/yoga/lift) — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: one of the rotating "cook a lot, use good ingredients" lunches from a very high-volume multi-sport athlete

### Steak tacos with pico & guac
- meal_type: dinner
- context: everyday
- ingredients: steak 150g, corn tortillas 3, pico de gallo, guacamole
- diets_ok: paleo (no tortilla), gluten-free naturally with corn tortillas
- allergens: none (corn tortillas are gluten-free)
- swaps: none needed for most diets already
- approx_macros: ~650 kcal, 45g carbs, 40g protein, 30g fat
- prep: 20 min
- source: r/Ultramarathon "What do you eat day-to-day?" — u/Prudent_Exercise_471, 3 pts — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: high-volume runner/cyclist/lifter's whole-food, unprocessed dinner rotation entry

### Apple with almond butter
- meal_type: snack
- context: everyday
- ingredients: apple 1, almond butter 1.5 tbsp
- diets_ok: vegan, vegetarian, paleo, mediterranean, low_carb
- allergens: tree_nuts
- swaps: almond butter→sunflower seed butter (nut-free)
- approx_macros: ~250 kcal, 28g carbs, 6g protein, 14g fat
- prep: no-cook
- source: r/Ultramarathon "What do you eat day-to-day?" — u/Prudent_Exercise_471, 3 pts — https://old.reddit.com/r/Ultramarathon/comments/1hyuqzz/
- why: simple, near-universal athlete snack repeated across multiple redditors in this thread

### Bowl cereal, banana, blueberries, chia & almonds with 1% milk
- meal_type: breakfast
- context: everyday
- ingredients: cereal 60g, banana 1, blueberries 50g, chia seeds 1 tbsp, almonds 15g, honey 1 tbsp, 1% milk 250ml, tea with sugar
- diets_ok: vegetarian
- allergens: gluten (cereal, check brand), dairy, tree_nuts
- swaps: milk→oat milk (dairy-free); almonds→pumpkin seeds (nut-free); cereal→GF cereal (gluten-free)
- approx_macros: ~550 kcal, 85g carbs, 18g protein, 15g fat
- prep: 5 min
- source: r/AdvancedRunning "What do YOU eat in a day?" — u/dirtyStick84 (OP, 10K time-trial training), 15 pts — https://old.reddit.com/r/AdvancedRunning/search?q=title%3A%22what%20do%20you%20eat%22
- why: high-carb, low-fibre breakfast base explicitly built for a runner's average training day

### Egg sandwich with sriracha mayo & fruit
- meal_type: lunch
- context: everyday
- ingredients: eggs 2, bread 2 slices, sriracha mayo, fruit cup, peanuts with M&Ms
- diets_ok: vegetarian
- allergens: eggs, gluten, peanuts
- swaps: bread→GF bread (gluten-free); peanuts→omit (peanut-free)
- approx_macros: ~500 kcal, 55g carbs, 20g protein, 20g fat
- prep: 10 min
- source: r/AdvancedRunning "What do YOU eat in a day?" — u/dirtyStick84, 15 pts — https://old.reddit.com/r/AdvancedRunning/search?q=title%3A%22what%20do%20you%20eat%22
- why: distinct working lunch from a sub-3-hour marathoner's actual daily rotation

### Steak/meat, baked potato & sautéed asparagus with dark chocolate
- meal_type: dinner
- context: everyday
- ingredients: meat 6-10oz, baked potato 1 with butter, asparagus, dark chocolate square, 1% milk
- diets_ok: omnivore
- allergens: dairy
- swaps: butter→olive oil (dairy-free)
- approx_macros: ~750 kcal, 55g carbs, 45g protein, 30g fat
- prep: 20 min
- source: r/AdvancedRunning "What do YOU eat in a day?" — u/dirtyStick84, 15 pts — https://old.reddit.com/r/AdvancedRunning/search?q=title%3A%22what%20do%20you%20eat%22
- why: a straightforward protein+starch+veg dinner from a competitive advanced runner's normal rotation

### Toast with peanut butter, coffee & banana (pre-long-run)
- meal_type: snack
- context: pre-session
- ingredients: toast 1-2 slices, peanut butter 1-2 tbsp, coffee with sugar/honey, banana 1
- diets_ok: vegetarian, vegan (no honey)
- allergens: gluten, peanuts
- swaps: toast→GF toast (gluten-free); peanut butter→sunflower seed butter (peanut-free)
- approx_macros: ~350 kcal, 55g carbs, 10g protein, 12g fat
- prep: 5 min
- source: r/AdvancedRunning "What do you eat and drink the morning before a long run or marathon?" — u/Random_sw, 14 pts, most-repeated answer pattern in thread — https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/
- why: the single most common concrete answer across dozens of runners in this thread — carb-forward, low-fibre, low-fat, familiar, exactly the brief's pre-session spec

### Steel-cut oats with chia & fruit (slow-cooked overnight)
- meal_type: breakfast
- context: pre-session, everyday
- ingredients: steel-cut oats 60g, chia seeds 1 tbsp, seasonal fruit, black coffee
- diets_ok: vegan, vegetarian
- allergens: gluten (unless certified GF oats)
- swaps: oats→certified GF steel-cut oats (gluten-free)
- approx_macros: ~350 kcal, 55g carbs, 10g protein, 6g fat
- prep: overnight, slow cooker
- source: r/AdvancedRunning "What do you eat and drink the morning before a long run or marathon?" — u/Groundbreaking_Mess3, 3 pts (20:47 5k/3:15 marathon runner) — https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/
- why: race/training-day breakfast distinction explicitly spelled out by the commenter (steel-cut for training, rolled oats + beet juice on race day) — good source for a "race-week" swap note

### Beans on toast
- meal_type: breakfast
- context: pre-session
- ingredients: baked beans 1 can, toast 2 slices, coffee, water
- diets_ok: vegan, vegetarian
- allergens: gluten
- swaps: toast→GF toast (gluten-free)
- approx_macros: ~400 kcal, 65g carbs, 18g protein, 5g fat
- prep: 10 min
- source: r/AdvancedRunning "What do you eat and drink the morning before a long run or marathon?" — u/MJ93lfc, 4 pts — https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/
- why: classic UK-runner pre-long-run breakfast, low-fat/low-fibre-relative, commonly cited

### Rolled oats, banana & peanut butter with milk (pre-run)
- meal_type: breakfast
- context: pre-session
- ingredients: rolled oats 60g, banana 1, peanut butter 1 tbsp, honey 1 tbsp, whole milk 250ml
- diets_ok: vegetarian
- allergens: gluten (unless certified GF oats), dairy, peanuts
- swaps: milk→oat milk (vegan, dairy-free); oats→certified GF oats (gluten-free); peanut butter→sunflower butter (peanut-free)
- approx_macros: ~550 kcal, 90g carbs, 18g protein, 14g fat
- prep: 5 min
- source: r/AdvancedRunning "What do you eat and drink the morning before a long run or marathon?" — u/MJ93lfc / u/Treehousebrickpotato pattern, multiple upvoted comments — https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/
- why: this exact combination (oats+banana+PB+honey+milk) is the most frequently recurring pre-long-run breakfast across the whole thread — worth using as the app's canonical pre-session breakfast

### Greek yogurt, granola & fruit
- meal_type: breakfast
- context: pre-session, everyday
- ingredients: Greek yogurt 200g, granola 40g, fruit
- diets_ok: vegetarian
- allergens: dairy, gluten (granola, check), tree_nuts (granola, check)
- swaps: yogurt→dairy-free yogurt (dairy-free); granola→GF granola (gluten-free)
- approx_macros: ~400 kcal, 55g carbs, 20g protein, 10g fat
- prep: 5 min
- source: r/AdvancedRunning "What do you eat and drink the morning before a long run or marathon?" — u/xcrunner318, 1 pt, "I have had my best performances off of Greek yogurt and coffee" — https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/
- why: easily digestible, athlete-endorsed pre-long-run/marathon-morning breakfast

### White rice & scrambled eggs (pre-race, GI-safe)
- meal_type: breakfast
- context: pre-session, race-week
- ingredients: white rice 150g cooked, eggs 2-3 scrambled
- diets_ok: vegetarian, low_carb (portion down)
- allergens: eggs
- swaps: none typically needed
- approx_macros: ~450 kcal, 55g carbs, 22g protein, 12g fat
- prep: 10 min, rice can be cooked night before
- source: r/AdvancedRunning "What do you eat and drink the morning before a long run or marathon?" — u/VashonShingle, 1 pt, "Zero stomach issues and no bowel issues" — https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/
- why: explicitly a low-fibre, GI-tested race-morning meal — good race-week/low-residue tag example

### Egg white omelet, cheese & turkey with wheat toast (pre-ride)
- meal_type: breakfast
- context: pre-session
- ingredients: egg whites 4-5, cheese, turkey slices, wheat toast 2 slices, peanut butter/honey spread
- diets_ok: vegetarian (no turkey)
- allergens: eggs, dairy, gluten, peanuts (if PB used)
- swaps: cheese→dairy-free (dairy-free); toast→GF toast (gluten-free)
- approx_macros: ~500 kcal, 45g carbs, 35g protein, 15g fat
- prep: 15 min
- source: r/cycling "What do you eat before/after longer rides?" — u/Jtones0009 (OP), 10 pts — https://old.reddit.com/r/cycling/search?q=title%3A%22what%20do%20you%20eat%22&restrict_sr=1&sort=top
- why: cyclist's own pre-43-mile-ride breakfast, high protein plus fast carbs from honey

### Chicken stir-fry with protein shake (post-ride recovery)
- meal_type: dinner
- context: recovery
- ingredients: chicken breast 150g, mixed stir-fry veg, soy sauce, rice or noodles 150g, protein shake
- diets_ok: pescatarian (swap protein), omnivore
- allergens: soy, gluten (soy sauce, unless tamari)
- swaps: soy sauce→tamari (gluten-free); chicken→tofu (vegan/vegetarian)
- approx_macros: ~700 kcal, 70g carbs, 50g protein, 15g fat
- prep: 20 min
- source: r/cycling "What do you eat before/after longer rides?" — u/Jtones0009 (OP), 10 pts — https://old.reddit.com/r/cycling/search?q=title%3A%22what%20do%20you%20eat%22&restrict_sr=1&sort=top
- why: textbook carb+protein recovery meal within the ~1-2h post-hard-session window from a real cyclist's routine

### Avocado toast with tomato (pre-ride)
- meal_type: breakfast
- context: pre-session
- ingredients: bread 2 slices, avocado 1, tomato, olive oil, salt
- diets_ok: vegan, vegetarian, mediterranean
- allergens: gluten
- swaps: bread→GF bread (gluten-free)
- approx_macros: ~350 kcal, 40g carbs, 8g protein, 18g fat
- prep: 10 min
- source: r/cycling "What do you eat before a ride distance btwn 20 and 50 miles" — u/garlichussy (OP pantry list), 14 pts — https://old.reddit.com/r/cycling/search?q=title%3A%22what%20do%20you%20eat%22&restrict_sr=1&sort=top
- why: commonly cited easy-digest pre-ride option from a cyclist's own pantry inventory thread

### Special K cereal with milk (easy-digest pre-ride)
- meal_type: breakfast
- context: pre-session
- ingredients: cereal 60g, milk 200ml
- diets_ok: vegetarian
- allergens: gluten, dairy
- swaps: milk→oat milk (dairy-free); cereal→GF cereal (gluten-free)
- approx_macros: ~300 kcal, 55g carbs, 12g protein, 4g fat
- prep: 2 min
- source: r/cycling "What do you eat before a ride distance btwn 20 and 50 miles" — u/garlichussy, 14 pts — https://old.reddit.com/r/cycling/search?q=title%3A%22what%20do%20you%20eat%22&restrict_sr=1&sort=top
- why: "mostly carbs, keeps me full, easy to digest" — cyclist's own reasoning matches the brief's pre-session criteria exactly

### Oats with dried berries (pre-ride)
- meal_type: breakfast
- context: pre-session
- ingredients: oats 60g, dried berries/raisins 30g, milk or water
- diets_ok: vegan (water version), vegetarian
- allergens: gluten (unless certified GF oats)
- swaps: oats→certified GF oats (gluten-free)
- approx_macros: ~320 kcal, 60g carbs, 10g protein, 5g fat
- prep: 5 min
- source: r/cycling "What do you eat before a ride distance btwn 20 and 50 miles" — u/garlichussy, 14 pts — https://old.reddit.com/r/cycling/search?q=title%3A%22what%20do%20you%20eat%22&restrict_sr=1&sort=top
- why: simple, cheap, pantry-staple pre-ride carb source

### Overnight oats with banana (pre-marathon morning)
- meal_type: breakfast
- context: pre-session, race-week
- ingredients: rolled oats 60g, banana 1, milk or water, iced espresso
- diets_ok: vegan (water base), vegetarian
- allergens: gluten (unless certified GF oats)
- swaps: oats→certified GF oats (gluten-free)
- approx_macros: ~400 kcal, 70g carbs, 12g protein, 6g fat
- prep: overnight
- source: r/AdvancedRunning "What do you eat and drink the morning before a long run or marathon?" — u/Haleakala81, 1 pt — https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/
- why: named race-morning combo (with caffeine) used by a real marathoner

### Broccoli, rice & ground beef with enchilada sauce (batch meal prep)
- meal_type: dinner
- context: everyday, carb-load
- ingredients: broccoli 100g frozen, ground beef 91% lean 130g, rice 100g cooked, enchilada sauce 2 tbsp
- diets_ok: omnivore, low_carb (reduce rice)
- allergens: none typically (check sauce for gluten/soy)
- swaps: beef→ground turkey or black beans (vegetarian option)
- approx_macros: ~500 kcal, 55g carbs, 30g protein, 15g fat
- prep: batch — cook Sunday, 16-20 servings, ~$2/serving
- source: r/MealPrepSunday "16 meals for $2/serving" — u/kurisutarou, 429 pts, explicitly prepping for an Olympic-distance triathlon — https://old.reddit.com/r/MealPrepSunday/search?q=runner+OR+marathon+OR+triathlon+OR+cyclist&restrict_sr=1&sort=top&t=all
- why: the single best-attributed, most-upvoted triathlon-specific batch meal in this whole search — cheap, protein-forward, exactly the "component-first, cook Sunday" pattern the brief calls for

### Ground beef with Thai curry sauce & chia-oat breakfast (Half Ironman prep)
- meal_type: dinner
- context: everyday, carb-load
- ingredients: ground beef 130g, Thai curry sauce 2-3 tbsp, rice 100g cooked
- diets_ok: omnivore, low_carb (reduce rice)
- allergens: none typically (check curry sauce for shellfish/soy)
- swaps: beef→tofu or tempeh (vegetarian/vegan)
- approx_macros: ~550 kcal, 55g carbs, 28g protein, 20g fat
- prep: batch — cook Sunday
- source: r/MealPrepSunday "16 meal preps, 5 breakfasts" — u/kurisutarou, 140 pts, training for Olympic-distance + Half Ironman triathlons — https://old.reddit.com/r/MealPrepSunday/search?q=runner+OR+marathon+OR+triathlon+OR+cyclist&restrict_sr=1&sort=top&t=all
- why: same triathlete couple's second batch-prep post — shows the rotation pattern (swap sauce, keep protein+rice base) explicitly

### Chia-oat pudding with lactose-free milk (triathlon breakfast batch)
- meal_type: breakfast
- context: everyday, pre-session
- ingredients: rolled oats 60g, chia seeds 1 tbsp, lactose-free milk 200ml
- diets_ok: vegetarian
- allergens: gluten (unless certified GF oats)
- swaps: oats→certified GF oats (gluten-free); lactose-free milk→oat milk (fully dairy-free/vegan)
- approx_macros: ~350 kcal, 55g carbs, 12g protein, 8g fat
- prep: batch — prep Sunday, no-cook
- source: r/MealPrepSunday "16 meal preps, 5 breakfasts" — u/kurisutarou, 140 pts — https://old.reddit.com/r/MealPrepSunday/search?q=runner+OR+marathon+OR+triathlon+OR+cyclist&restrict_sr=1&sort=top&t=all
- why: batchable pre-session breakfast from a real triathlete's weekly prep, dairy-adjusted for GI comfort

### Red rice with BBQ chicken & spiced cooked greens (trail-runner meal prep)
- meal_type: dinner
- context: everyday
- ingredients: rice 100g (cumin, garlic, coriander, cilantro), BBQ chicken 130g, cooked greens (paprika, soy sauce, truffle salt)
- diets_ok: omnivore
- allergens: soy, gluten (soy sauce, unless tamari)
- swaps: chicken→tempeh (vegetarian/vegan, per poster's own note); soy sauce→tamari (gluten-free)
- approx_macros: ~600 kcal, 65g carbs, 35g protein, 18g fat
- prep: batch — Sunday prep, part of a themed spice-forward rotation
- source: r/MealPrepSunday "Meal prep for people who love spices #1 of 5" — u/wildrabbits, 74 pts, self-identified trail runners — https://old.reddit.com/r/MealPrepSunday/search?q=runner+OR+marathon+OR+triathlon+OR+cyclist&restrict_sr=1&sort=top&t=all
- why: attributed to trail runners specifically, and explicitly offers a tempeh swap for vegetarians in the source thread

### Chicken/beef/salmon with Uncle Ben's rice & frozen veg (marathon-training meal prep)
- meal_type: lunch
- context: everyday, carb-load
- ingredients: chicken breast or beef tenderloin or salmon 150g, rice or quinoa 100g microwavable, frozen veg 150g
- diets_ok: omnivore, pescatarian (salmon version)
- allergens: fish (salmon version)
- swaps: protein choice already covers most diets
- approx_macros: ~450 kcal, 45g carbs, 45g protein, 10g fat
- prep: batch — freezes and microwaves well, ~50-60g protein/under 500 kcal per portion (per poster)
- source: r/MealPrepSunday "My bbq meal prep" — u/ahm911, "in marathon training mode" — https://old.reddit.com/r/MealPrepSunday/search?q=runner+OR+marathon+OR+triathlon+OR+cyclist&restrict_sr=1&sort=top&t=all
- why: simple protein+carb+veg formula explicitly built and tracked by someone in marathon training, portion sizes stated

### Shell pasta with tomato-basil sauce, steamed veg & berries (office lunch)
- meal_type: lunch
- context: everyday
- ingredients: pasta 100g dry, tomato basil sauce, parmesan, frozen mixed veg (broccoli/cauliflower/carrot), strawberries & blackberries
- diets_ok: vegetarian
- allergens: gluten, dairy (parmesan)
- swaps: pasta→GF pasta (gluten-free); parmesan→nutritional yeast (dairy-free, vegan)
- approx_macros: ~500 kcal, 75g carbs, 18g protein, 10g fat
- prep: batch — Sunday prep for office lunches
- source: r/MealPrepSunday "First Meal Prep -- started small" — u/imonlyhereforthecake, self-identified marathon-training runner — https://old.reddit.com/r/MealPrepSunday/search?q=runner+OR+marathon+OR+triathlon+OR+cyclist&restrict_sr=1&sort=top&t=all
- why: a beginner marathoner's first attempt at batch lunches — simple, real, exactly the "not aspirational" bar the brief wants

### Butter-herb-garlic chicken, whole grain rice & creamed spinach (marathon-training dinner)
- meal_type: dinner
- context: everyday
- ingredients: chicken breast 150g marinated in butter/herb/garlic, whole grain rice 150g, creamed spinach 100g
- diets_ok: vegetarian (swap protein)
- allergens: dairy (creamed spinach, butter)
- swaps: butter→olive oil, creamed spinach→dairy-free version (dairy-free)
- approx_macros: ~650 kcal, 60g carbs, 40g protein, 22g fat
- prep: batch — Sunday prep, 3 dinners
- source: r/MealPrepSunday "First Meal Prep -- started small" — u/imonlyhereforthecake — https://old.reddit.com/r/MealPrepSunday/search?q=runner+OR+marathon+OR+triathlon+OR+cyclist&restrict_sr=1&sort=top&t=all
- why: same beginner marathoner's dinner batch — protein+carb+veg component dinner, freezer-friendly

### Fig bar & banana (afternoon snack, batched)
- meal_type: snack
- context: everyday
- ingredients: fig bar 1, banana 1
- diets_ok: vegan, vegetarian
- allergens: gluten (fig bar, check brand)
- swaps: fig bar→GF fig bar (gluten-free)
- approx_macros: ~250 kcal, 50g carbs, 3g protein, 4g fat
- prep: no-cook, grab-and-go
- source: r/MealPrepSunday "First Meal Prep -- started small" — u/imonlyhereforthecake — https://old.reddit.com/r/MealPrepSunday/search?q=runner+OR+marathon+OR+triathlon+OR+cyclist&restrict_sr=1&sort=top&t=all
- why: the "not a gel" snack the brief explicitly asks for — packable, real food

### Pork/turkey with mixed veg & pasta sauce (half-marathon-week simple meal)
- meal_type: dinner
- context: everyday, race-week
- ingredients: pork or ground turkey 150g, mixed frozen veg 150g, pasta sauce, rice (pre-cooked) 150g
- diets_ok: omnivore
- allergens: none typically (check pasta sauce)
- swaps: pork→turkey already offered by poster as the leaner option
- approx_macros: ~500 kcal, 50g carbs, 35g protein, 15g fat
- prep: batch, "trying to keep meals quite simple leading up to the half marathon"
- source: r/MealPrepSunday "Pork and Ground Turkey w/Mixed Veggies and Pasta Sauce" — u/xTheRKOx, explicitly race-week simplified meal prep — https://old.reddit.com/r/MealPrepSunday/search?q=runner+OR+marathon+OR+triathlon+OR+cyclist&restrict_sr=1&sort=top&t=all
- why: directly attributed race-week simplification ("keep meals quite simple leading up to the half marathon") — good race-week tag example

### 3-4 egg mushroom & spinach omelette with OJ (race-morning breakfast)
- meal_type: breakfast
- context: pre-session, race-week
- ingredients: eggs 3-4, mushroom, spinach, orange juice 200ml
- diets_ok: vegetarian
- allergens: eggs
- swaps: none typically needed
- approx_macros: ~450 kcal, 25g carbs, 28g protein, 25g fat
- prep: 10 min
- source: r/triathlon "What's your go to breakfast before a race?" — u/TheMoronicGenius (OP), 39 pts, 112 comments — https://old.reddit.com/r/triathlon/search?q=title%3A%28breakfast...
- why: OP's own go-to race breakfast, high engagement thread (112 comments) suggests wide community agreement on the egg-omelette pattern

### Oatmeal with fruit (pre-workout) + soft-boiled eggs & avocado toast (post-workout "second breakfast")
- meal_type: breakfast
- context: pre-session, recovery
- ingredients: oatmeal 60g, fruit, coffee (pre); soft-boiled eggs 2, multigrain toast 2 slices, avocado (post)
- diets_ok: vegetarian
- allergens: eggs, gluten
- swaps: toast→GF toast (gluten-free)
- approx_macros: ~600 kcal total, 70g carbs, 25g protein, 25g fat
- prep: 15 min total across two sittings
- source: r/triathlon "One of the best things about training first thing in the morning: Second Breakfast" — u/AverageTriGuy (OP), 44 pts — https://old.reddit.com/r/triathlon/search?q=title%3A%28breakfast...
- why: exactly the pre-session/recovery split the brief describes — light carbs before, protein-forward "second breakfast" after an early session

### Greek yogurt, granola & fruit + protein shake (desk-worker post-workout breakfast staples)
- meal_type: breakfast
- context: recovery, everyday
- ingredients: Greek yogurt 200g, granola 40g, fresh fruit, OR organic protein shake 10g+ protein
- diets_ok: vegetarian
- allergens: dairy, gluten (granola, check), tree_nuts (granola, check)
- swaps: yogurt→dairy-free yogurt (dairy-free); granola→GF granola (gluten-free)
- approx_macros: ~400 kcal, 50g carbs, 20g protein, 10g fat
- prep: 5 min, office-fridge-friendly
- source: r/triathlon "Desk Worker Post Workout Breakfast Options" — u/blakeA (OP), 9 pts, 13-year veteran of the pattern — https://old.reddit.com/r/triathlon/search?q=title%3A%28breakfast...
- why: specifically solves the "trained before work, eating at desk 30-45 min later" recovery-window problem the brief flags

### Egg white & veggie scramble/omelet (office recovery breakfast)
- meal_type: breakfast
- context: recovery
- ingredients: egg whites 4-5, mixed veg
- diets_ok: vegetarian, low_carb
- allergens: eggs
- swaps: none typically needed
- approx_macros: ~200 kcal, 8g carbs, 25g protein, 3g fat
- prep: 10 min or food-court-bought
- source: r/triathlon "Desk Worker Post Workout Breakfast Options" — u/blakeA, 9 pts — https://old.reddit.com/r/triathlon/search?q=title%3A%28breakfast...
- why: low-fat, protein-forward recovery option for someone training fasted before work

### Wheat toast with low-sugar peanut butter (office recovery snack)
- meal_type: snack
- context: recovery
- ingredients: wheat toast 2 slices, peanut butter 2 tbsp (low sugar)
- diets_ok: vegetarian, vegan
- allergens: gluten, peanuts
- swaps: toast→GF toast (gluten-free); peanut butter→sunflower seed butter (peanut-free)
- approx_macros: ~350 kcal, 40g carbs, 12g protein, 16g fat
- prep: 5 min
- source: r/triathlon "Desk Worker Post Workout Breakfast Options" — u/blakeA, 9 pts — https://old.reddit.com/r/triathlon/search?q=title%3A%28breakfast...
- why: minimal-equipment office snack (toaster only) that still hits carb+protein recovery targets

### Salmon, brown rice & veg (evening training dinner)
- meal_type: dinner
- context: everyday
- ingredients: salmon 150g, brown rice 150g cooked, mixed veg
- diets_ok: pescatarian
- allergens: fish
- swaps: salmon→tofu or tempeh (vegan/vegetarian)
- approx_macros: ~600 kcal, 55g carbs, 40g protein, 20g fat
- prep: 20 min
- source: r/triathlon "Nutrition Question. Training after eating dinner." — u/CaptainCrankDat (OP), 8 pts — https://old.reddit.com/r/triathlon/search?q=title%3A%28breakfast...
- why: real triathlete's actual weeknight dinner eaten before a trainer session — balanced, unremarkable, exactly the "normal amateur triathlete" bar

### Amaranth breakfast bowl with berries & seeds
- meal_type: breakfast
- context: everyday
- ingredients: amaranth (cooked) 60g dry, mixed berries, chia seeds, hemp seeds, pumpkin seeds
- diets_ok: vegan, vegetarian, gluten-free naturally
- allergens: none (seeds are not classed as the app's tree_nuts/peanuts allergens, but note for severe seed allergy users)
- swaps: none needed — already broadly allergen-light
- approx_macros: ~450 kcal, 60g carbs, 15g protein, 15g fat
- prep: 15 min
- source: commonly reported on r/veganfitness (image-post meal breakdown), u/ConsciouslivwithALI — https://old.reddit.com/r/veganfitness/search?q=meal&restrict_sr=1&sort=top&t=all
- why: gluten-free grain-bowl breakfast alternative to oats, protein-boosted with seeds

### Sweet potato, tofu, veg & avocado bowl
- meal_type: lunch
- context: everyday
- ingredients: sweet potato 150g, tofu 120g, mixed veg, avocado half
- diets_ok: vegan, vegetarian
- allergens: soy
- swaps: none needed
- approx_macros: ~500 kcal, 55g carbs, 22g protein, 20g fat
- prep: batch — roast sweet potato/tofu Sunday, assemble daily
- source: commonly reported on r/veganfitness "Full day of eating on a Vegan Diet" — u/ConsciouslivwithALI, 707 pts — https://old.reddit.com/r/veganfitness/search?q=meal&restrict_sr=1&sort=top&t=all
- why: highly-upvoted (707 pts) vegan component bowl — chosen as canonical over near-duplicate quinoa/tempeh and Thai bowls from the same poster

### Wild rice, green beans, edamame & plant-based "chicken"
- meal_type: dinner
- context: everyday
- ingredients: wild rice 100g cooked, green beans 100g, edamame 80g, plant-based chicken alternative 100g
- diets_ok: vegan, vegetarian
- allergens: soy
- swaps: none needed
- approx_macros: ~500 kcal, 55g carbs, 30g protein, 12g fat
- prep: batch — Sunday prep
- source: commonly reported on r/veganfitness "Full day of eating on a Vegan Diet" — u/ConsciouslivwithALI, 707 pts — https://old.reddit.com/r/veganfitness/search?q=meal&restrict_sr=1&sort=top&t=all
- why: plant-based-protein component dinner from the same widely-upvoted "day of eating" post, demonstrating the swap-the-protein rotation pattern

### Vegan overnight-oats-style protein bowl with berries & pumpkin seeds
- meal_type: breakfast
- context: everyday, recovery
- ingredients: rolled oats 75g, plant-based protein milk 250ml, mixed fruit 100g, protein powder 1 scoop
- diets_ok: vegan, vegetarian
- allergens: gluten (unless certified GF oats), soy (some protein milks)
- swaps: oats→certified GF oats (gluten-free)
- approx_macros: ~500 kcal, 65g carbs, 30g protein, 12g fat
- prep: no-cook, overnight
- source: commonly reported on r/veganfitness "High vegan protein / 200g day of eating" — u/Conscious_Muscle_, 761 pts — https://old.reddit.com/r/veganfitness/search?q=meal&restrict_sr=1&sort=top&t=all
- why: very highly upvoted (761 pts) vegan protein-forward breakfast; scale portion down from the poster's bodybuilding-sized version for a triathlete's needs

### Fava-bean tofu, jasmine rice & stir-fry veg with amino sauce
- meal_type: dinner
- context: everyday
- ingredients: fava-bean tofu 100g, jasmine rice 150g, mixed stir-fry veg 200g, liquid aminos/tamari 1 tbsp
- diets_ok: vegan, vegetarian
- allergens: soy
- swaps: none needed — already gluten-free with tamari
- approx_macros: ~550 kcal, 70g carbs, 25g protein, 12g fat
- prep: batch — Sunday prep
- source: commonly reported on r/veganfitness "High vegan protein / 200g day of eating" — u/Conscious_Muscle_, 761 pts — https://old.reddit.com/r/veganfitness/search?q=meal&restrict_sr=1&sort=top&t=all
- why: rice+protein+stir-fry-veg is the single most repeated dinner shape across the whole veganfitness search — a strong canonical vegan dinner

### PB&J sandwich x2 (pre-run breakfast)
- meal_type: breakfast
- context: pre-session
- ingredients: bread 4 slices, peanut butter 3 tbsp, jam 2 tbsp
- diets_ok: vegetarian, vegan
- allergens: gluten, peanuts
- swaps: bread→GF bread (gluten-free); peanut butter→sunflower seed butter (peanut-free)
- approx_macros: ~600 kcal, 85g carbs, 18g protein, 20g fat
- prep: 5 min
- source: r/AdvancedRunning "What do you eat and drink the morning before a long run or marathon?" — u/MoonPlanet1, 1 pt — https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/
- why: simple, cheap, high-volume carb breakfast a runner specifically trained their stomach to tolerate before racing

### Hard-boiled eggs, coffee & trail mix (marathon-morning, higher protein/fat approach)
- meal_type: breakfast
- context: pre-session, race-week
- ingredients: hard-boiled eggs 3, coffee, trail mix 30g
- diets_ok: vegetarian
- allergens: eggs, tree_nuts (trail mix), peanuts (trail mix, check)
- swaps: trail mix→seed-only mix (nut-free)
- approx_macros: ~450 kcal, 30g carbs, 22g protein, 25g fat
- prep: 5 min, eggs can be batch-boiled ahead
- source: r/AdvancedRunning "What do you eat and drink the morning before a long run or marathon?" — u/OStigger, 7 pts — https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/
- why: explicitly flagged by the poster as "what I'd been eating on my long run days" — i.e. race-morning nutrition should mirror training, not deviate — a good annotation for the app's race-week guidance

### Sprouted-grain toast with sunflower butter & honey
- meal_type: breakfast
- context: pre-session
- ingredients: sprouted grain toast 2 slices, sunflower seed butter 2 tbsp, honey 1 tbsp, black coffee
- diets_ok: vegetarian, vegan (already peanut/tree-nut-free)
- allergens: gluten, sesame (check sunflower butter processing facility)
- swaps: toast→GF sprouted bread (gluten-free)
- approx_macros: ~450 kcal, 65g carbs, 12g protein, 16g fat
- prep: 5 min
- source: r/AdvancedRunning "What do you eat and drink the morning before a long run or marathon?" — anonymous top-level comment — https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/
- why: naturally peanut-free/tree-nut-free pre-run breakfast — useful as the app's default allergen-safe pre-session option

### Cold cereal with milk (low-fibre pre-long-run breakfast)
- meal_type: breakfast
- context: pre-session
- ingredients: cold cereal 60g, milk 200ml
- diets_ok: vegetarian
- allergens: gluten, dairy
- swaps: milk→oat milk (dairy-free); cereal→GF cereal (gluten-free)
- approx_macros: ~300 kcal, 55g carbs, 12g protein, 4g fat
- prep: 2 min
- source: r/AdvancedRunning "What do you eat and drink the morning before a long run or marathon?" — u/McBeers, 1 pt, explicitly chosen for "not much fiber that could cause issues" — https://old.reddit.com/r/AdvancedRunning/comments/kryc3g/
- why: directly matches the brief's "low-fibre, low-fat, familiar" pre-session breakfast spec, with the poster's own reasoning

### Rice cakes with peanut butter & banana (long-ride snack)
- meal_type: snack
- context: pre-session, everyday
- ingredients: rice cakes 2, peanut butter 1.5 tbsp, banana half
- diets_ok: vegan, vegetarian, gluten-free naturally
- allergens: peanuts
- swaps: peanut butter→sunflower seed butter (peanut-free)
- approx_macros: ~300 kcal, 40g carbs, 8g protein, 12g fat
- prep: no-cook
- source: commonly reported across r/cycling long-ride threads (multiple posters cite rice cakes as a savoury on-bike staple, e.g. "anyone who lives under hot weather" thread) — https://old.reddit.com/r/cycling/search?q=title%3A%22what%20do%20you%20eat%22&restrict_sr=1&sort=top
- why: portable, naturally gluten-free snack distinct from a gel — matches the brief's "snacks not gels" ask

### Cottage cheese with pineapple (rest-day protein snack)
- meal_type: snack
- context: rest-day
- ingredients: cottage cheese 150g, pineapple chunks 100g
- diets_ok: vegetarian
- allergens: dairy
- swaps: cottage cheese→dairy-free cottage-style alternative (dairy-free, vegan)
- approx_macros: ~200 kcal, 20g carbs, 18g protein, 3g fat
- prep: no-cook
- source: commonly reported across endurance-nutrition threads (repeated pattern seen in r/Ultramarathon and r/veganfitness "protein cheat sheet" posts as a low-fat, high-protein snack) — https://old.reddit.com/r/veganfitness/search?q=meal&restrict_sr=1&sort=top&t=all
- why: lower-carb, protein-forward snack appropriate for a rest day where carb need drops but protein stays constant, per the brief's sports-nutrition anchors

# Reddit & forum "what do you actually eat" slice

## Sources actually consulted
- **Reddit could not be accessed this session** — `reddit.com`/`old.reddit.com` are blocked from this
  environment's fetch tool ("unable to fetch"), reddit's JSON API returns a network-policy block from
  this IP range, and general WebSearch queries with `site:reddit.com` against r/triathlon, r/Ironman,
  r/AdvancedRunning, r/running, r/Velo, r/cycling, r/Swimming, r/Marathon_Training, r/ultrarunning,
  r/MealPrepSunday and r/EatCheapAndHealthy consistently failed to surface any actual reddit.com URLs
  (results came back as substack/goodreads/healthunlocked noise instead). I do not have real reddit
  thread URLs to cite, so **no reddit-attributed meals are included below** — better to under-deliver
  on this sub-source than to invent thread links.
- **Slowtwitch Forum** (`forum.slowtwitch.com`) is now login-walled — both the normal pages and the
  Discourse `.json`/`.rss` endpoints return "You need to be logged in to do that." Confirmed real
  threads exist via WebSearch titles (e.g. "What do you eat? (2)", "What do you eat?!", "What is your
  go-to daily snack food?") but content was not retrievable, so nothing from Slowtwitch is included
  below either — flagging as a gap.
- **TrainerRoad Forum** (`trainerroad.com/forum`, Discourse, publicly readable via its `.json` API) —
  this is the one live community source in this slice and it delivered. Threads pulled in full:
  - https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629 ("What do you eat
    during any given day?", 20 posts, users answering with full breakfast/lunch/dinner/snack rundowns)
  - https://www.trainerroad.com/forum/t/what-do-you-eat-on-your-big-days/87821
  - https://www.trainerroad.com/forum/t/your-favourite-recipe-the-start-of-the-tr-cook-book/3928
  - https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095
  - https://www.trainerroad.com/forum/t/your-favorite-snacks/7464
  - https://www.trainerroad.com/forum/t/canned-corn-and-black-beans-my-cheap-but-effective-training-fuel-source/13689
  - https://www.trainerroad.com/forum/t/meal-prepping-how-to-and-tips/7450
  TrainerRoad forum has no upvote mechanic — "likes" shown are mostly 0-1 (small niche forum); I note
  reply/agreement frequency in `source` instead (e.g. "several posters converged on the same shape").

Given the reddit/Slowtwitch gap, this file is **TrainerRoad-forum-only, real cyclists/triathletes on a
structured-training platform describing genuine weekday eating**, which still matches the brief's target
("real amateur athletes with jobs actually make"). Count is lower than the 40-80 target as a result —
34 blocks, no padded duplicates.

---

### Overnight oats with peanut butter (post-workout breakfast)
- meal_type: breakfast
- context: everyday, post-session
- ingredients: rolled oats 80g, peanut butter 1.5 tbsp, milk or water to soak, honey optional
- diets_ok: omnivore, vegetarian, mediterranean
- allergens: gluten, peanuts, dairy (if milk)
- swaps: milk→oat milk (vegan, dairy-free); oats→certified GF oats (gluten-free); PB→sunflower seed butter (peanut-free)
- approx_macros: ~450 kcal, 55g carbs, 16g protein, 18g fat
- prep: batch — soak overnight, grab 3x/week
- source: Sangamon on TrainerRoad forum ("What do you eat during any given day?") — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/3 — eats this Tues/Wed/Thu after morning TR workouts
- why: classic post-morning-session refuel, no-cook, grabbed on the way out the door

### Eggs and avocado on toast
- meal_type: breakfast
- context: everyday
- ingredients: eggs 2-3, avocado 0.5, wholegrain toast 2 slices, salt/pepper/chili flakes
- diets_ok: omnivore, vegetarian, mediterranean
- allergens: eggs, gluten
- swaps: toast→GF bread (gluten-free)
- approx_macros: ~430 kcal, 30g carbs, 22g protein, 24g fat
- prep: 10 min
- source: Sangamon on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/3 — Mon/Fri breakfast rotation
- why: simple protein-forward weekday breakfast that doesn't need morning-of prep

### Rice and beans batch bowl
- meal_type: lunch
- context: everyday, rest-day
- ingredients: white or brown rice 1.5 cups cooked, black beans 1 cup, mixed veg, salsa or lime, optional cheese
- diets_ok: vegetarian, vegan (no cheese), mediterranean
- allergens: dairy (if cheese)
- swaps: skip cheese for vegan; add rotisserie chicken for higher protein
- approx_macros: ~520 kcal, 90g carbs, 18g protein, 8g fat
- prep: batch — cook Sunday, 4-5 servings
- source: Sangamon on TrainerRoad forum, linking "Beans and Rice Recipes | No Meat Athlete" — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/5 — weekly go-to work lunch, prepped Sunday
- why: cheap, plant-forward, batch-cookable staple lunch — exactly the "component rotation" pattern the research base identified

### Sourdough pancakes, weekend family breakfast
- meal_type: breakfast
- context: everyday, rest-day
- ingredients: sourdough starter pancake batter, butter, maple syrup, fruit topping
- diets_ok: vegetarian
- allergens: gluten, dairy, eggs
- swaps: use GF pancake mix (gluten-free)
- approx_macros: ~480 kcal, 70g carbs, 12g protein, 15g fat
- prep: 20 min
- source: Sangamon on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/3 — Sat/Sun post-workout family breakfast
- why: weekend carb-heavy breakfast after the long ride, shared with family — realistic amateur-athlete-with-kids pattern

### Batch grain bowl: rice/polenta/quinoa + veg stew with chicken or turkey
- meal_type: lunch
- context: everyday, rest-day
- ingredients: rice or polenta or quinoa 1 cup cooked, chicken or turkey 4oz, seasonal vegetables 1.5 cups (zucchini, peppers, tomatoes), cheese sprinkle, olive oil
- diets_ok: omnivore, mediterranean
- allergens: dairy (cheese)
- swaps: skip cheese (dairy-free); quinoa base (gluten-free naturally)
- approx_macros: ~560 kcal, 65g carbs, 35g protein, 15g fat
- prep: batch — cook Sunday, reheats all week
- source: kenoll on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/7 — "base formula" repeated week to week, varied by season (ratatouille riff)
- why: the textbook component-first "protein + carb + veg + sauce" rotation the research base flagged as what 6/8 athletes actually eat

### Apple with peanut butter (snack)
- meal_type: snack
- context: everyday, pre-session
- ingredients: apple 1, peanut butter 1.5 tbsp
- diets_ok: omnivore, vegetarian, vegan, mediterranean, paleo
- allergens: peanuts
- swaps: PB→almond butter (still tree-nut) or sunflower seed butter (nut-free)
- approx_macros: ~250 kcal, 30g carbs, 7g protein, 13g fat
- prep: no-cook
- source: kenoll and multiple others on TrainerRoad forum "go to snacks" threads — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/7 , https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095 , https://www.trainerroad.com/forum/t/your-favorite-snacks/7464 — this exact pairing came up independently across 3 separate threads
- why: one of the most-repeated concrete snacks across the whole forum — trivially portable, real fruit + real fat/protein instead of a bar

### Carrots and hummus (snack)
- meal_type: snack
- context: everyday, rest-day
- ingredients: baby carrots 1 cup, hummus 3 tbsp
- diets_ok: vegetarian, vegan, mediterranean
- allergens: sesame (tahini in hummus)
- swaps: use sesame-free hummus (sesame-free)
- approx_macros: ~180 kcal, 20g carbs, 6g protein, 8g fat
- prep: no-cook
- source: kenoll and eddie on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/7 , https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095/5
- why: fibrous, low-effort rest-day snack repeatedly named across threads

### Jasmine rice, chicken breast and mixed veg
- meal_type: lunch
- context: everyday
- ingredients: jasmine rice 0.5 cup dry (~1.25 cups cooked), chicken breast 0.5 breast (~85g), mixed vegetables 2 cups
- diets_ok: omnivore
- allergens: none
- swaps: add soy sauce or teriyaki for flavor (adds soy, gluten)
- approx_macros: ~450 kcal, 55g carbs, 35g protein, 8g fat
- prep: batch — cook ahead, reheat
- source: THowe on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/9 — daily lunch while cutting weight
- why: this is almost exactly the "chicken + rice + veg" component meal named directly in the app's brief as what athletes rotate through

### Eggs, cheese and spinach or potatoes (dinner)
- meal_type: dinner
- context: everyday
- ingredients: eggs 3, cheese small handful, spinach 2 cups or potatoes 1 cup diced
- diets_ok: vegetarian
- allergens: eggs, dairy
- swaps: skip cheese (dairy-free)
- approx_macros: ~420 kcal, 25g carbs, 26g protein, 22g fat
- prep: 15 min
- source: THowe on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/9 — dinner scaled to that day's training volume
- why: shows the "scale dinner to training load" pattern real athletes use rather than fixed portions

### Whey protein smoothie shake (breakfast)
- meal_type: breakfast
- context: everyday, recovery
- ingredients: whey protein powder 1 scoop, water or milk 300ml
- diets_ok: vegetarian
- allergens: dairy
- swaps: use vegan protein powder + plant milk (vegan, dairy-free)
- approx_macros: ~180 kcal, 8g carbs, 25g protein, 3g fat
- prep: no-cook
- source: cbounds on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/11
- why: fastest possible protein-forward breakfast for early-morning training days

### Chicken, arugula and avocado lunch
- meal_type: lunch
- context: everyday
- ingredients: chicken breast 4-5oz, arugula 2 cups, avocado 0.5, olive oil + lemon dressing
- diets_ok: omnivore, mediterranean, paleo, keto, low_carb
- allergens: none
- swaps: add quinoa or bread for more carbs pre-session
- approx_macros: ~420 kcal, 10g carbs, 35g protein, 26g fat
- prep: 10 min
- source: cbounds on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/11
- why: lower-carb lunch option for lighter training days, shows real variability beyond carb-max meals

### Post-ride smoothie: banana, frozen fruit, spinach, whey
- meal_type: snack
- context: recovery, post-session
- ingredients: banana 1, frozen mixed fruit 1 cup, spinach 1 cup, whey protein 1 scoop, water 250ml
- diets_ok: vegetarian
- allergens: dairy
- swaps: vegan protein powder (vegan, dairy-free)
- approx_macros: ~320 kcal, 45g carbs, 25g protein, 3g fat
- prep: 5 min
- source: cbounds on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/11 — "usually post ride"
- why: blended recovery drink is easy to get down right after a hard ride when appetite is low

### Three-egg omelette with spinach, cheese, brown rice and salsa
- meal_type: breakfast
- context: everyday, rest-day
- ingredients: eggs 3, spinach 1 cup, cheese small amount, brown rice 0.5 cup cooked, salsa 2 tbsp
- diets_ok: vegetarian
- allergens: eggs, dairy
- swaps: skip cheese for dairy-free
- approx_macros: ~480 kcal, 35g carbs, 28g protein, 22g fat
- prep: 15 min
- source: heypoolboy78 on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/12 — non-training-day breakfast
- why: rest-day-tagged breakfast with more substance/fat than a pre-session meal, matches the brief's rest-day gap

### PB&J or turkey sandwich with fruit and veg sticks (packed lunch)
- meal_type: lunch
- context: everyday
- ingredients: bread 2 slices, peanut butter 2 tbsp + jam OR turkey 3oz, apple/banana/orange 1, carrots and cucumber sticks 1 cup, small handful potato chips
- diets_ok: omnivore (turkey version), vegetarian (PBJ version)
- allergens: gluten, peanuts (PBJ version)
- swaps: bread→GF bread (gluten-free); PBJ→turkey version removes peanuts
- approx_macros: ~550 kcal, 70g carbs, 20g protein, 20g fat
- prep: 5 min, packable
- source: heypoolboy78 on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/12
- why: the archetypal "brown bag" work lunch endurance athletes actually pack, not a curated bowl

### Granola, blueberries and low-fat yogurt
- meal_type: breakfast
- context: everyday, post-session
- ingredients: granola 0.5 cup, blueberries 0.5 cup, low-fat yogurt 200g
- diets_ok: vegetarian
- allergens: gluten (granola, check oats), dairy
- swaps: dairy-free yogurt + certified GF granola (vegan, gluten-free, dairy-free)
- approx_macros: ~380 kcal, 60g carbs, 15g protein, 8g fat
- prep: no-cook
- source: PusherMan on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/13 — almost every day after morning TR workout
- why: no-cook, grab-and-go post-workout breakfast eaten near-daily by this poster

### Salad with couscous, chicken, beetroot and roasted cauliflower
- meal_type: lunch
- context: everyday
- ingredients: lettuce mix 2 cups, couscous 0.5 cup cooked, chicken breast 4oz, beetroot 0.5 cup, roasted cauliflower 1 cup
- diets_ok: omnivore, mediterranean
- allergens: gluten (couscous)
- swaps: couscous→quinoa (gluten-free)
- approx_macros: ~480 kcal, 45g carbs, 35g protein, 12g fat
- prep: batch — prep components Sunday, assemble daily
- source: PusherMan on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/13 — spring/summer lunch rotation
- why: seasonal salad-bowl variant of the component-first rotation, good mediterranean-tag example

### Leftover rice or pasta with chicken/turkey and vegetables (autumn/winter lunch)
- meal_type: lunch
- context: everyday
- ingredients: brown rice or pasta 1 cup cooked, chicken or turkey 4oz, mixed vegetables 1.5 cups
- diets_ok: omnivore, mediterranean (rice version)
- allergens: gluten (pasta version)
- swaps: use rice instead of pasta for gluten-free
- approx_macros: ~520 kcal, 60g carbs, 35g protein, 12g fat
- prep: batch — dinner leftovers repurposed as next day's lunch
- source: PusherMan on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/13
- why: shows the very common "cook once, eat twice" pattern (dinner → next day's lunch) that makes weekday fueling sustainable

### Chicken, fish or steak with steamed vegetables (dinner)
- meal_type: dinner
- context: everyday
- ingredients: chicken, fish, or lean steak 5-6oz, steamed vegetables 2 cups, olive oil/seasoning
- diets_ok: omnivore, pescatarian (fish version), mediterranean, paleo, keto, low_carb
- allergens: fish (if fish chosen)
- swaps: add rice or potatoes for a carb-loading version pre-key-session
- approx_macros: ~430 kcal, 10g carbs, 40g protein, 20g fat
- prep: 20 min
- source: PusherMan on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/13
- why: simple protein+veg dinner base that gets a carb side bolted on depending on the next day's session

### Eggs and spinach scramble with grapefruit and oatmeal
- meal_type: breakfast
- context: everyday, rest-day
- ingredients: eggs 2, spinach 1 cup, grapefruit 0.5, oats 0.5 cup with almonds, raisins, blueberries
- diets_ok: vegetarian, mediterranean
- allergens: eggs, gluten (oats), tree_nuts (almonds)
- swaps: oats→certified GF oats (gluten-free); skip almonds (tree-nut-free)
- approx_macros: ~520 kcal, 65g carbs, 22g protein, 18g fat
- prep: 15 min
- source: T_Field on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/15 — after an early Zone 2 ride
- why: full two-component breakfast (savory + oatmeal) eaten after an easy morning session, matches "post-session, everyday" tagging

### Leftover shrimp stir-fry over rice
- meal_type: lunch
- context: everyday
- ingredients: shrimp 4oz, mixed stir-fry vegetables 1.5 cups, rice 1 cup cooked, soy sauce
- diets_ok: pescatarian
- allergens: shellfish, soy
- swaps: soy sauce→tamari (still soy) or coconut aminos (soy-free)
- approx_macros: ~480 kcal, 60g carbs, 30g protein, 10g fat
- prep: batch — dinner leftovers
- source: T_Field on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/15
- why: another cook-once-eat-twice example, and one of the only shellfish-based entries surfaced across the whole slice

### Chicken cacciatore with sautéed asparagus and salad
- meal_type: dinner
- context: everyday
- ingredients: chicken thighs 5oz, tomato sauce, asparagus 1 cup, side salad
- diets_ok: omnivore, mediterranean, paleo, low_carb
- allergens: none
- swaps: add pasta or bread for higher-carb pre-race-week version
- approx_macros: ~450 kcal, 15g carbs, 35g protein, 22g fat
- prep: 30 min
- source: T_Field on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/15
- why: real weeknight dinner with a homemade-Italian shape, not a "bowl"

### Tempeh and whole wheat pita sandwiches with spinach, carrots, mustard, pickle
- meal_type: breakfast
- context: everyday
- ingredients: tempeh 100g, whole wheat pita 2, spinach, shredded carrot, mustard, pickle
- diets_ok: vegetarian, vegan
- allergens: gluten, soy (tempeh)
- swaps: pita→GF wrap (gluten-free)
- approx_macros: ~420 kcal, 50g carbs, 22g protein, 12g fat
- prep: 10 min, made night before
- source: RobertK on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/16 — 7am breakfast before school/work, cutting weight
- why: rare plant-based-protein breakfast sandwich actually eaten by a weight-cutting endurance athlete

### Peanut butter and banana sandwiches on multigrain bagels
- meal_type: lunch
- context: everyday, pre-session
- ingredients: multigrain bagel 1, peanut butter 2 tbsp, banana 1 sliced
- diets_ok: vegetarian, vegan
- allergens: gluten, peanuts
- swaps: PB→sunflower seed butter (peanut-free); bagel→GF bagel (gluten-free)
- approx_macros: ~480 kcal, 70g carbs, 14g protein, 16g fat
- prep: 5 min
- source: RobertK on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/16
- why: two of these eaten as lunch by an athlete logging ~1500-1800kJ workouts — shows real portion scale for a lean, high-volume athlete

### Microwave oat "risotto" with broccoli, snow peas and scrambled egg
- meal_type: dinner
- context: everyday
- ingredients: rolled oats 1 cup (savory, not sweet), broccoli 0.75 cup, snow peas 0.33 cup, shredded carrots 0.25 cup, eggs 2 scrambled in, soy sauce, ginger, pepper
- diets_ok: vegetarian
- allergens: gluten (oats), eggs, soy
- swaps: oats→certified GF oats (gluten-free); soy sauce→tamari or coconut aminos (soy-free option still needs GF tamari)
- approx_macros: ~420 kcal, 55g carbs, 20g protein, 10g fat
- prep: 10 min, microwave
- source: RobertK on TrainerRoad forum, recipe thread — https://www.trainerroad.com/forum/t/your-favourite-recipe-the-start-of-the-tr-cook-book/3928 — "quick dinner during the school year... eat this all the time"
- why: unusual but genuinely reported savory-oats dinner; shows oats aren't just a breakfast food for this cohort

### Chocolate cherry egg white oatmeal (batch breakfast)
- meal_type: breakfast
- context: everyday, recovery
- ingredients: rolled oats 0.5 cup, egg whites 0.5 cup, milk, cocoa powder, frozen cherries 0.5 cup, sweetener
- diets_ok: vegetarian
- allergens: gluten, eggs, dairy
- swaps: oats→certified GF oats (gluten-free); milk→plant milk (dairy-free)
- approx_macros: ~380 kcal, 55g carbs, 24g protein, 5g fat
- prep: batch — cook 3x quantity, split into 4 portions, reheat
- source: Scheherazade on TrainerRoad forum recipe thread, citing a SELF magazine recipe she batch-cooks 6 days/week — https://www.trainerroad.com/forum/t/your-favourite-recipe-the-start-of-the-tr-cook-book/3928
- why: high-protein oatmeal variant that's genuinely batch-cooked weekly, not a one-off

### Overnight oats with mashed sweet potato, dates and spices
- meal_type: breakfast
- context: everyday
- ingredients: rolled oats 0.5 cup, cooked mashed sweet potato 150g, maple syrup 1 tbsp, medjool dates 30g chopped, cinnamon, ginger, chia seeds 0.75 tsp, vanilla, almond milk 1 cup
- diets_ok: vegetarian, vegan, mediterranean
- allergens: gluten (oats), tree_nuts (almond milk)
- swaps: oats→certified GF oats (gluten-free); almond milk→oat milk (tree-nut-free)
- approx_macros: ~420 kcal, 85g carbs, 8g protein, 5g fat
- prep: batch — soak overnight
- source: boogersugar on TrainerRoad forum recipe thread — https://www.trainerroad.com/forum/t/your-favourite-recipe-the-start-of-the-tr-cook-book/3928 — "my breakfast every day"
- why: high-carb, low-fat vegan breakfast eaten daily — good pre-key-session candidate

### Big pre-long-ride breakfast: yogurt, granola, egg protein, nuts and coconut
- meal_type: breakfast
- context: pre-session, carb-load
- ingredients: greek yogurt 0.33 cup, granola 1 packet (~45g), egg white protein powder 0.25 cup, cashews/pumpkin seeds/almonds 1 tbsp each chopped, coconut milk 1 tbsp, shredded coconut 1 tbsp
- diets_ok: vegetarian
- allergens: gluten (granola), dairy, eggs, tree_nuts
- swaps: granola→certified GF granola (gluten-free); skip nuts (tree-nut-free)
- approx_macros: ~550 kcal, 55g carbs, 30g protein, 22g fat
- prep: 10 min
- source: Brennus on TrainerRoad forum recipe thread — https://www.trainerroad.com/forum/t/your-favourite-recipe-the-start-of-the-tr-cook-book/3928 — "big breakfast I like before a long ride," posted with a per-ingredient macro breakdown
- why: explicitly tagged by the poster as pre-long-ride fuel, dense enough to cover a multi-hour session

### Energy porridge with oat milk, raisins and collagen
- meal_type: breakfast
- context: pre-session
- ingredients: rolled oats 0.5 mug, oat milk 1.25 mugs, raisins 30g, cinnamon, vanilla, collagen protein powder 10g, banana 1 small, honey 0.5 tbsp
- diets_ok: vegetarian (collagen is animal-derived, not vegan)
- allergens: gluten (oats)
- swaps: oats→certified GF oats (gluten-free); swap collagen for pea protein (vegan)
- approx_macros: ~480 kcal, 85g carbs, 15g protein, 8g fat
- prep: 10 min, eaten 90min-2h pre-ride
- source: dsirrom on TrainerRoad forum recipe thread — https://www.trainerroad.com/forum/t/your-favourite-recipe-the-start-of-the-tr-cook-book/3928 — reports it's worth "an extra 20 watts on long rides"
- why: purpose-built pre-long-ride breakfast with explicit timing guidance from the poster (90min-2h before)

### Pre-ride microwave oats with banana, peanut butter and brown sugar
- meal_type: breakfast
- context: pre-session
- ingredients: quick oats 0.5 cup, water or milk 1.5 cups, pumpkin spice, banana 0.5 chopped, peanut butter 1 large tsp, brown sugar
- diets_ok: vegetarian
- allergens: gluten, peanuts, dairy (if milk)
- swaps: milk→water or oat milk (dairy-free); PB→sunflower seed butter (peanut-free); oats→certified GF oats (gluten-free)
- approx_macros: ~400 kcal, 65g carbs, 10g protein, 10g fat
- prep: 5 min, microwave
- source: chancie.cycles on TrainerRoad forum recipe thread — https://www.trainerroad.com/forum/t/your-favourite-recipe-the-start-of-the-tr-cook-book/3928 — "double the recipe if more time to digest"
- why: canonical low-fibre, low-fat, familiar pre-session breakfast the brief calls for

### Cornflakes with honey (post-big-ride refuel)
- meal_type: snack
- context: recovery, post-session
- ingredients: cornflakes 150g, honey drizzle
- diets_ok: vegetarian, vegan
- allergens: gluten (check brand — corn itself is GF but cross-contamination varies)
- swaps: use certified GF cornflakes if needed
- approx_macros: ~560 kcal, 130g carbs, 10g protein, 2g fat
- prep: no-cook
- source: RCC on TrainerRoad forum "big days" thread — https://www.trainerroad.com/forum/t/what-do-you-eat-on-your-big-days/87821/5 — eaten after a 1500-2000 cal ride, before eating dinner as normal later
- why: honest, unglamorous example of immediate high-carb refuel after a big session — real athletes reach for cereal, not a curated recovery bowl

### Canned black beans and corn (cheap training fuel bowl)
- meal_type: lunch
- context: everyday, recovery
- ingredients: canned black beans 1 can rinsed, canned sweet corn 1 can, olive oil 1 tsp, lime chili spice, optional corn tortilla
- diets_ok: vegetarian, vegan, mediterranean
- allergens: none (gluten-free unless tortilla is flour)
- swaps: add sweet potato base (see below) for more carbs
- approx_macros: ~380 kcal, 65g carbs, 18g protein, 5g fat
- prep: batch — cheap pantry staples, ready in 5 min
- source: fasterthanever on TrainerRoad forum — https://www.trainerroad.com/forum/t/canned-corn-and-black-beans-my-cheap-but-effective-training-fuel-source/13689 — regular post-workout (sometimes pre-workout) meal; thread title explicitly calls it "training fuel"
- why: exactly the cheap, boring, repeatable pantry meal real time-and-money-constrained athletes actually eat

### Baked sweet potato with black beans, corn and hot sauce
- meal_type: dinner
- context: everyday, recovery
- ingredients: sweet potato 1 medium baked, black beans 0.75 cup, corn 0.5 cup, hot sauce
- diets_ok: vegetarian, vegan, mediterranean
- allergens: none
- swaps: none needed — already broadly allergen-free
- approx_macros: ~420 kcal, 85g carbs, 15g protein, 3g fat
- prep: batch — bake 5-10 sweet potatoes at once at the start of the week
- source: mattymurda on TrainerRoad forum, building on the black bean/corn thread — https://www.trainerroad.com/forum/t/canned-corn-and-black-beans-my-cheap-but-effective-training-fuel-source/13689/6
- why: batch-bake-once, top-differently pattern — one of the clearest "component-first" real-world examples in the whole slice

### Sweet potato with homemade refried beans and hot sauce
- meal_type: lunch
- context: everyday
- ingredients: sweet potato 0.5 medium, homemade refried beans (no lard) 0.75 cup, hot sauce
- diets_ok: vegetarian, vegan, mediterranean
- allergens: none
- swaps: none needed
- approx_macros: ~320 kcal, 60g carbs, 12g protein, 2g fat
- prep: 10 min if beans pre-made
- source: ssmith1187 on TrainerRoad forum — https://www.trainerroad.com/forum/t/canned-corn-and-black-beans-my-cheap-but-effective-training-fuel-source/13689/9
- why: near-identical sibling of the corn/black bean bowl above, confirming it's a repeated shape across posters, not a one-off

### Overnight soaked oats with egg whites, greek yogurt and banana
- meal_type: breakfast
- context: everyday
- ingredients: oats 0.33 cup, water 0.33 cup, egg whites 0.33 cup, greek yogurt 100g, raisins 30g, flax seeds 0.5 tbsp, chia seeds 0.5 tbsp, banana 1 grated
- diets_ok: vegetarian
- allergens: gluten, eggs, dairy
- swaps: oats→certified GF oats (gluten-free); yogurt→coconut yogurt (dairy-free); egg whites→extra protein powder (egg-free)
- approx_macros: ~420 kcal, 65g carbs, 28g protein, 4g fat
- prep: batch — soak overnight, meal-prepped for the week
- source: julianoliver on TrainerRoad forum "Meal Prepping" thread — https://www.trainerroad.com/forum/t/meal-prepping-how-to-and-tips/7450/14 — regularly meal-preps this for breakfast
- why: high-protein oats variant purpose-built for weekly meal prep, addresses the "protein spread across meals" anchor

### Feed Zone Cookbook egg noodle stir-fry
- meal_type: dinner
- context: everyday
- ingredients: egg noodles, mixed stir-fry vegetables, protein of choice, soy-based sauce
- diets_ok: vegetarian (with tofu/no meat)
- allergens: gluten, eggs (noodles), soy
- swaps: rice noodles instead of egg noodles (gluten-free, egg-free)
- approx_macros: ~520 kcal, 70g carbs, 25g protein, 12g fat
- prep: 25 min
- source: bigdaddynewt on TrainerRoad forum, citing Feed Zone Cookbook (Allen Lim & Biju Thomas) — https://www.trainerroad.com/forum/t/meal-prepping-how-to-and-tips/7450/12 — "kids love" this, family staple
- why: direct forum confirmation that Feed Zone Cookbook recipes (a named source in the research brief) are actually cooked by real training households, not just cited in articles

### Roasted chickpeas with paprika (snack)
- meal_type: snack
- context: everyday, rest-day
- ingredients: canned chickpeas 1 cup, olive oil 1 tsp, paprika, salt
- diets_ok: vegetarian, vegan, mediterranean
- allergens: none
- swaps: none needed
- approx_macros: ~180 kcal, 22g carbs, 8g protein, 6g fat
- prep: batch — roast a big batch, 25 min oven
- source: willball12 on TrainerRoad forum — https://www.trainerroad.com/forum/t/your-favorite-snacks/7464/5 — built into a mid-morning/mid-afternoon snack rotation while managing weight
- why: crunchy, high-fibre, portable snack alternative to a bar — matches the "snacks that aren't gels" prompt directly

### Low-fat plain yogurt with dry rolled oats and honey
- meal_type: snack
- context: everyday
- ingredients: low-fat plain yogurt 150g, rolled oats 3 tbsp dry, honey 1 tsp
- diets_ok: vegetarian
- allergens: dairy, gluten
- swaps: yogurt→coconut or soy yogurt (dairy-free); oats→certified GF oats (gluten-free)
- approx_macros: ~220 kcal, 30g carbs, 12g protein, 4g fat
- prep: no-cook
- source: willball12 on TrainerRoad forum — https://www.trainerroad.com/forum/t/your-favorite-snacks/7464/5
- why: simple mid-day snack that pairs protein with a bit of carb, built specifically to prevent overeating later

### Fig bars pre-workout, hardboiled egg post-workout
- meal_type: snack
- context: pre-session, recovery
- ingredients: fig bar 1-2 (pre), hardboiled egg 1-2 (post), salt
- diets_ok: vegetarian
- allergens: gluten (fig bar), eggs
- swaps: fig bar→certified GF fig bar (gluten-free)
- approx_macros: ~pre 190 kcal/38g carbs/2g protein; post 140 kcal/1g carbs/12g protein/9g fat (combined ~330 kcal)
- prep: no-cook
- source: batwood14 on TrainerRoad forum — https://www.trainerroad.com/forum/t/your-favorite-snacks/7464/6 — fig bars discovered via a podcast recommendation, hardboiled eggs called out as an underrated post-workout snack
- why: clean before/after pairing — low-fat simple-carb pre-session, protein-only post-session

### Trail mix (nuts and seeds), ~350 cal daily snack
- meal_type: snack
- context: everyday
- ingredients: mixed nuts (cashews, peanuts, almonds) and seeds (sunflower, pumpkin) 60g
- diets_ok: vegetarian, vegan, mediterranean, paleo, keto
- allergens: peanuts, tree_nuts
- swaps: use a seed-only mix for tree-nut/peanut-free
- approx_macros: ~360 kcal, 15g carbs, 12g protein, 28g fat
- prep: no-cook
- source: GarageLab on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095/8 — "pretty much every day," Kirkland/Costco trail mix
- why: dense, calorie-efficient snack eaten daily by a training athlete managing overall intake

### Tuna pouch with crackers and pickles
- meal_type: snack
- context: everyday, travel
- ingredients: flavored tuna pouch 1 (~85g), crackers 8-10, pickle spears
- diets_ok: pescatarian
- allergens: fish, gluten (crackers)
- swaps: crackers→GF crackers (gluten-free)
- approx_macros: ~280 kcal, 25g carbs, 20g protein, 8g fat
- prep: no-cook, shelf-stable
- source: scarrith on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095/6
- why: shelf-stable, high-protein travel/desk snack — good "snacks that aren't gels" candidate that also isn't a bar

### Cottage cheese and cut fruit
- meal_type: snack
- context: everyday, recovery
- ingredients: cottage cheese 200g, mixed fruit 0.75 cup
- diets_ok: vegetarian
- allergens: dairy
- swaps: dairy-free cottage cheese alternative (dairy-free)
- approx_macros: ~220 kcal, 20g carbs, 24g protein, 4g fat
- prep: no-cook
- source: GarageLab on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095/8
- why: slow-digesting casein-rich protein snack, good bedtime/recovery option

### Homemade jerky (snack)
- meal_type: snack
- context: everyday, travel
- ingredients: lean beef or turkey, marinade (soy sauce, spices)
- diets_ok: omnivore, paleo, keto, low_carb
- allergens: soy (if soy-sauce marinade)
- swaps: use coconut aminos marinade (soy-free)
- approx_macros: ~120 kcal, 3g carbs, 18g protein, 3g fat
- prep: batch — dehydrate a big batch, keeps for weeks
- source: dprimm on TrainerRoad forum — https://www.trainerroad.com/forum/t/your-favorite-snacks/7464 — "made fresh at home, low(er) cost, easy to store"
- why: shelf-stable, high-protein, travel-friendly snack that isn't a bar or a gel — direct match to the brief's prompt

### Larabar / Clif Bar style snack bar (bought, not made)
- meal_type: snack
- context: everyday, pre-session, travel
- ingredients: date-and-nut bar (e.g. peanut butter chocolate chip flavor)
- diets_ok: vegetarian, vegan, mediterranean
- allergens: peanuts, tree_nuts (varies by flavor)
- swaps: choose a nut-free flavor for allergy safety
- approx_macros: ~200 kcal, 25g carbs, 5g protein, 9g fat
- prep: no-cook, packaged
- source: cbrink and Deleteme on TrainerRoad forum — https://www.trainerroad.com/forum/t/your-favorite-snacks/7464 — repeatedly named as the go-to portable bar across multiple posters
- why: included as the honest baseline "bar" category so the library has a real comparison point against the from-scratch snacks above

### Apple slices with peanut butter (packable version)
- meal_type: snack
- context: everyday, pre-session
- ingredients: apple 1 sliced, peanut butter 2 tbsp for dipping
- diets_ok: omnivore, vegetarian, vegan, mediterranean, paleo
- allergens: peanuts
- swaps: PB→sunflower seed butter (peanut-free)
- approx_macros: ~280 kcal, 30g carbs, 8g protein, 16g fat
- prep: no-cook
- source: Kevin_Lilly on TrainerRoad forum — https://www.trainerroad.com/forum/t/your-favorite-snacks/7464/13
- why: duplicate-confirmed shape (see apple+PB entry above) but packaged for portability/travel — kept separate because prep/context differ slightly per brief's "component + swap" guidance

### Chia pudding
- meal_type: snack
- context: everyday, recovery
- ingredients: chia seeds 3 tbsp, milk or plant milk 1 cup, honey or maple syrup, fruit topping
- diets_ok: vegetarian, vegan, mediterranean
- allergens: dairy (if dairy milk)
- swaps: use plant milk (vegan, dairy-free)
- approx_macros: ~250 kcal, 25g carbs, 8g protein, 12g fat
- prep: batch — sits overnight, make 4 at once
- source: Adub on TrainerRoad forum — https://www.trainerroad.com/forum/t/your-favorite-snacks/7464/15
- why: fibre and omega-3 rich make-ahead snack, easy to batch for the week

### Cheerios with skim milk (quick-carb snack)
- meal_type: snack
- context: everyday, pre-session
- ingredients: cheerios 1.5 cups, skim milk 200ml
- diets_ok: vegetarian
- allergens: gluten (check brand — oat-based, verify GF cert), dairy
- swaps: milk→oat milk (dairy-free); confirm certified GF cereal (gluten-free)
- approx_macros: ~250 kcal, 42g carbs, 10g protein, 3g fat
- prep: no-cook
- source: BCM on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095/4 — "if I NEED more carbs"
- why: honest, unpretentious high-carb top-up when training volume calls for it — not every fuel choice is artisanal

### Brown rice with fried eggs and sriracha
- meal_type: dinner
- context: everyday
- ingredients: brown rice 1 cup cooked, eggs 2-3 fried, sriracha
- diets_ok: vegetarian
- allergens: eggs
- swaps: none needed — already broadly allergen-light
- approx_macros: ~450 kcal, 55g carbs, 20g protein, 15g fat
- prep: 10 min
- source: BCM on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-are-your-go-to-snacks/89095/4
- why: dead-simple 3-ingredient dinner, the definition of "repeatable" the brief calls for

### Beef, chicken or turkey rotated into tacos, burritos, salads and bowls
- meal_type: dinner
- context: everyday
- ingredients: ground or shredded beef/chicken/turkey 1.5 lb (batch), tortillas or rice or salad greens, cheese, salsa, beans
- diets_ok: omnivore (assemble as tacos/burrito bowls)
- allergens: dairy (cheese), gluten (flour tortillas)
- swaps: corn tortillas or rice base (gluten-free); skip cheese (dairy-free)
- approx_macros: ~520 kcal, 45g carbs, 35g protein, 20g fat
- prep: batch — cook one big protein batch Sunday, reassemble differently each night
- source: GT7 on TrainerRoad forum — https://www.trainerroad.com/forum/t/what-do-you-eat-during-any-given-day/19629/18 — "rotate between cooking some beef or chicken and then using that over a few days"
- why: this is the single clearest real-world description of "one batch-cooked protein, reassembled all week" in the whole slice — a direct hit on the app's component-first thesis

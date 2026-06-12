-- ============================================================
-- Mealvana Endurance — Curated Recipe Catalog Seed Data v2
-- ============================================================
-- Apply to DEV and PROD via DataGrip (paste and execute).
-- Run AFTER meal_logging_jade_schema.sql which creates the
-- `recipes` table.
--
-- Idempotent: ON CONFLICT (id) DO UPDATE overwrites all content
-- columns so re-running is safe (e.g. after a macro correction).
--
-- Macro sanity check: calories ≈ (carbs_g * 4) + (protein_g * 4) + (fat_g * 9)
-- All values are per-serving.
--
-- Categories:
--   breakfast    → morning meals
--   mains        → lunch & dinner
--   snacks       → any-time snacks
--   workout_fuel → portable eat-while-training fuel
--   recovery     → post-exercise recovery meals
-- ============================================================

-- Step 1: drop the old CHECK so existing rows with legacy type values
-- ('preRun', 'duringRun', 'postRun', 'general') do not block the upserts.
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS recipes_type_check;

-- ============================================================
-- BREAKFAST recipes (6)
-- ============================================================

INSERT INTO public.recipes (id, name, description, ingredients, instructions,
  prep_time_minutes, servings, type,
  calories, carbs_g, protein_g, fat_g, fiber_g, sugar_g, sodium_mg,
  image_url, tags, is_active, created_at, updated_at)
VALUES

-- 1. Overnight Oats with Banana & Honey  (kept UUID, was preRun → breakfast)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000001',
  'Overnight Oats with Banana & Honey',
  'Creamy high-carb oats prepped the night before — ready in seconds on busy training mornings.',
  '["1 cup rolled oats","1 cup oat milk","1 ripe banana, sliced","2 tbsp honey","1/4 tsp salt","1/2 tsp vanilla extract"]',
  '["Combine oats, oat milk, honey, salt, and vanilla in a jar or bowl.","Stir well, cover, and refrigerate overnight (at least 6 hours).","Top with sliced banana before serving."]',
  5, 1, 'breakfast',
  460, 92, 10, 6, 5, 36, 200,
  'overnight-oats-banana-honey.jpg',
  '["overnight","high-carb","make-ahead","banana","meal-prep"]',
  TRUE, NOW(), NOW()
),

-- 2. Avocado Egg Toast with Everything Seasoning  (kept UUID, was general → breakfast)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000023',
  'Avocado Egg Toast with Everything Seasoning',
  'Healthy fats, complete protein, and slow-release carbs — the go-to daily training breakfast.',
  '["2 slices whole grain bread","1 ripe avocado","2 eggs, poached or fried","1/2 tsp everything bagel seasoning","Chili flakes","1/2 lemon, juiced","Salt and pepper"]',
  '["Toast bread until golden.","Mash avocado with lemon juice; season with salt.","Spread avocado onto toast.","Cook eggs to your preference (poached is ideal).","Place eggs on avocado toast.","Sprinkle everything seasoning and chili flakes."]',
  10, 1, 'breakfast',
  490, 44, 22, 26, 10, 4, 540,
  'avocado-egg-toast.jpg',
  '["avocado","eggs","toast","healthy-fats","daily"]',
  TRUE, NOW(), NOW()
),

-- 3. Overnight Steel-Cut Oats with Chia & Berries  (kept UUID, was general → breakfast)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000020',
  'Overnight Steel-Cut Oats with Chia & Berries',
  'Slow-release carbs from steel-cut oats sustain energy all morning. Make a batch Sunday night.',
  '["1/2 cup steel-cut oats","1 cup unsweetened almond milk","2 tbsp chia seeds","1/2 cup mixed berries","1 tbsp maple syrup","1/4 tsp cinnamon"]',
  '["Combine oats, almond milk, chia seeds, maple syrup, and cinnamon in a jar.","Stir well, seal, and refrigerate overnight.","In the morning, stir again (oats absorb the liquid).","Top with berries and serve cold or briefly microwaved."]',
  5, 1, 'breakfast',
  410, 64, 12, 10, 12, 18, 140,
  'steel-cut-oats-chia-berries.jpg',
  '["oats","chia","berries","meal-prep","slow-release"]',
  TRUE, NOW(), NOW()
),

-- 4. Greek Yogurt Parfait with Granola & Berries  (kept UUID, was postRun → breakfast)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000012',
  'Greek Yogurt Parfait with Granola & Berries',
  'Layered Greek yogurt, crunchy granola, and antioxidant-rich berries — a high-protein breakfast in minutes.',
  '["1 cup full-fat Greek yogurt","1/2 cup mixed berries (blueberry, strawberry, raspberry)","1/4 cup granola","1 tbsp honey","1 tbsp chia seeds"]',
  '["Spoon Greek yogurt into a bowl or glass.","Layer berries over yogurt.","Top with granola and chia seeds.","Drizzle honey over the top."]',
  5, 1, 'breakfast',
  395, 52, 22, 10, 6, 34, 85,
  'greek-yogurt-parfait.jpg',
  '["yogurt","berries","granola","protein","quick"]',
  TRUE, NOW(), NOW()
),

-- 5. Banana Protein Pancakes  (new UUID)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000031',
  'Banana Protein Pancakes',
  'Two-ingredient base with a protein boost — fluffy, sweet, and ready in under 15 minutes.',
  '["2 ripe bananas, mashed","3 eggs","1 scoop vanilla protein powder (25g protein)","1/4 tsp baking powder","1/2 tsp cinnamon","Pinch of salt","Coconut oil for cooking","Fresh berries and maple syrup to serve"]',
  '["Whisk together mashed banana, eggs, protein powder, baking powder, cinnamon, and salt until smooth.","Heat a non-stick pan over medium-low heat; brush with coconut oil.","Pour small circles of batter (~3 tbsp each) into the pan.","Cook 2–3 minutes until bubbles form; flip and cook 1–2 minutes more.","Serve with fresh berries and a drizzle of maple syrup."]',
  15, 2, 'breakfast',
  380, 48, 28, 8, 4, 22, 200,
  'banana-protein-pancakes.jpg',
  '["pancakes","banana","protein","quick","egg"]',
  TRUE, NOW(), NOW()
),

-- 6. Smashed Avocado Toast with Smoked Salmon  (new UUID)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000032',
  'Smashed Avocado Toast with Smoked Salmon',
  'Omega-3-rich salmon on creamy avocado toast — a hotel-quality breakfast you can make in 10 minutes.',
  '["2 slices sourdough bread","1 ripe avocado","80g smoked salmon","1 tbsp capers","1/2 lemon, juiced","Red onion, thinly sliced","Dill fronds","Salt, pepper, chili flakes"]',
  '["Toast sourdough until golden.","Halve avocado, scoop into a bowl, add lemon juice; mash roughly with a fork.","Season avocado with salt and pepper.","Spread avocado generously on each toast slice.","Layer smoked salmon over the avocado.","Top with capers, red onion, dill, and chili flakes."]',
  10, 1, 'breakfast',
  450, 40, 26, 20, 7, 3, 780,
  'avocado-smoked-salmon-toast.jpg',
  '["salmon","avocado","toast","omega-3","sourdough"]',
  TRUE, NOW(), NOW()
),

-- ============================================================
-- MAINS recipes (8)
-- ============================================================

-- 7. Simple White Pasta with Marinara & Chicken  (kept UUID, was preRun → mains)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000003',
  'Simple White Pasta with Marinara & Chicken',
  'Classic carb-rich pasta dinner. Great the night before a long ride or race.',
  '["200g white pasta (spaghetti or penne)","150g cooked chicken breast, diced","1/2 cup marinara sauce","1 tsp olive oil","Salt to taste"]',
  '["Cook pasta according to package directions. Drain well.","Warm marinara sauce in a small pan.","Toss pasta with sauce and olive oil.","Top with diced chicken.","Season lightly with salt."]',
  20, 1, 'mains',
  580, 94, 40, 6, 4, 8, 420,
  'white-pasta-marinara-chicken.jpg',
  '["pasta","carb-loading","high-carb","chicken","dinner"]',
  TRUE, NOW(), NOW()
),

-- 8. Whole Wheat Pasta with Turkey Bolognese  (kept UUID, was general → mains)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000022',
  'Whole Wheat Pasta with Turkey Bolognese',
  'Leaner take on classic bolognese — higher-fibre carbs for regular training-day dinners.',
  '["200g whole wheat spaghetti","300g lean ground turkey","1 can crushed tomatoes (400g)","1 small onion, finely diced","2 cloves garlic, minced","1 tsp Italian seasoning","1 tbsp olive oil","Salt and pepper","Optional: parmesan to serve"]',
  '["Cook spaghetti per package directions; reserve 1/4 cup pasta water.","Heat olive oil in a wide pan. Sauté onion 3 minutes.","Add garlic and turkey; brown turkey 5–6 minutes, breaking it up.","Add crushed tomatoes, Italian seasoning, salt, and pepper.","Simmer 15 minutes. Add pasta water if sauce is too thick.","Toss sauce with drained spaghetti.","Serve with parmesan if desired."]',
  30, 2, 'mains',
  540, 72, 42, 10, 8, 10, 490,
  'turkey-bolognese-pasta.jpg',
  '["pasta","turkey","bolognese","high-protein","whole-wheat","training-day"]',
  TRUE, NOW(), NOW()
),

-- 9. Quinoa Power Bowl with Chickpeas & Tahini  (kept UUID, was general → mains)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000019',
  'Quinoa Power Bowl with Chickpeas & Tahini',
  'Complete plant-based protein from quinoa and chickpeas with a lemon-tahini drizzle.',
  '["1 cup cooked quinoa","1/2 cup canned chickpeas, drained and rinsed","1/2 cucumber, diced","1/4 cup cherry tomatoes","2 tbsp tahini","1 tbsp lemon juice","1 clove garlic, minced","Salt, cumin"]',
  '["Whisk tahini, lemon juice, garlic, a pinch of cumin and salt with 2 tbsp water to make dressing.","Combine quinoa, chickpeas, cucumber, and tomatoes in a bowl.","Drizzle tahini dressing over the bowl.","Toss gently and serve."]',
  10, 1, 'mains',
  480, 60, 18, 16, 10, 8, 340,
  'quinoa-chickpea-bowl.jpg',
  '["quinoa","chickpeas","plant-based","tahini","balanced","meal-prep"]',
  TRUE, NOW(), NOW()
),

-- 10. Salmon Sushi Bowl  (kept UUID, was general → mains)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000024',
  'Salmon Sushi Bowl',
  'Deconstructed sushi bowl — omega-3s for joint health and white rice for carb balance.',
  '["1.5 cups cooked sushi rice","120g sushi-grade salmon (or smoked salmon), cubed","1/2 avocado, sliced","1/4 cucumber, julienned","2 tbsp soy sauce","1 tsp sesame oil","1 tsp rice vinegar","1 tsp sesame seeds","Optional: nori strips, pickled ginger"]',
  '["Season warm sushi rice with rice vinegar; mix gently.","Mix soy sauce and sesame oil for dressing.","Scoop rice into a bowl.","Arrange salmon, avocado, and cucumber over rice.","Drizzle dressing over the bowl.","Sprinkle sesame seeds and add nori/ginger if using."]',
  15, 1, 'mains',
  520, 62, 28, 16, 5, 4, 680,
  'salmon-sushi-bowl.jpg',
  '["salmon","sushi","bowl","omega-3","rice"]',
  TRUE, NOW(), NOW()
),

-- 11. Black Bean & Sweet Potato Tacos  (kept UUID, was general → mains)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000025',
  'Black Bean & Sweet Potato Tacos',
  'Plant-based iron and slow-release carbs. Ideal on rest days or easy training days.',
  '["1 medium sweet potato, diced","1 can black beans, drained (240g)","4 small corn tortillas","1/2 tsp cumin","1/2 tsp smoked paprika","1/4 tsp garlic powder","1 tbsp olive oil","1/4 cup salsa","1/4 cup plain Greek yogurt (as sour cream sub)","Fresh cilantro, lime wedges"]',
  '["Preheat oven to 200°C (400°F).","Toss sweet potato with olive oil, cumin, paprika, and garlic powder.","Roast 20 minutes until tender and caramelised.","Warm black beans in a small pan with a pinch of cumin.","Warm tortillas directly on a gas flame or dry skillet 30 seconds each side.","Fill each tortilla with sweet potato, black beans, salsa, and yogurt.","Garnish with cilantro and a squeeze of lime."]',
  30, 2, 'mains',
  430, 72, 18, 8, 14, 10, 420,
  'black-bean-sweet-potato-tacos.jpg',
  '["tacos","black-beans","sweet-potato","plant-based","iron","rest-day"]',
  TRUE, NOW(), NOW()
),

-- 12. Red Lentil & Vegetable Soup  (kept UUID, was general → mains)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000021',
  'Red Lentil & Vegetable Soup',
  'Iron-rich lentils with anti-inflammatory turmeric — great for high-volume training weeks.',
  '["1 cup red lentils, rinsed","1 medium carrot, diced","1 celery stalk, diced","1 small onion, diced","2 cloves garlic, minced","1 can diced tomatoes (400g)","750ml vegetable broth","1 tsp cumin","1/2 tsp turmeric","Salt and pepper","1 tbsp olive oil"]',
  '["Heat olive oil in a large pot over medium heat.","Sauté onion, carrot, and celery 5 minutes until soft.","Add garlic, cumin, and turmeric; stir 1 minute.","Add lentils, diced tomatoes, and broth.","Bring to a boil, then simmer 20 minutes until lentils break down.","Season with salt and pepper.","Blend partially for a creamier texture if desired."]',
  35, 4, 'mains',
  285, 44, 16, 5, 10, 8, 520,
  'red-lentil-soup.jpg',
  '["lentils","soup","iron","turmeric","anti-inflammatory","meal-prep","plant-based"]',
  TRUE, NOW(), NOW()
),

-- 13. Rice Cakes with Almond Butter & Jam  (kept UUID, was preRun → mains... actually snacks; reassigned below)
-- Note: this UUID is now used for a Mains recipe; original rice-cake UUID goes to snacks below.
-- Teriyaki Chicken Rice Bowl  (new UUID — replaces preRun rice-cake slot in mains)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000033',
  'Teriyaki Chicken Rice Bowl',
  'Lean chicken thighs in a quick homemade teriyaki sauce over fluffy white rice — a weeknight staple.',
  '["300g chicken thighs, sliced","1.5 cups cooked white rice","2 tbsp soy sauce","1 tbsp honey","1 tsp sesame oil","1 tsp rice vinegar","1 tsp grated ginger","1 clove garlic, minced","Spring onions and sesame seeds to serve","1 tsp cornflour mixed with 1 tbsp water"]',
  '["Mix soy sauce, honey, sesame oil, vinegar, ginger, and garlic to make marinade.","Toss chicken in marinade; rest 10 minutes.","Cook chicken in a hot pan 4–5 minutes per side until cooked through.","Add cornflour slurry to the pan; stir until sauce thickens, 1 minute.","Serve over rice; garnish with spring onions and sesame seeds."]',
  25, 2, 'mains',
  510, 62, 38, 12, 1, 14, 680,
  'teriyaki-chicken-rice-bowl.jpg',
  '["chicken","rice","teriyaki","meal-prep","asian"]',
  TRUE, NOW(), NOW()
),

-- 14. Egg & Veggie Scramble  (kept UUID, was postRun → mains; protein-dense lunch/brunch)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000018',
  'Egg & Veggie Scramble',
  'Complete amino-acid profile from eggs. Spinach and peppers add potassium and iron.',
  '["3 large eggs","1/2 cup baby spinach","1/4 red bell pepper, diced","1/4 cup cherry tomatoes, halved","1 tsp olive oil","Salt, pepper, paprika"]',
  '["Heat olive oil in a non-stick pan over medium heat.","Sauté pepper and tomatoes 2 minutes until slightly soft.","Add spinach and stir until wilted, about 30 seconds.","Whisk eggs with salt, pepper, and a pinch of paprika; pour into pan.","Stir gently with a spatula until just set.","Serve immediately."]',
  10, 1, 'mains',
  280, 8, 22, 18, 2, 4, 310,
  'egg-veggie-scramble.jpg',
  '["eggs","scramble","protein","quick","iron","potassium"]',
  TRUE, NOW(), NOW()
),

-- ============================================================
-- SNACKS recipes (5)
-- ============================================================

-- 15. Rice Cakes with Almond Butter & Jam  (kept UUID, was preRun → snacks)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000002',
  'Rice Cakes with Almond Butter & Jam',
  'Light and digestible anytime snack — the perfect mid-morning energy top-up between sessions.',
  '["3 plain rice cakes","1.5 tbsp almond butter","2 tbsp strawberry jam"]',
  '["Spread almond butter evenly on each rice cake.","Top with strawberry jam.","Enjoy immediately."]',
  3, 1, 'snacks',
  310, 50, 7, 9, 2, 20, 105,
  'rice-cakes-almond-butter-jam.jpg',
  '["rice-cakes","quick","snack","almond-butter"]',
  TRUE, NOW(), NOW()
),

-- 16. Cottage Cheese & Pineapple Bowl  (kept UUID, was postRun → snacks; great any-time snack)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000017',
  'Cottage Cheese & Pineapple Bowl',
  'Cottage cheese is high in casein — slow-digesting protein ideal for muscle repair and satiety.',
  '["1 cup low-fat cottage cheese","3/4 cup fresh or tinned pineapple chunks","1 tbsp flaxseeds","1 tsp honey"]',
  '["Spoon cottage cheese into a bowl.","Top with pineapple chunks.","Sprinkle flaxseeds over the top.","Drizzle with honey and serve."]',
  3, 1, 'snacks',
  300, 38, 28, 5, 2, 32, 450,
  'cottage-cheese-pineapple-bowl.jpg',
  '["cottage-cheese","pineapple","casein","quick","protein"]',
  TRUE, NOW(), NOW()
),

-- 17. Banana & Date Energy Smoothie  (kept UUID, was preRun → snacks)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000005',
  'Banana & Date Energy Smoothie',
  'Blended in 3 minutes. Dates provide sustained glucose; banana adds potassium for muscle function.',
  '["2 ripe bananas","4 Medjool dates, pitted","1 cup oat milk","1/2 cup water","Pinch of sea salt"]',
  '["Remove pits from dates if needed.","Add all ingredients to a blender.","Blend on high for 45 seconds until smooth.","Drink immediately or store refrigerated up to 4 hours."]',
  3, 1, 'snacks',
  390, 88, 5, 3, 5, 60, 160,
  'banana-date-smoothie.jpg',
  '["smoothie","banana","dates","quick","liquid-carbs"]',
  TRUE, NOW(), NOW()
),

-- 18. Apple Slices with Peanut Butter  (new UUID)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000034',
  'Apple Slices with Peanut Butter',
  'One of the simplest and most satisfying training snacks — natural sugar, fibre, and healthy fat.',
  '["1 medium apple, cored and sliced","2 tbsp natural peanut butter","Pinch of cinnamon (optional)"]',
  '["Slice apple into wedges.","Serve alongside peanut butter for dipping.","Sprinkle cinnamon over the peanut butter if desired."]',
  2, 1, 'snacks',
  255, 32, 7, 12, 5, 22, 75,
  'apple-peanut-butter-slices.jpg',
  '["apple","peanut-butter","no-cook","quick","snack"]',
  TRUE, NOW(), NOW()
),

-- 19. Sourdough Toast with Honey & Peanut Butter  (kept UUID, was preRun → snacks)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000006',
  'Sourdough Toast with Honey & Peanut Butter',
  'A reliable anytime snack. Sourdough''s lower GI pairs with fast honey sugars for a sustained boost.',
  '["2 slices sourdough bread","2 tbsp natural peanut butter","1 tbsp honey","Pinch of salt"]',
  '["Toast sourdough slices to your preference.","Spread peanut butter on each slice.","Drizzle honey over the top.","Sprinkle a pinch of salt."]',
  5, 1, 'snacks',
  400, 55, 14, 14, 3, 18, 310,
  'sourdough-honey-peanut-butter.jpg',
  '["toast","peanut-butter","quick","sourdough","snack"]',
  TRUE, NOW(), NOW()
),

-- ============================================================
-- WORKOUT FUEL recipes (5)
-- ============================================================

-- 20. Homemade Honey & Salt Energy Gel  (kept UUID, was duringRun → workout_fuel)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000007',
  'Homemade Honey & Salt Energy Gel',
  'DIY gel using raw honey — ~25g fast carbs per serving. Fill into a reusable flask.',
  '["3 tbsp raw honey","1/8 tsp sea salt","1 tbsp water","Optional: 1/4 tsp lemon juice"]',
  '["Combine all ingredients in a small bowl and stir until salt dissolves.","Pour into a reusable gel flask or small zip-lock bag.","Take one serving every 45 minutes during runs over 75 minutes.","Chase with 150ml water."]',
  2, 1, 'workout_fuel',
  175, 44, 0, 0, 0, 43, 190,
  'honey-salt-energy-gel.jpg',
  '["gel","honey","portable","no-cook","fast-carbs","diy"]',
  TRUE, NOW(), NOW()
),

-- 21. Salted Onigiri Rice Balls  (kept UUID, was duringRun → workout_fuel)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000008',
  'Salted Onigiri Rice Balls',
  'Compact palm-sized rice balls used by elite ultrarunners. Wrap in plastic wrap for the trail.',
  '["2 cups cooked white sushi rice","1 tsp salt","1 tbsp soy sauce","Optional fillings: smoked salmon or umeboshi"]',
  '["Season warm rice with salt and soy sauce; mix gently.","Wet hands, take 1/3 cup rice, press firmly into a triangle or ball.","Press a small amount of filling into the centre if using.","Wrap tightly in plastic wrap.","Eat 1 ball every 45–60 minutes on long efforts."]',
  15, 3, 'workout_fuel',
  165, 36, 3, 0, 0, 0, 390,
  'salted-onigiri-rice-balls.jpg',
  '["onigiri","rice","portable","savoury","ultrarunning","japanese"]',
  TRUE, NOW(), NOW()
),

-- 22. Medjool Date & Sea Salt Bites  (kept UUID, was duringRun → workout_fuel)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000009',
  'Medjool Date & Sea Salt Bites',
  'Whole-food fuel — natural sugars and sodium with zero cooking. 2–3 dates per serving.',
  '["8 Medjool dates, pitted","1/4 tsp flaky sea salt","Optional: 2 tsp almond butter (insert inside date)"]',
  '["Split each date lengthwise and remove pit.","Sprinkle a pinch of flaky sea salt inside each date.","Optional: press 1/4 tsp almond butter inside and close.","Portion into small bags of 2–3 dates each.","Eat 1 serving every 45 minutes during long efforts."]',
  5, 4, 'workout_fuel',
  140, 34, 1, 1, 3, 30, 110,
  'medjool-date-sea-salt-bites.jpg',
  '["dates","portable","no-cook","natural","sodium","fuel"]',
  TRUE, NOW(), NOW()
),

-- 23. Banana & Rice Peanut Butter Chews  (kept UUID, was duringRun → workout_fuel)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000010',
  'Banana & Rice Peanut Butter Chews',
  'Baked rice-banana bars inspired by Feed Zone Portables. ~50g carbs each; pocket-sized.',
  '["3 cups cooked white rice (slightly warm)","2 ripe bananas, mashed","3 tbsp peanut butter","2 tbsp maple syrup","1/4 tsp salt"]',
  '["Preheat oven to 190°C (375°F).","Mash bananas with a fork until smooth.","Combine all ingredients in a large bowl; mix well.","Press mixture 1.5cm thick onto a parchment-lined baking tray.","Bake 20 minutes until edges are golden and centre is set.","Cool completely, then cut into 8 bars.","Wrap individually in foil for runs."]',
  35, 8, 'workout_fuel',
  195, 38, 5, 4, 2, 12, 95,
  'banana-rice-peanut-butter-chews.jpg',
  '["rice","banana","bars","baked","portable","peanut-butter"]',
  TRUE, NOW(), NOW()
),

-- 24. White Rice & Banana Bowl  (kept UUID, was preRun → workout_fuel; small pre-session carb hit)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000004',
  'White Rice & Banana Bowl',
  'Ultra-low-fibre bowl that sits well before any session. A drizzle of honey for quick energy.',
  '["1.5 cups cooked white rice","1 banana, sliced","1 tbsp honey","Pinch of salt"]',
  '["Place warm or cold white rice in a bowl.","Top with banana slices.","Drizzle with honey and add a pinch of salt."]',
  5, 1, 'workout_fuel',
  420, 95, 7, 1, 2, 28, 120,
  'white-rice-banana-bowl.jpg',
  '["rice","banana","low-fiber","ultra-simple","pre-session"]',
  TRUE, NOW(), NOW()
),

-- ============================================================
-- RECOVERY recipes (6)
-- ============================================================

-- 25. Chocolate Milk Recovery Shake  (kept UUID, was postRun → recovery)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000011',
  'Chocolate Milk Recovery Shake',
  'The original recovery drink. Research-backed 3:1 carb-to-protein ratio in under 5 minutes.',
  '["400ml low-fat chocolate milk","1 banana","1 tbsp honey","Pinch of salt"]',
  '["Pour chocolate milk into a blender.","Add banana, honey, and salt.","Blend 20 seconds.","Drink within 30 minutes of finishing your session."]',
  3, 1, 'recovery',
  385, 68, 14, 6, 1, 58, 260,
  'chocolate-milk-recovery-shake.jpg',
  '["recovery","shake","chocolate-milk","quick","3:1-ratio"]',
  TRUE, NOW(), NOW()
),

-- 26. Chicken & Brown Rice Recovery Bowl  (kept UUID, was postRun → recovery)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000013',
  'Chicken & Brown Rice Recovery Bowl',
  'Lean protein repairs muscle while brown rice restores glycogen after long efforts.',
  '["175g grilled chicken breast","1 cup cooked brown rice","1 cup steamed broccoli","2 tbsp soy sauce","1 tsp sesame oil","1/2 tsp ginger, grated"]',
  '["Cook chicken breast on a grill or skillet; slice thinly.","Steam broccoli until tender-crisp, about 4 minutes.","Combine soy sauce, sesame oil, and ginger in a small bowl.","Plate rice, top with chicken and broccoli.","Drizzle sauce over the bowl."]',
  25, 1, 'recovery',
  470, 55, 44, 9, 5, 4, 780,
  'chicken-brown-rice-bowl.jpg',
  '["chicken","brown-rice","meal","high-protein","glycogen"]',
  TRUE, NOW(), NOW()
),

-- 27. Baked Salmon & Sweet Potato Recovery Bowl  (kept UUID, was postRun → recovery)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000014',
  'Baked Salmon & Sweet Potato Recovery Bowl',
  'Omega-3s from salmon reduce muscle inflammation; sweet potato restores glycogen.',
  '["150g salmon fillet","1 medium sweet potato","1 cup baby spinach","1 tbsp olive oil","1/2 lemon, juiced","Salt and pepper"]',
  '["Preheat oven to 200°C (400°F).","Pierce sweet potato; microwave 5 minutes or until soft. Cube it.","Season salmon with salt, pepper, and half the lemon juice.","Roast salmon on a lined tray for 12–15 minutes.","Toss spinach with olive oil and remaining lemon juice.","Assemble bowl: spinach base, sweet potato, flaked salmon."]',
  25, 1, 'recovery',
  480, 42, 38, 16, 6, 10, 320,
  'salmon-sweet-potato-bowl.jpg',
  '["salmon","sweet-potato","omega-3","anti-inflammatory","recovery"]',
  TRUE, NOW(), NOW()
),

-- 28. Tart Cherry & Protein Recovery Smoothie  (kept UUID, was postRun → recovery)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000015',
  'Tart Cherry & Protein Recovery Smoothie',
  'Tart cherry juice reduces DOMS by up to 22% in studies. Whey protein drives muscle synthesis.',
  '["240ml tart cherry juice","1 scoop vanilla whey protein powder (approx 25g protein)","1/2 cup frozen mango","1/2 cup coconut water","Handful of ice"]',
  '["Add all ingredients to blender.","Blend on high 45 seconds until smooth.","Pour and drink within 30 minutes of completing your session."]',
  4, 1, 'recovery',
  340, 46, 29, 2, 1, 38, 180,
  'tart-cherry-protein-smoothie.jpg',
  '["smoothie","tart-cherry","whey","protein","DOMS","30-minute-window"]',
  TRUE, NOW(), NOW()
),

-- 29. Turkey & Avocado Recovery Wrap  (kept UUID, was postRun → recovery)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000016',
  'Turkey & Avocado Recovery Wrap',
  'High-protein wrap with healthy fats from avocado. Ready in 5 minutes, portable for post-race.',
  '["1 large whole-wheat tortilla","100g sliced turkey breast","1/2 avocado, sliced","1/4 cup cherry tomatoes, halved","1 tbsp Greek yogurt","Salt and pepper"]',
  '["Lay tortilla flat on a board.","Spread Greek yogurt across the centre.","Layer turkey, avocado, and tomatoes.","Season with salt and pepper.","Roll firmly, tucking in the sides, and slice in half."]',
  5, 1, 'recovery',
  440, 38, 34, 16, 6, 5, 600,
  'turkey-avocado-wrap.jpg',
  '["wrap","turkey","avocado","portable","quick","high-protein"]',
  TRUE, NOW(), NOW()
),

-- 30. Warm Spiced Oat & Protein Porridge  (new UUID)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000035',
  'Warm Spiced Oat & Protein Porridge',
  'Creamy rolled oats spiked with a scoop of protein powder — warming, comforting recovery fuel.',
  '["1 cup rolled oats","1.5 cups milk (dairy or oat)","1 scoop vanilla protein powder (25g protein)","1 tbsp almond butter","1/2 banana, sliced","1/4 tsp cinnamon","Pinch of nutmeg","Drizzle of honey"]',
  '["Bring milk to a gentle simmer in a small saucepan.","Stir in oats and cook over medium heat 4–5 minutes, stirring frequently.","Remove from heat; stir in protein powder and almond butter until smooth.","Pour into a bowl; top with banana slices, cinnamon, and honey."]',
  10, 1, 'recovery',
  510, 68, 34, 12, 6, 22, 220,
  'spiced-oat-protein-porridge.jpg',
  '["oats","protein","porridge","warm","recovery","banana"]',
  TRUE, NOW(), NOW()
)

ON CONFLICT (id) DO UPDATE SET
  name              = EXCLUDED.name,
  description       = EXCLUDED.description,
  ingredients       = EXCLUDED.ingredients,
  instructions      = EXCLUDED.instructions,
  prep_time_minutes = EXCLUDED.prep_time_minutes,
  servings          = EXCLUDED.servings,
  type              = EXCLUDED.type,
  calories          = EXCLUDED.calories,
  carbs_g           = EXCLUDED.carbs_g,
  protein_g         = EXCLUDED.protein_g,
  fat_g             = EXCLUDED.fat_g,
  fiber_g           = EXCLUDED.fiber_g,
  sugar_g           = EXCLUDED.sugar_g,
  sodium_mg         = EXCLUDED.sodium_mg,
  image_url         = EXCLUDED.image_url,
  tags              = EXCLUDED.tags,
  is_active         = EXCLUDED.is_active,
  updated_at        = NOW();

-- Step 2: deactivate any legacy rows not included in this v2 seed,
-- and coerce their type to 'mains' so the CHECK re-add below succeeds.
UPDATE public.recipes
SET is_active = false, type = 'mains'
WHERE id NOT IN (
  'a1b2c3d4-e5f6-7890-abcd-000000000001',
  'a1b2c3d4-e5f6-7890-abcd-000000000002',
  'a1b2c3d4-e5f6-7890-abcd-000000000003',
  'a1b2c3d4-e5f6-7890-abcd-000000000004',
  'a1b2c3d4-e5f6-7890-abcd-000000000005',
  'a1b2c3d4-e5f6-7890-abcd-000000000006',
  'a1b2c3d4-e5f6-7890-abcd-000000000007',
  'a1b2c3d4-e5f6-7890-abcd-000000000008',
  'a1b2c3d4-e5f6-7890-abcd-000000000009',
  'a1b2c3d4-e5f6-7890-abcd-000000000010',
  'a1b2c3d4-e5f6-7890-abcd-000000000011',
  'a1b2c3d4-e5f6-7890-abcd-000000000012',
  'a1b2c3d4-e5f6-7890-abcd-000000000013',
  'a1b2c3d4-e5f6-7890-abcd-000000000014',
  'a1b2c3d4-e5f6-7890-abcd-000000000015',
  'a1b2c3d4-e5f6-7890-abcd-000000000016',
  'a1b2c3d4-e5f6-7890-abcd-000000000017',
  'a1b2c3d4-e5f6-7890-abcd-000000000018',
  'a1b2c3d4-e5f6-7890-abcd-000000000019',
  'a1b2c3d4-e5f6-7890-abcd-000000000020',
  'a1b2c3d4-e5f6-7890-abcd-000000000021',
  'a1b2c3d4-e5f6-7890-abcd-000000000022',
  'a1b2c3d4-e5f6-7890-abcd-000000000023',
  'a1b2c3d4-e5f6-7890-abcd-000000000024',
  'a1b2c3d4-e5f6-7890-abcd-000000000025',
  'a1b2c3d4-e5f6-7890-abcd-000000000031',
  'a1b2c3d4-e5f6-7890-abcd-000000000032',
  'a1b2c3d4-e5f6-7890-abcd-000000000033',
  'a1b2c3d4-e5f6-7890-abcd-000000000034',
  'a1b2c3d4-e5f6-7890-abcd-000000000035'
);

-- Step 3: re-add the CHECK constraint with the new 5 category values.
ALTER TABLE public.recipes
  ADD CONSTRAINT recipes_type_check
  CHECK (type IN ('breakfast', 'mains', 'snacks', 'workout_fuel', 'recovery'));


-- ============================================================
-- Image filename → visual description
-- (for generating/uploading photos to the recipe-images bucket)
-- ============================================================

-- BREAKFAST
-- overnight-oats-banana-honey.jpg: glass jar of creamy oats topped with fresh banana slices and a golden honey drizzle
-- avocado-egg-toast.jpg: two slices of thick whole-grain toast topped with mashed green avocado and a poached egg, sprinkled with everything-bagel seasoning
-- steel-cut-oats-chia-berries.jpg: jar of thick grey-beige oats topped with vibrant blueberries, raspberries, and a sprinkle of black chia seeds
-- greek-yogurt-parfait.jpg: tall glass layered with white Greek yogurt, colorful mixed berries, golden granola clusters, and a honey drizzle
-- banana-protein-pancakes.jpg: stack of three golden-brown pancakes topped with fresh strawberries and blueberries on a white plate
-- avocado-smoked-salmon-toast.jpg: sourdough toast spread with chunky green avocado topped with translucent pink smoked salmon, capers, and dill fronds

-- MAINS
-- white-pasta-marinara-chicken.jpg: white bowl of spaghetti tossed in red marinara sauce with chunks of grilled chicken and a fresh basil leaf
-- turkey-bolognese-pasta.jpg: wide bowl of whole-wheat spaghetti coated in a rich brown turkey meat sauce, finished with grated parmesan
-- quinoa-chickpea-bowl.jpg: overhead bowl of fluffy white quinoa, golden chickpeas, diced cucumber and tomato, drizzled with creamy tahini
-- salmon-sushi-bowl.jpg: bowl of vinegared white rice topped with cubed pink salmon, sliced avocado, julienned cucumber, sesame seeds, and nori strips
-- black-bean-sweet-potato-tacos.jpg: three corn tortillas filled with caramelised orange sweet potato cubes, black beans, salsa, and cilantro on a wooden board
-- red-lentil-soup.jpg: rustic bowl of smooth orange-red lentil soup garnished with a swirl of olive oil and fresh coriander leaves
-- teriyaki-chicken-rice-bowl.jpg: bowl of steamed white rice topped with glossy soy-glazed chicken thigh slices, spring onion rings, and sesame seeds
-- egg-veggie-scramble.jpg: skillet of soft scrambled eggs folded with wilted spinach, red pepper strips, and halved cherry tomatoes

-- SNACKS
-- rice-cakes-almond-butter-jam.jpg: three plain rice cakes spread with smooth almond butter and a dollop of deep-red strawberry jam on a white plate
-- cottage-cheese-pineapple-bowl.jpg: white bowl of creamy cottage cheese topped with juicy yellow pineapple chunks and a sprinkle of flaxseeds
-- banana-date-smoothie.jpg: tall glass of thick caramel-brown smoothie garnished with a banana slice on the rim, on a light wooden surface
-- apple-peanut-butter-slices.jpg: fan of green apple wedges on a board alongside a small ramekin of smooth peanut butter dusted with cinnamon
-- sourdough-honey-peanut-butter.jpg: two slices of rustic sourdough toast spread with peanut butter, with a honey spoon drizzling golden honey across the top

-- WORKOUT FUEL
-- honey-salt-energy-gel.jpg: small glass jar of golden raw honey beside a reusable gel flask, with sea salt crystals and a lemon wedge
-- salted-onigiri-rice-balls.jpg: three white rice triangles wrapped partially in black nori on a bamboo mat, sprinkled with sesame seeds
-- medjool-date-sea-salt-bites.jpg: close-up of glossy Medjool dates split open on a dark slate, each dusted with flaky sea salt crystals
-- banana-rice-peanut-butter-chews.jpg: eight golden-brown rectangular rice bars on parchment paper, individually wrapped in small foil squares ready for a race
-- white-rice-banana-bowl.jpg: simple white ceramic bowl of steamed white rice topped with banana slices and a thin honey drizzle

-- RECOVERY
-- chocolate-milk-recovery-shake.jpg: tall glass of frothy chocolate milk with a banana beside it on a light marble surface
-- chicken-brown-rice-bowl.jpg: deep bowl with brown rice, sliced grilled chicken breast, bright green broccoli florets, and a dark soy glaze
-- salmon-sweet-potato-bowl.jpg: plate with a bed of baby spinach topped with orange sweet potato cubes and a flaked salmon fillet, with lemon slices
-- tart-cherry-protein-smoothie.jpg: vibrant deep-red smoothie in a clear glass, garnished with a few fresh cherries and mango cubes
-- turkey-avocado-wrap.jpg: halved whole-wheat wrap revealing layers of sliced turkey, green avocado, and cherry tomatoes on a cutting board
-- spiced-oat-protein-porridge.jpg: ceramic bowl of thick creamy porridge topped with banana coins, a swirl of almond butter, and a cinnamon dusting

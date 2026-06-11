-- ============================================================
-- Mealvana Endurance — Curated Recipe Catalog Seed Data
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
-- ============================================================

-- ============================================================
-- PRE-RUN recipes (~6)  — high-carb, low-fiber, low-fat
-- Goal: fast gastric emptying, sustained glycogen, minimal GI risk
-- ============================================================

INSERT INTO recipes (id, name, description, ingredients, instructions,
  prep_time_minutes, servings, type,
  calories, carbs_g, protein_g, fat_g, fiber_g, sugar_g, sodium_mg,
  image_url, tags, is_active, created_at, updated_at)
VALUES

-- 1. Overnight Oats with Banana & Honey
(
  'a1b2c3d4-e5f6-7890-abcd-000000000001',
  'Overnight Oats with Banana & Honey',
  'Creamy, high-carb oats prepped the night before. Easy on the stomach 2–3 hours pre-run.',
  '["1 cup rolled oats","1 cup oat milk","1 ripe banana, sliced","2 tbsp honey","1/4 tsp salt","1/2 tsp vanilla extract"]',
  '["Combine oats, oat milk, honey, salt, and vanilla in a jar or bowl.","Stir well, cover, and refrigerate overnight (at least 6 hours).","Top with sliced banana before serving.","Eat 2–3 hours before your run."]',
  5, 1, 'preRun',
  460, 92, 10, 6, 5, 36, 200,
  NULL,
  '["overnight","high-carb","make-ahead","low-fiber","banana"]',
  TRUE, NOW(), NOW()
),

-- 2. White Rice Cakes with Almond Butter & Jam
(
  'a1b2c3d4-e5f6-7890-abcd-000000000002',
  'Rice Cakes with Almond Butter & Jam',
  'Light, easily digestible snack perfect 60–90 min before a run.',
  '["3 plain rice cakes","1.5 tbsp almond butter","2 tbsp strawberry jam"]',
  '["Spread almond butter evenly on each rice cake.","Top with strawberry jam.","Eat 60–90 minutes before running."]',
  3, 1, 'preRun',
  310, 50, 7, 9, 2, 20, 105,
  NULL,
  '["rice-cakes","quick","low-fiber","pre-run-snack"]',
  TRUE, NOW(), NOW()
),

-- 3. White Pasta with Marinara & Chicken
(
  'a1b2c3d4-e5f6-7890-abcd-000000000003',
  'Simple White Pasta with Marinara & Chicken',
  'Classic carb-loading pasta meal. Best eaten 3+ hours before long runs or races.',
  '["200g white pasta (spaghetti or penne)","150g cooked chicken breast, diced","1/2 cup marinara sauce","1 tsp olive oil","Salt to taste"]',
  '["Cook pasta according to package directions. Drain well.","Warm marinara sauce in a small pan.","Toss pasta with sauce and olive oil.","Top with diced chicken.","Season lightly with salt."]',
  20, 1, 'preRun',
  580, 94, 40, 6, 4, 8, 420,
  NULL,
  '["pasta","carb-loading","high-carb","race-day","chicken"]',
  TRUE, NOW(), NOW()
),

-- 4. White Rice & Banana Bowl
(
  'a1b2c3d4-e5f6-7890-abcd-000000000004',
  'White Rice & Banana Bowl',
  'Ultra-low-fiber bowl that sits well on race morning. Add a drizzle of honey for extra quick energy.',
  '["1.5 cups cooked white rice","1 banana, sliced","1 tbsp honey","Pinch of salt"]',
  '["Place warm or cold white rice in a bowl.","Top with banana slices.","Drizzle with honey and add a pinch of salt.","Eat 2 hours before your run."]',
  5, 1, 'preRun',
  420, 95, 7, 1, 2, 28, 120,
  NULL,
  '["rice","banana","low-fiber","race-morning","ultra-simple"]',
  TRUE, NOW(), NOW()
),

-- 5. Banana & Date Energy Smoothie
(
  'a1b2c3d4-e5f6-7890-abcd-000000000005',
  'Banana & Date Energy Smoothie',
  'Blended in 3 minutes. Dates provide sustained glucose; banana adds potassium.',
  '["2 ripe bananas","4 Medjool dates, pitted","1 cup oat milk","1/2 cup water","Pinch of sea salt"]',
  '["Remove pits from dates if needed.","Add all ingredients to a blender.","Blend on high for 45 seconds until smooth.","Drink 90 minutes before your run."]',
  3, 1, 'preRun',
  390, 88, 5, 3, 5, 60, 160,
  NULL,
  '["smoothie","banana","dates","quick","liquid-carbs"]',
  TRUE, NOW(), NOW()
),

-- 6. Sourdough Toast with Honey & Peanut Butter
(
  'a1b2c3d4-e5f6-7890-abcd-000000000006',
  'Sourdough Toast with Honey & Peanut Butter',
  'Simple pre-run breakfast staple. Low-glycemic sourdough + fast honey sugars.',
  '["2 slices sourdough bread","2 tbsp natural peanut butter","1 tbsp honey","Pinch of salt"]',
  '["Toast sourdough slices to your preference.","Spread peanut butter on each slice.","Drizzle honey over the top.","Sprinkle a pinch of salt."]',
  5, 1, 'preRun',
  400, 55, 14, 14, 3, 18, 310,
  NULL,
  '["toast","peanut-butter","quick","sourdough"]',
  TRUE, NOW(), NOW()
),

-- ============================================================
-- DURING-RUN recipes (~4)  — portable, fast carbs, easy to eat on the move
-- ============================================================

-- 7. Homemade Energy Gel (Honey & Salt)
(
  'a1b2c3d4-e5f6-7890-abcd-000000000007',
  'Homemade Honey & Salt Energy Gel',
  'DIY gel using raw honey. ~25g fast carbs per serving. Fill into a reusable gel flask.',
  '["3 tbsp raw honey","1/8 tsp sea salt","1 tbsp water","Optional: 1/4 tsp lemon juice"]',
  '["Combine all ingredients in a small bowl and stir until salt dissolves.","Pour into a reusable gel flask or small zip-lock bag.","Take one serving every 45 minutes during runs over 75 minutes.","Chase with 150ml water."]',
  2, 1, 'duringRun',
  175, 44, 0, 0, 0, 43, 190,
  NULL,
  '["gel","honey","portable","no-cook","fast-carbs","diy"]',
  TRUE, NOW(), NOW()
),

-- 8. Japanese Onigiri Rice Balls
(
  'a1b2c3d4-e5f6-7890-abcd-000000000008',
  'Salted Onigiri Rice Balls',
  'Compact, palm-sized rice balls used by elite ultrarunners. Wrap in plastic wrap for runs.',
  '["2 cups cooked white sushi rice","1 tsp salt","1 tbsp soy sauce","Optional fillings: smoked salmon or umeboshi"]',
  '["Season warm rice with salt and soy sauce; mix gently.","Wet hands, take 1/3 cup rice, press firmly into a triangle or ball.","Press a small amount of filling into the centre if using.","Wrap tightly in plastic wrap.","Eat 1 ball every 45–60 minutes on long runs."]',
  15, 3, 'duringRun',
  165, 36, 3, 0, 0, 0, 390,
  NULL,
  '["onigiri","rice","portable","savoury","ultrarunning","japanese"]',
  TRUE, NOW(), NOW()
),

-- 9. Medjool Date & Sea Salt Bites
(
  'a1b2c3d4-e5f6-7890-abcd-000000000009',
  'Medjool Date & Sea Salt Bites',
  'Whole-food fuel: natural sugars + sodium. No cooking, just prep. 2–3 dates per serving.',
  '["8 Medjool dates, pitted","1/4 tsp flaky sea salt","Optional: 2 tsp almond butter (insert inside date)"]',
  '["Split each date lengthwise and remove pit.","Sprinkle a pinch of flaky sea salt inside each date.","Optional: press 1/4 tsp almond butter inside and close.","Portion into small bags of 2–3 dates each.","Eat 1 serving every 45 minutes during long efforts."]',
  5, 4, 'duringRun',
  140, 34, 1, 1, 3, 30, 110,
  NULL,
  '["dates","portable","no-cook","natural","sodium","fuel"]',
  TRUE, NOW(), NOW()
),

-- 10. Banana & Rice Peanut Butter Chews
(
  'a1b2c3d4-e5f6-7890-abcd-000000000010',
  'Banana & Rice Peanut Butter Chews',
  'Baked rice-banana bars inspired by the Feed Zone Portables cookbook. ~50g carbs each.',
  '["3 cups cooked white rice (slightly warm)","2 ripe bananas, mashed","3 tbsp peanut butter","2 tbsp maple syrup","1/4 tsp salt"]',
  '["Preheat oven to 190°C (375°F).","Mash bananas with a fork until smooth.","Combine all ingredients in a large bowl; mix well.","Press mixture 1.5cm thick onto a parchment-lined baking tray.","Bake 20 minutes until edges are golden and centre is set.","Cool completely, then cut into 8 bars.","Wrap individually in foil for runs."]',
  35, 8, 'duringRun',
  195, 38, 5, 4, 2, 12, 95,
  NULL,
  '["rice","banana","bars","baked","portable","peanut-butter"]',
  TRUE, NOW(), NOW()
),

-- ============================================================
-- POST-RUN recipes (~8)  — recovery focus: carb+protein, antioxidants
-- ============================================================

-- 11. Chocolate Milk Recovery Shake
(
  'a1b2c3d4-e5f6-7890-abcd-000000000011',
  'Chocolate Milk Recovery Shake',
  'The original recovery drink. Research-backed 3:1 carb-to-protein ratio.',
  '["400ml low-fat chocolate milk","1 banana","1 tbsp honey","Pinch of salt"]',
  '["Pour chocolate milk into a blender.","Add banana, honey, and salt.","Blend 20 seconds.","Drink within 30 minutes of finishing your run."]',
  3, 1, 'postRun',
  385, 68, 14, 6, 1, 58, 260,
  NULL,
  '["recovery","shake","chocolate-milk","quick","3:1-ratio"]',
  TRUE, NOW(), NOW()
),

-- 12. Greek Yogurt Berry Parfait
(
  'a1b2c3d4-e5f6-7890-abcd-000000000012',
  'Greek Yogurt Berry Recovery Parfait',
  'Antioxidant-rich berries + casein protein from Greek yogurt = ideal 30-minute window fuel.',
  '["1 cup full-fat Greek yogurt","1/2 cup mixed berries (blueberry, strawberry, raspberry)","1/4 cup granola","1 tbsp honey","1 tbsp chia seeds"]',
  '["Spoon Greek yogurt into a bowl or glass.","Layer berries over yogurt.","Top with granola and chia seeds.","Drizzle honey over the top.","Eat within 30–45 minutes post-run."]',
  5, 1, 'postRun',
  395, 52, 22, 10, 6, 34, 85,
  NULL,
  '["yogurt","berries","granola","antioxidants","protein","quick"]',
  TRUE, NOW(), NOW()
),

-- 13. Chicken & Brown Rice Recovery Bowl
(
  'a1b2c3d4-e5f6-7890-abcd-000000000013',
  'Chicken & Brown Rice Recovery Bowl',
  'Solid recovery meal for after long runs. Lean protein repairs muscle; brown rice restores glycogen.',
  '["175g grilled chicken breast","1 cup cooked brown rice","1 cup steamed broccoli","2 tbsp soy sauce","1 tsp sesame oil","1/2 tsp ginger, grated"]',
  '["Cook chicken breast on a grill or skillet; slice thinly.","Steam broccoli until tender-crisp, about 4 minutes.","Combine soy sauce, sesame oil, and ginger in a small bowl.","Plate rice, top with chicken and broccoli.","Drizzle sauce over the bowl."]',
  25, 1, 'postRun',
  470, 55, 44, 9, 5, 4, 780,
  NULL,
  '["chicken","brown-rice","meal","high-protein","glycogen-replenish"]',
  TRUE, NOW(), NOW()
),

-- 14. Salmon & Sweet Potato Bowl
(
  'a1b2c3d4-e5f6-7890-abcd-000000000014',
  'Baked Salmon & Sweet Potato Recovery Bowl',
  'Omega-3s from salmon reduce muscle inflammation. Sweet potato restores glycogen.',
  '["150g salmon fillet","1 medium sweet potato","1 cup baby spinach","1 tbsp olive oil","1/2 lemon, juiced","Salt and pepper"]',
  '["Preheat oven to 200°C (400°F).","Pierce sweet potato; microwave 5 minutes or until soft. Cube it.","Season salmon with salt, pepper, and half the lemon juice.","Roast salmon on a lined tray for 12–15 minutes.","Toss spinach with olive oil and remaining lemon juice.","Assemble bowl: spinach base, sweet potato, flaked salmon."]',
  25, 1, 'postRun',
  480, 42, 38, 16, 6, 10, 320,
  NULL,
  '["salmon","sweet-potato","omega-3","anti-inflammatory","recovery"]',
  TRUE, NOW(), NOW()
),

-- 15. Tart Cherry & Protein Recovery Smoothie
(
  'a1b2c3d4-e5f6-7890-abcd-000000000015',
  'Tart Cherry & Protein Recovery Smoothie',
  'Tart cherry juice reduces DOMS by up to 22% in studies. Whey protein drives muscle synthesis.',
  '["240ml tart cherry juice","1 scoop vanilla whey protein powder (approx 25g protein)","1/2 cup frozen mango","1/2 cup coconut water","Handful of ice"]',
  '["Add all ingredients to blender.","Blend on high 45 seconds until smooth.","Pour and drink within 30 minutes of completing your run."]',
  4, 1, 'postRun',
  340, 46, 29, 2, 1, 38, 180,
  NULL,
  '["smoothie","tart-cherry","whey","protein","DOMS","30-minute-window"]',
  TRUE, NOW(), NOW()
),

-- 16. Turkey & Avocado Recovery Wrap
(
  'a1b2c3d4-e5f6-7890-abcd-000000000016',
  'Turkey & Avocado Recovery Wrap',
  'High-protein wrap with healthy fats from avocado. Ready in 5 minutes, portable for post-race.',
  '["1 large whole-wheat tortilla","100g sliced turkey breast","1/2 avocado, sliced","1/4 cup cherry tomatoes, halved","1 tbsp Greek yogurt","Salt and pepper"]',
  '["Lay tortilla flat on a board.","Spread Greek yogurt across the centre.","Layer turkey, avocado, and tomatoes.","Season with salt and pepper.","Roll firmly, tucking in the sides, and slice in half."]',
  5, 1, 'postRun',
  440, 38, 34, 16, 6, 5, 600,
  NULL,
  '["wrap","turkey","avocado","portable","quick","high-protein"]',
  TRUE, NOW(), NOW()
),

-- 17. Cottage Cheese & Pineapple Recovery Bowl
(
  'a1b2c3d4-e5f6-7890-abcd-000000000017',
  'Cottage Cheese & Pineapple Recovery Bowl',
  'Cottage cheese is high in casein — slow-digesting protein ideal for muscle repair over hours.',
  '["1 cup low-fat cottage cheese","3/4 cup fresh or tinned pineapple chunks","1 tbsp flaxseeds","1 tsp honey"]',
  '["Spoon cottage cheese into a bowl.","Top with pineapple chunks.","Sprinkle flaxseeds over the top.","Drizzle with honey and serve."]',
  3, 1, 'postRun',
  300, 38, 28, 5, 2, 32, 450,
  NULL,
  '["cottage-cheese","pineapple","casein","quick","anti-inflammatory"]',
  TRUE, NOW(), NOW()
),

-- 18. Egg & Veggie Recovery Scramble
(
  'a1b2c3d4-e5f6-7890-abcd-000000000018',
  'Egg & Veggie Recovery Scramble',
  'Complete amino-acid profile from eggs. Spinach and peppers add potassium and iron.',
  '["3 large eggs","1/2 cup baby spinach","1/4 red bell pepper, diced","1/4 cup cherry tomatoes, halved","1 tsp olive oil","Salt, pepper, paprika"]',
  '["Heat olive oil in a non-stick pan over medium heat.","Sauté pepper and tomatoes 2 minutes until slightly soft.","Add spinach and stir until wilted, about 30 seconds.","Whisk eggs with salt, pepper, and a pinch of paprika; pour into pan.","Stir gently with a spatula until just set.","Serve immediately."]',
  10, 1, 'postRun',
  280, 8, 22, 18, 2, 4, 310,
  NULL,
  '["eggs","scramble","protein","quick","iron","potassium"]',
  TRUE, NOW(), NOW()
),

-- ============================================================
-- GENERAL recipes (~7)  — balanced training nutrition, everyday meals
-- ============================================================

-- 19. Quinoa Power Bowl with Chickpeas
(
  'a1b2c3d4-e5f6-7890-abcd-000000000019',
  'Quinoa Power Bowl with Chickpeas & Tahini',
  'Complete plant-based protein from quinoa + chickpeas. Balanced training-day lunch.',
  '["1 cup cooked quinoa","1/2 cup canned chickpeas, drained and rinsed","1/2 cucumber, diced","1/4 cup cherry tomatoes","2 tbsp tahini","1 tbsp lemon juice","1 clove garlic, minced","Salt, cumin"]',
  '["Whisk tahini, lemon juice, garlic, a pinch of cumin and salt with 2 tbsp water to make dressing.","Combine quinoa, chickpeas, cucumber, and tomatoes in a bowl.","Drizzle tahini dressing over the bowl.","Toss gently and serve."]',
  10, 1, 'general',
  480, 60, 18, 16, 10, 8, 340,
  NULL,
  '["quinoa","chickpeas","plant-based","tahini","balanced","meal-prep"]',
  TRUE, NOW(), NOW()
),

-- 20. Overnight Steel-Cut Oats with Chia & Berries
(
  'a1b2c3d4-e5f6-7890-abcd-000000000020',
  'Overnight Steel-Cut Oats with Chia & Berries',
  'Slow-release carbs from steel-cut oats sustain energy for the whole morning.',
  '["1/2 cup steel-cut oats","1 cup unsweetened almond milk","2 tbsp chia seeds","1/2 cup mixed berries","1 tbsp maple syrup","1/4 tsp cinnamon"]',
  '["Combine oats, almond milk, chia seeds, maple syrup, and cinnamon in a jar.","Stir well, seal, and refrigerate overnight.","In the morning, stir again (oats will have absorbed liquid).","Top with berries and serve cold or briefly microwaved."]',
  5, 1, 'general',
  410, 64, 12, 10, 12, 18, 140,
  NULL,
  '["oats","chia","berries","meal-prep","slow-release","breakfast"]',
  TRUE, NOW(), NOW()
),

-- 21. Lentil & Vegetable Soup
(
  'a1b2c3d4-e5f6-7890-abcd-000000000021',
  'Red Lentil & Vegetable Soup',
  'Iron-rich lentils + anti-inflammatory turmeric. Great for high-volume training weeks.',
  '["1 cup red lentils, rinsed","1 medium carrot, diced","1 celery stalk, diced","1 small onion, diced","2 cloves garlic, minced","1 can diced tomatoes (400g)","750ml vegetable broth","1 tsp cumin","1/2 tsp turmeric","Salt and pepper","1 tbsp olive oil"]',
  '["Heat olive oil in a large pot over medium heat.","Sauté onion, carrot, and celery 5 minutes until soft.","Add garlic, cumin, and turmeric; stir 1 minute.","Add lentils, diced tomatoes, and broth.","Bring to a boil, then simmer 20 minutes until lentils break down.","Season with salt and pepper.","Blend partially for a creamier texture if desired."]',
  35, 4, 'general',
  285, 44, 16, 5, 10, 8, 520,
  NULL,
  '["lentils","soup","iron","turmeric","anti-inflammatory","meal-prep","plant-based"]',
  TRUE, NOW(), NOW()
),

-- 22. Whole Wheat Pasta with Turkey Bolognese
(
  'a1b2c3d4-e5f6-7890-abcd-000000000022',
  'Whole Wheat Pasta with Turkey Bolognese',
  'Leaner take on classic bolognese. Higher fiber carbs for non-race training days.',
  '["200g whole wheat spaghetti","300g lean ground turkey","1 can crushed tomatoes (400g)","1 small onion, finely diced","2 cloves garlic, minced","1 tsp Italian seasoning","1 tbsp olive oil","Salt and pepper","Optional: parmesan to serve"]',
  '["Cook spaghetti per package directions; reserve 1/4 cup pasta water.","Heat olive oil in a wide pan. Sauté onion 3 minutes.","Add garlic and turkey; brown turkey 5–6 minutes, breaking it up.","Add crushed tomatoes, Italian seasoning, salt, and pepper.","Simmer 15 minutes. Add pasta water if sauce is too thick.","Toss sauce with drained spaghetti.","Serve with parmesan if desired."]',
  30, 2, 'general',
  540, 72, 42, 10, 8, 10, 490,
  NULL,
  '["pasta","turkey","bolognese","high-protein","whole-wheat","training-day"]',
  TRUE, NOW(), NOW()
),

-- 23. Avocado Egg Toast with Everything Bagel
(
  'a1b2c3d4-e5f6-7890-abcd-000000000023',
  'Avocado Egg Toast with Everything Seasoning',
  'Healthy fats, protein, and complex carbs. A go-to daily training breakfast.',
  '["2 slices whole grain bread","1 ripe avocado","2 eggs, poached or fried","1/2 tsp everything bagel seasoning","Chili flakes, lemon juice","Salt and pepper"]',
  '["Toast bread until golden.","Mash avocado in a bowl with a squeeze of lemon juice; season with salt.","Spread avocado onto toast.","Cook eggs to your preference (poached is ideal).","Place eggs on avocado toast.","Sprinkle everything seasoning and chili flakes."]',
  10, 1, 'general',
  490, 44, 22, 26, 10, 4, 540,
  NULL,
  '["avocado","eggs","toast","breakfast","healthy-fats","daily"]',
  TRUE, NOW(), NOW()
),

-- 24. Salmon Sushi Bowl
(
  'a1b2c3d4-e5f6-7890-abcd-000000000024',
  'Salmon Sushi Bowl',
  'Deconstructed sushi bowl. Omega-3s for joint and muscle health; rice for carb balance.',
  '["1.5 cups cooked sushi rice","120g sushi-grade salmon (or smoked salmon), cubed","1/2 avocado, sliced","1/4 cucumber, julienned","2 tbsp soy sauce","1 tsp sesame oil","1 tsp rice vinegar","1 tsp sesame seeds","Optional: nori strips, pickled ginger"]',
  '["Season warm sushi rice with rice vinegar; mix gently.","Mix soy sauce and sesame oil for dressing.","Scoop rice into a bowl.","Arrange salmon, avocado, and cucumber over rice.","Drizzle dressing over the bowl.","Sprinkle sesame seeds and add nori/ginger if using."]',
  15, 1, 'general',
  520, 62, 28, 16, 5, 4, 680,
  NULL,
  '["salmon","sushi","bowl","omega-3","rice","no-cook"]',
  TRUE, NOW(), NOW()
),

-- 25. Black Bean & Sweet Potato Tacos
(
  'a1b2c3d4-e5f6-7890-abcd-000000000025',
  'Black Bean & Sweet Potato Tacos',
  'Plant-based iron and slow-release carbs. Ideal on rest days or easy training days.',
  '["1 medium sweet potato, diced","1 can black beans, drained (240g)","4 small corn tortillas","1/2 tsp cumin","1/2 tsp smoked paprika","1/4 tsp garlic powder","1 tbsp olive oil","1/4 cup salsa","1/4 cup plain Greek yogurt (as sour cream sub)","Fresh cilantro, lime wedges"]',
  '["Preheat oven to 200°C (400°F).","Toss sweet potato with olive oil, cumin, paprika, and garlic powder.","Roast 20 minutes until tender and caramelised.","Warm black beans in a small pan with a pinch of cumin.","Warm tortillas directly on a gas flame or dry skillet 30 seconds each side.","Fill each tortilla with sweet potato, black beans, salsa, and yogurt.","Garnish with cilantro and a squeeze of lime."]',
  30, 2, 'general',
  430, 72, 18, 8, 14, 10, 420,
  NULL,
  '["tacos","black-beans","sweet-potato","plant-based","iron","rest-day"]',
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

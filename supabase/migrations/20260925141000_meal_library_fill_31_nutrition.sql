-- Fill the 31 active meal_library rows whose kcal/carbs_g/protein_g/fat_g were all null (Finding 29-001).
--
-- Depends on 20260925140000_meal_library_nutrition_origin.sql (nutrition_origin, nutrition_source_url).
-- Idempotent: each UPDATE only touches its row while kcal is still null, so a re-run changes nothing
-- and never overwrites a number set later by hand.
--
-- Basis: per serving, where one serving is the row's ingredient list (grocery.ts treats library
-- ingredients as one athlete serving; plan_meals copies these numbers per serving). kcal is rounded
-- to 10, macros to the gram, the same precision as the rest of the library.
--
-- Provenance: all 31 are ai_estimated. The rows' source pages (Greenletes "plant-based bowl formula",
-- No Meat Athlete, MamaSezz, Peloton, BikeRadar, active.com, nduranz, SM Nutrition RD) name the dishes
-- but none states kcal AND macros for them; published recipes of similar dishes use different
-- ingredients or ratios, so none could be scaled exactly. Each value is the sum of the listed
-- ingredients at USDA FoodData Central SR Legacy values per 100 g (a retail label where USDA has
-- no entry). Roasted/sauteed vegetables count only the oil the row lists. Full per-ingredient
-- breakdown: docs/new_mealplanning/assembly-library-research/null-nutrition-31.json.
--
-- Batch snacks (AB-195, AS-158, AS-159, AS-160, AS-161): the rows list a whole batch of bites as one
-- serving (servings = 1), which would read as a 600-1,400 kcal snack. Their numbers are for two
-- ~25 g bites (batch weight / 25 g = bite count), which is the portion the library research
-- (assembly-library.md "Approx") describes. The ingredient quantities still list the batch.

-- AB-036 · Rice cereal with orange juice
--   50 g label, Kellogg's Rice Krispies; 208 g USDA orange juice (200 ml = 208 g)
--   4/4/9 check: 286 kcal
update public.meal_library set kcal = 280, carbs_g = 65, protein_g = 4, fat_g = 1, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AB-036' and kcal is null;

-- AB-055 · White rice with fructose & jam
--   150 g USDA rice, white, long-grain, enriched, cooked; 40 g USDA jams and preserves (2 tbsp = 40 g)
--   4/4/9 check: 301 kcal
update public.meal_library set kcal = 310, carbs_g = 70, protein_g = 4, fat_g = 0.5, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AB-055' and kcal is null;

-- AB-195 · Gluten-free oat & sunflower-butter energy bites with dried fruit
--   81 g USDA oats, rolled (1 cup = 81 g); 128 g USDA sunflower seed butter (1/2 cup = 128 g); 80 g USDA maple syrup (1 tbsp = 20 g); 40 g USDA raisins, as "dried fruit" (1/4 cup = 40 g)
--   batch 329 g ≈ 13 bites of 25 g; one serving = 2 bites (1/6.5 of batch); batch total 1424 kcal
--   4/4/9 check: 231 kcal
update public.meal_library set kcal = 220, carbs_g = 26, protein_g = 5, fat_g = 12, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AB-195' and kcal is null;

-- AD-101 · Rice, baked tofu & roasted broccoli bowl with sriracha
--   250 g USDA rice, white, long-grain, enriched, cooked; 150 g USDA tofu, raw, firm, prepared with calcium sulfate; 150 g USDA broccoli, cooked; 16 g USDA hot chile sauce, sriracha (1 tbsp = 16 g); 3 g USDA sesame seeds
--   4/4/9 check: 650 kcal
update public.meal_library set kcal = 630, carbs_g = 89, protein_g = 37, fat_g = 16, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-101' and kcal is null;

-- AD-102 · Quinoa, black beans & roasted sweet potato bowl with salsa
--   200 g USDA quinoa, cooked; 150 g USDA beans, black, canned, drained; 150 g USDA sweet potato, baked in skin; 48 g USDA sauce, salsa, ready-to-serve (3 tbsp = 48 g); 68 g USDA avocados, raw (1/2 fruit = 68 g flesh)
--   4/4/9 check: 653 kcal
update public.meal_library set kcal = 640, carbs_g = 107, protein_g = 23, fat_g = 15, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-102' and kcal is null;

-- AD-103 · Farro, chickpea & roasted cauliflower bowl with tahini
--   200 g USDA spelt, cooked (no farro entry; emmer is a hulled wheat of the same profile); 150 g USDA chickpeas, canned, drained, rinsed; 150 g USDA cauliflower, cooked; 30 g label, jarred tahini sauce (2 tbsp = 30 g = 80 kcal)
--   4/4/9 check: 610 kcal
update public.meal_library set kcal = 580, carbs_g = 97, protein_g = 26, fat_g = 13, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-103' and kcal is null;

-- AD-104 · Bulgur, edamame & roasted beet bowl with balsamic vinaigrette
--   200 g USDA bulgur, cooked; 120 g USDA edamame, frozen, prepared; 120 g USDA beets, cooked; 30 g label, bottled balsamic vinaigrette (2 tbsp = 30 g = 90 kcal)
--   4/4/9 check: 484 kcal
update public.meal_library set kcal = 450, carbs_g = 63, protein_g = 23, fat_g = 16, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-104' and kcal is null;

-- AD-105 · Wheatberries, white bean & raw cabbage-carrot bowl with hummus
--   200 g USDA wheat, hard red winter (dry) scaled to cooked at 2.5x weight; 150 g USDA beans, white, canned; 80 g USDA cabbage, raw; 60 g USDA carrots, raw; 45 g USDA hummus, commercial (3 tbsp = 45 g)
--   4/4/9 check: 581 kcal
update public.meal_library set kcal = 550, carbs_g = 105, protein_g = 26, fat_g = 6, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-105' and kcal is null;

-- AD-106 · Rice, kidney bean & roasted green bean bowl with teriyaki
--   250 g USDA rice, brown, long-grain, cooked; 150 g USDA beans, kidney, red, canned, drained; 150 g USDA snap beans, green, cooked; 36 g USDA sauce, teriyaki, ready-to-serve (2 tbsp = 36 g)
--   4/4/9 check: 537 kcal
update public.meal_library set kcal = 530, carbs_g = 105, protein_g = 22, fat_g = 3, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-106' and kcal is null;

-- AD-107 · Quinoa, tempeh & roasted pepper-onion bowl with sriracha
--   200 g USDA quinoa, cooked; 150 g USDA tempeh; 80 g USDA peppers, sweet, red, raw; 60 g USDA onions, cooked; 16 g USDA hot chile sauce, sriracha (1 tbsp = 16 g)
--   4/4/9 check: 621 kcal
update public.meal_library set kcal = 590, carbs_g = 68, protein_g = 41, fat_g = 21, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-107' and kcal is null;

-- AD-108 · Spelt, lentil & raw pepper-carrot bowl with balsamic
--   200 g USDA spelt, cooked; 150 g USDA lentils, cooked; 60 g USDA peppers, sweet, red, raw; 60 g USDA carrots, raw; 30 g label, bottled balsamic vinaigrette (2 tbsp = 30 g = 90 kcal)
--   4/4/9 check: 589 kcal
update public.meal_library set kcal = 560, carbs_g = 95, protein_g = 26, fat_g = 12, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-108' and kcal is null;

-- AD-109 · Rice, seitan & roasted broccoli bowl with tzatziki (dairy-free)
--   250 g USDA rice, white, long-grain, enriched, cooked; 150 g label, packaged seitan (no USDA entry); 150 g USDA broccoli, cooked; 45 g label, dairy-free tzatziki (3 tbsp = 45 g = 60 kcal)
--   4/4/9 check: 634 kcal
update public.meal_library set kcal = 620, carbs_g = 92, protein_g = 47, fat_g = 9, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-109' and kcal is null;

-- AD-110 · Amaranth, black bean & roasted sweet potato bowl with pico de gallo
--   200 g USDA amaranth grain, cooked; 150 g USDA beans, black, canned, drained; 150 g USDA sweet potato, baked in skin; 48 g USDA sauce, salsa, ready-to-serve (3 tbsp = 48 g)
--   4/4/9 check: 504 kcal
update public.meal_library set kcal = 490, carbs_g = 97, protein_g = 20, fat_g = 4, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-110' and kcal is null;

-- AD-111 · Quinoa, chickpea & roasted green bean bowl with hummus and pumpkin seeds
--   200 g USDA quinoa, cooked; 150 g USDA chickpeas, canned, drained, rinsed; 150 g USDA snap beans, green, cooked; 45 g USDA hummus, commercial (3 tbsp = 45 g); 9 g USDA pumpkin seeds, dried (1 tbsp = 9 g)
--   4/4/9 check: 647 kcal
update public.meal_library set kcal = 630, carbs_g = 96, protein_g = 28, fat_g = 17, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-111' and kcal is null;

-- AD-112 · Rice, edamame & roasted cauliflower bowl with peanut sauce
--   250 g USDA rice, white, long-grain, enriched, cooked; 120 g USDA edamame, frozen, prepared; 150 g USDA cauliflower, cooked; 36 g label, jarred peanut sauce (2 tbsp = 36 g = 90 kcal)
--   4/4/9 check: 611 kcal
update public.meal_library set kcal = 600, carbs_g = 96, protein_g = 27, fat_g = 13, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-112' and kcal is null;

-- AD-113 · Farro, white bean & roasted beet bowl with pesto
--   200 g USDA spelt, cooked (no farro entry; emmer is a hulled wheat of the same profile); 150 g USDA beans, white, canned; 120 g USDA beets, cooked; 30 g label, jarred basil pesto (2 tbsp = 30 g = 130 kcal)
--   4/4/9 check: 641 kcal
update public.meal_library set kcal = 610, carbs_g = 99, protein_g = 26, fat_g = 15, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-113' and kcal is null;

-- AD-114 · Bulgur, black bean & raw cabbage bowl with sriracha and almonds
--   Low for a dinner (380 kcal) because cooked bulgur is 83 kcal/100 g and the row lists no oil; kept, it is what the listed bowl gives.
--   200 g USDA bulgur, cooked; 150 g USDA beans, black, canned, drained; 100 g USDA cabbage, raw; 16 g USDA hot chile sauce, sriracha (1 tbsp = 16 g); 6 g USDA almonds (1 tbsp sliced = 6 g)
--   4/4/9 check: 398 kcal
update public.meal_library set kcal = 380, carbs_g = 72, protein_g = 18, fat_g = 4, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-114' and kcal is null;

-- AD-115 · Quinoa, kidney bean & roasted pepper-carrot bowl with salsa and radish
--   200 g USDA quinoa, cooked; 150 g USDA beans, kidney, red, canned, drained; 60 g USDA peppers, sweet, red, raw; 60 g USDA carrots, cooked; 48 g USDA sauce, salsa, ready-to-serve (3 tbsp = 48 g); 30 g USDA radishes, raw
--   4/4/9 check: 470 kcal
update public.meal_library set kcal = 470, carbs_g = 85, protein_g = 22, fat_g = 5, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-115' and kcal is null;

-- AD-116 · Brown rice, broccoli & black bean bowl
--   250 g USDA rice, brown, long-grain, cooked; 150 g USDA broccoli, cooked; 150 g USDA beans, black, canned, drained; 13.5 g USDA olive oil (1 tbsp = 13.5 g)
--   4/4/9 check: 600 kcal
update public.meal_library set kcal = 590, carbs_g = 94, protein_g = 18, fat_g = 17, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-116' and kcal is null;

-- AD-117 · Brown rice, kale & chickpea bowl
--   250 g USDA rice, brown, long-grain, cooked; 100 g USDA kale, cooked; 150 g USDA chickpeas, canned, drained, rinsed; 13.5 g USDA olive oil (1 tbsp = 13.5 g)
--   4/4/9 check: 642 kcal
update public.meal_library set kcal = 640, carbs_g = 98, protein_g = 18, fat_g = 20, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-117' and kcal is null;

-- AD-118 · Farro, spinach & white bean bowl
--   200 g USDA spelt, cooked (no farro entry; emmer is a hulled wheat of the same profile); 100 g USDA spinach, cooked; 150 g USDA beans, white, canned; 13.5 g USDA olive oil (1 tbsp = 13.5 g)
--   4/4/9 check: 597 kcal
update public.meal_library set kcal = 570, carbs_g = 88, protein_g = 25, fat_g = 16, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-118' and kcal is null;

-- AD-119 · Brown rice, green beans & kidney bean bowl
--   250 g USDA rice, brown, long-grain, cooked; 150 g USDA snap beans, green, cooked; 150 g USDA beans, kidney, red, canned, drained; 13.5 g USDA olive oil (1 tbsp = 13.5 g)
--   4/4/9 check: 628 kcal
update public.meal_library set kcal = 620, carbs_g = 100, protein_g = 20, fat_g = 17, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-119' and kcal is null;

-- AD-120 · Quinoa, broccoli & lentil bowl
--   200 g USDA quinoa, cooked; 150 g USDA broccoli, cooked; 150 g USDA lentils, cooked; 13.5 g USDA olive oil (1 tbsp = 13.5 g)
--   4/4/9 check: 604 kcal
update public.meal_library set kcal = 590, carbs_g = 84, protein_g = 26, fat_g = 18, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-120' and kcal is null;

-- AD-121 · Brown rice, Brussels sprouts & black bean bowl
--   250 g USDA rice, brown, long-grain, cooked; 150 g USDA brussels sprouts, cooked; 150 g USDA beans, black, canned, drained; 13.5 g USDA olive oil (1 tbsp = 13.5 g)
--   4/4/9 check: 602 kcal
update public.meal_library set kcal = 590, carbs_g = 94, protein_g = 19, fat_g = 17, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-121' and kcal is null;

-- AD-122 · Barley, chard & pinto bean bowl
--   200 g USDA barley, pearled, cooked; 100 g USDA chard, swiss, cooked; 150 g USDA beans, pinto, canned, drained; 13.5 g USDA olive oil (1 tbsp = 13.5 g)
--   4/4/9 check: 572 kcal
update public.meal_library set kcal = 560, carbs_g = 90, protein_g = 17, fat_g = 16, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-122' and kcal is null;

-- AD-123 · Brown rice, zucchini & chickpea bowl
--   250 g USDA rice, brown, long-grain, cooked; 150 g USDA squash, summer, zucchini; 150 g USDA chickpeas, canned, drained, rinsed; 13.5 g USDA olive oil (1 tbsp = 13.5 g)
--   4/4/9 check: 638 kcal
update public.meal_library set kcal = 630, carbs_g = 97, protein_g = 18, fat_g = 20, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AD-123' and kcal is null;

-- AL-008 · Sweet potato, feta & spring onion wrap
--   Cross-check: BikeRadar (the row's source) states only "about 400kcal, with 13g fat and 1.3g salt", no carbs or
--   protein, so it is not 'sourced'. The 1 tsp olive oil comes from BikeRadar's method (not in the row's list).
--   150 g USDA sweet potato, baked in skin; 40 g label, reduced-fat feta; 45 g label, wholemeal tortilla, 45 g; 4.5 g USDA olive oil (1 tbsp = 13.5 g)
--   4/4/9 check: 388 kcal
update public.meal_library set kcal = 380, carbs_g = 53, protein_g = 14, fat_g = 13, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AL-008' and kcal is null;

-- AS-158 · Peanut butter energy balls with oats
--   40 g USDA oats, rolled (1 cup = 81 g); 64 g USDA peanut butter, smooth (1/4 cup = 64 g); 40 g USDA maple syrup (1 tbsp = 20 g)
--   batch 144 g ≈ 6 bites of 25 g; one serving = 2 bites (1/3 of batch); batch total 632 kcal
--   4/4/9 check: 221 kcal
update public.meal_library set kcal = 210, carbs_g = 22, protein_g = 7, fat_g = 12, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AS-158' and kcal is null;

-- AS-159 · Oat, nut and dried fruit energy bites with chocolate chips
--   40 g USDA oats, rolled (1 cup = 81 g); 34 g USDA mixed nuts, dry roasted (1/4 cup = 34 g); 40 g USDA raisins, as "dried fruit" (1/4 cup = 40 g); 21 g label, dairy-free dark chocolate chips (2 tbsp = 21 g); 32 g USDA almond butter, as "nut butter" (2 tbsp = 32 g)
--   batch 167 g ≈ 7 bites of 25 g; one serving = 2 bites (1/3.5 of batch); batch total 779 kcal
--   4/4/9 check: 237 kcal
update public.meal_library set kcal = 220, carbs_g = 24, protein_g = 6, fat_g = 13, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AS-159' and kcal is null;

-- AS-160 · No-bake date and oat energy balls
--   175 g USDA dates, medjool (1 cup pitted = 175 g); 81 g USDA oats, rolled (1 cup = 81 g); 64 g USDA almond butter (1/4 cup = 64 g)
--   batch 320 g ≈ 13 bites of 25 g; one serving = 2 bites (1/6.5 of batch); batch total 1185 kcal
--   4/4/9 check: 196 kcal
update public.meal_library set kcal = 180, carbs_g = 30, protein_g = 4, fat_g = 6, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AS-160' and kcal is null;

-- AS-161 · Chickpea cookie dough bites
--   164 g USDA chickpeas, canned, drained, rinsed; 64 g USDA almond butter, as "nut butter" (2 tbsp = 32 g); 40 g USDA maple syrup (1 tbsp = 20 g); 21 g label, dairy-free dark chocolate chips (2 tbsp = 21 g)
--   batch 289 g ≈ 12 bites of 25 g; one serving = 2 bites (1/6 of batch); batch total 830 kcal
--   4/4/9 check: 145 kcal
update public.meal_library set kcal = 140, carbs_g = 15, protein_g = 4, fat_g = 8, nutrition_origin = 'ai_estimated', nutrition_source_url = null, updated_at = now()
  where id = 'AS-161' and kcal is null;

-- plan_meals copies kcal/macros from the library at pick time (vana/plan.ts addMealById, swapMeal),
-- so plans that picked these meals before this fill still hold nulls. Backfill them from the
-- library, only where the plan row is still all-null and the library row was filled above.
-- On prod at cutover plan_meals is empty, so this is a no-op there.
update public.plan_meals pm
   set kcal = ml.kcal, carbs_g = ml.carbs_g, protein_g = ml.protein_g, fat_g = ml.fat_g, updated_at = now()
  from public.meal_library ml
 where pm.library_meal_id = ml.id
   and pm.source = 'library'
   and pm.kcal is null and pm.carbs_g is null and pm.protein_g is null and pm.fat_g is null
   and ml.nutrition_origin is not null
   and ml.kcal is not null;

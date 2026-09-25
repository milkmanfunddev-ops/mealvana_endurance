-- Name the source athlete in meal_library.why rows that start "his " / "her " (Finding 88-010, ticket 128).
--
-- meal_library.why holds the research files' evidence text word for word. Fifteen entries open with
-- "his " or "her ", meaning the athlete named in the row's source, which reads as a typo on its own
-- ("his dinner base is ..."). No letter was lost (Lee, 2026-09-25). Each row below names its source,
-- keeping the quoted words as they are.
--
-- Rows were found in docs/new_mealplanning/assembly-library.md (the merged library) and checked
-- against their research entry:
--   AB-163  breakfast-c.json B-c-006   Katya Meyers
--   AL-200  lunch-c.json     L-c-002   Gluten Free Traveller (celiac marathon runner, unnamed)
--   AD-014..016  dinner-a.json D-a-014..016  David Rother
--   AD-143..145  dinner-b.json D-b-043..045  Dotsie Bausch
--   AD-146..149  dinner-b.json D-b-046..049  Sonya Looney
--   AD-150..151  dinner-b.json D-b-050..051  Nick Squires
--   AD-157  dinner-b.json    D-b-057   Hellah Sidibe
-- A row missing from a database is a no-op. Rows starting capital "Her " (AB-132..138, Gwen Jorgensen,
-- whose name is already in the meal's title) read as sentences and are left alone.
--
-- Idempotent: each UPDATE touches its row only while why still starts "his " / "her ", so a re-run
-- changes nothing and never overwrites text edited later.

update public.meal_library set why = $w$Katya Meyers's own go-to, described as "Justin's nut butter and honey on English muffin"$w$, updated_at = now()
  where id = 'AB-163' and (why like 'his %' or why like 'her %');

update public.meal_library set why = $w$A celiac marathon runner's (Gluten Free Traveller) regular gluten-free sushi order from a local co-op during marathon training — "Fish Nigiri and either fish or vegetable Maki" with wheat-free soy sauce$w$, updated_at = now()
  where id = 'AL-200' and (why like 'his %' or why like 'her %');

update public.meal_library set why = $w$David Rother's dinner base is "rice, quinoa or wholewheat pasta" with vegetables "heated in whatever way is easiest" plus "an avocado, nuts, or seeds"$w$, updated_at = now()
  where id in ('AD-014', 'AD-015', 'AD-016') and (why like 'his %' or why like 'her %');

update public.meal_library set why = $w$Dotsie Bausch's "quick curry" dinner: veggies simmered with "chickpeas, tofu, or tempeh" in a store-bought curry sauce, served over rice -- explicitly offered as an interchangeable protein$w$, updated_at = now()
  where id in ('AD-143', 'AD-144', 'AD-145') and (why like 'his %' or why like 'her %');

update public.meal_library set why = $w$Sonya Looney's dinner rotation is described as "burritos, burrito bowls, quinoa/broccoli wraps, pasta dishes with veggies, homemade cashew-based sauce, and a legume"$w$, updated_at = now()
  where id in ('AD-146', 'AD-147', 'AD-148', 'AD-149') and (why like 'his %' or why like 'her %');

update public.meal_library set why = $w$Nick Squires's dinners: "Beyond Burgers" or Trader Joe's Turkeyless Protein Patties, and "pasta with 'meatballs' and spinach salad"$w$, updated_at = now()
  where id in ('AD-150', 'AD-151') and (why like 'his %' or why like 'her %');

update public.meal_library set why = $w$Hellah Sidibe's own words: "a hearty bowl of white rice, Impossible plant-based meat, avocado, hummus, and kimchi" is his "go-to favorite right now" on high-mileage training days$w$, updated_at = now()
  where id = 'AD-157' and (why like 'his %' or why like 'her %');

-- Check after applying (must return zero rows):
--   select id, left(why, 60) from public.meal_library where why like 'his %' or why like 'her %';

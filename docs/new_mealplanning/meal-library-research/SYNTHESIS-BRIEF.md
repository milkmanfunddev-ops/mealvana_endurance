# Synthesis brief — select the final 100 meals for ONE meal type

You are the editor. Sixteen research agents produced ~900 candidate meals from pro-triathlete diet features,
sports dietitians and endurance cookbooks, TrainerRoad/Reddit threads, Substacks, and diet-specific hunts
(vegan, GF/DF, allergen-safe, paleo/keto/low-carb/Mediterranean, international cuisines, rest-day/race-week/
recovery). Your candidate file (given in your prompt) holds every candidate for YOUR meal type. Read all of it.

## The product bar
Mealvana Endurance users are amateur triathletes/runners/cyclists with jobs. Every entry must pass this test:
**"Yeah, that makes sense — that's what I'd actually eat, and it looks like what a good triathlete eats."**
Real, repeatable, component-style food. Batch-cookable where relevant. No restaurant plating, no influencer
bowls, no obscure ingredients as the core of a meal, no supplements-as-meals (gels/chews/drink mix are
handled elsewhere — chocolate milk / a recovery shake counts as a snack though).

## Select EXACTLY 100 for your meal type, obeying ALL quotas
Coverage quotas (counted "as written", before swaps):
- ≥ 20 `vegan` (which also means vegetarian)
- ≥ 12 more that are `vegetarian` but not vegan (eggs/dairy)
- ≥ 30 gluten-free (no `gluten` in allergens)
- ≥ 30 dairy-free
- ≥ 15 that are simultaneously free of dairy + eggs + peanuts + tree_nuts
- ≥ 12 free of ≥ 6 of the 9 allergens
- ≥ 8 `paleo`, ≥ 8 `keto` and/or `low_carb` (rest-day framing is fine), ≥ 15 `mediterranean`
- ≥ 12 from non-Anglo food cultures (Japanese, Kenyan/Ethiopian, Indian, Mexican/Latin, Med/Italian/Spanish, Korean/Chinese, Nordic, Middle Eastern, Brazilian)
- Context spread: ≥ 12 `rest-day`, ≥ 8 `race-week` and/or `carb-load`, ≥ 12 `recovery`, ≥ 12 `pre-session` (breakfast: ≥ 25 pre-session), ≥ 6 `travel`
- ≥ 40 with a NAMED athlete, dietitian, team chef, or cookbook attribution (keep the attribution honest; keep the URL if there is one)
- ≥ 40 batch-friendly / meal-prep friendly (for breakfast and snack this can be "make 5 jars Sunday")
- No near-duplicates. "Oats + banana + PB" and "Oats + berries + honey" are ONE entry with swaps, unless the second
  is a genuinely different dish (baked oats, overnight oats, savoury oats are different). Max 6 oat-based,
  max 6 egg-centric, max 6 chicken-rice-style, max 5 smoothie entries per 100 (for breakfast/snack) — force variety.
- Spread across cheap/simple (≥ 50 that a student could make with ≤ 6 ingredients) and a few "weekend" ones.

## Merging rules
- Merge duplicates across sources into ONE canonical entry; combine the best attributions in `source`.
- Fix loose tagging: `diets_ok` and `allergens` must use ONLY the exact enum tokens below, no parentheticals.
  Judge them yourself from the ingredients — the researchers were inconsistent. Rules of thumb:
  oats = gluten unless "certified GF oats" in ingredients; soy sauce = soy + gluten (tamari = soy only);
  honey ≠ vegan; whey = dairy; butter/ghee = dairy; most bread/pasta/tortilla(flour)/couscous/bulgur/seitan = gluten;
  corn tortilla, rice, potato, quinoa, buckwheat = GF; paleo excludes grains, legumes (incl. soy/peanut), dairy;
  keto ≤ ~20 g net carbs; low_carb ≤ ~100 g carbs per meal-day context — tag low_carb for genuinely low-carb meals only;
  mediterranean = olive-oil / fish / legume / whole-grain / veg pattern, moderate dairy, little red meat;
  pescatarian ⊇ vegetarian (any vegetarian meal is also pescatarian-OK and omnivore-OK; any vegan is OK for all four).
  ALWAYS list every diet a meal fits, not just the "intended" one (e.g. a vegan dal is `omnivore, vegetarian, pescatarian, vegan` and usually `mediterranean`).
- Portions must be athlete-sized (main meals ~80–150 g carbs on training days, 25–40 g protein). Fix if the source was dainty.
- Rewrite names in the house style: plain, component-first, lowercase joiners, no marketing adjectives.
  Good: "Chicken, jasmine rice & roasted broccoli with teriyaki". Bad: "Power-Packed Teriyaki Bowl".
- `why` is one honest line an athlete would nod at ("high-carb, low-fibre — the classic pre-long-ride breakfast").

## Enum tokens (EXACT)
diets: omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb
allergens: dairy, eggs, fish, gluten, peanuts, sesame, shellfish, soy, tree_nuts   (or `none`)
contexts: everyday, pre-session, recovery, rest-day, race-week, carb-load, travel
cuisine: one word or hyphenated, e.g. american, british, mediterranean, italian, spanish, mexican, japanese, korean,
chinese, indian, kenyan, ethiopian, nordic, middle-eastern, brazilian, colombian, thai, vietnamese, german, general

## Output format (STRICT — parsed by script). Write to the path in your prompt.
First line: `# <Meal type> — 100 selected`. Then exactly 100 blocks, numbered with the prefix in your prompt:

```
### <PREFIX>-001 · <Name>
- meal_type: <breakfast|lunch|dinner|snack>
- context: <comma-separated context tokens>
- cuisine: <one token>
- ingredients: <comma-separated with portions for ONE athlete serving; for batch dishes say "(makes 4)" at the end>
- diets_ok: <comma-separated diet tokens>
- allergens: <comma-separated allergen tokens or none>
- swaps: <1–3 swaps, "X→Y (effect)" style>
- approx_macros: ~<kcal> kcal · <C>g C · <P>g P · <F>g F
- prep: <"5 min" | "15 min" | "batch — 30 min, 4–5 servings" | "no-cook" | "overnight">
- batch: yes | no
- source: <attribution + URL(s); "commonly reported (TrainerRoad forum <url>)" is fine>
- why: <one line>
```

After the 100 blocks, add a short `## Coverage check` section where you count each quota above and state
the number you achieved (be honest; if you missed one, say which and by how much).
No other prose. Return only a 3-line summary as your final message.

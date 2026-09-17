# 01: A Meal shows a Dish photo or nothing

**What to build:** An athlete opening the Meals tab or a recipe sees a Meal's Dish photo, or no picture
slot at all. There is no Mosaic, no single Tile, no placeholder box and no icon. At switchover the
Meals that keep a picture are those whose picture is a Dish photo with an `ok` Verdict (170 on dev).
The salmon, quinoa, asparagus and spinach salad shows nothing. Spec:
`.scratch/meal-imagery-dish-or-nothing/spec.md`; ADR 0003; mp-145 as re-ruled 2026-09-15.

**Blocked by:** None (can start immediately).

**Status:** done (2026-09-16)

- [x] `meal_library` carries the current Dish photo as its own fields (address, credit, credit link).
      The pipeline's image columns are untouched.
- [x] A switchover migration fills those fields for every active Meal with `image_mode = 'dish'`
      and `image_verdict = 'ok'`. The credit is composed from the structured creator, provider and
      licence fields, falling back to the stored credit line, and the credit link comes from the
      source URL. It is idempotent and applied to dev. A read-only verify query shows the count
      equals the `dish` + `ok` count.
- [x] `search_meals` and the Vana `get_meal` return the new fields. The Vana meal contract gains
      them.
- [x] The app's Meal picture is one optional Dish photo read only from the new fields. A row that
      still carries `mosaic` or `tile` tiles, or a `weak` photo, maps to no picture.
- [x] Meals tab cards, the recipe screen, the meal sheet, the swap screen and the shopping list
      show the photo, or lay out with no picture slot. Lists mixing both stay aligned.
- [x] The plain placeholder widget is deleted. Meal surfaces never build a Mosaic, though the
      shared Mosaic design widget stays.
- [x] A Dish photo that fails to load collapses the same way as no photo, with no glyph.
- [x] The recipe screen shows one credit line only when a credit exists, and tapping it opens
      the credit link when there is one. Cards keep the credit as the screen-reader label only.
- [x] Seam 1 tests are rewritten and pass. Rows shaped like `search_meals` and `get_meal` go
      through the real mapping into the widgets. They cover dish, no photo (including leftover
      mosaic/tile/weak data), credit present and absent, and a failed load. The placeholder
      tests are inverted.
- [x] `/design-sync` is run for the `kyle_design` changes. Goldens that showed placeholders are
      regenerated.
- [x] Checked on the simulator: the salmon salad's recipe screen starts at the title, and a Meal
      with an `ok` photo still shows it.

## Comments

**2026-09-15 — implemented.** Everything but the simulator check is done and verified.

- `meal_library` gained `photo_url` / `photo_credit` / `photo_credit_url`
  (`20260916140000_meal_photo_dish_or_nothing.sql`). The pipeline's columns are untouched.
- The switchover ran on dev and verifies: **170** Meals with a photo = **170** `dish` + `ok`
  rows, every one credited and linked. 1,752 Meals now show nothing.
- `search_meals` returns the three new columns (`20260916141000`), confirmed against dev's live
  function signature. `vana-action`, `vana-chat` and `vana-day-notes` redeployed to dev — all
  three bundle `_shared/vana/meals.ts` through `actions.ts` / `tools.ts` / `plan.ts`.
- The app reads only the new fields. A row still carrying `mosaic` or `tile` tiles, or a `weak`
  photograph, maps to no picture — covered by tests rather than by trust.
- `MealPicturePlaceholder` and `meal_picture_mapping.dart` are deleted; `MealImageMosaic` stays
  in `kyle_design` unused by meal surfaces, as ADR 0003 intends.
- 621 meal-planning tests and 106 Deno tests green; six plan goldens regenerated. The one failing
  test in the full suite (`test/shared/ci_config_contract_test.dart`) is pre-existing: it reads
  only `codemagic.yaml` and `.github/workflows/tests-selfhosted.yml`, neither of which this work
  touches.

**Three defects `/code-review` caught, all fixed:**

1. `MealPhoto.identity` keyed on the address alone, so two Meals mirroring one Wikimedia file
   would both show it. Dev has 5 credit pages shared by two or more Meals against only 2 shared
   addresses, so this was live. Identity now keys on the credit page too, with regression tests.
2. The SQL credit composer wrote `CC BY SA 2.0` (99 dev rows) instead of `CC BY-SA 2.0`, and
   ignored `image_provider`. Corrected in `20260916140000` itself, so a fresh prod run is right
   first time, plus `20260916150000` to re-compose the rows dev had already stored.
3. Vana's saved-meal `MealRef` never received a photo, breaking "a saved Meal shows the library
   Meal's current photo" (story 11). `search_meals` had it right; only the `get_meal` card path
   was wrong.

**`/design-sync` has no input:** nothing under `lib/theme/` or `lib/shared/widgets/kyle_design/`
changed. The goldens that showed placeholders are regenerated.

**Open for Lee — where the photo widgets live.** The Standards review flags
`presentation/widgets/meal_photo_view.dart` as a design-bearing widget that CLAUDE.md says belongs
in `lib/shared/widgets/kyle_design/` under a spec name. It was left in the feature: it replaces
`MealPicturePlaceholder`, which lived there too, and the rule also wants a header citing a
ratified spec, which no Dish photo component has —
`docs/ssot/spec/design/components/` is the QA mirror this repo must not write to. Moving it would
mint an unratified library component, which `source-authority.md` calls drift. Worth a ruling
before ticket 03.

**Simulator check (iPhone 17 Pro, dev flavour, 2026-09-15).** Reached by deep link
(`com.milkman.mealvanaendurance:///food/meals/<id>`), which is quicker than the Meals tab and
worth knowing for later tickets:

- **AD-001 "Salmon, quinoa, asparagus & spinach salad"** — the ADR's own example. The screen has
  no `Image` node at all: the first element under the header is the title, then "See the original
  recipe". No picture, no credit line, no box.
- **B-046 "Avocado toast with chilli & lime"** — a mirrored storage photo. The hero renders, with
  exactly one credit line reading `Photo by Jami430 on Wikimedia Commons (CC BY-SA 4.0)`,
  character for character what `meal_library.photo_credit` holds. The hyphenated licence is the
  credit fix proving out on a device, and the line is also the image's accessibility label.
- The Meals tab's cards (Egg & Veggie Scramble, the tofu bowl, the oats plate, the peanut-butter
  toast) each start at the meal's name with no picture slot and no placeholder box.

One thing learned on the way: the dev athlete is **vegetarian**, so `search_meals` hard-filters
meat dishes out of the Meals tab — D-027 Bibimbap has a photo but can never appear for this
account. That is correct behaviour, not a bug, and it is why a photo-bearing card is easier to
find by deep link than by searching.

**Still owed:** nothing in this ticket. `docs/meal-images/README.md` still names `picturesForList`
and describes the ladder's fallback; left alone because ticket 02 owns that rewrite.

**2026-09-17 — Lee's rulings.**

- **Where the photo widgets live — resolved, and my reason was wrong.** I said a spec could not be
  written because `docs/ssot/` is the QA mirror. Lee ruled on 2026-09-11 that app-authored design
  specs *do* live there, marked "PROPOSED … awaiting Xuan" (precedents: `vana-sheet.md`,
  `vana-moment.md`, `meal-image-mosaic.md`); CLAUDE.md never said so, and now does. So the widgets
  moved into the library: spec `docs/ssot/spec/design/components/dish-photo.md` (PROPOSED v1,
  contracts DP-1..7) and `lib/shared/widgets/kyle_design/data/dish_photo.dart` (`DishPhotoThumb`,
  `DishPhotoHero`, `DishPhotoCreditLine`). The library takes plain fields, so it depends on no
  feature; `meal_photo_view.dart` keeps the `MealPhoto*` names as thin adapters, so no call site or
  test changed. Meal-planning presentation tests 296/296.
- Xuan's liquid-glass work is in the same library (`kyle_design/materials/glass.dart`,
  `theme/kyle_design/app_materials.dart`): `kyle_design` is the one component library, whatever
  the name suggests. No separate aggregation to reconcile.
- **Owed:** `/design-sync` — CLAUDE.md asks for it after `kyle_design/` changes, but no such skill
  is installed (it sits in `.claude/archive/`).

# Frozen — do not run

This pipeline is frozen (ADR 0003, `docs/adr/0003-a-meal-shows-a-dish-photo-or-nothing.md`,
accepted 2026-09-15). A Meal shows one Dish photo or nothing, and the photos Testers add are
the only ones that change. Nothing new is sourced from here.

**Running any pass would overwrite a Tester's photo**, which is why these scripts were moved out
of `scripts/` rather than left where a tab-complete reaches them.

Nothing it wrote was deleted, and the app no longer reads any of it. What is kept and why is in
ADR 0003 and in `docs/meal-images/README.md`.

What is still live here:

- `lib/mosaic-geometry.json` — the one description of the Mosaic grid. The shipped
  `MealImageMosaic` widget is still asserted against it by
  `test/shared/widgets/kyle_design/meal_image_mosaic_geometry_test.dart`, so this file is load
  bearing even while the pipeline is frozen.
- The pure libraries and their tests, which still pass from here:
  `node --test scripts/_archived/meal-images/lib/<name>.test.mjs`.

How pictures are found from here on is an open question for a later session. See
`docs/meal-images/README.md` for what the pipeline did and what it measured.

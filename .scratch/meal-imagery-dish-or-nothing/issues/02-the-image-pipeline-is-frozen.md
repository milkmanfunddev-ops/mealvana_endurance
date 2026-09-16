# 02: The image pipeline is frozen

**What to build:** Nobody can re-run the meal image pipeline by accident, and anyone reading about
it learns it is frozen and why. Nothing new is sourced from it, and everything it wrote stays in
the database so Mosaics can come back later. See ADR 0003.

**Blocked by:** None (can start immediately).

**Status:** done (2026-09-16)

- [x] The meal-image scripts move to an archive location. Nothing in the repo (package scripts,
      docs commands, CI) still points at their old path.
- [x] The meal-images docs open with a frozen notice that links ADR 0003 and says the data
      (Verdicts, the Tile bank, Tile lists, Image mode) is kept on purpose.
- [x] No database columns, tables or storage objects are changed.
- [x] Any tests that lived with the scripts are archived with them, or still pass from the new
      location. The app's test suite is unaffected.

## Comments

**2026-09-16 — built.** `scripts/meal-images/` moved to `scripts/_archived/meal-images/` as a git
rename. Two files resolved paths relative to their own location and were re-based a level:
`lib/db.mjs` (the dev service-role key) and `lib/report-doc.mjs` (`docs/meal-images/honesty.md`);
left alone they would have failed silently. `FROZEN.md` sits in the archived directory saying why
nothing there may run.

Both meal-images docs open with a frozen notice linking ADR 0003 and naming the data kept on
purpose. Every live pointer at the old path moved with it: the Flutter geometry test's two path
constants, `meal_photo.dart`'s comment, ADRs 0001-0003, `.env.example`, and the docs' own commands.

Two classes of reference were deliberately left: applied migrations
(`20260909120000`, `20260910140000`, `20260910200000`) and the historical `.scratch/meal-imagery/`
tickets. Both are records of what was run at the time, not things that run.

No schema, column or storage object was touched.

Verified: the 8 archived test files pass from the new location (115 assertions, same as before the
move); `meal_image_mosaic_geometry_test.dart` passes, including the pixel comparison against the
archived compositor; full suite 5033 pass / 8 skip / 3 fail, the 3 pre-existing and unrelated
(nutrition-plan CF-2, the CI-gate contract, and a TrainingPeaks live-credential test).

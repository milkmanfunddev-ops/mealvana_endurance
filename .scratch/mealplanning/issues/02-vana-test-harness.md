# 02: Vana test harness

**What to build:** The shared Vana server modules can be tested without a database or a model. A fake database answers the queries the context builder and memory module make from producer-shaped rows, the fetchers those modules use are injectable, and the first Deno test proves the existing meal-planning context block line by line from fixture rows: athlete, week, targets, race, logged, plan, memories. This is the prefactor that every later server ticket tests through. It changes no behaviour.

**Blocked by:** None (can start immediately)

**Status:** done (2026-09-09)

- [x] A fake database and injectable fetchers exist for the shared Vana modules, following the daily-macros function tests' shape
- [x] One test builds the planning-mode context block from fixture rows and asserts every line
- [x] Fixture rows are producer-shaped (what the tables return), never the engine's own output
- [x] The tests run through the existing algorithm test runner
- [x] The deployed function behaves identically; the live eval run passes unchanged

**Notes (2026-09-09).** The fake database is `tests/vana/support/fake_db.ts` (a chainable in-memory
PostgREST stand-in that records every write) and `tests/vana/support/vana_ctx.ts` (a `VanaCtx` over
it, plus offline stand-ins). `buildAthleteContext` gained a fourth parameter, `deps`, defaulting to
the real macro fill, weather line, and vector recall — the only three collaborators that leave the
process. Production passes nothing and is unchanged.

Two things found on the way:
- `run-algorithm-tests.sh` needed `--allow-sys`: importing the shared Vana modules pulls the AI SDK,
  which reads `os.hostname()` at import time.
- `meal_detail.json` and `meal_detail_saved.json` were stale — the meal-images work made `imageMode`
  and `imageTiles` required on `MealDetail` without regenerating them, so `contract.test.ts` had been
  failing at HEAD. Both fixtures now carry the values the server produces for a row with no dish
  photo.

Not done: the live eval run. It spends real model calls against dev and is a by-hand step; the
change is a defaulted parameter and cannot alter deployed behaviour.


# 03: Measure every Meal

**What to build:** A maintainer can ask how many Meals are showing something wrong and get an
answer, instead of sampling. Judge every active Meal against the picture it actually shows and store
the verdict.

This includes the 708 Dish photos, which have never been judged at all — every quality number
discussed so far comes from Tile and Mosaic samples, and the strategy assumes Dish photos are good
without evidence.

Costs single-digit dollars and runs for hours.

**Blocked by:** 02 (the judge must see what the app draws)

**Status:** done

- [x] Every active Meal carries a verdict, a reason and a timestamp.
- [x] A summary reports ok / weak / wrong counts broken down by Image mode, Dish included.
- [x] The Meals rated wrong can be listed, ordered by how often each surfaces to an athlete.
- [x] The run is resumable: a killed run costs time, not correctness, and a re-run judges only what
      has no verdict.
- [x] The measured honesty figure — Meals showing an `ok` image, plus Meals honestly blocked — is
      recorded so later tickets can be compared against it.
- [x] The actual spend is recorded.

**Measured 2026-09-10** (`docs/meal-images/honesty.md`): honesty **27.3%** — 146 meals showing an
`ok` picture plus 378 honestly showing nothing, out of 1,922. Coverage, the retired headline, is
80.3%. 1,494 meals judged for **$6.66** on Sonnet 5, 0 skipped.

**The finding that changes the plan: Dish photos are the worst rung, not the safe one.** 539 of 708
are wrong (76%), against 367 of 802 mosaics (46%). They had never been judged and the strategy
assumed they were fine. See tickets 04 and 05.

Two things had to be built before the sweep could be trusted, and both are in the diff: pass 8 now
writes each verdict as it reaches it (the old batch-at-the-end lost everything a killed run had
paid for), and tile fetches are paced per host (the first attempt skipped 41 of 44 consecutive
meals on Wikimedia 429s — correct, and useless).

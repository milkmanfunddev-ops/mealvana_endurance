# 03: Measure every Meal

**What to build:** A maintainer can ask how many Meals are showing something wrong and get an
answer, instead of sampling. Judge every active Meal against the picture it actually shows and store
the verdict.

This includes the 708 Dish photos, which have never been judged at all — every quality number
discussed so far comes from Tile and Mosaic samples, and the strategy assumes Dish photos are good
without evidence.

Costs single-digit dollars and runs for hours.

**Blocked by:** 02 (the judge must see what the app draws)

**Status:** ready-for-agent

- [ ] Every active Meal carries a verdict, a reason and a timestamp.
- [ ] A summary reports ok / weak / wrong counts broken down by Image mode, Dish included.
- [ ] The Meals rated wrong can be listed, ordered by how often each surfaces to an athlete.
- [ ] The run is resumable: a killed run costs time, not correctness, and a re-run judges only what
      has no verdict.
- [ ] The measured honesty figure — Meals showing an `ok` image, plus Meals honestly blocked — is
      recorded so later tickets can be compared against it.
- [ ] The actual spend is recorded.

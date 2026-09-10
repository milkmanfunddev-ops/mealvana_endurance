# 01: Extract the ladder decision as a testable rule set

**What to build:** The rules that decide what a Meal shows — Dish photo wins, a Transformed Meal
gets nothing, seasonings and liquids are never Tiles, one Tile only when the Meal genuinely is one
ingredient — currently live inline in the assignment pass, tangled with database reads and writes.
Move them into one pure decision so a rule change is an edit with a test beside it rather than
surgery on a script. No Meal changes what it shows.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] A pure function takes a Meal and the Tile bank and returns the resolved Image mode, its Tiles,
      the blocked flag and a reason. It performs no network, database or model calls.
- [ ] Running the assignment pass before and after the change produces byte-identical output for
      every Meal in the library.
- [ ] A Dish photo resolves to `dish` even when several Tiles are available.
- [ ] A Transformed Meal with Tiles available resolves to `none`, blocked, with a reason.
- [ ] A Meal whose only Tile candidate is a seasoning, oil or liquid resolves to `none`, not to that
      Tile.
- [ ] A one-ingredient Meal with one Tile resolves to `tile`.
- [ ] A Meal of several ingredients with one Tile resolves to `none`, blocked, and says why.
- [ ] A Separable Meal with two to four Tiles resolves to `mosaic`, capped at four, in
      principal-ingredient order.
- [ ] The same inputs produce the same output on a re-run.

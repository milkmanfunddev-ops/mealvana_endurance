# 05: Dish photos for Meals judged wrong

**What to build:** Ticket 03 produces a list of Meals whose current picture actively misrepresents
them. On sample that is roughly half of all Mosaics, and it includes most of the 197 Recipes still
wearing ingredient Tiles — the Meals most likely to have a real photograph somewhere.

A Tile may be a finished dish (decided 2026-09-10), so the tile bank is not being purged. Instead,
Meals whose Mosaic is judged wrong are fixed individually, using ticket 04's sourcing pass. A Dish
photo outranks a Mosaic in the ladder, so a successful sourcing simply replaces it.

**Blocked by:** 03 (the list of wrong Meals), 04 (the sourcing pass)

**Status:** ready-for-agent

- [ ] Every Meal whose verdict is `wrong` is either re-served with an `ok` Dish photo or falls back
      to blocked with a reason.
- [ ] No Meal ends the ticket still displaying an image rated `wrong`.
- [ ] Recipes wearing Tiles are included in the population, whatever their verdict.
- [ ] A replaced Mosaic's Tiles are cleared, so no Meal carries both.
- [ ] The honesty figure is re-reported, and the remaining blocked population is broken down by
      reason.

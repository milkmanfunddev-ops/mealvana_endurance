# 05: Review, before anything is sent

**What to build:** The shopper sees what Mealvana matched before it reaches their cart, and sees
plainly what it could not match.

After a matching run, each list line is shown beside the real Kroger product name and package size
it matched to. Lines with no match are listed separately and plainly — these are the items the
shopper will add themselves on Kroger's site, and they remain on the screen after the Hand-off so
that a shopper switching back still has them.

Price disappears from the delivery experience. Delivery-only Locations return no price for any
product, so a cost estimate there is a column of blanks; it is removed rather than shown as
unknowns, and a price from a different Location is never substituted.

Per-line correction — choose a different product, adjust quantity, exclude a line — stays
available, but is no longer the primary path.

**Blocked by:** 02, 04

**Status:** ready-for-agent

- [ ] After matching, every matched line shows the Kroger product name and package size
- [ ] Product names are shown exactly as Kroger returns them
- [ ] Unmatched lines are listed plainly and separately
- [ ] The unmatched list survives the Hand-off and is present on return
- [ ] No price or cost estimate appears in the delivery path
- [ ] No price is ever substituted from another Location
- [ ] A shopper can still change a single match, its quantity, or exclude a line
- [ ] Already-ticked lines are excluded from the run

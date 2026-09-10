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

**Status:** built (2026-09-10)

- [x] After matching, every matched line shows the Kroger product name and package size
- [x] Product names are shown exactly as Kroger returns them
- [x] Unmatched lines are listed plainly and separately
- [x] The unmatched list survives the Hand-off and is present on return
- [x] No price or cost estimate appears in the delivery path
- [x] No price is ever substituted from another Location
- [x] A shopper can still change a single match, its quantity, or exclude a line
- [x] Already-ticked lines are excluded from the run

Notes for whoever picks up 06 and 07:

- The draft now partitions itself three ways — `matched`, `unmatched`, `skipped` — and the screen
  renders one section per part. The third is not in the acceptance list above: once a line belongs
  to exactly one section, an excluded line has nowhere to live, and taking something out of the
  order would be a one-way door. Its heading is `kroger.skipped_heading`.
- `ready` changed meaning: it asks `matched.every(...)` where it asked `included.every(...)`, so a
  draft with unmatched lines can be sent. This follows from the ticket — the shopper adds those on
  Kroger's site — and it is also what stops `export` dereferencing `l.product!` on a line that has
  none.
- The export payload still carries each line's `price`. It is never shown; the server compares it
  against Kroger's current price to decide whether a product changed under the shopper. Removing it
  would weaken that check for pickup, where prices exist.
- Four content keys were deleted with their copy: `kroger.price`, `kroger.estimate`,
  `kroger.unknown_prices`, `kroger.estimate_note`, along with `kroger.unmatched` (the section
  heading says what that per-line label used to). `kroger.price_note` replaces the estimate note
  and is why prices are absent, for story 31.
- The price test deliberately runs at 35242, whose fixture catalogue has a price. At the Spoke it
  could not fail. Mutation-checked: re-adding a price widget turns it red.

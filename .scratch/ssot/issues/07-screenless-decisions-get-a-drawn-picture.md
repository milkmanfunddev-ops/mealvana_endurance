# 07: Screenless decisions get a drawn picture

**Status:** done
**Blocked by:** 01.
**Next:** `/mattpocock-skills:implement 08`

**What to build:** A card whose screen is "none" no longer says "No picture yet". The skill that
proposes it draws a small plain diagram of the mechanism in inline SVG, in the page's own tokens:
boxes, arrows, one worked example with real numbers. The page renders it on the left like a
screenshot. Lee's example is the paywall: what a new account sees on day one, day seven and day
eight. Story 15 and the Pictures section.

- [x] The format has an `svg` part; parse and serialise round-trip it byte-identical
- [x] The page renders the SVG in the picture box, in both themes, and no longer flags the card as missing a picture
- [x] The proposing step in the epilogue and in backfill draws one for every card with `screen: none`
- [x] The paywall card (mp-266 and its trial clauses) shows day one, day seven, day eight as a drawn timeline
- [x] No stock illustration, no raster, no colour outside the page's tokens

**Done 2026-09-14.** The `svg` part is a `- svg: <repo path>` meta line; the SVG lives in
`docs/ssot/decisions/images/<feature>/<id>.svg` and `prepare` inlines it into the page document
(an inline body in the markdown would bury 37 drawings in the record). "Trial clauses" was read
as mp-266's own three clauses; mp-267 (a question) and mp-270 name the Paywall screen and are
captured under ticket 08. Drawing goes through `sync.mjs draw` (`_page/diagram.mjs`) from a JSON
spec; specs from this run are in `.scratch/ssot/diagrams/`. Backfilled all 36 existing screenless
cards plus mp-266 and reseeded the page.

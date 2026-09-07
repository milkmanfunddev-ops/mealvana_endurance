# RULING #3 — the compact zone renders the top-fade dissolve (RESOLVED)

**Ruled: Xuan, 2026-09-06 (evening — Bevel reference: "this is how bevel healthy app looks
like", IMG_8929).**
**Status: RESOLVED — applied same day to `spec/design/components/date-header.md`,
`spec/design/tokens.md` §Materials (`top-fade`), and the app (feature/home-shell-v1).**

## The ruling

The compact date-header zone renders a **progressive blackberry dissolve**: content scrolling
beneath blurs and dims gradually toward the top — no band, no hard edge. The two circular
buttons stay floating `glass` chrome on top; the centred date renders in the dissolve.

This is the treatment the archived export ALWAYS drew for this row (blur-14 masked to a fade
over a blackberry gradient) and the treatment Bevel's home uses. The ruling chain it closes:

1. **#1** (ruling-desk block): superseded the export's fade with the `glass` band.
2. **#2** (first Rad build): removed the band — a full-width backdrop region read as a slab.
3. **#3** (this ruling): reinstates the export's fade as the blend. The fade was never the
   defect; the band was.

## Values (export-exact, now §Materials `top-fade`)

Zone height 104 px · blur 14 at the top easing to 0 down the zone (app: stacked backdrop
strips 14/8/4/1.5 — Flutter has no gradient-masked backdrop filter; the dim gradient hides the
seams) · dim gradient `blackberry` 85% → 55% at half → transparent.

## Conformance impact

`date_header_compact` golden re-blessed from the dissolve rendering (spec change cited). No
gesture-manifest change (dh1–dh6 unaffected).

# The docked action panel has no material and no library home

`type:` ruling-request
`bundle:` (brick — the CANDIDATE carry-over on `macro-dashboard`)

## Why this matters

The docked LEG ORDER panel is the app's first bottom-docked action surface, it is unspecified,
and it shipped wrong (1.26.0). The next one — Vana, the deferred companion pill's utility slot,
any multi-select flow — will be the second, with the same nothing to copy from.

## The gap, precisely

There is no spec for this surface, and the near-miss makes it easy to believe there is:

- `spec/design/components/brick-leg-builder.md` (PROPOSED) governs the **`create-activity-plan`**
  surface — sport chips, leg rows, drag reorder. Not this panel.
- `spec/design/surfaces/macro-dashboard.md` (RATIFIED v2) does not mention the brick flow at all.
  Grep for "brick" returns nothing.
- The panel's only authority is Notion 3a7e3fdb, which specifies **behaviour** (step 2 → step 3,
  commit directly, no confirm modal) and names no material.

The app source says so itself, in the screen's header comment: *"Nothing brick-shaped lives in
kyle_design/ yet, by design: promotion into the library follows ratification
(source-authority.md §3), not this port."* That is the correct policy, and it is also why the
panel was hand-rolled inside a 1365-line screen file with a fill somebody chose by eye.

The library gap is real but downstream of the spec gap: `lib/shared/widgets/kyle_design/materials/`
holds exactly `GlassSurface`, `GlassSheetSurface`, `GlassLens` and `GlassTopFade`, and all three
consumers are navigation chrome (tab bar, date header, calendar sheet). There is no component for
*docked chrome at the bottom edge* — so even a developer reaching for the library finds
`GlassSurface` documented as "capsules and circles" and the boundary clause saying cards are not
glass, concludes their rounded rect is neither, and writes a `Container`.

## The questions

| Q | Question |
|---|---|
| Q-DAP1 | **What is the docked action panel made of?** (a) opaque ground + hairline, i.e. the ratified card treatment applied to chrome — what the repair currently ships; (b) the `glass` recipe, which would extend "floating chrome" past capsules and circles; (c) a new named recipe. Note the ruling-#2 precedent: a full-width region-bound backdrop filter over flat ground reads as a painted slab, and this panel is inset 18 px with a 16 px radius — closer to a floating pill than to the band that ruling rejected. |
| Q-DAP2 | **Does the bottom edge get a `top-fade` counterpart** — content dissolving into the docked panel the way it dissolves into the pinned block — or does content simply pass behind an opaque edge? |
| Q-DAP3 | **Does the panel separate from the cards it covers by elevation or by hairline?** `tokens.md` says hairlines do the work everywhere glass is not named; the panel's orange 35 % rim is already that hairline, so this may need no ruling beyond confirming it. |
| Q-DAP4 | **Is this component or surface?** If the panel is one instance of a general "docked action bar", it earns a `components/docked-action-bar.md` and a `kyle_design/materials/` home; if it is brick-specific, it belongs in a brick component spec alongside the leg chips. |

## Conformance gap (worth ruling on regardless)

**No golden captures leg-picking.** `macro_dashboard_goldens_test.dart` contains no brick or
picking state at all — the mode is transient, so the device sweep photographed resting screens
and the goldens follow the same shape. Both widget tests that exercise the LEG ORDER panel set a
**1600 px viewport** with the comment *"in the default 800×600 the docked LEG ORDER panel covers
the second card, so the tap never reaches it"* — the trapped-content defect was observed, worked
around, and never filed. Whatever Q-DAP1 rules, the picking mode needs a golden at phone height.

## What this gates

- The final treatment of the two panels repaired on `fix/brick-docked-panel-opacity` (the repair
  is legibility-only and invents no material — see
  [`2026-09-09-overlay-material-boundary.md`](2026-09-09-overlay-material-boundary.md)).
- Promotion of anything brick-shaped into `kyle_design/` (source-authority.md §3 holds it until
  ratification — correctly).
- The brick bundle's design session generally: the panel is one of several CANDIDATE carry-overs
  from Notion 3a7e3fdb that have never been through a design ratification.

## Suggested spec home

A new `spec/design/components/docked-action-bar.md` if Q-DAP4 rules "component"; otherwise the
brick component spec when the brick bundle is ratified, with the material clause landing in
`tokens.md` §Materials alongside the sibling's boundary.

> **RESOLVED 2026-09-06 → spec/design/tokens.md §Materials post-ratification addition (scrim: blackberry 60% — export governs; lensing boundary lifted)**

type: ruling-request
bundle: home-shell@v1 (proposed — see 2026-09-06-tab-bar-v2-glass-scroll-collapse.md)

## Why this matters
`tokens.md` has no translucent-blur material — the ratified elevation story is "hairlines do
the work". The home-shell redesign introduces liquid glass on floating chrome; without a token
ruling, every glass surface ships as ad-hoc alpha values and the goldens pin accidents.

## Companion artifact & scope
Same HTML as the tab-bar intake. **Only the tab bar, date header, and calendar sheet are in
scope; ignore every AI element in the file this version.**

## The proposed material (numbers are the contract — measured from the approved round-2/3
artboards, chosen to be achievable in Flutter on both platforms)

**`glass` (floating chrome — pills, circular buttons, compact header):**
- backdrop: blur 4 px · saturate 1.8 · brightness 1.12 (content behind stays recognizable,
  gets more vivid and slightly BRIGHTER — never darker)
- fill: vertical gradient, cream 7 % → cream 2 % alpha
- rim, light source top: 1 px inner specular highlight, cream 40 % across the top arc fading
  to cream 8 % at the sides; bottom inner shadow inset 0 −1 px 1 px black 25 %
- outer lift under floating pills only: 0 8 px 24 px black 25 %
- shapes: capsules and circles; highlights are cream-based — never #fff at full opacity

**`glass-sheet` (summoned surfaces — the calendar sheet):**
- the same backdrop chain; top radius 24; specular line under the grabber; fill cream 4 % → 1 %
- **plus a scrim: black ~35 % between the page and the sheet.** Load-bearing, not cosmetic:
  without it, page chrome bleeds through at full strength and impersonates the sheet's own
  glyph vocabulary (found in review: the teal clock toggle behind Aug 1 read as a
  completed-workout ring). Every future summoned glass surface inherits the scrim.

## Boundaries
- Edge refraction / displacement "lensing" is **non-contractual polish** — excluded from the
  spec and the goldens (Flutter can't ship it reasonably; the artboards don't show it).
- Timeline/content cards NEVER take glass — solid fill + hairline stays their ratified
  treatment. Glass is floating chrome + summoned sheets only.
- Dark-first: values above are for the blackberry ground; a light-surface variant is not
  proposed (defer until a light surface needs one).
- Flutter implementation is `BackdropFilter` + painted rim; the app's own goldens are the
  conformance reference (the phase-card-parity precedent: the spec's numbers govern, the HTML
  illustrates).

## Gates
Everything in home-shell@v1 — tab bar, date header, calendar sheet all depend on this ruling.
App: material constants in `lib/theme/kyle_design/` (one registry — no second token class),
then `/design-sync`.

## Suggested spec home
`spec/design/tokens.md` — new material section (`glass`, `glass-sheet`), post-ratification
addition or minor rev at the ratifier's discretion.

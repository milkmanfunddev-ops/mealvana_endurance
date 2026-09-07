# Design SSOT — Tokens

**Status: RATIFIED v1 (Xuan, 2026-08-14).**
**Scope:** the named palette and its **meaning contracts** — global to every component and surface
in `spec/design/`. Single source: the prototype's CSS custom properties. Code and specs reference
tokens, never raw values; a value lives in exactly one place — this table.
*(This table is the one deliberate exception to the screenshot test: raw values appear here —
and only here — because goldens render "at token-resolved colors" and code must resolve the same
registry. Everywhere else, values are screenshot-held.)*

| Token | Value | Meaning contract |
|---|---|---|
| `--me-blackberry` | rgb(56, 22, 51) | Ground; card fills derive from it |
| `--me-cream` | rgb(248, 246, 235) | Primary text |
| `--me-electrolyte` | rgb(28, 249, 207) | **Burn / activity side, and the per-workout fuel plan** (widened Q-D3 2026-08-14 from verified-only; widened again **Q-D8 2026-08-26**): burn-side figures, workout accents, verified chips, the done-swipe fill, **and** the headline figures / delivered markers / hydration-check accent of a **per-workout fueling card** (pre / during / after). Still may **not** signify **daily** intake or planning — that stays `orange` (macro-dashboard Q-D3). The boundary is per-workout-fuel (teal) vs daily-energy (orange) |
| `--me-orange` | rgb(247, 139, 20) | **Daily** energy & intake accent; planned-workout accent. (Per-workout fuel figures are `electrolyte`, Q-D8) |
| `--me-dragonfruit` | rgb(220, 37, 151) | **Destructive, or out-of-range caution** (widened **Q-D9 2026-08-26**): destructive actions, **and** an out-of-range / overshoot warning marker (over-drinking fluid above the ceiling; a macro out of band). May not signify anything else |
| `--me-yolk` | rgb(255, 198, 41) | **RESERVED — no meaning contract yet** (RULED Xuan, 2026-08-25, Q-SA2 in `source-authority.md`, post-ratification addition). Kyle's secondary `#FFC629`; kept in the registry so code stops inventing yellows. Assigning what it may signify is a sweep-time ruling; until then a component using it fails conformance |

**The contract is the meaning column.** A component using `electrolyte` for a **daily**-intake
element, or `dragonfruit` for a non-destructive **and** non-caution one, fails conformance even if
it "looks right."

**Q-D8 — RULED (Xuan, 2026-08-26): option (a) — widen `electrolyte` to the per-workout fuel side.**
The pre-workout BEFORE card's headline figures, delivered markers and hydration-check accent may
render in `electrolyte`; a per-workout fueling plan (pre / during / after) is inside the token's
domain. The daily-dashboard boundary is unchanged — daily intake stays `orange` (Q-D3). Parallel to
Q-D3's earlier widening of this same token from verified-only. Unblocks the four PROPOSED pre-workout
design specs and their teal goldens.

**Q-D9 — RULED (Xuan, 2026-08-26): option (a) — widen `dragonfruit` to out-of-range caution.**
The fuel-stat's overshoot marker (over-drinking above the fluid ceiling; a macro out of band) may
render in `dragonfruit`. The token now means destructive **or** out-of-range caution. Unblocks the
`fuel-stat` overshoot golden.

## Materials — RULED (Xuan, 2026-09-06, post-ratification addition; no version bump)

**Ruling source:** [`../../intake/2026-09-06-glass-material-token-ruling.md`](../../intake/2026-09-06-glass-material-token-ruling.md)
(RESOLVED — ruling-desk block of 2026-09-06). First translucent-blur material in the registry;
the "hairlines do the work" elevation story is unchanged everywhere glass is not named. The
numbers below are **the contract** (DOM-verified against the home-shell design export
2026-09-06); the export illustrates — phase-card-parity precedent. Conformance reference is the
app's own goldens (Flutter: `BackdropFilter` + painted rim), never a pixel match to any HTML or
to iOS.

**`glass`** — floating chrome: pills and circular buttons. *(The compact header row carries NO
material of its own — RULED Xuan 2026-09-06 **#2**, on-device review, reversing the same-day
row-takes-glass ruling; the export's blur-14 fade stays superseded and no band replaces it. Only
the row's floating buttons take this recipe.)*:
- backdrop: blur 4 px · saturate 1.8 · brightness 1.12 (content behind stays recognizable, gets
  more vivid and slightly BRIGHTER — never darker)
- fill: vertical gradient, `cream` 7 % → 2 % alpha
- rim, light source top: 1 px inner specular highlight, `cream` 40 % across the top arc fading to
  `cream` 8 % at the sides; bottom inner shadow inset 0 −1 px 1 px black 25 %
- outer lift under floating pills only: 0 8 px 24 px black 25 %
- shapes: capsules and circles; highlights are `cream`-based — never `#fff` at full opacity

**`glass-sheet`** — summoned surfaces (the calendar sheet):
- the same backdrop chain; top radius 24; specular line under the grabber; fill `cream` 4 % → 1 %
- **scrim: `blackberry` 60 % — rgba(56, 22, 51, 0.6) — between the page and the sheet.**
  RULED 2026-09-06: **the export governs**; the intake's proposed black ~35 % is corrected by
  this ruling. Load-bearing, not cosmetic: without it, page chrome bleeds through and
  impersonates the sheet's own glyph vocabulary. Every future summoned glass surface inherits
  the scrim.

**Lensing — boundary LIFTED (RULED Xuan, 2026-09-06; reverses the filed intake's exclusion):**
edge refraction/displacement may be **contractual on any glass chrome** where the invoking
component spec names it (first: the tab bar's switch transition,
[`components/tab-bar.md`](components/tab-bar.md)). Defined by **observable properties only**
(distortion magnitude and falloff, easing/timing) — never "matches iOS" — and **per-surface
goldens are required** for every surface that lenses. A glass surface whose spec does not name
lensing does not lens.

**Boundaries (unchanged by this addition):** timeline/content cards NEVER take glass — solid
fill + hairline stays their ratified treatment; glass is floating chrome + summoned sheets only.
Dark-first: the values above are for the `blackberry` ground; a light-surface variant is
deferred until a light surface needs one.

**Q-D2 — RULED (Xuan, 2026-08-14): the current `dragonfruit` delete treatment is the contract
as-is.** Weight accepted at reference-rendering saturation and size; open to future iteration but
not a defect. (Register finding W-9 closes with this.) *v2 note (2026-08-17, Q-D6): delete is
deferred and skip replaces it — the workout card carries **no** `dragonfruit` element in v2; the
Q-D2 treatment returns with the delete bundle.*

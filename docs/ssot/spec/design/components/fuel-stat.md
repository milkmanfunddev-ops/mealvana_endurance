# Design SSOT — Component: Fuel Stat (figure + band)

**Status: RATIFIED v1 (Xuan, 2026-08-26).** Extracted 2026-08-26 from the reference rendering; reviewed on the spec-review page (7/7 checked; M-4 ruled no-signifier and folded pre-ratification). Token questions Q-D8/Q-D9 RULED (Xuan 2026-08-26, option a) — see `tokens.md`.
**Component contract** — one summary quantity (carbs · fluids · sodium) with its optional band.
Three instances compose the BEFORE summary row; composition is
[`../surfaces/pre-workout-before-card.md`](../surfaces/pre-workout-before-card.md).
**Tokens:** [`../tokens.md`](../tokens.md). **Numbers authority:** `spec/fueling/pre-workout-carbs.md`
v2 (`carbsG`, `carbsLowG/HighG`, `targetBasis`), `pre-workout-hydration.md` v6 (`fluidMl`,
`fluidLowMl/HighMl`, `targetBasis`, `regime`), `pre-workout-sodium.md` v3 (no target). This file
contracts presentation only.
**Reference rendering:** [`../renderings/pre-workout@v2.html`](../renderings/pre-workout@v2.html)
(ratified Xuan 2026-08-26).

## State model

```
quantity  ∈ { CARBS, FLUIDS, SODIUM }
mode      ∈ { TARGETED, NO_TARGET, NONE }     # from the engine, per quantity — see table
basis     ∈ { GUIDELINE, ESTIMATE }           # engine data (targetBasis) — NOT rendered, M-4
delivered : number                            # Σ over feeding rows (surface B-1)
```

| Quantity × mode | Figure | Band | Caption | When |
|---|---|---|---|---|
| `CARBS · TARGETED` | delivered g | `[carbsLowG, carbsHighG]` with **two markers** (M-1) | none (M-4) | normal |
| `CARBS · TARGETED`, band `[0,0]` | `0g` | **suppressed** — no rail, no ends, no markers | none | `t = 0` (carbs † rule) |
| `CARBS · NONE` | no figure — line `No carbs this session` | none | none | `isFasted` (`tiers: []`, `targetBasis: none`) |
| `FLUIDS · TARGETED` | delivered oz | `[fluidLowMl, fluidHighMl]` in oz, two markers | `guideline` (≥ 2 h) / `our estimate` (< 2 h) | normal |
| `FLUIDS · NO_TARGET` | no figure — line `No fluid target for this session` | none | none | gate path (`fluidMl: null`, `regime: gated`) |
| `SODIUM` | delivered mg, **always** | **never** — no rail, no marker, no state | none | sodium v3: reported, not targeted |

**F-1 · Three "no number" states never look alike.** In plain terms: *"we recommend none"* (a real
`0g` — no time to eat), *"we're not stating a target"* (the gate — `No fluid target for this
session`), and *"there is nothing to recommend"* (fasted — `No carbs this session`) are three
different messages, and the athlete must be able to tell them apart at a glance. A consumer that
renders any two of these the same fails conformance (brief §3) — a gate shown as "0 oz" reads as
*drink nothing*, which is the coach-complaint class the fluid-gate ruling request documents.

**F-2 · Sodium has no band, ever.** No marker, no in/out-of-range state, no colour change — there
is no target for a bar to measure against.

## Markers and signalling

**M-1 · Two markers, two quantities.** The band carries a **delivered** marker (diamond) that
moves as food rows change, and a **suggested** marker (triangle beneath the rail) at the engine
target that moves only when the engine target moves (e.g. the hydration check). A single marker
would carry the wrong one — the one that does not change when you add a bagel.

**M-2 · Signalling is one-way for fluid, two-way for carbs.**

| Quantity | Delivered below floor | Delivered above ceiling |
|---|---|---|
| CARBS | signalled (delivered marker takes the *out-of-band* colour) | signalled |
| FLUIDS | **not signalled** — nothing changes; a short fill is in spec (`fluidLowMl = 0` below 2 h) | signalled |

No progress ring, no `0 / N`, no completion state, no streak, no checkmark on any stat (hydration
*What `fluidMl` means* §4; notes §5.12).

**M-3 · The *suggested* marker may sit exactly on a band end** (at the edges of the cited window
the engine target coincides with the floor or ceiling) and this is **not** an out-of-band state —
no alarm colour. Not to be confused with the **delivered** marker leaving the band, which is
exactly what M-2 alarms (clarified 2026-08-26 after review comment).

**M-4 · No basis signifier renders — RULED (Xuan, 2026-08-26, via artifact comment).** The UI does
**not** signify `evidenced_band` vs `design_choice`: every band renders identically (solid rail,
two markers, end labels) whatever `targetBasis` is. The distinction stays an **engine output**
(`targetBasis`, still emitted and still traced) and appears in prose only in the fine print
(notes §7 ¶2 — itself deferred this iteration, S-G4). History: a dashed-rail form was tried and
dropped, then a "guideline" / "our estimate" caption was tried and **retired the same day** —
"the word 'guideline' doesn't carry much to the UI." Supersedes the caption resolution of register
finding F-04; if a future surface needs the distinction visible, that is a new ruling.

**M-5 · Rounding is presentational.** Fluid displays in whole US fl oz (R-01, Xuan 2026-08-26 —
target rounds to the ounce, band ends floor/ceil to the ounce); carbs to the gram on this surface.
The engine values are exact; no visible jump may be introduced by rounding.

## Traceability

Every figure and band end maps to a named engine field above; the delivered figure is the surface's
sum (B-1). This component invents no arithmetic and no threshold.

## Conformance (design vectors)

- **Golden (L1):** carbs TARGETED (in band, below, above), carbs `[0,0]` suppressed, carbs NONE,
  fluids TARGETED (in band, above — and *below*, asserting no signal), fluids NO_TARGET, sodium —
  ten images from the 63 kg mock.
- **Widget (L2):** M-2 — drive delivered fluid to 0 and to 2× ceiling; assert the marker colour
  changes only in the second case. Drive carbs both ways; assert both signal. M-1 — change a food
  row; assert the delivered marker moves and the suggested marker does not. F-1 — render the three
  no-number states; assert three distinct trees. F-2 — no band node under SODIUM in any state.
- **A golden may only be regenerated after this spec changes.**

## Token rulings (were open)

- **Q-D8 — RULED (Xuan, 2026-08-26, option a):** `electrolyte` is widened to the **per-workout fuel
  side**; the carbs/fluids delivered figures may render teal. `tokens.md`.
- **Q-D9 — RULED (Xuan, 2026-08-26, option a):** `dragonfruit` is widened to **out-of-range
  caution**; the overshoot marker may render magenta. `tokens.md`.

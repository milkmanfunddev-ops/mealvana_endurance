# SSOT — During-Workout Hydration (single-sport)

**Status: RATIFIED (Xuan, 2026-07-26), Algorithm v2.1.**
**Source:** Notion "💧 During-Workout Hydration · Transparency Copy V1" (Algorithm v2.1, 2026-04-08)
— [page](https://app.notion.com/p/33ce3fdb754c81b9be8bf88932468bfb).
**Code:** `OfflineMacroCalculator.calculateDuringWorkoutHydration` + `calculateActualSweatRate`
(`app/lib/features/nutrition_plan/data/offline_macro_calculator.dart:922, :879`), mirrors
`generate-macros-v4`. **Code matches v2.1 constants** (verified: sweat tiers, temp baseline, replacement %).
**Scope of this slice:** single-sport during-hydration. Multi-segment tri (T1/T2 transitions +
redistribution, `calculateBrickHydration`) is a SEPARATE follow-up slice.

## Effective sweat rate (5-step chain)
```
base         = knownSweatRateMlPerHour/1000  OR  sweatTier[category]     # L/hr
tempMult     = clamp(1 + (tempC − 22)·0.04, 0.50, 1.80)
humidityMult = clamp(1 + max(0, humid% − 50)·0.002, 1.00, 1.10)
indoorMult   = 1.30 if indoor else 1.00
effective    = round3dp( clamp(base·tempMult·humidityMult·indoorMult, 0.30, 3.00) )   # L/hr
```

## Target, floor, ceiling
```
replacementPct = 30% (<60min) · 50% (60–90] · 60% (90–150] · 70% (150–240) · 80% (240+)
gate           = duration < 60 AND tempC < 30  → rate = round(effMlHr · pct), floor = 0
standard:
  ceiling = round( min(GI_limit, effMlHr) )          # GI: 800 run / 1200 bike ; + 100%-sweat cap
  floor   = max(0, (totalLoss − 0.02·BW·1000) / durH)   # keep deficit ≤ 2% BW
  rate    = min( max( round(effMlHr·pct), floor ), ceiling )
  flags:  ceiling<floor → "exceed 2% BW even at max"; realized deficit >3% → dehydration flag
swimming → all hydration outputs 0 (no drinking)
```

## Constants — research vs design choice (confidence per the SSOT)
| Constant | Value | Confidence / source |
|---|---|---|
| sweat tiers | light 0.90 · medium 1.28 · heavy 1.66 L/hr | **High** — Barnes & Baker 2019, n=1,303 (25/50/75th pct) |
| temp coefficient | +0.04 L/hr per °C over 22 °C, clamp 0.50–1.80× | Medium — Jenkins 2023 |
| humidity mult | +0.002 per %RH over 50, cap 1.10× | **Design choice** — Jenkins 2023 found humidity NOT significant; Mealvana conservative estimate |
| indoor mult | 1.30× | **Low / design choice** — not quantified in research |
| replacement % | 30/50/60/70/80 by duration | Med (60–240) · **High** (240+) · **Low design-choice** (30% <60min soft target) |
| 2% BW floor | 0.02·BW | **High** — Sawka 2007 ACSM |
| GI ceiling | 800 run · 1200 bike ml/hr | Peters 1999 / Coyle 1992 |
| 100%-sweat ceiling | effMlHr | **High** — hyponatremia guard (Hew-Butler 2015) |

## Worked examples (from the SSOT) — NOTE a rounding nuance
The doc's examples hand-round the sweat rate to **2 dp** (e.g. 1.29), but the code uses the
spec's own **round3dp** (1.293). So precise-algorithm outputs differ from the doc's printed
numbers by ~2–3 ml. **Vectors use the precise algorithm** (3dp), not the doc's 2dp hand-calc.
- Ex1 (90-min run, 65 kg, medium, 22 °C, 55%): doc prints rate 645 / floor 423 / ceiling 800;
  **precise: rate 647 / floor 426 / ceiling 800** (eff 1.293).
- Ex2 (45-min gate, 70 kg, medium, 22 °C): rate 384 / floor 0 / ceiling 800 (matches; no fractional carry).

## Ratification (resolved — Xuan, 2026-07-26)
1. **`round3dp` on the sweat rate is canonical** (the code + vectors). The doc's 2dp worked
   examples are illustrative only.
2. **Accepted as ratified design choices:** humidity 1.10×, indoor 1.30×, 30% <60-min soft target.

## Conformance
Vectors: `qa/vectors/fueling/during-workout-hydration.json`. Runner asserts
`calculateDuringWorkoutHydration` output (rate/floor/ceiling/replacementPct/effectiveSweatRate).

---

## Conditions provenance — RULED (Xuan, 2026-09-21, post-ratification addition)

`tempC` and `humid%` enter the ratified sweat-rate chain as known inputs. They are not always
known. When the weather fetch fails the app seeds **68 °F (20.0 °C) / 60 %** and generates
anyway — values that existed only in app code until this ruling. Live consequence (Tampa,
2026-09): against a real 80 °F / 95 % day the silent default understates effective sweat rate
by ~38 %, and sodium by the same factor (it is proportional to the post-clamp fluid rate).

**CP-1 — the fallback is named, not invented.** When conditions cannot be fetched and the
athlete has not supplied them, the engine uses `tempC = 20.0`, `humid% = 60`. These are now
ruled spec values; changing them is a ruling, not a code edit.

**CP-2 — every plan carries `conditionsSource`**, one of:
| value | meaning |
|---|---|
| `measured` | fetched for the session's place and time |
| `assumed` | CP-1 fallback used — the fetch failed or was unavailable |
| `manual` | the athlete supplied or overrode the values |
A plan whose conditions were assumed MUST NOT be presentable as one built on measured
conditions. The flag travels with the plan, not with the transient fetch attempt.

**CP-3 — the display must surface it, persistently.** The existing failure copy
("Couldn't fetch weather. Enter manually or try again") is transient and the plan outlives it;
surfacing therefore uses the RATIFIED source-chip pattern
(`spec/design/surfaces/integrations-data-display.md` D-2, inherited by D-2b for body
composition with named parameters). Parameters for this application: sources
`Measured · Assumed · Manual`; the chip sits with the conditions value it describes, per D-2's
own rule that every value displays with its source chip. **No new pattern ratification is
required** — this is pattern application, the class D-2b established. If a surface shows a
fueling plan WITHOUT showing its conditions value, that surface has no anchor for the chip and
its treatment is a design question for the ruling desk — flagged, not decided here.

**CP-4 — the arithmetic is unchanged.** Provenance does not alter the sweat-rate chain, the
clamps, or sodium's proportionality. A conformance run must show identical numbers to the
pre-ruling contract for identical inputs; only the flag is new.

**Generation is never blocked** on a failed fetch (a third-party outage must not prevent
planning; offline planning is a real use). Authority:
`intake/2026-09-09-environment-fallback-when-weather-fetch-fails.md` (RESOLVED 2026-09-21,
option 1).

**CP-5 — provenance is SOURCE-driven, never failure-driven** (added 2026-09-21 after the
Q-CA2 landing exposed a second path): more than one code path seeds the CP-1 constants —
the failed fetch, and the per-activity form reset entering the create flow with no forecast
loaded. `conditionsSource` reports WHERE THE VALUE CAME FROM, not whether a network call
failed; an implementation keyed on the fetch outcome marks the first path and silently
misses the second, reproducing the exact defect CP-1..CP-4 exist to prevent.

**CP-6 — the per-activity reset restores the AUTO SOURCE, not a flat constant** (ruled as a
consequence of CP-2 + the Q-CA2 per-activity ruling; revisable by Xuan): on entering the
create flow for a new activity, temperature and humidity return to the loaded forecast when
one exists, to the CP-1 placeholders when none does, and indoor cycling keeps its ratified
45 % humidity. A reset that always seeded 20.0/60 would discard a loaded forecast and mark
every plan `assumed`, destroying the measured-vs-assumed distinction CP-2 must report.

# SSOT — Daily Macros: Multi-Day Context (Recovery, Pre-Load, Weekly, Phase)

**Status: RECORDED — awaiting ratification** (2026-07-28). Source: Notion
`daily_macro_calc_iteration2_spec` (Formulas 7–10). **Engine:** B. **Conformance target:**
`calculate-daily-macros/formulas/multi-day.ts` (name match only — not yet diffed).

## The rule
> Today's target is not only about today. Yesterday's hard session leaves a repayable debt,
> tomorrow's hard session needs loading for today, the week's overall load nudges the whole
> baseline, and the training phase scales everything.

These four steps run **in this order** — additive, then upward-only override, then additive, then
multiplicative — and the order is load-bearing.

---

## Formula 7 — `recoveryDebt(yesterday_tss, hours_since, weight_kg)`

Only fires for genuinely hard days, and decays linearly from 18 h to 36 h post-session.

```
if yesterday_tss is null OR yesterday_tss < 150:
  return { carb_add: 0, prot_add: 0 }

factor   = clamp(1.0 − (hours_since − 18) / 18, 0, 1)
carb_add = 1.25 × weight_kg × factor
prot_add = 0.10 × weight_kg × factor
```

Key values: `factor = 1.0` at ≤ 18 h (including 0 h — just finished), `0.5` at 27 h, `0.0` at
≥ 36 h. The TSS gate is `≥ 150`; the debt magnitude does **not** scale with TSS above the gate —
TSS 150 and TSS 400 produce identical debt.

If `yesterday_tss` is unavailable it may be derived as `duration_hr × IF² × 100`; if it is null
after that, the step is skipped entirely.

### Aggregation when yesterday had multiple sessions

**RATIFIED (Xuan, 2026-07-29)** — resolves [Q-013](OPEN-QUESTIONS.md#q-013). Not present in the
Notion source, which models yesterday as a single session.

```
yesterday_tss = Σ TSS(s) for every session s completed yesterday
                # each s resolved by the normal ladder:
                #   TP actual → TP planned → duration_hr × IF² × 100

hours_since   = hours between the LAST session's end time and now
```

Two consequences worth stating, because they are the whole point of the ruling:
- **The debt is computed once, from the summed TSS** — not once per session. Two qualifying
  sessions do not produce double debt.
- **A double yesterday can clear the ≥ 150 gate that neither session clears alone.** Two 2-hour
  rides at IF 0.72 sum to 207 and earn full debt (94 g carb at 75 kg), where the larger-single-
  session reading would earn nothing. This is the case the ruling exists to settle.

Because the debt magnitude does not scale with TSS above the gate, aggregation is only observable
in that band — where no single session reaches 150 but the day total does.

Using the **last** session's end time is the generous reading: it minimizes `hours_since` and so
maximizes the decay factor. For a morning-plus-evening double it can be a near-2× swing in the
debt versus using the first session's end time.

| yesterday TSS | hours since | carb add | prot add |
|---|---|---|---|
| 100 | 20 | 0 | 0 |
| 150 | 16 | 94 | 7.5 |
| 150 | 27 | 47 | 3.8 |
| 220 | 34 | 10 | 0.8 |
| 220 | 36 | 0 | 0 |
| 200 | 18 | 94 | 7.5 |
| null | — | 0 | 0 |
| 200 | 0 | 94 | 7.5 |
| 200 | 100 | 0 | 0 |

(75 kg reference athlete; full debt = `1.25 × 75 = 93.75 → 94 g` carb, `7.5 g` protein.)

---

## Formula 8 — `preLoadOverride(...)`

**Upward-only: this step can raise carb, never lower it.**

```
if tomorrow_is_race OR tomorrow_tss > 200:
  return max(current_carb, 9.0 × weight_kg)      # full carb-load floor

if tomorrow_tss > 120 OR tomorrow_duration_hr > 1.5:
  return current_carb + 1.5 × weight_kg          # moderate top-up, additive

return current_carb
```

The two tiers behave differently: the race tier is a **floor** (`max`), so an already-higher target
survives untouched; the moderate tier is an **addition**, so it always increases the target.
Thresholds are strict — TSS 121 triggers the moderate tier, TSS 120 does not.

If every tomorrow field is null, the step is skipped.

| Tomorrow | current carb | result |
|---|---|---|
| null | 400 | 400 |
| TSS 50, 1 hr, not race | 400 | 400 |
| TSS 130, 2 hr, not race | 350 | 462.5 → **463** |
| TSS 130, 2 hr, not race | 500 | 612.5 → **613** |
| `is_race = true` | 350 | **675** (= 9.0 × 75) |
| `is_race = true` | 700 | **700** (already above the floor) |
| TSS 250, not race | 400 | **675** |
| TSS 121 | c | c + 112.5 |
| TSS 120 | c | c (trigger is `>`, not `≥`) |

---

## Formula 9 — `weeklyLoadAdjust(ratio, weight_kg)`

Additive nudge, in g/kg, from this week's load relative to typical.

| `weekly_load_ratio` | carb | protein |
|---|---|---|
| `< 0.7` | −1.0 × weight | 0 |
| `< 0.9` | −0.5 × weight | 0 |
| `≤ 1.1` | 0 | 0 |
| `≤ 1.3` | +0.5 × weight | +0.1 × weight |
| `> 1.3` | +1.0 × weight | +0.2 × weight |

Boundary semantics, pinned by the source tests: ratio **exactly 0.7** falls in the −0.5 bucket (the
first test is strict `<`); ratio **exactly 1.1** falls in the neutral bucket; ratio 1.11 falls in
the +0.5 bucket. At 75 kg: −75, −38, 0, +38 / +8, +75 / +15.

---

## Formula 10 — `phaseModifiers(phase)`

Multiplicative scaling, applied **after all additive steps and before clamping**.

| Phase | carb_mod | prot_mod | fat_mod |
|---|---|---|---|
| `BASE` | 1.00 | 1.00 | 1.00 |
| `BUILD` | 1.08 | 1.05 | 1.00 |
| `PEAK` | 1.12 | 1.10 | 0.95 |
| `TAPER` | 0.88 | 1.00 | 1.05 |
| `RACE_WEEK` | 1.00 | 1.00 | 0.85 |
| `OFF_SEASON` | 0.80 | 1.00 | 1.10 |

`RACE_WEEK`'s carb modifier is deliberately forced to 1.00 — the SSOT states this explicitly, so a
taper-style reduction cannot undermine the pre-load carb protocol.

**`fat_mod` is never applied anywhere in the pipeline.** Fat is a pure residual
([R3](README.md#cross-cutting-rules)), so the column has no effect on output. Registered as
[Q-004](OPEN-QUESTIONS.md#q-004).

At carb 400 / prot 130: BUILD → 432 / 137, PEAK → 448 / 143, TAPER → 352 / 130,
OFF_SEASON → 320 / 130, RACE_WEEK → 400 / 130.

---

## Worked integration example (verified end-to-end)

The "pre-race, all layers" case exercises every step in this file. Reference athlete 75 kg,
run 1.5 hr IF 0.82, yesterday TSS 220 at 20 h, tomorrow is a race, phase `PEAK`, ratio 1.25:

```
baseline carb                      300
+ session carb (IF 0.82, 1.5 hr)   +88.5   → 388.5   (rate 59 g/hr; no ×1.15: IF ≤ 0.85, dur = 1.5)
+ recovery debt (factor 0.889)     +83.3   → 471.8
  pre-load: max(471.8, 675)                → 675     (race floor wins)
+ weekly (ratio 1.25 → +0.5/kg)    +37.5   → 712.5
× phase PEAK 1.12                          → 798     ✓ matches the source expectation
```

Protein, same case: `115.2 + 15 (dur > 1 hr) + 6.67 (debt) + 7.5 (weekly) = 144.4 × 1.10 = 158.8
→ 159` ✓.

Note this example uses phase `PEAK` while tomorrow is a race, whereas the source's conflict table
asserts the phase "must be `RACE_WEEK`" in that situation. The spec contains no rule forcing the
phase — see [Q-005](OPEN-QUESTIONS.md#q-005).

## Constants — provenance

Every constant in this section is **uncited** in the SSOT doc: the TSS 150 recovery gate, the
18 h/36 h decay window, 1.25 and 0.10 g/kg debt rates, the 9.0 g/kg carb-load floor, the TSS 200 /
120 and 1.5 hr pre-load triggers, the 1.5 g/kg moderate top-up, all five weekly-ratio buckets and
their magnitudes, and all eighteen phase modifiers. The 9.0 g/kg race load sits inside the
commonly cited 8–12 g/kg carb-loading range, but the page asserts no source.

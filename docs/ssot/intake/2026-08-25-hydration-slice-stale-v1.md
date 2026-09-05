type: spec-erratum
bundle: pre-workout-macros@v1

## Why this matters
The `pre-workout-hydration` conformance slice **cannot run on any branch** — it fails to compile
against the current engine. So nothing is verifying pre-workout hydration today. On `main` the
vector set additionally still asserts **v1**, and if the harness were repaired there as-is it would
ratify `fluidMl: 0` on the gate path: precisely the value ratified v6 invariant 11 forbids, and
precisely the value production is persisting on all 10 August gated plans. Red-means-raise, so this
is filed rather than fixed. It blocks verification of the sibling ruling-request
`2026-08-25-pre-workout-fluid-gate-thresholds.md`.

## Artifact + location
1. `conformance/pre_workout_hydration_conformance_test.dart` — lines 38, 40–45. **Broken on every
   branch, including `qa/pre-workout-drawers`.** This is the unsolved half.
2. `vectors/fueling/pre-workout-hydration.json` and `spec/fueling/pre-workout-hydration.md` — the v1
   slice **on `main` only**. Already corrected on `qa/pre-workout-drawers` (19 commits ahead,
   unmerged); that branch carries the ratified v6 spec and its 21 vectors, byte-matching the app
   mirror at `docs/ssot/vectors/fueling/pre-workout-hydration.json`, with both gate vectors
   (`gate-fires-short-mild`, `gate-tempnull-default`) correctly expecting
   `fluidMl / fluidLowMl / fluidHighMl: null`, `regime: "gated"`, `targetBasis: "none"`.

## Why it is wrong

### (a) The harness does not compile — on any branch
`./conformance/run_dart.sh pre-workout-hydration` fails to build against the real
`OfflineMacroCalculator`:

- `:38` `chkInt('tier', out.tier)` — `PreWorkoutHydrationResult` has no `tier` getter. v6 retires it
  ("**`tier` (int) is RETIRED. Not emitted.**").
- `:40–42` `chkInt` takes `int`; `fluidMl` / `fluidLowMl` / `fluidHighMl` are `double?`.
- `:43–45` `chkInt` takes `int`; `sodiumMg` / `sodiumLowMg` / `sodiumHighMg` are `int?` — null on
  every path under sodium v3.

`chkInt` is also structurally unable to express this slice's central distinction: it cannot compare
a nullable against an expected `null`, so a repaired-but-unchanged comparator would silently treat
gate-path `null` and a real `0` as the same result — the exact conflation the v6 Outputs section
warns "will misreport both". Landing the v6 vectors without rewriting the comparator therefore does
**not** fix this.

### (b) `main`'s vector set is v1 throughout
`spec/fueling/pre-workout-hydration.md` on `main` is the v1 slice (RATIFIED 2026-07-26,
`fluidMl = BW·6`). All 9 of its vectors contradict ratified v6; 8 of 9 also assert the retired
`tier`:

| vector id | `tier`? | `main` `fluidMl` | v6 requires |
|---|---|---|---|
| tier1-ge120-65kg | yes | 390 | 487.5 |
| tier1-boundary-120-70kg | yes | 420 | 525 |
| tier1-heavy-90kg | yes | 540 | 675 |
| tier2-60min-before | yes | 250 | 368.8 |
| tier2-boundary-119 | yes | 250 | 597.1 |
| tier2-boundary-10 | yes | 250 | 269.8 |
| tier3-too-late | yes | 0 | 259.9 |
| gate-short-mild | no | **0** | **null** |
| gate-not-fired-hot-short | yes | 390 | 487.5 |

The tier1 rows are `BW·6`; v6 is `7.5·BW` above `T_REF`. `tier3-too-late` asserts all-zeros below
10 min, a v1 rule v6 removed — invariant 7 pins `plan = min(250, 7.5·BW)` at `t = 0`, so zero is
unreachable. `gate-short-mild` asserts `fluidMl: 0` where invariant 11 requires
`null`/`null`/`null` and an empty `tiers` array, "**never `0`**".

## Smallest correction
Two independent steps:

1. **Rewrite `pre_workout_hydration_conformance_test.dart` to the v6 output shape** — drop `tier`,
   compare `fluidMl`/`fluidLowMl`/`fluidHighMl` as nullable doubles and `sodium*Mg` as nullable ints,
   assert `null` distinctly from `0` so invariant 11 is genuinely pinned, and add
   `regime` / `targetBasis` / `tiers`-length assertions the current harness never checks. No branch
   has this yet; it is the only new work.
2. **Land `qa/pre-workout-drawers` into `main`** (or record why it is parked). Its spec and vectors
   are already correct and need no edits.

Neither step requires a judgment call on content. The only open sequencing question is whether the
branch is deliberately parked pending
`2026-08-25-pre-workout-fluid-gate-thresholds.md` — if the gate thresholds move, the two gate vectors
regenerate, but the other 19 are unaffected and the harness rewrite is needed either way.

## Related
- Ruling-request `2026-08-25-pre-workout-fluid-gate-thresholds.md` (PW-003) — the gate's thresholds.
- `pre-workout-hydration.md` and `pre-workout-sodium.md` both still carry a stale banner claiming
  "**Not yet implemented — code implements v1**" — on `qa/pre-workout-drawers` *and* in the app
  mirror. Production disproves it: August plans emit v6 regimes (`gated` / `cited` / `extrapolated`)
  and v3 `null` sodium. One-line erratum against those headers, to fold in with step 2.

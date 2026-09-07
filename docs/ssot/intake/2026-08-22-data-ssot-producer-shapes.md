type: ruling-request
bundle: daily-macros-dashboard@v3

## Why this matters
Every ratified family in this repo specifies MATH — given these inputs, this output. Nothing
specifies **what the inputs look like in production**. That gap is not theoretical: it shipped
a wrong number to prod in 1.24.0, and the test suite could not see it because both halves of
the seam are tested and neither test knows the other exists.

## The question
Should `producers` become a ratified SSOT family in its own right — normative statements of the
row shapes each writer produces, plus ONE ordered resolution ladder per derived quantity that
every consumer must follow — with `vectors/producers/` as its conformance corpus?

## What happened (the evidence for "yes")
Providers deliberately write `activities.duration_minutes = NULL` whenever a workout carries
distance or pace. This is intentional and documented in code
(`FinalSurgeTransformer._getFallbackDurationMinutes`: "keep duration null and let the UI
estimate") and asserted **ten times** in `final_surge_transformer_test.dart`.

Four consumers then each resolved that field their own way:

| Consumer | Duration | `other` → sport | Zoneless IF |
|---|---|---|---|
| `daily_macro_service._sessionFromActivityRow` (engine input) | distance×pace / ÷speed / swim pace, else 30/60 | strength @ 30 min | 70/20/10 → 0.7715 |
| `dashboard_assembler._sessionKcal` (display) | **none** — `?? 60` | unmapped @ 60 min | flat 0.74 |
| `training_insight_service` (onboarding reveal) | mirrors the engine, via its own copy of the constants | excluded | own constants |
| `plan_preview_service` (onboarding preview) | insights' longest run/ride | n/a | own constants |

A fifth copy lives inside `test/features/daily_macros/estimate_duration_minutes_test.dart`,
which imports only `flutter_test` and therefore pins no production code at all.

Result on a real prod account: a 3 mi, a 6.2 mi and a 15 mi run all priced at 510 kcal; the
15-miler is ~47% low. The macro targets on the same screen were CORRECT (they came from the
engine's ladder), so the dashboard contradicted itself by 649 kcal.
Full analysis: `ops/data/bug-reports/2026-08-22-dashboard-prices-distance-sessions-at-flat-60min.md`.

## Why the existing instruments missed it
- **Vectors** start one layer below the defect: all 27 `session-demand` vectors take `durationHr`
  as an input; `distance` appears in zero vectors across the whole `vectors/` tree.
- **Cross-language parity** compares two implementations of the same formula — both handed the
  same already-resolved duration. Two runtimes, one truth, wrong input.
- **Stage 6b recon** looks for twin *implementations* and adjacent *call sites* — both code-shaped.
  This defect lived in data. (Recon has since been extended: `ship-bundle` item (7), the
  producer/consumer inventory.)

## Options
1. **Ratify `producers` as a full family** (recommended): `spec/producers/*.md` per writer +
   `spec/producers/resolution-ladders.md` + `vectors/producers/*.json` as the corpus. Consumed by
   an app-side producer→consumer contract tier, dispatched as a normal conformance slice.
2. **Ladders only** — skip the per-producer docs, ratify just one ordered ladder per derived
   quantity. Cheaper; leaves "what shapes exist" undocumented, which is half the bug.
3. **Treat each divergence as its own Q-#** — no new family. Fixes today's three divergences,
   guarantees the next surface reintroduces a fourth.

## Note on sequencing
This ruling is NOT a blocker for fixing the shipped bug. The engine's ladder is already the
ratified-by-behaviour one and the display is simply missing it; unifying them restores agreement
with a spec that already exists in `session-demand.md`. Ratification decides whether the ladder
becomes *enforced contract* going forward, not what today's correct number is.

## Related open items
- `intake/2026-08-20-zoneless-if-default-engine-vs-display.md` — the IF row of the same table.
- `intake/2026-08-20-session-cost-unknown-activity-types.md` — the `other`→sport row.
- Both are ladder cells; ruling them individually and ruling this family are complementary,
  not alternatives.

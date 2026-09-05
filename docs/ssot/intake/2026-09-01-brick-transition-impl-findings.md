> **RESOLVED 2026-09-01 — finding 1: watchlist row struck in the handoff; finding 2: candidateIds convention deferred to the next vector regeneration (inside the tag; @v1.1 not worth a point re-tag for zero behavioral change)**

type: finding
bundle: brick-transition@v1 (implementation pass, app feature/brick-transition-v1)

# Implementation findings — brick-transition@v1 (2026-09-01)

Two mismatches between the bundle's documents and what the code/vectors
actually hold, found while implementing to green. Neither blocked done_when;
both are recorded so the documents can be corrected (never the mirror).

## 1. Handoff watchlist row 4 overstates parity fixtures 29/30

`bundles/brick-transition.handoff.md` (watchlist item 4) lists parity
fixtures `29/30-brick-triathlon-*.json` as pinning "old T1/T2 names + 300 ml
+ weight carbs". Verified against the files
(`app/supabase/functions/tests/parity/fixtures/`): both are single-blob
`during_run`/`post_run` triathlon-path fixtures — no `transition_name`, no
300 ml, no transition carbs, no `brick_segments`; a grep for `transition`
over the whole 41-fixture corpus returns nothing. The parity suite ran green
before and after the T-1/R8 change with the fixtures untouched. The
watchlist row should be struck at the handoff's next revision so a future
agent doesn't hunt for pins that don't exist. (Every other watchlist row
verified accurate; the extra pin the list missed —
`test/features/nutrition_plan/data/offline_macro_calculator_hydration_test.dart`
pinning `T2` on a 2-leg bike→run brick — was found by grep and updated with
the change.)

## 2. brick-eligibility vectors: `candidateIds` on offered:false rows

In `vectors/domain/brick-eligibility.json`, the four `offered: false` offer
vectors carry a non-empty `expected.candidateIds` enumerating the
eligible-but-insufficient rows (e.g. `single-eligible-not-offered` expects
`["w1"]`). The published app interface (`brickCandidateIds`) deliberately
returns EMPTY when the R1 offer gate fails — nothing is selectable when no
offer is made — so those ids are not observable through the published
predicate. The conformance harness
(`conformance/brick_eligibility_conformance_test.dart`) therefore asserts,
for offered:false vectors: the offer gate itself, `brickCandidateIds` empty,
fewer than 2 eligible rows on the day, and per-row `isBrickEligible`
matching the vector's candidate list exactly. This checks the same facts by
another route, but the vector shape implies an API ("candidates while not
offered") that the spec never defines. Suggest either the oracle notes this
convention explicitly or the offered:false vectors move `candidateIds` to a
differently-named diagnostic field at the next vector regeneration.

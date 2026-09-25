type: ruling-request
bundle: real-payload-corpus@v1.1 + data-integrations family — the ruled-but-unpinned audit (Xuan asked "what else is missing?", 2026-09-20)

## Why this matters
Q7's gap prompted a mechanical sweep of EVERY ruling from the 2026-09-20 interview against
two tests: implemented? and PINNED (does anything go red if it's absent)? Five more gaps.
Every one shares Q7's disease: ruled → folded → handback line → nothing red → gates blind.

## The audit table (verified by grep/ls, not memory)
| # | Ruled item | State | Why gates missed it | The pin it needs |
|---|---|---|---|---|
| G1 | Q-INT29 narrowing: DELETE the fabricating fallbacks (≤1.5⇒%FTP at `training_peaks_transformer.dart:977`, conversational default `:914`, FS twin) | **NOT IMPLEMENTED** — branches alive on the landed release branch | the deletion-assert row (DI-16) lives on qa-33's UNLANDED v1.1 branch; nothing landed pins it | a landed DI row + a vector asserting the branches are gone (or a test that fabricated-classification inputs yield null/default, never %FTP) |
| G2 | Dead-man client check (ruled 2026-09-20) | implemented (`raw_retention_dead_man_check.dart`) but **NO TEST** | handback checkbox only | behavioral test: stale audit row ⇒ Sentry warning fired; fresh ⇒ silent |
| G3 | Garmin corpus wing — batch scan of stored raw incl. C9 multisport parents (B-2/B-5 material) | **NOT IMPLEMENTED** — `samples/` has no `garmin/`; export scans provider_raw_payloads only | no DI row demanded a garmin exemplar; handback §2 line unpinned | DI row + an expected_flow-style check ("≥1 garmin exemplar exists once the wing ships") + the C9 promotion itself |
| G4 | Q3's privacy-declaration line ("rides the next terms update") | **NO LINE, NO OWNER, NO TRACKING** (`docs/privacy/` has nothing) | "rides the next X" assigned no owner and pinned nothing | an ops-side task with an owner + a qa check (grep the privacy doc) that flips when the line ships |
| G5 | B1 TP scope request (metrics:read + file-export) | draft created in Gmail — **SEND UNCONFIRMED** | an external action can't be pinned by the repo; nobody asked | Xuan confirms sent y/n; then a blocked-on-provider register note with the sent date |
| — | Q7 sample/HRV capture | already filed: `intake/2026-09-20-q7-sample-hrv-capture-unimplemented.md` | — | — |

Known-and-deliberate (tracked, not gaps): expected_flows unseeded until prod deploy (W8,
runbook); casing fix on its own ops-Critical ticket; novelty push-counter deferred (ruled).

## The systemic fix (one rule, recommend folding into apply-ruling + ship-bundle)
**A handback/build item does not count as carried unless it names its RED** — the vector,
test row, or expected_flow that is red today and turns green when the item ships. An item
that cannot name one gets a live check invented for it before the bundle ships. (Q7 + G1–G4
are four instances of the same failure in one day's work — the rule pays immediately.)

## The question
Expedite G1–G3 + Q7 as one small gap-closure bundle now, or ride the next bundle? (G4 is an
ops-side task either way; G5 is one word from Xuan.)

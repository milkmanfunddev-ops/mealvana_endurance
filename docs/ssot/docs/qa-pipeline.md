# The QA pipeline — from Notion intent to a landed bundle

The canonical workflow, one skill per stage, human gates marked ⚖ (deliberate, never automated
away — the rulings and ratifications ARE the product). Stages 1–8 proved out on
`daily-macros-dashboard@v1` (2026-08-13/14).

> This doc covers the QA half. The full cross-repo arc — this pipeline → app implementation
> (Phase A/B) → dev deploy → land → sim-explore loop → prod (Phase C) — is routed by
> `ops/docs/feature-delivery-lifecycle.md`, which also carries the stage-number ↔ Phase-A/B/C
> crosswalk.

| # | Stage | Skill / actor | Output | Gate |
|---|---|---|---|---|
| 0 | Distill upstream intent (Notion) into math SSOTs; contradictions → OPEN-QUESTIONS register | by hand (pattern established) | `spec/<family>/*.md` RECORDED + register | |
| 1 | Rule the register | ⚖ author rules, agent researches + folds | all questions RULED | ⚖ |
| 2 | **Reconcile** the design prototype against the math SSOTs — traceability, not accuracy | `design-spec-reconcile` | findings register: TRACED / DESIGN-FIX / SPEC-ADD / RULING-NEEDED / MOCK-NOTE | ⚖ rulings |
| 3 | **Extract** the design SSOT from the prototype (screenshot test: only what stills can't hold) | `design-ssot-extract` | `spec/design/` tokens + components + surfaces, PROPOSED | ⚖ ratify (math + design families) |
| 4 | **Vectors** for every ratified math/display spec (oracle → verify vs worked examples → emit) | `spec-to-vectors` | `vectors/<family>/*.json` | |
| 5 | **Design conformance manifests** — goldens + gesture tests that must exist | by hand today (candidate: a design mode for spec-to-vectors) | `conformance/design/*.yaml` | |
| 6 | **Test plan** — the generative gap pass BETWEEN documents; owned-by-NONE links surface here | `qa-test-plan` (lives on `qa/feature-test-plans` pending merge) | `docs/feature-test-plans/<feature>.md` DRAFT | ⚖ rule any NONE links |
| 6b | **Terrain recon** — verify against the EXISTING codebase: update-vs-greenfield, twin implementations & parity fixtures, deploy-coupled API surfaces, tests pinning superseded behavior, adjacent call sites the rulings touch (e.g. other delete paths), fate of existing UI/goldens, **and runtime coexistence with INSTALLED versions** — deployed function names old clients still call, client-side version gates that discard on mismatch, schema-version windows (`app_config` min/current), flags — so the handoff answers the frozen-v5/`-v6`-class question before the coding agent meets it (added 2026-08-20 after the daily-macros deploy hit every one of these live; rulings in `ops/docs/supabase-deploy-playbook.md` §6); **plus the producer/consumer inventory** — one table over every domain field the new surface reads: producers, the shapes they actually write (deliberate NULLs named — verified from the producers' own tests, not the column definition), existing consumers and how each resolves it, and this surface's rule; a rule that differs from an existing consumer's is a finding, and a second implementation of an existing derivation is a request to EXTRACT it, never to copy it (added 2026-08-22 after the flat-60-minute session-cost bug, where the recon's code-shaped items — twins, call sites — missed a defect that lived in data) | read-only greps + file checks; findings feed the test plan and the handoff | the **conflict watchlist** (mandatory handoff section) | ⚖ if recon surfaces a rulable question |
| 7 | **Ship** — manifest, commit, annotated tag, push branch; emit the coding-agent HANDOFF | `ship-bundle` | `bundles/<bundle>.yaml` + `<bundle>.handoff.md` + tag `<bundle>@vN` | |
| 8 | Implement — the coding agent works from the handoff (port prompt + design addendum), builds runner, tests, goldens, schema | coding agent (app repo) | green conformance | |
| 9 | **Land** — the only step that touches main, both repos, one gate | `land-bundle` | merged trunk, both repos | gate: green + contract-unmodified |

**Why recon sits at 6b and not earlier:** specs are derived from intent (stages 0–3), never from
code — running recon early invites the regression-snapshot trap. The codebase is checked exactly
once contracts are settled, as *terrain*, not *authority*: findings become watchlist items,
DEVIATIONS entries, or rulings — never silent spec edits. Proved necessary on
`daily-macros-dashboard@v1`, where recon (run late, by luck) found a cross-language parity twin,
hard-delete call sites outside the feature, and four legacy test files pinning the superseded
engine.

Cross-cutting rules that bind every stage: implementation is not authorization (CLAUDE.md);
specs/vectors never move to make code pass; goldens regenerate only after a spec change; the
prototype is the reference rendering, the spec is the contract; expected-red until the gate.

Iteration re-entry: a change after ratification is a ruled amendment (Q-#, folded in place) or a
new spec version → new bundle version. `design-spec-reconcile` re-runs after either the prototype
or the specs move; TRACED must grow monotonically.

## The Intake stage — how post-ship findings flow back (between 8 and 9)

Once a bundle is shipped and implementation is underway, the app side WILL hit spec gaps, suspect
vectors, and unspecified behavior. Those findings enter through `intake/` (contract:
`intake/README.md`), never through direct spec or vector edits — "red means raise", on both sides.

| # | Stage | Skill / actor | Output | Gate |
|---|---|---|---|---|
| I1 | Producer files a `ruling-request` or `spec-erratum` in `intake/` | app-side agent (never edits specs/vectors) | unstamped `intake/YYYY-MM-DD-<slug>.md` | |
| I2 | **Triage** — validate vs contract, map to bundle+slices, classify impact (erratum / post-ratification addition / contract change), independently verify errata, brief each ruling | `intake-triage` | ONE triage report; optionally Q-numbers registered | ⚖ Xuan rules |
| I3 | **Apply** — write the resolution (regenerated vectors / dated spec folds / register + DEVIATIONS), update bundle notes (re-tag `@vN.M` recommended for in-place fixes; contract changes go to `ship-bundle` for `@v(N+1)`), stamp the intake file | `apply-ruling` | resolved artifacts + stamped intake + APP-SIDE HANDBACK checklist | |
| I4 | Handback — app agent re-syncs the SSOT mirror, re-runs suites, implements what the ruling gates, flips test-plan rows | coding agent (app repo) | green conformance on the corrected contract | |
| I5 | Land via stage 9 as usual | `land-bundle` | merged trunk | gate: green + contract-unmodified |

The two skills split exactly at the human gate: `intake-triage` prepares and STOPS (it never
rules, never edits an artifact beyond register promotion); `apply-ruling` runs only on decided
items (it never rules either — a missing decision stops it). Neither writes vectors by hand
(`spec-to-vectors`), tags (`ship-bundle`), or touches main (`land-bundle`).

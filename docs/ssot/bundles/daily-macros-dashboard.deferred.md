# Deferred ledger — daily-macros-dashboard (post-@v3, toward release)

**What this file is:** the written record of gaps we KNOW about and are consciously shipping
around — so "good enough, move on" never silently becomes "forgotten." One line per item, with
where its full record lives and what un-defers it. Reviewed at every release-candidate
`/sim-explore` gate; items leave this file only by being fixed, ruled, or explicitly re-deferred
with a new date.

**RC-gate reconciliation (2026-08-21, `/sim-explore prod`):** every line below re-verdicted; D12/D13
added from that session; see `runs/2026-08-21-sim-explore-prod-release-smoke.md`.

**Release decision (Xuan, 2026-08-20):** ship once the dispatch's release-gating fixes land
(70-kg weight plumbing · unknown-sport interim · duplicate creation — plus what else the
bug-batch returns); everything below is consciously carried.

| # | Deferred item | Record | Un-deferred by |
|---|---|---|---|
| ~~D1~~ | **RESOLVED (fix/qa-2026-08-20-findings `1efac08f`):** IF unified — zones-when-present (RMS), documented 0.74 fallback, ONE `_sessionKcal` feeds card/face/sheet; verified on-sim 2026-08-20 (1,408 → 1,443 tracking weight) | same | — |
| D2 | Server-side tombstone not applied to locally-known rows (bites multi-device / coach-delete flows only) | `ops/data/bug-reports/2026-08-20-server-tombstone-not-applied-to-known-local-rows.md` | sync-cadence determination + the two merge-semantics rulings (D6), so the seam is touched once |
| D3 | Unknown-sport FINAL session-cost rates (interim low-rate ships; mobility/composite/other classes unruled) | `intake/2026-08-20-session-cost-unknown-activity-types.md` | Xuan's ruling → apply-ruling → vectors |
| D4 | Future-day net-balance figure + "time to eat" copy (intraday register applied to a day not begun) | `intake/2026-08-20-future-day-net-balance-copy.md` | Xuan's ruling (projection register recommended) |
| ~~D5~~ | **CLOSED — spec-correct (QA trace, 2026-08-20):** skip flips `getDayModifier` training→rest, full-day NEAT moves ~40 kcal, prorated ≈25 by late afternoon. Q-D5 zero-demand composing with ratified NEAT day-typing; no double-count. (The dispatch's trace ask went unanswered by the agent — QA traced it instead) | this line | — |
| D6 | Skipped-row sync match window + platform-declared skip semantics (status quo IS the ratified text — nothing un-ruled ships) | `intake/2026-08-18-skipped-row-sync-match-window.md`, `-platform-declared-skip-semantics.md` | Xuan's rulings, likely with the integration-sync SSOT pass |
| D7 | Charter row 7 never exercised: no DONE_VERIFIED card existed on any visited day — G3 suppression is manifest-pinned but not eyeballed on-device | `runs/2026-08-20-sim-explore-macro-dashboard.md` | a sim-explore session with a Garmin-synced fixture |
| ~~D8~~ | **RESOLVED (fix branch `043d0cab`):** reveal outside-tap dismiss verified on-sim; live caption; button semantics | same | — |
| D9 | Test-plan rows I7 / I8 / I4-concrete: tests EXIST on the fix branch and pass locally (72/72 Dart + 145/145 Deno, QA-run 2026-08-20) — flip ⬜→✅ when they run in CI post-merge | `docs/feature-test-plans/macro-dashboard.md` (qa `788360f`) | CI run on develop after merge |
| D10 | `daily_macro_targets.updated_at` touched on past-day rows during recomputes (values unchanged — Q-016 intact; auditability noise only) | `runs/2026-08-20-sim-explore-macro-dashboard.md` (observation) | next time someone is in the upsert path |
| D11 | `birthday ?? DateTime(1990,1,1)` in the user DAO masks the missing-birthday validator the same way the 150-lb default masked weight — deliberately NOT changed in the batch (age flows through more consumers); same silent-default class as I7 | agent's note in app `6fdc26b5` + `ops/data/bug-reports/2026-08-20-user-dao-silent-150lb-weight-default.md` | its own triaged fix |
| D12 | Engine↔display session-kcal disagree ~8.7% (display 918 / engine `session_kcal` 998 for one workout; IF source differs across the layer boundary). Display surfaces agree with each other — this is the remaining cross-layer edge of I4 | `ops/data/bug-reports/2026-08-21-engine-vs-display-session-kcal-if-source.md` | next display/engine iteration — confirm the engine's IF derivation, then make one layer authoritative |
| D13 | Cold start routes to the onboarding welcome screen whenever `users.onboarding_completed = false`, even with a live persisted session — while sign-in on the same account routes to the dashboard. Not a bug for real athletes (flag true); an incoherence worth resolving | `runs/2026-08-21-sim-explore-prod-release-smoke.md` finding 2 | whenever the startup gate is next touched |
| D14 | Charter rows 6 (skip/unskip) and 9 (weight change → recompute) never exercised **on prod** — deliberately skipped to limit writes on a real account; both proven on dev | same run file | a prod session on a throwaway internal account |
| D15 | P5 upgrade-from-old-install (old build → 1.24.0 over existing data) is not simulator-testable; remains a human-on-device step | playbook §7 P5 | Xuan, on device, at TestFlight |


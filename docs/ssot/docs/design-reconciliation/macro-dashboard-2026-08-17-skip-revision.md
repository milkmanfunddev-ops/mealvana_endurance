# Macro-dashboard prototype revision (2026-08-17) — reconciliation against the v1.1 rulings

**Prototype:** `prototypes/macro-dashboard/index.html` @ `5a22ca8` (2026-08-17 17:00), diffed against
`aa81d21` (2026-08-14, the rendering the v1 goldens/gestures manifests were written from). Method:
unpacked both bundle exports and diffed the template + Day Header source; every changed line read.
**Contract checked:** `spec/design/components/workout-card.md` Q-D4/Q-D5 folds (v1.1),
`conformance/design/macro-dashboard.{goldens,gestures}.yaml`, and the STAGED-FOR-@v2 unified-skip
model in `bundles/daily-macros-dashboard.yaml`.

## Verdict
The revision delivers everything Q-D4/Q-D5 asked for **and** already implements the v2 unified-skip
model (skip replaces delete). It is therefore a valid reference rendering for the v1.1 SKIPPED golden
and the three new gesture tests, but it is no longer a reference rendering for the v1/v1.1 delete
gestures (G4/G5, S-2, `tombstone_prevents_reimport`) — those reconcile only at v2.

## Register

| # | Class | Finding | Where in prototype |
|---|---|---|---|
| T-1 | traced | Q-D4: no awaiting-sync glyph — `awaitingSync:false` in every skin; confirmed = done skin + `self-reported` chip | template L563–580 |
| T-2 | traced | Q-D5 trigger: passive SKIPPED exists only on the past day (day 16 run `def:"skipped"`, "the day rolling over skipped it passively"); today's run stays `scheduled`; no 22:00 trigger; "Did this happen? Swipe right to mark done" copy is gone | `WK_BY_DAY`, `NOW = isToday ? 900 : 1440` |
| T-3 | traced | Q-D5 treatment: single-word `Skipped` chip; S-6 unaffected | skin `isSkipped` |
| T-4 | traced | Q-D5 fuel: every day figure reads `wkCounted` (excludes skipped) — done-workout kcal, workouts list, Active Energy sheet data + rows, by-end-of-day burn, `workoutsJson` | L552, 662–691, 807–810 |
| T-5 | traced | Q-D5 gesture: full right-swipe on SKIPPED → `confirmed` (`wkToggle`: anything not confirmed → confirmed; fuel re-enters) | `wkToggle` L393 |
| T-6 | traced | Q-D5 reference rendering: previous-day view carrying one SKIPPED card now exists (Day Header nav 16 ↔ 17) | Day Header component |
| T-7 | traced (improvement) | G3/Q-D1: a verified card now takes **no gesture at all** and renders no "Mark undone" node — the reference-rendering defect the `g3_verified_suppressed` negative test guards has been removed | drag guard `if (!canToggle) return` |
| T-8 | traced (v2) | left-swipe reveals neutral `Skip` / `Unskip` (never destructive); `wdel`/delete gone | `wkSkip`, L607–613 |
| T-9 | traced (v2) | active skip allowed on the current day (today's run is skippable) | `wkSkip` on `w2` |
| T-10 | traced (v2) | skipped card loses its timeline slot — no timestamp, tucked after every timed card, neutral rail ink; unskip restores `planned_time` + position | `wkNode`, `fullTimeline` |
| D-1 | design-fix (reference-rendering defect, do NOT encode) | On a past day, right-swipe #2 on a recovered card goes `confirmed → scheduled`, rendering a **PLANNED card on a past day** — Q-D5 forbids that state. The app derives state (past + unresolved ⇒ SKIPPED), so the manifest's "back to SKIPPED-eligible state" wording is right; add to workout-card's known-defects list (W-9) so no one encodes it | `wkToggle` next-state |
| D-2 | spec-add (one line) | SKIPPED visual is "planned treatment **drained to neutral**" (cream dotted edge/icon, neutral chip, dim kcal, neutral rail) — the spec row says only "Planned treatment", which literally means indistinguishable from PLANNED except the chip. Since the golden is blessed from this rendering, the States row should carry the neutral signature the day it is blessed | skin `isSkipped` |
| D-3 | contract (v2) | G4/G5 delete, surface S-2, `g4_swipe_left_reveals_delete`, `g5_delete_removes_everywhere`, `tombstone_prevents_reimport` have no counterpart in the rendering any more. Stay ratified at v1/v1.1 (delete deferred, not repealed); v2 rewrites G4→skip reveal, G5→skip semantics (not counted, tucked), S-2→skip scope, adds "verified takes no left-swipe", "sync beats skip" | — |
| D-4 | mock-note | "sync beats skip" (skipped → later sync ⇒ DONE_VERIFIED) is not demonstrable — no sync simulation in the prototype | — |
| D-5 | mock-note (unrelated to rulings) | meal-row `⋯` expansion with **Swap food** removed — consistent with the F-15 swap-engine deferral; nothing in the manifests referenced it | L296–301 old |
| D-6 | mock-note | Day Header: only days 16/17 tappable (the two days with data); discovery hint copy is now "Swipe right to mark done · left to skip" | Day Header |

## Decision and outcome (Xuan, 2026-08-17, later the same day)
- D-1 accepted as reference-rendering defect → **W-10** (register + workout-card known-defects).
- D-2 accepted as-is → the `SKIPPED` row now names the neutral drain.
- **`@v1.1` is not cut.** Because the app had already built delete (`macro_dashboard_screen.dart`
  `_deleteWithUndo`, gestures test, four blessed goldens) and the prototype is already the v2
  reference rendering, the next tag is **`daily-macros-dashboard@v2`** carrying the six intake
  resolutions + the unified-skip contract. **Q-017's 10b exemption is excluded from v2.**
- Skip contract written as v2 DRAFT FOR RATIFICATION: `spec/design/components/workout-card.md`
  (Q-D6, G1–G7 rewritten), `spec/design/surfaces/macro-dashboard.md` (S-2 → skip scope, S-7 tuck),
  both conformance manifests (v2 proposed), `spec/daily-macros/platform-resolution.md` (`SKIPPED`
  status addition, sync beats skip), `spec/design/tokens.md` (no dragonfruit on the card in v2).
  Two derived rules flagged `[design, derived — confirm at ratification]`: past-day passive
  `SKIPPED` reveals no Unskip button (G4); several skipped cards order by `planned_time` (S-7).
- **RATIFIED v2 (Xuan, 2026-08-17)** — both derived rules ratified as `[design]`. `ship-bundle` writes the v2 manifest and tags `@v2`.

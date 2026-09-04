# Meal-planning SSOT — plan

Scales the QA repo's proven shape (`mealvana_endurance_qa/PLAN.md`) to this app-side SSOT: **Lee records what
the code + Xuan's artifacts say; Xuan rules on the ⚖️ interim calls and the deviations; the record gets stamped
RATIFIED per family as she rules.** Same governing rule as the QA repo: **implementation is not authorization.**
Code behavior the SSOT hasn't ratified is a documented/pending-ruling deviation, never a silent spec edit.

---

## Phase 0 — DONE (2026-09-02): intent capture
Xuan's artifacts (AI Scenarios, the 2026-06-17 scope decision, meeting notes, the MealBuddy brief, the UI/UX
brief, prototype test results) distilled into `spec/intent/vana-mealplanning-chatbot.md`, every claim sourced.
Contradictions between her own artifacts, and between her artifacts and the shipped build, filed as Q-1..Q-7
(`OPEN-QUESTIONS.md`) and D-001..D-010 (`DEVIATIONS.md` Part A) — each carrying the ⚖️ interim
call that let building continue.

## Phase 1 — DONE (2026-09-03): restructure into families + vectors + runners
The single intent doc + deviation list split into the families this README's Layout section describes
(`spec/{intent,planning,selection,domain,agent,design}/`), each with `RECORDED v1 — PROPOSED` status; 130+15+5
vectors written against the edge/prototype/Dart triple twins; `conformance/run_{edge,prototype,dart}.sh` +
`run_all.sh` wired to run them for real. Twin-vs-twin and code-vs-spec drift found in the process filed as
Part B deviations (D-011..D-019).

## Phase 2 — DONE (2026-09-03 evening → 09-04): fold in the evening's code + normalize form ← the current restructure
Two things landed the same evening this doc was written:
1. **Code changes** (`../vana-chatbot-update-plan.md` §3's "Opener reversal" + Phase 5/6 notes): the
   question-first opener (D-020), the Q-7 intro card built-then-removed (D-021), verified chat-draft ownership
   (conversation-scoped, already correctly recorded — no deviation found), picker tap-opens/tick-adds
   (`meal_picker_carousel.dart`), the "Next: <type>" progression chip, and "Browse meals from chat"
   (`vana_browse_screen.dart`, `MealCatalogBrowser`, `/vana/browse`).
2. **Form normalization** to match the QA repo's style exactly: explicit `**Status/Source/Code/Scope**` header
   blocks, `R1/R2/…` rule numbering with `RULED`/`⚖️ interim` stamps, `## Conformance` sections naming the
   vector file, DEVIATIONS renumbered to three digits (D-001…) with an old→new map, an `intake/` ruling-request
   folder (Q-1..Q-8, one file each), and vector `status` values restricted to `proposed`/`characterization`.

## Phase 3 — NEXT: Xuan's rulings ← START HERE
Nothing in this SSOT is ratified. The highest-value next step is Xuan actually reading and ruling on:
- **`intake/2026-09-03-*.md`** (8 files: Q-1 scenario scope, Q-2 wizard, Q-3 artifact depth, Q-4 macros default
  — low-ambiguity, mostly a formality — Q-5 proactive cadence, Q-6 tone, Q-7 intro-card reversal, and the new
  Q-8 opener-question-first reversal — the least-settled of all of them, since it trades two of her own spec
  passages against each other).
- Each ruling gets quoted, dated, and folded into its "Suggested spec home" (the `intraday-display.md` §4b
  pattern from the QA repo) — never paraphrased loosely.
- As families get ruled on, promote their `RECORDED v1 — PROPOSED` status header to `RATIFIED v1 (Xuan, date)`
  per family, mirroring the QA repo's stamp discipline.

## Phase 4 — port backlog (D-012)
Decide: port the prototype (`../../mealplanning-prototype/`) up to the edge twin's `contract-v1` surface (opener
variants, context lines, settings, tools, `rewind`+`plan_snapshot`, `Memory.source`, pantry-fed `have`), or
declare it frozen at its current `contract-v1` slice and stop mirroring the persona into it. This is a real
resourcing call, not a ruling — flagged here rather than in `intake/` because it isn't Xuan's decision to make.

## Phase 5 — design conformance (Q-DS1)
`spec/design/` has no `conformance/design/*.yaml` manifests yet — screenshot-test discipline is stated as the
intent but not wired. Write the manifest format (mirroring the QA repo's design conformance shape once one
exists there, or inventing app-side if the QA repo has none) and back-fill it against the golden tests already
listed in each component/surface spec's Conformance section.

## Phase 6 — the loop, ongoing
Bug found in the meal-planning surface → write it as a failing vector here first → fix the twin → the vector is
a permanent guard. Every phase above: red means raise, on every side — a red conformance arm is either wrong
code (fix app-side) or a spec that needs a Q-item / intake file, never a silently edited vector.

---

## Sequencing

Phase 3 (Xuan's rulings) is the only phase blocked on someone other than whoever picks up this doc next; Phases
4 and 5 can run in parallel with it and with each other. Phase 6 is not a phase, it's the standing discipline
every future change follows.

## Ownership

Lee: recording, restructuring, vectors, conformance runners, code verification. Xuan: every ruling in
`intake/`, family ratification stamps, design conformance manifest shape (or delegates it). Neither side
resolves a Q-item by implementer judgment without the ⚖️ mark this register already uses everywhere.

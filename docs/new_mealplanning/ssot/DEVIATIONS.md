# Meal Planning — Deviation Register

Behaviours the SSOT has **not** ratified, in two parts:

- **Part A — intent vs build (D-001 … D-010).** The gaps between Xuan's design intent
  (`spec/intent/vana-mealplanning-chatbot.md`) and the shipped chatbot, surveyed 2026-09-02 and updated as the
  2026-09-03/09-04 phases landed. Each carries the ⚖️ interim call that let the build proceed; none is "fixed" by
  implementer judgment where a Q-item exists.
- **Part B — twin and code deviations (D-011 … D-019).** Found while recording the calculation / domain / design
  families on 2026-09-03: places where the three implementations have drifted from each other, or where the
  build does something the recorded spec calls out. Filed here, never folded into a spec.
- **New entries from the 2026-09-03 evening restructure (D-020+)** are appended after Part B.

**Principle: implementation is not authorization.** Discovering that code does X is a reason to log X here,
not to rewrite the SSOT to say X. Vectors that pin a deviation are `status: characterization` — a tripwire, not
an endorsement.

| status | meaning |
|---|---|
| `open` | logged; awaiting a decision |
| `pending-ruling` | surfaced; not yet decided how to treat (an ⚖️ interim call is live pending Xuan's veto) |
| `expected-red` | Part B — a conformance arm is red on purpose until the named twin catches up |
| `documented` | logged; SSOT deliberately NOT evolved; a future team decision |
| `resolved (date)` | decision made / behaviour landed cleanly under a low-ambiguity interim call — see the note |

## Old → new ID map

This register's IDs were single/double-digit (D-1 … D-19) before the 2026-09-03 evening restructure; every
other doc in this repo (notably `../vana-chatbot-update-plan.md`, which cites D-1 … D-19 throughout) still uses
the old numbers. This table translates.

| Old | New | Old | New | Old | New |
|---|---|---|---|---|---|
| D-1 | D-001 | D-8 | D-008 | D-15 | D-015 |
| D-2 | D-002 | D-9 | D-009 | D-16 | D-016 |
| D-3 | D-003 | D-10 | D-010 | D-17 | D-017 |
| D-4 | D-004 | D-11 | D-011 | D-18 | D-018 |
| D-5 | D-005 | D-12 | D-012 | D-19 | D-019 |
| D-6 | D-006 | D-13 | D-013 | — | — |
| D-7 | D-007 | D-14 | D-014 | — | — |

New (no old number): **D-020** (opener reversal — resolves the old D-002/D-009 "already matches §2.1" note),
**D-021** (Q-7 intro card built-then-removed — tightens old D-010).

---

## Part B — twin and code deviations (2026-09-03)

### D-011 — Prototype `coverageOf` has no `coverage_scope` argument
- **Status:** `expected-red` (prototype arm: `dinners-only-scope`, `dinners-scope-cap-at-7`).
- **Observed:** edge `plan-math.ts` `coverageOf(meals, scope)` narrows the denominator to 7 for `dinners`; the
  prototype's `plan.ts` `coverageOf(meals)` always returns 14, so its plan bar shows "/14" for a dinners-only
  athlete. Dart mirrors the edge (reads the denominator from the wire).
- **Code:** `supabase/functions/_shared/vana/plan-math.ts` `coverageOf` vs prototype `server/vana/plan.ts`.
- **SSOT status:** `spec/planning/plan-coverage.md` records the edge behaviour as the contract. **Fix:** the
  prototype adopts `plan-math.ts` verbatim (R5).

### D-012 — The edge twin is ahead of the prototype (2026-09-03 Phases 2–8)
- **Status:** `open` (port backlog). The prototype is the `contract-v1` reference and the persona mirror, but it
  lacks: opener variants (`opener.ts`, `plan_debriefs`, lifecycle stamps), `SEASON` / `RECENT` / `BUDGET` /
  `LAST WEEK` / coverage context lines, `SETTING_DEFAULTS` + `coverage_scope` / `weekly_budget_usd` /
  `pantry_items`, `askChoice` details (cap 4), `draftWeek`, `askPantry`, `recordDebrief`, `planWeek`,
  `suggestMeals.ingredientsOnHand`, `swap_ingredient`, `set_pantry`, `pantry_photo`, `rewind` + `plan_snapshot`,
  `Memory.source`, `sessionDates`, pantry-fed `have`, the question-first opener (D-020), and Browse-meals
  (`/vana/browse`, this is app-only — not applicable to the prototype at all).
- **Code:** every file under `supabase/functions/_shared/vana/` vs `../../mealplanning-prototype/server/vana/`.
- **SSOT status:** every family notes the affected rows. **Decision needed:** port, or declare the prototype
  frozen at `contract-v1` and stop mirroring the persona into it.

### D-013 — `findDurations` / `clock` are not exported from the prototype
- **Status:** `open`. The TS timer parser lives inside the cooking-mode route; only the Dart port is testable.
  **Fix:** move to `lib/vana/cooking-timers.ts` and export (the prototype runner then gains the 21 vectors).

### D-014 — Sentence clamp and output cap differ between twins
- **Status:** `open` (part of D-012). Prototype: planning turns clamped to 2 sentences, `MAX_OUTPUT_TOKENS` 400.
  Edge: 8-sentence runaway guard, 700 tokens (Lee, 2026-09-03). `spec/agent/voice.md` records the edge as the
  contract.

### D-015 — Macros function name differs between twins
- **Status:** `open`. Edge back-fills targets from `calculate-daily-macros-v6`; the prototype calls the
  unversioned `calculate-daily-macros`. Same engine today; a deploy-coupled seam (QA pipeline 6b).

### D-016 — `new_plan` declared but unimplemented in the prototype
- **Status:** `open`. In the `UiAction` union since `contract-v1`; the edge implements it (archive + fresh draft).

### D-017 — `plan_meals` removals are hard deletes
- **Status:** `documented`. Both twins delete the row; the sync plan (`plan-tab-v2.md`) wants `is_deleted` so
  offline removals sync. Schema change pending.

### D-018 — Default chat model differs
- **Status:** `open`. Edge default `anthropic/claude-haiku-4-5` (the walkthrough's cost posture); prototype
  default `anthropic/claude-sonnet-4-6`. Env overrides both; the *default* is the contract question.

### D-019 — Slot colours reuse meaning-bound tokens
- **Status:** `documented` pending Q-TK1. breakfast = `orange` (ratified: daily intake accent), lunch =
  `electrolyte-dark` (per-workout fuel), snack = `dragonfruit` (destructive / caution), dinner = an unregistered
  purple. Recorded in `spec/design/tokens.md`; no token change authorised.

---

## New entries (2026-09-03 evening restructure)

### D-020 — Opener reversal: question-first supersedes the 08-31 "frame + three dinners" decision
- **Status:** `resolved (2026-09-03)` — see note. This both records a code change and retracts a claim this
  register used to make (the old D-002/D-009 "already matches §2.1/§2.2" line named the three-dinner opener as
  the matched behaviour; that specific shape no longer exists).
- **Observed:** `persona.ts` `OPENERS.meal_planning` (verified in code, 2026-09-03 evening): the opener writes
  2–3 PRESENTING sentences proving context awareness (salience order: race → holiday → recent session → rest
  week → biggest session → weather, then a LAST WEEK clause when a debrief exists), then calls `askChoice` with
  the question **"What sounds good for dinners this week?"** and 3–4 label-only options (e.g. "Batch-cook
  staples", "Quick weeknights", "Something new", "Use what I have"; free text always allowed). It explicitly
  does **not** call `suggestMeals` or `draftWeek` on the opener turn. Rule 0 ("THE INTERVIEW") then allows at
  most one follow-up before the first `suggestMeals` (dinner) picker, shaped by the athlete's answer.
- **Code:** `supabase/functions/_shared/vana/persona.ts` (`OPENERS.meal_planning`, rule 0). Conformance
  mechanism: `scripts/vana-eval/run.ts` `presenting` check (2–3 sentences, a concrete athlete fact, a `choices`
  part, and `!picker(t)` — the opener may not propose meals) and `scripts/vana-eval/lifecycle.ts` line 60
  (`'opener asks the opening question (choices, no meals yet)'`).
- **SSOT status:** `spec/agent/voice.md` §Opener and `spec/planning/opener-selection.md`'s `plan` variant now
  describe the question-first shape (updated 2026-09-03 evening). The root README's Part A "Where the
  implementation already matches Xuan's intent" bullet — "Proactive contextual opener with week-fact + three
  dinners; no 'how can I help'" — is corrected: the three-dinner presentation is gone, but the underlying claim
  in `spec/intent/` §2.1 ("proactive… never 'how can I help'") and §2.3 ("one question at a time… present a real
  fork with trade-off options") is, if anything, **more directly met** — Xuan's own SCEN-U source opens with a
  question ("Let's plan the week — starting with dinner. What sounds good?"), which this shape now mirrors.
  §2.2 ("confident proposal first") is in tension with a question-first opener; `draftWeek` (Phase 2, "Draft my
  whole week" chip) is the mechanism that still delivers a confident complete-week proposal without an
  interview, so §2.2 is met by a different door than the opener. Filed as `resolved` because it is a clean,
  low-ambiguity call following Xuan's own scenario text — not awaiting her veto the way Q-6/Q-2 are — but see
  the intake ruling request `intake/2026-09-03-opener-question-first-reversal.md` for the parts of this call
  Xuan may still want to weigh in on (whether §2.2's "confident proposal" should also front the *opener*, not
  just the draftWeek door).

### D-021 — Q-7 intro card: built, then removed the same evening
- **Status:** `resolved (2026-09-03)` — tightens D-010, which already recorded this but left the wording loose.
- **Observed (verified in code, 2026-09-03 evening):** `lib/` contains no `vana_intro_card.dart` and no file
  matching `*vana_intro*` anywhere in `lib/` — `find lib -iname "*vana_intro*"` returns nothing. The Phase 5
  intro card (one-time dismissible card, "Vana already did the homework", three example chips) was built earlier
  2026-09-03 and removed later the same evening at Lee's call ("we don't need that block") once the
  question-first opener (D-020) became the first-contact surface — the opener itself now does the "prove what
  Vana knows" work the intro card duplicated.
- **Code:** confirmed absent from `lib/`; `spec/design/surfaces/vana-planning-chat.md` VP-8 (updated 2026-09-03
  evening to remove the intro-card contract) and its Conformance line (removed the stale
  `vana_intro_card_test` reference — no such test file exists in `test/`, confirmed).
- **SSOT status:** Q-7's ⚖️ interim call in `OPEN-QUESTIONS.md` is reversed by this build decision; the ruling
  request Xuan still owes is now "should first contact stay opener-only, or does *some* one-time explainer still
  earn its place" — see `intake/2026-09-03-q7-intro-card-reversal.md`.

---

## Part A — intent vs build (surveyed 2026-09-02; status as of the 2026-09-03/09-04 phases)

### D-001 · Tone (spec §6) — `pending-ruling` (Phase 1 built 2026-09-03, ⚖️ Q-6 interpreted per plan §2; Xuan may veto)
Persona as surveyed 2026-09-02 (`_shared/vana/persona.ts` CORE): "direct, warm, no cheerleading, no
exclamation marks, no emoji… Max TWO short sentences of text per turn." **2026-09-03:** replaced by the
moment-based VOICE contract (PICKING ≤2 · PRESENTING 2–4 · EXPLAINING uncapped · MILESTONE, one
exclamation allowed; emoji ban kept) — see the plan §3.1, recorded at `spec/agent/voice.md`. Remaining gap =
whatever Xuan strikes. Xuan's scenarios and her "playful… emotional partner" persona spec are warm, celebratory,
and explain reasoning at length. This is the single largest divergence between what ships and what Xuan wrote.
Likely resolution shape: moment-dependent verbosity (terse during picking, expansive for why/celebration) — but
that's Q-6, not ours to decide. `pending-ruling` rather than `resolved`: this is a real interpretive call on an
open aesthetic question, not a mechanical fix.

### D-002 · No proactive loop (spec §5) — `resolved (2026-09-03)` — see note
Opener-on-open check-in + debrief loop (`spec/planning/opener-selection.md`); local notifications ship dark per
⚖️ Q-5. No cron, no push, no scheduled check-ins or debriefs previously existed anywhere in the vana functions;
day notes were pull-based (`daynotes.ts`) and never delivered as a message. Xuan's unstructured scenario asked
for scheduled pre-execution check-ins, post-execution debriefs, and learnings applied to the next plan — the
mechanism (opener variants + `recordDebrief` + the `LAST WEEK` context line) now exists and is conformance-
tested (`scripts/vana-eval/lifecycle.ts`). Filed `resolved` because the loop itself is a mechanical build against
an unambiguous spec passage, not an aesthetic call; the *cadence* (opener-only vs push) is still ⚖️ Q-5. See also
D-020 for the specific text of the opener's first turn, which changed again the same evening.

### D-003 · No learning-from-outcomes (spec §5.1) — `resolved (2026-09-03)` — see note
`recordDebrief` → `plan_debriefs` + `source: debrief` memories → the `LAST WEEK` context line → voice rule 1
(the first proposal after a debrief reacts to it: "kept the two you repeated, dropped the salmon that slipped
twice"). Previously `rememberFact`/`recallFacts` existed but no debrief flow captured what worked/skipped and
folded it into the next proposal. Mechanical build against an unambiguous spec passage → `resolved`.

### D-004 · Artifacts stop at the shopping list (spec §4.2–4.3) — `pending-ruling` (partly met 2026-09-03: confirmed-card summary, share sheet, reminder chip; no calendar/email/PDF per ⚖️ Q-3)
Confirm now builds the shopping list (remote-ack, `confirm_meal_plan` RPC), the `ConfirmedCard` "you're set"
summary, an OS share sheet, and a "remind me the night before cook day" chip. No calendar reminders, no
export/share to PDF/email — those stay behind Q-3, which is a real scope-of-integration judgment call Xuan
should confirm, not a mechanical fix, hence `pending-ruling` rather than `resolved`.

### D-005 · No reasoning/education layer (spec §2.6) — `pending-ruling` (Phase 1: clamp removed, EXPLAINING register, training-anchored why-lines; eval-enforced)
The old 2-sentence cap plus "never restate the athlete context" left no room for the per-item "Why:"
explanations and pros/cons option framing that appear in every Xuan artifact (scenarios, demo script, UIUX
brief "Transparent Processing"). Meal tiles now carry a one-line "why" (voice rule 1, eval-enforced), which is
the right instinct but still thinner than what the scenarios spec — whether it needs to go further is a tone
call bundled with Q-6, hence `pending-ruling`.

### D-006 · Refinement options lack trade-offs (spec §2.3, §2.5) — `pending-ruling` (Phase 1: askChoice 2–4 options each with a `detail` trade-off line; ingredient-level swap still `open` → Phase 6.3)
`askChoice` now renders `{label, detail}` rows (cap 4) — Xuan's fork pattern of one-line trade-offs per option.
Meal-level swap exists (`swapMeal`, SwapPicker); ingredient-level swap with recompute (Phase 6.3) is still not
built — `pending-ruling` because whether ingredient-level swap ships v1 is a scope call, not yet Xuan's word.

### D-007 · No deal / seasonal-produce awareness (spec §3.1, §3.4) — `pending-ruling` (2026-09-03: SEASON + BUDGET context lines; grocery deals still `open` — no data source)
Context block now has weather, training, race, holidays, targets, memories, season (static month table) and
budget (if the athlete ever set one) — no seasonal produce *ranking*, no grocery deals. The post-lock
deal-stitching moment (Xuan's "not just ChatGPT" beat) has no data source yet — blocked on a real decision
about whether/how to source grocery pricing, not a code fix, hence `pending-ruling`.

### D-008 · Memory drawer — `resolved (2026-09-03)` — see note
`vana_settings_screen.dart` renders a `MemoryDrawer` with per-memory delete and now `source · date` provenance
(the update plan's Phase 2.4). Mechanical build against an unambiguous spec passage → `resolved`.

### D-009 · No structured wizard door (spec §2.8) — `pending-ruling`, gated on Q-2
Only unstructured chat exists. Xuan authored a full 6-step wizard scenario; whether it ships is Q-2, and Q-2's
⚖️ interim call ("no wizard in v1") is exactly the kind of product-shape call that needs Xuan's word, not ours.

### D-010 · No first-run guided intro — `resolved (2026-09-03)` — see D-021
Superseded by D-021 (fuller detail): a one-time intro card was built under ⚖️ Q-7, then removed the same
evening once the question-first opener (D-020) took over as the first-contact surface. Testing (Test Theme 1)
said no user starts with chat unprompted — the opener is now the answer to that finding, not a separate intro
surface.

## Where the implementation already matches Xuan's intent (no action)
- Weekly collection × servings, never a day grid; batch-cooking sessions derived
  deterministically; coverage-driven "That's my week". (spec §4.1)
- Proactive contextual opener that proves context awareness before anything else; no "how can I help".
  **(spec §2.1 — updated 2026-09-03 evening: the opener now asks a question rather than presenting three
  dinners; see D-020. §2.1's "proactive… never how can I help" claim is unaffected — met either way. §2.2's
  "confident proposal first" is now met by the `draftWeek` door, not the opener itself — see D-020's note.)**
- Confident propose-first flow via `draftWeek`; "Act, don't ask"; picker chips over typing;
  plan-bar/card-scoped steppers and remove. (spec §2.2, §2.4)
- One question at a time, with a real fork carrying trade-off options once a fork exists (`askChoice`
  `{label, detail}`, cap 4). (spec §2.3)
- Thin-LLM/thick-algorithm: meals only from tool results, `checkCombination`
  anti-hallucination, deterministic recomputes, remote-ack confirm. (spec §7.1)
- Minimums framing, no weight talk, ED referral, medical referral. (spec §6.3)
- One confirmed plan per week, drafts per conversation; explicit confirm via
  Review sheet. (spec §2.7)
- Race fueling absent from the planning toolset, per the scope decision. (spec §1.2)

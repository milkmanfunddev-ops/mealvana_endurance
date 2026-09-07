# SSOT — Opener Selection

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** built 2026-09-03 (update plan Phase 3, the relationship loop, `../intent/` §5).
**Code:** `pickOpener(input)` · `pendingDebrief(input)` — `_shared/vana/opener.ts` (pure); `chat.ts` loads the
inputs and stamps `meal_plans.checkin_done_at`; `recordDebrief` stamps `debrief_done_at`. **Edge only** — the
prototype has one scripted opener (D-012).
**Scope:** which first turn a new planning conversation gets — plan · check-in · debrief.
**Consumers:** the first turn of every new **meal_planning** conversation (general conversations have no opener,
`../domain/conversation.md` C-3).

## Definitions

- **current** — the active plan of the anchor week (`getPlan`, confirmed first else newest draft).
- **previous** — the active plan of the week before (`weekStart − 7`).
- **cook date** — `sessionDates(weekStart)` for a session the plan actually uses (some meal carries it).

## Constants

```
CHECKIN_WINDOW   = { today, tomorrow }          # relative to the cook date
DEBRIEF_OPENS    = previous.weekStart + 7  <= today
DEBRIEF_CLOSES   = previous.weekStart + 21 >  today      # opener only; pendingDebrief has no close
```

## The algorithm (precedence top to bottom)

```
if previous.status == confirmed and previous.meals ≠ ∅ and !previous.debriefDoneAt
   and weekStart+7 <= today < weekStart+21                         → { kind: debrief, plan: previous }
if current.status == confirmed and current.meals ≠ ∅ and !current.checkinDoneAt:
   upcoming = sessions used by current, with their dates, where date ∈ {today, tomorrow}, earliest first
   if upcoming                                                       → { kind: checkin, plan, cookDate, session }
→ { kind: plan }
```

Each variant maps to a synthetic first user message (`persona.ts` `OPENERS.meal_planning` · `checkinOpener` ·
`debriefOpener`) that is **never stored**; because of that the context also carries a `DEBRIEF PENDING <planId>`
line on later turns so `recordDebrief` can still land ([`athlete-context.md`](athlete-context.md)). The `plan`
variant's exact wording (2–3 context sentences, then one `askChoice` question — no meals proposed) is
`voice.md`'s to state, not restated here; this file only owns which variant is chosen (D-020).

## Side effects

| Variant | Stamp | When |
|---|---|---|
| checkin | `meal_plans.checkin_done_at = now()` | as the opener is served — so it never repeats even if the athlete says nothing |
| debrief | `meal_plans.debrief_done_at = now()` + a `plan_debriefs` row + ≤ 3 `pattern` memories with `source: debrief` | only when the model calls `recordDebrief` |

## Invariants

1. Debrief beats check-in beats plan (`debrief-wins-over-checkin`).
2. A draft never checks in; an empty confirmed plan never debriefs.
3. The check-in window is exactly today/tomorrow — a missed cook day is never nagged late.
4. The debrief opener stops after 14 days past the week's end; `pendingDebrief` does not (an in-progress
   debrief conversation can still record).
5. Stamps are idempotent guards: once set, the variant is `plan`.

## Deviations

- **D-012** — prototype has no opener variants, no `plan_debriefs`, no stamps.
- **D-020** — the `plan` variant's opener text changed 2026-09-03 evening: question-first (2–3 sentences + one
  `askChoice`), reversing the 2026-08-31 "frame + three dinners" decision. See `voice.md` §Opener.
- The client's local reminders (`PlanReminderService`: 18:00 the evening before cook day; 18:00 the closing Sunday)
  are scheduled from the same `sessionDates` but ship dark (toggle OFF). **⚖️ interim (Lee, 2026-09-03)** — Q-5 open.

## Conformance

Vectors: `vectors/planning/opener-selection.json` (14: 12 `pickOpener`, 2 `pendingDebrief`). Edge 14/14
(2026-09-03). The end-to-end loop (confirm → time-travel → debrief → next opener reacts) is
`scripts/vana-eval/lifecycle.ts` (bills spend; run by hand) — line 60 specifically asserts the `plan` variant's
question-first shape (`'opener asks the opening question (choices, no meals yet)'`, D-020); `run.ts`'s
`presenting` check does the same for every canned planning conversation's opener.

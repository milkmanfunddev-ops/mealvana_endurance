# SSOT — Opener Selection

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.** Built 2026-09-03 (update plan Phase 3,
the relationship loop, `../intent/` §5). **Edge only** — the prototype has one scripted opener (D-12).
**Engine:** `pickOpener(input)` · `pendingDebrief(input)` — `_shared/vana/opener.ts` (pure); `chat.ts` loads the
inputs and stamps `meal_plans.checkin_done_at`; `recordDebrief` stamps `debrief_done_at`.
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
line on later turns so `recordDebrief` can still land ([`athlete-context.md`](athlete-context.md)).

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

- **D-12** — prototype has no opener variants, no `plan_debriefs`, no stamps.
- The client's local reminders (`PlanReminderService`: 18:00 the evening before cook day; 18:00 the closing Sunday)
  are scheduled from the same `sessionDates` but ship dark (toggle OFF) per ⚖️ Q-5.

## Conformance

Vectors: `vectors/planning/opener-selection.json` (14: 12 `pickOpener`, 2 `pendingDebrief`). Edge 14/14
(2026-09-03). The end-to-end loop (confirm → time-travel → debrief → next opener reacts) is
`scripts/vana-eval/lifecycle.ts` (bills spend; run by hand).

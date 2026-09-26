# S04 — swap Thursday's dinner before the long ride

Converted from `S04` in the old corpus (`evals/vana/scenarios/v1.json`, deleted by ticket 06):
task `adjust existing plan`, athlete `dense`, character `well-specified`, seed `existing_plan`.

- **Account:** judging-1 (test persona)
- **Persona:** dense — a veteran in heavy training: six sessions a week, a race on the
  calendar, macro targets, meal votes, saved meals, memories and past debriefs on file.
  Omnivore, batch-cooks, coverage set to dinners and lunches. Needs the dense persona when
  spawned; judging-1 stands in until then (`../accounts.md`).
- **Task:** adjust an existing plan — change a plan already in place.
- **Query character:** well-specified — the athlete names the exact change and the reason.

## Setup

Seed `existing_plan` from the old corpus: the account holds a confirmed plan for the current
week before the conversation opens. Seed it before the Run.

## Goal

Thursday's dinner in the current week's plan is the marathon bolognese, swapped in cleanly,
with the rest of the week untouched.

## Opening turn

Pinned verbatim from the old corpus; the Examiner sends it as the first athlete message and
improvises only after Vana replies.

> Swap Thursday's dinner for the marathon bolognese, I've got the long ride the next morning.

## Required beats

- Thursday's dinner is the marathon bolognese in the plan data by the end of the Run — a real
  write, verifiable in the plan, not just agreed in chat.
- The rest of the week's plan survives the edit: other days unchanged, plan still confirmed.

## Examiner notes

- Watch she connects the swap to the next-morning long ride rather than executing it blind —
  the athlete gave the reason, and a dietitian would use it (the persona's file even says big
  pasta the night before long sessions).
- Quick surgical edit, not a re-plan.

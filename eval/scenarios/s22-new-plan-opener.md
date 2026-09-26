# S22 — the new-plan opener

Converted from `S22` in the old corpus (`evals/vana/scenarios/v1.json`, deleted by ticket 06):
task `plan a week`, athlete `dense`, character `well-specified`, seed `awaiting_debrief`,
`new_plan: true`, and the old corpus pinned an empty first turn — the emptiness is the point.

- **Account:** judging-1 (test persona)
- **Persona:** dense — a veteran in heavy training: six sessions a week, a race on the
  calendar, macro targets, meal votes, saved meals, memories and past debriefs on file.
  Omnivore, batch-cooks, coverage set to dinners and lunches. Needs the dense persona when
  spawned; judging-1 stands in until then (`../accounts.md`).
- **Task:** plan a week — build and confirm a new week's plan, starting from Vana's opener.
- **Query character:** well-specified — the athlete (played by the Examiner) answers directly
  and concretely once asked; the opener has to do the opening.

## Setup

Seed `awaiting_debrief` from the old corpus: last week's plan is confirmed on the account
with its debrief not yet done. Seed it before the Run. The `new_plan` flag says how the
conversation opens: from "New meal plan" on the Plan tab.

## Goal

Vana speaks first with an opener that proves she knows this athlete, and the conversation
proceeds to a new week's plan that is confirmed by the end of the Run.

## Opening turn

None — pinned empty in the old corpus on purpose. The conversation is opened from "New meal
plan" on the Plan tab, and Vana's opener is the first thing said. The Examiner sends no
athlete message until Vana has opened.

## Required beats

- Vana's opener arrives first and is specific to this athlete: one thing only this athlete
  told her, said the way a dietitian who remembers them would — not a greeting, not a
  read-out of data (the Rubric's opener anchors).
- The opener acknowledges that last week exists — the unfinished debrief is on the account,
  and the opener (or the turn straight after it) shows she knows it.
- The conversation reaches a new week's plan, confirmed by the end of the Run.

## Examiner notes

- The old corpus pinned no athlete turn at all: the Examiner's improvisation is the whole
  athlete side. Stay inside the dense persona and answer well-specified — decisive, concrete.
- This Scenario exercises the opener dimension harder than any other in the corpus; weight it
  accordingly when writing the verdict.

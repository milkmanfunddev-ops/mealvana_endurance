# S05 — cut the grain bowl, remember cooking for two

Converted from `S05` in the old corpus (`evals/vana/scenarios/v1.json`, deleted by ticket 06):
task `adjust existing plan`, athlete `offseason`, character `multi-intent`, seed `existing_plan`.

- **Account:** judging-1 (test persona)
- **Persona:** offseason — an athlete off-season until January: base training only, easy rides
  and trail runs, likes trying new recipes outside race prep. Batch-cooks; coverage dinners;
  a past debrief on file. Needs the offseason persona when spawned; judging-1 stands in
  until then (`../accounts.md`).
- **Task:** adjust an existing plan — change a plan already in place.
- **Query character:** multi-intent — two requests in one message; both must land.

## Goal

The grain bowl is gone from this week's plan, the household change (sister staying, cooking
for two) is remembered beyond the conversation, and the plan still holds together.

## Setup

Seed `existing_plan` from the old corpus: the account holds a confirmed plan for the current
week before the conversation opens. Seed it before the Run.

## Opening turn

Pinned verbatim from the old corpus; the Examiner sends it as the first athlete message and
improvises only after Vana replies.

> Take the grain bowl off this week's plan, and remember that my sister's staying with us so I'm cooking for two now.

## Required beats

- The grain bowl is removed from the current week's plan (verifiable in the plan data).
- Cooking for two is written to memory — a lasting fact on the Doll, not an acknowledgement
  that evaporates with the conversation.
- The plan stays coherent after the removal: the gap is handled, the plan is not left broken.

## Examiner notes

- The memory write is the quieter half of the test; check it landed (Rubric dimension 5).
- Off-season context: no race-fuelling pushback is needed for removing a meal.

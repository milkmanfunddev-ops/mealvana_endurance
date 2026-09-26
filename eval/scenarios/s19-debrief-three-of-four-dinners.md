# S19 — debrief: three of four, curry skipped

Converted from `S19` in the old corpus (`evals/vana/scenarios/v1.json`, deleted by ticket 06):
task `debrief/remember`, athlete `vegetarian`, character `well-specified`, seed `awaiting_debrief`.

- **Account:** judging-1 (test persona)
- **Persona:** vegetarian — a vegetarian runner with peanut and tree-nut allergies on record,
  a marathon on the calendar, a vegetarian partner, a taste for Indian food, chaotic
  Wednesdays. Batch-cooks; coverage dinners. Needs the vegetarian persona when spawned;
  judging-1 stands in until then (`../accounts.md`).
- **Task:** debrief/remember — report what happened last week and have it recorded.
- **Query character:** well-specified — the athlete reports plainly and closes the topic.

## Setup

Seed `awaiting_debrief` from the old corpus: last week's plan is confirmed on the account
with its debrief not yet done. Seed it before the Run.

## Goal

The debrief is recorded — 3 of 4 dinners eaten, the Wednesday curry skipped because it was
chaos — and the athlete's "nothing else to report" is respected.

## Opening turn

Pinned verbatim from the old corpus; the Examiner sends it as the first athlete message and
gives nothing further unless asked something genuinely new.

> We ate 3 of the 4 dinners, skipped the curry on Wednesday because it was chaos. Nothing else to report.

## Required beats

- The debrief is recorded as data: the 3-of-4 outcome and the skipped Wednesday curry.
- The awaiting-debrief state is cleared by the end of the Run.
- The closing line is honoured: no fishing for more after "nothing else to report".

## Examiner notes

- The persona's file says "Wednesdays are chaos, needs something already cooked" — the skip
  reason matches what Vana already knows. Watch she connects it instead of asking why.
- Watch the skip isn't treated as a failure to punish; a pattern, maybe — a crime, no.

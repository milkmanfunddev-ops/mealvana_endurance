type: ruling-request
bundle: data-integrations@v1.1 (D-2 manual-wins family · events)

## Why this matters
The 1.27.0 OTA fix makes an event-date edit move its linked ACTIVITY (the fueling unit, and the
date the events list renders), but it deliberately **skips provider-synced and
already-performed activities** — chosen in a hotfix with no ruling behind it
(`ops/docs/deploys/2026-09-data-integration.md` status header, 2026-09-16: "the activity-side
analogue of D-2c is UNRULED and was deliberately not decided in a hotfix"). Until it is ruled,
the shipped behaviour is an accident of urgency and there is no vector pinning it.

## The question
When an athlete edits an event's date, what happens to the linked activity in each of these
cases?
1. Activity is manual / app-created and still planned → (shipped: it moves)
2. Activity carries a provider origin (TP / FS / Garmin) and is still planned → (shipped: skipped)
3. Activity is already performed / verified (has measured data) → (shipped: skipped)
4. Activity was provider-created but the athlete has since edited it (D-2c "edit flips field
   manual + exempts from re-sync overwrite") → **undefined today**

## What is already ruled (the row-level analogue)
`spec/design/surfaces/integrations-data-display.md` D-2c (RULED Xuan, 2026-09-11): event rows
carry one origin (Manual · TP · FS), and an edit flips that field to manual and exempts it from
re-sync overwrite. The open question is whether that same "the athlete's edit wins, and wins
durably" logic extends **across the event→activity link**, where the edited row and the moved
row are different records with different origins.

## Options
1. **Athlete's edit wins across the link: move the linked activity regardless of origin**, and
   mark the moved activity manual/exempt per D-2c so the next sync does not drag it back.
   Matches D-2's manual-wins direction. Cost: a provider-owned row is mutated locally; the next
   provider push may recreate the original day's row (duplicate risk — needs the matcher's view).
2. **Keep the shipped split (planned+manual moves; provider-synced and performed do not)** and
   tell the athlete why — a note on the edit screen, since today it silently half-applies.
3. **Never move the activity; the event's date is the only thing edited**, and the events list
   reads the EVENT date rather than the activity date (the list's date source is itself the
   original bug — `ops/data/bug-reports/2026-09-11-events-list-skips-rows-without-start-time.md`).

## What it gates
- Whether case 4 (provider-created then athlete-edited) has a defined answer at all.
- A D-2c conformance vector for the activity side, including the background-sync path (the
  background-path gap already raised in `intake/2026-09-11-data-integrations-implementation-findings.md`
  item 10).
- 1.28.0 scope: the fix itself is currently MISSING from `mealplanning`
  (`ops/data/bug-reports/2026-09-17-event-date-linked-activity-fix-missing-from-mealplanning.md`),
  so whatever is ruled should land with that merge rather than after it.

## Suggested spec home
`spec/design/surfaces/integrations-data-display.md`, as a D-2c sub-clause on event→activity date
propagation, with the vector family noted above.

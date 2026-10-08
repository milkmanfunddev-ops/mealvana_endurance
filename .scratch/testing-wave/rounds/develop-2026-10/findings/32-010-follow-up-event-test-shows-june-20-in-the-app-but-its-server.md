# 32-010 · Follow-up: event 'Test' shows June 20 in the app but its server row says event_date 2026-07-17 (start_time 2026-06-20)

- kind: followup-test
- status: closed
- ticket: 32
- run: w3-20261008T1256Z
- screen: Events, Event Details
- decision: retest ticket 50 (startup, tabs, learn, connected apps), wave 5

**Steps.**
1. test@test.com, Events: past event "Test" shows JUN 20 2026 / "Saturday, June 20, 2026, Event completed".
2. Read its server row: `event_date 2026-07-17`, `start_time 2026-06-20T08:58:00.000`.
3. Find which column each surface reads (list, detail, carb-loading window, nudges, plan) and whether an
   edit writes both; try editing the date of an event and compare the two columns.

**Expected.**
One date per event, the same on every surface and in both columns.

**Actual.**
Not run (seen at 13:29:52Z during the Connected Apps reads). The row was last written 2026-06-17.

**Evidence.**
- runs/32/db-event-test-row.txt the row
- runs/32/e05-past-event-detail.png the app's date

**Decision quote.**
> 

**Triage.**

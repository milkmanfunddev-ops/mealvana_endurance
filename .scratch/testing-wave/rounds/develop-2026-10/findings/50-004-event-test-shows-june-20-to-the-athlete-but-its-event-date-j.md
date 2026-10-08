# 50-004 · Event 'Test' shows June 20 to the athlete but its event_date (July 17) drives coach views, calendar dots and the carb nudge (retest of 32-010)

- kind: bug
- status: open
- ticket: 50
- run: w5-20261008T1720Z
- screen: Events, Event Details
- decision: 

**Steps.**
1. test@test.com → Events. Past event "Test"; open it.
2. `select id, event_name, event_date, start_time, origin, has_carb_loading, carb_loading_start_date, updated_at
   from events where user_id = '607f9dd5-…' and event_name = 'Test'`.
3. Read which code reads which column (grep `eventDate` / `event_date` in `lib/`).

**Expected.**
One date per event, the same on every surface and in both columns (32-010).

**Actual.**
List: "Test JUN 20 2026" (Past Events). Detail: "Saturday, June 20, 2026 · Event completed", "Carb loading window
has passed". Row: `event_date 2026-07-17`, `start_time 2026-06-20T08:58:00.000`, `origin null`, last written
2026-06-17 08:59. So the two columns still disagree by 27 days.
Which column rules (from code, unverified): the athlete's events list and Event Details use the linked activity's
time, else `start_time` (`calendar_controller.dart:568-627`, `event_header_card.dart`). `event_date` is read by
the calendar day indicators (`calendar_day_indicators_provider.dart:52-54`), the carb-load nudge
(`carb_nudge_coordinator.dart`, `eventDate ?? startTime`), and every coach surface: athlete detail ordering
(`athlete_detail_controller.dart:133`), coach reports' next event (`coach_reports_controller.dart:355-383,
570-593`) and the portal panel (`portal_athlete_detail_panel.dart:354`). A coach looking at this athlete would see
July 17 while the athlete sees June 20; an event in this state 1-3 days out by `event_date` would fire a carb
nudge for a race the athlete's list dates elsewhere. The unique constraint `(user_id, event_date, event_name)`
(`auth_migration_service.dart:284`) also keys on the column the athlete never sees. How the row got this way is
not known (no edit made in this run; the code re-derives `event_date` from `start_time` on create and edit).

**Evidence.**
- runs/50/j01-events.png list: Test JUN 20 2026
- runs/50/j02-event-test-detail.png detail: Saturday, June 20, 2026
- runs/50/db-event-test-row.txt the row

**Decision quote.**
> 

**Triage.**


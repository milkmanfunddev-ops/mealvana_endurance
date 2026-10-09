# 69-005 · Follow-up: Events, unsaved-edit guard, carb-load reminders after delete, imported-event edit then TrainingPeaks sync, swipe delete

- kind: followup-test
- status: triaged
- ticket: 69
- run: w7-20261008T2311Z
- screen: My Events / Event Details / Edit Event
- decision: 

**Steps.**
1. Edit Event with a change, then X or an edge swipe: the form leaves without asking and drops the change (seen this
   run on tw69). Decide whether a discard prompt is wanted; retest whichever is ruled.
2. Create an event 4+ weeks out (it schedules three carb_load local notifications, `notif_scheduled` days 3/2/1), then
   delete it: are the three pending notifications cancelled? (read the pending list or wait for a fast-fire variant).
3. Once 69-004 is fixed: edit only the Location of an imported TrainingPeaks event, then TrainingPeaks Sync Now. Does the
   sync keep the edit, overwrite it, or add a duplicate row? Read `events.origin` before and after (code says it flips
   to manual for good).
4. Delete an event by swiping its My Events row right-to-left (the list's own confirm dialog), and delete one that has
   race-checklist items and a carb-loading plan: are the checklist rows and the plan gone too?
5. Edit an event's start time across midnight (11:30 PM → 12:30 AM): do event_date and start_time stay on one date?

**Expected.**
Each path keeps one row per event with matching event_date and start_time, never leaves reminders or child rows for a
deleted event, and never asks the athlete for data an import did not have.

**Actual.**
Not run (step 1 seen: no prompt, change dropped; steps 2-5 not tried).

**Evidence.**
- runs/69/h01-edit-back-no-prompt.png detail after X with an unsaved Location
- runs/69/h03-checklist-added.png checklist on the event later deleted

**Decision quote.**
> 

**Triage.**
- triaged · retest ticket C (onboarding plan, Events, Learn, Connected Apps; with fix tickets 70 and 52 if a Runna URL lands in CRED), cut after fix wave 8 for test wave 9 · Lee, 2026-10-09

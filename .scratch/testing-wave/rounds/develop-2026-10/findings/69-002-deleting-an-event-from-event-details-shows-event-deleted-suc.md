# 69-002 · Deleting an event from Event Details shows Event deleted successfully but leaves the deleted event's detail on screen

- kind: bug
- status: triaged
- ticket: 69
- run: w7-20261008T2311Z
- screen: Event Details
- decision: 

**Steps.**
1. Signed in as the dev test account, create an event (here "Tw69 2330", Nov 14 2026) and open its Event Details.
2. More options → Delete Event → Delete.

**Expected.**
The event is deleted and the app leaves the detail screen (the code calls `context.go('/main')` right after the
snackbar, `event_detail_screen.dart:312-315`), so the athlete never sees a screen for an event that no longer exists.

**Actual.**
23:31:43Z: the server row was gone at once (hard delete) and the snackbar "Event deleted successfully" showed, but the
screen stayed on the deleted event's Event Details, with its name, date, "5 weeks away", Create Nutrition Plan, Set Up
Carb Loading and Race Day Checklist still live, for at least 25 s until I tapped Back. Back → My Events without the
event. No console line at all for the delete.

**Evidence.**
- runs/69/h05-after-delete.png snackbar over the deleted event's detail, 1 s after Delete
- runs/69/h06-after-delete-2.png same screen ~25 s later
- runs/69/h07-back-after-delete.png My Events after Back: event gone
- runs/69/db-tw69-after-delete.txt server row gone

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 80 (event delete pops to My Events; an imported event saves without a race distance), fix wave 8 · Lee, 2026-10-09

# 03-007 · My Events: with a full list, New Event comes to rest under the floating tab bar

- kind: bug
- status: closed
- ticket: 03
- run: w3-20260923T1942Z
- screen: My Events
- decision: 

**Steps.**
1. Sign in as an account with enough events to fill the screen (the dev admin: one upcoming,
   four past).
2. Open the Events tab and scroll to the end of the list.

**Expected.**
The list scrolls far enough that New Event (the only way to add an event here) clears the
floating tab bar and can be tapped.

**Actual.**
At the end of the list New Event rests behind the floating tab bar: only an orange sliver shows
above the bar (`events_list_screen.dart` ends with `SizedBox(height: AppSpacing.xxxl)`, less than
the bar's height). For Patrol the button was not hit-testable after a plain tap or after
`Scrollable.ensureVisible` centering, so events_crud and event_checklist_carbload failed at their
first step for this account. A `scrollTo` drag reaches it only mid-overscroll; the wave review
made both flows let the list come to rest before tapping, so they stay red until this is fixed
(runs/03/patrol-review-events.log: both fail at the New Event tap, "did not find any visible
(i.e. hit-testable) widgets"). An athlete has to hit the sliver above the bar.

**Evidence.**
- runs/03/my-events-new-event-under-tab-bar.png
- runs/03/patrol-batch7.log and runs/03/patrol-events-diag.log (tap fails after
  waitUntilExists and centering)
- runs/03/patrol-review-events.log (after the review: both flows red at the tap)
- runs/03/device-batch7.log, "did not find any visible (i.e. hit-testable) widgets"

**Decision quote.**
> 

**Triage.**
Fix ticket 52 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 118 when 93 was split (Lee, 2026-09-25).

Run by retest ticket 118 (run w36-20260926T0031Z, build 72d3723e): pass; New Event rests above the tab bar at the end of My Events and takes a tap.

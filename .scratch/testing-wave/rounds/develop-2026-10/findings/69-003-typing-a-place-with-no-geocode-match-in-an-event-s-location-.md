# 69-003 · Typing a place with no geocode match in an event's Location field reports error_reported fault (area location) to Sentry

- kind: bug
- status: triaged
- ticket: 69
- run: w7-20261008T2311Z
- screen: Edit Event
- decision: 

**Steps.**
1. Event Details (any event) → More options → Edit Event.
2. Type a word that is not a place into Location (optional), here "tw69 unsaved".

**Expected.**
No suggestions, or a quiet "no places found". A search that matches nothing is an expected outcome, not a fault: no
`error_reported`, no Sentry error.

**Actual.**
The place search got `NotFoundException (404): No location found: {"error":"Unable to geocode"}`; the console printed a
red `⛔ [location] Error searching locations` box with a stack (LocationRepository.searchLocations:56) and
`📊 [ANALYTICS] error_reported {severity: fault, area: location, exception_type: _Exception, sentry_event_id:
79bf721231fb44d58ebd9fce87a74dac}` (18:30:44 local, 23:30:44Z). Every no-match keystroke batch can do this.

**Evidence.**
- runs/69/console-redacted.log the `[location] Error searching locations` box and the error_reported line at 18:30:44
- runs/69/h01-edit-back-no-prompt.png the screen after leaving the form

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 81 (geocode no-match and camera-denied are expected outcomes with copy that says what to do; process_uptime_ms from the real process start), fix wave 8 · Lee, 2026-10-09

type: ruling-request
bundle: intent@v1

## Why this matters
Determines whether the `PlanReminderService` local-notification toggle ever gets turned on by default, or
whether push notification (OneSignal) gets built as a second channel.

## The question
The proactive loop currently has two touchpoints per plan cycle — the prep-day check-in and the end-of-week
debrief — delivered only as the opener of the next app-open. Local notifications exist
(`PlanReminderService`: 18:00 the evening before cook day; 18:00 the closing Sunday) but ship dark (OFF) by
default. Does the cadence stay opener-only, or does a push channel (OneSignal, currently off) get turned on?

## Options
- **Opener-only (current build).** Zero spam risk — "proactive" never becomes "naggy" because nothing reaches
  the athlete outside the app. Cost: an athlete who doesn't open the app in the check-in/debrief window never
  sees it (the opener stamps `checkin_done_at`/`debrief_done_at` so it doesn't repeat once served, meaning a
  missed window is a missed touchpoint, not a queued one).
- **Turn local notifications on by default.** Same content, delivered as a device notification at the scheduled
  time — reaches athletes who don't open the app on schedule, at the cost of being an actual interruption.
- **Add push (OneSignal) as a third option.** More reach, more infrastructure, more opt-out friction to design.

## Recommendation
Prove the opener-on-open version in dev/TestFlight first (zero-risk, already built); turn local notifications on
only once that's validated, and treat push as a later increment, not a v1 concern.

## Gates
`PlanReminderService` default toggle state; any OneSignal push scheduling work.

## Suggested spec home
`spec/planning/opener-selection.md` §Deviations; `OPEN-QUESTIONS.md` Q-5.

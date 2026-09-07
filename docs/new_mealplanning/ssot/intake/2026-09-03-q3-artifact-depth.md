type: ruling-request
bundle: intent@v1

## Why this matters
Determines whether calendar/email/PDF integration work ever gets scoped, or whether the shopping list + OS
share sheet + local notifications is the permanent artifact ceiling for this feature.

## The question
Xuan's artifacts describe calendar reminders, email, and PDF export as part of the "artifact depth" the
assistant should produce. v1 ships in-app only: the shopping list (exists), an OS share sheet (plain text), and
local notifications for check-ins. Is that the intended ceiling, or does calendar/email/PDF integration belong
on the roadmap?

## Options
- **In-app only (current build).** Shopping list + share sheet + local notifications. ~90% of the felt value
  ("it saved things for me") at a fraction of the integration cost (no OAuth flows, no email deliverability, no
  PDF rendering pipeline).
- **Add calendar integration.** Cook-day reminders as real calendar events, not just local notifications —
  meaningfully stickier, but a real OAuth + sync surface to build and maintain.
- **Add email/PDF export.** Useful for athletes who want to print a shopping list or forward a plan to a
  partner; lower priority than calendar per user research so far.

## Recommendation
Ship in-app only for v1; treat calendar integration as the most likely next increment if athlete feedback asks
for it specifically (rather than building speculatively).

## Gates
Any calendar/email/PDF work; `PlanShareService` scope.

## Suggested spec home
`spec/intent/vana-mealplanning-chatbot.md` §4.2–4.3; `OPEN-QUESTIONS.md` Q-3.

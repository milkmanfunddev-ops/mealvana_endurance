# Description

The simplest possible logging experience: after a workout, the athlete sees their planned nutrition items and taps to confirm, adjust, or skip each one. Unplanned items can be quick-added from the product database.

The goal is to validate whether athletes will actually log — this is the critical assumption the entire feature chain depends on.

## What it delivers

- **Post-workout logging prompt**: triggered after a workout is marked complete (manually or via Garmin sync when available). Timing is key — Andy Grant was definitive that post-workout, not mid-workout, is the right moment
- **Tap-to-confirm UI**: athlete sees their planned items (e.g., "2x Maurten Gel 100, 1x bottle Skratch") and taps each as consumed, skipped, or partial
- **Quick-add for unplanned items**: athlete grabbed something at an aid station or from their kitchen that wasn't in the plan — search the product database and add it with one tap
- **Simple quantity adjustment**: ate 3 gels instead of 2? Tap the number up. Only drank half a bottle? Tap it to partial
- **Optional freeform note**: one text field for anything else ("stomach felt off after hour 2")
- **Per-workout log saved**: data is stored against the specific workout for later review

## Design principles

- Must be completable in under 60 seconds — if it takes longer, athletes won't do it
- Default state is "consumed as planned" — athlete only taps to change things, not to confirm every item
- No login wall or separate app launch required — push notification deep-links straight to the logging screen
- Designed for thumb-zone on mobile — large tap targets, minimal scrolling

## What it doesn't do yet

- No coach visibility (V2)
- No longitudinal tracking or trends (V3)
- No connection to the adaptive algorithm (V3)
- No voice input (future consideration from Food Journaling feature)

## Key risk

Will athletes actually log? Josh & Jen described unreliable self-reporting ("one guy says, I took 4 gels in 3 hours... and I'm like, no, you didn't"). The tap-to-confirm UI is designed to lower the bar, but adoption is the critical metric for V1.

# Comments

(Please feel free to provide comments below)
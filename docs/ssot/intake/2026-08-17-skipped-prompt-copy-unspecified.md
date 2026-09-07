> **RESOLVED 2026-08-17 → Q-D5 RULED (SKIPPED state: past-day only, 'Skipped' chip, fuel not counted, swipe still works), folded into workout-card.md + both design manifests**

type: ruling-request
bundle: daily-macros-dashboard@v1

## Why this matters
The SKIPPED? card state is ratified and golden-manifested, but no document or reference rendering specifies what the "skipped prompt" says or looks like — the shipped app invented provisional copy that will otherwise calcify via its golden.

## The question
What is the SKIPPED? prompt's copy and treatment?

- `spec/design/components/workout-card.md` states: "Planned treatment + skipped prompt (end of day, neither sync nor confirmation)" — the prompt itself is undescribed.
- The reference rendering's dataset never enters this state (its two-workout day has no end-of-day unresolved workout), so there is nothing to port.
- The confirmation rung is ruled engine-side (platform-resolution.md: "no sync" and "didn't happen" are different facts; the athlete is the tiebreaker) — this request is only for the card-level prompt that solicits that tiebreak.

## Current app-side state (provisional, flagged for replacement)
Planned treatment + a hint-row-styled line: "Did this happen? Swipe right to mark done" (icon: help-outline). Golden `workout_card_skipped.png` is blessed with it. Also `[design]`-assumed trigger: state flips to SKIPPED? when the day is past, or after 22:00 on the day itself — the spec's "end of day" is likewise unquantified and could be folded into this ruling.

## Gates
Final copy + treatment → one string/layout change + golden regeneration citing the ruling. If S-6-style copy constraints apply to this prompt, stating so here keeps the string-level checks complete.

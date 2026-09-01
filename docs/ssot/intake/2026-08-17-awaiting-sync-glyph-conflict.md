> **RESOLVED 2026-08-17 → Q-D4 RULED (no glyph — sync upgrade to verified is the signal), workout-card.md folded + goldens manifest note corrected**

type: ruling-request
bundle: daily-macros-dashboard@v1

## Why this matters
Two ratified design artifacts disagree about the DONE_CONFIRMED workout card; the blessed golden currently encodes one side of the conflict and will pin it permanently.

## The question
Does the DONE_CONFIRMED card carry an "awaiting-sync" glyph?

- `conformance/design/macro-dashboard.goldens.yaml`, row `workout_card_done_confirmed`, notes: *"solid, 'self-reported' chip, **awaiting-sync glyph**"*.
- `spec/design/components/workout-card.md` states only "Solid fill, solid border" + `self-reported` chip — no glyph.
- The reference rendering (prototype @ aa81d21) has an `awaitingSync` flag that is **always false** — no glyph renders anywhere.

## Current app-side state
Shipped WITHOUT the glyph (component spec + reference rendering agree; the manifest note is the outlier). The golden `workout_card_done_confirmed.png` is blessed glyph-less. Per the regeneration rule, adding the glyph later requires a spec change first — this ruling is that change (or confirms the manifest note as the erratum).

## Options
1. No glyph — amend the goldens manifest note (then this is a one-line manifest erratum, nothing app-side moves).
2. Glyph ratified — specify it in workout-card.md (what it looks like, where it sits), app adds it, golden regenerates citing the ruling.

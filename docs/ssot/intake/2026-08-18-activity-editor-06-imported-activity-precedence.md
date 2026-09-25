type: ruling-request
bundle:

## Why this matters
Garmin/Runna imports arrive with observed distance/duration (and sometimes avg speed); the editor currently treats them like hand-typed values and the import path writes fields independently (see item 04). Which value is "held" for an imported workout is a policy call, and it also decides whether a completed activity is editable here at all.

## The question (R6)
For an activity that arrived by import: on open, which quantity is held and which derived; do items 01–03 apply once the athlete edits; and is a *completed* (actual) activity editable in this screen?

## Options
1. **Imported distance + duration are held on load (they are observed), speed/pace derived; once the athlete edits any field, items 01–03 apply. Completed activities are read-only here (recommended).**
2. Treat imported exactly like hand-built (item 01 default applies on load) — re-derives duration from a baseline and discards the observed one.
3. Imported fields locked entirely; editing forces a "detach from import" step. Safest, heaviest.

## What is already ruled (and what isn't)
- `spec/daily-macros/platform-resolution.md` rules Garmin *body-comp* propagation (raw, latest-wins vs manual timestamps) — a precedent for "observed beats derived", not a ruling on activity fields.

## Suggested spec home
`spec/activity/editor-inputs.md` §imported activities; cross-reference `platform-resolution.md`.

## Gates
Design state E (imported workout) in the ops brief; the Garmin avg-speed bug's fix scope; item 04.

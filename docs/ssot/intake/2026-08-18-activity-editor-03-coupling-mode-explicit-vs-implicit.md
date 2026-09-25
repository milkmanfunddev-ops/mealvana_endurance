type: ruling-request
bundle:

## Why this matters
This is the ruling that decides whether the By Duration / By Speed toggle survives. Lee: "I know you like the by duration / by speed, but this is confusing… we can even remove that toggle and have both there." Xuan: "nothing is set in stone." A designer cannot settle it; it is an interaction-model contract the controllers implement.

## The question (R3)
Is the held/derived choice **explicit state** the athlete sets (a toggle), or **implicit** (the last-edited field is held, the third is derived), and are all three quantities always visible?

## Options
1. **Implicit — last-edited wins; distance, duration, speed/pace all visible; the derived one is marked as estimated (recommended).** Reconciles Lee (both visible, no hidden mode) with Xuan (item 01 default). Toggle retired.
2. **Explicit toggle kept, relabelled by intent ("I know my time" / "I know my pace"), both values still visible.** Keeps a mode but makes it legible; candidate for a comprehension A/B against option 1.
3. **As built** — hidden mode, one secondary field. Rejected by both parties in the meeting.

## What is already ruled (and what isn't)
- Nothing. The toggle was the output of an earlier design round that could not be retrieved in the meeting; no Notion record exists (checked 2026-08-18).

## Suggested spec home
`spec/activity/editor-inputs.md` §interaction model; the visual treatment (marker, chip, layout) goes to `spec/design/surfaces/activity-editor.md` after mockups.

## Gates
The Claude Design iteration cannot start honestly until this is ruled; item 01.

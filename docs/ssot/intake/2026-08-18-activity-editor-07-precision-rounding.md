type: ruling-request
bundle:

## Why this matters
Every golden vector for items 01–06 needs a stated precision, and item 04's "reconcile within tolerance" needs the tolerance. Today: cycling duration is floored to the minute from `distance/speed`; running to minute+second from `distance × pace`; speed to whatever the double holds; the plan header shows one decimal on distance and mm:ss pace.

## The question (R7)
Display and storage precision for distance, duration, speed and pace per sport; the reconciliation tolerance for item 04; and which field absorbs the rounding residual.

## Options
1. **Distance 0.1 unit · duration to the minute (stored) with mm:ss on display for pace-based sports · speed 0.1 mph · pace to the second; tolerance = one display unit of the derived field; the derived field absorbs the residual (recommended).**
2. Store seconds for duration everywhere (finer; migration of `durationMinutes`).
3. Leave unstated (status quo) — vectors then pin incidental double behavior.

## What is already ruled (and what isn't)
- Nothing for the editor. Engine specs state their own output precision only.

## Suggested spec home
`spec/activity/editor-inputs.md` §precision; referenced by the vector family.

## Gates
Golden vectors for items 01–06; item 04's tolerance.

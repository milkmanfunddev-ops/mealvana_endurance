type: ruling-request
bundle: daily-macros-dashboard@v2

## Why this matters
Under the shipped @v2 implementation, an athlete who skips a planned 5:30 PM run and then runs at 3:00 PM gets a SECOND, verified card next to the skipped one instead of the skipped card upgrading — spec-conformant today, but a likely user-visible surprise the moment Garmin completions flow. Fix scope waits on this ruling.

## The question
When a platform sync arrives for an athlete who has a `status = 'skipped'` row that day, which match window decides "this measured session IS the skipped one" (→ upgrade to DONE_VERIFIED, clear the skip) versus "this is a different session" (→ import as a new activity, skip stands)?

## What is already ruled
- `spec/daily-macros/platform-resolution.md`, "SKIPPED — the athlete's 'didn't happen'" (2026-08-17): sync beats skip; the matcher must not filter skipped rows; the match key is "the same match key as above" — i.e. the tombstone key: **platform id, else same platform + same sport + start ±15 min**.
- The PLANNED completion matcher (`app/supabase/functions/_shared/garmin/activity_completion.ts` `findMatchingPlannedActivity`) has always used a **day-wide** window for same-sport planned/draft rows (a 5:30 PM plan done at 3:00 PM still completes) — an app-side convention that predates the register and was never ruled on.
- Implemented @v2 (app `28159f54`): skipped rows match under the ruled ±15 min key, tried before the day-wide planned window. Deno tests pin the tier order and the key.

## Options
1. **Keep the ruled ±15 min key for skipped rows (status quo).** Consistent with the tombstone rationale (a genuine second session must survive). Cost: the "skipped it, then did it at a different time" case yields two cards.
2. **Day-wide window for skipped rows, same as planned.** Treats a skip as "still on the day's plan, just declared not-happening" — a same-sport session that day upgrades it. Cost: a genuinely different same-sport session that day (e.g. a second easy run) silently un-skips the wrong row.
3. **Day-wide for the first same-sport session, ±15 min for any further ones** — heuristics; needs its own rule text.

## Recommendation
None strong. This is exactly the kind of question the planned integration-sync SSOT pass should settle in one place, alongside the un-ruled day-wide planned window (they should probably be ruled together, not one at a time). Until then option 1 stands (it is what the ruled text says).

## Suggested spec home
`spec/daily-macros/platform-resolution.md`, the match-key ruling — extend it to name the window per row status (deleted / skipped / planned), or fold into the integration-sync SSOT when it exists.

## Gates
Possible one-line change in `findMatchingSkippedActivity` (window) + a Deno test update; a gestures-manifest `g6_sync_beats_skip` wording tweak if the key changes.

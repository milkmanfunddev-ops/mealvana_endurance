type: ruling-request
bundle: daily-macros-dashboard@v2

## Why this matters
TrainingPeaks can mark a planned workout `skipped` on its side; the app has always imported that as `ActivityStatus.skipped` (`app/lib/features/activities/data/activity_mapper.dart` L603; `vdot_transformer.dart` L147 drops TP-`skipped` entirely). Under @v2 that row now renders as an ACTIVELY skipped card (Unskip available) and stops counting toward macros — behaviour nobody ruled on. Low frequency, but a platform-declared skip and an athlete-declared skip are being conflated.

## The question
Is a platform-declared skip (TP `skipped`) the same fact as the athlete's Skip press?
- Should the athlete be able to **Unskip** it (and does that mean anything to TP)?
- Should the next TP re-sync (which preserves local `status` — `_mergeProviderUpdate`) be able to un-skip / re-skip it?
- Does it count as "the athlete's 'didn't happen'" for the fuel ladder, or as platform data with its own provenance chip?

## What is already ruled
- `spec/daily-macros/platform-resolution.md` SKIPPED addition (2026-08-17): `skipped` is "the athlete's 'didn't happen'"; written by Skip, cleared by Unskip / mark-done, overridden by any matching sync. Silent on platform-declared skips.
- App-side default shipped @v2 (per the handoff watchlist item 2): treat as an active skip — the athlete is the tiebreaker (Unskip available, zero contribution).

## Options
1. **Same fact (status quo).** Simplest; athlete can Unskip. Cost: a TP re-sync never re-asserts the skip; TP is not told about the Unskip.
2. **Distinct provenance:** keep `status='skipped'` but chip it "skipped · TrainingPeaks"; Unskip allowed; a TP re-sync that still says skipped re-applies it. Needs a `skip_source` (or reuse of `synced_from_provider` + a rule).
3. **Drop platform skips on import** (as `vdot_transformer.dart` already does for VDOT) — never render, never count. Loses information the coach put in TP.

## Recommendation
Option 1 until the integration-sync SSOT pass, which should own the whole "platform status ↔ local status" table (planned/completed/skipped per provider, re-sync precedence). Raise together with `2026-08-18-skipped-row-sync-match-window.md`.

## Suggested spec home
The integration-sync SSOT (when cut); interim: a one-line addition under the SKIPPED paragraph of `platform-resolution.md`.

## Gates
Possibly a mapper/transformer change + a chip variant; nothing in the current manifests.

> **RESOLVED 2026-08-17 → Q-016 RULED (today + future cached days; past days are history), folded into platform-resolution.md**

type: ruling-request
bundle: daily-macros-dashboard@v1

## Why this matters
The app-side fix for a Major bug (dashboard keeps stale targets after a settings change — `app repo ../ops/data/bug-reports/2026-08-17-profile-save-macro-cache-stale.md`) is one line, but WHICH cached days recalculate is a policy call only the spec owner can make; the wrong choice silently rewrites nutrition history.

## The question
When an athlete **manually** edits an engine input in Settings (weight, height, body fat, lifestyle, typical weekly hours, carb-cycle opt-in, training phase), which cached daily plans are invalidated and recalculated with the new values?

## Options
1. **Today + future cached days only (recommended).** Past days remain the historical record of what the athlete was told to eat. Consistent in spirit with the "today is for today" ruling (platform-resolution.md F27) and with treating delivered plans as history.
2. **All cached days.** Simplest; matches the engine-version-bump behavior — but recalculating past days with a new weight retroactively flips "you hit your target" verdicts.
3. **Today only.** Minimal blast radius, but future cached days keep stale targets until something else invalidates them.

## What is already ruled (and what isn't)
- The **Garmin** body-comp path: raw propagation, latest-wins vs manual timestamps (`spec/daily-macros/platform-resolution.md`, "Athlete profile auto-update").
- The **activity-change** invalidation window, app-side: the activity's Mon–Sun week ± a day (`app/lib/features/daily_macros/domain/macro_cache_invalidation.dart`).
- The **manual** input-change case: specified nowhere. Settings is merely the surface; the policy should be surface-independent (any MANUAL profile write).

## Suggested spec home
`spec/daily-macros/platform-resolution.md`, extending "Athlete profile auto-update" to cover profile-input changes from ANY source: Garmin rung already ruled; add the MANUAL rung (which days recalculate). The app owns the mechanism (cache invalidation); the spec owns the policy; the feature test plan gains a chain row pinning it.

## Gates
The one-line app fix in `nutrition_profile_screen.dart` (call `invalidateDates` with the ruled window + invalidate the daily-macros controller), and a behavioral test for the chain.

# Ticket 32 expected records (written before the run)

Run: w3-20261008T1256Z. App build a89ace2a (dev flavour, com.milkman.mealvanaendurance.dev).

## RevenueCat
No RevenueCat read or write in this ticket: none of its checks names one.

## Dev database (vlmtsdzpnjnavdgytcmi), read only
- `events` rows for test@test.com: count before step 7 == count after step 7 (the swipe is cancelled at
  its confirm; New Event is backed out of).
- No other row written by this run on test@test.com before the Connected Apps section.
- Connected Apps section (last, named writes, Lee 2026-10-07): `integrations` for the account, columns
  `provider, status, requires_reauth, last_sync_at, last_sync_status, last_sync_error` only:
  - before: V.O2 and TrainingPeaks rows present with dead tokens (requires_reauth or failing syncs);
  - after: no V.O2 row (or status disconnected); TrainingPeaks row live (`status` connected/active,
    `requires_reauth` false, `last_sync_at` inside the run window after Sync Now);
  - a relaunch afterwards logs no refresh failure for TrainingPeaks or V.O2.

## Routes that must now be unknown (tickets 26 and 27): Page Not Found, Go Home -> Timeline
/pro, /settings/sport-settings, /settings/food-preferences-consolidated,
/settings/food-preferences/add-food, /meal-log/manual, /meal-log/photo, /meal-log/describe,
/meal-log/recent-saved, /meal-log/recipe, /jade

## Routes that must still work signed in
/athlete/feedback (renders), /buy-credits (renders or redirects as ticket 23 left it),
Settings -> Food Preferences (opens, Back works), every tab of the Log a meal sheet.

## Console lines that must not appear
- A launch-trail dialog (`Launch trail` AlertDialog) on a launch or resume without a notification
  (ticket 28, 08-007); never more than one per process (01-011).
- `error_reported ... SlowOperation` for `deferred.notifications` covering the time the iOS
  permission prompt was up (ticket 22, 08-009). Expected instead: a `permission prompt wait <ms>ms`
  trail line and a breadcrumb with `user_wait_ms`.

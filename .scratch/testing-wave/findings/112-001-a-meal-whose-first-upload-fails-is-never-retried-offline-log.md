# 112-001 · A meal whose first upload fails is never retried: offline logs stay on the phone after the network returns

- kind: bug
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal → quick log sheet
- decision: 

**Steps.**
1. Retest of 26-009 step 4 and 09-005 step 3. Signed in as test@test.com; app relaunched offline with `netcut.sh on SCRATCH --relaunch UDID` (23:39:02Z).
2. Log a Meal → Common → "Apple + cheese" → Log it (23:39:31Z). Recent → "Greek yogurt + honey" → Log it (23:39:55Z).
3. `netcut.sh off` (23:40:27Z). Leave the app on the timeline 2 min; pull the timeline down (23:42:38Z); open Log a Meal again (23:42:50Z).
4. Read dev `meal_logs` for the two ids the console names (330dab98…, 33bee368…).
5. Same thing online: Recipes → "Red Lentil & Vegetable Soup", 2 servings, leave the sheet open 2 min, Log it (23:32:33Z). The immediate insert timed out after 31 s (errno 60) and the log (b426390d…) stayed dirty.

**Expected.**
Offline-first (CLAUDE.md): the meal shows at once and uploads when the network returns, or at the latest the next time the athlete pulls or reopens Log a Meal.

**Actual.**
Both offline meals showed at once ("Meal logged!", first in Recent, counted in the day's Eaten 4,632). Neither reached the server: no row at 23:40:47, 23:41:07 … 23:42:30Z, after the pull, after reopening Log a Meal, or at the last read before step 9 (see notes.md). The soup logged online at 23:32:33Z was not uploaded either, through two relaunches (23:37:59Z and 23:39:02Z) and ~15 minutes online. Reading the code: `MealLogRepository` logs "Immediate insert upload failed; log stays dirty for retry", but `SyncCoordinator.ensureSynced` skips while the data is fresh (<1 h since the last sync) and only marks `_uploadRetryOwed` when its own upload fails, so a failed immediate insert waits up to an hour. If the athlete signs out or the phone is wiped in that hour, the meal is gone.

**Evidence.**
- runs/112/console-meal-uploads.txt (18:33:05 errno 60 for b426390d; 18:39:31 and 18:39:55 errno 51 for 330dab98, 33bee368)
- runs/112/db-run-rows.txt ("Local-only rows": no rows for the three ids)
- runs/112/54-offline-apple-after-log-1s.png
- runs/112/57-offline-recent-relog-1s.png
- runs/112/60-offline-balance-details.png
- runs/112/41-timeline-after-soup.png
- runs/112/notes.md

**Decision quote.**
> 

**Triage.**

Fix ticket 135, Meal upload and quick logging (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.

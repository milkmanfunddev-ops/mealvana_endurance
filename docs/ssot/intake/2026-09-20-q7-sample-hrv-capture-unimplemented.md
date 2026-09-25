type: ruling-request
bundle: real-payload-corpus@v1.1 (L-7 item 3, RULED — implementation gap) → next bundle or expedite

## Why this matters
Xuan asked "was in-workout HR / HRV recorded with this bundle?" — the answer is NO, and no
gate could have said so: the ruled item had a handback checkbox but no test-plan row, no
vector, and no expected_flow, so both landings went green around it.

## The gap, verified 2026-09-20
- **Per-second workout samples (HR/pace/power curves): recorded NOWHERE.** garmin-push still
  persists `detail.summary` only; `activity_detail_full` appears in the sweep's TTL list
  (forward-looking) but NOTHING writes it — zero rows in dev; garmin-push untouched by both
  landings. Even the 2026-09-14 dev/self capture (owner-consented) was never built.
- **HRV: handler exists, subscription doesn't.** The @v1 unhandled-push-types capture maps
  `hrv`, but we do not subscribe to Garmin's HRV summaries, so nothing ever arrives.
- The ruled contract (L-7 item 3, interview Q7): sample-level + HRV capture graduates to
  PROD under the 90-day TTL, size-guarded (watchlist W7: today's guard is a comment).

## The question
Expedite as a small bundle now, or ride the next bundle (producer-shapes re-authoring etc.)?
Either way the work is: garmin-push writes full `activityDetails` (samples) size-guarded for
all prod athletes + enables/handles the Garmin HRV subscription (portal change + verify),
DI-25 test-plan row, and expected_flows seeds ("activity_detail_full ≥1/48h given an active
Garmin athlete"; "hrv ≥1/week once subscribed") so the liveness meter pins it permanently.

## The process lesson (recommend folding into apply-ruling/land-bundle discipline)
A ruled build-item with no pinned row/vector/flow is invisible to every gate — the same
class as DI-13c's null-indistinguishability, one level up. Proposed rule: a handback item
is not "carried" unless something red exists that turns green when it ships.

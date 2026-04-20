# Write Consistency Policy

## Purpose
Define when Mealvana should use offline-first local writes vs server-acknowledged writes, so coach and athlete flows are predictable and consistent.

## Philosophy
- Preserve offline-first behavior for athlete self-service flows.
- Require server acknowledgment for coach-on-athlete writes when the next UI reads remote state.
- Treat consistency as a product contract, not a per-screen patch.

## Decision Rule
For any write action, choose consistency mode by actor + ownership + immediate read pattern:

1. `offline_first`: actor writes their own data and offline resilience is a priority.
2. `remote_ack_required`: actor writes another user's data, and immediate cross-user visibility is required.

## Where `remote_ack_required` Applies
- Activities (coach creates/edits athlete activity or nutrition plan)
- Events (coach creates/edits athlete event)
- Carb loading plans and carb loading days (coach edits athlete plan/day)
- Coach-managed athlete nutrition/profile targets
- Any cross-user state that is read from Supabase immediately after save

## Where `offline_first` Stays
- Athlete editing their own activities, events, and nutrition flows
- Athlete-side data capture while on unreliable networks
- Non-critical local updates that can sync later without UX ambiguity

## Architecture Contract
- Add an explicit consistency mode to service-layer writes (for example: `WriteConsistency.offlineFirst` and `WriteConsistency.remoteAckRequired`).
- Keep policy decisions in application/services, not in screens/controllers.
- Success toasts/navigation must occur only after the required consistency contract is satisfied.
- For `remote_ack_required`, fail fast with retry UI when remote write fails.

## Rollout Plan

### Phase 1: Shared Contract
- Introduce shared `WriteConsistency` type in a common domain/service location.
- Add service APIs that accept consistency mode for create/update/delete operations.
- Add structured logging/analytics fields: `entity`, `actor_user_id`, `owner_user_id`, `consistency_mode`, `remote_ack_latency_ms`, `remote_ack_success`.

### Phase 2: Activities + Nutrition Plan (Highest Priority)
- Route coach-on-athlete activity/nutrition writes through `remote_ack_required`.
- Remove screen-level direct repository workarounds once service contract handles consistency.
- Ensure navigation back to coach detail/portal happens only after remote ack.

### Phase 3: Events + Carb Loading
- Apply same contract to event writes and carb loading plan/day writes in coach mode.
- Normalize all coach portal save flows to a single save-and-ack pattern.

### Phase 4: Remaining Coach-Owned Domains
- Apply policy to coach editing athlete profile/targets and other cross-user entities.
- Audit all cross-user write paths with a checklist and close remaining gaps.

## Verification Plan
- Unit tests for consistency mode selection based on actor/owner IDs.
- Service tests asserting remote ack gating for coach-on-athlete writes.
- Integration tests for end-to-end coach flows:
  - save succeeds and next screen shows updated state
  - remote failure blocks navigation and shows retry path
- Regression tests confirming athlete self-service remains offline-first.

## Definition of Done
- No screen/controller decides consistency behavior ad hoc.
- Cross-user coach writes use `remote_ack_required` by default.
- Athlete self writes remain offline-first by default.
- All high-priority entities (activities, events, carb loading) follow the policy.
- Documentation and onboarding references point to this policy.

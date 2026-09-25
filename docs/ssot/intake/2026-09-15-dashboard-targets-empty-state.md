type: ruling-request + design
driver: usability / observability
area: macro dashboard — app `lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart` (energy-card gate ~L100), `lib/features/daily_macros/presentation/providers/daily_macros_controller.dart` (DailyMacrosState.calculationError / isCalculating, background recompute ~L189-245), `lib/features/daily_macros/data/daily_macro_targets_repository.dart` (algorithm-version floor)
reporter: Claude (with Xuan)
found: 2026-09-15 (1.27.0 TestFlight)

# Dashboard fuel-targets empty state — design the "no targets yet" surface + instrument it

## Why this exists
The dashboard's energy / macro-summary card is shown **iff `targets != null`**
(`macro_dashboard_screen.dart` ~L100: `if (view.trackingOn && data.energy != null)`).
When targets are null the card is **silently hidden** — no copy, no affordance —
so the surface reads as "disabled / broken" with nothing telling the user (or us)
why. There are three distinct reasons targets can be null, and today all three
collapse into the same blank:

1. **Calculating (transient).** 1.27.0 raised the daily-macros algorithm floor to
   `v6.1.0` (F4a). Prod only began emitting v6.1.0 after the 2026-09-14 P2 deploy,
   so on first open of 1.27.0 a stale cached `v6.0.0` "today" row is rejected →
   the controller reads a miss → a single background edge recompute for the week
   fires and, on success, `invalidateSelf()` repaints with targets. Window is one
   round trip (server compute sub-second; ~1-3s end-to-end on a normal connection),
   **once per install**. Self-heals. (Observed: Xuan, 07:07 screenshot showed the
   blank; the week recomputed to v6.1.0 at 07:30; reinstall confirmed self-heal.)

2. **Missing input (NOT transient).** If the profile is missing weight / height /
   birthday, the edge function rejects and `DailyMacrosState.calculationError` is
   populated (`daily_macro_service.dart` ~L60-66: "Your weight is missing. Set it
   in Settings → Preferences → Profile."). The controller **does not retry**
   (`daily_macros_controller.dart` ~L237, to avoid an infinite loop), so the card
   stays blank **indefinitely** with no prompt. The `calculationError` field's own
   doc says the UI should "surface this instead of a generic empty state" — but the
   energy card ignores it.

3. **Hard failure (NOT transient).** Edge/network error, retry exhausted → blank,
   no feedback, no signal to us.

**The core risk Xuan flagged:** cases 2 and 3 let the app *break silently* — the
user sees a dead dashboard and we have no telemetry that it happened. This intake
is to (a) DESIGN the state properly (not rushed) and (b) INSTRUMENT it so we know
when users hit it.

## Design asks (ratify with Kyle)
Design the EnergySummaryCard slot's non-empty-but-no-targets states. It must sit in
the card's existing footprint (no layout jump) and must NOT reuse the red whole-day
error surface (`macro_dashboard_screen.dart` ~L1323). Proposed three states — copy,
visual, and affordances to be ratified:

- **A. Calculating** — calm loading affordance (skeleton of the card, or the
  existing electrolyte spinner) + label e.g. "Calculating your fuel targets…". Reads
  as "working," bounded to the transient. Q: skeleton vs spinner? show only after a
  short delay (avoid a flash for a <1s heal)?
- **B. Missing input** — actionable nudge surfacing `calculationError`, e.g.
  "Add your weight to see fuel targets ›" → deep-links to Settings → Profile. Not an
  error style. Q: one generic nudge vs field-specific copy? which fields gate?
- **C. Hard failure** — retry affordance ("Couldn't calculate — try again") distinct
  from B. Q: is C worth a separate state or fold into a generic retry?

Also decide: should tracking-off still hide everything (today `view.trackingOn`
gates first), and how these states interact with the tracking toggle.

## Observability asks (so silent breakage is visible)
Instrument analytics (Mixpanel, via the existing events pipeline) so we can see the
population and duration of the null-targets state:
- Event when the dashboard renders with `targets == null`, with a `reason` property:
  `calculating | missing_input | failure`, plus `missing_fields` (for B) and the
  `algorithm_version` of any rejected cached row (for case 1).
- Event/measure when the transient RESOLVES (recompute landed) with elapsed time —
  so we can tell "healthy transient" from "stuck." Alert threshold TBD (e.g., users
  stuck in `missing_input`/`failure` > N minutes, or `calculating` not resolving).
- Confirm these fire in prod (the current dashboard golden/widget tests inject mock
  targets in the dev env, so none exercises the null-targets path — see below).

## Test-gap note
`test/features/macro_dashboard/macro_dashboard_screen_test.dart` (11/11 pass) and the
goldens inject non-null targets and run in the dev environment; the Patrol
`macro_dashboard_flow` runs against dev Supabase where targets compute. So no
existing test covers `targets == null`. Whatever states A/B/C are ratified should get
widget coverage (pump the screen with each DailyMacrosState variant).

## Explicitly NOT this intake
The floor-bump transient itself is expected one-time behavior and needs no code
change beyond the state surface + telemetry. Not changing the algorithm-version floor
or the no-retry guard.

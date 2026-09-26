type: ruling-request
bundle: (cross-cutting — session pricing producers · engine⇄spec conformance scope)

## Why this matters
A second, server-side producer of the daily-macros payload has appeared on the unreleased
`mealplanning` branch, and it is a hand-port of the app's session builder that predates four
ratified fixes. It writes the SAME `daily_macro_targets` cache the dashboard reads, with the
service role — so it can silently restore already-fixed wrong numbers, and nothing in the
conformance layer covers it. Defect detail:
`ops/data/bug-reports/2026-09-17-vana-week-targets-double-count-archived-brick-legs.md`.

Note (Xuan, 2026-09-17): the Vana AI agent is **not shipping in the next version** and stays on the
dev branch. So this is not a release blocker — but it is unresolved before Vana ever ships, and the
fill runs on every Vana turn once it does.

## The question
Is a server-side producer of the engine payload (here: Vana's `ensureWeekTargets`) allowed at
all, and if so, what must hold for it — must it be conformance-tested against the same
producer⇄consumer vectors as the app's `DailyMacroService`, or must the payload build live in
exactly one place both callers share?

## Facts
- `app/supabase/functions/_shared/vana/macros.ts` (`ensureWeekTargets`, introduced `f64bec32`)
  fills missing `daily_macro_targets` days by calling the deployed
  `calculate-daily-macros-v6` with its own `sessionFromActivity` port. Its own doc comment
  states the intent: "App parity: `_sessionFromActivityRow`".
- Where the port has drifted from the app today:
  - no `status` filter (`:65` selects on `deleted_at` only) ⇒ archived brick legs and skipped
    rows are priced again — the double-count fixed app-side by `5175a843`;
  - anything not cycling/swimming/other ⇒ `'running'` for the whole duration ⇒ a brick priced
    as one run, not per leg (app: `brick_session_legs.dart`);
  - `other` ⇒ `'strength'` hardcoded (`:27`), against the F4a ruling's treatment of an unknown
    `other`;
  - flat 60 min (30 for `other`) duration fallback (`:24`) where the app resolves via
    `SessionInputResolver` (`d8c08558`) — see also
    `intake/2026-09-17-measured-near-zero-duration-session-pricing.md`;
  - invents `height_feet ?? 6` and `age 35` where the app stopped inventing body metrics
    (`6fdc26b5`, `1efac08f`).
- Nothing tests it: `app/supabase/functions/tests/vana/support/vana_ctx.ts:34` stubs
  `ensureWeekTargets` out.
- The app side of this seam IS pinned — `test/contracts/session_pricing_producer_consumer_test.dart`
  (the I4 "no surface disagrees" invariant).

## Options
1. **One payload builder, shared.** The server fill must call the same code path/contract the
   app uses (extract it, or have the fill request the app-side shape) — no second port allowed.
   Strongest guarantee; costs refactor work inside the 1.28.0 branch.
2. **Second producer allowed, but conformance-gated:** any producer of the engine payload must
   pass the producer⇄consumer vectors, and the bundle's `done_when` must list it. Cheaper now;
   keeps two implementations that can drift between gates.
3. **Server fill is out of the contract's scope** (it only caches what the engine returns, so
   the engine's own vectors are deemed sufficient). Then the drifts above are ordinary app bugs
   and the I4 invariant explicitly does not reach server-side callers — worth saying out loud
   if that is the intent.

## Recommendation
Option 1 for the status filter and brick legs (they are data-selection rules, not pricing math,
and duplicating them is how this class of bug recurs), with option 2's gate as the durable rule
for anything that must stay separate. Either way this should be settled before 1.28.0 ships,
since the fill is enabled on every Vana turn.

## Suggested spec home
The conformance/scope section that defines the producer⇄consumer invariant (I4 in
`app/docs/feature-test-plans/…` and its QA counterpart) — naming which callers are producers of
the engine payload, plus a `done_when` line for the 1.28.0 bundle.

# Ticket 03, run w3-20260923T1942Z: expected

Written before the app was touched. Dev project `vlmtsdzpnjnavdgytcmi` only.

This ticket runs the Patrol suite; it names no RevenueCat or database records of its own. Each
flow's own assertions are its expected records (several read rows back through PostgREST with
`SupabaseProbe`). What the run is judged against:

- Each flow in `integration_test/` and `integration_test/flows/` runs once on one pool simulator,
  dev flavor, signed in as the integration-test account (`secrets/integration_test.env`).
- A flow passes, or fails. A failure is sorted by reading the failing step against the app as it
  is today:
  - the app changed and the flow did not (a key renamed, a screen moved, a route redirected):
    the flow is updated and run again, result "fixed";
  - the app is wrong: a bug Finding, the flow stays red;
  - a hang: fixed if it is the flow's own wait, otherwise a Finding.
- A self-skip is not a pass. A skip whose precondition the run can meet (a clean install for the
  signup and account-delete flows) is re-run with the precondition met.
- AI spend: `meal_plan_build_flow_test` makes one new Vana plan (one `plan` spend on wave 3's
  counter, taken before the run). `ai_coach_chat_flow_test` sends one Vana general-chat turn (one
  `logging` spend; the counter has no chat kind). No other flow is expected to call a model.
- Accounts: `account_delete_flow_test` makes two `lee+e2e-<millis>` accounts and deletes both;
  afterwards `sweep-accounts.mjs list` shows none of them left.
- RevenueCat: no writes. The dev test account's entitlement is whatever it holds; `pro_gate`
  checks the gate agrees with itself either way.

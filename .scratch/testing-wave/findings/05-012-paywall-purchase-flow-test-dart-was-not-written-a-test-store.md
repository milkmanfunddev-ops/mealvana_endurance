# 05-012 · paywall_purchase_flow_test.dart was not written; a Test Store purchase flow is feasible

- kind: followup-test
- status: open
- ticket: 05
- run: w5-20260924T0839Z
- screen: Paywall (onboarding), Test Store sheet
- decision: 

**Steps.**
1. Write `integration_test/flows/paywall_purchase_flow_test.dart`: fresh signup → onboarding paywall → Monthly → Continue → tap "Test valid purchase" in the native Test Store alert with `$.native`.
2. Check the app lands on the timeline, then that the webhook wrote `user_entitlements` (it lands within about 2 s).
3. Finish within 25 minutes of the purchase (the Test Store monthly lapses after four 5-minute renewals, 05-003), and delete the account.

**Expected.**
A deterministic Patrol flow for the purchase path joins the others, as spec Seam 2 asks ("New flows join the existing ones and the self-hosted runner's list").

**Actual.**
The ticket's Touches line names the file; the agent did not write it (its criteria did not ask for it, and 05-002/05-003 change what it would check). Written by the wave lead.

**Evidence.**
- runs/05/notes.md, section Patrol

**Decision quote.**
> 

**Triage.**


# 115-004 · Deleting an account from the Lapsed paywall (not the onboarding one): which analytics event fires, and can analytics tell the two paywalls apart

- kind: followup-test
- status: open
- ticket: 115
- run: w32-20260925T2219Z
- screen: Paywall (Lapsed)
- decision: 

**Steps.**
1. A Lapsed account signs in: full-screen paywall.
2. ⋯ > Delete account > Delete.
3. Read the console analytics line.

**Expected.**
An event that says the delete came from the paywall, and ideally which one (onboarding, never paid, or Lapsed), so the numbers mp-494 is about can be split.


**Actual.**
Not run. This run checked the onboarding paywall only: `paywall_delete_account_tapped {}` with no properties (04-001 pass), and Settings still sends `settings_delete_account_tapped {}`. The event carries no property naming which paywall, so a Lapsed athlete deleting is counted with brand-new accounts.


**Evidence.**
- runs/115/console-redacted.log — `paywall_delete_account_tapped {}` at 17:27:46 local.
- runs/115/notes.md — the 04-001 lines.

**Decision quote.**
> 

**Triage.**


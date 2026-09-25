# 03-002 · Signed out, the RevenueCat SDK stays identified as the last signed-in account (another user's customer and entitlement)

- kind: bug
- status: closed
- ticket: 03
- run: w3-20260923T1942Z
- screen: Welcome
- decision: 

**Steps.**
1. Sign in as one account, then sign out (or, as here, start from a simulator where another
   account was signed in last).
2. Stay signed out on the welcome screen.

**Expected.**
Signed out, the RevenueCat SDK holds no account's customer: sign-out logs RevenueCat out (or
logs in the next user before any status is read), so no customer info for the previous account
reaches the app.

**Actual.**
The app never calls `Purchases.logOut` (no `logOut` anywhere in `lib/`). Signed out on the
welcome screen, the SDK stays identified as the last account: this run's device log shows it
fetching `/v1/subscribers/607f9dd5-…` (the dev admin) and pushing that customer's active
entitlement while nobody was signed in. It is also what runs/02/notes.md saw as "the signed-out
RevenueCat anonymous customer … holds an active entitlement". No wrong Gate answer was seen in this run (the status
switched to the signed-in account's before the Gate read it), but on a shared
device, the next person's first status can be the previous person's subscription.

**Evidence.**
- runs/03/device-auth.log, lines before the email login: `[RevenueCatService] configured`,
  the `/v1/subscribers/607f9dd5-…` request, `customer info updated {active: true, …2027-09-15…}`
- runs/02/notes.md, "Console lines and what they are", last bullet

**Decision quote.**
> 

**Triage.**
Fix ticket 33 (Lee, 2026-09-25). Closed by the retest after it merges.

Closed by retest ticket 86 (run w25-20260925T1324Z, build 5e05f8a6): pass, evidence in runs/86/verdicts.md.

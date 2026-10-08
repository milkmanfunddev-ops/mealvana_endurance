# 01-015 · Post-onboarding auth: Continue without an account, then delete; Back; Apple and Google

- kind: followup-test
- status: closed
- ticket: 01
- run: w1-20261007T1103Z
- screen: Post-Onboarding Auth
- decision: 

**Steps.**
1. Tap "Continue without an account": land on the Timeline as an anonymous user; then Settings → Delete Account. Does delete-user remove the anonymous auth user and its rows (footprint)?
2. Tap Back from this screen: are the onboarding answers kept?
3. Continue with Google and Continue with Apple (simulator): does each reach its sheet and come back cleanly when cancelled?

**Expected.**
An anonymous athlete can delete too and leaves nothing; Back keeps answers; a cancelled provider sheet returns to this screen without an error box or a Sentry error.

**Actual.**
Not run (look-around).

**Evidence.**
- runs/01/17-create-account.png

**Decision quote.**
> 

**Triage.**
retest ticket 30 (retest: auth and account), wave 3 (Lee: all 27 followups into four retest tickets)

**Closed (wave 3, 2026-10-08).** run in ticket 30; re-filed as 30-005 and 30-006

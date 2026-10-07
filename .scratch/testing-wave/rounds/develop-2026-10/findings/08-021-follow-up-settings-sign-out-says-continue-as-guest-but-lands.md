# 08-021 · Follow-up: Settings → Sign Out says 'continue as guest' but lands on Welcome; test Cancel and the guest claim

- kind: followup-test
- status: triaged
- ticket: 08
- run: w1-20261007T1105Z
- screen: Settings
- decision: 

**Steps.**
1. Tap Sign Out, read the dialog ('You'll continue using the app as a guest. Your preferences will be saved on this device.'), try Cancel, then Sign Out, and check whether anything of the old account's local data stays visible or is offered as guest.

**Expected.**
The dialog's text matches what happens.

**Actual.**


**Evidence.**
- runs/08/b01-after-signout-tap.png the dialog
- runs/08/b02-signed-out.png Welcome after Sign Out

**Decision quote.**
> 

**Triage.**
retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets)

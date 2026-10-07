# 08-017 · Follow-up: notification permission prompt first appears on the offline cold start after re-sign-in

- kind: followup-test
- status: triaged
- ticket: 08
- run: w1-20261007T1105Z
- screen: none (startup)
- decision: 

**Steps.**
1. Run under the notification-testing skill (CLAUDE.md rule). Fresh sign-in, then cold start online and offline: when does the OS permission prompt appear, and what happens on Allow vs Don't Allow? Here it did not show on the leftover-data launch (trail: permission=false optedIn=false) but showed on the next cold start after sign-out/sign-in; I tapped Don't Allow. Afterwards the app logged notif_scheduled carb_load x3 with notifications_enabled: false.

**Expected.**
The prompt appears at a deliberate moment, once; scheduling with permission off is intended.

**Actual.**


**Evidence.**
- runs/08/b13-offline-cold-start.png the prompt
- runs/08/console-redacted.log notif_scheduled lines after 11:13Z

**Decision quote.**
> 

**Triage.**
retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets)

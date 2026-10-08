# 48-005 · Follow-up: consent ON afterwards, Settings Privacy and Mixpanel

- kind: followup-test
- status: triaged
- ticket: 48
- run: w5-20261008T1718Z
- screen: Your privacy
- decision: 

**Steps.**
1. Reach Your privacy (GB geo cache written through cfprefsd with `simctl spawn defaults write <container plist path>`, relaunch
   with `netcut.sh slow 3000 --only app.mealvana.io --relaunch`), switch Share usage data ON, Continue, finish signup.
2. Settings → Privacy: the usage switch shows ON. Switch it OFF: analytics stop (no further `📊 [ANALYTICS]` lines sent to
   Mixpanel), prefs `analytics_consent_status=denied`.
3. Check Mixpanel (read-only) for the run's distinct id: events only after the ON tap, none after OFF.

**Expected.**
The Settings switch matches the consent screen's answer, and turning it off stops sending.

**Actual.**
Not run. This run saw only the first half: after ON, prefs `analytics_consent_status=granted`, `analytics_consent_regime=strict`
(prefs-pending-signup-before-relaunch.txt). The stored time `analytics_consent_at=2026-10-08T12:23:11.370899` is local with no offset,
as 30-014 already noted.

**Evidence.**
- runs/48/48-08-consent-toggle-on.png
- runs/48/prefs-pending-signup-before-relaunch.txt

**Decision quote.**
> 

**Triage.**

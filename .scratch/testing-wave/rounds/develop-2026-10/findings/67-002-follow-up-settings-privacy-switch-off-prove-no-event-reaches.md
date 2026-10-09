# 67-002 · Follow-up: Settings Privacy switch OFF, prove no event reaches Mixpanel, and the card tap target

- kind: followup-test
- status: triaged
- ticket: 67
- run: w7-20261008T2308Z
- screen: Privacy
- decision: 

**Steps.**
1. On a build with the Mixpanel tracker live (`ANALYTICS_DEV_ENABLED=true`, so the console shows `[analytics] 📊 …` lines), or
   with Mixpanel's live view open for the run's distinct id: Settings → Privacy, switch OFF, then visit two screens that emit events
   (Settings → Privacy again emits `settings_privacy_tapped`; any onboarding screen emits `screen_viewed`).
2. Switch it back ON and check events resume.
3. Tap the card's text (not the switch) and, with VoiceOver on a device, double-tap the "Share anonymous usage data" element.

**Expected.**
1. No event reaches Mixpanel after OFF; events resume after ON.
3. Either the whole card toggles or the accessibility element is the switch alone, so a VoiceOver double-tap toggles it.

**Actual.**
Not a failure in this run; this is what the run could not prove. Prefs went `granted` (23:10:26Z) → `denied` (23:20:09Z), snackbar
"Usage data sharing is off". This debug build never built the Mixpanel tracker: zero `[analytics] 📊` lines in the whole console,
and the Noop echo `📊 [ANALYTICS] settings_privacy_tapped {}` printed at 23:20:59Z after OFF just as it did at 23:19:45Z before it,
so the console cannot tell "sent" from "not sent". Also: the `CheckBox` element spans the whole card (x=16 y=134 w=370 h=225), but a
tap at its centre (23:19:55Z) did nothing; only the switch at (340,174) toggled. Flutter routes VoiceOver activation through the
semantics action, so it may work on a device; unverified.

**Evidence.**
- runs/67/ui-26-privacy-settings.txt
- runs/67/67-27-privacy-off.png
- runs/67/prefs-check4-after-off.txt
- runs/67/console-redacted.log

**Decision quote.**
> 

**Triage.**
- triaged · retest ticket A (auth, startup, Welcome, Sign Out; with fix ticket 53), cut after fix wave 8 for test wave 9 · Lee, 2026-10-09

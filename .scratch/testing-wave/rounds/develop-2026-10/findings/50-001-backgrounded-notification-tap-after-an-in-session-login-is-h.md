# 50-001 · Backgrounded notification tap after an in-session login is HELD as 'startup not routable' and never routes (retest of 22-001)

- kind: bug
- status: open
- ticket: 50
- run: w5-20261008T1720Z
- screen: none (resume path; app was on Settings → Connected Apps)
- decision: 

**Steps.**
1. Cleared app, launched signed out on Welcome (startup resolves with no user). Log In with test@test.com in the
   same session; allow notifications. Timeline shows.
2. Background the app (HOME). `xcrun simctl push UDID com.milkman.mealvanaendurance.dev` with
   `"payload":"reminder:be55a023-b878-4a32-a166-2ab92b9a4815"` (Run - Long Run, Oct 10). Tap the banner (17:26:15Z).
3. Read the dev trail dialog; dismiss it.
4. Control: terminate, relaunch signed in, background, same push, tap (17:27:35Z).

**Expected.**
The resume consumes the payload and routes to the activity detail (ticket 34 / 22-001), whatever way the athlete
signed in.

**Actual.**
Step 2-3 tape: `native ios_un_response_payload=reminder:be55…` → `(consumed)` → `dispatch … handlerSet=true` →
`HELD id=be55… type=reminder (startup not routable)`. The app stayed on Connected Apps; nothing routed, and no
REPLAY line followed (the key is already removed from prefs, so the tap is gone unless startup re-resolves). From
code (unverified): `_isRoutableNow()` (`lib/shared/widgets/root_app_widget.dart` ~276) needs
`appStartupProvider` data with `user != null`; the provider resolved at launch while signed out and the in-session
login did not re-resolve it, so every backgrounded tap until the next cold start is held.
Control (step 4): from a signed-in cold start the same tap routed: `routing id=…` → `deepLinkTo /plan (seeded /
beneath)`, landed on "Run - Long Run" detail (Oct 10, 7:00am), Back went to the Timeline, and
`flutter.ios_un_response_payload` was absent from the plist after terminate. So 22-001 is fixed for a signed-in
launch and still broken for the first session after a fresh login (every new install and every re-login).

**Evidence.**
- runs/50/d03-after-banner-tap-2.png trail dialog with the HELD line
- runs/50/d04-after-dismiss.png still on Connected Apps after the tap
- runs/50/d07-after-tap-coldstart.png control: routing + deepLinkTo lines
- runs/50/d08-landed-activity.png control: Run - Long Run detail
- runs/50/plist-after-tap1.txt payload key absent after the held tap (consumed and lost)
- runs/50/console-redacted.log `[LAUNCH] HELD id=be55…` at 12:26:16

**Decision quote.**
> 

**Triage.**


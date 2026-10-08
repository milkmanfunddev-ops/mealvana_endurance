# 30-003 · The iOS notification prompt appears the instant the signup code is accepted, with nothing in the app saying why first

- kind: idea
- status: open
- ticket: 30
- run: w3-20261008T1255Z
- screen: Verify your email
- decision: 

**Steps.**
Idea: show one line or a short screen before the iOS "Would Like to Send You Notifications" prompt saying what Mealvana
will send (fuelling reminders, carb-loading nudges), and ask at a moment tied to a feature, not the second the account
is confirmed. Seen in this run: fresh install, plain email signup; the code was accepted at 13:02:18Z and the system
prompt was already over the Timeline in the next screenshot, before the athlete had seen the app. A "Don't Allow" given
there is final for that install unless they go to iOS Settings. The fix for 01-010 moved the ask behind "an athlete id"
(`[LAUNCH] onesignal started; permission ask + heal wait for an athlete id`), which is right for a signed-out Welcome; this is about what comes
before it. Note: an anonymous id counts as an athlete id. At 13:07:06Z, one second after Build My Plan minted an anonymous
session, the console logged `[LAUNCH] permission prompt wait 112ms granted=false` (already decided on this simulator, so
nothing showed). On a fresh install with network the prompt would come up as onboarding starts, before the athlete has
answered a single question. In A's run it came after the code only because the anonymous sign-in was forced to fail.

**Expected.**
The athlete knows why the app wants notifications before iOS asks.

**Actual.**
The prompt arrives with no context, straight after verification.

**Evidence.**
- runs/30/30a-19-notif-prompt-after-verify.png
- runs/30/console-redacted.log (`[LAUNCH] permission prompt wait 19037ms granted=false`)

**Decision quote.**
> 

**Triage.**

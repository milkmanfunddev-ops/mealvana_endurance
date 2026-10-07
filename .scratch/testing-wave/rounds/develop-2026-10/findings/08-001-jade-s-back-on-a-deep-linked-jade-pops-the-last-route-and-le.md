# 08-001 · Jade's Back on a deep-linked /jade pops the last route and leaves a black screen

- kind: bug
- status: open
- ticket: 08
- run: w1-20261007T1105Z
- screen: Mealvana AI (AiCoachChatScreen, /jade)
- decision: 

**Steps.**
1. Signed in as test@test.com (has Jade history, so no opener fires), open xcrun simctl openurl <udid> "com.milkman.mealvanaendurance:///jade" (three slashes), signed in as test@test.com.
2. Mealvana AI opens on the last conversation.
3. Tap the Back chevron (top left).

**Expected.**
Back returns somewhere usable (the Timeline), as Coach Messages' Back does.

**Actual.**
The screen goes fully black; only the dev testing-tools overlay stays. No Flutter console line at all. The chevron calls `Navigator.of(context).pop()` (ai_coach_chat_screen.dart:158, from code) on a stack holding only /jade. The app stays black until another deep link or a relaunch.

**Evidence.**
- runs/08/c11-jade.png Jade before Back
- runs/08/c11b-jade-back.png black screen after Back
- runs/08/console-redacted.log no line after the tap (11:18Z)

**Decision quote.**
> 

**Triage.**

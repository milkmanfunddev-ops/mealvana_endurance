# 08-006 · Mealvana AI shows markdown ** markers as literal text in a stored reply

- kind: bug
- status: open
- ticket: 08
- run: w1-20261007T1105Z
- screen: Mealvana AI (AiCoachChatScreen, /jade)
- decision: 

**Steps.**
1. Open xcrun simctl openurl <udid> "com.milkman.mealvanaendurance:///jade" (three slashes), signed in as test@test.com on test@test.com; the latest conversation loads from history (2026-09-30).

**Expected.**
Bold markdown renders as bold (or the reply has no markup).

**Actual.**
The assistant bubble prints '**Today, Wednesday 9/30:** - Swim 30 min - Bike…' with the asterisks visible and the list run together on one paragraph. Not re-checked on a fresh reply (that would be an AI call).

**Evidence.**
- runs/08/c11-jade.png

**Decision quote.**
> 

**Triage.**

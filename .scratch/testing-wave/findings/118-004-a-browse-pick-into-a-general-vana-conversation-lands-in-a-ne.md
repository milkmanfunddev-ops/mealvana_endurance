# 118-004 · A Browse pick into a general Vana conversation lands in a new server draft, but the chat's plan bar reads 0 meals and the pick cannot be removed

- kind: bug
- status: open
- ticket: 118
- run: w36-20260926T0031Z
- screen: Browse meals; Vana chat
- decision: 

**Steps.**
1. test@test.com, Timeline → Ask Vana (general conversation ec37f880-05e9-460f-8af0-cbb5e4403260,
   "Quick question", opened 00:46:05Z).
2. Open Browse for it: `xcrun simctl openurl UDID "com.milkman.mealvanaendurance:///vana/browse?c=ec37f880-05e9-460f-8af0-cbb5e4403260"`.
3. Tap "+" on Recents → Egg & Veggie Scramble (00:48:03Z). Tap it again. Tap Done.
4. Tap Review plan. Then open the conversation itself by deep link (`/vana?c=ec37f880-…`).

**Expected.**
The pick shows in the conversation's plan bar ("Your plan · 1 meal"), and the athlete can take it
out again (a second tap on the ticked button, or Remove in the plan bar or review).

**Actual.**
The pick reached the server: a new `meal_plans` draft 50390c90-9253-491d-9658-8fa846c58368 (week
2026-09-20, `days` {}) with one `plan_meals` row (Egg & Veggie Scramble, dinner, 4 servings). The
card ticked ("In your plan"). A second tap on the ticked button did nothing. After Done, and again
when the conversation was opened by its own link, the chat's title read "New meal plan" (the
conversation is `kind` general, "Quick question") and its plan bar read "Your plan · 0 meals ·
Tap a meal above and it lands here." Review plan did nothing. So the pick sits in a draft the chat
does not show and cannot be removed from the app. The draft was left unconfirmed.
Browse was opened by deep link (no model call); the in-chat path (the composer's Add → Browse
meals) was not tried and may reload the draft differently.

**Evidence.**
- runs/118/56-browse-add-tapped.png, runs/118/57-browse-after-pick.png: before and after the tick.
- runs/118/db-18-005-draft-before.txt, runs/118/db-18-005-draft-after-pick.txt: no draft, then the draft's plan_meals row.
- runs/118/65-review-plan.png: "Your plan · 0 meals" after Done and Review plan.
- runs/118/66-conversation-deeplink.png: the same with the conversation opened by its link.

**Decision quote.**
> 

**Triage.**

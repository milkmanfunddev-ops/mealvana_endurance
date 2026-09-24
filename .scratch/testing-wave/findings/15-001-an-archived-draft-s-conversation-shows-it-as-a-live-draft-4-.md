# 15-001 · An archived Draft's conversation shows it as a live Draft: 4 meals, editable servings, Review plan with Confirm plan

- kind: ssot-conflict
- status: open
- ticket: 15
- run: w12-20260924T1712Z
- screen: Vana chat (meal planning), opened from Conversations
- decision: mp-241

**Steps.**
1. Signed in as test@test.com, Ask Vana → full screen → Conversations → Meal plans → "This week's plan, Sep 22, 7:08 AM" (conversation `ebac747d`).
2. Read the plan bar; tap "Your plan · 4 meals" to expand it; tap Review plan; tap Keep planning (Confirm, -/+ and remove were not tapped).

**Expected.**
mp-241: confirming a draft archives every other plan for that week, drafts from other conversations included. This conversation's Draft `15b6b4f4` is archived (a later confirm of the week of Sep 20 archived it). The conversation should say so: the plan reads as archived (or replaced by the week's confirmed plan), and offers no Confirm on it. The Decision does not say what a conversation whose Draft was archived shows, or whether the next pick starts a fresh Draft there ("every conversation builds its own Draft"), which is the product question here.

**Actual.**
The plan bar reads "Your plan · 4 meals" with an orange Review plan button, the same as a live Draft. Expanded, each of the four meals has -/+ servings and a remove (×) control. Review plan opens "Your week · 4 meals · 16 servings" with Cook Sunday / Top-up Wednesday groups and a live Confirm plan button. Nothing on screen says the Draft was archived. The server returns the plan's status with `get_plan` (plan.ts `hydrate` sets `status`), and the chat labels a confirmed plan "Plan confirmed" (1a24f2bf in this run, 19-1a24f2bf-open.png), so only the archived case is drawn as a Draft. Combined with 16-001 (the Review sheet's Confirm sends no conversation or plan scope and re-confirmed the week's confirmed plan), a tap on Confirm here would not do what the button says.

**Evidence.**
- runs/15/10-ebac747d-open-1s.png — plan bar "Your plan · 4 meals", Review plan.
- runs/15/17-ebac747d-plan-bar-expanded.png — servings -/+ and × on the archived Draft's meals.
- runs/15/18-ebac747d-review-sheet.png — Review sheet with Confirm plan.
- runs/15/db-before.txt — `15b6b4f4 | 2026-09-20 | archived | ebac747d… | 4 meals`; `be6abf2f` confirmed for the same week.
- runs/15/db-after.txt — statuses unchanged (nothing was tapped).
- Related: 16-001 (confirm without scope), 16-010 (follow-up that asked what such a conversation shows; this Finding answers it for `ebac747d`).

**Decision quote.**
> Every conversation with Vana builds its own Draft, so an athlete can hold any number of drafts but only one confirmed plan per week. Confirming a draft archives every other plan for that week, drafts from other conversations included, and the Plan tab keeps the confirmed plan until a new one is confirmed. "New meal plan" archives the plan it is on and starts a fresh, empty draft. Example: an athlete starts a draft in Monday's conversation and another in Wednesday's; confirming Wednesday's archives Monday's draft and the week's old confirmed plan.

**Triage.**

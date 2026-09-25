# 15-007 · Conversations list: scroll to the oldest row, rows for deleted or other-week plans, and the Ask Vana tab's empty state

- kind: followup-test
- status: closed
- ticket: 15
- run: w12-20260924T1712Z
- screen: Conversations
- decision: 

**Steps.**
1. Conversations → Meal plans: scroll to the bottom. test@test.com has about 60 meal-planning conversations back to August; check the list reaches the oldest one (or pages), and count rows against vana_conversations where kind = meal_planning and is_deleted = false.
2. Open a row whose plan is deleted, a row with no plan (`0401b3d8`, 1 turn), and a row whose plan is for an older week (`1a24f2bf`, week of Sep 13) and read what the plan bar says.
3. Long-press and swipe a row (delete or rename, if offered).
4. Sign in as an account with no conversations and open both tabs (empty states).
5. Pull to refresh after a conversation is added on another device.

**Expected.**
Every stored conversation is reachable; rows for other weeks are told apart from this week's (16-006); an empty tab says so and offers New conversation / New meal plan; a conversation with no plan shows no plan bar.

**Actual.**


**Evidence.**
- runs/15/09-conversations-meal-plans.png
- runs/15/21-back-to-list.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 88 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).

Run by retest ticket 88 (run w29-20260925T1949Z, build e3367d2c): fail, filed as 88-002, 88-021, 88-024; closed here, the new Findings carry it.

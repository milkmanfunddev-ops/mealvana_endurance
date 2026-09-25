# 88-005 · Browse and cards in a replaced draft's conversation write into the archived plan and show In your plan

- kind: bug
- status: open
- ticket: 88
- run: w29-20260925T1949Z
- screen: Browse meals (from a conversation whose draft was replaced)
- decision: 

**Steps.**
1. Retest of 18-009 step 1. Conversations > Meal plans > Sep 24 9:23 AM (`d8efbdb3`, archived draft 54a02440, 1 meal). The bar reads "You confirmed a different plan for this week…" with Use this plan instead.
2. Plus > Browse meals > "+" on a Recents card (20:01:59Z). Done.
3. Also in `ebac747d` (archived 15b6b4f4): tap an old turn's chip "Different protein" (19:57:17Z).

**Expected.**
18-009: Browse either starts a fresh draft for this conversation or tells the athlete the plan was replaced; it never writes into an archived plan. mp-683 (open) asks which.

**Actual.**
The pick went into the archived plan: 54a02440 now has 2 meals (Rice, black beans & roasted plantain x4 added, updated 20:02:00Z), its status stays archived, the card turns to "In your plan" and the toast says it was added; back in the chat the read-only bar reads "Your plan · 2 meals" under the replaced-plan note. Nothing tells the athlete the meal went into a plan that is not live. The composer, Browse and the old chips stay live; the old chip tap in step 3 sent nothing and only scrolled the transcript to the bottom. Step 2 of 18-009 (Browse from `f6a0f7fa`, confirmed be6abf2f) added the meal to the confirmed plan and rebuilt its list 15 -> 17 rows, which is right.

**Evidence.**
- runs/88/31-18-009-browse-from-d8efbdb3.png, runs/88/33-18-009-add-injera-4s.png: the add and its tick.
- runs/88/db-06-18-009-after-browse-add-d8efbdb3.txt: 54a02440 archived, 2 meals.
- runs/88/34-18-009-chat-after-done.png: read-only bar at 2 meals.
- runs/88/db-16-18-009-be6abf2f.txt: step 2, confirmed plan edited and list rebuilt.

**Decision quote.**
> 

**Triage.**

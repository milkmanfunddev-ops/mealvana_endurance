# Vana — turn-by-turn walkthrough (v2, 2026-08-26)

Canvas, page "Walkthrough": https://claude.ai/code/artifact/c776e4cd-1e7f-4f7a-8c71-a6a2d332ec21

Rules the flow obeys (v7, 2026-08-28):
- **Act, don't ask.** Vana never confirms what the data already says: staples come up as tappable options (suggest-only — nothing enters the plan until the athlete taps; changed from the earlier auto-add, 2026-09-02), picker ticks land in the plan bar, no "which one first". Questions only at a real fork. Every turn ends with feedback chips (Looks good · Change something · Swap a meal · Confirm plan when coverage ≥ 10/14).
- **Two conversation kinds.** `meal_planning` (from the Plan tab) = planning persona + tools + plan bar; `general` (Ask Vana elsewhere) = Q&A persona, offers "Start a meal plan". /vana opens the most recent of the requested kind; the list tags each; New conversation asks which.
- **Cost.** Chat model is Haiku (≤900-token prompt, compact tool outputs, ≤6 steps); Sonnet only by env override. Daily targets come from `daily_macro_targets` (the daily-macros service), never recomputed.

Older rules still in force:
- Vana never says more than two sentences before the user has buttons. One question per turn, 2–3 chips, free text always available.
- The first move is always "here's what you already eat" (diagnose-and-add), never a questionnaire.
- Nothing is committed until the user taps **Confirm**. Macros stay behind a disclosure, with the daily total.
- Batch cooking is a **setting** (Settings → Batch cooking). Vana asks once, saves it, and can flip it in conversation. It only changes whether the week is grouped into cooking sessions.
- The Plan tab is the plan (meals × servings, tap → plan detail with Edit / New plan / Confirm) plus a day planner; no brief and no shopping list there. Vana always opens the most recent conversation; a conversations list (title · last message · summary) lets you reopen old ones or start a new one, which opens with Vana's opener.
- Shopping is its own segment under the Food tab (Plan · Meals · Formulas · Shopping). "Meals" holds Mine | Library (the 400-meal library, `mealplanning-prototype/packages/web/data/meal-library-400.json`).
- The word is **meal** (not plate): the library rows are the catalog the picker, day cards and staples-matching draw from.

| # | Screen | What comes up / what Vana says | What the user can do |
|---|---|---|---|
| 1 | Food → Plan, no plan yet | "No plan yet" card → **Build with Vana** / Create a plan; empty day planner (Breakfast · Lunch · Dinner · Snack, date strip); today line + **today's target from the daily-macros service** ("at least 344g carbs · 117g protein · 2,640 kcal"). No brief, no shopping card. | Build with Vana · Create a plan · Add to a slot · Ask Vana |
| 2 | New meal-plan conversation | Vana ACTS, one sentence: "Race week, and you're ~120g carbs a day short from Wednesday — your chicken & rice, porridge and salmon are one tap away, and I've pulled three starch-forward dinners." (*staples are suggest-only — the shipped `diagnoseStaples` adds nothing for the athlete; the auto-add wording here was the old design*). Then the picker (trimmed cards: name · why · short attribution · Batch · prep; macros behind a disclosure) — **every tick lands in the horizontal plan bar immediately** — then feedback chips. The plan bar (cards with name · slot · ×servings, a + card, "13 / 14" coverage pill, **Confirm plan** always visible) is pinned above the composer from the first turn. No confirmation questions. | tick meals · **Looks good** · Change something · Swap a meal · Confirm plan · type |
| 3 | Swap a meal | Tap a plan-bar card → sheet: servings stepper · **Swap** · Remove · Done. Swap → "Same slot, race-week fits, none already in your plan — tick one and it replaces the salmon in place." + three same-slot options. | stepper · Swap · Remove · tick a replacement |
| 4 | Batch? (asked once) + Friday | "Looks good" → the only real forks: "do you cook in batches, or most nights?" (saved to Settings, never asked again) and "Friday night, Mirinda Carfrae's race-eve plate?" with the D-002 card. | Batches, weekends · Most nights · Depends → Yes · Show me others · Why? |
| 5 | Your week · Confirm plan | "That's your week — 14 of 14 lunches and dinners covered, breakfast stays your porridge. Confirm when you're ready." + sessions summary (only if batch cooking on) + rule chips; feedback chips; **Confirm plan** in the bar. | Looks good · Change something · Swap a meal · **Confirm plan** |
| 6 | List ready | "Done — shopping list is ready, 13 items. I skipped rice, you have it." | Open shopping list · Add rice back · Send to Publix |
| 7 | Food → Plan, mid-week (Thursday) | The plan with servings-left and **Ate it**; the day planner filled from the plan; carb-load line + today's target; Edit plan / New plan. | Ate it · open the plan · Edit / New plan |
| 8 | Food → Shopping | Aisle-grouped list, "have it" ticks, Send to Reminders / Order pickup. | tick · share |
| 9 | General question | Ask Vana from the Meals tab → a **general** conversation (header "Vana · general"): "what should I eat before tomorrow's ride?" → ≤2 sentences citing today's target, a library snack card. No plan bar. | Add to today · Start a meal plan · Why 344g? |
| 10 | Batch cooking via Vana / Settings | "I'm traveling next week, no batch cooking" → "Okay — next week I'll plan meals you can make the night of. Turn batch cooking off for good, or just next week?"; the same switch in Settings. | Just next week · For good · toggle in Settings |

If batch cooking is **off**: step 5's session line is skipped; step 6 shows plates × servings with no Cook Sunday / Top-up rows ("make the night of" plates, 10–25 min); the shopping list is identical.

Widget → tool mapping and the not-v1 list are on the canvas notes and in `synthesis-and-recommendations.md`.

# Decisions: Meal planning

Feature: mealplanning
Feature name: Meal planning

## mp-001 · The assistant is called Vana
- category: Vana: who she is and how she talks
- status: approved
- image: none
- screen: Vana chat
- source: synthesis-and-recommendations.md; memory 08-26

**Context.** The assistant had three placeholder names: Sage, MealBuddy and Jade.

**Question.** What is the assistant called?

**Decision.** Vana, from Meal-vana. "AI" is not part of her name, and the one name is used everywhere in the app.

**Why.** The placeholders were never meant to ship, and one name was needed before more screens were drawn.

**What else was considered.** Mel, Endy, or "Mealvana AI".

> 2026-09-26 overhaul: rewritten from mp-001

## mp-002 · There is one Vana, and Jade is retired
- category: Vana: who she is and how she talks
- status: approved
- folded: mp-209
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption: The Vana chat. Every way into Vana reaches the same assistant.
- screen: Vana chat
- source: spec.md; CONTEXT.md; memory 09-09; Lee on the page 2026-09-13

**Context.** The app once had Jade for general questions and a separate planner for meals.

**Question.** Is there one assistant or several?

**Decision.** One. Every way into Vana (the launcher, the Plan tab, a coach's feedback on a formula) talks to the same Vana with the same tools. Jade is removed everywhere, including the words a coach sees.

**Why.** Two assistants would split what the athlete has told the app, and the athlete would have to know which one to ask.

**What else was considered.** Jade for general chat plus a separate planner, with a classifier routing between them.

> 2026-09-26 overhaul: rewritten from mp-002, mp-209

## mp-214 · Vana is short and to the point
- category: Vana: who she is and how she talks
- status: approved
- folded: mp-012, mp-546
- image: none
- screen: Vana chat
- source: Lee on the page 2026-09-13, rejecting mp-011

**Context.** An earlier rule capped each kind of turn at a fixed number of sentences.

**Question.** How long are Vana's replies, and what is off limits?

**Decision.** Vana says what the athlete needs and stops. There is no sentence count. When she sends the athlete to a screen, she writes one sentence and stops. No emoji, no talk about weight, food framed as minimums to reach, and medical questions go to a professional.

**Why.** A fixed sentence count cut useful answers short; the tone rules protect athletes.

**What else was considered.** A length limit per kind of turn.

> 2026-09-26 overhaul: rewritten from mp-214, mp-012
> 2026-09-26 approved by Lee: one sentence before a hand-off, checked in code (mp-546)

## mp-006 · Vana looks things up before she asks
- category: Vana: who she is and how she talks
- status: approved
- image: none
- screen: Vana chat
- source: vana-chatbot-update-plan.md

**Context.** The app already knows the athlete's training, goals, diet and allergies from onboarding, the calendar and the integrations.

**Question.** Does Vana run a questionnaire before she helps?

**Decision.** No. She uses what she is handed and her tools first, and only asks about things the app cannot know that matter to the plan, such as who is eating this week.

**Why.** Asking for what the app already holds wastes the athlete's time.

**What else was considered.** A setup questionnaire at the start of planning.

> 2026-09-26 overhaul: rewritten from mp-006

## mp-008 · Every opener says the most relevant thing Vana knows, and never waits
- category: Vana: who she is and how she talks
- status: approved
- folded: mp-010, mp-268, mp-278
- image: none
- screen: Vana chat
- source: CONTEXT.md; memory 09-11; commit 1dedc493

**Context.** The opener is Vana's first message in a new conversation.

**Question.** What does Vana open with?

**Decision.** The most relevant thing she knows right now: the athlete's next workout, the weather, what is on screen, or something they told her before. It never greets and never shows example chips or an intro card. It goes out at once with what she already holds. Example: "Tonight's run is at 5:30. Want me to walk you through fuelling it?", not "Hi! How can I help?".

**Why.** A personal first line shows she knows the athlete; a generic one wastes the first turn.

**What else was considered.** Example-question chips, a one-time intro card, and waiting for the last chat to be summarised first.

> 2026-09-26 overhaul: rewritten from mp-008, mp-010, mp-268, mp-278

## mp-275 · The launcher reopens today's conversation; New meal plan starts a new one
- category: Vana: who she is and how she talks
- status: approved
- folded: mp-003, mp-058, mp-443
- image: none
- screen: Plan tab
- source: grill 2026-09-15

**Context.** Athletes reach Vana from the launcher, the Plan tab's Vana card, and New meal plan.

**Question.** When does the athlete get a new conversation?

**Decision.** The launcher and the Plan tab's Vana card reopen the day's one conversation all day; the first open after midnight starts a new one. New meal plan always starts a new conversation. Reopening a conversation shows it as it was, with no new model call, and every past conversation stays in history.

**Why.** One running conversation a day keeps context together, and a plan needs a clean start.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-275, mp-003, mp-058, mp-443

## mp-264 · Vana opens as a sheet from a launcher on three screens
- category: Vana: who she is and how she talks
- status: approved
- folded: mp-051, mp-061, mp-265
- image: docs/ssot/decisions/images/mealplanning/timeline.png
- caption: The main tabs with Vana's launcher.
- screen: Main tabs, Plan tab, coach formulas
- source: Lee on the page 2026-09-14, on mp-049, mp-050, mp-053 to mp-057

**Context.** The launcher is the round button that opens Vana over the app.

**Question.** Where can the athlete open Vana, and how does it look?

**Decision.** The launcher shows on three screens only: the main tabs, the meal-planning screen and coach formulas. It opens a sheet of one fixed height over the screen, which keeps its place underneath. Full screen happens only when the athlete presses the full-screen button. The launcher hides under any dialog or sheet.

**Why.** Three screens avoid a list of exceptions; more screens are a later decision.

**What else was considered.** Vana everywhere, with a list of screens that hide the launcher.

> 2026-09-26 overhaul: rewritten from mp-264, mp-051, mp-061, mp-265

## mp-223 · Vana speaks first before and after a workout, at most twice a day
- category: Vana: who she is and how she talks
- status: approved
- folded: mp-224, mp-226, mp-227, mp-228, mp-229, mp-421
- image: none
- screen: Any screen with the launcher
- source: ticket 09; vana-moment.md; archive ticket 13; ticket 10; memory 09-11

**Context.** A moment is when Vana raises something without being asked.

**Question.** When does Vana speak first?

**Decision.** Only in two fuelling windows: before a planned workout today, and after a finished endurance session of 60 minutes or more when nothing has been logged since. At most twice a day, never twice for the same workout. Cook-day check-ins and week debriefs come as the opener the next time the app opens, not as moments. When more than one thing could open the conversation, a live fuelling moment comes first, then what is on screen, then the personal opener. When the athlete asks for a plan, Vana shows a button to the planning screen.

**Why.** Fuelling around a workout is where a nudge helps most; more than two a day would be noise.

**What else was considered.** Plan moments (cook day, debrief) as their own nudges, put off until the fuelling moments have been lived with.

> 2026-09-26 overhaul: rewritten from mp-223, mp-224, mp-226, mp-227, mp-228, mp-229
> 2026-09-26 approved by Lee: order of first messages and the plan button (mp-421)

## mp-245 · Feedback typed to Vana is saved for the team
- category: Vana: who she is and how she talks
- status: approved
- folded: mp-246, mp-427, mp-547
- image: none
- screen: Vana chat
- source: spec.md; ticket 01; 02-contract.md; archive ticket 01

**Context.** Athletes complain, praise and suggest things to Vana in the chat.

**Question.** What happens to feedback the athlete types to Vana?

**Decision.** A complaint, praise or suggestion is saved for the team in the athlete's own words and also sent to Wiredash, the bug-report tool. Vana replies only "Saved for the team". If the same message also asks a question, she answers the question. Admins also get a Good / Not good review box on every meal. A taste comment like "not those" is not feedback. A problem report shows a card with a "Send to the team" button.

**Why.** The team hears what athletes say in one place, and Vana never claims to have sent something she did not.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-245, mp-246
> 2026-09-26 approved by Lee: feedback plus a question, admin review box, checked in code (mp-427, mp-547)

## mp-273 · Vana is sent the athlete's Voodoo Doll on every turn
- category: What Vana knows
- status: approved
- folded: mp-020, mp-021, mp-023, mp-042
- image: none
- screen: none (algorithm/data)
- source: grill 2026-09-15

**Context.** The Voodoo Doll is everything Vana knows about the athlete: their Facts (profile, diet, allergies, calendar, events, meal votes) and their Memories.

**Question.** What does Vana know about the athlete?

**Decision.** Every conversation, from any screen, gets the same Doll: a short, fixed digest built fresh from the records that already hold each Fact, plus a season line and any budget the athlete gave. Anything deeper she looks up with a tool. There is no second copy of the athlete's data, and onboarding is unchanged.

**Why.** One Doll everywhere means Vana never forgets on one screen what she knew on another, and reading records in place means a change in the app reaches her at once.

**What else was considered.** Sending the whole athlete context every turn; a separate preferences table.

> 2026-09-26 overhaul: rewritten from mp-273, mp-020, mp-021, mp-023, mp-042

## mp-043 · Vana knows which screen the athlete asked from
- category: What Vana knows
- status: approved
- folded: mp-044, mp-045, mp-274
- image: none
- screen: none (algorithm/data)
- source: spec.md; archive ticket 04

**Context.** The Situation is what the athlete was looking at when they asked.

**Question.** Does Vana know what is on screen?

**Decision.** Yes. Each message carries the screen and the id of the thing on it (a meal, an activity, a date), and the server turns that into one line for Vana. Nothing about the screen is stored.

**Why.** "Is this enough?" only makes sense if Vana knows what "this" is.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-043, mp-044, mp-045, mp-274

## mp-022 · Vana remembers what changes how she plans, and the athlete can see and delete it
- category: What Vana knows
- status: approved
- folded: mp-024, mp-025, mp-027, mp-028, mp-029, mp-030, mp-031, mp-037, mp-040, mp-277, mp-419
- image: none
- screen: Vana settings
- source: spec.md; CONTEXT.md

**Context.** A Memory is a note Vana keeps about the athlete, separate from the Facts the app already records.

**Question.** What does Vana remember, and who can see it?

**Decision.** A Memory is one sentence a dietitian would write in the margin, kept only if it changes how Vana plans, such as "Wednesdays are long days". It is saved when the athlete says "remember this", when Vana notices it, or from a read of the chat after it ends; the week's debrief is the only place she learns from what the athlete did. Every Memory shows in one list in Vana settings, where any row can be deleted. Past chats reach her as a short line of what the athlete said, and a long chat keeps its latest 40 messages word for word with older ones summarised twenty at a time.

**Why.** Short notes that matter keep her useful without piling up noise, and the athlete stays in control of what she holds.

**What else was considered.** A trained model of the athlete's preferences; learning from every swap and skip.

> 2026-09-26 overhaul: rewritten from mp-022, mp-024, mp-025, mp-027, mp-028, mp-029, mp-030, mp-031, mp-037, mp-040, mp-277
> 2026-09-26 approved by Lee: memory as built, checked in code (mp-419)

## mp-041 · Coach mode never reads an athlete's Doll
- category: What Vana knows
- status: approved
- image: none
- screen: none (algorithm/data)
- source: spec.md

**Context.** Coaches can talk to Vana too.

**Question.** Does Vana see an athlete's Facts and Memories when a coach asks?

**Decision.** No. Coach mode is out of scope for this work.

**Why.** Coach features are outside this work, and an athlete's notes are theirs.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-041

## mp-212 · Vana has tools for the athlete's own records
- category: Vana's tools
- status: approved
- folded: mp-014, mp-015
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption: The Vana chat.
- screen: Vana chat
- source: Lee on the page 2026-09-13, amending mp-005

**Context.** A tool is a lookup or action Vana can call in the middle of a reply.

**Question.** What can Vana look up and do?

**Decision.** She has tools for the upcoming event list, activity history, macro targets, food suggestions for a session, guidance for a given day, meal search, remembering a note, saving a setting or the athlete's home, and saving feedback. When a record can settle a question, she looks it up before answering. While a tool runs, the athlete sees a short status line such as "Finding options that fit your week…".

**Why.** Answers come from the athlete's real data instead of guesses.

**What else was considered.** Rebuilding the app's calculations inside her prompt.

> 2026-09-26 overhaul: rewritten from mp-212, mp-014, mp-015

## mp-005 · Race fuelling and meal numbers never come from the model
- category: Vana's tools
- status: approved
- folded: mp-233
- image: none
- screen: none (algorithm/data)
- source: synthesis-and-recommendations.md

**Context.** The app has its own fuelling calculator built on the ratified nutrition specs.

**Question.** Who works out fuelling targets and meal numbers?

**Decision.** The app. Pre, during and post race targets, rest-day and race-week guidance and meal numbers all come from the app's own calculations; Vana only puts them into words. Meal search removes anything that breaks the athlete's allergies or diet before Vana sees it.

**Why.** Fuelling numbers must be the same every time and match the specs.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-005, mp-233

## mp-007 · A new meal plan starts with a read of the week and one question
- category: Planning a week
- status: approved
- folded: mp-213
- image: none
- screen: Vana chat
- source: vana-chatbot-update-plan.md; memory 09-03

**Context.** New meal plan opens a planning conversation with Vana.

**Question.** How does planning start?

**Decision.** Vana writes two or three sentences about the athlete's week and asks one question, with no meals yet. The first meal picker follows the answer. If the athlete asks something off topic, she answers it in full and then offers to get back to picking, with the draft kept.

**Why.** One question keeps it quick, and a side question should not derail the plan.

**What else was considered.** A fixed opening with dinners first.

> 2026-09-26 overhaul: rewritten from mp-007, mp-213

## mp-231 · A plan covers the meal types the athlete picks, liked meals first
- category: Planning a week
- status: approved
- folded: mp-230, mp-272, mp-620
- image: none
- screen: Vana chat
- source: memory 08-31; 02-contract.md; memory 09-03; vana-chatbot-update-plan.md

**Context.** Vana suggests meals in a picker; the athlete ticks the ones they want.

**Question.** What does a plan cover, and how are meals chosen?

**Decision.** A plan covers only the meal types the athlete wants, over the plan period. Pickers put meals they liked or cooked before first, and only a tick adds a meal. After each picker the chips come from the plan as it stands: "More <meal type>" for each type still short, "Done" and "Ask Vana". "Draft it for me" and "Same as last time" fill the plan in one tap.

**Why.** The athlete decides the pace; the plan itself, not a script, says what is left.

**What else was considered.** A fixed walk through every meal type in order.

> 2026-09-26 overhaul: rewritten from mp-231, mp-230, mp-272, mp-620

## mp-232 · Batch cooking, coverage and the plan period are settings Vana reads, never asks
- category: Planning a week
- status: approved
- folded: mp-269, mp-424, mp-593, mp-608, mp-425
- image: none
- screen: Vana settings
- source: prototype-rebuild-spec.md; 05-flutter-feature.md

**Context.** Vana used to stop mid-plan to ask how the athlete cooks and how much of the week to cover.

**Question.** Where do batch cooking, coverage and the plan period live?

**Decision.** In settings. Batch cooking is on unless turned off. With it on, a plan has three meals per meal type, each cooked in enough servings to cover the period (3 servings for 7 days, 5 for 14). Coverage is "Dinners only", "Dinners and lunches" or "Every meal", starting on dinners only. A plan period starts on Sunday and runs seven days unless the athlete changes it: they pick the start day and a length of 3 to 14 days, and each plan keeps the period it was made for. Vana plans to these and never asks; if the athlete tells her otherwise in chat, she saves it as the setting.

**Why.** The settings screen already answers these questions, and every question costs a paid model turn.

**What else was considered.** Asking each question once when never chosen; weeks fixed to Sunday with set cook days.

> 2026-09-26 overhaul: rewritten from mp-232, mp-269, mp-593, mp-608
> 2026-09-26 approved by Lee: start day and a 3 to 14 day length (mp-424)
> 2026-09-26 approved by Lee: batch plan shape, checked in code (mp-425)

## mp-234 · The draft sits in the plan bar, and Confirm lands on the shopping list
- category: Planning a week
- status: approved
- folded: mp-235, mp-652
- image: none
- screen: Vana chat plan bar
- source: 02-contract.md; plan-tab-v2.md; 05-flutter-feature.md; memory 09-03

**Context.** The plan bar is pinned above the message box and shows the meals picked so far.

**Question.** Where does the draft live, and what happens on Confirm?

**Decision.** The draft shows only in the plan bar, where meals can be removed or their servings changed. Confirm is only in the Review sheet. Confirming shows a "you're set" card and lands on the Food tab's shopping list; spreading meals across days is optional.

**Why.** The shopping list is the next thing the athlete needs after planning.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-234, mp-235, mp-652

## mp-238 · Meal planning lives in the Food tab and opens on the plan
- category: Plan tab and meals
- status: approved
- folded: mp-139
- image: none
- screen: Food tab
- source: synthesis-and-recommendations.md; 05-flutter-feature.md

**Context.** The Food tab has Meals, Formulas and Shopping.

**Question.** Where does meal planning live?

**Decision.** It is the Plan section of the Food tab, not a tab of its own. It opens on this week's plan, with a note from Vana for each day; the chat is where the athlete goes for more, not where they start.

**Why.** The plan is what the athlete checks most; chatting is the exception.

**What else was considered.** A separate tab that opens on the chat.

> 2026-09-26 overhaul: rewritten from mp-238, mp-139

## mp-675 · Plans are a list the athlete can reuse
- category: Plan tab and meals
- status: approved
- folded: mp-674, mp-676, mp-677, mp-681, mp-687, mp-682, mp-683
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: The Plan tab.
- screen: Plan tab
- source: Lee in the terminal 2026-09-25 (testing-wave triage 2)

**Context.** An athlete makes a new plan most weeks.

**Question.** What happens to old plans?

**Decision.** Confirmed plans form a list, newest first. The athlete can open, edit, rename or delete any of them, or "Use this plan again" to copy it into this week as a new draft. This week's plan stays until a new one is confirmed. Drafts never confirmed are not listed. A draft replaced by a different confirmed plan stays in its own conversation, read-only, with "Use this plan instead"; its note says it stays in that conversation. An earlier plan can have servings changed or meals removed, but not new meals added; to add meals, the athlete uses the plan again.

**Why.** Athletes repeat weeks that worked.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-675, mp-674, mp-676, mp-677
> 2026-09-26 approved by Lee: what an earlier plan allows, checked in code (mp-681, mp-687)
> 2026-09-26 decided by Claude (Lee's delegation): replaced drafts stay read-only in their chat, as built; the note's promise is corrected (mp-682, mp-683)
> 2026-09-26 built (merged on mealplanning; dev deploy owed)

## mp-004 · The word is "meal", and a week of meals is a "batch"
- category: Plan tab and meals
- status: approved
- image: none
- screen: Plan tab
- source: synthesis-and-recommendations.md

**Context.** Earlier designs used "plate" and other words.

**Question.** What words does the app use?

**Decision.** Everything in the library or entered by the athlete is a "meal", never a "plate". A week of meals is a "batch". "Cooking session" appears only when batch cooking is on.

**Why.** One word per thing across every screen.

**What else was considered.** "Plate".

> 2026-09-26 overhaul: rewritten from mp-004

## mp-242 · The Meals tab is for browsing; meals join a plan from the plan
- category: Plan tab and meals
- status: approved
- image: docs/ssot/decisions/images/mealplanning/meals-tab.png
- caption: The Meals tab.
- screen: Meals tab
- source: memory 08-31; 05-flutter-feature.md

**Context.** The Meals tab shows the meal library.

**Question.** Can the athlete add meals to a plan from the Meals tab?

**Decision.** No. The Meals tab is for looking: Recents, My Foods, Assemblies and Recipes, with search and filters. Add and Swap show only when the athlete came from a plan row. Meals the athlete's allergies rule out are greyed, not hidden.

**Why.** Planning happens in one place.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-242

## mp-144 · A thumbs down means Vana will not suggest the meal again
- category: Plan tab and meals
- status: approved
- image: docs/ssot/decisions/images/mealplanning/meal-detail.png
- caption: A meal's detail page.
- screen: Meal detail
- source: recipe-directions-and-cooking-mode.md; 05-flutter-feature.md

**Context.** Each meal page has thumbs up and down.

**Question.** What does a vote do?

**Decision.** One vote per person per meal. A thumbs down keeps the meal out of Vana's suggestions (it still shows when browsing); a thumbs up ranks it higher.

**Why.** The athlete should never be offered a meal they said no to.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-144

## mp-418 · Meals show their photo or nothing
- category: Plan tab and meals
- status: approved
- folded: mp-145
- image: none
- screen: Plan tab
- source: Lee, from the category discussion on 2026-09-17

**Context.** Some library meals have a Dish photo and some do not (ADR 0003).

**Question.** What does a meal show where its picture would be?

**Decision.** Its Dish photo, the same one the Meals tab shows, or nothing at all: no placeholder box and no icon. Plans look the photo up from the library, so a photo added later appears in plans already made.

**Why.** A wrong or generic picture is worse than none.

**What else was considered.** A tinted placeholder square; drawn meal icons.

> 2026-09-26 overhaul: rewritten from mp-418, mp-145

## mp-678 · A plan never picks a meal without nutrition numbers
- category: Plan tab and meals
- status: approved
- folded: mp-688
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: The Plan tab.
- screen: Plan tab
- source: Lee in the terminal 2026-09-25 (testing-wave triage 2)

**Context.** 31 library meals had no calories or macros.

**Question.** What happens to meals with missing numbers?

**Decision.** Planning never picks a meal whose numbers are missing; it stays browsable. Every way into a plan (add, swap, the meal page, search) refuses it. The 31 meals get numbers, from a source where one exists, otherwise estimated from their ingredients and marked AI-estimated.

**Why.** A plan with blank numbers cannot be fuelled against.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-678
> 2026-09-26 approved by Lee: every path refuses, checked in code (mp-688)

## mp-146 · Every recipe says where its steps came from
- category: Recipes and cooking
- status: approved
- image: none
- screen: Meal detail
- source: memory 09-01; 05-flutter-feature.md

**Context.** Library recipes come from published sources, simple assemblies, or AI.

**Question.** Does the athlete see where a recipe's steps came from?

**Decision.** Yes. Steps taken word for word read "as published by X" with a link; AI-written steps carry a sparkle. Macros are marked approximate.

**Why.** Credit to the source, and honesty about what AI wrote.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-146

## mp-243 · Cooking mode shows one step per screen, with timers
- category: Recipes and cooking
- status: approved
- image: docs/ssot/decisions/images/mealplanning/cooking-mode.png
- caption: Cooking mode.
- screen: Cooking mode
- source: 05-flutter-feature.md; recipe-directions-and-cooking-mode.md; README

**Context.** Athletes follow a recipe while cooking.

**Question.** How does cooking mode work?

**Decision.** An overview, then one large step per screen, then a done screen asking for a thumbs up or down. Timers are read from each step's words and keep running between steps. The screen stays awake while cooking.

**Why.** Big steps and hands-free timers suit a kitchen.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-243

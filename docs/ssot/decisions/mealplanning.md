# Decisions: Meal planning and Vana

Feature: mealplanning
Feature name: Meal planning and Vana

## mp-001 · The assistant is called Vana
- category: Vana's voice and openers
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption: The Vana sheet open with her first message and two quick replies.
- svg2: docs/ssot/decisions/images/mealplanning/mp-001-2.svg
- screen: Vana chat
- source: synthesis-and-recommendations.md; memory 08-26

**Context.** The app's assistant had gone by three placeholder names. Sage was the early canvas, MealBuddy the Figma concept, Jade the shipped general chat. More screens were about to be drawn and each one needed a name on it.

**Question.** What is the assistant called?

**Decision.** She is called Vana, from Meal-vana, and "AI" is not part of her name. The one name is used everywhere in the app and in the prototype. Example: where the Figma concept said MealBuddy and the shipped chat said Jade, both are to say Vana, and a label such as "Mealvana AI" is not used.

**Why.** The placeholders were never meant to ship. One name was needed before more screens were drawn against the wrong one.

**What else was considered.** Mel, Endy, or keeping "Mealvana AI". None tied to the brand as directly, and "AI" in the name was unwanted.

**What it touches.** Every Vana surface, persona prompt, content keys.

**Details.** Precisely:
1. The assistant is named Vana, taken from Meal-vana, with no "AI" in the name.
2. The one name is used across the app and the prototype.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-002 · One Vana answers everything and picks an intent per exchange
- category: Vana's voice and openers
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_thread_light.png
- caption: The Vana sheet mid-conversation. The same Vana answers whatever the athlete asks.
- svg2: docs/ssot/decisions/images/mealplanning/mp-002-2.svg
- screen: Vana chat
- source: spec.md; CONTEXT.md; memory 09-09; Lee on the page 2026-09-13

**Context.** The app once had two assistants. Jade answered general questions from the coach and formula screens, and a separate planner was going to build meal plans. Vana replaced both in name, but the code, the prompts, and some coach-facing copy still carry Jade.

**Question.** Is there one assistant or several?

**Decision.** One. Jade is retired, and every place the athlete can reach Vana from talks to the same Vana with the same tools. She works out the Intent of each exchange from her own prompt, with no extra model call to sort the message first. Only the context she is handed changes with the screen, and it always includes the athlete's full Voodoo Doll. Example: the athlete who asks about a formula's coach feedback and later opens the Plan tab talks to the same Vana both times, and both times she has the whole Doll.

**Why.** Two characters would split what the athlete has told the app. A classifier is another model call and another thing to be wrong. Lee, on the page on 2026-09-13: one Vana, Jade retired everywhere, and every context carries the Doll.

**What else was considered.** Keep Jade for general chat and a separate planner for meals, with a classifier routing between them. It lost because the athlete would have to know which assistant to ask, and each would forget what the other was told.

**What it touches.** vana-chat function, chat screen, sheet, persona prompt, tool set, coach formula feedback.

**Details.** Precisely:
1. There is one Vana and no Jade.
2. Every entry point, whether the sheet, the Plan tab, a formula's coach feedback, or the events page, talks to the same Vana with the same tools.
3. She picks an intent per exchange from the prompt, and no classifier call runs before a turn.
4. What differs by entry point is the context she is handed, never who she is.
5. Every context always includes the athlete's full Doll.

> 2026-09-13 amended by Lee
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-003 · Each conversation is tagged general or meal-planning, and a new plan always starts a new one
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-003.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-003-2.svg
- screen: none (algorithm/data)
- source: spec.md

**Context.** Vana has two kinds of conversation. A general one opens from the sheet or the Plan tab's note and can be about anything. A meal-planning one starts when the athlete taps New meal plan and builds a week. Once there was one Vana, the two kinds stopped being separate products.

**Question.** Do general and meal-planning conversations still differ?

**Decision.** Only by a tag. Each conversation is tagged general or meal-planning, and the history list and the opener read that tag. Tapping New meal plan, or asking Vana a fresh question from a button, always starts a new conversation rather than continuing an old one, and every past conversation stays in history. Example: an athlete taps New meal plan on Monday and asks Vana a question from a button on Wednesday; that makes two new conversations, one tagged meal-planning and one tagged general, and both stay listed in history.

**Why.** The opener and the history list need the tag. Lee on 2026-09-13: a cold question or a new plan should feel like a fresh start, not a continuation.

**What else was considered.** Merge the kinds entirely. It lost because the opener and the history list still needed to tell them apart.

**What it touches.** Conversation history, opener selection.

**Details.** Precisely:
1. General and meal-planning stay as a tag on each conversation, read by the history list and the opener.
2. Tapping New meal plan, or asking Vana cold from a button, always starts a new conversation rather than continuing an old one.
3. Every past conversation stays listed in history so the athlete can return to it.

> 2026-09-14 amended by Lee
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-004 · The word is "meal" and the week is a "batch"
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: The Plan tab listing this week's meals.
- svg2: docs/ssot/decisions/images/mealplanning/mp-004-2.svg
- screen: Plan tab
- source: synthesis-and-recommendations.md

**Context.** The Sage canvas called a library entry a "plate" and the week a plan of plates. The meal library, then about 400 rows, already typed each entry by meal type. Copy for the Plan tab, the pickers and the shopping list was about to be written.

**Question.** What words does meal planning use?

**Decision.** Anything in the library, or entered by the athlete, is a "meal", never a "plate". The week of meals is a "batch". The words "cooking session" appear only when batch cooking is turned on. Example: the Plan tab lists this week's batch of meals, and with batch cooking off it never mentions a cooking session.

**Why.** The library already used meal types, so "meal" matched the data. One vocabulary keeps copy and code aligned.

**What else was considered.** "Plate", the wording of the earlier Sage canvas. It lost because the data never used it.

**What it touches.** All meal-planning copy and content keys.

**Details.** Precisely:
1. A library or user entry is a "meal", never a "plate".
2. The week is a "batch".
3. "Cooking session" appears only when batch cooking is on.

> 2026-09-14 approved
> 2026-09-14 picture refreshed at 1.26.0+1, 469da691, replacing test/features/meal_planning/presentation/goldens/plan_confirmed_light.png
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-005 · Race fuelling never comes from the model
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-005.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-005-2.svg
- screen: none (algorithm/data)
- source: synthesis-and-recommendations.md

**Context.** Race-day fuelling is the app's core. A deterministic module computes pre, during and post targets from the ratified nutrition specs. Xuan's AI Scenarios document had used race fuelling as the assistant's domain. Trials in June 2025 showed the model calling tools wrongly and passing wrong parameters.

**Question.** Where do Vana's fuelling numbers come from?

**Decision.** From the app's own fuelling calculator, never from the model. The calculator works out pre, during and post race targets from the ratified nutrition specs and gives the same answer every time. Vana reaches it, and the athlete's own records, through tools: upcoming events, activity history, macro targets and food suggestions for a session; she shows what a tool returns and never makes up a number or a meal. Example: asked what races are coming up, Vana looks at the athlete's event list and answers from it.

**Why.** Safety on the numbers, and usefulness on the questions. Lee on 2026-09-13: if an athlete asks what races are coming up, Vana must be able to look at the event list.

**What else was considered.** Xuan's AI Scenarios used race fuelling as the domain. That was rejected on 2026-06-17 on the same safety grounds.

**What it touches.** Persona guardrails, tool set.

**Details.** Precisely:
1. Race-day fuelling numbers come from the deterministic module, never from the model.
2. Vana reaches that module and the athlete's own records through tools: upcoming events, activity history, macro targets, and food suggestions for a session.
3. She presents what a tool returns and never invents a number or a meal.

> 2026-09-14 amended by Lee
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-006 · Vana diagnoses and adds, never runs a questionnaire
- category: Vana's voice and openers
- status: approved
- image: docs/new_mealplanning/figma/05-meal-prep-style.png
- caption: The MealBuddy interview step that was rejected.
- svg2: docs/ssot/decisions/images/mealplanning/mp-006-2.svg
- screen: Vana chat
- source: vana-chatbot-update-plan.md

**Context.** The MealBuddy Figma concept opened with a six-step interview. It asked for training schedule, goal, diet and allergies before showing anything. The app already holds all of that from onboarding, the calendar and the integrations.

**Question.** Does Vana ask the athlete for what the app already knows?

**Decision.** No. Before asking anything, Vana uses what she is handed and her tools. She asks only about things the app cannot know, and only when they matter to the plan. Example: she never asks for the training schedule, goal, diet or allergies, which the app holds from onboarding, the calendar and the integrations, but she may ask who is eating this week or what is in the fridge.

**Why.** Asking for what is on file undoes the feeling that she knows the athlete. Lee on 2026-09-13: use context and tools first, and ask only what they cannot answer.

**What else was considered.** MealBuddy's six-step wizard. It lost because every answer was already on file.

**What it touches.** Persona prompt, opener.

**Details.** Precisely:
1. Vana never asks for what the app already knows.
2. Before asking anything she uses the context block and her tools.
3. She may ask about things the app cannot know when they matter to the plan, such as who is eating this week or what is in the fridge.

> 2026-09-14 amended by Lee
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-007 · The planning opener asks one question first and stays fluid after it
- category: Vana's voice and openers
- status: approved
- image: docs/_archived/mealplanning_prototype/screenshots/figma/02_active_chat.png
- caption: The earlier chat concept the opener grew out of.
- svg2: docs/ssot/decisions/images/mealplanning/mp-007-2.svg
- screen: Vana chat
- source: vana-chatbot-update-plan.md; memory 09-03

**Context.** The planning opener is Vana's first turn after the athlete taps New meal plan. The 2026-08-31 version put a week frame and three dinners on screen before the athlete had said anything. Xuan's scenario and her v5 prototype opened with a short read of the week and one question instead.

**Question.** What does Vana's first turn show when a plan starts?

**Decision.** Two or three sentences about the athlete's week and one choice question whose chips carry labels only, with no meals. The first meal picker follows whatever the athlete answered, so it need not be dinners. A question that is not about planning gets an answer without meal suggestions, and once that is done Vana offers to start picking. Example: the athlete taps New meal plan and sees a short read of the week and one question, with no meals; the first picker then shows whichever meal the answer named, dinners or not.

**Why.** Lee ruled the question-first shape on 2026-09-03 and added the fluidity on 2026-09-13: no forced dinner-first, and a side question deserves an answer, not a meal carousel.

**What else was considered.** The 2026-08-31 opener that put a week frame and three dinners on screen. Withdrawn because it decided for the athlete before asking.

**What it touches.** Opener prompts, lifecycle, the presenting eval check.

**Details.** Precisely:
1. The planning opener writes two or three context sentences and asks one question with label-only chips.
2. No meals appear on the opener turn.
3. The first picker follows whatever the athlete answered, so it need not be dinners.
4. If the athlete asks something unrelated to planning, Vana answers it without recommending meals, and once that thread is done she offers to start picking.

> 2026-09-14 amended by Lee
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-008 · Every opener says the most relevant thing Vana knows
- category: Vana's voice and openers
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption: The sheet at rest on an opener.
- svg2: docs/ssot/decisions/images/mealplanning/mp-008-2.svg
- screen: Vana chat
- source: CONTEXT.md; memory 09-11; commit 1dedc493

**Context.** An opener is any first turn Vana writes. The planning opener, the sheet's general opener, and the moment openers before a workout or after one. The memory work gave Vana a full picture of the athlete, but it showed only in replies. First turns still read like a greeting from a bot.

**Question.** What does every opener lead with?

**Decision.** The most relevant thing Vana knows right now, picked from everything she holds: the weather, the race schedule, holidays, what is on screen and what the athlete has said before. Something personal is welcome when it is the most relevant thing, but it is not required. An opener never greets. Example: on a day when the race schedule matters most, the opener starts with the race, not with a hello.

**Why.** Lee on 2026-09-13: something personal is nice to have, not a must. The opener should weigh all the islands of information and lead with what matters most today.

**What else was considered.** none recorded

**What it touches.** Opener prompt in vana-chat, context builder.

**Details.** Precisely:
1. Every opener picks the most relevant thing to say from everything Vana holds: the weather, the race schedule, holidays, what is on screen, and what the athlete has said before.
2. A personal reference is welcome when it is the most relevant thing, not required.
3. An opener never greets.

> 2026-09-14 amended by Lee
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-009 · The opener waits up to 3.5 seconds for the read-back
- category: Vana's voice and openers
- status: rejected
- image: none
- caption:
- screen: none (algorithm/data)
- source: memory 09-11; commit 1dedc493

**Context.** When a conversation opens, the previous one is read back in the background to pull out new notes. The opener wants those notes so it can mention what the athlete said last time. On dev the full read-back took about seven seconds.

**Question.** How long a first turn may wait for it.

**Decision.** The opener waits up to 3.5 seconds for the previous conversation's extraction to finish. If it is late, the athlete's last words go first in the LAST TALKS line instead, and the opener goes out without the new notes.

**Why.** Waiting for the full extraction took about seven seconds on dev, too long for a first turn. The last words give the opener something personal either way.

**What else was considered.** Wait for extraction to finish every time. It lost on the seven-second first turn.

**What it touches.** vana-chat opener, readBackWithin.

> 2026-09-14 rejected: whoa whoa this is too deterministic.  I don't know why were are doing this.  we need to definitely revisit this.  htis has too much of a bad smell

## mp-010 · The one-time intro card was removed; the opener does its job
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-010-2.svg
- screen: Vana chat
- source: DEVIATIONS.md

**Context.** MealBuddy opened with a welcome screen of goal buttons. The plan adapted that into a one-time card at the top of the planning chat saying Vana had already done the homework, with three example chips. It was built the same day the question-first opener landed.

**Question.** Does the planning chat start with a welcome card?

**Decision.** No. A one-time card saying "Vana already did the homework", with three example chips, was built and removed the same evening. Vana's opener does that job. Example: an athlete who taps New meal plan sees Vana's opener first, with no card above it.

**Why.** Lee said "we don't need that block". The question-first opener already proves what Vana knows.

**What else was considered.** A dismissible card with three example chips. It lost because the opener already said the same thing.

**What it touches.** Planning chat screen.

**Details.** Precisely:
1. The one-time "Vana already did the homework" card was built and removed the same evening.
2. The opener does that job.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-011 · The voice contract is set per moment, with emoji banned
- category: Vana's voice and openers
- status: rejected
- image: none
- caption:
- screen: Vana chat
- source: vana-chatbot-update-plan.md

**Context.** The persona prompt sets how long and how warm Vana's turns are. The shipped persona had a flat cap of two sentences on every turn, which read as clipped. Xuan's scenarios were warm and used exclamation marks freely. A planning conversation has different moments, picking, presenting, explaining, and celebrating a confirmed week.

**Question.** Whether one length rule fits all of them.

**Decision.** Picking turns run at most two sentences. Presenting turns run up to four with one concrete athlete fact. Explaining is uncapped. A milestone congratulates by name with one exclamation allowed. Emoji stay banned, framing is minimums, no weight talk, medical referrals stay.

**Why.** It splits the difference between Xuan's warm scenarios and the shipped clipped persona. The flat two-sentence cap was the real blocker, not emoji.

**What else was considered.** A flat "max two sentences", which lost as the thing making her sound clipped. Xuan's exclamation-heavy tone, which is still an open question for her.

**What it touches.** Persona core prompt.

> 2026-09-14 rejected: this is ok but too rigid and structured.  i do want her in general to get to the point and to "unslop" meaning that we don't have unnecessary text but saying things like "with one concrete athlete fact" and wheree we are saying at most 2 sentences and up to four seems too rigid.  i hope we can convey to keep things short and to the point without such strict guidelines.  and yes ban emojis plese

## mp-012 · The server no longer cuts planning turns to two sentences
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-012.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-012-2.svg
- screen: none (algorithm/data)
- source: memory 09-03

**Context.** To keep planning turns short, the server used to cut each one to two sentences after the model had written it. The trimmed text was what the athlete saw and what was stored. Meanwhile the persona prompt was being rewritten with the per-moment rules above.

**Question.** Where is Vana kept brief?

**Decision.** In her prompt. The server no longer cuts each planning turn down to two sentences after it is written; only a guard against runaway turns of more than eight sentences remains. The cap on how much a turn may write went from 400 to 700 to 900 tokens (the units a model's output is counted and paid in), so longer turns have room. Example: a planning turn of three sentences used to reach the athlete, and the stored transcript, as two; now all three are shown and stored.

**Why.** A clamp trims text after the tokens were paid for, so it saved nothing. The clamped text was also what got stored, so the transcript lost what she said.

**What else was considered.** Keep the clamp and rewrite the persona. It lost because the prompt work would have been invisible on screen.

**What it touches.** chat.ts partsFromSteps, persona.

**Details.** Precisely:
1. The server no longer trims planning turns to two sentences.
2. Only an eight-sentence runaway guard remains.
3. The output cap went from 400 to 700 to 900 tokens so the longer moments have room.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-013 · Planning turns take six tool steps, general turns eight, four sends per ten seconds
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-013.svg
- screen: none (algorithm/data)
- source: 02-contract.md; walkthrough.md

**Context.** Each Vana turn can call several tools in a row before it answers. Each step is another model call and more tokens. The athlete can also send faster than the server should answer. A planning chat is mostly pickers and chips rather than prose.

**Question.** How much work may one Vana turn do?

**Decision.** A planning turn may run up to six tool steps before it answers, and a general turn up to eight; each step is another model call. Each athlete may send Vana at most four messages in any ten seconds. Her standing instructions (the system prompt) stay near 900 tokens, and what tools return is kept short. Example: an athlete who sends five messages within ten seconds has sent one more than the limit allows.

**Why.** Cost and brevity in a chat that is mostly widgets.

**What else was considered.** none recorded

**What it touches.** vana-chat.

**Details.** Precisely:
1. A planning turn may run six tool steps and a general turn eight.
2. Chat is rate-limited to four requests per ten seconds per athlete.
3. The system prompt is about 900 tokens and tool outputs are kept compact.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-014 · Every picker comes with a sentence and no narration before a tool call
- category: Vana's voice and openers
- status: approved
- image: test/features/meal_planning/presentation/goldens/meal_picker_light.png
- caption: A meal picker in chat, always introduced by text.
- svg2: docs/ssot/decisions/images/mealplanning/mp-014-2.svg
- screen: Vana chat
- source: 05-flutter-feature.md

**Context.** A meal picker is the carousel of meals Vana puts in the chat. The day-guidance tool is a deterministic server function: given a date, it reads that day's workouts, the macro budget, and the library's rest-day and race-week rules, and returns what to eat and why as data. Vana phrases that data and never computes it. In the walkthrough some pickers arrived with no text, "Other options" came back bare, Vana wrote "I need to check" before calling tools, and day questions sometimes got a guess instead of the tool.

**Question.** What must a turn that uses a tool look like?

**Decision.** A meal picker always comes with a sentence, and so does "Other options". A question about a particular day goes to the day-guidance tool, which reads that day's workouts, the macro budget and the library's rest-day and race-week rules, instead of getting a guess. Vana never says what she is about to do before calling a tool. Example: asked what to eat on a day in race week, Vana calls the day-guidance tool for that date and puts its answer in her own words, with no "I need to check" first.

**Why.** Bare widgets and "I need to check…" narration read badly in the walkthrough.

**What else was considered.** none recorded

**What it touches.** Persona prompt on server and prototype.

**Details.** Precisely:
1. A meal picker is never sent bare and "Other options" always carries text.
2. For a question about a specific day, Vana calls the day-guidance tool rather than guessing.
3. She never narrates before a tool call.

> 2026-09-14 amended by Lee
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-015 · Status lines replace narration and there is no fake progress
- category: Vana's voice and openers
- status: approved
- image: docs/new_mealplanning/figma/14-generating.png
- caption: MealBuddy's progress ring, which was rejected.
- svg2: docs/ssot/decisions/images/mealplanning/mp-015-2.svg
- screen: Vana chat
- source: vana-chatbot-update-plan.md

**Context.** While a tool runs the athlete waits a few seconds and sees nothing. MealBuddy filled that gap with a progress ring showing a percentage. Early Vana filled it with prose narrating what she was about to do.

**Question.** What does the athlete see while a tool runs?

**Decision.** A short line for that tool beside a small picture of Vana, such as "Finding options that fit your week…". Anything Vana wrote before the tool call is dropped from the stored transcript, and there is no progress ring with a percentage. Example: while Vana looks for meals, the athlete sees "Finding options that fit your week…" until the picker arrives, not a percentage like MealBuddy's ring.

**Why.** MealBuddy's ten percent ring was fake. Narrating tool calls wastes tokens.

**What else was considered.** A generic thinking line, which lost as less informative. A progress ring, which lost because it had no real number behind it.

**What it touches.** Message card status row, status content keys.

**Details.** Precisely:
1. While a tool runs, a short content line per tool sits beside a mini avatar, such as "Finding options that fit your week…".
2. Pre-tool narration is dropped from the transcript.
3. There is no percentage ring.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-016 · A choice-only step keeps its sentence in the stored transcript
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-016-2.svg
- screen: Vana chat
- source: ticket 09; memory 09-11

**Context.** The rule above drops text written before a tool call when the transcript is stored. An opener is a sentence or two followed by a choice question, and the choice question is itself a tool. So on reload the opener's prose vanished while the live stream had shown it. Found while building the moments.

**Question.** Is the text before a choice question kept when the chat is saved?

**Decision.** Yes. Text Vana writes before a tool call is normally dropped when the conversation is stored, but a step whose only tool is a choice question keeps its text. Without this, an opener's sentences showed while it streamed in and were gone after a reload. Example: Vana's opener writes two sentences and asks a choice question; the athlete closes and reopens the chat and still sees both sentences above the question.

**Why.** The no-narration rule dropped the opener's prose on reload while the live stream had shown it.

**What else was considered.** none recorded

**What it touches.** chat.ts partsFromSteps.

**Details.** Precisely:
1. A step whose only tool is a choice question keeps its text when the transcript is stored.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-017 · Unknown part kinds are dropped, not errors
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-017-2.svg
- screen: Vana chat
- source: 02-contract.md

**Context.** The server streams a conversation to the app as message parts. Text, a picker, a choice question, a receipt, and so on. New part kinds get added on the server as features land, and older app versions stay in the field for months. The coach chat had already met this problem.

**Question.** What does an older app do with a message part it has never seen?

**Decision.** It skips that part and shows the rest of the message. The server sends each message in parts, such as text, a meal picker, a choice question or a receipt, and new kinds of part are added as features land while older app versions stay in use for months. The coach chat already works this way. Example: on an older app, a message holding a sentence, a picker and a kind of part added later shows the sentence and the picker, and the new part is simply left out.

**Why.** A newer server must never break an older app.

**What else was considered.** Fail the message on an unknown kind. It lost because every server release would break shipped clients.

**What it touches.** Part parser, shipped clients.

**Details.** Precisely:
1. The app ignores any message part kind it does not know and renders the rest of the message.
2. This is the same rule the coach chat uses.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-018 · The chat model is Haiku, with cost recorded per eval case
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-018.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-018-2.svg
- screen: none (algorithm/data)
- source: 03-backend.md; walkthrough.md; spec.md

**Context.** Every Vana turn is a model call, and a planning conversation is many turns. The prototype defaulted to Sonnet, the larger and dearer model. The personalisation evals run by hand against dev and report pass or fail.

**Question.** Which model runs Vana's chat, and how would we argue for changing it?

**Decision.** Vana's chat runs on Claude Haiku 4.5, the smaller and cheaper Claude model, through the AI Gateway, and embeddings (the number fingerprints used to compare pieces of text) come from text-embedding-3-small. Sonnet, the larger and dearer model, is used only when a setting on the server asks for it. Every eval case records how many tokens went in and came out, so a later switch is argued with numbers. Example: if someone proposes moving the chat to Sonnet, the eval run shows each case's input and output tokens on both models, and the cost per turn is a figure, not a feeling.

**Why.** Cost per turn. A later model decision should be made with numbers rather than a feeling.

**What else was considered.** Sonnet by default, as the prototype did. It lost on cost per turn.

**What it touches.** All Vana model calls, eval scripts.

**Details.** Precisely:
1. The default chat model is Claude Haiku 4.5 through the AI Gateway.
2. Embeddings use text-embedding-3-small.
3. Sonnet is only an environment override.
4. Every eval case records its input and output tokens.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-019 · About 1.5k input tokens per turn for the context block is accepted
- category: Vana's voice and openers
- status: rejected
- image: none
- caption:
- screen: none (algorithm/data)
- source: spec.md

**Context.** The context block is everything Vana knows about the athlete, written into the prompt. Profile, this week's workouts, the race, memories, likes, goals and what is on screen. It comes to about 1.5k tokens. That could be sent every turn or fetched by a tool only when the model asks.

**Question.** Whether the spend was worth it.

**Decision.** The whole athlete context is injected on every turn on Haiku. The extra spend of about 1.5k input tokens per turn is accepted.

**Why.** Personalisation is worth more than the token spend. A tool the model may or may not call is not personalisation.

**What else was considered.** Fetch context lazily by tool call. It lost because the model would skip the call and answer as a stranger.

**What it touches.** vana-chat.

> 2026-09-14 rejected: wait do we send the entire context each time??  is this not wasteful?  does claude not remember this context in a conversation?

## mp-020 · Vana reads what she knows where it lives and keeps no copy
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-020.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-020-2.svg
- screen: none (algorithm/data)
- source: spec.md; memory 09-09

**Context.** The Doll is the name for everything Vana knows about a person. Most of it already lives somewhere. The user record, the calendar, the events, the meal votes, the onboarding survey. One option was a separate profile table for Vana with those fields copied in.

**Question.** Does Vana keep her own copy of what she knows about a person?

**Decision.** No. Each time she needs it, the server builds the Voodoo Doll from the records that already hold each Fact: the user record, the calendar, the events, the meal votes, the onboarding survey. The one record that belongs to the Doll itself is the memory table. What she is handed is short, only the facts that matter for this turn, and anything deeper she looks up with a tool. Example: an athlete switches their diet to vegetarian in the app on 3 October; Vana's next plan reads vegetarian from the user record, because there is no second copy left saying otherwise.

**Why.** No profile field is stored twice, so nothing drifts. Lee on 2026-09-14: the view must not be too large or carry extraneous data, and a full set of tools covers the rest.

**What else was considered.** A separate profile or preferences store copied from the source records. It lost because a copy drifts.

**What it touches.** vana-chat context builder.

**Details.** Precisely:
1. Everything Vana knows about a person is assembled on the server at request time from the records that already own it.
2. Only the memory table belongs to the Doll.
3. The assembled block is short: the most relevant facts for this turn, nothing the prompt does not use.
4. Anything deeper is reached through tools, not carried in the block.

> 2026-09-14 rewritten from Lee's words
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-021 · Both conversation modes read the full Doll
- category: Vana's memory
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-021-2.svg
- screen: Vana chat
- source: spec.md; archive ticket 03

**Context.** Vana chat had two modes: planning, for building meals for the week, and general, for everything else. Planning conversations got the full context block; general ones got a first name and today's date, and the prompt opened by saying nothing was preloaded. So "what's my workout tomorrow" in the sheet needed a tool call the model might not make. That was the real "she doesn't know me".

**Question.** Does Vana know the athlete as well in a general chat as when planning?

**Decision.** Yes. General mode gets the same context block planning mode gets, plus three lines: LIKES from the athlete's Meal feedback, GOALS from the onboarding survey, and SITUATION for what is on screen. The general prompt no longer opens by telling Vana that nothing is preloaded. Example: an athlete asks in the sheet "what's my workout tomorrow"; tomorrow's workout is already in the block, so Vana can answer with no tool call.

**Why.** General mode carried only a first name and today's date, so Vana answered as a stranger. "What's my workout tomorrow" should answer without a tool call.

**What else was considered.** Leave general mode relying on tool calls the model may or may not make. It lost because the model often did not make them.

**What it touches.** systemPrompt, buildAthleteContext.

**Details.** Precisely:
1. General mode gets the same context block planning mode gets, plus LIKES from meal votes, GOALS from the onboarding survey and SITUATION for what is on screen.
2. The general prompt's "nothing is preloaded" opening was removed.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-022 · A Memory is one margin-note sentence
- category: Vana's memory
- status: approved
- image: test/features/meal_planning/presentation/goldens/memory_list_light.png
- caption: The "What Vana knows" list, one sentence per row with source and date.
- svg2: docs/ssot/decisions/images/mealplanning/mp-022-2.svg
- screen: Vana settings
- source: spec.md; CONTEXT.md

**Context.** Vana's store held mixed records. Settings, summaries, preferences and meal feedback sat together with no rule about what belonged. Two writers were about to be added, the model on its own and a background extractor. Both needed the same test for what to keep.

**Question.** What counts as a Memory?

**Decision.** One sentence a good dietitian would write in the margin of the person's file, and only if it changes how Vana plans next time. What the athlete asked for, this week's plan and anything the app already records as a Fact are not Memories. Example: "Wednesdays are long days" is a Memory; "asked for a pasta dinner tonight" is not, and neither is an allergy, which is a Fact.

**Why.** One literal rule keeps the store small and useful. The extractor and the model share it.

**What else was considered.** Store preferences, summaries and meal feedback as one mixed record. It lost because nothing then had a clear owner or a limit.

**What it touches.** Extractor prompt, persona prompt, user_memories.

**Details.** Precisely:
1. A Memory is one sentence a good dietitian would write in the margin of the person's file, and only if it changes how Vana plans next time.
2. Not what was asked, not this week's plan, not anything already a Fact.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-023 · Meal votes are Facts read in place, never moved into Memory
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-023.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-023-2.svg
- screen: none (algorithm/data)
- source: spec.md; memory 09-09

**Context.** Meal detail has thumbs up and down. Those votes already live in the meal feedback table and drive search. Lee had earlier floated a new meal preferences table for Vana. The Formula Kit already has its own fuelling-product preferences with screens.

**Question.** Where do Vana's meal likes come from?

**Decision.** From the thumbs votes athletes already give on a Meal's detail page. Those votes are Meal feedback, a Fact, and Vana reads them every turn as a LIKES line straight from the existing meal feedback table. There is no new preferences table, and the Formula Kit's fuelling-product preferences and their screens stay as they are. Example: an athlete gives a salmon bowl a thumbs down on 2 October; the vote is stored once, in the table that also drives search, and Vana reads it from there.

**Why.** Formula Kit keeps working and nothing is stored twice. Lee reversed his own earlier idea of a meal preferences table.

**What else was considered.** A new meal preferences table. It lost because the votes already existed and a second copy would drift.

**What it touches.** Context builder, meal feedback table.

**Details.** Precisely:
1. Thumbs votes on meals are Facts, read every turn as a LIKES line from the existing meal feedback table.
2. There is no new preferences table.
3. The fuelling-product preferences and their screens are untouched.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-024 · Three writers save Memories: the athlete's ask, Vana herself, and a read of the finished chat
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-024.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-024-2.svg
- screen: none (algorithm/data)
- source: spec.md

**Context.** Vana had a remember tool she could call when the athlete said something worth keeping. In practice she never called it. The only thing writing Memories was the weekly debrief. So the store stayed empty for most people.

**Question.** Who writes Memories, and when?

**Decision.** Three writers. The athlete saying "remember this"; Vana on her own, when something meets the margin-note rule (mp-022: a sentence that changes how she plans next time); and a background extraction, Vana reading the conversation after it ends. Example: an athlete mentions in passing that they train before work and never asks Vana to keep it; if she did not save it during the chat, the read after the chat ends can still write it.

**Why.** The remember tool alone was never called. Only the weekly debrief wrote anything.

**What else was considered.** A scheduler that extracts on a timer, which lost as needing a cron. Extraction on every turn, which lost on cost.

**What it touches.** vana-chat, extractor, memory table.

**Details.** Precisely:
1. Memories are written three ways: by an explicit "remember this" from the athlete, by the model on its own when the margin-note rule is met, and by a background extraction after a conversation ends.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-025 · An explicit "remember" always calls the tool
- category: Vana's memory
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-025-2.svg
- screen: Vana chat
- source: archive ticket 05

**Context.** The margin-note rule tells Vana to skip a note that is already known. In testing the athlete said "remember Wednesdays are long days" and a Wednesday note was already in her context. So she skipped the request and said nothing was saved.

**Question.** If the athlete says "remember this", does Vana always save it?

**Decision.** Yes. When the athlete asks outright, Vana calls her remember tool every time and lets the server decide whether the note is new or a refresh of one it holds. The margin-note rule, which tells her to skip a note that is already known, applies only to notes she takes on her own. Example: in testing, an athlete said "remember Wednesdays are long days" while a Wednesday note was already in Vana's context, so she skipped it and said nothing was saved; under this rule she calls the tool and the server decides.

**Why.** A Wednesday note already in the context made her skip an explicit request.

**What else was considered.** One rule for both triggers. It lost because it made her ignore the athlete.

**What it touches.** Persona, remember tool description.

**Details.** Precisely:
1. When the athlete asks, Vana calls remember every time and lets the server decide whether it is new or a refresh.
2. The margin-note rule applies only to notes she takes on her own.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-026 · Finished conversations are read back silently when the next one opens
- category: Vana's memory
- status: rejected
- image: none
- caption:
- screen: none (algorithm/data)
- source: spec.md; archive ticket 06

**Context.** Things said in passing during a conversation should be known next time without anyone saying "remember". Something has to read the finished conversation and pull those out. Lee wanted the simplest thing that worked and was wary of the cost of doing it every turn.

**Question.** When and how a finished conversation is mined.

**Decision.** Opening a conversation feeds the newest unread previous one to a single Haiku call. That call writes zero to three Memories and one episode sentence. It claims the conversation first so it is never read twice, and it runs in the background. Read-back is limited to three a minute. There is no scheduler.

**Why.** A fact said in passing should be known next time without a "remember". It needs no cron and never interrupts the live conversation.

**What else was considered.** A scheduled job, which lost as needing a cron. Extracting at the end of the same conversation, which lost because a conversation has no clear end.

**What it touches.** extract.ts, vana_conversations.read_back_at, conversation list summary.

> 2026-09-14 rejected: we need to think through this a bit better.   this causes problems discussed before I think where we are waiting for this summary.  i can't think of anything else but perhaps we can do some research and find some clever other ideas

## mp-027 · Extracted Memories are never announced
- category: Vana's memory
- status: approved
- image: test/features/meal_planning/presentation/goldens/memory_list_light.png
- caption: The settings list that serves as the only audit trail.
- svg2: docs/ssot/decisions/images/mealplanning/mp-027-2.svg
- screen: Vana settings
- source: spec.md

**Context.** When the athlete says "remember this", a small card in the chat confirms it. The background extraction now learns things nobody asked her to keep. Vana settings has a list of everything she holds.

**Question.** Does Vana tell the athlete when she learns something quietly?

**Decision.** No. What the background extraction learns produces no card and no mention in the chat. The small "remembered" card in the chat stays only for when the athlete asked her to remember something, with the remember tool. The flat list in Vana settings is where the athlete can see everything she holds. Example: after a chat about a race weekend, the extraction saves "prefers rice to pasta before long rides"; nothing appears in the chat, and the sentence shows up in the list in Vana settings.

**Why.** Vana should read as attentive, not surveilling.

**What else was considered.** Show a card each time something is learned. It lost because it reads as being watched.

**What it touches.** Vana chat, Vana settings.

**Details.** Precisely:
1. Extraction produces no card and no mention in the conversation.
2. The in-chat "remembered" card stays only for the explicit remember tool, used when the athlete asked her to remember.
3. The flat list in settings is the audit trail.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-028 · A near-repeat of a Memory refreshes the old one instead of adding a second
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-028.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-028-2.svg
- screen: none (algorithm/data)
- source: spec.md; archive ticket 05

**Context.** With three writers, the same note can arrive more than once in slightly different words. On dev the debrief learning had been written twice. Each Memory is stored with an embedding, a numeric fingerprint of its meaning.

**Question.** What happens when the same note arrives twice in different words?

**Decision.** The old note stays and its confirmed date is refreshed; no second row is added. "Near" means a match of 0.95 or more between embeddings, numeric fingerprints of each sentence's meaning. If that comparison cannot be made, the note is saved anyway, because a repeat is better than a lost note; keyed Memories keep one row per key and episodes one per conversation. Example: on dev the debrief's learning was written twice; under this rule the second write only refreshes the first row's date.

**Why.** The store must not fill with the same note. A duplicate beats a lost note.

**What else was considered.** Exact-text dedupe. It lost because the same fact rarely arrives in the same words.

**What it touches.** memory.ts rememberFact, recall.

**Details.** Precisely:
1. A new sentence within 0.95 embedding similarity of an existing Memory refreshes that row's confirmed date instead of inserting.
2. If the embedding call fails the note is written anyway.
3. Settings keep one row per key and episodes one row per conversation.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-029 · Conflicting Memories both stay
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-029.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-029-2.svg
- screen: none (algorithm/data)
- source: spec.md

**Context.** People change. An athlete may say they are vegetarian and months later say they eat fish. Both sentences can end up in the store. A full answer would detect the contradiction and mark the older note as superseded.

**Question.** What happens when two Memories disagree?

**Decision.** Both stay. Nothing checks for contradictions: each Memory keeps its date, and Vana weighs how recent each one is when she reads them. Example: an athlete says on 3 March that they are vegetarian and on 9 June that they now eat fish; both sentences stay, dated, and Vana reads the June one as the newer.

**Why.** A supersedes chain waits until a real user hits a real contradiction.

**What else was considered.** Contradiction detection and a supersedes mechanism. It lost as work for a problem nobody had yet.

**What it touches.** memory.ts.

**Details.** Precisely:
1. There is no contradiction handling.
2. Conflicting Memories both stay, each with its date, and the model weighs recency when it reads them.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-030 · Swaps, skips and repeats never write a Memory; only the debrief learns from behaviour
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-030.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-030-2.svg
- screen: none (algorithm/data)
- source: spec.md; memory 09-09

**Context.** The app sees what the athlete does with a plan. Meals swapped out, meals skipped, the same meal logged again and again. Those patterns could be turned into preferences without anyone saying a word. The weekly debrief already asks how the week went and writes from the answers.

**Question.** Can what the athlete does, without saying anything, become a Memory?

**Decision.** No. Swapping a meal out, skipping one or logging the same one again and again never writes a Memory. The weekly debrief, where Vana asks how the week went, is the only writer that learns from what the athlete did. Example: an athlete swaps out the salmon three weeks running and no Memory is written; if they say "I'm off salmon" in the debrief, that answer can become one.

**Why.** The debrief keeps the person in the loop. Silent inference would not.

**What else was considered.** Infer preferences from logging patterns. It lost because the athlete would never know why Vana changed.

**What it touches.** Memory writers.

**Details.** Precisely:
1. Swaps, skips and repeated logs never write Memories.
2. The weekly debrief is the only behaviour-derived writer.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-031 · Debrief learnings feed the next plan
- category: Vana's memory
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-031-2.svg
- screen: Vana chat
- source: DEVIATIONS.md

**Context.** After a plan week ends, Vana's next opener asks how it went. The answers are recorded as a debrief. Xuan's spec asks that the app learn from outcomes, not just collect them.

**Question.** Does the next plan change because of what the athlete said in the debrief?

**Decision.** Yes. Recording a debrief writes a debrief row and one to three Memories marked as coming from the debrief. The context block then carries a LAST WEEK line, so Vana's first proposal for the next week reacts to it. Example: an athlete repeated two meals and says the salmon did not work; the next first proposal opens "kept the two you repeated, dropped the salmon".

**Why.** Xuan's spec asks for learning from outcomes.

**What else was considered.** none recorded

**What it touches.** recordDebrief, context builder.

**Details.** Precisely:
1. Recording a debrief writes a debrief row plus one to three Memories marked as from the debrief.
2. A LAST WEEK line in the context makes the next first proposal react, for example "kept the two you repeated, dropped the salmon".

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-037 · What Vana knows is one flat list; the kinds of Memory stay out of sight
- category: Vana's memory
- status: approved
- image: test/features/meal_planning/presentation/goldens/memory_list_light.png
- caption: The flat list, newest first, no kind tags.
- svg2: docs/ssot/decisions/images/mealplanning/mp-037-2.svg
- screen: Vana settings
- source: spec.md; archive ticket 08

**Context.** Vana settings has a screen listing what she holds about the athlete. In code, Memories come in kinds. Plain notes, keyed settings such as batch cooking and coverage, and episodes. The glossary had also called some of them "Decisions". Facts such as allergies live in their own screens.

**Question.** What does the athlete see of what Vana holds about them?

**Decision.** One flat list in Vana settings: every Memory, newest first, as a sentence with its source and date, with no tag for its kind, and any row can be deleted. Keyed Memories such as batch cooking show as plain sentences too. Episodes are left out, Facts such as allergies are changed on their own screens, and the old glossary word "Decision" for a kind of Memory is retired. Example: an athlete who told Vana they batch cook sees that as one sentence with its source and date among the rest, and can delete it like any other row.

**Why.** The athlete should see and remove anything Vana holds without learning the internal kinds.

**What else was considered.** Group by kind, which lost as exposing internals. List Facts too, which lost because Facts already have their own screens.

**What it touches.** Vana settings screen, watchMemories.

**Details.** Precisely:
1. Settings shows every Memory newest first as a sentence with its source and date, with no kind tag, and any row can be deleted.
2. Keyed settings appear as sentences.
3. Episodes are excluded.
4. Facts are edited where they live.
5. The glossary word "Decision" is retired.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-039 · A season line and a budget clause exist, grocery deals do not
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-039.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-039-2.svg
- screen: none (algorithm/data)
- source: vana-chatbot-update-plan.md

**Context.** The spec's headline moment was Vana planning around this week's grocery deals, and MealBuddy, the Figma concept for the assistant, showed a "gathering coupons" step. There is no source of grocery prices, and at the time the profile had no home location either. Season and budget could be done from what the app already has.

**Question.** Can Vana plan around the season, a budget and this week's grocery deals?

**Decision.** Season and budget, yes; deals, no. The context block carries a SEASON line from a fixed month-by-month table, and a BUDGET clause if the athlete ever said "keep it under N dollars". Grocery deals, coupons and an estimated cost of the shopping list are not built. Example: an athlete planning in October gets a SEASON line from the table's October row and a BUDGET clause from what they once said about spending, and never sees a "gathering coupons" step.

**Why.** There is no pricing data source. Revisit if a static price table lands.

**What else was considered.** MealBuddy's "gathering coupons" and recipe prices. They lost because there was nothing to gather.

**What it touches.** season.ts, context.ts.

**Details.** Precisely:
1. The context carries a SEASON line from a static month table and a BUDGET clause if the athlete ever said "keep it under N dollars".
2. Grocery deals, coupons and a list cost estimate are not built.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-040 · Vana finds Memories by meaning match, with no trained model of the athlete
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-040.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-040-2.svg
- screen: none (algorithm/data)
- source: spec.md; memory 09-09

**Context.** In the Voodoo Doll design session on 09-09 the question was how far personalisation should go. Memories are already found by embedding similarity, comparing numeric fingerprints of each sentence's meaning, and that works. A trained model of each athlete's preferences would need many weeks of data per person.

**Question.** Does "she knows me" need a trained model of each athlete?

**Decision.** No. Finding Memories by meaning match (embedding recall) already works, and it stays the only way Vana looks them up. There is no trained model of an athlete's preferences and no change to how the model calls are arranged. Example: an athlete who joined on 1 October has no weeks of history to train a model on, but on 2 October recall can already find the note they gave Vana on day one.

**Why.** The pattern in place already works, and a trained user model needs data no user has.

**What else was considered.** A trained preference model. It lost for lack of training data.

**What it touches.** Memory recall.

**Details.** Precisely:
1. Embedding recall stays the only retrieval pattern.
2. No trained preference model and no change to how the model is orchestrated.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-041 · Coach mode never reads an athlete's Doll
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-041.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-041-2.svg
- screen: none (algorithm/data)
- source: spec.md

**Context.** Coaches use the app too, with their own portal and a chat with each athlete. A coach could in principle ask Vana about an athlete and get answers built from that athlete's Facts and Memories.

**Question.** Can a coach's Vana see what Vana knows about an athlete?

**Decision.** No. Coach mode is out of scope for this work: when a coach talks to Vana, she does not see the athlete's Facts or Memories. Example: a coach asks Vana on 7 October how an athlete's week is going; Vana has none of that athlete's Facts or Memories to answer from.

**Why.** Scope and privacy.

**What else was considered.** Extend the Doll to coaches. It lost on privacy and on scope.

**What it touches.** Coach portal.

**Details.** Precisely:
1. Coach mode is out of scope.
2. A coach's Vana does not see the athlete's Facts or Memories.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-042 · Onboarding is untouched, with no likes step
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-042.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-042-2.svg
- screen: none (algorithm/data)
- source: spec.md

**Context.** Onboarding already asks the survey questions that give Vana her GOALS line. One idea was a new onboarding step asking what foods the athlete likes so the first plan lands better. Meal votes already give a LIKES line.

**Question.** Does onboarding gain a step asking what foods the athlete likes?

**Decision.** No. Onboarding stays as it is: Vana's LIKES line comes from Meal feedback and her GOALS line from the survey onboarding already runs. Vana never asks for likes. Example: a new athlete finishes the same survey as before, which gives Vana her GOALS line; their first thumbs up on a Meal's detail page starts the LIKES line.

**Why.** The app already holds the data.

**What else was considered.** Add a likes step to onboarding. It lost because votes already carry the same signal.

**What it touches.** Onboarding.

**Details.** Precisely:
1. Onboarding does not change.
2. LIKES come from meal votes and GOALS from the existing survey.
3. Vana never asks for likes.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-043 · The Situation travels with each message and is never stored
- category: Situation awareness
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-043.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-043-2.svg
- screen: none (algorithm/data)
- source: spec.md; archive ticket 04

**Context.** When the athlete opens Vana from a screen and asks "is this enough", "this" means whatever is on that screen: a ride, a meal, a day. The server has to learn what that is. Three ways were open: store the current screen on the server as the athlete moves, let the app write a sentence about it, or let the app send only ids.

**Question.** How does the server learn what is on the athlete's screen?

**Decision.** The app sends only ids with each message: the route, meaning the name of the screen, plus the id of the main thing on it, the date and the meal slot. The server turns those ids into one sentence for Vana. The app never sends names or free text, and nothing is written to any table. Example: an athlete looking at a meal of two bagels asks Vana "is this enough?"; the message carries the meal detail route and that meal's id, the server looks the meal up and writes one sentence naming it, and nothing about the screen is saved.

**Why.** Vana answers about what is in front of the athlete, and the app neither leaks nor stores what is on the screen.

**What else was considered.** Store the current screen server-side, which lost as state that goes stale. Let the client compose the text, which lost because the client would be sending names.

**What it touches.** Every screen with a situation scope, situation.ts resolver.

**Details.** Precisely:
1. The client sends the route plus the primary entity id, date and slot with each message.
2. The server resolves those ids into one sentence.
3. Clients never send names or free text, and nothing is written to any table.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-044 · Fifteen screens name what is in view, the rest send only their route
- category: Situation awareness
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-044.svg
- screen: none (algorithm/data)
- source: spec.md; archive ticket 04

**Context.** Not every screen has a thing in view worth naming. The Plan tab has a plan and a date. Meal detail has a meal. The fuel log has an activity. Settings has nothing.

**Question.** Which screens tell Vana what is on them, and which only say where the athlete is?

**Decision.** Fifteen screens name the thing in view: the Plan tab sends the date and the plan, meal detail the meal, the fuel log and the session plan the activity, the event screens the event, the meal-log screens the date and the meal slot, and the main tabs the date. Every other screen, Settings among them, sends its route alone. Example: asked from the fuel log of a ride, the message to Vana carries that ride's activity id; asked from Settings, it carries only the Settings route.

**Why.** Fifteen screens have something in view worth naming. The rest only need their route.

**What else was considered.** none recorded

**What it touches.** Fifteen wired screens.

**Details.** Precisely:
1. The Plan tab sends date and plan.
2. Meal detail sends the meal.
3. Fuel log and session plan send the activity.
4. Event screens send the event.
5. Meal-log screens send date and slot.
6. The main tabs send the date.
7. Every other screen sends its route alone.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-045 · The session screen is the activity and the Plan tab is the meal plan
- category: Situation awareness
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-045.svg
- screen: none (algorithm/data)
- source: archive ticket 04; memory 09-09

**Context.** Two things are called a plan. The session screen shows an activity's fuel plan and its route is named plan. The meal-planning Plan tab is a segment of the Food tab. The spec's screen table had the two the wrong way round, so the fuel plan would have reported a meal plan.

**Question.** When a route says "plan", which plan does it mean?

**Decision.** Two things in the app are called a plan. The routes named plan and current plan belong to the session screen, so they point at the activity's fuel plan. The meal-planning Plan tab is the Food tab's route with its Plan segment selected. Example: an athlete on the session screen for a ride asks Vana a question, and Vana is told about that ride's fuel plan, not the week's meal plan.

**Why.** The spec's screen table had the two routes the wrong way round.

**What else was considered.** none recorded

**What it touches.** Situation table.

**Details.** Precisely:
1. The routes named `plan` and current plan resolve to an activity's fuel plan.
2. The meal-planning Plan tab is the food route with the plan tab selected.
3. This corrects the spec's screen table, which had the two routes the wrong way round.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-046 · A screen's report counts only while that screen is on top
- category: Situation awareness
- status: approved
- image: docs/ssot/decisions/images/mealplanning/settings.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-046-2.svg
- screen: Settings
- source: ticket 06

**Context.** A screen with something in view reports it when it appears. Most screens, settings among them, report nothing. So the last report stood until another screen replaced it. From settings, Vana went on speaking about the fuel log the athlete had left.

**Question.** How long does what a screen told Vana keep counting?

**Decision.** Only while that screen is on top. The app keeps track of which screen is on top, and a screen's report of what is in view is used only then; anywhere else the Situation is the route alone. When the athlete comes back to a screen, it reports again. Example: an athlete opens meal A, then meal B, then goes back, and Vana is told about meal A again; from Settings, which reports nothing, she is told only the Settings route, not the fuel log the athlete just left.

**Why.** Without it, settings kept speaking for the last scoped screen, such as the fuel log.

**What else was considered.** Let the last report stand until replaced. It lost because unscoped screens never replace it.

**What it touches.** Companion host, situation controller.

**Details.** Precisely:
1. The host tells the controller which route is on top.
2. A scoped report is used only while that route is on top.
3. Anywhere else the Situation is the route alone.
4. A scope reports again when its route comes back, so meal A to meal B and back reads as A again.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-047 · The frame around the main tabs reports each tab, and a tab's own report wins
- category: Situation awareness
- status: approved
- image: docs/ssot/decisions/images/mealplanning/timeline-launcher.png
- caption: The Timeline tab, one of the main tabs the shell reports for.
- svg2: docs/ssot/decisions/images/mealplanning/mp-047-2.svg
- screen: Main tabs
- source: ticket 06

**Context.** Timeline, Food, Learn and the other main tabs all share one route, and switching tabs does not change it. So the rule that a report counts only while its route is on top (mp-046) could not tell Food from Learn, and moving from Food to Learn left Food speaking.

**Question.** Who tells Vana which main tab the athlete is on?

**Decision.** The tab shell, the frame that holds the main tabs, reports each tab as the athlete switches to it. A tab that reports something of its own, such as the Plan tab, reports after the shell, and its report wins. Example: an athlete moves from Food to Learn and Vana is told Learn, where before Food kept speaking.

**Why.** Moving from Food to Learn no longer leaves Food speaking.

**What else was considered.** none recorded

**What it touches.** Main tab shell, Timeline, Learn.

**Details.** Precisely:
1. The tab shell reports for each main tab as the athlete switches.
2. A tab with its own scope, such as the Plan tab, reports after the shell and wins.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-048 · The last screen keeps speaking for 30 minutes, and Vana's own screens say nothing
- category: Situation awareness
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-048.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-048-2.svg
- screen: none (algorithm/data)
- source: archive ticket 04

**Context.** Opening Vana means leaving the screen you want to ask about: the sheet and the full-screen chat are screens of their own. If Vana's screens reported themselves, every question would be about Vana. If a report lived forever, an hour-old screen could answer a question about today.

**Question.** What happens to the Situation when the athlete opens Vana?

**Decision.** Opening Vana does not clear it. Vana's sheet and full-screen chat report nothing, so the screen the athlete opened Vana from keeps speaking. A report older than 30 minutes stops counting, so an hour-old screen cannot answer a question about today. Example: at 07:00 an athlete on a ride's fuel log opens the sheet and asks "is this enough?", and Vana is told about that ride; at 08:00, with no screen reporting since, that report no longer counts.

**Why.** The sheet and chat open over the screen the athlete cares about.

**What else was considered.** Clear on every route change. It lost because opening Vana is itself a route change.

**What it touches.** Situation controller.

**Details.** Precisely:
1. Opening a Vana route (the sheet or the full-screen chat) does not clear the Situation.
2. Vana routes report nothing.
3. A 30-minute staleness cut-off stops an hour-old screen answering.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-049 · Vana is everywhere, not home-first
- category: The sheet and launcher
- status: rejected
- image: docs/ssot/decisions/images/mealplanning/timeline-launcher.png
- caption: The launcher at bottom right of the Timeline tab.
- screen: Any screen with the launcher
- source: ticket 06; vana-sheet.md; archive ticket 10

**Context.** The launcher is the small glass button at bottom right that raises the Vana sheet. Before it, Vana was reached only from the Plan tab and the chat route. One plan was to put the launcher on the home tab first and widen later. The Situation work already let fifteen screens say what is in view.

**Question.** How far the launcher goes on day one.

**Decision.** The launcher appears on every ordinary screen from the start. Lee ruled.

**Why.** The Situation already reports from fifteen screens, so Vana has something to say wherever she appears. Asking her should not cost the athlete their place.

**What else was considered.** Launch on the home screen first and widen later. It lost because the plumbing for everywhere was already there.

**What it touches.** Root app widget, router.

> 2026-09-14 rejected: she's at select places not everywhere.

## mp-050 · The launcher is hidden on auth, onboarding, consent, paywall, force-upgrade and Vana routes
- category: The sheet and launcher
- status: rejected
- image: none
- caption:
- screen: Sign-in, onboarding, paywall
- source: spec.md; ticket 06; vana-sheet.md

**Context.** Everywhere has exceptions. Before sign-in there is no athlete to talk to. During onboarding and consent there is nothing to talk about yet. On the paywall and the force-upgrade screen the athlete has one job. On a Vana route the launcher would summon the surface already open.

**Question.** How those screens lose the launcher.

**Decision.** Those routes get no launcher node at all. It is not hidden by opacity or disabled, it is simply absent from the widget tree.

**Why.** Vana should not appear before there is anything to talk about, or on top of herself.

**What else was considered.** Disabling or hiding by opacity. It lost because an invisible button still takes taps and screen-reader focus.

**What it touches.** vana_launcher_rule.dart.

> 2026-09-14 rejected: as I said below, we ONLY show vana on a select number of screens right now (the main screen, coach formulas and mealplanning).  eventually we will broaden the number of screens but not right now.  so we are talking about "hiding" and what not and that's not the right approah I don't think

## mp-051 · The launcher hides under any dialog or bottom sheet
- category: The sheet and launcher
- status: approved
- image: docs/ssot/decisions/images/mealplanning/calendar-sheet.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-051-2.svg
- screen: Calendar sheet over the Plan tab
- source: ticket 06

**Context.** Screens open dialogs and bottom sheets over themselves. The calendar sheet over the Plan tab is one. The launcher floats above the screen, so it floated above those modals too, and above Vana's own sheet.

**Question.** What happens to the launcher when a dialog or bottom sheet opens?

**Decision.** The launcher hides while any dialog or bottom sheet is open, and that includes Vana's own sheet. It never floats on top of one. Example: on the Plan tab the athlete opens the calendar sheet, and the launcher is not shown while that sheet is up.

**Why.** The launcher should not float over a modal.

**What else was considered.** none recorded

**What it touches.** VanaCompanionObserver.

**Details.** Precisely:
1. A navigator observer (VanaCompanionObserver) hides the launcher under any dialog or bottom sheet, Vana's own sheet included.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-053 · Flow screens hide the launcher rather than inset their buttons
- category: The sheet and launcher
- status: rejected
- image: none
- caption:
- screen: New activity
- source: ticket 11; memory 09-11

**Context.** On the device the launcher covered the right end of "Generate Plan" on the new-activity screen. Many screens end in a full-width bottom button like that. Two fixes were possible. Add clearance under the button on every such screen, or take the launcher off those screens.

**Question.** Which.

**Decision.** A flow screen is one whose job ends in a full-width bottom action. Creating or editing something, a wizard step, a form. Those screens get no launcher node. Browsing screens keep it. Lee ruled on 2026-09-11.

**Why.** The launcher covered "Generate Plan" on the new-activity screen.

**What else was considered.** A clearance inset per screen. It lost because every new flow screen would need one.

**What it touches.** vana_launcher_rule.dart flow patterns.

> 2026-09-14 rejected: this is the wrong approach.  we put vana on a select number of screens and do not maintain this sort of list

## mp-054 · The flow set is a named list of exact route patterns
- category: The sheet and launcher
- status: rejected
- image: none
- caption:
- screen: Any flow screen
- source: ticket 11

**Context.** The rule above needs a list of which screens count as flow screens. The launcher rule already had a list of exclusions for auth, onboarding and the rest. The list could match whole subtrees of routes or exact paths.

**Question.** How the flow set is written down and matched.

**Decision.** New activity, adjust macros, event form, the settings forms, onboarding steps in settings mode, formula editor, swap food, food detail, carb-loading picks, coach registration, coach chat, meal logging, build meal, scanned food, cooking mode and Kroger hide the launcher. Patterns match one route segment, never a subtree.

**Why.** One named set beside the existing exclusions, not checks scattered across screens.

**What else was considered.** Subtree matching. It lost because it would hide the launcher on browsing screens under a flow route.

**What it touches.** vana_launcher_rule.dart.

> 2026-09-14 rejected: we simply cannot maintain a list like this.  instead we need to have a specific list of screens we will show vana on and we don't even need a list like this.  so the rule that vana appears "on every screen" is too literal.  we can just start with the main screen with the tabs and then the mealplanning screen plus when we are doing the coach formulas.

## mp-055 · The session screen and meal detail keep the launcher, Kroger loses it
- category: The sheet and launcher
- status: rejected
- image: none
- caption:
- screen: Session screen, meal detail, Shop with Kroger
- source: ticket 11

**Context.** Three screens sat on the line. The session screen shows an activity's fuel plan and has a pre-workout card the launcher clips. Meal detail sometimes shows "Swap in" or "Add to plan" and sometimes not, depending on how it was reached. The Kroger review screen ends in a Send button. The rule can only see the route, not the buttons.

**Question.** Where each one falls.

**Decision.** The session screen is a browsing screen, so the launcher stays and the pre-workout card's right edge remains an open clearance question. A meal page is browsing because its add buttons appear only in some flows a route cannot tell apart. Kroger's one job is the send, so it is a flow screen.

**Why.** The path is the only signal the rule has.

**What else was considered.** Hide the launcher on those screens too. It lost for the session screen and meal detail because their main job is looking, not acting.

**What it touches.** Session screen, meal detail, Kroger review.

> 2026-09-14 rejected: same as above.  wrong approach

## mp-056 · Coach chat, cooking mode and Kroger are hidden, and Lee may reverse it
- category: The sheet and launcher
- status: rejected
- image: none
- caption:
- screen: Cooking mode, coach chat, Kroger review
- source: ticket 11; memory 09-11

**Context.** Three screens were judgement calls. Coach chat has a send button. Cooking mode has a Next button under each step, and asking Vana mid-cook is a plausible thing to want. The Kroger review ends in Send. All three put a button where the launcher sits.

**Question.** Which way to call them without a ruling.

**Decision.** These three are in the flow set because the launcher covers Send or Next. This is the current reading and Lee has not ruled on it.

**Why.** A Vana question mid-cook is plausible, but Next sits under the launcher.

**What else was considered.** Keep the launcher on any of the three. It lost for now because the button overlap was certain and the mid-cook question was a guess.

**What it touches.** vana_launcher_rule.dart.

> 2026-09-14 rejected: wrong approach

## mp-058 · The sheet continues one conversation all day, one per phone
- category: The sheet and launcher
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_thread_light.png
- caption: The day's conversation continuing in the sheet.
- svg2: docs/ssot/decisions/images/mealplanning/mp-058-2.svg
- screen: Vana sheet
- source: spec.md; ticket 06

**Context.** The Vana sheet opens a general conversation with Vana. An athlete may open it in the morning, close it, and open it again at lunch, and each open could either start fresh or continue. The note of which conversation is current could live on the phone or on the server, and a sheet closed before the first message arrives could lose its conversation.

**Question.** Does opening the sheet again start a new conversation?

**Decision.** Not on the same day. Every open of the sheet that day continues one general conversation, and the next day starts a new one. Each phone remembers its own day's conversation, so a second phone opens a separate one, and a conversation is kept even if the sheet was closed before Vana's first reply arrived. Example: an athlete opens the sheet on Monday morning, closes it, and opens it again at lunch; the morning's messages are still there. On Tuesday the sheet starts a new conversation.

**Why.** A follow-up an hour later should carry the morning's context. A fast close should not orphan the conversation.

**What else was considered.** A new conversation per open, which lost the morning's context. A server-held pointer shared across devices, which lost as more machinery than the case needed.

**What it touches.** Ambient conversation controller, companion host.

**Details.** Precisely:
1. The sheet continues the same general conversation all day and starts a new one the next day.
2. The pointer is stored on the device, so a second phone opens its own conversation.
3. The host adopts the server's id for the day's first conversation, so closing the sheet before the first event still keeps it.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-059 · Full screen opens the existing chat route on the same conversation
- category: The sheet and launcher
- status: rejected
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption: The sheet chrome with its dismiss and full-screen circles.
- screen: Vana sheet, full-screen Vana chat
- source: spec.md; ticket 06

**Context.** The sheet is small by design. Planning a week needs the full-screen chat with its plan bar. The design export drew the sheet with a dismiss button only.

**Question.** How the athlete gets from the sheet to full screen, and whether they keep the thread they are in.

**Decision.** A second 30 px glass circle beside dismiss opens the full-screen chat route on the sheet's own conversation. A turn in flight carries over.

**Why.** Planning a week needs room. The design export had no full-screen button, so one was added.

**What else was considered.** A separate full-screen conversation. It lost because the athlete would lose the thread they were in.

**What it touches.** Sheet chrome, chat route.

> 2026-09-14 rejected: i actually don't like this to make it small by design.  going back and forth to full screen seems janky.  ONLY if someone presses that full screen button should it go to full screen and then i hope it's just a graphical thing and nothing has to change with vana

## mp-060 · Planning actions leave the sheet for full screen
- category: The sheet and launcher
- status: rejected
- image: none
- caption:
- screen: Full-screen Vana chat
- source: ticket 06

**Context.** In the sheet Vana may offer a meal picker, a rule to accept, the pantry grid or a swap. Those actions build a draft plan, and the draft shows in a plan bar. The plan bar exists only on the full-screen chat.

**Question.** Whether planning happens inside the sheet.

**Decision.** Picking a meal, accepting a rule, the pantry and swap open the full-screen chat on the same conversation. They do not run in the sheet.

**Why.** The plan bar lives on the full-screen chat, and the sheet has none.

**What else was considered.** Run planning actions inside the sheet. It lost because the sheet has nowhere to show the growing plan.

**What it touches.** Part actions, chat route.

> 2026-09-14 rejected: i actually don't like this to make it small by design.  going back and forth to full screen seems janky.  ONLY if someone presses that full screen button should it go to full screen and then i hope it's just a graphical thing and nothing has to change with vana.  so planning actions can stay in the sheet and the sheet can grow to accomodate it.  however for mealplanning, i do think if it detects we are doing that then perhaps there can be a button to just mealplan which takes us to the mealplanning page rather than trying to meallplan in the general chat area

## mp-061 · The sheet opens on top of the app, and the screen underneath keeps its place
- category: The sheet and launcher
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption: The sheet raised over the home screen, which stays legible.
- svg2: docs/ssot/decisions/images/mealplanning/mp-061-2.svg
- screen: Vana sheet over any screen
- source: ticket 06; vana-sheet.md

**Context.** The sheet rises over whatever screen the athlete was on. It could be drawn as an overlay inside each screen, or as a route of its own on top of the app. The screen underneath has scroll position, a half-filled form, an open tab.

**Question.** When the sheet closes, is the screen underneath just as the athlete left it?

**Decision.** Yes. The sheet opens as a layer on top of the whole app, not drawn inside each screen, so the screen underneath keeps its scroll position and anything half filled in. Tapping the dimmed area around the sheet, or the phone's back gesture, closes it. Example: an athlete halfway down the Plan tab opens the sheet, asks Vana a question and taps the dimmed area; the Plan tab is still at the same place.

**Why.** Closing must return the athlete exactly where they were.

**What else was considered.** An overlay drawn inside each screen. It lost because every screen would have to host it.

**What it touches.** VanaSheetRoute.

**Details.** Precisely:
1. The sheet is a popup route on the root navigator (VanaSheetRoute).
2. The page underneath keeps its state and scroll.
3. A tap on the scrim (the dimmed area around the sheet) and the system back gesture both pop the sheet.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-062 · Every close shrinks the sheet back into the launcher over about 470 ms
- category: The sheet and launcher
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_closed_light.png
- caption: The launcher the sheet condenses back into.
- svg2: docs/ssot/decisions/images/mealplanning/mp-062-2.svg
- screen: Vana sheet mid-dismiss
- source: tickets 06, 08; vana-sheet.md

**Context.** The sheet can be closed four ways: dragging the grabber down, the close button, tapping the dimmed area around it, and the phone's back gesture. A bottom sheet usually slides off the bottom of the screen. The written spec said the sheet shrinks into "the launcher's corner", but the design file's numbers shrink it towards the launcher's centre.

**Question.** What does the sheet look like when it closes?

**Decision.** However it is closed, the sheet shrinks back into the launcher, the button it came from, and never slides off the bottom of the screen. The shrink takes about 470 ms and the rise on opening takes 360 ms. Example: dragging the grabber down, the close button, tapping the dimmed area and the back gesture all look the same: the sheet folds into the launcher's centre in about half a second.

**Why.** The sheet is the launcher opened up, and what the athlete was reading ends where the thing that brings it back lives.

**What else was considered.** Slide down off-screen on some paths, which lost because the motion would say the sheet went somewhere else. Condense to the screen corner, which lost to the export's numbers.

**What it touches.** VanaSheetRoute.

**Details.** Precisely:
1. Grabber, close button, scrim and system back all condense the sheet into the launcher over about 470 ms, with the origin at the launcher's centre.
2. The rise on open is 360 ms.
3. The sheet never slides off-screen.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-063 · Three sheet heights: auto, 75 percent and 100 percent under the status bar
- category: The sheet and launcher
- status: rejected
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption: The sheet at its 75 percent rest height.
- screen: Vana sheet
- source: tickets 05, 08; vana-sheet.md

**Context.** The design export drew the sheet at three heights. A short one for a single message, a resting one for a card and replies, and a tall one for reading a thread. A single fixed height would be simpler to build. The tall one could reach the very top of the screen or stop under the status bar.

**Question.** How many heights the sheet has and where the tallest stops.

**Decision.** Auto height for one message and a dismiss, 75 percent at rest with a card and replies, 100 percent when expanded. The expanded sheet stops under the status bar. Lee confirmed on 2026-09-11.

**Why.** The design export drew three heights, and a short exchange should not take most of the screen.

**What else was considered.** A single fixed rest height, which lost because a one-line answer would fill most of the screen. Full-bleed to the top edge, which lost because the status bar stays readable.

**What it touches.** VanaSheet, VanaSheetRoute.

> 2026-09-14 rejected: ah this seems overly designed.  just one height and make things standardized

## mp-064 · "A dismiss" means any single reply, and a receipt counts as a card
- category: The sheet and launcher
- status: rejected
- image: none
- caption:
- screen: Vana sheet at auto height
- source: ticket 08; memory 09-10

**Context.** The spec gives the short auto height to "one message and a dismiss". Vana's first message may come with one quick reply, or two, or a card. A receipt such as "memory saved" or "logged" is a small part that is not quite a card.

**Question.** Exactly which first messages get the short height.

**Decision.** Auto height applies when the first transcript is one settled Vana message with no card and at most one reply, whatever the reply says. A receipt part such as memory saved or logged counts as a card.

**Why.** One message and one reply is a short exchange whatever the reply says.

**What else was considered.** Auto only for a literal "Dismiss" reply. It lost because the reply's wording does not change how much is on screen.

**What it touches.** VanaExchange.oneMessage.

> 2026-09-14 rejected: again auto height and stuff like this... it's too much why are we talking abuot auto height.  no.

## mp-065 · The stream never resizes the sheet, but the first send grows auto to 75 percent once
- category: The sheet and launcher
- status: rejected
- image: test/features/meal_planning/presentation/goldens/vana_sheet_streaming_light.png
- caption: The sheet holding its height while Vana types.
- screen: Vana sheet
- source: ticket 08; memory 09-10

**Context.** At auto height the sheet is as tall as its content. Vana's replies stream in word by word. If auto held through a reply, the sheet would grow with every word. The export grows the sheet to 100 percent when the athlete sends.

**Question.** When the sheet changes height during an exchange.

**Decision.** An auto sheet grows to 75 percent in the same frame as the athlete's first send. Streaming never resizes the sheet after that. The export's grow-to-100-percent on send is not adopted.

**Why.** Holding auto through a turn would resize the sheet with every streamed word.

**What else was considered.** Grow to 100 percent on send, as the export does. It lost because a short answer would then sit in a full-screen sheet.

**What it touches.** VanaSheet.

> 2026-09-14 rejected: we are not doing fancy calculations with height like this

## mp-066 · Drag thresholds come from the export, plus a flick
- category: The sheet and launcher
- status: rejected
- image: none
- caption:
- screen: Vana sheet
- source: ticket 08; vana-sheet.md

**Context.** The athlete moves the sheet between its heights by dragging the grabber. The export gives pixel distances for when a drag counts. It says nothing about a fast short flick, which people use all the time. From the tallest height a drag could need one pull or two to dismiss.

**Question.** What distances and speeds move the sheet.

**Decision.** 24 px up expands. 90 px down collapses from 100 percent or dismisses from rest. A drag from 100 percent that ends 90 px past the rest line dismisses in one pull. A grabber tap toggles. An upward pull at rest gives at 35 percent. A flick faster than 700 px per second counts as passing the threshold.

**Why.** The export's numbers, with a flick added because the export had none.

**What else was considered.** No flick, which lost because a fast short pull would do nothing. Two drags to dismiss from 100 percent, which lost to the export and the spec.

**What it touches.** VanaSheet.

> 2026-09-14 rejected: what are we doing here?  this seems overly complicated

## mp-121 · Editing an earlier turn rewinds the conversation and restores the draft
- category: The planning conversation
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-121-2.svg
- screen: Vana chat
- source: vana-chatbot-update-plan.md

**Context.** MealBuddy, a meal-planning app we studied, lets the athlete edit an earlier message and run the conversation again from there. Our conversations are stored on the server. Meals picked after the edited message would be left behind, belonging to a conversation that no longer exists.

**Question.** What happens when the athlete edits an earlier message?

**Decision.** We adopt it: the conversation rewinds to the edited message. That message and everything after it are deleted, the Draft goes back to how it stood before it, and the edited message is sent again. Each of Vana's replies keeps a copy of the plan as it stood, which is what the rewind restores, and the rewind happens on the server. Example: an athlete asks for Thai food in their second message, then edits it to say Italian; the second message and every reply after it are deleted, picks made after it leave the Draft, and the Italian version goes to Vana.

**Why.** MealBuddy's single best interaction idea. History is server-owned.

**What else was considered.** Client-side truncation, which fights the server-owned history, or leaving orphaned picks, which desyncs the draft.

**What it touches.** Rewind action, message metadata.

**Details.** Precisely:
1. Every assistant row stores a plan snapshot.
2. Editing an athlete turn deletes messages from that turn on, restores the draft from the snapshot, and resends.
3. A rewind past the first turn empties the draft.
4. The endpoint is server-side.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-139 · Day notes are precomputed in one call for seven days and refreshed in the background
- category: Plan tab
- status: approved
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: The day note card at the top of the Plan tab.
- svg2: docs/ssot/decisions/images/mealplanning/mp-139-2.svg
- screen: Plan tab
- source: plan-tab-v2.md; 03-backend.md

**Context.** The Plan tab opens with Vana's day note at the top. Writing it while the page loaded made every load take about five seconds. A note goes out of date when the plan is edited.

**Question.** When are the day notes written, and does anyone wait for them?

**Decision.** Vana writes the day notes for all seven days in one call when the athlete confirms a plan. An edit to the plan marks the notes out of date and rewrites them in the background, so nobody waits: the Plan tab shows the old note at once and asks again 7 seconds later. Only a day that has no note at all is written while the athlete waits. The numbers in a note come from the athlete's records; the model only puts them into words. Example: an athlete swaps a dinner and reopens the Plan tab; the old note shows straight away, and 7 seconds later the tab asks again for the rewritten one.

**Why.** Waiting for the note made every page load take about five seconds.

**What else was considered.** Per-visit generation, which pays the five seconds every time, or generating on the client, which makes the client pay for a model call it cannot see.

**What it touches.** daynotes.ts, vana-day-notes, Plan tab day note card.

**Details.** Precisely:
1. One Haiku call writes all seven day notes on confirm.
2. A plan edit marks them stale and regenerates them in the background, never awaited.
3. A stale note is served instantly and the Plan tab re-polls after 7 seconds.
4. If a day has no note at all it is generated inline.
5. Numbers come from context and the model only phrases.

> 2026-09-14 approved
> 2026-09-14 picture refreshed at 1.26.0+1, 469da691, replacing test/features/meal_planning/presentation/goldens/plan_confirmed_light.png
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-144 · One thumb per person per meal, and a thumbs down means Vana will not suggest it again
- category: Meals tab and library
- status: approved
- image: docs/ssot/decisions/images/mealplanning/meal-detail.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-144-2.svg
- screen: Meal detail
- source: recipe-directions-and-cooking-mode.md; 05-flutter-feature.md
- work: pending

**Context.** Opening a meal from the Meals tab or a plan tile shows the meal detail screen. The app already had a favourite flag on saved recipes, which marks a meal the athlete wants to keep. Vana's planner needed a separate signal for meals the athlete does not want offered again.

**Question.** What does a thumbs vote on a meal do?

**Decision.** Each person has one vote per meal, up or down, and tapping the same vote again clears it; the screen shows the vote straight away. A thumbs down keeps the meal out of Vana's suggestions, and the screen says so, but the meal still shows when browsing; a thumbs up adds 0.10 to its search score. Admins also see a comment box on every meal page to say whether it is a good recipe and why, and each comment lands in a table the team reviews; athletes never see it. Example: an athlete gives a meal a thumbs down; the page says Vana will not suggest it again, and the meal is still on the Meals tab.

**Why.** A quality signal distinct from the saved-meal favourite, and the one structured meal preference the planner honours. Lee on 2026-09-14: admins need to comment on recipes from the page and have it reach the database.

**What else was considered.** Reusing the recipe favourite flag. It lost because a favourite says "keep this" and cannot say "never again".

**What it touches.** set_meal_feedback, search_meals, meal detail controller. Admin flag, meal_reviews table, meal detail screen.

**Details.** Precisely:
1. Meal feedback holds one vote per person per meal. Tapping the same vote twice clears it. The detail screen shows the thumbs optimistically, and a thumbs down shows a note that Vana will not suggest that meal again.
2. A disliked meal is filtered out of suggestions but still visible when browsing. A thumbs up adds 0.10 to the meal's search score.
3. A signed-in admin sees a comment box on every meal page. They can say whether it is a good recipe and why, and each comment lands in a table for the team to review. Athletes never see the box.

> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-145 · Meal icons are classified and stored, but not drawn
- category: Meals tab and library
- status: approved
- image: test/features/meal_planning/presentation/goldens/meal_icon_glyphs_grid.png
- caption: The 23 meal icon glyphs.
- svg2: docs/ssot/decisions/images/mealplanning/mp-145-2.svg
- screen: Meals tab
- source: plan-tab-v2.md; 02-contract.md
- work: pending

**Original.** 1. The 23-key classifier stays and the key is stored on library, saved and plan meals, copied along on add and swap, so the data is there when it is wanted.
2. Icons are not drawn on tiles, cards, the plan bar or the review sheet. Tiles keep their shape without the glyph.
3. A meal with no photo shows a plain placeholder, not an icon.

**Lee said.** Edit accepted from the category discussion on 2026-09-15: Meal icons are classified and stored, but not drawn

**Context.** Every meal card and plan row showed a small icon beside the name, and the icon stood in when a meal had no photo. The fuel log already had a set of 12 food icons. The meal library needed finer distinctions, and many meals have no photo at all.

**Question.** Does a meal show an icon, and what shows when it has no photo?

**Decision.** Each meal is still sorted into one of 23 icon kinds by a fixed rule, and the kind is saved on library, saved and plan meals and carried along when a meal is added or swapped, so it is there if it is wanted later. No icon is drawn: not on plan rows, meal cards, the plan bar or the review sheet. A meal with no photo shows nothing where the picture would be, neither a placeholder box nor an icon (ADR 0003). Example: a meal with no Dish photo shows as its name and details alone, with no empty box beside them.

**Why.** Lee on 2026-09-14: the icons clutter the UI. The classification is cheap to keep and costs nothing unseen. Lee on 2026-09-15: no plain placeholder box either; a meal has a Dish photo or nothing, which is cleaner.

**What else was considered.** Model-chosen icons, which would cost a call per meal and could drift. Extending the 12 food icons, which lost because the fuel-log set was built for logged foods rather than dishes.

**What it touches.** MealIconClassifier, KyleFoodIcon, meal cards. Meal card, plan tile, plan bar, review sheet.

**Details.** Precisely:
1. The 23-key classifier stays and the key is stored on library, saved and plan meals, copied along on add and swap, so the data is there when it is wanted.
2. Icons are not drawn on tiles, cards, the plan bar or the review sheet.
3. A meal with no photo shows nothing where the picture would be: no placeholder box, no icon. The space is not drawn (ADR 0003).

> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-15 approved by Lee
> 2026-09-15 edited from the category discussion on 2026-09-15 by Lee
> 2026-09-15 approved again by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-146 · Every meal's steps carry where they came from, and the meal page says so
- category: Recipes and cooking
- status: approved
- image: docs/ssot/decisions/images/mealplanning/meal-detail.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-146-2.svg
- screen: Meal detail
- source: memory 09-01; 05-flutter-feature.md

**Context.** The meal library cites a source page for most meals, but that citation is attribution, not a recipe. Only 14 of the 247 cited pages had steps a machine could read. The rest of the cooking steps had to come from somewhere else, and some are AI-generated.

**Question.** How does the athlete know where a meal's cooking steps came from?

**Decision.** Every meal in the library records where its steps came from: word for word from the source, from another source, a simple assembly, or written by AI. The meal page labels the steps by that origin: word-for-word steps read "as published by X" with a link to the original, and AI-written steps carry a sparkle with a tooltip. The macros sit in a fold-out marked approximate. Example: the library cites 247 source pages, but only 14 had steps a machine could read, so a meal from one of the other pages whose steps were written by AI shows the sparkle instead of "as published by".

**Why.** Honesty about where cooking instructions came from.

**What else was considered.** Paraphrased directions with no record of origin. It lost because the athlete could not tell a publisher's method from a model's guess.

**What it touches.** meal_library, meal detail screen, cooking mode.

**Details.** Precisely:
1. Every library row records where its steps came from: the source verbatim, an alternate source, a simple assembly, or AI-generated.
2. The detail screen labels steps by origin.
3. AI-generated steps carry a sparkle with a tooltip.
4. Verbatim steps read "as published by X" with a link to the original.
5. Macros sit in a disclosure marked approximate.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-165 · What's New shows when the content version goes up, with no new release
- category: Feedback loop
- status: approved
- image: docs/ssot/decisions/images/mealplanning/timeline.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-165-2.svg
- screen: Home shell
- source: memory 09-08

**Context.** The app needed a way to tell athletes what changed. The app already has a content system whose strings can be updated on the server without a release.

**Question.** How is a What's New announcement shown, and does it need a new build?

**Decision.** It needs no new build. The app's text lives in a content system on the server that changes without a release, and that content has a version number. When the number is higher than the one stored on the phone, a glass What's New sheet shows, on phones only, when the main tabs screen first builds. Example: to announce a change the team bumps the content version, and a phone that stored the older number shows What's New the next time its main tabs screen first builds, with no release shipped.

**Why.** Announce changes without shipping.

**What else was considered.** none recorded

**What it touches.** WhatsNewSheet, app content.

**Details.** Precisely:
1. A glass What's New sheet shows when the content system's version number is higher than the one stored on the device.
2. It shows on phones only, when the main tabs screen first builds.
3. Announcing again means bumping the content version, not shipping a release.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-197 · MealBuddy's skin is rejected, only its interactions are adopted
- category: Design system
- status: approved
- image: docs/new_mealplanning/figma/16-plan-detail-modal.png
- caption: A MealBuddy frame, whose look was not adopted.
- svg2: docs/ssot/decisions/images/mealplanning/mp-197-2.svg
- screen: Vana chat
- source: vana-chatbot-update-plan.md

**Context.** MealBuddy is a Figma concept file that explored a meal-planning assistant with a mascot, a cream and navy palette, coloured outlines on chips and bars and controls drawn the iOS way. The app already had the Kyle design system and a working prototype styled with it.

**Question.** How much of the MealBuddy design comes into the app?

**Decision.** Only how MealBuddy behaves comes in, not how it looks: no mascot, no cream and navy colours, no coloured outlines on chips and no iOS-only chrome (bars and controls drawn only the iPhone way). Colours come only from the Kyle design system, and any new designed widget gets a written spec first and is then built once in the shared widget library. When MealBuddy and the Kyle-styled prototype look different, the prototype wins. Example: a MealBuddy frame shows a chip with a coloured outline on cream; the app draws that chip the way the prototype does, in Kyle colours.

**Why.** MealBuddy is a concept file, not a finished look to copy, and the app ships on iOS, Android and Web, so iOS-only chrome would not fit.

**What else was considered.** Adopting the MealBuddy look. It lost because it is a concept, not a system, and its chrome is iOS-only.

**What it touches.** lib/shared/widgets/kyle_design/, design component specs.

**Details.** Precisely:
1. No mascot, no cream and navy palette, no coloured chip outlines, no iOS-only chrome.
2. Kyle tokens are the only registry.
3. New design-bearing widgets are built once in the shared library with a spec written first.
4. When MealBuddy and the Kyle prototype disagree visually, the prototype wins.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-209 · Jade is retired everywhere, including coach formula feedback
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-209-2.svg
- screen: Coach formula feedback, Vana chat
- source: Lee on the page 2026-09-13, amending mp-002

**Context.** Jade was the earlier name for the assistant. Her name survives in a compatibility route the shipped app still calls, in database views, in some prompts, and in the copy the coach sees when giving feedback on a formula. The one-Vana decision made her redundant, but nothing said when the last traces go.

**Question.** When do the last traces of the name Jade go?

**Decision.** Now. Every mention of Jade goes: the old server route and its functions, the prompts, the database names as soon as the shipped app no longer calls them, and the words a coach sees when giving feedback on a formula. Coach feedback on a formula becomes an ordinary Vana conversation, like any other way into Vana. Example: a coach opens an athlete's formula to leave feedback and talks to Vana, the same assistant the athlete meets in the chat, with no Jade anywhere on the screen.

**Why.** Lee ruled it on the page on 2026-09-13. One assistant with two names reads as two assistants.

**What else was considered.** Leave the compatibility route and copy in place until a later cleanup. It lost because the copy is athlete-facing and coach-facing today.

**What it touches.** jade-chat route and alias, jade_* views, persona prompts, coach formula feedback copy, content keys.

**Details.** Precisely:
1. Every mention of Jade goes: the route, the functions, the prompts, the database names once the shipped app no longer needs them, and the coach-facing copy in formula feedback.
2. The coach formula feedback is a Vana conversation like any other entry point.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-212 · Vana looks up the athlete's own records with tools before answering
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-212-2.svg
- screen: Vana chat
- source: Lee on the page 2026-09-13, amending mp-005

**Context.** The app holds the athlete's events, activity history, macro targets, logged food, and the deterministic fuelling module. Some of that is written into every turn's context block. The rest can only reach Vana if a tool exposes it. Today the tool set covers meal search, memory, settings, weather and the day-guidance function.

**Question.** How much of the athlete's record can Vana look at when asked?

**Decision.** Vana gets a tool, a lookup she can call in the middle of a reply, for each record a question could need: the upcoming event list, activity history, macro targets, and food suggestions for a given session such as a long run. The app's own fixed calculations are offered to her as tools rather than rebuilt in her prompt. When one of those records can settle a question, she looks it up before she answers. Example: an athlete asks what races are coming up, and Vana reads their event list instead of asking them.

**Why.** Lee on 2026-09-13: if an athlete asks what races are coming up, Vana should have access to the event list. Asking the athlete for what the app already stores reads as not knowing them.

**What else was considered.** Put more of the record into the per-turn context block. It lost because the block already costs about 1.5k tokens and most questions never need most of it.

**What it touches.** vana-chat tool set, context builder, event and activity queries.

**Details.** Precisely:
1. Vana gets a tool for each of the athlete's records that a question could need: the upcoming event list, activity history, macro targets, and food suggestions for a given session such as a long run.
2. The deterministic functions behind the app are exposed as tools rather than rebuilt in the prompt.
3. She calls a tool before answering a question those records can settle.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-213 · A side question gets an answer, then an offer to resume planning
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-213-2.svg
- screen: Vana chat
- source: Lee on the page 2026-09-13, amending mp-007

**Context.** During a planning conversation the athlete may ask something unrelated, such as what the weather will be for Saturday's ride. The shipped prompt treated every turn in a planning conversation as a planning turn, so the answer came with a meal carousel attached.

**Question.** What happens when the athlete asks something off the planning path?

**Decision.** Vana answers it in full and shows no meals. When that thread is done, she asks whether they are ready to pick meals, and the plan bar keeps the draft as it was. Example: halfway through planning the week, an athlete asks what the weather will be for Saturday's ride; Vana answers with no meal carousel, then asks if they are ready to get back to picking meals, and the dinners already chosen are still in the plan bar.

**Why.** Lee on 2026-09-13: there should be some fluidity. A question deserves an answer, not a redirect.

**What else was considered.** Keep every turn in a planning conversation on the planning rails. It lost because it made Vana ignore the question.

**What it touches.** Persona prompt, planning intent rules, picker chips.

**Details.** Precisely:
1. When the athlete asks something unrelated to planning, Vana answers it fully and shows no meals.
2. When that thread is done, she asks whether they are ready to pick meals.
3. The plan bar keeps the draft as it was.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-214 · Vana is short and to the point, without a sentence count
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-214-2.svg
- screen: Vana chat
- source: Lee on the page 2026-09-13, rejecting mp-011

**Context.** The shipped persona once capped every turn at two sentences and read as clipped. A later contract set a length per moment: two sentences when picking, four when presenting with one athlete fact, uncapped when explaining. Lee rejected that contract as too rigid.

**Question.** How do we keep Vana brief without counting sentences?

**Decision.** Vana gets to the point and leaves out anything that does not help. There is no sentence count and no rule that every turn must mention something about the athlete. A milestone may carry one exclamation mark, and emoji are banned everywhere; talking about food as minimums to reach, never talking about weight, and sending medical questions to a professional all stay. Example: under the rejected contract a picking turn was capped at two sentences; now Vana writes what the athlete needs to choose and stops, with no emoji.

**Why.** Lee on 2026-09-13: convey short and to the point without strict guidelines, and ban emoji.

**What else was considered.** The per-moment sentence caps. They lost because a number in the prompt made her count instead of think.

**What it touches.** Persona prompt core.

**Details.** Precisely:
1. Vana gets to the point and leaves out anything that does not help.
2. No sentence counts and no required athlete fact per turn.
3. A milestone may carry one exclamation.
4. Emoji are banned everywhere.
5. Minimums framing, no weight talk, and medical referrals stay.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-218 · The context block has a token budget and a test that enforces it
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-218.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-218-2.svg
- screen: none (algorithm/data)
- source: Lee on the page 2026-09-14, amending mp-020

**Context.** The context block is assembled on every turn from the athlete's records. Nothing today measures how large it is or whether every field in it is used by a prompt. It has grown as features were added, and it is the main cost of a turn.

**Question.** How is Vana's context block kept short?

**Decision.** By a size limit that a test checks. The test builds the block for a set of typical athletes, counts its tokens (the units the model reads and is billed by), and fails when the count goes over the limit or when the block carries a field no prompt reads. The limit is set when the test lands and recorded on this card. Example: if a change left a LIKES line in the block after every prompt had stopped reading it, the test would fail even with the block under the limit.

**Why.** Lee on 2026-09-14: test that this view is not too large and is not sending extraneous data. It should be short and compact, giving the most relevant information.

**What else was considered.** Trust the builder and review it by eye. It lost because the block already grew unnoticed.

**What it touches.** Context builder tests, the eval scripts.

**Details.** Precisely:
1. The context block has a token budget.
2. A test builds the block for representative athletes, counts the tokens, and fails when the count passes the budget or when the block carries a field no prompt reads.
3. The budget number is set when the test lands and recorded here.

> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-219 · The status chip above the transcript
- category: The sheet and launcher
- status: rejected
- image: test/features/meal_planning/presentation/goldens/vana_sheet_thread_light.png
- caption: The status chip pinned above a thread.
- screen: Vana sheet
- source: ticket 07; memory 09-10

**Context.** The Vana sheet is the slide-up companion that opens from the launcher. A small status chip sits above its transcript. The design export draws it in two states and lets it scroll away with the thread.

**Question.** What the small chip above the sheet's transcript says, and when.

**Decision.** 1. The chip reads "Fuel plan · to do" in orange when Vana's latest settled turn asks the athlete for something, and "Update" in electrolyte when it does not. Before Vana has spoken there is no chip.
2. Only Vana's latest settled turn sets the tone. The athlete's turns and a turn still streaming do not count, so answering a question does not clear the to-do. Vana's next turn does.
3. The general opener's two choices are a menu, not a to-do, so a fresh sheet opens on "Update". Orange on open is reserved for a moment.
4. The topic word comes from a planning part if there is one, else from the screen underneath: Timeline, fuel log and session plan read "Fuel plan", the Plan tab, a meal and cooking mode read "Meal plan", anywhere else reads a bare "To do".
5. The chip is pinned and does not scroll with the transcript.

**Why.** The athlete sees at a glance whether there is something to do, and the chip stays readable in a long thread.

**What else was considered.** Reading the newest turn from either side, which cleared the to-do the moment the athlete sent. Opening on the orange to-do as the export draws, which would mark every fresh sheet as unfinished business. Letting the chip scroll away, which hides it on any long thread.

**What it touches.** vana_exchange.dart, sheet conversation, content keys.

**Details.** All chip strings are content keys.

> 2026-09-14 folded from mp-071, mp-072, mp-073, mp-074, mp-075
> 2026-09-14 rejected: I don't think this badge adds anything and seems unncessary overcomplication

## mp-220 · The opener shows two quick replies, gone once the conversation starts
- category: The sheet and launcher
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption: Two quick replies under the opener.
- svg2: docs/ssot/decisions/images/mealplanning/mp-220-2.svg
- screen: Vana sheet on open
- source: ticket 07; memory 09-10

**Context.** Quick replies are the tappable answers under Vana's opening line in the sheet. The server's opener ends in a choice question and its prompt asks for two to three options. The export draws exactly two chips.

**Question.** How many answer buttons sit under Vana's first line, and when do they go?

**Decision.** Vana's opener ends with a choice, and its first two options show as buttons under it, called quick replies: the first filled, the second outlined. A third option is dropped. The buttons go as soon as anything is in the conversation, not when the athlete starts typing, and stay gone while the sheet is open. Example: the opener offers three options, so the athlete sees two buttons; they send a message, the buttons go at once, and they stay gone even if that send fails.

**Why.** The design file shows two buttons, and drawing the opener's choices twice would bring the replies back.

**What else was considered.** Asking the prompt for exactly two, which costs a server deploy for the same result. Hiding the replies on typing a draft, which the spec prose said but the spec table and export did not.

**What it touches.** Sheet conversation, VanaExchange, persona.

**Details.** Precisely:
1. The opening's choice part becomes the quick replies. The first two options show, the first filled and the second outline. A third option is dropped.
2. The replies vanish the moment the thread has anything in it, not when the athlete types a draft, and they stay gone for the sheet's life even if that first send fails.
3. The opening's choices are drawn only as quick replies, never also inline. A choice part later in the thread renders as ordinary chips.

> 2026-09-14 folded from mp-076, mp-077
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, why, details)

## mp-221 · The sheet follows its own design, not the full-screen chat's
- category: The sheet and launcher
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_thread_light.png
- caption: Vana's row and the athlete's bubble in the sheet.
- svg2: docs/ssot/decisions/images/mealplanning/mp-221-2.svg
- screen: Vana sheet
- source: ticket 07

**Context.** The full-screen Vana chat draws her turns in an existing message card. The sheet is a newer, smaller surface with its own design file, its own typing indicator, and a typing box (the composer) with a send button and placeholder text.

**Question.** Do the sheet's messages and typing box look like the full-screen chat's?

**Decision.** No, the sheet follows its own design. Vana's messages sit on the left beside a small orange sparkle with no bubble, and the athlete's sit on the right in a soft cream bubble. The send button is grey when the box is empty or Vana is still replying, orange otherwise; Lee has not ruled on the grey while she replies. The typing box keeps a general hint, not the design's fuelling one. Example: while Vana is still writing an answer the send button is grey, and the empty box does not read "Ask about your fueling".

**Why.** The export draws the sheet this way, and the sheet is a general conversation rather than a fuelling one.

**What else was considered.** Reusing the existing Vana message card, which does not match the export. Orange send on any draft, as the export keys it, which lights a button the controller ignores mid-stream. The export's fuelling placeholder, which narrows the sheet.

**What it touches.** Sheet conversation, sheet composer.

**Details.** Precisely:
1. Vana's messages sit flush left with a small filled orange sparkle avatar and no bubble. The athlete's turns are right-aligned in a soft cream bubble.
2. The typing indicator is the in-flight turn with no prose yet, drawn in Vana's row. It never shows beside quick replies.
3. Send is grey with an empty draft and grey while a turn is in flight, orange otherwise. Lee has not ruled on the in-flight grey.
4. The composer keeps the general placeholder, not the export's "Ask about your fueling".

> 2026-09-14 folded from mp-078, mp-079, mp-080, mp-081
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-222 · The launcher is its own accessibility node
- category: The sheet and launcher
- status: approved
- image: docs/ssot/decisions/images/mealplanning/timeline-launcher.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-222-2.svg
- screen: Any screen with the launcher
- source: ticket 06
- detail: yes

**Context.** The launcher floats above every screen at the app's root. On the device its label merged into the root, so VoiceOver read the entire screen as one button called "Ask Vana".

**Question.** How does a screen reader see the launcher?

**Decision.** As a button of its own, with its own label, separate from the screen around it. Before this, VoiceOver, the iPhone's screen reader, read the whole screen as one button called "Ask Vana". Example: on the Timeline tab VoiceOver reads the launcher as its own button and no longer reads the whole screen as that one button.

**Why.** VoiceOver read the whole screen as one "Ask Vana" button.

**What else was considered.** none recorded

**What it touches.** VanaLauncher.

**Details.** Precisely:
1. The launcher is its own accessibility node with its own label.
2. Its semantics no longer merge into the app root (VanaLauncher).

> 2026-09-14 folded from mp-070
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-14 picture reused from docs/ssot/decisions/images/mealplanning/timeline-launcher.png
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-223 · Two fuelling windows make Vana speak first: before a workout and after one
- category: Moments: Vana speaks first
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_moment_pill_light.png
- caption: The launcher's moment pill asking "Fuel tonight's run?".
- svg2: docs/ssot/decisions/images/mealplanning/mp-223-2.svg
- screen: Any screen with the launcher
- source: ticket 09; vana-moment.md; archive ticket 13; ticket 10; memory 09-11

**Context.** A moment is Vana speaking first: the launcher rings, a pill shows a question, and the sheet opens on her already talking. Three sets of triggers were on the table. Meal-plan beats such as a cook check-in are decided on the server, which the launcher cannot ask without a call.

**Question.** What makes Vana speak first?

**Decision.** Only two windows: the pre-workout window before a planned workout today, and the recovery window after a finished endurance session of 60 minutes or more. The phone works both out from its own records, and meal-plan beats wait. Pre-workout speaks once its window has opened, while the workout has not started and no meal has been logged since the window opened; recovery speaks when nothing has been logged since the session, and never for strength or import-only sessions. Example: an athlete finishes an hour-long endurance run and logs nothing, so the pill asks "Recovery fuel?"; an hour of strength work raises nothing.

**Why.** A companion that interrupts on the wrong trigger is worse than one that waits. The server decides plan beats and the launcher cannot know them without a call. The SSOT names the 60 minute endurance clause and no single recovery window.

**What else was considered.** Windows plus existing plan beats, or a server moment endpoint, both needing a server call the launcher cannot afford. Any session the during-workout spec fuels, which made the 60 minute clause meaningless. Stopping to ask for a recovery window, which would have blocked the ticket.

**What it touches.** Moment resolver, launcher, recovery_window_authority.dart.

**Details.** Precisely:
1. Only two windows raise a moment: the pre-workout window and the recovery window. Both are resolved on the device from local rows. Meal-plan beats and informational moments are deferred and the "planning…" pill is not built.
2. Pre-workout raises for a planned, not-completed workout today whose window has opened and whose start has not passed, with no meal logged at or after the window opened. Import-only workouts raise nothing.
3. Recovery raises for a completed endurance session of 60 minutes or more with nothing logged since. Strength and import-only sessions never do. The pill says "Recovery fuel?".
4. The recovery moment stays live 4 hours when the next fuel-demanding session is under 8 hours away, else 2 hours. This is a reading of the SSOT's urgent and relaxed branches, not a ruling. Lee and Xuan have not ruled.

> 2026-09-14 folded from mp-082, mp-083, mp-091, mp-092
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-224 · A workout's window comes from its own minutes or the app's default, and a session ends at start plus duration
- category: Moments: Vana speaks first
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-224.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-224-2.svg
- screen: none (algorithm/data)
- source: ticket 09; memory 09-11; ticket 10
- detail: yes

**Context.** The pre-workout window's length varies by workout, and the app already has one place that owns it, the fuelling window authority. A session's end has to be worked out from a row where marking it done and Garmin write different things into the completed field.

**Question.** How long is a workout's window, and when did a session end?

**Decision.** The window is the workout's own stored pre-workout minutes, or else the default the fuelling window authority gives for its duration and intensity; a workout created close to its start has its window opening the minute it is created, and the phone sends the window to the server so Vana names the same one. A session ends at its actual start, else its scheduled start, plus its actual duration, else its planned one. The completed time is never read. Example: a ride scheduled for 07:00 and planned at 90 minutes that Garmin records as starting at 07:10 and lasting 100 minutes ends at 08:50.

**Why.** The fuelling window authority already owns the number, and the completed field means different things depending on whether the athlete marked the session done or Garmin filled it.

**What else was considered.** A fixed window in the resolver, which would put a second window number outside the authority. Reading the completed time, which mark-done and Garmin fill differently.

**What it touches.** fueling_window_authority.dart, moment resolver, moment.ts, chat body.

**Details.** Precisely:
1. The resolver reads the workout's stored pre-workout minutes and falls back to the authority's default from duration and intensity. A workout created close to its start is clamped so its window opens the minute it is created. The device sends the window to the server so Vana names the same one.
2. A session's end is the actual start, else the scheduled start, plus the actual duration, else the planned duration. The completed timestamp is never read.

> 2026-09-14 folded from mp-084, mp-093
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-225 · The launcher rings, then the pill shows, then the launcher stays tinted
- category: Moments: Vana speaks first
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_moment_tinted_light.png
- caption: The launcher tinted orange after the pill has gone.
- svg2: docs/ssot/decisions/images/mealplanning/mp-225-2.svg
- screen: Any screen with the launcher
- source: ticket 09; vana-moment.md

**Context.** A moment has three visible pieces on the launcher: a ring animation, a pill carrying the question, and a tinted resting state. The spec table lists all three and the export overlaps the first two. The pill sits beside the tab bar.

**Question.** In what order does the athlete see the ring, the pill and the tinted launcher?

**Decision.** One after another. The launcher rings, then the pill with Vana's question shows for a few seconds, then the launcher stays tinted orange until the moment ends; the pill never opens during the ring, and with reduced motion on it skips straight to tinted with the pill. While the pill shows, the tab bar shrinks to its home button, and the two must not overlap on an iPhone SE. Example: before tonight's run the launcher rings for about 2 seconds, the 240 px pill asks "Fuel tonight's run?" for 4 seconds, then the launcher stays orange.

**Why.** The spec's table reads as a sequence, and the export collapses the bar while the pill is open.

**What else was considered.** The pill during the ring, as the export does, which the spec table contradicts.

**What it touches.** VanaLauncher states, tab bar, home shell.

**Details.** Precisely:
1. The launcher rings, then the pill shows for a few seconds, then the launcher stays tinted until the moment retires. The pill never opens during the ring. Reduced motion skips straight to tinted with the pill.
2. While the pill shows, the tab bar collapses to its home button, and the two must not overlap at iPhone SE width.
3. Ring about 2 s, pill 240 px for 4 s, then orange with a cream top highlight and the mark in blackberry.

> 2026-09-14 folded from mp-085, mp-086
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-226 · Vana speaks first at most twice a day, and never twice for the same thing
- category: Moments: Vana speaks first
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-226.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-226-2.svg
- screen: none (algorithm/data)
- source: ticket 09; vana-moment.md; ticket 10

**Context.** A moment rings when it first raises. The athlete may switch screens, or kill and reopen the app, while a window is still open. With two moment kinds, a day with a morning and an evening session could raise four moments, and two windows can be open at once.

**Question.** How many times a day can a moment ring?

**Decision.** At most twice, and never twice for the same workout and window; once two have rung, a new moment is not raised at all, though one that already rang stays live. The phone stores each ring per person per day, so reopening the app or Garmin correcting a session's start does not ring it again. When a pre-workout and a recovery window are open at once, the one that closes sooner speaks. Example: an athlete with a morning run and an evening ride hears Vana before the run and after it; by the evening two have rung, so neither of the ride's moments is raised.

**Why.** An athlete with a morning and an evening session hears from Vana at most twice, and never twice for the same thing.

**What else was considered.** In-memory only, which rings again after every restart. No cap, which nags, or a cap of one, which silences the evening session. Pre-workout always wins, which can let a closing recovery window pass unspoken.

**What it touches.** Moment controller, moment resolver, rung record.

**Details.** Precisely:
1. "Rang for this workout and window" is stored on the device per user per day, so a restart does not ring again. A raised moment waits for a launcher on screen before ringing.
2. A recovery moment is keyed on the activity alone, with no time in it, so Garmin refining a marked-done session's start does not ring it again.
3. At most two rings a day. Once two have rung, an unrung moment is not raised at all. A moment that already rang stays live.
4. When a pre-workout and a recovery window overlap, the one that closes sooner speaks.
5. The controller re-resolves every minute while either window is open, because a window can close with no row changing.

> 2026-09-14 folded from mp-087, mp-094, mp-095, mp-096, mp-097
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-227 · A moment opens in today's conversation and ends on a reply, a meal or the workout
- category: Moments: Vana speaks first
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_moment_tinted_light.png
- caption: The launcher staying tinted after a dismissed sheet.
- svg2: docs/ssot/decisions/images/mealplanning/mp-227-2.svg
- screen: Vana sheet on a moment
- source: ticket 09; vana-moment.md

**Context.** Tapping the pill or the tinted launcher opens the sheet. Each day has one ambient conversation that may already hold turns. Once a moment has raised the athlete can dismiss the sheet, reply, log a meal, or start the workout.

**Question.** What happens when the athlete taps a moment, and what ends it?

**Decision.** Tapping the pill or the tinted launcher opens today's one conversation, even one that already has messages, on Vana's opener naming the session, its time and the window and ending in a choice of two options. Closing the sheet keeps the launcher tinted without a second ring; any reply after that opener answers the moment, and a meal logged in the window or the workout starting ends it. A moment that ends unanswered stays in the conversation with its two options drawn in place. Example: an athlete taps "Fuel tonight's run?", closes the sheet without replying and then logs a meal in the window, so the moment ends and Vana's question stays in the day's conversation with its two options.

**Why.** The sheet should open on Vana already naming the run. The nudge persists quietly but never nags, and the history stays honest.

**What else was considered.** A new conversation per moment, which breaks one conversation per day. Special-casing the moment in the exchange logic, which scatters the rule. Retiring on dismiss, which loses the nudge, or removing the turn on retire, which rewrites history.

**What it touches.** chat.ts runChat, companion host, VanaExchange, moment controller, sheet transcript.

**Details.** Precisely:
1. The client sends the moment kind and activity id as an opener into the existing conversation, even mid-thread. The opener names the session, its time and the window, and ends in a choice with two options. Landing mid-thread is not a first turn, so there is no second feedback tip and no read-back.
2. A moment starts a new exchange explicitly, so its quick replies show and the chip reads "Fuel plan · to do" even mid-thread.
3. Dismissing the sheet leaves the launcher tinted with no second ring. Any send in the moment's exchange answers it. A meal logged in the window or the workout starting retires it on the next resolve.
4. A retired, unanswered moment leaves its turn in the thread with its options drawn inline.

> 2026-09-14 folded from mp-088, mp-089, mp-090
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-228 · Urgent recovery names the next session, relaxed recovery sets no deadline
- category: Moments: Vana speaks first
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_moment_tinted_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-228-2.svg
- screen: Vana sheet on a recovery moment
- source: ticket 10; memory 09-11

**Context.** The nutrition rules for after a workout (the SSOT post-workout spec) have an urgent and a relaxed branch, and forbid presenting the 2-hour protein anchor as a window. The launcher's design spec gives the recovery moment the orange to-do look, while the SSOT's relaxed badge reads "with your next meal".

**Question.** What does Vana say when the athlete taps a recovery moment?

**Decision.** It follows the two branches of the nutrition rules. Urgent names the next session and says to keep carbs coming through the next 4 hours; relaxed says there is no rush and gives no deadline, and with a session 8 to 24 hours away it leans "earlier rather than later today". Both mention 20 to 30 g of protein within a couple of hours, and both use the same orange launcher and "Recovery fuel?" pill, which is the current reading and not yet ruled. Example: on the relaxed branch with the next session 12 hours away, Vana says there is no rush, eat earlier rather than later today, and 20 to 30 g of protein within a couple of hours.

**Why.** The SSOT forbids presenting the 2 hour anchor as a window, and the component spec assigns recovery the orange tone.

**What else was considered.** Naming the window in every recovery opener, which the SSOT forbids for the relaxed branch. Raising nothing for relaxed, or a news tone, both open for a ruling.

**What it touches.** chat.ts recovery opener, launcher, moment resolver.

**Details.** Precisely:
1. Urgent names the next session and says to keep carbs coming through the next 4 hours. Relaxed says there is no rush and gives no deadline; with a session 8 to 24 hours away it leans "earlier rather than later today". Both mention 20 to 30 g protein within a couple of hours.
2. Relaxed recovery uses the same orange to-do and "Recovery fuel?" pill as urgent. This is the current reading, not a ruling. It could raise nothing, or raise a calmer news tone.

> 2026-09-14 folded from mp-098, mp-099
> 2026-09-14 approved
> 2026-09-14 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_moment_tinted_light.png
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-229 · Cook check-ins and week debriefs come as the opener on the next app open, not as moments
- category: Moments: Vana speaks first
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-229-2.svg
- screen: Vana chat
- source: ticket 12; vana-chatbot-update-plan.md

**Context.** Beyond fuelling, the plan has beats where Vana could speak first: a cook check-in before a cooking session and a debrief after the week. Those are decided on the server. Push notifications and a cron job were on the table.

**Question.** Does Vana speak first about the meal plan, and how?

**Decision.** Not as a moment yet: cook check-in and week debrief moments wait until the two fuelling moments have been lived with; still open are how often to ask the server, what happens offline, and whether a plan moment may take one of the day's two rings. Until then Vana brings them up as her opener the next time the app opens, marked so they never repeat: a prep-day check-in when a cook session is today or tomorrow, and a debrief for a finished week not yet debriefed, up to 14 days old. Local notifications at 18:00 exist but are off unless turned on. Example: an athlete with a cook session on Sunday opens the app on Saturday and Vana opens with a prep-day check-in; opening the app again does not bring it back.

**Why.** Proactive must not mean naggy. An opener on open has zero spam risk, and the server-decided beats need a cadence decision first.

**What else was considered.** Building plan moments alongside the fuelling ones before the cadence and offline questions were answered. Cron or push through OneSignal, which can interrupt an athlete who did not open the app.

**What it touches.** opener.ts pickOpener, plan_debriefs, reminder service, moment controller.

**Details.** Precisely:
1. Cook check-in and week debrief moments wait until the fuelling moments have been lived with. Open: how often to ask the server, what happens offline, and whether a plan moment may take one of the day's two rings.
2. Meanwhile the two touchpoints arrive as the opener of the next app open, stamped so they never repeat: a prep-day check-in when a cook session is today or tomorrow, and a debrief for a finished undebriefed week up to 14 days old.
3. Local notifications at 18:00 exist but default off.

> 2026-09-14 folded from mp-100, mp-101
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-230 · A picker's tick adds a meal, and the chips under it are the app's own
- category: The planning conversation
- status: approved
- image: test/features/meal_planning/presentation/goldens/picker_chips_complete_light.png
- caption: Compact chips under a picker in the planning chat.
- svg2: docs/ssot/decisions/images/mealplanning/mp-230-2.svg
- screen: Vana chat
- source: memory 09-04; memory 09-03; 02-contract.md; plan-tab-v2.md
- work: pending

**Context.** In the planning chat Vana asks Choice questions and shows Meal pickers, carousels of suggested meals. Lee's walkthroughs on 09-03 and 09-04 found meals picked by accident and chip rows that did not earn their space. What the server sends the app for a turn had no field saying which meal type comes next.

**Question.** How does a meal picker work, and where do the chips under it come from?

**Decision.** A Choice question has two to four short answers; a Meal picker shows a handful of meals from a search of the meal library, the athlete's saved meals ranked up, with a Show more sheet for many more. Tapping a meal opens its detail page, and only the tick adds it to the Draft. The chips under a picker are always the app's own buttons: their words come from Vana when her turn names them (mp-272) and otherwise from the app's own set, and Other options never repeats a meal already in the Draft or already shown. Example: Vana's turn names no chips, so under her picker the athlete sees "I like these", then "Next: …" with a meal type or "That's my week" depending on how much of the week is covered, then "Other options" and "Something else…".

**Why.** Whole-card adding caused accidental picks, three meals felt thin, the model kept naming the wrong next type, and repeats read as not listening. Lee on 2026-09-14: the picker should be flexible, with a show-more sheet, and fed by the semantic search over the embedded library. Lee on 2026-09-15: the chip text can come from the model, which may say what buttons it expects next; when it says nothing the app shows its own; the widgets are always the app's.

**What else was considered.** Two-line label and detail rows, stripped as not earning their space. MealBuddy's five to seven option groups. A fixed three meals. Model-authored chips, or a next-slot hint on the wire the contract does not carry.

**What it touches.** askChoice schema, choice chips, suggestMeals tool, picker carousel, PickerChips, persona rule 3.

**Details.** Precisely:
1. A choice question takes two to four options as plain strings, drawn as compact pills. Bigger sets go through the selectable chip grid.
2. A picker shows a handful of meals from the semantic search over the library, with saved meals boosted. A "Show more" raises a sheet with many more options from the same search. The count is not fixed.
3. Tapping a picker tile opens meal detail. Only the tick adds it to the draft. Picked tiles get a swap circle. Chat tiles have no overflow menu, title, "tap to add" or why blurb.
4. The chips under a picker are widgets the app draws. Their labels come from the model when its turn names the choices it expects next (mp-272). When the turn names none, the app shows its own set: "I like these", then "Next: type" or "That's my week" by coverage, plus "Other options" and "Something else…". Filter chips appear once the plan has a meal. Tapping a chip sends its label.
5. "Other options" never repeats a meal already in the draft or already shown in the conversation.

The tick sits top-left and the swap circle top-right on picked tiles. The shown set is parsed from stored picker and staples parts.

> 2026-09-14 folded from mp-102, mp-103, mp-104, mp-105, mp-108
> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-15 amended by Lee
> 2026-09-15 rewritten from Lee's words
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-231 · A plan covers the meal types the athlete chooses, over a period they set, liked meals first
- category: The planning conversation
- status: approved
- image: test/features/meal_planning/presentation/goldens/plan_bar_expanded_light.png
- caption: The plan bar with its coverage count.
- svg2: docs/ssot/decisions/images/mealplanning/mp-231-2.svg
- screen: Vana chat
- source: memory 08-31; 02-contract.md; memory 09-03; vana-chatbot-update-plan.md
- work: pending

**Context.** A week's plan covers several meal types and the plan bar shows how much of the week is covered. Breakfast and snacks are staples. Not every athlete wants lunches planned, and Xuan's scenario has an athlete who trusts Vana to decide for them.

**Question.** Which meals get planned, over how many days, and what is suggested first?

**Decision.** The athlete plans only the meal types they want, in any order, over a cooking period that is a week unless they change it. With batch cooking on, a few meals cooked at one sitting are scaled to enough servings to last the period, and the plan counts servings against the period; without it, they plan day by day. Suggestions put meals they liked or already cooked first, one tap drafts the period from what they ate last time, and "Draft it for me" builds the plan by fixed rules, with Vana only presenting it. Example: an athlete who skips breakfast and snacks and batch cooks for a week is walked through lunches and dinners only, and the plan bar counts servings against that week, not against 14 fixed slots.

**Why.** Lee on 2026-09-14: the order is not fixed, the span is not a set week, batch cooking is cooking a few meals and eating them through the period, so servings must scale, non-batchers plan differently, and already-cooked or liked meals must come first.

**What else was considered.** A fixed dinner-lunch-breakfast-snack walk over 14 slots (the earlier reading), rejected as too rigid.

**What it touches.** Chip logic, planning prompt, coverage service, plan bar denominator, batch setting, suggestMeals ranking, draftWeek tool, settings.

**Details.** Precisely:
1. The order of meal types is not fixed. A person may skip breakfast, snacks or any type, and the walk only covers the types they plan.
2. The plan spans a cooking period. A week is the default and the athlete can change it, so several days is fine.
3. In batch mode the athlete cooks a few meals at one sitting and eats them across the period. Servings scale so the batch covers the days, and coverage counts servings against the period, not a fixed 14 slots.
4. People who do not batch plan per day instead, and the walk, coverage and review follow that mode.
5. Suggestions give the highest weight to meals the athlete has liked or already cooked. One tap drafts the period from what they ate last time.
6. "Draft it for me" runs deterministically. The model selects nothing and only presents the result.

> 2026-09-14 folded from mp-106, mp-107, mp-111
> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-232 · Batch cooking is asked once
- category: The planning conversation
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-232-2.svg
- screen: Vana chat
- source: prototype-rebuild-spec.md; 05-flutter-feature.md

**Context.** Batch cooking groups the week's meals into cooking sessions. The prototype defaulted it to true, so its ask-when-unknown rule never fired, and it went straight to rebuild-or-keep when the athlete switched it off.

**Question.** When does Vana ask about batch cooking, and does a change during a plan stick?

**Decision.** Vana asks once, before she shows lunches, and only if the athlete has never chosen; the answer is saved as a keyed Memory, and Settings has the same switch. Off means no cooking sessions, and each meal is "make the night of". If the athlete switches it off in the middle of a plan, Vana first asks whether that is for good or just this week, and then whether to rebuild the plan or keep it. Example: an athlete who batch cooks switches it off halfway through planning a week and answers "just this week", so the saved setting stays on for their next plan, and Vana then asks whether to rebuild this plan or keep it.

**Why.** It only changes grouping, so asking every plan is noise, and a one-week change should not overwrite the setting.

**What else was considered.** A per-plan question, which is noise. Asking rebuild-or-keep straight away, as the prototype did, which silently overwrote the setting.

**What it touches.** user_memories, Vana settings, review sheet sessions, persona, set_setting.

**Details.** Precisely:
1. Batch cooking is a keyed setting. When it has never been chosen, Vana asks before showing lunches and saves the answer. Settings has the same switch. Off means no cooking sessions and meals are "make the night of".
2. Switching it off during a plan first asks whether the change is for good or just this week, then asks rebuild-or-keep.

> 2026-09-14 folded from mp-109, mp-110
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-233 · What Vana suggests, and what she never invents
- category: The planning conversation
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-233-2.svg
- screen: Vana chat
- source: memory 08-31; README; prototype-rebuild-spec.md; 05-flutter-feature.md

**Context.** The standing rule is that numbers and meals never come from the model. The search tool feeds pickers from the library and the athlete's saved meals. A 2026-08-28 design auto-added staples under "act, don't ask". Rest days were the biggest gap the research found unaddressed.

**Question.** Where do suggestions, staples and day guidance come from, and what may Vana make up?

**Decision.** Nothing: Vana only puts into words what the app has worked out, and staples are suggested from the athlete's own logs and wait in the chat until the athlete ticks them. Guidance for rest days, carb-load days and race week is computed by the app from the athlete's numbers, workouts and library picks; a race-week rule may name a specific meal and is only offered when a race exists, and race day carries no carb number. The search drops anything that breaks the athlete's allergies or diet before it reaches Vana, ranks saved meals up, lifts common Assemblies and never pairs foods no athlete has been documented eating. Example: a vegetarian athlete never sees a meat dish in a picker, because the search removes it in the database before Vana sees the list.

**Why.** Lee ruled twice that auto-adding surprised users. Numbers never come from the model, and the model may never emit a meal a tool did not vet.

**What else was considered.** The "act, don't ask" auto-add. Model-generated day advice. Model-side filtering, which lets the model emit a meal the tool did not vet.

**What it touches.** diagnoseStaples, Plan tab, dayGuidance, day cards, rule chip, search_meals, meal library pairs.

**Details.** Precisely:
1. Staples are suggested from the athlete's own logs and nothing enters the plan until the athlete ticks. The staples card is a chat part only.
2. Day guidance for rest days, carb-load days and race week is computed from the budget, the workouts and the library's picks. The model only phrases it. A race-week rule can be a specific meal and is only proposed when a race exists. Race day carries no carb number.
3. Search applies allergies and dietary preference as a hard filter in the database, returns saved and library rows together with saved boosted, nudges common assemblies up, and rejects pairs no athlete has been documented eating.

> 2026-09-14 folded from mp-112, mp-113, mp-114
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-234 · The plan bar shows the Draft, and Confirm lives only in the Review sheet
- category: The planning conversation
- status: approved
- image: test/features/meal_planning/presentation/goldens/plan_bar_minimized_light.png
- caption: The plan bar minimized above the composer.
- svg2: docs/ssot/decisions/images/mealplanning/mp-234-2.svg
- screen: Vana chat plan bar
- source: 02-contract.md; plan-tab-v2.md; 05-flutter-feature.md; memory 09-03

**Context.** The plan bar is pinned above the composer in the planning chat and grows as meals are picked. The server sends a plan snapshot whenever the draft changes. The 2026-08-28 design kept Confirm always visible, and "New meal plan" was opening on the confirmed plan with meals already in it.

**Question.** What does the plan bar show, where is Confirm, and which plan does it change?

**Decision.** The plan bar sits pinned above the message box and shows this conversation's Draft; the plan is never shown as a message in the chat. It starts at "Your plan · 0 meals" and folds shut on every turn; each meal in it can be removed (with Undo), shows its slot and has a servings stepper, and "Review plan" becomes the main button once there are three meals. Confirm is only in the Review sheet, never in the bar or in Vana's chips, and the bar never reads or changes the plan already active on the phone. Example: an athlete with a confirmed plan for this week starts a new meal plan; the bar opens at "Your plan · 0 meals", not on this week's meals, and removing a meal from it leaves this week's plan as it was.

**Why.** The plan is state, not a message. Nothing commits without an explicit review, and the bar must not crowd the transcript.

**What else was considered.** Rendering each snapshot as a card, which fills the transcript with state. Confirm always visible in the bar, which let a plan commit without a review.

**What it touches.** Chat controller, PlanBar, ReviewSheet, applyDraftPlan.

**Details.** Precisely:
1. A plan snapshot is never a message bubble. It updates the draft and the bar, and history rows have snapshots stripped on load.
2. The bar opens as "Your plan · 0 meals" and collapses on every turn. Tiles carry remove with Undo, a slot chip and a servings stepper. "Review plan" is secondary until three meals, then primary.
3. Confirm lives only in the Review sheet, grouped by cooking session when batch cooking is on. It is not in the bar or in Vana's chips.
4. The bar and picks in chat read and write the conversation's draft, never the device's active week plan.

> 2026-09-14 folded from mp-115, mp-116, mp-117
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-235 · Confirm lands on the shopping list, and laying meals across days stays optional
- category: The planning conversation
- status: approved
- image: docs/new_mealplanning/figma/18-all-days-collapsed-confirm.png
- caption: MealBuddy's day slotting, which was rejected as the default.
- svg2: docs/ssot/decisions/images/mealplanning/mp-235-2.svg
- screen: Vana chat
- source: vana-chatbot-update-plan.md; OPEN-QUESTIONS.md; memory 09-07

**Context.** Confirm is the moment of value. A confirmed plan is a collection of meals with servings. MealBuddy assigns every meal to a day at generation. Calendar, email and PDF integrations were candidates, and the first build landed on a bare route with no tab bar.

**Question.** What does confirming a plan give the athlete, and where do they land?

**Decision.** Confirm shows a "you're set" card with the week, the cooking sessions, the size of the list and where things live, plus a plain-text share and a "remind me the night before cook day" chip; no calendar, email or PDF in the first version. The athlete lands on the main screens with the Food tab's Shopping part open, so the tab bar is there. The chips after it are Open shopping list, Lay it across the week and Adjust; laying it across shows read-only day cards, and an athlete who never taps it keeps the plan as a set of meals with servings. Example: an athlete confirms, taps the reminder chip, lands on Food > Shopping with the tab bar showing, and never lays the plan across the week, so it stays a set of meals with no days attached.

**Why.** Most of the felt value at a fraction of the cost. The shopping list is the moment of value and the athlete should not be stranded off the shell. Research on batch cooks says collections, not day grids.

**What else was considered.** Calendar and email APIs. A bare food route. MealBuddy's Day 1 to Day 6 slotting up front, which the research argues against.

**What it touches.** ConfirmedCard, share service, reminder service, router food parameter, planWeek, week part.

**Details.** Precisely:
1. Confirm shows a "you're set" card with the week, the sessions, the list size and where things live. It offers an OS share sheet for plain text and a "remind me the night before cook day" chip. No calendar, email or PDF in the first version.
2. Confirm lands on the main shell with the Food tab's Shopping segment selected, so the tab bar is present.
3. The chips after confirm are Open shopping list, Lay it across the week, and Adjust. Laying it across renders read-only day cards. Athletes who ignore it keep the collection-only plan.

> 2026-09-14 folded from mp-118, mp-119, mp-120
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-236 · The composer's plus menu: pantry, fridge photo and browse
- category: The planning conversation
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-236-2.svg
- screen: Vana chat
- source: memory 09-07; vana-chatbot-update-plan.md; memory 09-03

**Context.** The composer is the input row at the bottom of the planning chat. It takes text, voice, photos and a way into the catalog. Lee reviewed the layout on the simulator on 2026-09-07. The prototype offered a generic pantry list, and other AI surfaces charge credits.

**Question.** How is the message box laid out, and what does its plus menu offer?

**Decision.** The composer, the message box at the bottom of the planning chat, is one pill: a plus on the left, a mic while it is empty and a send arrow once there is text; on the web there is no camera and no mic. The plus opens Snap my fridge, Choose a photo, Use what I have and Browse meals. Snap my fridge uses the same photo path as meal logging and is counted but costs no credits, because Pro already pays for it; Browse meals opens the catalog, where a tick on any meal adds it to the Draft. Example: an athlete taps Use what I have and gets up to eight chips drawn from their last 30 days of logs, their saved meals and their last plan; tapping "Use these" saves them as pantry items and marks those rows as had on the shopping list.

**Why.** Lee's 2026-09-07 simulator pass. Personalisation only reads as personal when shown. AI surfaces stay on and meal planning is already paid for. Lee wanted the v5 browse-sheet pattern inside the app's own catalog.

**What else was considered.** Separate composer buttons, rejected on the simulator. A hardcoded staples list, or a top 14. Charging credits per photo, which double-charges a Pro feature. Look-only browsing from chat.

**What it touches.** Chat composer, speech to text, askPantry, set_pantry, grocery.ts, pantry_photo action, ai_usage, MealCatalogBrowser, MealAddButton, refreshDraft.

**Details.** Precisely:
1. One pill with a flat plus on the left, a mic while empty and an up-arrow send when there is text. Web gets no camera and no mic.
2. The plus sheet offers Snap my fridge, Choose a photo, Use what I have and Browse meals.
3. The pantry question seeds a chip grid from the athlete's own 30-day logs, saved-meal components and the last plan's have or checked items, top 8. "Use these" writes pantry items and marks shopping rows as had.
4. Snap my fridge reuses the meal-logging upload path and vision model. It is metered with no credit charge. Pro is the price.
5. Browse meals opens the catalog tied to the conversation. Every card carries a tick that picks into the draft, and the chat refreshes its draft on return.

> 2026-09-14 folded from mp-122, mp-123, mp-124, mp-125
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-237 · General mode's empty state, and what each failure shows
- category: The planning conversation
- status: rejected
- image: none
- caption:
- screen: Vana chat
- source: 05-flutter-feature.md

**Context.** Vana has a general conversation for questions and a planning one for building a week. The chat can fail four ways: offline, rate-limited, out of credits, or no Pro.

**Question.** What the general chat looks like when empty, and what the athlete sees when a turn fails.

**Decision.** 1. The general conversation opens with three example chips and no plan bar. It can offer "Start a meal plan" or "Not now".
2. Offline shows a bubble. A rate limit says "Give me N seconds". Out of credits opens the credits paywall. No Pro goes to the Pro screen.

**Why.** General questions should not look like planning, and each failure has one recoverable outcome.

**What else was considered.** none recorded

**What it touches.** Vana chat screen, transport.

> 2026-09-14 folded from mp-126, mp-127
> 2026-09-14 rejected: the general conversation doesn't need example chips.  we can think of a potential opener though based off of which route they are on.  like "I see you are planning an event" or "I see you are carb loading" or something like that

## mp-238 · Meal planning is part of the Food tab, and it opens on the plan, not the chat
- category: Plan tab
- status: approved
- image: docs/_archived/uiux/alex_screens/Plan.png
- caption: An early concept of the Plan tab.
- svg2: docs/ssot/decisions/images/mealplanning/mp-238-2.svg
- screen: Food tab
- source: synthesis-and-recommendations.md; 05-flutter-feature.md

**Context.** The Food tab holds Meals, Formulas and Shopping. An early concept, the Sage canvas, opened meal planning on a chat. Six live tests were run with real users, and research finding 6 says users land on a screen with structure and the assistant built into it.

**Question.** Where does meal planning live, and does the athlete land on the chat or on the plan?

**Decision.** Meal planning is one section of the Food tab, beside Meals, Formulas and Shopping; it is not a tab of its own. It opens on the plan itself, and Vana is reached from there: the chat is where the athlete goes for more, not where they start. The Vana message card at the top of the Plan tab opens her general conversation, not a planning one. Example: an athlete opens Food, picks the plan section and sees this week's meals; tapping Vana's card at the top opens the everyday conversation, not a new plan.

**Why.** Nobody opened with chat in the six live tests, and users skim chat. The day note at the top is about the day, not the plan.

**What else was considered.** A separate Plan tab, or a chat-first tab. The Sage canvas.

**What it touches.** Tabs screen, food routes, Plan tab, Vana entry points, router.

**Details.** Precisely:
1. Meal planning is a segment of the Food tab beside Meals, Formulas and Shopping. It is not its own tab.
2. The Plan tab is the plan and Vana is reached from it. Chat is escalation, not the landing.
3. The Vana message card at the top of the Plan tab opens the general conversation, not a planning one.

> 2026-09-14 folded from mp-128, mp-129, mp-140
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-239 · The Plan tab lists each meal as a row you tap or swipe
- category: Plan tab
- status: approved
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: A confirmed plan as a tile list.
- svg2: docs/ssot/decisions/images/mealplanning/mp-239-2.svg
- screen: Plan tab
- source: plan-tab-v2.md; 05-flutter-feature.md; 07-verification-release.md; synthesis-and-recommendations.md; 03-backend.md

**Context.** The Plan tab shows the confirmed week. The prototype drew a "Your day" grid, a separate page per plan, a history of past plans and a settings gear in the header. The app's other lists already use rows you swipe. The dietitian will not recommend logging every day.

**Question.** What does the Plan tab show, and what can the athlete do with each meal on it?

**Decision.** The Plan tab shows a message from Vana, then every plan meal as one row with its name, meal type and servings, and two buttons: Add meal and New meal plan. Tapping a row opens a sheet to change servings, swap, remove or mark it eaten; swiping right removes it with Undo, and swiping left swaps it. A swap keeps the row's identity, so changing servings afterwards changes the right one. Ate it waits for the server, logs the meal and takes one serving off, and nothing reminds the athlete to log each day. Example: a dinner row shows 2 servings; the athlete taps Ate it, the meal is logged from the plan and the row shows 1; after the last serving, Ate it no longer shows.

**Why.** Lee wanted the plan on its own, without a brief or shopping on the screen. Matching meals by name went wrong when two meals had the same name. A count of servings left does the logging job without a daily logging habit, which the dietitian will not recommend.

**What else was considered.** A "Your day" grid, detail routes and a plans history, which Lee cut. Delete-and-insert on swap, which loses the id. A logging loop. Storing macro totals and dividing at log time.

**What it touches.** Plan tab, plan tile sheet, Swap screen, PlanList, logFromPlan, meal_logs, log_from_plan RPC, coverage service.

**Details.** Precisely:
1. A message from Vana, then every meal as a tile with icon, name, slot chip and servings. The buttons are Add meal and New meal plan. No day grid, chevron, detail route, swipe hint, status tag, Edit button or gear.
2. Tap opens a sheet with a servings stepper, Swap, Remove and Ate it. Swipe right removes with Undo. Swipe left swaps.
3. A swap keeps the same plan-meal id, so a servings edit after a swap is exact.
4. "Ate it" waits for the server, hides when no servings are left, writes a meal log with source plan and decrements servings. There are no daily logging reminders.
5. Plan meal macros are stored per serving.

> 2026-09-14 folded from mp-130, mp-135, mp-136, mp-137, mp-138
> 2026-09-14 approved
> 2026-09-14 picture refreshed at 1.26.0+1, 469da691, replacing test/features/meal_planning/presentation/goldens/plan_confirmed_light.png
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-240 · The week starts on Sunday and cook days are fixed
- category: Plan tab
- status: rejected
- image: none
- caption:
- screen: Plan tab
- source: 05-flutter-feature.md; memory 09-03

**Context.** The week start decides which plan is this week's. The server already used Sunday and a Dart comment said Monday. Cooking sessions need dates, and the athlete's real cook day is not modelled anywhere.

**Question.** Which day the plan week starts, and which days cooking sessions fall on.

**Decision.** 1. The plan week starts on Sunday.
2. Cooking sessions fall on the week start, plus three and plus five days. The athlete's real cook day is not modelled yet and stays an open question.

**Why.** The server already used Sunday. Deterministic sessions without asking.

**What else was considered.** Monday-start weeks, which disagreed with the server. Asking the athlete's cook day, deferred.

**What it touches.** Week start, plan queries, Plan tab header, session dates, review sheet, check-in opener.

> 2026-09-14 folded from mp-131, mp-132
> 2026-09-14 rejected: nope it is not this, it is variable.  a user can change which day the week starts and how many days and what not as settings.  we can have this as default but it has to be able to be changed

## mp-241 · One confirmed plan per week, and a fresh draft per conversation
- category: Plan tab
- status: approved
- image: test/features/meal_planning/presentation/goldens/plan_draft_light.png
- caption: The Plan tab with a draft in progress.
- svg2: docs/ssot/decisions/images/mealplanning/mp-241-2.svg
- screen: Plan tab
- source: plan-tab-v2.md; 03-backend.md

**Context.** Plans used to be filed by the day their week starts, so a new conversation reopened the confirmed plan with three meals already in it. The Plan tab expects exactly one live plan for the week.

**Question.** How do plans, drafts and conversations fit together, and what does "New meal plan" do?

**Decision.** Every conversation with Vana builds its own draft plan, so an athlete can hold any number of drafts but only one confirmed plan per week. Confirming a draft archives every other plan for that week, drafts from other conversations included, and the Plan tab keeps the confirmed plan until a new one is confirmed. "New meal plan" archives the plan it is on and starts a fresh, empty draft. Example: an athlete starts a draft in Monday's conversation and another in Wednesday's; confirming Wednesday's archives Monday's draft and the week's old confirmed plan.

**Why.** Filing plans by week made a new conversation reopen the confirmed plan with meals already in it.

**What else was considered.** One plan per week shared by all conversations. Archiving only the previous confirmed plan as the prototype did, which left stray drafts.

**What it touches.** plan.ts resolvePlan, confirm_meal_plan RPC, vana-action, Plan tab button.

**Details.** Precisely:
1. Each conversation keys its own draft. A partial unique index allows one confirmed plan per athlete-week and any number of drafts.
2. Confirming archives every other non-archived plan for that week, drafts from other conversations included. The Plan tab keeps the confirmed plan until a new one is confirmed.
3. "New meal plan" archives the scope's plan and returns a fresh empty draft.

> 2026-09-14 folded from mp-133, mp-134
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-242 · The Meals tab is for looking; meals reach a plan from the plan
- category: Meals tab and library
- status: approved
- image: docs/ssot/decisions/images/mealplanning/meals-tab.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-242-2.svg
- screen: Meals tab
- source: memory 08-31; 05-flutter-feature.md

**Context.** Meals is the catalog: the library of about 1,900 meals plus the athlete's own saved foods. Meals reach a plan through Vana's meal pickers or a swap on a plan row. The app keeps a fuel log on the phone, but many entries are just a typed name.

**Question.** What is the Meals tab for, how do search results look, and where do Recents come from?

**Decision.** The Meals tab is for looking: four rows of cards, Recents, My Foods, Assemblies and Recipes in that order, with a search bar behind an icon and a filter by meal type and by recipe or not. Add and Swap buttons show only when the athlete arrived from a plan row to swap a meal. Search results use the same cards, meals the athlete's allergens rule out are greyed rather than hidden, and a Vana row at the bottom offers to build the week. Example: offline, Recents come from the logs on the phone and skip entries that are only a typed name; once online, the server's list of recent meals replaces them.

**Why.** Browsing should not be a second way to change the plan; adding belongs to the plan. One card, one look across the tab. Only the server can match a logged name to a library meal.

**What else was considered.** An Add button on every card, which gives plain browsing two ways to change the plan. A dedicated dense row for results.

**What it touches.** Meal catalog, search_meals, MealCatalog, catalog controller, Recents screen.

**Details.** Precisely:
1. Four rails in this order: Recents, My Foods, Assemblies and Recipes. A search icon reveals a search bar and a filter popover narrows by meal type and by recipe or no-recipe. Add and Swap buttons appear only in swap mode from a plan tile.
2. Search results reuse the rail card. Meals excluded by the athlete's allergens are greyed, not hidden. A Vana row at the bottom offers "Want me to build the week instead?".
3. Offline, Recents come from local logs and skip name-only entries. Online, the server's recent meals list replaces the local one.

Semantic search runs once a query reaches three characters, and the type filter is dropped while a query is active.

> 2026-09-14 folded from mp-141, mp-142, mp-143
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-243 · Cooking mode shows one step per screen, with timers read from the step
- category: Recipes and cooking
- status: approved
- image: docs/ssot/decisions/images/mealplanning/cooking-mode.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-243-2.svg
- screen: Cooking mode
- source: 05-flutter-feature.md; recipe-directions-and-cooking-mode.md; README

**Context.** From a meal's detail screen the athlete can start cooking mode, a hands-busy view read from across a counter. Steps come from many origins and are not structured. The shared notification service only talks to OneSignal.

**Question.** How does cooking mode work on the phone?

**Decision.** Cooking mode has three parts: an overview, one big step per screen, and a done screen that asks for a thumbs up or down. The athlete moves by swiping, by tapping large zones or with Back and Next, and the screen stays awake only while they cook. Up to three timers per step are read from the step's own words, run side by side and keep running when the athlete moves on; a finished timer sends a notification and a vibration, with the ringing chip on screen as the fallback and no sound, and waving a hand over the phone to move on works only on phones. Example: a step reads "simmer for 10 to 12 minutes", so its chip sets a 12-minute timer, which keeps running while the athlete reads the next step and buzzes the phone when it ends.

**Why.** A screen that stays on only when needed. Deterministic timers with no model call. The shared notification service has no immediate-show call. Browsers expose no proximity API.

**What else was considered.** In-app audio, which would need an asset and a sound session for a case the notification already covers.

**What it touches.** CookingSessionController, CookingModeScreen, cooking timers, cooking mode route.

**Details.** Precisely:
1. Three phases: an overview, one big step per screen, then a done screen that asks for a thumb vote. Steps move by swipe, oversized tap zones, and Back and Next. The wake lock is held only during the cooking phase.
2. Timer chips are parsed from each step's text, at most three per step. Timers run at the same time and keep running when the athlete moves on.
3. A finished timer fires a local notification and a vibration. The ringing chip on screen is the fallback. No audio.
4. Wave-to-advance over the proximity sensor exists only on phones.

A duration must be between 5 seconds and 12 hours. A range takes its upper bound. Timers tick once a second.

> 2026-09-14 folded from mp-147, mp-148, mp-149, mp-150
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-244 · The server builds the shopping list at confirm and after every edit
- category: Shopping list
- status: approved
- image: docs/ssot/decisions/images/mealplanning/shopping-tab.png
- caption: The shopping list grouped by aisle.
- svg2: docs/ssot/decisions/images/mealplanning/mp-244-2.svg
- screen: Shopping tab
- source: plan-tab-v2.md; 05-flutter-feature.md; memory 09-07; memory 09-02
- work: pending

**Context.** When the athlete confirms a plan they land on the Shopping tab. Building the list means adding up ingredients across every meal and serving. Most plan edits write locally first. The prototype had aisle groups, a pickup placeholder, and filtered out items the athlete already has.

**Question.** Where is the shopping list built, and what does the Shopping tab show?

**Decision.** The server adds up the list by fixed rules when the athlete confirms, Confirm waits until the server says it is done, and the list is rebuilt after every plan edit; the phone never works it out itself. The tab shows nine aisle groups, each row with a checkbox and a quantity, in imperial units unless Settings says metric; a row used by more than one meal carries a count that opens a list of those meals, which is also the way back to their recipes. Items marked as had are hidden and only Vana's "Add back" brings them back; there is no per-row "have it" switch and no pickup button, and Share sends plain text. Example: two meals in the plan both use onions, so the list shows one onion row with a count of 2 in imperial units, and tapping the count lists both meals and leads back to either recipe.

**Why.** The list is the moment of value and must exist before the athlete lands on it. Kroger and other surfaces read it too, so there is one builder. US users read imperial. Lee on 2026-09-14: a tap back to the original recipe, through minimal UI.

**What else was considered.** Computing on the device, which gives two builders that disagree. A metric default. Keeping the unwired per-row toggle.

**What it touches.** grocery.ts, confirm_meal_plan, Shopping tab, ShoppingListController, quantity formatter.

**Details.** Precisely:
1. The list is aggregated deterministically on the server at confirm, and confirm waits for the server's acknowledgement. It is rebuilt after every plan edit. The device never computes it.
2. Nine aisle groups. Each row has a checkbox and a quantity. A row from more than one meal carries a count badge that opens a sheet listing those meals. Share sends plain text. No pickup button.
3. Quantities render imperial unless Settings says metric, on screen and in the shared text.
4. Items marked as had are filtered out and only Vana's "Add back" restores them. There is no per-row "have it" toggle. That toggle is logged as an open question.
5. Each row can tap back to the recipe or recipes it came from, through the count-badge sheet every multi-meal row already has, so no new control is added.

Plans confirmed before a change keep their old quantities until reconfirmed. Always-have items match on whole phrases, and catalog rows with a blank quantity get a default.

> 2026-09-14 folded from mp-151, mp-152, mp-153, mp-154
> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-15 approved by Lee
> 2026-09-15 picture refreshed at 1.26.0+1, f30e3897, replacing test/features/meal_planning/presentation/goldens/shopping_list_light.png
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-245 · Feedback typed to Vana is saved for the team in the athlete's own words
- category: Feedback loop
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-245-2.svg
- screen: Vana chat
- source: spec.md; ticket 01; 02-contract.md; archive ticket 01
- work: pending

**Context.** The only existing channel was a Wiredash form buried in Settings that nobody used. Vana is already the surface athletes talk to. In testing Vana apologised instead of filing about half the time, filed feature requests under the wrong heading, and twice said "saved" without calling the tool.

**Question.** Is telling Vana something the way athletes give feedback?

**Decision.** Yes. A complaint, praise or suggestion typed to Vana is saved for the team in the athlete's own words; a taste comment such as "not those" is not. Vana must actually save it before she says it is saved, and each saved item also goes to Wiredash, the bug-report tool, so typed and shaken reports end up in one place. How the phone files that Wiredash entry for the server is still open. Example: an athlete types "you keep getting this wrong"; that counts as feedback and is saved.

**Why.** The athlete should not have to find a form. Position beat wording. Feature requests were going to the wrong pile. Lee on 2026-09-14: one uniform Wiredash entry for everything, if possible.

**What else was considered.** A feedback form or screen. Silence on every feedback message, which leaves a question unanswered.

**What it touches.** save-feedback tool, user_feedback table, chat.ts, general prompt.

**Details.** Precisely:
1. A complaint, praise or suggestion typed to Vana files a row in the athlete's own words, with a sentiment, an about-field and the conversation id. Taste comments such as "not those" write no row. The Wiredash card stays for anything that needs a screenshot.
2. A message that is both a complaint and a question keeps Vana's answer. A pure vent gets the acknowledgement alone.
3. "I have told you" and "you keep getting this wrong" count as feedback. The feedback rule sits at the top of the prompt's rules.
4. A request for something new is filed as a suggestion. Praise or a complaint about Vana's meal ideas is about Vana, even when the athlete says "the app".
5. Vana must call the tool before claiming feedback is saved, and the conversation id travels apart from the plan scope so general mode keeps it.
6. Vana's feedback tool also files a Wiredash entry, so typed feedback and shaken reports land in one place. Wiredash entries are created on the device, so the server tool hands the row to the app to file. This is the reading; the device hand-off is the open detail.

> 2026-09-14 folded from mp-155, mp-157, mp-158, mp-159, mp-162
> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-246 · After saving feedback Vana says nothing more, and a new athlete is told once they can type it
- category: Feedback loop
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-246-2.svg
- screen: Vana chat after feedback
- source: ticket 01; memory 09-10; 02-contract.md

**Context.** When Vana saves feedback a "Saved for the team" row appears. On the Haiku model her own reply after it tended to apologise and start troubleshooting, and three prompt rewrites failed. Athletes will not know they can type feedback unless something tells them, and Vana's prose can be paraphrased away.

**Question.** What does Vana say after saving feedback, and how does a new athlete learn they can type it?

**Decision.** Nothing more: the "Saved for the team" row is the whole reply, and anything the model writes after it is thrown away, on screen and in the saved conversation. A brand-new athlete's first conversation shows one fixed line after Vana's opener, "Have feedback for me? Just type it here.", written by the server rather than by Vana, and it never appears again. Example: an athlete vents that the plan was wrong; they see "Saved for the team" and no apology or troubleshooting after it.

**Why.** Lee ruled that the athlete should not be troubleshot when venting. One nudge is enough, and server-authored text cannot be paraphrased away.

**What else was considered.** Clamping Vana to one sentence, which kept the apology. A stronger model for that turn. Putting the line in the persona prompt, or repeating it.

**What it touches.** chat.ts silenceAfterFeedback, feedback_saved part, feedback_prompt part, FeedbackPromptRow.

**Details.** Precisely:
1. The "Saved for the team" row is the whole acknowledgement. Every later text delta from the model is dropped from the stream and the transcript.
2. After the opener of a brand-new athlete's first conversation, the server appends a fixed "Have feedback for me? Just type it here." part. The model never sees it. It never appears again.

> 2026-09-14 folded from mp-156, mp-161
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-247 · The praise test checks that praise reads as positive, not what it is about
- category: Feedback loop
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-247.svg
- screen: none (algorithm/data)
- source: ticket 01
- detail: yes

**Context.** Live evals are automated tests that send messages to Vana on the dev server and check the feedback row she saves. Praise such as "this app planned my week perfectly" names the app while describing Vana's planning.

**Question.** When the automated test sends Vana praise, what must the saved row get right?

**Decision.** Only that it is positive, with a rating. The test records what the praise was about but does not fail on it, because praise like "this app planned my week perfectly" names the app while describing Vana's planning, and either answer is fair. Example: the test sends "this app planned my week perfectly"; if the row is positive with a rating, the test passes whether the row says the praise is about the app or about Vana.

**Why.** Praise naming "this app" while describing Vana's planning is genuinely either.

**What else was considered.** none recorded

**What it touches.** Personalisation eval.

**Details.** Precisely:
1. The praise eval checks for positive sentiment and rating.
2. It logs the about-field but does not assert on it.

> 2026-09-14 folded from mp-160
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-248 · Problem reports go through Wiredash, from a card or a shake
- category: Feedback loop
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-248-2.svg
- screen: Vana chat, shake sheet
- source: memory 09-08

**Context.** Some problems need a screenshot, which typed feedback cannot carry. Wiredash exists but its full flow asks for an email and several steps.

**Question.** How does a problem that needs a screenshot reach the team?

**Decision.** Through Wiredash, the bug-report tool, reached two ways. When an athlete reports a problem to Vana, a card appears in the chat with a "Send to the team" button that opens Wiredash; Vana never says she sent anything herself. Shaking the phone twice opens a sheet and then a two-step Wiredash with no email asked and an optional screenshot. Example: an athlete shakes the phone twice (each shake 3.2 g or more), writes what went wrong and adds a screenshot in two steps; the text also lands in the app's own feedback table.

**Why.** The card sends, not Vana. A two-step Wiredash is one people will finish.

**What else was considered.** none recorded

**What it touches.** Problem report card, shake detector, Wiredash config, feedback table.

**Details.** Precisely:
1. A problem report produces a card in the chat with a "Send to the team" button that opens Wiredash. Vana never claims to have sent anything and no longer mentions shaking.
2. Two shakes open a Kyle sheet, then Wiredash cut down to two steps with no email prompt and an optional screenshot. The text also lands in the app's own feedback table.

Shake threshold 3.2 g or more, twice.

> 2026-09-14 folded from mp-163, mp-164
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-249 · Pro: what it covers and what it costs
- category: Pro and paywall
- status: rejected
- image: none
- caption:
- screen: Pro screen
- source: README; memory 09-01; 04-entitlement.md

**Context.** Meal planning needed a paywall. The app already sells AI credit bundles for chat. Apple product ids are team-unique, so prod ids need their own suffix.

**Question.** What Pro gates, what it costs, and whether buying it grants credits.

**Decision.** 1. Meal planning is gated by a Pro subscription, enforced on the server through the entitlements table, and never debits credits. General chat keeps its one-credit debit for free users and is free for Pro.
2. Pro is 9.99 dollars monthly and 69.99 dollars annual on both stores in all territories. The RevenueCat offering is the default one.
3. Buying Pro grants no credit bundle.

**Why.** One gate, enforced where it cannot be bypassed.

**What else was considered.** none recorded

**What it touches.** Entitlements table, Pro screen, RevenueCat offering, store products.

**Details.** Prod Apple product ids carry a prod suffix. Apple equalises prices across regions.

> 2026-09-14 folded from mp-166, mp-167, mp-172
> 2026-09-14 rejected: we are not doing freemium.  7 day free trial and purchase.

## mp-250 · Shipping dark: the gate flag and the Buy button
- category: Pro and paywall
- status: rejected
- image: none
- caption:
- screen: Pro screen
- source: 07-verification-release.md; 03-backend.md; 04-entitlement.md

**Context.** The paywall design and the App Review screenshot were not ready. A gate flag decides whether the Food tab and the functions are locked.

**Question.** How the feature ships to prod before the paywall and store products exist.

**Decision.** 1. Prod ships with the gate on and no Food tab. The feature opens later by granting entitlements or enabling purchase.
2. A missing gate flag means the gate is on everywhere except dev. Dev builds force it off. Prod builds fail if the key is absent.
3. A subscription status still resolving counts as locked. A deep link into meal planning lands on the Pro screen, not an error.
4. The Pro screen shows real store prices and a working Restore. Buy waits behind a purchase flag until the paywall design and the review screenshot land.

**Why.** Nothing unfinished reaches a paying customer, and a missing flag fails closed.

**What else was considered.** none recorded

**What it touches.** Gate flag, Pro screen, purchase flag, router.

> 2026-09-14 folded from mp-168, mp-169, mp-170, mp-171
> 2026-09-14 rejected: we won't ship without this purchase/7day free trial thing.  so no mealplanning without this

## mp-251 · Webhook ordering and the tester switch
- category: Pro and paywall
- status: rejected
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-251.svg
- screen: none (algorithm/data)
- source: 04-entitlement.md; 05-flutter-feature.md; memory 09-01
- detail: yes

**Context.** RevenueCat events can arrive out of order. Testers need to pass both the tab gate and the function gate without buying.

**Question.** How out-of-order store events and internal testers are handled.

**Decision.** 1. An event older than the stored row is acknowledged as stale and ignored. A transfer event moves the entitlement between users.
2. The seven-tap tester switch also writes the internal flag on the server. The flag is self-service and accepted as a team convenience. The webhook's entitlement row remains the real paywall.

**Why.** A late event must not roll a subscription back, and testers need one switch.

**What else was considered.** none recorded

**What it touches.** Webhook handler, internal-device switch, users.internal flag.

> 2026-09-14 folded from mp-173, mp-174
> 2026-09-15 rejected by Lee: we are not using the entitlements table anymore

## mp-252 · Vana runs as three Supabase edge functions that speak the app's existing stream format
- category: Data, sync and backend
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-252.svg
- screen: none (algorithm/data)
- source: README; 02-contract.md; 03-backend.md
- detail: yes

**Context.** The prototype ran its server on Vercel. The app already reads a stream of JSON lines (the NDJSON envelope) from the old chat function, and the prototype's saved example files, the fixtures, define what each message looks like.

**Question.** Where does Vana's server code run, and how does the app talk to it?

**Decision.** Vana runs as three Supabase edge functions, small server programs beside the database: chat, action and day notes; there is no Vercel service. They answer in the stream format the app already reads, with status lines added, the prototype speaks the same format, and the saved fixture files are the one truth for how a message is shaped, for both clients. The functions read the database as the athlete who called them, so the database's own row rules decide what they see; the all-access service key is kept only for call logs, pair refresh and macro fills. Example: when Lee sends Vana a message, the chat function reads as Lee and sees only Lee's rows, and writing the call log is one of the three jobs allowed the service key.

**Why.** One backend and one message format, and the database itself decides who may read what.

**What else was considered.** none recorded

**What it touches.** vana-chat, vana-action, vana-day-notes, contracts file, fixtures.

**Details.** Precisely:
1. Vana runs as three Supabase edge functions: chat, action and day notes. There is no Vercel service.
2. The wire is the existing NDJSON envelope extended with status lines. The prototype speaks the same transport.
3. The wire shape is camelCase and the frozen fixture files are the truth for both clients.
4. The functions read as the caller so row-level security filters. The service key is kept only for call logs, pair refresh and macro fills.

> 2026-09-14 folded from mp-175, mp-176, mp-177, mp-178
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-253 · Openers live in the chat function, and the old chat route survives one release
- category: Data, sync and backend
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-253-2.svg
- screen: Vana chat
- source: 03-backend.md; memory 08-26
- detail: yes

**Context.** App versions already in people's hands call the old chat address (route). General Openers used to be made up on the fly and never saved.

**Question.** Does the Opener get its own server function, and what happens to the old chat?

**Decision.** There is no separate function: a flag on the ordinary chat call makes Vana write the Opener, and general Openers are now saved. The old chat function becomes Vana in general mode under the old route, so apps already shipped keep working and keep their unsaved Opener, and the app's old chat path redirects there. The old route stays until the lowest app version we support is past 1.24, and the old tables are renamed to Vana names while the old names keep working. Example: an athlete still on app 1.24 opens chat and gets Vana in general mode through the old route, with an Opener that is not saved; on a newer app the Opener comes from the chat call and is saved.

**Why.** Apps already shipped keep working while the app moves over.

**What else was considered.** none recorded

**What it touches.** vana-chat opener flag, old chat function, table renames and views.

**Details.** Precisely:
1. There is no separate opener function. An opener flag on the chat call runs it. General openers are persisted. The old chat route keeps its unstored opener for shipped clients.
2. The old chat function becomes Vana in general mode under the old route, and the app's old chat path redirects there. The route stays until the minimum app version passes 1.24. The old tables are renamed to Vana names with compatibility views under the old names.

> 2026-09-14 folded from mp-179, mp-180
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-254 · Small plan edits save on the phone first; changes the server builds on wait for it
- category: Data, sync and backend
- status: approved
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-254-2.svg
- screen: Plan tab
- source: 05-flutter-feature.md; plan-tab-v2.md; memory 09-01

**Context.** The app is offline-first, but shopping lists, day notes and coverage are computed on the server, and a coach may act on an athlete's plan.

**Question.** Which meal-plan changes save on the phone first, and which wait for the server?

**Decision.** Small edits save on the phone at once and upload later, and when two copies disagree the last one written wins: servings, remove, session, shopping ticks, day slots, settings, comments, memory delete and saved-meal notes. Changes the server works from wait for it: pick, swap, plan day, new plan, log-from-plan and confirm. If one of those fails, the plan goes back to how it was and a short message at the bottom of the screen says it needs a connection or needs Pro, and with no connection at all the app says so before it sends anything. Example: with no signal, an athlete ticks eggs on the shopping list and the tick stays, but tapping swap on a dinner shows the needs-connection message and the dinner is unchanged.

**Why.** Anything the server computes from must reach it, and a failure must never leave a half-applied plan.

**What else was considered.** none recorded

**What it touches.** Meal plan repository, plan controller, screens.

**Details.** Precisely:
1. Servings, remove, session, shopping ticks, day slots, settings, comments, memory delete and saved-meal notes write locally first and upload later, last writer wins.
2. Pick, swap, plan day, new plan, log-from-plan and confirm wait for the server.
3. A failed server write restores the previous plan and throws a needs-connection or Pro-required error the screen catches with a snackbar. Offline is caught before any request is made.

> 2026-09-14 folded from mp-181, mp-182
> 2026-09-14 approved
> 2026-09-14 picture reused from test/features/meal_planning/presentation/goldens/plan_confirmed_light.png
> 2026-09-14 picture refreshed at 1.26.0+1, 469da691, replacing test/features/meal_planning/presentation/goldens/plan_confirmed_light.png
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-255 · The meal library stays on the server, and plans and memories sync only when needed
- category: Data, sync and backend
- status: approved
- image: docs/ssot/decisions/images/mealplanning/meals-tab.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-255-2.svg
- screen: Meals tab
- source: 05-flutter-feature.md; plan-tab-v2.md; 06-sync-schema-envs.md
- work: pending

**Context.** The meal library is about 1,900 meals, each with an embedding, the numbers used to search meals by meaning. The app's rule is that each kind of data syncs when it is needed, never all at once at start-up. Entitlements are written only by the webhook.

**Question.** Which meal-planning data is copied to the phone, and when does it sync?

**Decision.** The meal library is never copied to the phone: search and meal detail ask the server, keep answers in memory while the app is open, and fall back to a text search on the phone. Plans and Memories sync the first time the app loads them and when the athlete pulls down to refresh the Plan tab, and nothing syncs at start-up. There is no entitlements table: whether a person is in a Trial or paid is read from the store's subscription state, and nothing about it is copied or synced. Example: an athlete opens the app and nothing syncs; searching "oats" on the Meals tab asks the server, and pulling down on the Plan tab syncs the plans.

**Why.** The library is too big and too alive to mirror, and startup sync-all is banned. Lee on 2026-09-14: the entitlements table is not needed under the trial model.

**What else was considered.** none recorded

**What it touches.** Catalog repository, plan and memory repositories, entitlements table.

**Details.** Precisely:
1. The meal library is never mirrored. Search and detail hit the server, with an in-memory cache for the session and a local text search as fallback.
2. Plans and memories sync when their controller first builds and on pull-to-refresh on the Plan tab. Nothing syncs from startup.
3. There is no entitlements table. Whether a person is in trial or paid is read from the store subscription state, and nothing about it is mirrored or synced.

> 2026-09-14 folded from mp-183, mp-184, mp-185
> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-256 · An action targets the plan id, else the conversation's draft, else the week
- category: Data, sync and backend
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-256.svg
- screen: none (algorithm/data)
- source: 02-contract.md
- detail: yes

**Context.** An action is a change to a plan sent to the server. Actions come from parts in the chat, from the Plan tab and from the Review sheet, and not all of them know which plan they are for.

**Question.** Which plan does a change hit when it does not name one?

**Decision.** An action that names a plan hits that plan. If it names none, it hits the draft of the conversation it came from, and if there is no draft, the week's active plan. Example: in a planning chat that holds a draft, the athlete taps a chat part that names no plan; the change goes into that draft, not into the week's active plan.

**Why.** One order for every caller, so each change lands on the plan it means.

**What else was considered.** none recorded

**What it touches.** vana-action plan resolution.

**Details.** Precisely:
1. An action that names a plan id hits that plan.
2. Otherwise it hits the conversation's draft.
3. Otherwise it hits the week's active plan.

> 2026-09-14 folded from mp-186
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-257 · Home location is a Fact set in conversation
- category: Data, sync and backend
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-257.svg
- screen: none (algorithm/data)
- source: spec.md; ticket 02; memory 09-10

**Context.** Weather and the Kroger coverage check used the race venue because the app had nowhere to keep the athlete's home. No settings screen offered one.

**Question.** Where is the athlete's home kept, how is it set, and what uses it?

**Decision.** Home is four fields on the athlete's record, each empty until set: city, latitude, longitude and timezone; the athlete tells Vana, her profile tool turns the place into coordinates and saves them, and no settings screen edits home. Weather and the Kroger coverage check use home once it is set, and the race venue while it is empty. Clearing nutrition overrides is one flag on the profile copy, not a rebuild field by field. Example: an athlete tells Vana she lives in Birmingham, Alabama; the four fields fill in, and from then on weather and the Kroger check use Birmingham instead of the race venue.

**Why.** Home is something the athlete tells Vana once, and the rest of the app should read it from the one place it lives.

**What else was considered.** none recorded

**What it touches.** users table, profile tool, weather, Kroger coverage, settings controller.

**Details.** Precisely:
1. Home is four nullable columns on the user record: city, latitude, longitude and timezone. A profile tool geocodes what the athlete says in conversation and sets them. No settings screen edits home.
2. When home is set, weather and Kroger coverage use it. When it is null they fall back to the race venue.
3. Clearing nutrition overrides is one flag on the profile copy, not a field-by-field rebuild.

Device schema version 21.

> 2026-09-14 folded from mp-187, mp-188, mp-189
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-258 · Everything is dev-only until the cutover
- category: Data, sync and backend
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-258.svg
- screen: none (algorithm/data)
- source: spec.md; ticket 02; README; 06-sync-schema-envs.md

**Context.** Production's database has no pgvector, the add-on that stores the numbers for searching meals by meaning. The home-location change adds columns that every save of a user's record needs. The text bundled with the app was losing to an old cached copy.

**Question.** What reaches production before the cutover, and what must the cutover do?

**Decision.** Nothing from this work is pushed to the develop or release branches before the cutover, and the home-location database change goes out with it, because a build that reaches production before those columns exist fails every save of a user's record. The cutover's seed step recomputes the search numbers (embeddings) for the whole meal library, and it counts as done only when every meal has them. The text bundled with the app loads before the first screen and beats an old cached copy. Example: seeding production makes about 1,922 embedding calls, and the seed is not done while even one meal is still missing its embedding.

**Why.** A half-moved production would break sign-in for everyone.

**What else was considered.** none recorded

**What it touches.** Cutover runbook, seed script, content service.

**Details.** Precisely:
1. Nothing is pushed to the develop or release branches. The home-location migration rides the cutover, whose schema target reads 21. A build that reaches prod before the columns exist fails every users upsert.
2. The prod seed re-embeds the library. The verify step requires every row embedded before the seed counts as done.
3. Bundled content defaults load before the first frame and win over a stale cache.

About 1,922 embedding calls at seed time.

> 2026-09-14 folded from mp-190, mp-191, mp-192
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-259 · The Vana sheet and the Launcher are specced and built once, and the tokens beat the export
- category: Design system
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption: The glass sheet built once from the shared tokens.
- svg2: docs/ssot/decisions/images/mealplanning/mp-259-2.svg
- screen: Any screen with the launcher
- source: spec.md; tickets 05, 06; ticket 06; ticket 05; memory 09-11; archive ticket 09

**Context.** Any widget that carries the look of the app is built once, named after its written spec, and takes its colours and sizes from one set of tokens. The design export for the Vana sheet (the numbers handed over with the design) drew its own corner radius and its own dimming behind the sheet, called the scrim. The tab bar spec already kept a bottom-right slot free for an AI companion.

**Question.** How do the Vana sheet and the Launcher join the design system?

**Decision.** Each gets a written component spec drawn from the glass-surface and tab-bar tokens the app already has, and is built once in the shared widget library for the app shell (the frame of tab bar and screens) to use. Where the export's numbers differ from the tokens, the tokens win. The Launcher's mark is a speech-bubble outline, the first brand symbol on the shell, and it sits in the slot the tab bar kept free, with the scrim taken from the calendar sheet. Example: the export drew the sheet's corners at 26 and its scrim at 45 percent; the app uses the tokens, 24 and 60 percent, and the Launcher is 52 px.

**Why.** One set of tokens and one build of each widget, and because the Launcher uses the slot the tab bar spec already kept, that spec does not need approving again.

**What else was considered.** none recorded

**What it touches.** kyle_design navigation widgets, vana-sheet.md spec, tab bar spec.

**Details.** Precisely:
1. A component spec is written from the existing glass surface and tab-bar tokens. The widget is implemented once under that spec name in the shared library and the app shell composes it.
2. Token values beat the export where they disagree.
3. The launcher mark is a speech-bubble outline drawn as a path, the first branded glyph on the shell.
4. The launcher takes the tab bar's reserved utility slot and inherits the old floating button's clearance rule. The scrim comes from the calendar sheet.

Radius token 24 not the export's 26. Scrim token 60 percent not 45. Launcher 52 px.

> 2026-09-14 folded from mp-193, mp-194, mp-195, mp-196
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-260 · The selector and servings stepper are custom, and each meal slot keeps the prototype's colour
- category: Design system
- status: approved
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: Slot chips on plan tiles.
- svg2: docs/ssot/decisions/images/mealplanning/mp-260-2.svg
- screen: Food tab, meal cards
- source: 05-flutter-feature.md; 02-contract.md; plan-tab-v2.md; memory 09-11

**Context.** The shared segmented control (a row of options with one selected) shows the code names of its options, and the shared plus-minus control stretches full width. The prototype gave each meal type a fixed colour and always tinted meal icons electrolyte, one of the Kyle colours. A build agent later proposed ink-coloured icons on cards.

**Question.** Which meal-planning widgets are custom, and how are slots and meal icons coloured?

**Decision.** The Plan, Meals, Shopping selector and the servings stepper are built for this feature, not taken from the shared library. Each meal slot keeps the prototype's colour: breakfast orange, lunch electrolyte dark, dinner purple and snack dragonfruit (Kyle colour names). Meal icons on cards are ink-coloured in the current code, against the prototype's rule of electrolyte icons; Lee has not ruled on that yet and will look at it on a device. Example: on the Plan tab a breakfast tile's slot chip is orange and a dinner tile's is purple.

**Why.** Every label has to come from the app's content system, which the shared selector could not do, and the shared stepper did not fit.

**What else was considered.** none recorded

**What it touches.** Food tab segments, servings stepper, slot chip colours, meal icon tint.

**Details.** Precisely:
1. The Plan, Meals, Shopping selector and the servings stepper are custom feature widgets.
2. Breakfast is orange, lunch electrolyte dark, dinner purple and snack dragonfruit, as ported from the prototype.
3. Meal icons on cards are ink-tinted in the current code, against the prototype's electrolyte rule. Lee has not ruled and is to see it on a device.

> 2026-09-14 folded from mp-198, mp-199, mp-200
> 2026-09-14 approved
> 2026-09-14 picture refreshed at 1.26.0+1, 469da691, replacing test/features/meal_planning/presentation/goldens/plan_confirmed_light.png
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-261 · Planning parts land after Vana's words, and the macro pills show four numbers
- category: Design system
- status: approved
- image: test/features/meal_planning/presentation/goldens/plan_bar_expanded_light.png
- caption: Plan tiles with their macro pills.
- svg2: docs/ssot/decisions/images/mealplanning/mp-261-2.svg
- screen: Vana chat, Plan tab
- source: memory 09-07; memory 09-04; OPEN-QUESTIONS.md

**Context.** Cards and controls that arrived while Vana was still writing jumped into place. The planning chat's top bar had a subtitle. Meal cards, plan tiles, the plan bar and the review sheet all show macro pills.

**Question.** How do planning parts appear in the chat, and which macros do the pills show?

**Decision.** The parts Vana puts in a planning chat wait behind the typing dots until her words arrive, then grow and fade in one after another, and the plan bar fades and slides in. The planning chat's top bar reads only "New meal plan". Macros show by default as four pills, kcal, carbs, protein and fat, while the Meal picker's tiles show kcal only. Example: Vana writes her sentence about the week, then the plan parts appear one after another over 520 ms, each plan tile showing kcal, carbs, protein and fat.

**Why.** Parts should land, not jump, and the pills should carry only what an athlete reads at a glance.

**What else was considered.** none recorded

**What it touches.** Chat part animation, planning app bar, macro pills, show-macros setting.

**Details.** Precisely:
1. Planning parts wait behind the typing dots until prose arrives, then grow and fade in with a soft stagger. The plan bar fades and slides in.
2. The planning app bar reads "New meal plan" only.
3. Macros are on by default and show kcal, carbs, protein and fat only. The picker carousel tile stays kcal-only.

Stagger over 520 ms.

> 2026-09-14 folded from mp-201, mp-202, mp-203
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-262 · Either Lee or Xuan settles a decision, and the record runs from any laptop
- category: Design system
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-262.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-262-2.svg
- screen: none (algorithm/data)
- source: tickets 04, 05; memory 09-09; ticket 05; README
- work: pending

**Context.** The QA repo is Xuan's. The app wrote three component specs it needed before Xuan could approve them. The TanStack prototype, in its own repo, is the living reference and the source of the test fixtures. The earlier reading was that only Xuan approved, and only in the QA repo.

**Question.** Who approves decisions, where do they live, and who else can run the page?

**Decision.** Lee and Xuan both ratify, which means approve, specs and decisions, and one approval on the page from either of them settles it. The specs and this record stay in the app's own repo for now, and the QA repo is not touched. The page, its files and its tools work from any laptop, so another person can open it, see the same record and run the skills; the prototype stays in its own repo and none of its TypeScript is copied into the app. Example: Xuan opens the page on her own laptop and approves one of the three app-written component specs; it is settled, even if Lee has not looked yet.

**Why.** Lee on 2026-09-14: both ratify, keep things in docs/ssot for now, and Xuan must be able to run this from another laptop.

**What else was considered.** Ratification only in the QA repo and only by Xuan (the earlier reading).

**What it touches.** docs/ssot/decisions, the page artifact and its sharing, the skills, the QA repo boundary.

**Details.** Precisely:
1. Lee and Xuan both ratify. A spec or decision is settled when either has approved it on the page.
2. Specs and the decision record stay in the app repo under docs/ssot for now. The QA repo is not touched.
3. The decisions page, its files and its tooling are portable. Another person on another laptop can open the page, see the same record, and run the skills. Nothing depends on one machine.
4. The prototype stays in its own repo. No TypeScript is copied into the app. SQL migrations live in the app repo.

> 2026-09-14 folded from mp-204, mp-205, mp-206
> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-263 · Tests sit in three places, and the costly live-model ones never run in CI
- category: Process and scope
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-263.svg
- screen: none (algorithm/data)
- source: spec.md; 07-verification-release.md; memory 09-02
- detail: yes

**Context.** Server pure functions (code that only turns inputs into outputs), live checks against a real model and the app's controllers each need a different kind of test. Live checks cost money, and the plan-build flow talks to a real model.

**Question.** Where do the tests sit, and which ones run only by hand?

**Decision.** Tests sit in three places: the server's pure functions, against a fake database; live checks of how well Vana personalises, run by hand against dev; and the app's controllers, through the real code plus saved reference screenshots. A test feeds in data shaped like what its real source sends and never checks Vana's prompt wording. The eval, lifecycle and personalisation scripts and the full plan-build test never run in CI, the automatic checks on every push, and the Gate test that does run checks that the tab and the routes (screen addresses) agree. Example: the personalisation eval pays for real model calls, so it runs only when someone starts it against dev, never on a push.

**Why.** Tests that cost money or need a live model are run on purpose, not on every push.

**What else was considered.** none recorded

**What it touches.** test/, scripts/vana-eval, CI lists.

**Details.** Precisely:
1. Three seams: server pure functions with a fake database, live personalisation evals by hand against dev, and client controller tests through the real notifier plus goldens. A test feeds producer-shaped rows and never asserts on prompt wording.
2. The eval, lifecycle and personalisation scripts and the end-to-end plan-build test never run in CI. The Pro-gate flow that does run asserts that the tab and the routes agree.

> 2026-09-14 folded from mp-207, mp-208
> 2026-09-14 approved
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-264 · The launcher shows on three screens only, for now
- category: The sheet and launcher
- status: approved
- image: docs/ssot/decisions/images/mealplanning/timeline.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-264-2.svg
- screen: Main tabs, Plan tab, coach formulas
- source: Lee on the page 2026-09-14, on mp-049, mp-050, mp-053 to mp-057
- work: pending

**Context.** The launcher was built to appear on every ordinary screen, with one list of exclusions for auth, onboarding, paywall and Vana routes and a second list of flow screens whose bottom button it covered. Lee rejected that shape: it is a list nobody can maintain, and Vana is meant to be on a few screens for now.

**Question.** Which screens show the launcher?

**Decision.** Only three: the main tabs, the meal-planning screen and coach formulas. Every other screen has no launcher at all, and any page opened on top of one of the three hides it, so no screen ever has to be listed as an exception. Adding more screens is a later decision. Example: on the main tabs the launcher shows; the athlete opens a form on top of them and it hides, though nobody named that form anywhere.

**Why.** Lee on 2026-09-14: we only show Vana on a select number of screens right now and cannot maintain a list of exclusions.

**What else was considered.** Everywhere with exclusion lists (mp-049, mp-050, mp-053 to mp-056), rejected as unmaintainable. Naming pushed pages so the rule can see them (mp-057), unnecessary once any pushed page hides the launcher.

**What it touches.** vana_launcher_rule.dart, VanaCompanionObserver, root app widget.

**Details.** Precisely:
1. The launcher appears on three screens: the main tabs screen, the meal-planning screen and coach formulas. Every other screen has no launcher node at all.
2. There is no everywhere rule, no flow-screen list and no auth-or-onboarding exclusion list. The rule is an allow-list of three routes.
3. Any page pushed over one of the three hides the launcher, so a pushed form never needs to name itself.
4. Widening to more screens is a later decision.

> 2026-09-14 folded from mp-057
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-265 · One sheet height, and full screen only when its button is pressed
- category: The sheet and launcher
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-265-2.svg
- screen: Vana sheet, full-screen Vana chat
- source: Lee on the page 2026-09-14, on mp-059, mp-060, mp-063 to mp-066
- work: pending

**Context.** The sheet was built with three heights, an auto height that grew on the first send, drag thresholds in pixels, a flick rule, and a grabber that toggled height. Planning actions left the sheet for full screen. Lee rejected all of it as over-designed and janky.

**Question.** How tall is the sheet, and when does the athlete go to full screen?

**Decision.** The sheet has one height and its contents scroll inside it; it never grows or shrinks on its own. It closes with the close button or an ordinary drag down. Full screen happens only when the athlete presses the full-screen button, and it is the same conversation, only bigger. When the athlete asks for something the app already has a screen for, Vana offers a button that takes them to that screen instead of doing it in the sheet. Example: the athlete asks Vana for a meal plan, and she offers a button to the meal-planning page rather than planning it in the sheet.

**Why.** Lee on 2026-09-14: one height and make things standardised; going back and forth to full screen seems janky; only the full-screen button should go to full screen. Lee on 2026-09-14: all deterministic actions direct the athlete to the appropriate place in the app.

**What else was considered.** Three heights with auto, 75 and 100 percent (mp-063 to mp-065), export drag thresholds plus a flick (mp-066), and planning actions leaving for full screen (mp-059, mp-060), all rejected.

**What it touches.** VanaSheet, VanaSheetRoute, sheet chrome, part actions, chat route. Intent detection in vana-chat, hand-off buttons per flow.

**Details.** Precisely:
1. The sheet has one standard height. Contents scroll within it.
2. The close button or a normal drag down dismisses it. There is no auto height, no growth on send, no resize while Vana streams, and no custom thresholds.
3. Full screen happens only when the athlete presses the full-screen button. It opens the full-screen chat on the same conversation and is only a bigger view of the same thing. Nothing changes for Vana.
4. Every deterministic action is a hand-off, not a chat. When Vana sees the athlete is trying to do something the app already has a screen for, she offers a button that takes them there instead of doing it in the sheet: a meal plan to the meal-planning page, fuelling an upcoming workout to the new-activity screen, planning an event to the event screen, carb loading to the carb-loading picks, and so on for every flow the app owns.
5. Collapsing or dismissing the sheet drops the composer's focus so the keyboard never outlives it. The sheet keeps one widget tree shape so a change of height never remounts it.

> 2026-09-14 folded from mp-067, mp-068, mp-069
> 2026-09-14 amended by Lee
> 2026-09-14 clause 4 rewritten from Lee's words
> 2026-09-14 approved
> 2026-09-14 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-266 · A seven-day trial, then purchase: no free tier and no Pro tier
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-266-2.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-266-2.svg
- screen: Paywall
- source: Lee on the page 2026-09-14, on mp-052
- work: pending

**Context.** The app was freemium: a free tier with AI credits, and Pro for meal planning. The launcher without Pro opened the paywall. Lee is moving the app to a trial model.

**Question.** What does a new account get before it pays, and what happens after?

**Decision.** Every new account gets seven free days of the whole app, then must buy. There is no free tier and no separate Pro tier: an account is on its Trial or it pays. Once the Trial has ended, tapping the launcher opens the paywall, through the one Gate that covers the whole app; Vana has no gate of her own. Example: an athlete who starts on 1 October has the whole app through 7 October; if they have not bought by 8 October, tapping the launcher opens the paywall.

**Why.** Lee on 2026-09-14: we are swapping from a freemium model to a seven-day free trial and then you must buy, so we do not have free and Pro any more.

**What else was considered.** Keeping free and Pro with meal planning behind Pro (mp-052 as first written, and the three Pro cards in this category, which still describe the old model).

**What it touches.** Paywall, entitlements, RevenueCat products, credits system.

**Details.** Precisely:
1. Every new account gets a seven-day free trial of the whole app, then must buy. There is no free tier and no Pro tier, only trial and paid.
2. Tapping the launcher after the trial has ended opens the paywall. Gating follows the one app gate. There is no Vana-specific gate.
3. The move away from freemium is its own piece of work; see the open question beside this card.

> 2026-09-14 folded from mp-052
> 2026-09-14 approved
> 2026-09-15 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-268 · The general conversation opens on the screen underneath
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-268-2.svg
- work: pending
- category: The planning conversation
- screen: Vana sheet
- source: Lee on the page 2026-09-14, on mp-237

**Context.** The general conversation used to open with three example chips. Vana lives on three screens and knows what is in view on each.

**Question.** What does Vana say first in the general conversation?

**Decision.** The general conversation (Vana's own chat, as opposed to a meal-planning one) opens with no example chips. Vana's first line reads the screen the athlete came from, such as "I see you are planning an event"; when that screen tells her nothing useful, she uses the personal Opener every conversation already carries. Being offline, hitting the rate limit and being out of the trial each keep the one outcome they already show. Example: an athlete on a carb-load day opens Vana and reads "I see you are carb loading" instead of three sample questions.

**Why.** Lee on 2026-09-14: the general conversation does not need example chips; open from the route they are on.

**What else was considered.** Three example chips and a "Start a meal plan" offer (mp-237), rejected.

**What it touches.** vana-chat opener, situation resolver, sheet conversation.

**Details.** Precisely:
1. No example chips. The general conversation opens with a line that reads the screen underneath, such as "I see you are planning an event" or "I see you are carb loading".
2. When the screen underneath says nothing useful, the opener falls back to the personal opener that every conversation already carries.
3. Offline, rate limit and out-of-trial failures keep their one visible outcome each.

> 2026-09-14 from Lee's rejection of undefined
> 2026-09-14 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-269 · The athlete sets the day a plan period starts and how long it runs
- status: approved
- image: docs/ssot/decisions/images/mealplanning/settings.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-269-2.svg
- work: pending
- category: Plan tab
- screen: Settings, Plan tab
- source: Lee on the page 2026-09-14, on mp-240

**Context.** The plan week always started on Sunday, with cooking on fixed days after it: Sunday, Wednesday and Friday (mp-240). Athletes cook on different days and over different spans.

**Question.** Which day does a plan period start, and how long does it run?

**Decision.** The athlete can change the day a plan period starts and how many days it runs; Sunday and seven days are the defaults. Cook days follow from those two settings instead of sitting on fixed days. The Plan tab, plan coverage, the review sheet and the check-in opener all read the settings. Example: an athlete who shops on Mondays sets the start day to Monday and keeps seven days, and the Plan tab, plan coverage, the review sheet and the check-in opener all work from a Monday start.

**Why.** Lee on 2026-09-14: it is variable; a user can change which day the week starts and how many days.

**What else was considered.** Sunday start with cook days at plus three and plus five (mp-240), rejected.

**What it touches.** Settings, week start, plan queries, session dates, review sheet, check-in opener.

**Details.** Precisely:
1. The start day and the length of a plan period are settings the athlete can change. Sunday and seven days are the defaults.
2. Cook days derive from those settings, not from fixed offsets.
3. The Plan tab, coverage, the review sheet and the check-in opener all read the settings.

> 2026-09-14 from Lee's rejection of undefined
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-270 · Meal planning ships only with the trial and purchase model
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-270-2.svg
- work: pending
- category: Pro and paywall
- screen: Paywall
- source: Lee on the page 2026-09-14, on mp-250

**Context.** The earlier plan shipped meal planning dark behind a gate flag and opened it later by granting entitlements or enabling purchase.

**Question.** Can meal planning reach the live app before the trial exists?

**Decision.** No. Meal planning does not ship until the seven-day trial and purchase are live. There is no dark launch, meaning no shipping it hidden behind a switch to turn on later. That makes the move to the trial part of the critical path for meal planning. Example: the paywall and its seven-day trial go live on 1 October, so meal planning cannot reach the live app before 1 October.

**Why.** Lee on 2026-09-14: we will not ship without the purchase and seven-day trial, so no meal planning without it.

**What else was considered.** Shipping dark with a gate flag and a Buy button behind a purchase flag (mp-250), rejected.

**What it touches.** Release plan, gate flag, Pro screen, RevenueCat products.

**Details.** Precisely:
1. Meal planning does not ship until the seven-day trial and purchase model is live. No dark launch and no gate flag as the release plan.
2. The trial move (see the open question beside the trial card) is therefore on the critical path for the meal-planning release.

> 2026-09-14 from Lee's rejection of undefined
> 2026-09-15 approved by Lee
> 2026-09-15 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-271 · On the dev build, a Settings switch turns the accessibility buttons off
- category: Process and scope
- status: approved
- image: docs/ssot/decisions/images/mealplanning/settings.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-271-2.svg
- screen: Settings
- source: Lee on the page 2026-09-15
- work: pending

**Context.** The dev build shows two floating buttons in the bottom right of every screen: the blue wrench (debug tools) and the red accessibility figure. They are always on. On the simulator they cover the Launcher and the tab bar, and they appear in every screenshot the record captures. Nothing in the dev build is hidden behind a build flag.

**Question.** Can someone using the dev build turn the floating accessibility buttons off?

**Decision.** Yes, in Settings. The dev build still ships the buttons on, with no build-time flag to hide them, and a switch in Settings, shown only in dev mode, turns the accessibility buttons off and back on for that person on that device. The switch starts on and remembers its setting across launches. Example: on the simulator the floating buttons cover the Launcher; the person testing turns the switch off in Settings, the accessibility buttons go, and they are still off the next time the app opens.

**Why.** Lee on 2026-09-15: no build flag hides anything in dev; instead, whoever is on the dev build can turn the accessibility buttons on or off in Settings.

**What else was considered.** A build-time hide-flag, ruled out by the repo rule that dev ships visible. Leaving the buttons always on, which blocks the launcher on the simulator.

**What it touches.** Settings screen, the dev button overlay, the capture drives in screens.json.

**Details.** Precisely:
1. The dev build ships the buttons on, with no build-time flag.
2. Settings gets a switch, shown in dev mode only, that turns the accessibility buttons off and on for that tester on that device.
3. The switch defaults to on and is remembered across launches.

> 2026-09-15 proposed from Lee's words on mp-222
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-272 · A turn may name the chips it expects next
- category: The planning conversation
- status: approved
- image: test/features/meal_planning/presentation/goldens/picker_chips_complete_light.png
- caption: The chips under a picker; the labels may now come from the turn.
- svg2: docs/ssot/decisions/images/mealplanning/mp-272-2.svg
- screen: Vana chat
- source: Lee on the page 2026-09-15; 02-contract.md
- work: pending

**Context.** The chips under a picker used to be drawn by the app with labels the app chose (mp-230 clause 4 as first written). Lee ruled on 2026-09-15 that Vana should be able to say which buttons she has in mind next, with the app's own set as the fallback. What the server sends the app for a turn had no field for this.

**Question.** How does Vana tell the app which chips to show under a picker?

**Decision.** Her turn may carry a short list of chip labels, two to four plain phrases. The app draws them under the picker in its own buttons and style; Vana never draws or styles a chip. With no list, or an empty one, the app shows its own set (mp-230), and tapping one of Vana's chips sends its label, exactly as an app chip does. Example: Vana's turn names "Show me lunches" and "Something quicker"; the athlete sees them as the app's usual chips, taps "Something quicker", and that phrase is sent as their message.

**Why.** Lee on 2026-09-15: the text can sometimes come from the model, so the model should be able to indicate what buttons it is thinking about next; if there is no model indicator we show our buttons; the widgets are drawn by the app.

**What else was considered.** Model-authored chips as markup, rejected: the widgets stay the app's. A next-slot hint alone, which names a slot but not the labels.

**What it touches.** Turn contract (chat.ts, 02-contract.md), PickerChips, stored turn parts, persona rule 3.

**Details.** Precisely:
1. A Vana turn may carry an optional list of suggested chip labels: two to four plain strings.
2. The app draws them as the chips under the picker, in the app's own widget and style. The model never draws or styles a chip.
3. When the list is absent or empty, the app's own set applies (mp-230 clause 4).
4. Tapping a suggested chip sends its label, the same as an app chip.

> 2026-09-15 proposed from Lee's words on mp-230
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-273 · Every entry point sends the same Doll, plus one section for what is in view
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-273.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-273-2.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15
- linked: mp-210

**Context.** Vana is reached from the sheet, the Plan tab, the full-screen chat, the history list, and later the formula editor and the events screens. Today the sheet and Plan tab send the Doll plus a Situation naming the screen; the coach insight is a one-shot call with no Doll at all. The Doll block is already a digest of about 250 to 500 tokens, one capped line per fact family, and is under a tenth of the prompt; the persona and the 32 tool schemas are four fifths of it. Lee's worry was overloading the model and paying for it on every turn. Answers mp-210.

**Question.** What does Vana get told about the athlete from each place she is opened?

**Decision.** Every place Vana is opened from sends the same Voodoo Doll: a fixed digest, the same lines in the same order for everyone, every list capped. The only part that changes is the Situation: the app sends where the athlete is and which item is in view, and the server adds one short section about that item, only while it is in view. Anything deeper Vana looks up with a tool, and the Doll never grows to suit one screen. Example: an athlete asks Vana on the Plan tab and she gets the usual Doll plus a few lines with the day's plan; the same athlete asks from the formula screens and gets the same Doll plus a FORMULA section instead.

**Why.** Cost is not in the Doll but in the unchanged prefix, which caching makes nearly free (mp-274); what would overload the model and break the cache is a Doll that grows or churns. Keeping the constant constant and the variable small is the guard.

**What else was considered.** Each screen declaring its own context in the client (breaks mp-043); growing the Doll so every entry point's needs are always present (fights mp-020 and mp-218).

**What it touches.** Situation resolver, context builder, coach formula feedback, events page, sheet.

**Details.** Precisely:
1. The Doll is a fixed-shape digest: the same lines in the same order for everyone, every list capped, nothing free-form. It is the constant, sent by every entry point. mp-218's budget test guards its size.
2. The Situation is the only variable. The client sends a route and an id; the server adds one capped section for the entity in view, only while it is in view: a FORMULA section on the formula screens, an EVENTS AHEAD list on the events screens, the day's plan on the Plan tab. A section is a few lines, never a dump of the record.
3. Anything deeper is a tool, never a line. The block says what exists; the tools (mp-212) give detail on demand.
4. The Doll never grows to hold what one entry point might want. New entry points add a row to the server's screen table and nothing else.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-274 · The formula editor sends its draft as structured fields
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/formula-editor.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-274-2.svg
- screen: Formula editor
- source: grill 2026-09-15

**Context.** A saved personal formula is on the server and a Situation with its id resolves like any other entity. The formula editor is different: the draft may not exist on the server, and edits since the last save never do. Today's coach insight sends the draft itself (phase, sub-phase, durations, activities, name, per-component macros and quantity). mp-043 says clients send ids and dates, never names or free text. mp-209 makes coach formula feedback a Vana conversation. Follows from mp-273.

**Question.** How does the formula editor show Vana the draft on screen?

**Decision.** The formula editor sends the draft itself with the message, as set fields: phase, sub-phase, durations, activities, component ids with quantities, and a name of at most 40 characters. The server builds the FORMULA section from those fields, so Vana sees the draft exactly as it is on screen, unsaved edits included. Normally the app sends only ids and dates, never names or free text (mp-043); this screen is the one named exception, the server checks the shape, and no other free text travels with a message. Example: an athlete changes a component's quantity in a draft formula and asks Vana about it before saving; Vana sees the new quantity, and nothing was saved behind the athlete's back.

**Why.** The draft is what the athlete is asking about, so Vana must see it as it is on screen, unsaved edits included. Saving first would write drafts behind their back and show stale data offline.

**What else was considered.** Save first and send the id (drafts saved behind their back, stale offline); keep the one-shot insight and make only saved formulas a conversation (contradicts mp-209).

**What it touches.** Situation resolver, the formula editor, the ai-coach call it replaces.

**Details.** Precisely:
1. The Situation for the formula editor carries the draft as structured fields: phase, sub-phase, durations, activities, component ids with quantities, and a name capped at 40 characters. The server builds the FORMULA section from that.
2. This is the one named exception to mp-043, for one screen, and the server validates the shape as it validates routes. No other free text travels with a message.

> 2026-09-15 proposed in the grill
> 2026-09-15 picture captured at 1.26.0+1, f84827b9
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-275 · The launcher and the Plan tab's note card continue the day's conversation; New meal plan starts a new one
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-275-2.svg
- screen: Plan tab
- source: grill 2026-09-15
- linked: mp-211

**Context.** The launcher sheet continues the day's ambient conversation (mp-058), the full-screen button carries it over (mp-265), a moment tap opens into it (mp-227), New meal plan starts a new planning conversation (mp-003). The Plan tab's Vana note card was meant to open the general conversation (mp-238) but opens the chat route with no id, which starts a second general conversation with no opener. There is no other "cold button" in the app: the formula editor has the one-shot insight, the events screens have no launcher (mp-264). Answers mp-211.

**Question.** Which ways into Vana continue a conversation, and which start a new one?

**Decision.** The launcher, its full-screen button, the Plan tab's note card and a tap on a moment all open the day's conversation, the one the launcher reopens all day. New meal plan and the plus button in the chat's top bar start a new conversation, and so will a future entry from the formula editor. A conversation started that way never takes over the launcher: close it, tap the launcher, and the day's conversation is back, while the new one stays in history. Example: an athlete chats from the launcher in the morning, taps New meal plan at lunch and plans the week, closes it, then taps the launcher again and finds the morning conversation; the meal plan conversation is in history.

**Why.** Two entry points that disagree about continuing or starting fresh land the athlete somewhere they did not expect; the note card was doing exactly that. The launcher's promise of "where you left off" is worth more than one saved tap.

**What else was considered.** The newest conversation becomes the launcher's for the rest of the day; it lost to the side-trip reading and to leaving mp-058 untouched.

**What it touches.** Ambient conversation controller, chat route, Plan tab note card, history list, opener.

**Details.** Precisely:
1. The launcher, its full-screen button, the Plan tab's note card, and a moment tap all open the day's ambient conversation. The note card stops starting its own.
2. New meal plan and the chat app bar's plus button start a new conversation. A future entry from the formula editor does the same.
3. A conversation started that way never moves the launcher's pointer. Close it and tap the launcher, and the day's ambient conversation is back. The new one stays in history.

> 2026-09-15 proposed in the grill
> 2026-09-15 picture captured at 1.26.0+1, f84827b9
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-276 · The unchanged start of every prompt is cached, and the context block stays the same between turns
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-276.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-276-2.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15
- linked: mp-215

**Context.** The whole prompt goes every turn and the model keeps nothing between calls; that is how every chat model works. Anthropic bills an unchanged prefix at a tenth of the price once caching is on, in the order tools, persona, context, messages; anything that changes invalidates everything after it. Nothing under the Vana functions sets a cache marker, so every turn pays full price for about 8,800 tokens. Two things defeat the cache as built: the context block is rebuilt every turn (LOGGED TODAY and per-message memory recall change it) and the 20-message sliding window shifts the first replayed message every turn. Answers mp-215.

**Question.** Is sending the whole context every turn wasteful, and what do we do about it?

**Decision.** Every turn sends the whole prompt, because the model keeps nothing between calls. Anthropic charges a tenth of the price for the part of a prompt that has not changed since the last call, so caching is on, and each call logs how many tokens came from the cache so a zero shows. The context block is built once when a conversation opens and reused, rebuilt only when a tool writes something or the day changes, and the prompt keeps one order: tools, persona, context, messages. Example: a 40-turn planning session drops from about $0.40 to about $0.11.

**Why.** The sending is unavoidable; the paying is not. A mid-conversation turn drops from about a cent to about a quarter of a cent, and the rest of the design stops fighting for tokens.

**What else was considered.** Leaving the context out and fetching by tool (Vana forgets unless she asks; mp-019's reason); shrinking the Doll (it is under a tenth of the prompt).

**What it touches.** vana-chat model call options, context builder, vana_calls log, mp-218's test.

**Details.** Precisely:
1. Caching is on, through the gateway's automatic mode, and the cache-read token count is logged per call so a zero is visible.
2. The context block is assembled once when a conversation opens and reused for its turns. It is refreshed only when a tool writes (plan, memory, pantry, home) or the day changes. Per-message memory recall leaves the block; the memories and last talks in it cover the person, and recall stays available as a tool.
3. The prompt order is fixed: tools, persona, context, messages. The mp-218 budget test also asserts the block is byte-identical across two turns with no writes between them.

Today about 8,800 input tokens a turn at full price, about $0.010 a turn; cached with a stable block about $0.0023. A 40-turn planning session from about $0.40 to about $0.11. Cache entries live five minutes; a reply after a longer gap pays one 1.25x write.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-277 · Vana folds long chats into summaries, saves notes as they are said, and writes the Episode when a chat goes idle
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-277.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-277-2.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15
- linked: mp-217

**Context.** The model remembers nothing between turns, so everything that looked like memory was machinery the app built: a 20-message sliding window, an Episode written mid-conversation from the opening half, a read-back of the previous conversation when the next one opened, a 3.5 second wait for it, an "athlete's last words" fallback, and two Episode writers racing each other. Lee held mp-032 to mp-036 and mp-038, rejected mp-009 and mp-026, and asked for a rethink. The research (docs/research/conversation-memory-strategies.md) found nobody ships "summarise when the next one opens": LangChain keeps the last 20 messages word for word and folds the rest into a rolling summary in chunks, Claude and Character.AI save notes during the chat, and OpenAI and Anthropic compact on the server at a threshold. This card replaces mp-032, mp-033, mp-034, mp-035 and mp-036, keeps mp-038, and answers mp-217.

**Question.** How does Vana remember, inside one conversation and from one to the next?

**Decision.** Inside a conversation every message is kept word for word up to 40; at 40 the oldest 20 become one summary and the last 20 stay, and at 60 the same again. That summary is prepared in the background from message 30, so no reply waits. While the athlete talks, Vana saves anything lasting the moment it is said, with her remember tool; when the chat goes idle (the sheet closes, the app goes to the background, or a new chat starts) the server writes the conversation's Episode and any notes she missed, once, so the next opener reads what exists and never waits. Example: an athlete plans dinners on the evening of 6 October and closes the sheet; the Episode is written then, and the opener on the morning of 7 October reads it with no wait.

**Why.** Lee: "If there is a new conversation, we should have summarised the earlier one sometime before that", and machinery that exists only to cover a late summary should go. Folding the history in chunks keeps both the prompt cache (mp-276: the start of the prompt that does not change is cached) and the conversation's opening, which a sliding window would drop.

**What else was considered.** A scheduled server sweep every 15 minutes for conversations idle 30 minutes, as the safety net for an app killed mid-conversation; deferred (mp-026 rejected cron as plumbing) until the miss shows up. That conversation's margin notes were already written by clause 2; only its episode waits until it is next opened.

**What it touches.** vana-chat replayHistory, extract.ts, the episode row, the conversation row, the opener path, the client's idle signal from the sheet and the chat route.

**Details.** Precisely:
1. Within a conversation the history is chunked, never sliding. Every message stays verbatim up to 40. At 40 the oldest 20 become one summary message and the last 20 stay verbatim; at 60 the same again, rolling the previous summary in. The summary is written in the background when the count reaches 30 and applied at 40, so no turn waits and the cached prefix changes once per 20 turns. It lives on the conversation row, keyed by the message index it covers; no new table and no two-writer race.
2. During the conversation the remember tool is the memory writer, as mp-024's second writer. The prompt is sharpened so a durable thing the athlete says is saved the moment they say it, and the eval tests that.
3. At the end the client says when: when the sheet closes, the app goes to the background, or a new conversation starts, the client tells the server the conversation is idle, and the server writes its episode and any margin notes the tool missed, once. The summary exists before the next conversation opens.
4. The opener reads what exists and never waits. No read-back on open, no wait, no last-words fallback, no mid-conversation episode from the opening half. Episodes and the LAST TALKS line stay (mp-038).

HISTORY_CAP 20 becomes verbatim to 40, chunk 20, summary at 30. OPENER_READ_BACK_MS, readBackWithin, athleteWordsFrom and writeOpenEpisode are removed.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-278 · The opener never waits
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-278.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-278-2.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15
- linked: mp-216

**Context.** The shipped opener waited up to 3.5 seconds for the previous conversation's read-back and fell back to the athlete's last words when it was late (mp-009, rejected as too deterministic). Under mp-277 there is no read-back at open, so there is nothing to wait for. Answers mp-216.

**Question.** Does the opener wait for the last conversation to be read back?

**Decision.** No. The opener never waits on anything. It says the most relevant thing Vana already holds (mp-008), taken from her Memories and the newest episodes as they stand, and when the last conversation's episode is not written yet she leaves it out rather than stretch. Example: an athlete closes a chat about race week and taps New meal plan straight away; the opener goes out at once, and if that chat's episode is not written yet, Vana does not mention it.

**Why.** It removes the constant, the wait and the fallback in one stroke, and nothing else about the opener changes.

**What else was considered.** A shorter wait, or an adaptive one; both keep the plumbing mp-217 asked to remove.

**What it touches.** Opener path in vana-chat.

**Details.** Precisely:
1. The opener never waits on anything.
2. It says the most relevant thing Vana already holds (mp-008) from the memory table and the newest episodes as they stand.
3. When the previous conversation's episode does not exist yet, she leaves it out rather than stretch.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-279 · The store runs the seven-day trial, and RevenueCat is the only gate
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-279-2.svg
- screen: Paywall
- source: grill 2026-09-15
- linked: mp-267

**Original.** 
1. The store runs it. The existing monthly and annual subscriptions each get a seven-day free introductory offer on both stores. No new product ids.
2. The athlete subscribes at the end of onboarding with a payment method on file, pays nothing for seven days, and is charged on day eight unless they cancel. The store's own eligibility rule applies: one introductory offer per person per subscription group, so a cancelled trial is not repeated.
3. RevenueCat's entitlement is the gate, active from day one. There is no trial clock and no trial state in the app or the server.

**Lee said.** "if we can clean up the spec a little bit with reversals or things like that so that our single source of truth is respected" (terminal, 2026-09-21). Clause 1 is reversed by mp-429 clause 1.

**Context.** Monthly and annual subscriptions exist on both stores at $9.99 and $69.99, attached to one RevenueCat entitlement in the default offering, with no introductory offer. mp-266 rules a seven-day trial of the whole app, then purchase, with one app gate. A trial can be run by the store (an introductory free offer, card on file, charged on day eight) or by the app (a server clock from signup, paywall on day eight, a rule for second accounts). Answers mp-267.

**Question.** Who runs the free trial, the store or the app?

**Decision.** The store does. Every subscription product carries a seven-day free offer on both stores, set on Xuan's new products (mp-429). The athlete subscribes at the end of onboarding with a card on file, pays nothing for seven days and is charged on day eight unless they cancel; the store allows one trial per person, so a cancelled trial never comes back. Whether someone may use the app is RevenueCat's `pro` being live from day one, and neither the app nor the server keeps a trial clock. Example: an athlete subscribes to the monthly plan on 1 October at the Founding Month price, pays nothing that week, and is charged $12.49 on 8 October unless they cancel first.

**Why.** It is the model that lets the app stop keeping its own entitlement logic rather than rebuild it, and it makes RevenueCat the single truth for "may this person use the app". A card-up-front trial converts fewer signups and more payers, and payers are the number the business runs on.

**What else was considered.** An app-run trial from account creation (needs a server clock, a combined gate, and a second-account rule).

**What it touches.** App Store Connect and Play subscription offers, the RevenueCat offering, onboarding's last step, the paywall.

**Details.** Precisely:
1. The store runs it. Every subscription product carries a seven-day free introductory offer on both stores. The products are Xuan's new ones (mp-429), not the existing monthly and annual ids.
2. The athlete subscribes at the end of onboarding with a payment method on file, pays nothing for seven days, and is charged on day eight unless they cancel. The store's own eligibility rule applies: one introductory offer per person per subscription group, so a cancelled trial is not repeated.
3. RevenueCat's entitlement is the gate, active from day one. There is no trial clock and no trial state in the app or the server.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee
> 2026-09-15 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-21 amended by Lee
> 2026-09-21 approved again by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-280 · A lapsed account sees its own data read-only under the paywall
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-280-2.svg
- screen: Paywall
- source: grill 2026-09-15

**Original.** 
1. After sign-in an inactive account lands on the paywall and stays there. No screen of the app renders.
2. The paywall carries Restore purchases, Manage subscription, Sign out and Delete account.
3. Their data is untouched and returns the moment they subscribe or restore.

**Lee said.** "if we can clean up the spec a little bit with reversals or things like that so that our single source of truth is respected" (terminal, 2026-09-21). Clause 1 is adjusted by mp-429 clause 6.

**Context.** When a Trial ends unpaid or a subscription is cancelled, the account is Lapsed: RevenueCat's `pro` is not live, and the two cases look the same. mp-266 said there is one Gate and that the launcher opens the paywall after the Trial, but not what else a Lapsed account can reach. This follows from mp-267, and mp-429 clause 6 adjusted clause 1.

**Question.** What can a Lapsed account still open?

**Decision.** Its own data, read-only, with the paywall over it. Nothing that writes or calls AI runs until the account subscribes or restores a purchase, and the paywall offers Restore purchases, Manage subscription, Sign out and Delete account. The data is never touched and can be edited again the moment they subscribe or restore. Example: an athlete's Trial ends on 7 October unpaid; on 8 October they can still read their plan but cannot change it or ask Vana anything until they subscribe.

**Why.** One gate, one rule, nothing to audit per screen. The trial is seven days of the whole app; when it ends, the whole app is what they are buying back.

**What else was considered.** A read-only mode for their own data (every screen needs a locked variant and the server must decide per endpoint what read-only means).

**What it touches.** The app gate, the paywall, the router's redirect.

**Details.** Precisely:
1. After sign-in an account with no access sees its own data read-only, with the paywall over it. Nothing that writes or calls AI runs until it subscribes or restores. (mp-429 clause 6)
2. The paywall carries Restore purchases, Manage subscription, Sign out and Delete account.
3. Their data is untouched and becomes editable again the moment they subscribe or restore.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee
> 2026-09-15 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-21 amended by Lee
> 2026-09-21 approved again by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-281 · The subscription fills a monthly budget, and bought top-ups are spent after it
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-281.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-281-2.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15

**Original.** 
1. Credits stay. The subscription carries a monthly allowance of credits, granted into the same wallet the packs fill. Packs are spent only when the allowance is empty. The six functions keep debiting one credit per call.
2. The grant lands on each RevenueCat renewal event (initial purchase, renewal), so the reset follows the billing date. An annual subscription gets the same grant monthly, on the anniversary day, from the webhook.
3. The trial week gets the full monthly grant on day one. A cancelled trial forfeits what is left of it; purchased pack credits are never forfeited.
4. Unused allowance does not roll over. Pack credits never expire.
5. The number is set when the paywall copy is written and recorded here, with the per-call cost log deciding it: enough that a person who plans a week and asks a few questions a day never sees the top-up.

**Lee said.** "if we can clean up the spec a little bit with reversals or things like that so that our single source of truth is respected" (terminal, 2026-09-21). Credits per call are replaced by mp-430's monthly budget on real cost.

**Context.** Before the paywall, six functions each took one credit from the wallet per call: general chat, planning chat, the coach insight, describe-meal, photo analysis, and the webhook that grants purchases. Credits were sold in packs of 50 and 250. mp-249 (rejected) had meal planning never debiting and general chat costing free users a credit; under one subscription there is no free user. This card follows from mp-267.

**Question.** What happens to credits once the app is a subscription?

**Decision.** The subscription carries a monthly budget measured in what AI calls actually cost us, and every AI call draws it down by its real cost; nothing takes a flat credit per call. The budget is $4.00 a month on every plan, it lands in the same wallet as bought top-ups, and top-ups are spent only once the month's budget is empty. Unused monthly budget does not carry over; bought top-ups never expire, and the trial week starts with a quarter of the budget. Example: an athlete starts a trial on 1 October with $1.00 of budget, the renewal on 8 October puts $4.00 in, a $4.99 pack bought on 20 October is spent only after that $4.00 is gone, and what is left of the pack is still there after the 8 November refill.

**Why.** Lee chose to keep a top-up over removing credits. The monthly budget is what stops a trial of the whole app from saying "out of credits" on day three, and the packs stay for heavy use.

**What else was considered.** Removing credits entirely (every AI feature included, rate limits as the only bound); keeping credits exactly as now beside the subscription.

**What it touches.** revenuecat-webhook, credits wallet, the six debiting functions, the packs screen.

**Details.** Precisely:
1. The subscription carries a monthly budget measured in what AI calls actually cost us (mp-430), granted into the same wallet that bought budget fills. Bought budget is spent only when the monthly budget is empty. Each AI call draws down its real cost; nothing debits a flat credit per call.
2. The grant lands on each RevenueCat renewal event (initial purchase, renewal), so the reset follows the billing date. An annual subscription gets the same grant monthly, on the anniversary day.
3. The trial week gets a quarter of the monthly budget on day one. A cancelled trial forfeits what is left of it; bought budget is never forfeited.
4. Unused monthly budget does not roll over. Bought budget never expires.
5. The monthly budget is $4.00 of model cost, the same for every plan (mp-430).

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee
> 2026-09-21 amended by Lee
> 2026-09-21 approved again by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-282 · An empty wallet opens the top-up sheet, never the Gate
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-282-2.svg
- screen: Credits paywall
- source: grill 2026-09-15

**Context.** Before this card an empty wallet came back from the server as a 402 ("payment required"), and each feature caught it its own way: a snackbar with a Buy Credits action on the formula screen, a push to the paywall elsewhere. mp-237, which carried "out of credits opens the credits paywall" inside a card about empty-state chips, was rejected with that card. This card follows from mp-281.

**Question.** What does the athlete see when their wallet runs out?

**Decision.** Running out never locks the athlete out: an empty wallet is not the Gate, and everything that uses no AI keeps working. The button that would spend opens the top-up sheet, which shows the monthly allowance, when it renews and the two packs. In Vana, pressing send opens it, with one line above the message box saying so; Vana never says "out of credits" in the conversation. Example: on 20 October an athlete whose month is used up taps Analyze on a meal photo; the top-up sheet opens with the 8 November renewal and the $4.99 and $19.99 packs, and their plan and logs stay open.

**Why.** The wallet and the Gate answer different questions. One handler keeps the six AI features from each inventing their own path.

**What else was considered.** none recorded

**What it touches.** Shared 402 handler, the composer, the coach insight panel, the photo and describe flows, the credits sheet.

**Details.** Precisely:
1. An empty wallet is never the app gate. The person stays in the app with everything that does not debit.
2. The button that would debit shows the top-up sheet: what the allowance is, when it renews, and the two packs. In Vana the composer's send shows it, with one line above the composer saying so; Vana never says "out of credits" mid-thread.
3. The server keeps returning 402 and the client keeps one handler for it, in the shared layer, so a new debiting feature gets the sheet for free.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee
> 2026-09-15 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-283 · Existing accounts get no grace period
- category: Pro and paywall
- status: withdrawn
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- screen: Paywall
- source: grill 2026-09-15

**Context.** Pro was never sold, so no one has a subscription. Every existing account has used the app free, and some hold paid pack credits. On update day the new build sends them to the paywall on launch. Follows from mp-267.

**Question.** What accounts that exist today get.

**Decision.** No grace period. An existing account meets the paywall and the store trial on first launch of the new build, like a new one. Paid pack credits stay in the wallet and are spendable once subscribed (mp-281).

**Why.** Lee ruled for the simplest cutover: one model for every account from launch day.

**What else was considered.** A 30-day promotional entitlement granted in RevenueCat for accounts older than the release, with a What's New notice; free for life for existing accounts.

**What it touches.** Release notes, the paywall, the What's New sheet.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee
> 2026-09-15 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-21 withdrawn by Lee

## mp-284 · The phone's saved answer decides, and no answer at all means locked
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-284.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-284-2.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15

**Context.** The app works offline, and the Gate reads RevenueCat. RevenueCat's code on the phone saves its last answer, so a subscriber who is offline still has a saved answer saying `pro` is live. The only case with no answer is a fresh install, or cleared app data, with no network. Follows from mp-279.

**Question.** What does the Gate do when it cannot tell whether the account has paid?

**Decision.** It trusts the copy of RevenueCat's answer saved on the phone whenever there is one, online or not, and RevenueCat refreshes that copy in the background. With no saved copy and no answer within a couple of seconds, the account counts as locked: it sees the paywall, where Restore purchases works as soon as the network is back. The server checks every paid call against its own record (mp-285), so a phone that fakes its saved copy gets nothing. Example: a subscriber on a plane opens the app and gets straight in from the saved copy; the same person on a fresh install with no signal sees the paywall until the network returns and Restore lets them in.

**Why.** Locked when unknown is the only safe default for a paid app, and the saved copy means an honest subscriber never notices it.

**What else was considered.** Open-when-unknown for a short grace; it lost as a free path for a cleared cache.

**What it touches.** The app gate, subscription status provider, the paywall, the server's entitlement check.

**Details.** Precisely:
1. The cached entitlement is the answer whenever there is one, online or not. RevenueCat refreshes it in the background and the gate reacts when it changes.
2. No cache and no answer within a couple of seconds counts as locked: the paywall, with Restore purchases, which succeeds as soon as the network is back.
3. The server checks every debiting or Vana call itself against its own record of RevenueCat's status (mp-285), so a device that lies about its cache buys nothing.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-285 · The server keeps a small copy of RevenueCat's answer, written only by the webhook
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-285.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-285-2.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15

**Context.** Lee said on the page that the app's own entitlements table goes away under the trial model. The server still needs its own check on paid calls, because it cannot take the phone's word. Asking RevenueCat on every call adds a wait to every Vana message, cannot be kept between calls in the server's short-lived functions, and stops every subscriber when RevenueCat is down. The webhook already wrote the table, the server already read it, and the monthly Allowance (mp-281) needs the webhook anyway. Follows from mp-284.

**Question.** Does the server need its own record of who has paid?

**Decision.** Yes, a small one: the Entitlement row, holding only the two fields the Gate reads (active until and period type), and written only by the webhook. When the row and RevenueCat disagree, RevenueCat wins: a purchase or Restore makes the app ask again, the next webhook call corrects the row, and an event older than the row is ignored. Nothing in the app ever gives anyone access. Example: if RevenueCat is down on 15 October, subscribers keep talking to Vana, because the server reads its own row instead of asking RevenueCat on every message.

**Why.** Code that already works beats an extra call on every Vana message and an outage that stops every subscriber. Lee's remark was against the app being a second system that grants access, and a copy only the webhook writes is not one.

**What else was considered.** Fetch from RevenueCat's REST API per call with an in-memory cache (recommended first in the grill, withdrawn for the reasons above).

**What it touches.** user_entitlements table, revenuecat-webhook, the vana functions' requirePro, the entitlement repository.

**Details.** Precisely:
1. The table stays, shrunk to a cache of RevenueCat: the two fields the gate reads, active until and period type, written only by the webhook.
2. On any disagreement RevenueCat wins: Restore or a purchase tells the client to refetch, and the next webhook corrects the row. An event older than the row's event time is ignored.
3. Nothing grants an entitlement from the app side, ever.

The table is `user_entitlements`; the Vana functions read it through `requirePro`.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-286 · Coaches get nothing special until Xuan's paywall document
- category: Pro and paywall
- status: withdrawn
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-286.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15

**Context.** There is no coach subscription. A coach signs in, sees athletes, chats with them and gives formula feedback. Under one gate an unsubscribed coach is locked out on day eight like anyone else. Lee has something to say about coaches that depends on a paywall document Xuan will provide. Follows from mp-280.

**Question.** Whether coaches pay, for now.

**Decision.** For now, coaches get no special treatment: one gate, one trial, the same subscription, and no coach branch in the code. When the coach rule is written it becomes a new proposal; the adaptation path is a RevenueCat grant on the coach role, so the gate itself never changes.

**Why.** Lee: do the simplest thing first that can be adapted later, until the paywall document arrives.

**What else was considered.** A promotional entitlement granted at coach registration; a coach product later.

**What it touches.** Coach registration, the app gate.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee
> 2026-09-21 withdrawn by Lee

## mp-288 · The client says when a conversation is idle, as a flag on the chat call
- category: Spec
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-288.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-288-2.svg
- screen: none (algorithm/data)
- source: spec mealplanning 2026-09-15

**Context.** When a conversation with Vana goes quiet, the server reads it back and writes its Episode (mp-277). Before that ruling, what looked like Vana remembering was work that only ran when the next conversation opened. mp-277 says the app tells the server when a conversation is idle; this card is the spec's Implementation Decisions paragraph on how that signal travels.

**Question.** How does the app tell the server a conversation has gone quiet?

**Decision.** With a flag on the chat call the app already makes, the same way the opener flag travels, so there is no new server function. The app sends it when the Vana sheet closes, when the app goes to the background, or when a new conversation starts, and it never waits for an answer. The server writes the conversation's Episode only once; if the phone is offline the flag is lost, and the conversation is read back the next time it is opened. Example: an athlete closes the Vana sheet and sends the app to the background a minute later; the first flag writes the Episode, and the second finds it already written and writes nothing.

**Why.** The opener flag already proves the pattern, and one call path keeps auth, rate limits and logging in one place. Fire-and-forget keeps the sheet's close instant.

**What else was considered.** A separate idle endpoint (a second path to secure and log); a scheduled server sweep (deferred by mp-277 until a miss shows).

**What it touches.** vana-chat request body, the sheet controller, the chat route, app lifecycle observer, extract.ts.

**Details.** Precisely:
1. The idle signal is a flag on the existing chat call, the way the opener flag rides it (mp-253). No new function.
2. The client sends it when the sheet closes, the app goes to the background, or a new conversation starts. It is fire-and-forget: nothing waits on the reply.
3. The server is idempotent: a second signal for a conversation that already has its episode writes nothing.
4. Offline, the signal is dropped. That conversation is read back the next time it is opened; its margin notes were already written by the remember tool in the hot path. No scheduled sweep yet.

> 2026-09-15 proposed from the spec
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-289 · The store trial is verified by hand in sandbox, never in CI
- category: Spec
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-289.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-289-2.svg
- screen: none (algorithm/data)
- source: spec mealplanning 2026-09-15

**Context.** Meal planning cannot ship until the seven-day Trial exists. The stores run the Trial and RevenueCat decides whether `pro` is live (mp-279), and no test in the repo can drive either. This card is the spec's Testing Decisions paragraph on how the Trial is proven.

**Question.** How do we prove the Trial, the Gate and the Allowance work end to end?

**Decision.** By hand, with a fresh Sandbox account on each store. The account subscribes through the seven-day free offer, holds `pro` from day one, receives the Allowance, cancels, meets the paywall, and gets back in with Restore purchases. The run is written up with the release and never runs in CI (the automatic checks on every push); the webhook's own rules are tested separately on the server with fake events. Example: on the App Store a new Sandbox account starts the free week, sees its credits arrive on day one, cancels, is sent to the paywall, and taps Restore purchases to reopen the app.

**Why.** Only the stores can run an introductory offer, and a sandbox clock cannot be driven from a test. The seam test covers what the app owns; the hand run covers what it does not.

**What else was considered.** Mocking RevenueCat end to end (proves nothing about the store); skipping the hand run (the first person to hit day eight would be a customer).

**What it touches.** revenuecat-webhook seam tests, the release checklist, the paywall.

**Details.** Precisely:
1. A fresh sandbox account on each store subscribes through the introductory offer. The entitlement is active on day one, the webhook lands the Allowance, the subscription is cancelled, the account meets the paywall, and Restore reopens it.
2. The run is by hand, written up with the release, and never in CI. The webhook's own logic (grant on renewal, stale event ignored, transfer moves the row) is tested at the server seam with fake events.

> 2026-09-15 proposed from the spec
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-290 · Caching and history summaries are tested by what the prompt looks like, not by what it costs
- category: Spec
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-290.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-290-2.svg
- screen: none (algorithm/data)
- source: spec mealplanning 2026-09-15

**Context.** Every Turn used to pay full price for a prompt four fifths the same as the one before. mp-276 turns on caching, so the repeated start of the prompt is billed cheaply, and keeps the Context block unchanged for the whole conversation; mp-277 folds the oldest messages into a summary once a conversation reaches forty. No test can check either by what it costs. This card is the spec's Testing Decisions paragraph on what is checked instead.

**Question.** How do we test that caching and history summaries work?

**Decision.** By checking the shape of what is sent to the model, never its dollar cost. The Context block built twice for one athlete with nothing written in between must come out identical to the byte, and must change after a tool writes or the day changes. Long conversations are replayed to check that the oldest messages fold into summaries at the counts mp-277 sets and that a turn never waits for its summary, and the scripted test conversations run against the model (the eval) fail any case whose second turn reads nothing from the cache. Example: a conversation of 39 messages replays all 39 word for word, one of 40 replays as one summary plus the last 20, and one of 61 as one rolled summary plus the last 20.

**Why.** Whether the prompt stays the same is a matter of its bytes, and a cache hit is a number the model provider reports; neither needs a price. The eval catches a cache that silently stops working (a prompt start shorter than the model's minimum, or a change before the point where caching begins) on the day it happens.

**What else was considered.** Asserting dollar cost per turn (depends on prices that change); trusting the gateway's automatic mode without a read count (a silent miss stays silent).

**What it touches.** tests/vana context_block and a new replay test, vana-eval, vana_calls log.

**Details.** Precisely:
1. The token-budget test (mp-218) also builds the block twice for one athlete with no writes between and asserts the two are byte-identical, and that a tool write or a day change produces a different block.
2. The compaction test feeds conversations of thirty-nine, forty and sixty-one messages and asserts the replayed shape: all verbatim; one summary plus twenty; one rolled summary plus twenty. It asserts the summary is keyed to the index it covers and that the turn returns before the summary call does.
3. The eval seam records cache-read tokens per case and fails a case whose second turn reads zero.

> 2026-09-15 proposed from the spec
> 2026-09-15 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-291 · Ticket 13: Every turn after the first is cached
- category: Tickets
- status: approved
- ticket: 13
- depends: mp-276, mp-290, mp-218
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-291.svg
- screen: none (algorithm/data)
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and every turn paid full price for a prompt four fifths identical to the last. This is the first of nine tickets cut on 2026-09-15 (13 to 21) and the first of three on Vana's memory and cost; 14 and 15 build on it. Tickets 01 to 12 are the earlier build.

**Question.** Is one ticket for caching plus a stable context block the right slice, with no blockers?

**Decision.** An athlete's second turn in a conversation is served from a cached prefix. Caching is on through the gateway's automatic mode; the context block is assembled once when a conversation opens and reused for its turns, refreshed only on a tool write or a new day; per-message memory recall leaves the block; the prompt order is tools, persona, context, messages; every call logs its cache-read tokens beside its input tokens, so the vana_calls table shows a non-zero read on turn two.

**Why.** It is the cost floor every later ticket stands on, it is demoable from one table query, and it fits one context window because it changes how the prompt is assembled and nothing about what it says.

**What else was considered.** Folding it into the chunked-history ticket; it lost because the cache proves itself alone and the history change is where the risk is.

**What it touches.** supabase/functions/_shared/vana/chat.ts, supabase/functions/_shared/vana/context.ts, supabase/functions/_shared/vana/log.ts, supabase/functions/tests/vana/context_block.test.ts, supabase/functions/vana-eval

**Details.** 
- [ ] The gateway call carries automatic caching and the cache-read token count is written to vana_calls per call.
- [ ] The context block is built once per conversation open and reused; a tool write (plan, memory, pantry, home) or a day change rebuilds it; nothing else does.
- [ ] Per-message memory recall is out of the block; recall remains a tool.
- [ ] Prompt order is tools, persona, context, messages, and the block is byte-identical across two turns with no writes between (mp-218 test extended).
- [ ] The eval records cache reads per case and fails a case whose second turn reads zero.
- [ ] Dev deploy of vana-chat; a two-turn conversation on the dev account shows a non-zero cache read on turn two.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 approved by Lee

## mp-292 · Ticket 14: A long conversation keeps its opening
- category: Tickets
- status: approved
- ticket: 14
- blocked: 13
- depends: mp-277, mp-290
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-292.svg
- screen: none (algorithm/data)
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and a sliding window forgot the start of a long conversation. Second of nine tickets, second of three on memory and cost: after the cache (13), before the idle signal (15).

**Question.** Is chunked compaction its own ticket, blocked only by the cache?

**Decision.** An athlete forty turns into a planning conversation asks about the meal they picked in turn three and Vana knows it. Every message stays verbatim to forty; at forty the oldest twenty become one summary and the last twenty stay; at sixty the same again, rolling. The summary is written in the background at thirty and applied at forty, stored on the conversation row keyed by the message index it covers. The mid-conversation episode writer and its opening-half prompt are removed.

**Why.** It is the one change that touches the replay path, it is verifiable from message shapes alone, and it has to follow the cache so the chunk boundary is what moves the prefix.

**What else was considered.** Keeping the sliding window and only fixing the summary's slice; rejected by mp-277.

**What it touches.** supabase/functions/_shared/vana/chat.ts, supabase/functions/_shared/vana/extract.ts, supabase/functions/_shared/vana/memory.ts, supabase/migrations/20260916100000_vana_conversation_summary_index.sql, supabase/functions/tests/vana/open_episode.test.ts, supabase/functions/tests/vana/extract.test.ts

**Details.** 
- [ ] Replay at 39, 40 and 61 messages gives all verbatim, one summary plus twenty, one rolled summary plus twenty.
- [ ] The summary is written in the background when the count reaches thirty and the turn returns before that call does; it is applied from forty.
- [ ] The summary lives on the conversation row with the index it covers; a migration adds the index column and nothing else.
- [ ] writeOpenEpisode, the opening-half prompt and the open-episode test are gone; the episode row stays for the end-of-conversation writer.
- [ ] Dev deploy; a 45-turn eval conversation answers a question about turn three.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 approved by Lee

## mp-293 · Ticket 15: The next conversation knows the last one, and never waits
- category: Tickets
- status: approved
- ticket: 15
- blocked: 13, 14
- depends: mp-277, mp-278, mp-288, mp-024
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: Vana sheet
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the next conversation waited three and a half seconds for a read-back of the last one. Third of nine tickets, last of the three on memory and cost. It removes the read-back plumbing and adds the idle signal on both sides of the wire.

**Question.** Is the idle signal plus the opener cleanup one slice, blocked by the history change?

**Decision.** An athlete closes the sheet at night and opens it in the morning: the opener arrives at once and knows what last night established. The client sends the idle flag on the chat call when the sheet closes, the app backgrounds, or a new conversation starts; the server writes the episode and any missed margin notes once and ignores a repeat. The remember tool's prompt rule is sharpened so durable things are saved as they are said. The read-back-on-open, its wait, the last-words fallback and their helpers are removed. The opener reads what exists.

**Why.** The signal and the removal are two halves of one behaviour and cannot be demoed apart. It follows 14 because both rewrite the extractor.

**What else was considered.** A scheduled sweep for conversations never signalled; deferred by mp-277 and named in the ticket as the fallback if a miss shows.

**What it touches.** supabase/functions/_shared/vana/chat.ts, supabase/functions/_shared/vana/extract.ts, supabase/functions/_shared/vana/opener.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/_shared/vana/schemas.ts, supabase/functions/tests/vana/personal_openers.test.ts, lib/features/meal_planning/data/vana_chat_repository.dart, lib/features/meal_planning/application/vana_ambient_conversation_controller.dart, lib/features/meal_planning/presentation/widgets/vana_companion.dart, test/features/meal_planning/application/vana_ambient_conversation_test.dart

**Details.** 
- [ ] The chat request accepts an idle flag; the first idle for a conversation writes its episode and notes, the second writes nothing, no flag writes nothing (server seam).
- [ ] The client sends idle on sheet close, app background and new conversation (controller test through the real notifier), fire-and-forget.
- [ ] OPENER_READ_BACK_MS, readBackWithin and athleteWordsFrom are gone; the opener path awaits nothing.
- [ ] The remember rule in the persona is sharpened and the eval case "a durable thing said in passing is a Memory by the next turn" passes.
- [ ] Eval: a conversation never signalled idle still opens the next one at once.
- [ ] Dev deploy; simulator: close the sheet, reopen, the opener mentions last time.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
> 2026-09-15 approved by Lee

## mp-294 · Ticket 16: Every entry point gets the Doll plus what is in view
- category: Tickets
- status: approved
- ticket: 16
- blocked: 13, 15
- depends: mp-273, mp-275, mp-058
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: The Plan tab: the note card and New meal plan
- screen: Plan tab
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and each screen invented its own context. Fourth of nine tickets, first of two on entry points; 17 (the formula editor) follows it.

**Question.** Is the entry-point rule plus the note-card fix one slice, blocked by the memory work?

**Decision.** An athlete on the events screens asks about the second race and Vana knows it; the Plan tab's Vana card opens the same conversation the launcher does. The server adds one capped section for the entity in view (EVENTS AHEAD on the events routes, the day's plan on the Plan tab) only while it is in view; the Doll stays the fixed digest; the note card routes to the day's ambient conversation; New meal plan and the plus button start new and leave the launcher's pointer alone.

**Why.** The section builder and the routing fix are small on their own and together make one demo: open Vana from three places and see the right thing. It follows 15 because both edit the ambient controller and the context builder.

**What else was considered.** Building the formula section here too; it lost because the editor needs a wire change of its own (17).

**What it touches.** supabase/functions/_shared/vana/context.ts, supabase/functions/_shared/vana/situation.ts, supabase/functions/tests/vana/context.test.ts, supabase/functions/tests/vana/situation.test.ts, lib/features/meal_planning/presentation/screens/plan_tab.dart, lib/features/meal_planning/application/vana_ambient_conversation_controller.dart, test/features/meal_planning/application/vana_ambient_conversation_test.dart

**Details.** 
- [ ] Events routes in the Situation produce an EVENTS AHEAD section listing every upcoming event; the Plan tab produces the day's plan; any other route produces no section (server seam).
- [ ] The Doll block itself is unchanged in shape by any entry point (mp-218 test).
- [ ] The Plan tab note card opens the day's ambient conversation, not a fresh one (controller test).
- [ ] A conversation started by New meal plan or the plus button does not change the launcher's pointer (controller test).
- [ ] Simulator: note card and launcher land in the same thread.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, f84827b9
> 2026-09-15 approved by Lee

## mp-295 · Ticket 17: Ask Vana about the formula on screen
- category: Tickets
- status: approved
- ticket: 17
- blocked: 15, 16
- depends: mp-274, mp-273, mp-209, mp-275
- image: docs/ssot/decisions/images/mealplanning/formula-editor.png
- caption: The formula editor, where Ask Vana will sit
- screen: Formula editor
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the coach formula feedback was a one-shot call with no Doll at all. Fifth of nine tickets, last on entry points.

**Question.** Is replacing the coach insight with a Vana conversation over the draft one slice, blocked by 16?

**Decision.** An athlete editing a formula taps Ask Vana and a new conversation opens that sees the draft as it is on screen, unsaved edits included, plus everything Vana knows about them. The editor's Situation carries the draft as structured fields (phase, sub-phase, durations, activities, component ids and quantities, a name capped at forty characters); the server validates the shape and builds a FORMULA section; the one-shot insight panel is retired in favour of that conversation. Coach formula feedback is a Vana conversation like any other (mp-209).

**Why.** It is the one entry point that needs a wire exception, so it gets its own ticket after the general rule (16) is in.

**What else was considered.** Save first and send the id; rejected by mp-274.

**What it touches.** supabase/functions/_shared/vana/situation.ts, supabase/functions/_shared/vana/schemas.ts, supabase/functions/tests/vana/situation.test.ts, lib/features/formula_kit/presentation/screens/formula_editor_screen.dart, lib/features/formula_kit/presentation/widgets/coach_insight_panel.dart, lib/features/formula_kit/application/coach_insight_controller.dart, lib/features/meal_planning/application/vana_situation_controller.dart, lib/features/meal_planning/presentation/widgets/vana_situation_scope.dart

**Details.** 
- [ ] The Situation schema accepts a formula draft for the editor route only; any other route with a draft is refused (server seam).
- [ ] A draft in produces a FORMULA section out with its components and targets; an empty draft produces a one-line section (server seam).
- [ ] Ask Vana from the editor starts a new conversation and does not move the launcher's pointer (controller test).
- [ ] The insight panel's one-shot call is removed from the editor; the ai-coach function is left as it is for other callers.
- [ ] Simulator: edit a component, tap Ask Vana, she names the edited quantity.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, f84827b9
> 2026-09-15 approved by Lee

## mp-296 · Ticket 18: The server gates on a two-field RevenueCat cache
- category: Tickets
- status: approved
- ticket: 18
- depends: mp-285, mp-279, mp-266
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-296.svg
- screen: none (algorithm/data)
- source: tickets mealplanning 2026-09-15

**Context.** Meal planning is not released until the seven-day trial exists, and the store products, the webhook and the entitlements table were built for free and Pro. Sixth of nine tickets, first of four on the trial; it has no blockers and can run beside 13.

**Question.** Is the server side of the trial (store offers, webhook cache, server gate) one slice with no blockers?

**Decision.** A sandbox subscriber's first webhook event lands two fields on their entitlement row, and every Vana or debiting call is gated on them. The monthly and annual subscriptions get a seven-day free introductory offer on both stores through their APIs (no new product ids); the webhook writes only active until and period type and ignores an event older than the row; the server check reads those two fields and nothing app-side can grant one; the Pro gate flag and its config key are removed on the server.

**Why.** It is the foundation the client gate (19) and the allowance (20) both read, it is testable at the webhook seam with fake events, and the store-side change is scripted work that fits beside it.

**What else was considered.** Deleting the table and asking RevenueCat per call; withdrawn in the grill (mp-285).

**What it touches.** supabase/functions/revenuecat-webhook/index.ts, supabase/functions/revenuecat-webhook/entitlements.ts, supabase/functions/revenuecat-webhook/index.test.ts, supabase/functions/_shared/vana/entitlement.ts, supabase/migrations/20260916110000_user_entitlements_two_fields.sql, scripts/store

**Details.** 
- [ ] Both stores carry a seven-day free introductory offer on the monthly and annual subscriptions, created by script and recorded in docs/implement_mealplanning.
- [ ] The webhook writes active until and period type only; an event older than the row's event time is ignored; a transfer moves the row (seam tests with fake events).
- [ ] The migration drops every other column from the entitlements table and nothing app-side can insert into it.
- [ ] requirePro reads the two fields; the Pro gate flag is gone from the server and the config key from app_config's read.
- [ ] Dev deploy of the webhook; a sandbox purchase on the dev app lands the row.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 approved by Lee

## mp-297 · Ticket 19: Seven free days, then the paywall, and nothing else
- category: Tickets
- status: approved
- ticket: 19
- blocked: 18
- depends: mp-279, mp-280, mp-283, mp-284, mp-286, mp-266, mp-270
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- screen: Paywall
- source: tickets mealplanning 2026-09-15

**Context.** Meal planning is not released until the seven-day trial exists, and the app's gate was a Pro flag with a dark-launch plan. Seventh of nine tickets, second of four on the trial.

**Question.** Is the client gate plus the paywall one slice, blocked by the server cache?

**Decision.** A new athlete finishes onboarding, subscribes with the free week, and uses the whole app; on day eight without payment they land on the paywall, which offers Restore, Manage subscription, Sign out and Delete account and nothing else. The gate provider reads the SDK's cached entitlement, treats no cache plus a short timeout as locked, and reacts when RevenueCat refreshes; the router redirect covers every route; existing accounts meet the same paywall; coaches get no branch; the Pro screen and the gate flag are gone from the client.

**Why.** It is the athlete-facing half of the trial and the first demo of "one gate"; it must follow 18 so the server agrees with the device.

**What else was considered.** A read-only mode for lapsed accounts and a grace period for existing ones; both rejected in the grill.

**What it touches.** lib/features/subscription/application/pro_gate.dart, lib/features/subscription/application/subscription_status_provider.dart, lib/features/subscription/presentation/pro_gate_redirect.dart, lib/features/subscription/presentation/screens/pro_version_screen.dart, lib/features/subscription/data/user_entitlements_repository.dart, lib/features/onboarding, lib/shared/services/app_config.dart, lib/shared/core/app_router.dart, test/features/subscription

**Details.** 
- [ ] Onboarding ends on the paywall with the introductory offer shown from store prices.
- [ ] Cached entitlement opens the app online or offline; no cache and no answer within two seconds locks it; a later refresh reopens (controller tests through the real notifier).
- [ ] The paywall carries Restore, Manage subscription, Sign out and Delete account, and no app route renders behind it (golden plus redirect test).
- [ ] The Pro screen, the proGateEnabled config and the Pro-gated path list are removed; the one redirect covers every route.
- [ ] Simulator: a sandbox account without an entitlement sees the paywall on launch; Restore after a sandbox purchase reopens the app.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 approved by Lee
> 2026-09-15 picture reused from test/features/subscription/presentation/goldens/paywall_light.png

## mp-298 · Ticket 20: The monthly Allowance and the top-up sheet
- category: Tickets
- status: approved
- ticket: 20
- blocked: 18
- depends: mp-281, mp-282
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- screen: Credits paywall
- source: tickets mealplanning 2026-09-15

**Context.** Meal planning is not released until the seven-day trial exists, and credits were metered for a free tier that no longer exists. Eighth of nine tickets, third of four on the trial. It runs beside 19; both read what 18 built.

**Question.** Is the allowance grant plus the shared empty-wallet handler one slice, blocked by the webhook cache?

**Decision.** A subscriber's wallet is topped up on every renewal and a trial gets the full grant on day one; when it runs out, the button that would debit shows the top-up sheet with the allowance, the renewal date and the two packs, and the app never locks. The webhook grants the monthly Allowance into the existing wallet on initial purchase and renewal (monthly on the anniversary for annual plans); Allowance is spent before pack credits and does not roll over; one shared 402 handler raises the sheet from every debiting call, including the Vana composer with a line above it.

**Why.** It is one wallet rule and one client handler, demoable by draining a sandbox account. It follows 18 because the webhook is the same file.

**What else was considered.** Removing credits entirely; Lee chose the top-up model.

**What it touches.** supabase/functions/revenuecat-webhook/index.ts, supabase/functions/_shared/ai/credits.ts, supabase/functions/_shared/ai/usage.ts, lib/features/ai_credits/data/credits_repository.dart, lib/features/ai_credits/domain/credit_wallet.dart, lib/features/ai_credits/presentation/sheets/token_top_up_sheet.dart, lib/features/ai_credits/presentation/insufficient_credits_paywall.dart, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_logging/presentation/screens, lib/features/ai_coach/presentation/providers/ai_coach_chat_controller.dart, test/features/ai_credits

**Details.** 
- [ ] A renewal event grants the Allowance; the trial's initial purchase grants it in full; a cancelled trial forfeits the remainder and pack credits are untouched (webhook seam).
- [ ] Debits take Allowance first, then packs; unused Allowance does not roll over (wallet tests).
- [ ] One handler for 402 in the shared layer raises the top-up sheet showing allowance, renewal date and packs; every current call site uses it.
- [ ] The Vana composer's send raises the sheet and shows one line above the composer; Vana never says "out of credits" in a message.
- [ ] The Allowance number is set in this ticket and recorded on mp-281's Details.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 approved by Lee
> 2026-09-15 picture reused from test/features/subscription/presentation/goldens/paywall_light.png

## mp-299 · Ticket 21: The sandbox run and the release gate
- category: Tickets
- status: approved
- ticket: 21
- blocked: 19, 20
- depends: mp-289, mp-270
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-299.svg
- screen: none (algorithm/data)
- source: tickets mealplanning 2026-09-15

**Context.** Meal planning is not released until the seven-day trial exists, and only the stores can run an introductory offer. Ninth of nine tickets, last on the trial and the one that gates the release.

**Question.** Is the hand-run wizard plus the release checklist its own ticket, blocked by the gate and the allowance?

**Decision.** A person with a fresh sandbox account on each store walks a wizard that subscribes through the introductory offer, checks the entitlement is active on day one, checks the Allowance landed, cancels, meets the paywall, and restores; the wizard records each step and the write-up goes with the release. The release checklist gains the trial gate: no meal-planning release without a green run on both stores.

**Why.** It is the only proof the stores give, it cannot run in CI, and it needs 19 and 20 done to have anything to verify.

**What else was considered.** Folding the run into 19's acceptance; it lost because it spans two tickets and two stores.

**What it touches.** scripts/sandbox-trial-wizard.sh, docs/release, docs/deployment/supabase-deploy-playbook.md

**Details.** 
- [ ] A bash wizard walks the two-store run step by step and writes a dated log under docs/release.
- [ ] The release checklist names the run as a gate for any meal-planning release.
- [ ] One run on each store is logged green before the ticket closes.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 approved by Lee

## mp-300 · Ticket 22: Meal icons come off the tiles
- category: Tickets
- status: approved
- ticket: 22
- depends: mp-145
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: Plan tiles, where the icons come off
- screen: Plan tab
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the build drew a classified icon on every meal tile that had no photo. mp-145 keeps the classifier and its stored key and rules the icons off. First of eleven follow-on tickets (22 to 32) cut on 2026-09-15 for the approved rulings the build does not yet match; this one has no blockers.

**Question.** Is removing the drawn icons its own small ticket, first in the follow-on set?

**Decision.** A meal with no photo shows a plain placeholder on the Meals tab, the plan tiles, the plan bar and the review sheet. The 23-key classifier and the stored icon key on library, saved and plan meals stay exactly as they are. The glyph set and the icon tile widget are deleted.

**Why.** It is a removal with goldens to prove it, small enough to go first, and it touches the review sheet that 29 and 30 rebuild, so it goes ahead of them.

**What else was considered.** Folding it into the cooking-period ticket; it lost as unrelated work in a large ticket.

**What it touches.** lib/features/meal_planning/presentation/widgets/meal_card.dart, lib/features/meal_planning/presentation/widgets/plan_tile.dart, lib/features/meal_planning/presentation/widgets/plan_bar.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart, lib/features/meal_planning/presentation/widgets/meal_icon_glyphs.dart

**Details.** 
- [ ] No tile, card, plan bar row or review sheet row draws an icon; a missing photo shows the plain placeholder.
- [ ] The classifier, the icon key and its copy on add and swap are untouched (existing tests still pass).
- [ ] The glyph file and the icon tile widget are removed; goldens for the plan tile and the meal card are regenerated.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, f84827b9
> 2026-09-15 approved by Lee

## mp-301 · Ticket 23: The launcher is an allow-list of three screens
- category: Tickets
- status: approved
- ticket: 23
- depends: mp-264
- image: docs/ssot/decisions/images/mealplanning/timeline-launcher.png
- caption: The launcher on the Timeline, one of three screens
- screen: Launcher
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the launcher rule was built as a deny-list: an auth-and-paywall exclusion list plus thirty flow-screen patterns, with route-name workarounds on three pushed screens. mp-264 replaces that with an allow-list of three routes. Second of the follow-on set; no blockers.

**Question.** Is replacing the deny-list with the three-route allow-list one ticket?

**Decision.** The launcher appears on the main tabs screen, the meal-planning screen and coach formulas, and nowhere else. Any page pushed over one of those hides it without naming itself. The flow-pattern list, the gate-prefix list and the three route-settings workarounds are deleted.

**Why.** One rule file and its test, plus three deletions; it can run in the first wave beside anything.

**What else was considered.** Keeping the deny-list and adding coach formulas; rejected by mp-264.

**What it touches.** lib/features/meal_planning/domain/vana_launcher_rule.dart, test/features/meal_planning/domain/vana_launcher_rule_test.dart, lib/shared/screens/food_detail_screen.dart, lib/features/events/presentation/screens/event_form_screen.dart

**Details.** 
- [ ] The rule is an allow-list of the three routes; every other route, and any route pushed over one of the three, returns no launcher (rule tests).
- [ ] The flow-pattern list, the gate-prefix list and the RouteSettings workarounds are gone (the build-meal screen's workaround included; that file is otherwise untouched).
- [ ] Simulator: launcher on the Timeline, the Food tab and the formula library; none on a pushed form.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture reused from docs/ssot/decisions/images/mealplanning/timeline-launcher.png
> 2026-09-15 approved by Lee

## mp-302 · Ticket 24: Testers switch the dev buttons off in Settings
- category: Tickets
- status: approved
- ticket: 24
- depends: mp-271
- image: docs/ssot/decisions/images/mealplanning/settings.png
- caption: Settings, where the dev switch goes
- screen: Settings
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and on the simulator the dev accessibility and wrench buttons cover the launcher. mp-271 rules a per-tester switch in Settings, dev mode only. Third of the follow-on set; no blockers.

**Question.** Is the dev-mode switch its own small ticket?

**Decision.** In a dev build, Settings shows a switch that turns the accessibility and wrench buttons off and on for that tester on that device. It defaults to on, is remembered across launches, and is absent from release builds. No build-time flag.

**Why.** It is one persisted flag read by two widgets, and it unblocks every simulator capture that the launcher sits under.

**What else was considered.** A build flag; rejected by mp-271.

**What it touches.** lib/features/settings/presentation/screens/settings_screen.dart, lib/shared/widgets/root_app_widget.dart, lib/shared/widgets/environment_indicator.dart, test/features/settings

**Details.** 
- [ ] A dev-only switch in Settings, default on, persisted per device (controller test through the real notifier).
- [ ] Off hides the accessibility tools and the wrench; on restores them without a restart.
- [ ] Release builds show no switch and no buttons, as today.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee

## mp-303 · Ticket 25: An admin can review any meal
- category: Tickets
- status: approved
- ticket: 25
- depends: mp-144
- image: docs/ssot/decisions/images/mealplanning/meal-detail.png
- caption: Meal detail, where the admin box goes under the thumbs
- screen: Meal detail
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the meal library's quality is judged by nobody in the app. mp-144 clause 3 gives a signed-in admin a comment box on every meal page; the rest of mp-144 is built. The app has no admin role today. Fourth of the follow-on set; no blockers.

**Question.** Is the admin comment box, with the smallest admin role that can carry it, one ticket?

**Decision.** A signed-in admin opens any meal and sees a comment box under the thumbs: is this a good recipe, and why. Each comment lands in a review table with the meal, the admin and the date, for the team to read. Athletes never see the box. Admin is a boolean on the user record, set by hand in the database, read by the server for the insert policy and by the client to show the box; there is no admin UI to grant it.

**Why.** It is the last clause of mp-144 and the only one unbuilt; the hand-set flag is the least role machinery that still keeps athletes out.

**What else was considered.** Reusing the tester device flag (per device, not per person); a full roles table (more than the box needs).

**What it touches.** supabase/migrations/20260916120000_meal_reviews_and_admin_flag.sql, lib/features/meal_planning/presentation/screens/meal_detail_screen.dart, lib/features/meal_planning/application/meal_detail_controller.dart, lib/features/meal_planning/data/meal_review_repository.dart, test/features/meal_planning/application/meal_detail_controller_test.dart

**Details.** 
- [ ] Migration: an is_admin boolean on users (default false) and a meal_reviews table whose insert policy requires it.
- [ ] The box shows only when the signed-in user is an admin; a review writes one row (controller test through the real notifier).
- [ ] The dev account used for captures is set admin by hand and the simulator shows the box; a second dev account does not.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee

## mp-304 · Ticket 26: Typed feedback reaches the same inbox as a shaken report
- category: Tickets
- status: approved
- ticket: 26
- depends: mp-245, mp-248
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-304.svg
- screen: none (algorithm/data)
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and feedback she saves goes to a table the team must remember to read while shaken reports go to Wiredash. mp-245 clause 6 says the feedback tool also files a Wiredash entry. The server has no Wiredash client today, and Wiredash may offer no server-side ingest. Fifth of the follow-on set; no blockers.

**Question.** Is bridging typed feedback into Wiredash one ticket, with a stop if no ingest path exists?

**Decision.** A complaint typed to Vana appears in the same Wiredash inbox as a shaken report, with the athlete's words, the sentiment and the conversation id. The ticket's first step finds the ingest path (a Wiredash server API, or the client filing silently when it receives the feedback-saved part); if neither exists, the ticket stops and puts the question on the page instead of building a substitute.

**Why.** One inbox is the whole point of mp-245; the guard keeps an agent from inventing a second feedback system.

**What else was considered.** A scheduled export from the feedback table into Wiredash; deferred until the ingest question is answered.

**What it touches.** supabase/functions/_shared/vana/tools.ts, supabase/functions/tests/vana/feedback_ack.test.ts, lib/features/feedback/data/feedback_repository.dart, lib/shared/widgets/shake_to_report.dart

**Details.** 
- [ ] The ingest path is found and named in the ticket, or the ticket stops with an open question on the page.
- [ ] A saved feedback row produces one Wiredash entry carrying words, sentiment and conversation id (seam test with a fake client).
- [ ] The feedback-saved acknowledgement is unchanged for the athlete.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 approved by Lee

## mp-305 · Ticket 27: One sheet height, and hand-offs instead of doing it in the sheet
- category: Tickets
- status: approved
- ticket: 27
- blocked: 15, 26
- depends: mp-265, mp-061
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: Vana sheet
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the sheet was built with three heights, auto sizing and custom drag thresholds. mp-265 rules one height and turns every deterministic action into a hand-off button to the app's own screen. Sixth of the follow-on set; it follows 15 because both edit the sheet's host.

**Question.** Is the one-height sheet plus the hand-off part one ticket, blocked by 15?

**Decision.** The sheet opens at one standard height and its contents scroll; the close button or a plain drag down dismisses it; nothing grows on send or resizes while Vana streams; full screen happens only from its button. When the athlete asks for something the app has a screen for, Vana answers with a hand-off button (meal plan to the meal-planning page, fuelling a workout to new activity, planning an event to the event screen, carb loading to the picks) instead of doing it in the sheet; the button is a new part in the wire contract that the app renders.

**Why.** The height change and the hand-off part are the two halves of "the sheet is a bigger view of nothing": one demo shows both.

**What else was considered.** Keeping auto height for one-line openers; rejected by mp-265.

**What it touches.** lib/shared/widgets/kyle_design/navigation/vana_sheet.dart, lib/features/meal_planning/presentation/widgets/vana_companion.dart, lib/features/meal_planning/presentation/widgets/vana_part_renderer.dart, supabase/functions/_shared/vana/contracts.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/tests/vana/contract.test.ts, docs/ssot/spec/design/components/vana-sheet.md

**Details.** 
- [ ] One height, no auto or three-quarter state, no custom thresholds; goldens regenerated and the component spec updated with its version.
- [ ] A hand-off part in the contract (target screen, label, entity id) rendered as a button that navigates; the frozen fixtures carry it (contract test).
- [ ] The persona names the four hand-offs and the eval shows a meal-plan request in the sheet answered with the button, not a picker.
- [ ] Simulator: ask for a plan from the sheet, tap the button, land on the meal-planning page.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
> 2026-09-15 approved by Lee

## mp-306 · Ticket 28: The general opener reads the screen underneath
- category: Tickets
- status: approved
- ticket: 28
- blocked: 15, 20
- depends: mp-268, mp-008
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: Vana sheet
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the general opener reads only a workout moment and otherwise says a fixed line, while the empty chat still shows three example chips. mp-268 rules that the opener reads the screen underneath and falls back to the personal opener, with no example chips. Seventh of the follow-on set; it follows 15 because the opener path is rewritten there.

**Question.** Is the screen-aware general opener one ticket, blocked by 15?

**Decision.** An athlete opens the sheet on the event screen and Vana's first line is about that event; on a screen that says nothing useful, she says the most relevant personal thing she holds. The general opener reads the resolved Situation before anything else; the example chips are removed from the empty state; offline, rate limit and out-of-trial keep their one visible outcome each.

**Why.** It is the one opener rule not yet built, and it lands on the opener path 15 leaves behind.

**What else was considered.** Keeping the chips as a fallback; rejected by mp-268.

**What it touches.** supabase/functions/_shared/vana/moment.ts, supabase/functions/tests/vana/moment.test.ts, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart

**Details.** 
- [ ] The general opener with a Situation naming an event, a meal or a session opens on it; with a bare route it falls back to the personal opener (server seam).
- [ ] The three example chips are gone from the empty state (golden).
- [ ] Simulator: open the sheet on an event and hear about the event.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
> 2026-09-15 approved by Lee

## mp-307 · Ticket 29: Week start and period length are settings
- category: Tickets
- status: approved
- ticket: 29
- blocked: 15, 22
- depends: mp-269
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-307.svg
- screen: none (algorithm/data)
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the plan week starts on Sunday by a hardcoded offset, with cook days at fixed offsets from it. mp-269 makes the start day and the period length settings. Eighth of the follow-on set; it follows 15 (the opener file) and 22 (the review sheet).

**Question.** Are the two settings and every reader of them one ticket?

**Decision.** An athlete sets their week to start on Monday and their period to ten days; the Plan tab, coverage, the review sheet and the check-in opener all follow, and cook days derive from the settings rather than fixed offsets. Sunday and seven days stay the defaults. The two settings are keyed Vana settings like batch cooking, editable in Vana settings.

**Why.** Every reader must move at once or the tab and the opener disagree; the cooking-period ticket (30) needs the period length to exist first.

**What else was considered.** Week start alone; it lost because the period length is what 30 counts against.

**What it touches.** lib/features/meal_planning/domain/vana_setting.dart, lib/features/meal_planning/presentation/screens/vana_settings_screen.dart, lib/features/meal_planning/application/vana_settings_controller.dart, lib/features/meal_planning/domain/plan_coverage.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart, lib/features/meal_planning/presentation/widgets/week_card.dart, supabase/functions/_shared/vana/env.ts, supabase/functions/_shared/vana/opener.ts, supabase/functions/_shared/vana/plan-math.ts, test/features/meal_planning/application/vana_settings_controller_test.dart

**Details.** 
- [ ] Two keyed settings, week start and period days, with defaults Sunday and 7, editable in Vana settings (controller test).
- [ ] weekStartFor and the cook-day offsets read the settings; a Monday start moves cook, top-up and fresh days accordingly (server seam).
- [ ] Coverage, the review sheet and the week card read the period length (widget tests).
- [ ] Simulator: change the start day and see the Plan tab's week move.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 approved by Lee

## mp-308 · Ticket 30: A plan fills a cooking period, not fourteen slots
- category: Tickets
- status: approved
- ticket: 30
- blocked: 15, 22, 26, 27, 29
- depends: mp-231, mp-232
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: The Plan tab, counting against a period
- screen: Plan tab
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the plan walk is a fixed order of meal types with fixed servings against seven or fourteen slots. mp-231 rules a cooking period, servings that scale to cover it, a walk over only the types the athlete plans, per-day planning for non-batch athletes, and a one-tap draft from last time. Ninth of the follow-on set; it follows 29 (the period length) and 27 (the persona).

**Question.** Is the cooking-period model one ticket, blocked by the settings and the persona work?

**Decision.** An athlete who batches picks a few meals and the servings scale so the batch covers their period; coverage counts servings against the period; one who does not batch plans per day; the walk covers only the meal types they plan, in any order; one tap drafts the period from what they ate last time; Draft it for me stays deterministic and the model only presents it.

**Why.** It is the largest follow-on and the one most tied to the prototype's shape; it cannot start until the period length exists.

**What else was considered.** Splitting batch and per-day into two tickets; they lost because coverage is one function.

**What it touches.** supabase/functions/_shared/vana/plan-math.ts, supabase/functions/_shared/vana/plan.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/tests/vana/doll.test.ts, lib/features/meal_planning/domain/plan_coverage.dart, lib/features/meal_planning/application/plan_coverage_service.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart

**Details.** 
- [ ] Coverage counts servings against the period from the settings; batch mode scales servings to cover it; per-day mode counts days (server and client seams agree on fixtures).
- [ ] The walk visits only the types the athlete plans, in the order they choose (server seam).
- [ ] "Same as last time" drafts the period from the previous confirmed plan deterministically (server seam).
- [ ] Simulator: a ten-day period in batch mode shows servings scaled and coverage against ten days.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, f84827b9
> 2026-09-15 approved by Lee

## mp-309 · Ticket 31: A turn names its chips, and Show more opens the library
- category: Tickets
- status: approved
- ticket: 31
- blocked: 15, 26, 27, 30
- depends: mp-272, mp-230
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption: The chat, where the chips sit under a picker
- screen: Vana chat
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the chips under a picker are only the app's fixed set; there is no Show more. mp-272 lets a turn name two to four chip labels the app draws, and mp-230 asks for a Show more sheet over the same search. Tenth of the follow-on set; it follows 27 because both extend the wire contract and the renderer.

**Question.** Are the model-named chips and the Show more sheet one ticket, blocked by 27?

**Decision.** When Vana's turn names the choices it expects next, those labels appear as the chips under the picker, drawn by the app; when it names none, the app's own set applies; tapping any chip sends its label. Show more under a picker raises a sheet with many more meals from the same search.

**Why.** Both are picker affordances on the same part and share the renderer; together they are one demo.

**What else was considered.** Letting the model draw chips; rejected by mp-272.

**What it touches.** supabase/functions/_shared/vana/contracts.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/persona.ts, lib/features/meal_planning/presentation/widgets/picker_chips.dart, lib/features/meal_planning/presentation/widgets/meal_picker_carousel.dart, lib/features/meal_planning/presentation/widgets/vana_part_renderer.dart, lib/features/meal_planning/presentation/widgets/meal_catalog_browser.dart

**Details.** 
- [ ] The picker part carries an optional chips list of two to four strings; more or fewer is clamped or dropped (contract test with the frozen fixtures).
- [ ] Named chips replace the app set; absent or empty falls back to it; a tap sends the label (widget test).
- [ ] Show more raises a sheet over the same search with many more meals; the tick adds, the tile opens detail.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee

## mp-310 · Ticket 32: Every recipe says where its steps came from
- category: Tickets
- status: approved
- ticket: 32
- blocked: 25
- depends: mp-146
- image: docs/ssot/decisions/images/mealplanning/meal-detail.png
- caption: Meal detail, where the origin label sits
- screen: Meal detail
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and a recipe's origin is recorded on every row but only the AI-generated badge survived a cleanup. mp-146 rules a badge per origin and an "as published by X" link for verbatim steps. Eleventh and last of the follow-on set; it follows 25 because both edit the meal detail screen.

**Question.** Is restoring the origin badges and the publisher link one ticket, blocked by 25?

**Decision.** Every recipe's steps carry a label by origin: verbatim steps read "as published by X" with a link to the original, an alternate source names it, a simple assembly says so, and AI-generated steps keep the sparkle with its tooltip. Macros stay as they were.

**Why.** The data exists; this is the last unbuilt half of an approved card, and it sits on the screen 25 just touched.

**What else was considered.** none recorded

**What it touches.** lib/features/meal_planning/presentation/screens/meal_detail_screen.dart, lib/features/meal_planning/domain/directions_origin.dart

**Details.** 
- [ ] Four origins, four labels; verbatim carries the publisher name and link (widget test per origin).
- [ ] The sparkle tooltip is unchanged for AI-generated steps.
- [ ] Golden of the detail screen per origin.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee

## mp-317 · The Entitlement row holds four fields, and each kind of event has one rule
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-317.svg
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 18

**Context.** mp-285 shrinks the entitlements table to a cache of RevenueCat: active until and period type, written only by the webhook, with an event older than the row ignored. Ticket 18 wrote the migration and the handler and had to settle what "older than the row" is stored as and what each event kind does to the row.

**Question.** What is on the Entitlement row, and what does each kind of event do to it?

**Decision.** The row holds four things: the user, active until, period type and the time of the last event, and an event older than that time is ignored. A transfer, where a purchase moves to another account, closes the old account's row and writes the new one's; a test event from RevenueCat writes nothing; and signed-in users can only read the row. The precise rule for an expiration event is in Details. Example: an athlete restores their purchase onto a new account on 10 October; the old account's row closes on 10 October, and a late event for the old account that arrives on 11 October is ignored.

**Why.** Each clause is what mp-285's "RevenueCat wins" and "nothing app-side grants" need once real event shapes are in front of the writer.

**What else was considered.** Keeping the old column names (expires at, updated at). Deleting the old owner's row on transfer instead of closing it.

**What it touches.** The webhook handler, the entitlements table, the migration, the server gate.

**Details.** Precisely:
1. The row holds the user id, active until, period type and the event time. Every other column is dropped. The event time is what "older than the row" compares against.
2. A transfer closes the old owner's row at the transfer time and writes the new owner's, so a late event for the old owner is stale and ignored.
3. A test event writes nothing: a ping has no expiry and must not touch the cache.
4. An expiration whose payload names a later expiry closes the row at the event time, so a clock-skewed payload cannot keep a lapsed subscriber active.
5. Signed-in users may only read the table. No app-side insert or update is granted.

Migration 20260916110000, applied to dev (11 columns and 0 rows before; 4 columns after). An insert as the authenticated role fails with 42501. Thirty handler test steps run against RevenueCat-shaped events.

> 2026-09-15 proposed from wave 1 ticket 18
> 2026-09-17 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-318 · No flag the app sets opens the server's check; testers subscribe in TestFlight
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-318.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-318-2.svg
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 18

**Context.** The server's Pro check used to let in anyone whose users row said internal, a flag the app itself writes when a Tester marks the phone. mp-285 clause 3 says nothing in the app ever gives anyone access.

**Question.** Do testers still get past the server's paid check?

**Decision.** No. The server lets in only accounts RevenueCat shows as paid, reading active until and period type on the Entitlement row and nothing else; no flag the app writes counts. A Tester gets in by subscribing in TestFlight, where a purchase charges nothing, and that purchase reaches the row like any other. An Admin skips the paywall screen in the app only, and still needs a TestFlight subscription or a Grant for Vana to answer. Example: a Tester who marked their phone as internal but never subscribed is refused by Vana; after a $0 TestFlight subscription the webhook writes their row and Vana answers.

**Why.** A flag the app writes is the app giving access, which mp-285 forbids. Keeping the users column (clause 4) kept the wave's other simulators working, since the dev table had no rows.

**What else was considered.** Keeping the bypass for dev builds only.

**What it touches.** The server gate, RevenueCat promotional grants, the dev deploy order.

**Details.** Precisely:
1. The server asks only whether RevenueCat shows the account as paid: it reads active until and period type and nothing else. No flag the app sets opens it.
2. Testers get in by subscribing in TestFlight, which charges nothing; the purchase reaches the row through the webhook like any other. There is no per-tester setup and no list of testers.
3. A team admin account skips the paywall screen in the app only (mp-416). For Vana to work it also needs a TestFlight subscription or a RevenueCat grant.
4. The users column stays; the app still writes it for its own dev features.

> 2026-09-15 proposed from wave 1 ticket 18
> 2026-09-17 amended by Lee
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-319 · The store offers are written by script, on the dev apps, per territory
- category: Pro and paywall
- status: rejected
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-319.svg
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 18

**Context.** mp-279 gives the monthly and annual subscriptions a seven-day free introductory offer on both stores with no new product ids. Ticket 18 had to create them through the store APIs and decide where the scripts may point.

**Question.** How are the offers created, and what stops a script from touching the live apps?

**Decision.** 
1. Two scripts under scripts/store, one per store, each with a read-only listing and an add-trial command. Both refuse the production app id and package name by construction and exit with code 2.
2. Apple stores the offer once per territory. The script writes it to every territory the products sell in (175 today) and must run again when a territory is added.
3. Google's offer targets any subscription in the app, which gives the one-trial-per-person rule. Mongolia is left out because it is not billable at the regions version the app uses.
4. The dev RevenueCat integration now delivers all eleven lifecycle events instead of three, so a cache that hears purchases also hears expirations. The production integration is untouched.

**Why.** The dev apps are where a script can be proved. Production is a release-day act with the migration and the webhook.

**What else was considered.** Creating the offers by hand in both consoles.

**What it touches.** App Store Connect and Google Play for the dev apps, the dev RevenueCat integration, docs/implement_mealplanning/04-entitlement.md.

**Details.** Apple dev app 6756683509, products mealvana_pro_monthly and mealvana_pro_annual, offer FREE_TRIAL ONE_WEEK. Play package com.milkman.mealvanaendurance.dev, offer free-week, one phase P7D free.

> 2026-09-15 proposed from wave 1 ticket 18
> 2026-09-17 rejected by Lee: i don't want scripts.  i want to have claude do this with computer use and doing it manually through the browser

## mp-323 · The plain placeholder is a tinted rounded square
- category: Meals tab and library
- status: rejected
- image: docs/ssot/decisions/images/mealplanning/meals-tab.png
- caption:
- screen: Meals tab
- source: wave mealplanning 1 ticket 22

**Context.** mp-145 says a meal with no photo shows a plain placeholder, not an icon, and the glyphs come off the tiles. No design-system widget for a missing picture existed, and the glyph file also held the slot colour lookup and was used on three surfaces the ticket did not name.

**Question.** What does the placeholder look like, and where does it live?

**Decision.** 
1. A flat fill of the host's ink at 10% alpha, no border, nothing inside. On a failed photo load the same box shows, never a blank slot.
2. A rounded square with radius a quarter of its size, so at 36 points it matches the meal card's picture radius. The old circle is gone.
3. The widget lives in the meal-planning presentation folder, not in the design system, because it is one tinted box drawn from registry tokens.
4. The meal sheet header, the shopping list's source rows and the swap screen's "swapping out" row use the same placeholder at their old sizes.
5. The slot colour lookup moved to the slot chip file, its remaining consumers being the chip and the shopping list.

**Why.** 10% is the hairline alpha the same rows already use, so the box sits at the card's own edge weight. A placeholder that stands in for a photo should read as the photo's box on every surface.

**What else was considered.** Keeping the mosaic spec's 18% tint box minus the glyph. Making the placeholder a design-system component with its own spec.

**What it touches.** Meals tab, Plan tab tiles, the plan bar, the review sheet, the meal sheet, the Shopping tab's source rows, the swap screen.

**Details.** Sizes 36 (tile, meal sheet, swap row), 32 (shopping source row), 30 (plan bar), 28 (review sheet row). Goldens regenerated: plan_draft, plan_confirmed, plan_bar_expanded, light and dark.

> 2026-09-15 proposed from wave 1 ticket 22
> 2026-09-15 picture captured at 1.26.0+1, f30e3897
> 2026-09-15 rejected by Lee: No placeholder at all. mp-145 re-ruled on 2026-09-15: a meal with no photo shows nothing (ADR 0003).

## mp-335 · On a phone the Gate reads RevenueCat's saved copy, on the web the server's row
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-335-2.svg
- screen: Paywall
- source: wave mealplanning 2 ticket 19
- linked: mp-337

**Context.** mp-279, mp-280 and mp-284 make RevenueCat's cached entitlement the only gate, lock an unknown answer after a couple of seconds, and put the whole app behind the paywall. Ticket 19 built the client side and made the choices the record left open.

**Question.** How does the app decide whether to show the paywall, and when?

**Decision.** On a phone the Gate reads the copy of RevenueCat's answer saved on the device, so it answers at once after a purchase and works offline; the web build has no RevenueCat and reads the server's Entitlement row instead, which opens the coach portal on the web. Startup waits for the Gate, at most two seconds, so a subscriber never sees the paywall flash, and the saved copy counts only once it belongs to the signed-in account. The router is the one place that sends people to or from the paywall, so an account with access can never see it, and the old tester shortcuts and switches are gone. Example: an athlete buys the monthly plan on the paywall on 8 October; the saved copy updates at once and the router takes them into the app without the paywall moving itself.

**Why.** Each clause follows from "RevenueCat is the only gate": no second source of truth, no bypass, and the router as the one place the gate is enforced.

**What else was considered.** Keeping the tester grant for debug builds (a second gate, and the server dropped its own bypass in ticket 18); letting the paywall pop itself on success (two owners of navigation).

**What it touches.** `lib/features/subscription/`, the router, app startup, the Vana chat screen, the main tabs shell, `codemagic.yaml` (the removed flags and the removed Patrol paywall flow).

**Details.** Precisely:
1. On a phone the app reads RevenueCat's saved copy on the device: it answers at once after a purchase and works offline. The network is not on the path; the copy refreshes in the background.
2. The web build has no RevenueCat, so it reads the server's entitlement table, which the RevenueCat webhook keeps. This opens the coach portal on the web and answers mp-337.
3. Startup resolves the gate on the critical path, bounded by the two-second cap, so a subscriber's cold start never flashes the paywall.
4. Before trusting the cache the app checks the SDK's identity: a different app user id logs in first, and if that cannot happen offline the answer is locked.
5. The paywall route redirects to the app whenever the gate is unlocked, so a purchase, a restore or a background refresh moves the person in without the screen navigating. An entitled account can never view the paywall.
6. The tester tap-grant, the `users.is_internal` mirror in the gate, the purchase-enabled flag and the gate flag are gone. Testers need a real entitlement: a TestFlight subscription or a RevenueCat grant (mp-318).
7. The introductory offer shows unless the store says the person is ineligible. "Manage subscription" opens RevenueCat's management URL, else the platform's subscriptions page.
8. A Pro-required answer from a Vana call warns and refreshes the status; the router alone moves onto the paywall.

Seam tests: 17 through the status controller, 9 through the paywall controller, a router redirect test, light and dark goldens of the paywall. The Drift `user_entitlements` table stays in the schema unused until a schema bump.

> 2026-09-15 proposed from wave 2 ticket 19
> 2026-09-15 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-17 amended by Lee
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-336 · The ratifier checks purchase-then-Restore on TestFlight, because no agent can
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-336-2.svg
- screen: Paywall
- source: wave mealplanning 2 ticket 19

**Context.** Ticket 19's last criterion asks that a sandbox account without an entitlement sees the paywall on launch, and that Restore after a sandbox purchase reopens the app. The first half ran on a pool simulator (the paywall with Test Store prices, Restore leaving it locked). A simulator cannot sign into a sandbox account, so the second half cannot be observed by any wave agent, on this wave or a later one.

**Question.** Who checks that Restore after a test purchase reopens the app?

**Decision.** The ratifier (Lee), on a TestFlight build signed into an Apple sandbox account, a test account that buys without being charged. A simulator cannot sign into a sandbox account, so no build agent, on this wave or a later one, can ever watch this happen. Ticket 19 is done on its code and the half of the check an agent could run, and the wave does not rebuild it. Example: an agent's simulator showed the paywall with Test Store prices and Restore leaving it locked; buying with a sandbox account and then tapping Restore is left for Lee on TestFlight.

**Why.** Rebuilding the ticket against the same impossibility produces the same result; the person with a device and a sandbox account is the one who can see it.

**What else was considered.** Failing the ticket and re-queueing it (no path to the observation); a RevenueCat promotional grant as a stand-in (it proves the gate reacts, not that a store purchase restores).

**What it touches.** The paywall, the release checklist.

**Details.** Precisely: the purchase-then-Restore check is the ratifier's, on a TestFlight build with a sandbox account. The ticket is done on the code and the first half of the check; the wave does not rebuild it for a criterion no agent can meet.

> 2026-09-15 proposed from wave 2 ticket 19
> 2026-09-15 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-17 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-340 · The monthly Allowance is 300 credits
- category: Pro and paywall
- status: rejected
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-340.svg
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 20

**Context.** mp-281 §5 leaves the allowance number to the ticket that writes the paywall copy, with the per-call cost log deciding it: enough that a person who plans a week and asks a few questions a day never sees the top-up. Ticket 20 read the dev cost log and set it; this card records the number mp-281 asks to have recorded.

**Question.** How many credits does the subscription grant each month?

**Decision.** 300 credits a month, set in `_shared/ai/allowance.ts` and overridable per project with `AI_MONTHLY_ALLOWANCE`.

**Why.** The mp-281 person spends about 236 a month: one planning conversation a week at about six turns (26), three questions a day (90), up to three meal logs a day (90), one coach insight a day (30). 300 leaves about a quarter of headroom, and spent in full at the worst per-call price costs about $3.60 against the $9.99 subscription.

**What else was considered.** 250 (the large pack's size; too tight against 236) and 500 (dev's old free number, about $6.50 of exposure).

**What it touches.** The webhook grant, the wallet roll, the top-up sheet's allowance line, the prod environment (`AI_MONTHLY_ALLOWANCE` unset means 300).

**Details.** Per-call costs from dev on 2026-09-15: vana-chat turn about $0.015 uncached (14.2k in, 165 out, n=510; planning turns read about 19k cached); describe-meal $0.0077 average, $0.0092 p95 (n=33); analyze-meal-photo $0.0130 average, $0.0166 p95 (n=24); ai-coach $0.0021 (n=7); jade-chat about 12.9k in. Planning conversations: p50 one user turn, p90 four.

> 2026-09-15 proposed from wave 2 ticket 20
> 2026-09-17 approved by Lee
> 2026-09-21 rejected by Lee: replaced by mp-430, a monthly budget on real cost, not a credit count

## mp-341 · How the Allowance lives in the wallet and rolls
- category: Pro and paywall
- status: rejected
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-341.svg
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 20

**Context.** mp-281 grants the allowance on each RevenueCat renewal event, monthly on the anniversary for annual plans, forfeits a cancelled trial's remainder and never rolls unused allowance over. The webhook gets no monthly event for an annual plan, and RevenueCat's cancellation event keeps access to the period end, so ticket 20 had to choose the mechanism.

**Question.** When is the allowance granted, forfeited and spent, and what does a Vana turn cost?

**Decision.** 
1. The wallet row carries `allowance` (part of the balance, spent first), `allowance_monthly` (the grant the sheet shows) and `allowance_expires_at`. The ledger records `grant_allowance` (unique per event or window) and `forfeit_allowance`.
2. The webhook grants on INITIAL_PURCHASE and RENEWAL, keyed on the event id, into a window ending at the period end, or at the next anniversary day for an annual plan.
3. Annual plans roll monthly by a lazy check, not a scheduler: before every debiting call and at app start, an expired allowance is forfeited and, while the entitlement is active and no window is open, the current window is granted.
4. Forfeit happens on EXPIRATION, and on the first debit after the window ends, not on CANCELLATION: cancelling keeps access to the period end, and forfeiting on cancel would refill on uncancel.
5. A Vana message turn debits one credit; the scripted opener does not. The 402 body carries the allowance size and renewal date.
6. The free monthly grant of 20 credits (50 on dev) is untouched by this ticket.

**Why.** A lazy roll needs no second moving part and keys idempotency on the window; forfeiting at expiry matches RevenueCat's own semantics; the composer could never see a 402 while Vana turns were free.

**What else was considered.** pg_cron or a scheduled function for the anniversary grant; forfeiting on CANCELLATION.

**What it touches.** `revenuecat-webhook`, `_shared/ai/credits.ts`, `ensure-credits`, `vana-chat`, `jade-chat`, `ai-coach`, `describe-meal`, `analyze-meal-photo`; migration 20260916130000; the wallet row.

**Details.** Wallet rules are proved by five scenarios against the real SQL on dev inside a rolled-back transaction (`_shared/ai/wallet_rules.test.ts`), skipped when the management token is absent, so CI does not run them.

> 2026-09-15 proposed from wave 2 ticket 20
> 2026-09-17 rejected by Lee: as part of this work we now need to do some evaluations of cost and pricing.  so this needs to be a thorough task.  the objective is if we charge however much per month then how can we maximize usage of vana for our clients while still returning a healthy profit.  if each turn debits 1 thing then that might prove too restrictive.  as part of this should also be ways in which we can reduce costs like perhaps using apple's own native intelilgence for people with newer iphones and perhaps having some prompt rerouting rules for super simple prompts to a really basic agent.  perhaps seeing if there are even more basic agents on vercel that we have access to and can call.  so this needs some thorough work and evaluation and we need to think about this a lot more

## mp-342 · The top-up sheet shows the share of the month used, and Vana's strip clears itself
- category: Pro and paywall
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-342-2.svg
- screen: Vana chat
- source: wave mealplanning 2 ticket 20

**Original.** 
1. The sheet keeps the word "tokens" and adds "Your plan includes 300 tokens a month · N left · renews <date>" above the two packs, reading the wallet row live rather than the 402 body.
2. The one handler lives in the credits feature's presentation folder and every debiting call site imports it; a second sheet never stacks on the first.
3. The strip above Vana's composer reads "Out of tokens for now — top up to keep chatting · Top up", the typed text goes back into the field, and the strip comes down on its own when the wallet rises or a turn goes through.
4. The AI coach chat rolls a 402 turn back with no line in the thread, as Vana does.

**Lee said.** wait are we surfacing credits to the user? or are we talking about usage?

**Context.** mp-282 puts the top-up sheet on the button that would spend, with one line above Vana's message box and one handler for the server's 402 ("payment required") in the app. Ticket 20 built the sheet's allowance lines, the strip and the handler.

**Question.** What do the top-up sheet and the strip above Vana's message box say, and when does the strip go?

**Decision.** The sheet shows how much of this month's Vana budget is used, as a percentage with the renewal date, above the two packs; it never shows credits, tokens or dollars. When the budget is used up, a strip above Vana's message box says so with a Top up button, the typed message goes back into the field, and the strip goes away by itself once the budget rises or a message goes through. The AI coach chat takes a refused message back the same way, with no line left in the conversation. Example: on 20 October an athlete with nothing left types "swap Thursday's dinner" and taps send; the strip reads "You've used this month's Vana budget. Top up to keep chatting · Top up", the text is back in the field, and the sheet reads "100% of this month's Vana budget used · renews 8 November".

**Why.** One handler means a new AI feature gets the sheet without extra work. The sheet already watches the wallet row, so that is its one source. Moving the handler into the app's shared code would pull RevenueCat's purchase code in with it.

**What else was considered.** A handler under `lib/shared/` (drags purchase controllers into shared); reading the sheet's numbers from the 402 body (a second source).

**What it touches.** The Vana chat screen, the top-up sheet, the describe, log-meal, edit-log, photo-capture, coach insight and AI coach call sites.

**Details.** Precisely:
1. The sheet shows usage, never credits, tokens or dollars: "N% of this month's Vana budget used · renews <date>" above the two packs, reading the wallet row live rather than the 402 body.
2. The one handler lives in the credits feature's presentation folder and every debiting call site imports it; a second sheet never stacks on the first.
3. The strip above Vana's composer reads "You've used this month's Vana budget. Top up to keep chatting · Top up", the typed text goes back into the field, and the strip comes down on its own when the budget rises or a turn goes through.
4. The AI coach chat rolls a 402 turn back with no line in the thread, as Vana does.

The sheet's allowance lines render only when `allowance_monthly` is above zero, so a subscriber whose grant has not landed sees the packs alone.

The handler is not under `lib/shared/`: that would pull RevenueCat into shared code.

> 2026-09-15 proposed from wave 2 ticket 20
> 2026-09-15 picture captured at 1.26.0+1, 2656d4b8
> 2026-09-17 approved by Lee
> 2026-09-21 amended by Lee
> 2026-09-21 approved again by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-416 · A team admin opens the app without a subscription
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_dark.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-416-2.svg
- screen: Paywall
- source: Lee in the terminal 2026-09-16
- linked: mp-279, mp-286

**Context.** mp-279 makes RevenueCat's `pro` the only Gate, and mp-286 gives no one a branch. The team's own accounts (test@test.com and any other Admin) then met the paywall on every device without a purchase, which is what mp-415 hit on a test simulator. The Admin mark already existed for the meal review box (mp-144).

**Question.** Does an Admin account meet the paywall?

**Decision.** No. The Gate in the app opens for an Admin, an account the team marked by hand in the database, whatever its subscription says; there is no other exception, no build switch, no tester shortcut, no coach branch. The app checks for Admin only when the account has no access, and waits no longer than the same two seconds, so on a slow network it still lands on the paywall. The server still checks the subscription on every paid and Vana call, so an Admin skips only the paywall screen. Example: test@test.com signs in on a fresh simulator with no purchase and goes straight into the app, but Vana refuses it until it has a TestFlight subscription or a Grant (mp-318).

**Why.** Lee on 2026-09-16: test@test.com and other admin accounts must not be shown this screen and should access the account like normal. Setting the flag by hand keeps the exception to accounts the team names.

**What else was considered.** A dev-only bypass switch (a build flag, ruled out by mp-279), copying the dev simulator's receipt onto every pool device (mp-415).

**What it touches.** pro_gate.dart, is_admin_provider.dart, the gate tests.

**Details.** Precisely:
1. The app gate opens for an account whose `users.is_admin` is true, whatever the subscription status. No other exception: no build flag, no tester grant, no coach branch.
2. The admin read runs only when the status is inactive, and is bounded by the same two-second answer window as the entitlement, so a slow network still lands on the paywall.
3. The server keeps checking the entitlement on every debiting and Vana call (mp-285); the bypass is the client gate only.

> 2026-09-16 proposed from Lee's terminal ruling; code landed the same day
> 2026-09-17 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-417 · The account is required, and the plan screen is onboarding's last step
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_dark.png
- caption: The paywall; onboarding shares its layout and ⋯ menu (mp-494)
- svg2: docs/ssot/decisions/images/mealplanning/mp-417-2.svg
- screen: Paywall
- source: Lee in the terminal 2026-09-16
- linked: mp-279, mp-280, mp-297

**Original.** 
1. The account is required. The guest path and its "create one later in Settings" note are gone from the account screen. The anonymous session stays as plumbing that sign-up links onto so onboarding answers survive.
2. The account screen's one line of copy under the title is the trial line, from store prices: "{days} days free, then {monthly} a month or {annual} a year. Cancel any time." A price-free fallback shows while the store answers.
3. After sign-up the athlete lands on the paywall in its onboarding shape: the app name, the two plans and Restore purchases only. Manage subscription, Sign out and Delete account belong to the lapsed shape (mp-280) and do not appear.
4. The onboarding shape is the same route with a query; the gate's redirect still moves an unlocked account on to the app, so an admin (mp-416) or a restored account never sees it.

**Lee said.** we don't want any anonymous users anymore. all of that plumbing needs to be archived

**Context.** The account screen at the end of onboarding still offered "Continue without signing in". With every screen behind the one Gate, a guest would finish onboarding and meet the paywall at once, and could not buy, because a purchase is tied to the signed-in account (mp-279). The paywall then arrived as a lock screen with Sign out and Delete account beside the buy buttons, on an account made a moment ago, with nothing having warned the athlete a plan choice was coming.

**Question.** How does onboarding end now that every account must pay?

**Decision.** Every athlete makes an account: there are no anonymous users, the app never starts an anonymous session, and onboarding answers stay on the phone until sign-up writes them to the account. The account screen says under its title what the Trial costs, from the store's prices, and right after sign-up the athlete lands on the paywall in its onboarding form: the app name, the two plans and Restore purchases only. An account that already has access skips it, because the router moves it on to the app. Example: with the base prices the account screen reads "7 days free, then $24.99 a month or $199.99 a year. Cancel any time."

**Why.** The account has to come first because the purchase is stored against it; the fix is to say so before the account is made, and to make the plan screen read as the next step rather than a wall.

**What else was considered.** Plan choice before the account (the purchase would have no auth id to map onto); keeping the guest path (leads straight to a paywall the guest cannot pay).

**What it touches.** post_onboarding_auth_screen.dart, post_onboarding_auth_controller.dart, paywall_screen.dart, pro_gate_redirect.dart, app_router.dart, content_defaults.json, the onboarding sign-up Patrol flow.

**Details.** Precisely:
1. The account is required and there are no anonymous users. The app never starts an anonymous session; onboarding answers are kept on the phone until sign-up and written to the account then. The anonymous-session plumbing is archived. An install left anonymous from before the paywall registers to claim its grace (mp-429).
2. The account screen's one line of copy under the title is the trial line, from store prices: "{days} days free, then {monthly} a month or {annual} a year. Cancel any time." A price-free fallback shows while the store answers.
3. After sign-up the athlete lands on the paywall in its onboarding shape: the app name, the two plans and Restore purchases only. Manage subscription, Sign out and Delete account belong to the lapsed shape (mp-280) and do not appear.
4. The onboarding shape is the same route with a query; the gate's redirect still moves an unlocked account on to the app, so an admin (mp-416) or a restored account never sees it.

> 2026-09-16 proposed from Lee's terminal ruling; code landed the same day
> 2026-09-17 approved by Lee
> 2026-09-21 amended by Lee
> 2026-09-21 approved again by Lee
> 2026-09-22 picture reused from test/features/subscription/presentation/goldens/paywall_dark.png
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-418 · Plan rows show the library Meal's photo
- category: Plan tab
- status: approved
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-418-2.svg
- screen: Plan tab
- source: Lee, from the category discussion on 2026-09-17
- linked: mp-324

**Context.** A plan meal stores its name, meal type and icon key, and no picture. So the Plan tab, the plan bar and the review sheet had no photo to show, while the Meals tab and the recipe screen show a Meal's Dish photo (ADR 0003). mp-324 asked whether plan rows should ever show photos.

**Question.** Do the meals in a plan show a photo, and which one?

**Decision.** Wherever a plan shows a meal (the Plan tab, the plan bar pinned above the chat, and the review sheet) it shows the same Dish photo the Meals tab shows, or nothing. The photo is looked up from the library each time the plan is shown and never copied into the plan, so a photo a Tester adds, removes or restores later reaches plans already made. A meal that is in a plan twice shows its photo on both rows, and offline plan rows show no photos. Example: a Tester adds a Dish photo to a meal today; a plan confirmed last week that holds that meal shows the photo the next time it opens.

**Why.** Lee's ruling that a Meal looks the same wherever it is met (spec story 10). Looking the photo up rather than copying it means a plan never shows a stale or removed photograph. Built in meal-imagery ticket 03 (c714dae7). Lee on 2026-09-17: accepted offline showing no photos, and closed mp-324 with this card.

**What else was considered.** Copying the picture fields onto the plan meal row on add and swap, which lost because a later photo change would never reach plans already made. Keeping plan rows picture-less, which contradicts the everywhere ruling.

**What it touches.** lib/features/meal_planning/application/plan_meal_photos.dart, lib/features/meal_planning/presentation/widgets/plan_tile.dart, lib/features/meal_planning/presentation/widgets/plan_bar.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart

**Details.** Precisely:
1. Plan tiles, the plan bar and the review sheet show the same Dish photo the Meal shows on the Meals tab, or nothing, with the same collapse-on-failure rule.
2. The photo is looked up from the library Meal by meal id every time the plan is shown. It is never copied onto the plan row, and the add and swap paths are unchanged, so a photo a Tester adds, removes or restores later reaches plans already made.
3. A Meal that appears twice in a plan shows its photo on both rows. The one-photo-per-list rule does not apply to plans.
4. Offline, plan rows show no photos: nothing is mirrored to the phone.

> 2026-09-17 added from the category discussion on 2026-09-17 by Lee
> 2026-09-17 approved by Lee
> 2026-09-21 picture captured at 1.27.0+3, 18e21789
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-420 · Vana's prompt is cached in two parts, so a plan change keeps the tools and persona
- category: Cutting costs
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-420.svg
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 13; wave mealplanning 4 ticket 16
- work: pending
- linked: mp-316; mp-353

**Context.** Every turn sends Vana's whole prompt to the model: the tools, the persona, the Context block and the conversation so far. The prompt cache bills a part the model has already seen at a tenth of the price. Lee approved caching in mp-276 and ticket 13 built it; on dev, turn one of a conversation sent about 10,900 tokens and later turns about 6,000, most of it read from the cache. The first turn of every new conversation still reads nothing from the cache.

**Question.** How does Vana use the prompt cache, and should a brand-new conversation read from it too?

**Decision.** The prompt cache is on for every Vana call, and the Context block is kept on the conversation and rebuilt only on a new day or when the athlete changes something through Vana; anything that changes every message, such as the screen in view, rides on the athlete's message instead. Still to build: the tools and persona, which are the same for every athlete, get a cache marker of their own, so a new conversation can read them from the cache and a plan change no longer throws them away. A replayed conversation will be sent exactly as it was the first time, the call log will record what October's traffic needs to set the numbers, and the opener's 3.5-second start test stays as it is. Example: today a planning turn reads only 43% of its input from the cache, because every plan change rebuilds the Context block and discards the 12,000 tokens of tools and persona with it; with their own marker that turn drops from about 3.2 cents to about 1.2 cents.

**Why.** Cached input costs a tenth of fresh input. Clause 4 cuts a planning turn from about 3.2 cents to about 1.2 cents, roughly 40% of all AI cost. Clause 5 adds about 6%.

**What else was considered.** Marking individual prompt blocks by hand instead of automatic mode. Leaving the first turn uncached.

**What it touches.** vana-chat, vana-action, jade-chat, vana-day-notes; the conversation and call-log tables.

**Details.** Precisely:
1. Caching is switched on for every Vana call in Anthropic's automatic mode, and the call log records cached tokens. (mp-311) [built]
2. The athlete context is stored on the conversation and rebuilt only on a new day or when the athlete changes something through Vana. (mp-311) [built]
3. Anything that changes every message (the screen the athlete is on, the entity in view) rides on the athlete's message, never in the system prompt. A screen gets its "in view" section by adding one row to the server's screen table. (mp-312, mp-359) [built]
4. The tools and persona, which are the same for every athlete, get their own cache breakpoint, and the athlete context gets a second one. Today a planning turn reads only 43% of its input from the cache, because every plan change rebuilds the context and throws away the 12,000 tokens of tools and persona with it. (mp-316) [to build]
5. A replayed conversation is byte-for-byte what was sent the first time: the screen line and the opener's hidden first message are stored with the transcript. Today they are not, so each new turn misses the cache written by the last. [to build]
6. The call log also records cache-write tokens, the number of model steps, the gateway's own charge and whether the turn cost a credit, so October's real traffic can set the numbers. [to build]
7. The opener's start-time test stays at 3.5 seconds. The way to tighten it is a faster context build, not a looser test. (mp-353) [no work]

Audit 2026-09-20, dev, last 30 days: cache read share 43% on planning turns, 65% on planning openers, 52% on general openers. Dev conversation 614dbee6: turn 1 input 10,886, cache read 4,980; turn 2 input 6,075, cache read 4,980; turn 3 input 6,123, cache read 6,072. Migration 20260915120000 added context, context_day and cache_read_tokens. The cost report of 2026-09-20 has the full audit.

> 2026-09-20 folded from mp-311, mp-312, mp-359; answers mp-316, mp-353
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-429 · We build the 1 October paywall to Xuan's RevenueCat spec
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-429-2.svg
- screen: Paywall
- source: docs/revenuecat-spec-for-lee.md (Xuan, revised 2026-09-16)
- work: pending
- linked: mp-287

**Context.** Xuan's spec (docs/revenuecat-spec-for-lee.md, revised 09-16) is the paywall document mp-286 and mp-287 were waiting for. It sets prices, the Founding Month from 1 October to 30 November, how coaches get in, and a ship order with store submission around 25 September. It differs from three approved cards: mp-279 clause 1 (no new product ids), mp-283 (no grace for existing accounts) and mp-280 (what a lapsed account can open). Her answers are adopted here; tick a clause to keep your earlier ruling instead.

**Question.** Do we build the paywall to Xuan's RevenueCat spec, even where it changes earlier rulings?

**Decision.** Yes, whole, including the three places it changes what was ruled on 15 September. It sets $24.99 a month and $199.99 a year, with Founding Month prices of $12.49 and $99.99 to 30 November, each with the seven-day Trial, on new products; a coach gets 30 days of access from their own Code; every account that exists when the paywall switches on gets 30 days of Legacy grace; and a Lapsed account sees its data read-only instead of nothing. Every AI function checks the subscription on the server, and on day five of a Trial the phone reminds the athlete it ends in two days. Example: an athlete whose account already exists on 1 October gets 30 days free as a founding member, announced by email a week before; a new athlete signing up that day sees $12.49 a month after seven free days.

**Why.** Xuan owns pricing and go-to-market, and her document is the one the 09-15 rulings said they were waiting on. The dates leave five days to store submission.

**What else was considered.** Keeping the 09-15 rulings as they are: existing product ids, no grace period, everything locked for a lapsed account.

**What it touches.** App Store Connect, Play Console, RevenueCat offerings, the paywall, the gate, a codes table, OneSignal, the legacy-grant run, mp-279, mp-280, mp-283, mp-286.

**Details.** Precisely:
1. Prices: $24.99 a month and $199.99 a year. Founding Month prices, 1 October to 30 November: $12.49 and $99.99. Each with the seven-day free trial. These are new product ids (me_pro_…), which reverses mp-279 clause 1. [to build]
2. Four products now (base and founding). The coach-discount products (15% and 30% off, 14-day trial) wait until mid-October because founding beats them until 30 November. [to build]
3. RevenueCat shows the founding offering to everyone during the window. It is switched on by hand on 1 October and off on 30 November. [to build]
4. A coach registers like anyone else and enters their own code. The server sees the code is theirs, marks the account as a coach and grants 30 days of access at once, so a coach never sees the paywall. Another 30 days when their first athlete pairs, then free for as long as five of their athletes are active. Through November this is done by hand in the RevenueCat dashboard. This answers mp-287 and replaces mp-286. [to build]
5. Every account that exists when the paywall switches on gets 30 days of granted access and founding-member status, announced by email a week before. This reverses mp-283. [to build]
6. An account with no access sees its data read-only with the paywall over it, rather than nothing at all. This adjusts mp-280. [to build]
7. On day five of the trial the app sends a push: the trial ends in two days, the price after, and how to cancel. It is scheduled on the phone at purchase, so it needs no server work. [to build]
8. Discount and coach codes are ours, in our own table. Apple's and Google's offer codes are not used. [to build, by 1 October]
9. Before any product is created, RevenueCat support is asked one question: one subscription group for all eight products, or a separate group for the discounted ones. [you or Xuan]
10. Cut order if time runs short: coach-discount products, then the coach cron, then giveaway grants, then the webhook-to-Mixpanel pipeline. Never cut: products, paywall, trial, the day-five reminder, the grace grant, Restore. [no work]
11. Every AI function checks the subscription on the server, not only the four Vana ones. Today a lapsed account holding bought credits can still call describe-meal, meal photo, the coach insight and the old chat. (mp-320) Moved here from mp-430 on 2026-09-21: it is paywall plumbing, not cost cutting. [to build]

You rejected mp-319 (store offers by script) on 09-17 and asked for the store setup to be done through the browser instead. Apple gives one introductory offer per subscription group per person, so a lapsed seven-day trial cannot later get the 14-day coach trial. All eight products in one group would let any subscriber switch to a founding price from Apple's own Manage Subscriptions screen; removing founding products from sale on 30 November closes that.

> 2026-09-20 proposed in the 09-20 clean-up; answers mp-287
> 2026-09-21 clause 11 moved in from mp-430 with Lee's yes in the terminal
> 2026-09-21 approved by Lee
> 2026-09-21 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-430 · Every account gets the same $4.00 monthly Vana budget, counted in real cost
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-430.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-430-2.svg
- screen: none (algorithm/data)
- source: docs/research/vana-cost-and-pricing.md (2026-09-17); dev cost audit 2026-09-20; Lee on the page 2026-09-17 rejecting mp-341
- work: pending
- linked: mp-320; mp-343; mp-344

**Context.** On 17 September Lee rejected mp-341 (one credit per action) and asked for a thorough look at cost and pricing: the most Vana we can give for the monthly price while keeping a healthy profit, and ways to cut cost. The research is in docs/research/vana-cost-and-pricing.md, re-measured on dev on 20 September. A planning message costs about 3.2 cents today, twice what mp-340 assumed; a typical athlete costs about $2.86 a month and a heavy one $6.85, falling to $1.64 and $3.93 after the cache fix. At Xuan's prices we keep $10.62 a month from a founding monthly subscriber and $7.08 from a founding annual one.

**Question.** How much Vana does a subscriber get each month, and what stops one account costing more than it pays?

**Decision.** Every account gets the same monthly budget of $4.00, measured in what its AI calls actually cost us; each call draws it down by its real cost, nothing counts messages or actions, and there is no daily cap. The athlete never sees dollars, only the share of the month used and the refill date in Vana settings. At 100% Vana stops and the top-up sheet opens; packs keep their prices and add budget, $1.00 for $4.99 and $5.00 for $19.99. Example: a typical athlete on the founding monthly plan ($12.49) uses about $1.64 after the cache fix, so their bar reads about 40%; the most any subscriber can cost us in a month is $4.00, against the $10.62 we keep.

**Why.** Lee on 21 September: a cap is on usage, what the account actually cost, never on how many times it spoke; no daily caps; one cap for the month, the same for every account, and the athlete can see their usage in Vana settings. With a cost budget no subscriber can cost more than $4.00, against $10.62 kept from a founding monthly plan and $7.08 from a founding annual one. Under 600 credits the worst case was $19.20 today.

**What else was considered.** One credit per action with 600 a month (the 09-20 proposal): it counts times spoken and leaves the worst case loose. Daily caps of 40 openers and 150 turns: ruled out by Lee. A hidden dollar ceiling behind visible credits (two meters). Showing dollars to the athlete.

**What it touches.** The wallet's unit and debit, the call log (every call needs its cost), the budget setting, the webhook grant, the top-up products' text, Vana settings, mp-281, mp-340, mp-341. The server subscription check moved to mp-429 clause 11; the cost work moved to mp-432.

**Details.** Precisely:
1. Every account gets the same monthly budget, measured in what its AI calls actually cost us. Each call draws the budget down by its real cost: a message to Vana, an opener, a described meal, a meal photo, a coach insight. Nothing counts turns or actions, and openers are no longer free. This replaces one credit per action. [to build]
2. The budget is $4.00 of model cost a month, one setting, the same for monthly, annual and founding plans. It covers a heavy user after the cache fix ($3.93) and a typical user spends about 40% of it. The figure is confirmed in the spec. [to build: one setting]
3. The trial week gets a quarter of the monthly budget, a week's share. More than half of cancelled trials cancel on day one. This amends mp-281 clause 3. [to build]
4. Unused budget does not roll over. Bought budget never expires, which Apple requires. (mp-281, unchanged) [built]
5. The monthly budget sits in the same wallet as bought budget and is spent first. Monthly plans refill on renewal. Annual plans refill each month on the anniversary day, checked when the app opens and before any AI call. A lapsed subscription forfeits what is left of the month; cancelling does not, until the period ends. This is mp-341's mechanism, live on dev; only the unit changes. Credits already in wallets convert at one fixed rate. [built; the unit is to build]
6. At 100% the athlete gets the top-up sheet and Vana stops (mp-282). Later, once a cheaper model passes the voice test, general chat carries on with it and only planning stops. [built; the fallback is later]
7. Top-up packs keep their prices and add budget, not credits: $4.99 adds a quarter of a month ($1.00) and $19.99 adds a month and a quarter ($5.00). Margin is 70% or better after the store's cut. The store text that names credits changes with it. [to build]
8. Vana settings shows the usage: a bar with the share of this month used, the refill date, and any bought extra. The athlete sees a percentage, never dollars. [to build]
9. There is no daily cap and no cap on turns or openers. The monthly budget is the only ceiling. A call is counted when it starts, so parallel requests cannot pass it. [to build]
10. The old free grant of 20 credits a month ends when the paywall opens. Free credits already in wallets stay. (mp-343) [to build]
11. When a subscription is transferred to another account the allowance stays where it was granted. Switching between monthly and annual grants nothing until the next refill. (mp-344) [built]

Dev, last 30 days, Haiku 4.5 through the Vercel AI Gateway (no markup): planning turn 21.3k tokens in, $0.032 average, $0.055 at p95; general turn about $0.011; planning opener $0.015; general opener $0.010; describe-meal (Sonnet 4.6) $0.007; meal photo $0.013; coach insight $0.002. Net after a 15% store cut: $24.99 -> $21.24, $12.49 -> $10.62, $199.99 a year -> $14.17 a month, $99.99 a year -> $7.08. Under the 09-20 proposal of 600 credits the worst case was $19.20 today and $6.96 after the cache fix; under the budget it is $4.00. Profiles are assumptions from 3 to 8 dev users; October traffic replaces them. Two wallet bugs to fix with the budget: the credit check passes when the database errors, and a balance that drains between check and debit serves one free call.

> 2026-09-20 proposed in the 09-20 clean-up; answers mp-320, mp-343, mp-344
> 2026-09-21 rewritten with Lee in the terminal: a monthly budget on real cost replaces credits per action and the daily caps; the server check moved to mp-429, the cost work to mp-432
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-432 · Cost work runs in six steps, logging first, and three savings wait
- category: Cutting costs
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-432.svg
- screen: none (algorithm/data)
- source: mp-430 clauses 12 and 13 (2026-09-20), moved here 2026-09-21 so cost cutting sits in one place
- work: pending
- linked: mp-420; mp-430

**Context.** mp-430 carried the list of cost work beside the monthly budget, and on 2026-09-21 Lee asked for cost cutting to sit in one place on the page. The research is in docs/research/vana-cost-and-pricing.md and the seven ai-cost files beside it; the build notes sit in the ai-cost folder of the scratch area. mp-465 later put off the last step of the list, the 50-meal test, and keeps meal logging on Sonnet.

**Question.** What is done to bring the cost of a Vana turn down, and in what order?

**Decision.** Six pieces of cost work, in this order: log what is missing, fix the prompt cache, the monthly budget (mp-430), send a replayed conversation exactly as it was first sent, let openers fetch their data before they call the model, then a 50-meal test to move meal logging off Sonnet to the cheapest model that passes. Three savings are not taken now: Apple's on-device model, the batch API, and sending simple prompts to a cheaper model before it passes a test of Vana's voice. Example: the cache fix alone takes a typical athlete from $2.86 a month to $1.64, while Apple's on-device model would save under 5% and cannot run a Vana turn at all, because it holds only 4,096 tokens.

**Why.** Most of the avoidable cost is our own code, not the model's price: a planning turn reads 43% of its input from the cache, and the fix takes a typical athlete from $2.86 a month to $1.64.

**What else was considered.** Leaving the list inside mp-430, where it sat under "Pro and paywall".

**What it touches.** The Vana functions, the call log, the opener path, meal logging's model, `.scratch/ai-cost/spec.md`.

**Details.** Precisely:
1. Cost work, in this order: log what is missing, the cache fix, the monthly budget (mp-430), byte-stable replay, openers that fetch their data before calling the model, then a 50-meal test to move meal logging off Sonnet to the cheapest model that passes. [to build]
2. Not doing now: Apple's on-device model (a 4,096-token window, cannot run a Vana turn, would save under 5%), the batch API (a day's delay breaks the next opener), and routing simple prompts to a cheaper model until it passes a test of Vana's voice (about 6%). [no work]

> 2026-09-21 split out of mp-430 with Lee's yes in the terminal
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-436 · What the athlete meets at the edge of the monthly budget
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-436.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-436-2.svg
- screen: none (algorithm/data)
- source: spec ai-cost 2026-09-21
- work: pending

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. mp-430 rules the monthly budget. It leaves three things an athlete would notice, and this card rules them.

**Question.** What happens to the call that crosses the budget, and to credits already in wallets?

**Decision.** A call that starts while there is budget left always finishes, even if it ends a few cents over; Vana never stops mid-answer, and the next call gets the top-up sheet. Credits already in wallets convert once at 2 cents each, the rate the packs imply. The app is never sent a dollar figure, only the share of the month used, the refill date and any bought extra. Example: an athlete with 2 cents left sends a planning message that costs about 3.2 cents, gets the whole answer, and their next message opens the top-up sheet; someone holding 250 credits from a $19.99 pack gets $5.00 of bought budget.

**Why.** Cutting Vana off mid-answer costs more goodwill than the few cents it saves. The pack rate is the only conversion under which nobody who paid for credits loses by the change.

**What else was considered.** Refusing a call whose estimate does not fit the remaining budget. Converting credits at the average cost of a call, which is lower than what a pack buyer paid.

**What it touches.** The wallet, the top-up sheet, Vana settings.

**Details.** Precisely:
1. A call that starts inside the budget finishes, even if it ends a few cents over. Vana never stops mid-answer. The next call gets the top-up sheet.
2. Credits already in wallets convert once at 2 cents a credit. That is the rate the packs imply: 50 credits were $4.99 and now add $1.00, 250 were $19.99 and now add $5.00.
3. The app is never sent a dollar figure. It gets the share of the month used, the refill date and any bought extra.

> 2026-09-21 proposed from the ai-cost spec
> 2026-09-21 cut down to its product rulings after Lee said implementation detail does not belong on the page
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-437 · When the fault is ours, the athlete sees "unavailable", never the top-up sheet
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-437.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-437-2.svg
- screen: none (algorithm/data)
- source: spec ai-cost 2026-09-21
- work: pending

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Each of our AI keys gets a hard monthly spending limit, so a runaway script cannot run up a bill. When a key reaches its limit the provider refuses calls with the same 402 status the app uses for an empty wallet.

**Question.** What does the athlete see when our own AI key has hit its spending limit?

**Decision.** Each of our AI keys has a hard monthly spending limit, and a key at its limit is refused with the same 402 ("payment required") an empty wallet gets. When that happens the athlete sees "Vana is unavailable right now", never the top-up sheet, because their own budget is not what ran out. The same message covers meal logging and the coach insight. Example: on 20 October our key reaches its monthly limit while an athlete with most of their budget left asks Vana a question; they see "Vana is unavailable right now" and are not offered a pack.

**Why.** The shared 402 handler shows the top-up sheet (mp-282). Without this rule an outage of ours would ask athletes to pay.

**What else was considered.** Letting the shared 402 handler show the top-up sheet.

**What it touches.** The shared 402 handler, the Vana sheet, the meal logging screens.

**Details.** Precisely:
1. The athlete sees "Vana is unavailable right now". The top-up sheet never appears for this, because the athlete's own budget is not what ran out.
2. The same message covers meal logging and the coach insight.

> 2026-09-21 proposed from the ai-cost spec
> 2026-09-21 cut down to its product rulings after Lee said implementation detail does not belong on the page
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-443 · The same conversation keeps its opener; a new conversation gets a new one
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-443.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-443-2.svg
- screen: none (algorithm/data)
- source: spec ai-cost 2026-09-21

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price.

**Question.** When does Vana draft a new opener, and when does the athlete see the one they already had?

**Decision.** Opening a conversation that already exists shows it as it was, including an opener nobody answered, and makes no model call. A new conversation always gets a new opener that Vana drafts, and New meal plan on the Plan tab always starts one. The launcher sheet and the Plan tab's Vana card reopen the day's conversation all day; the first sheet after midnight starts a new one. Example: an athlete opens the sheet at 07:00 on 3 October, Vana drafts an opener, and they close it without answering; at 12:00 they reopen it and see the same opener, with no model call, and the first sheet on 4 October starts a new conversation with a new opener.

**Why.** A code check on 2026-09-21 found the app already works this way: the day's conversation id is kept on the phone and the transcript is read back from the server, so reopening costs nothing. The 30-minute reuse solved a problem that was not there.

**What else was considered.** Showing an unanswered opener again for 30 minutes, or for the day, from a server-side store. A daily cap on openers, which Lee ruled out.

**What it touches.** Nothing new. The sheet controller and the day's conversation pointer already do this.

**Details.** Precisely:
1. Opening a conversation that already exists shows it as it was, the unanswered opener included. No model call is made. This is a rule of the app, not of the server. [built]
2. A new conversation always gets a new opener, drafted by Vana. "New meal plan" on the Plan tab always starts a new conversation. [built]
3. The launcher sheet and the Plan tab's Vana card reopen the day's conversation for the whole day. The first sheet after midnight starts a new one. [built]
4. No opener is stored for reuse, none is templated (mp-007, mp-008), and no timer decides anything. [no work]

> 2026-09-21 proposed from the ai-cost spec
> 2026-09-21 amended by Lee
> 2026-09-21 rewritten with Lee in the terminal: the rule is per conversation, not per timer; nothing to build
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-452 · Four new products on each app, all in the one Mealvana Pro group
- category: Spec
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-452.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-452-2.svg
- screen: none (store setup)
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. What is built today sells the old monthly and annual products. This card is the Products paragraph in the spec's Implementation Decisions.

**Question.** Which subscriptions do the stores sell, and how are they set up?

**Decision.** Four new subscriptions on each store and each app, each with the seven-day free offer: monthly at $24.99, annual at $199.99, and founding monthly at $12.49 and founding annual at $99.99. A script makes them through the Apple and Google APIs, all four go into the existing "Mealvana Pro" group and count as `pro`, and the founding two come off sale on 30 November. The old monthly and annual products leave every Offering and are never sold again. Example: an athlete subscribing on 1 October can take the monthly plan at $12.49; one subscribing after 30 November can only take $24.99 a month or $199.99 a year.

**Why.** Apple refuses a product id that another app in our team already holds, which is why the production app sells its own copies of each id today. Store setup by script was rejected on 17 September (mp-319); this card replaces that ruling. One group keeps upgrades simple, and taking the founding products off sale closes the leak of subscribers switching onto them.

**What else was considered.** Separate groups for the founding products, waiting on RevenueCat's answer with no deadline.

**What it touches.** App Store Connect, Play Console, RevenueCat products and offerings, the webhook's product list.

**Details.** Precisely:
1. Four products on each store and each app: monthly $24.99, annual $199.99, founding monthly $12.49, founding annual $99.99, each with the seven-day introductory offer. They are created through the App Store Connect and Google Play APIs with the scripts in `scripts/store`, replacing the 09-17 ruling that store setup is done by hand (mp-319).
2. The dev app sells `me_pro_monthly`, `me_pro_annual`, `me_pro_monthly_founding` and `me_pro_annual_founding`. The production app sells the same ids ending in `_prod`.
3. All four go into the existing "Mealvana Pro" subscription group on each app and attach to `pro`. RevenueCat support is not asked; this reverses mp-429 clause 9. The founding products come off sale on 30 November.
4. The old monthly and annual products leave every offering and are never sold again.
5. The webhook's fallback list of `pro` product ids gains the eight new ids.

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 amended by Lee
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, why, details)

## mp-453 · The paywall sells the Offering marked current, with founding prices beside the struck-through regular ones
- category: Spec
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption: The paywall as built on 09-15, before this spec
- svg2: docs/ssot/decisions/images/mealplanning/mp-453-2.svg
- screen: Paywall
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October at Xuan's prices, with the Founding Month running to 30 November, and the store submission goes in around 25 September. Until now the paywall read one fixed Offering, the regular one, so Xuan switching the current Offering in RevenueCat's dashboard would change nothing on screen. This card is the "What the paywall shows" paragraph in the spec's Implementation Decisions.

**Question.** Which plans does the paywall show, and how does a founding price look?

**Decision.** The paywall shows whichever Offering is marked current in RevenueCat, so the switch to the Founding Month plans on 1 October and back after 30 November needs no app release. While the founding Offering is current, each plan shows its founding price, the matching regular price struck through beside it, and a "Founding member" line; otherwise it shows the plain price. Every price and the trial line come from the store, the words come from the content system, and the paywall always carries the trial terms, the price after the trial, and links to terms and privacy. Example: on 1 October the monthly plan reads $12.49 with $24.99 struck through and "Founding member"; after the switch back it reads $24.99.

**Why.** Xuan's spec makes the switch a manual dashboard flip with no date logic in the app. Review rejections on first subscriptions are mostly about missing trial terms and links.

**What else was considered.** A date check in the app; keeping the fixed `default` id and renaming offerings on the day.

**What it touches.** The paywall screen, the paywall controller, the subscription service, the content system.

**Details.** Precisely:
1. The paywall reads RevenueCat's Current Offering, not a fixed id. Switching to `founding` on 1 October and back to `default` after 30 November needs no release.
2. While the current offering is `founding`, each plan shows the founding price, the matching `default` price struck through beside it, and a "Founding member" line. While it is `default`, it shows the plain price.
3. Every price and the trial line come from the store. The copy lives in the content system.
4. The paywall carries the trial terms, the price after the trial, and links to terms and privacy.

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-454 · The webhook writes RevenueCat's own expiry, so grants reach the server
- category: Spec
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-454.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-454-2.svg
- screen: none (algorithm/data)
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October at Xuan's prices, and anyone given free access by hand is still refused by the server today, because the server never hears about a Grant. RevenueCat sends a Grant as a one-off promotional purchase that it labels as production even when it comes from Sandbox, and the webhook ignored that event for `pro`. This card is the webhook paragraph in the spec's Implementation Decisions.

**Question.** How does a Grant reach the server, and which end date wins when a Grant and a subscription overlap?

**Decision.** Every event about `pro`, bought or granted, updates the Entitlement row. On each one the webhook asks RevenueCat for the customer's Expiry and writes that; RevenueCat already takes the later of a Grant and a subscription. The webhook never drops an event because of which environment it says it came from. Example: an athlete on Legacy grace to 31 October starts a Trial on 5 October that ends on 12 October; RevenueCat still answers 31 October, so the row keeps 31 October and the Trial does not cut the grace short.

**Why.** Legacy grace, free access for coaches and giveaways are all Grants. Without this the app opens (the phone sees the Grant) and every AI call is refused. Writing the event's own end date would let a Trial started during Legacy grace cut the grace short.

**What else was considered.** A third column for the grant's end, which reverses mp-317; mapping each event's expiry and taking the later of the two by hand.

**What it touches.** The `revenuecat-webhook` function and its environment, the entitlement row.

**Details.** Precisely:
1. Every event for `pro`, bought or granted, updates the row.
2. On each one the webhook asks RevenueCat's REST API for the customer's current `pro` expiry and writes that as active until. RevenueCat already takes the later of a grant and a subscription.
3. The row keeps the two fields and the event time (mp-317). The webhook never filters by environment.
4. The function holds a RevenueCat secret API key.

RevenueCat sends a grant as a `NON_RENEWING_PURCHASE` with store and period type `PROMOTIONAL` and environment `PRODUCTION`, even from sandbox.

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-455 · Legacy grace goes out in one script run at the Flip, and old anonymous installs claim it by signing up
- category: Spec
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-455.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-455-2.svg
- screen: none (algorithm/data)
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October, and a person who has used the app for months would be locked out on the first launch of the new build. mp-429 clause 5 gives every existing account 30 days and founding-member status. This card is the grace paragraph in the spec's Implementation Decisions.

**Question.** How does every existing account get its 30 days of Legacy grace, including installs that never made an account?

**Decision.** At the Flip a script gives 30 days of `pro` through RevenueCat to every registered account created before it, and marks each one as a founding member. Unless run with an explicit flag it only lists who would get it and how many; it skips anyone who already holds a Grant, and it runs on dev first and on production only with Lee's go. An install still anonymous (signed in with no account behind it) is sent to the account screen when it opens the new build; signing up keeps its data, and a server function gives the same 30 days if it predates the Flip and has no Grant yet. Example: with the Flip on 1 October, Lee reads the list first, then runs the script with the flag, every account made before the Flip holds `pro` to 31 October, and a second run gives nobody anything.

**Why.** Xuan's spec: a one-time loop at flip, and anonymous installs claim grace by registering. The dry run lets Lee see who gets it before anyone does.

**What else was considered.** Granting from the app on first launch, which would let a client decide its own access.

**What it touches.** A script under `scripts/`, a grace-claim function, the account screen, RevenueCat.

**Details.** Precisely:
1. On flip day a script grants 30 days of `pro` through RevenueCat's REST API to every registered account created before the flip, and sets a `founding_member` subscriber attribute.
2. It is a dry run by default: it prints the accounts and the count, and writes only with an explicit flag. It skips an account that already holds a grant, so a second run does nothing.
3. It runs on dev first, then production with Lee's go.
4. An install still anonymous when it opens the new build goes to the account screen. Sign-up links onto that anonymous user so the data survives, and a server function grants the same 30 days when the anonymous user predates the flip and has no grant yet.
5. That link is the only place the app still meets an anonymous user. It never starts one.

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-456 · The day-five reminder is a local notification set at purchase
- category: Spec
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-456.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-456-2.svg
- screen: none (notification)
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October, and nobody warns a trialist before the first charge today. Xuan calls the day-five reminder non-negotiable, scheduled on the phone with no webhook. Her spec names OneSignal, whose client cannot schedule a push. This card is the reminder paragraph in the spec's Implementation Decisions.

**Question.** What warns an athlete before the first charge of a Trial, and when?

**Decision.** The phone itself. When a purchase starts a Trial, the app schedules a local notification (one the phone raises with no server involved) for 10:00 local time two days before the Trial ends, saying it ends in two days, the price after from the store, and that they can cancel any time. Tapping it opens the store's subscription page, the words live in the content system, and if the app opens and RevenueCat says the Trial will not renew, the notification is cancelled. Example: a Trial that ends on 8 October gets its reminder at 10:00 on 6 October; if the athlete cancelled on 4 October and opened the app since, no reminder comes.

**Why.** A local notification needs no server and works offline, which is what Xuan's "client-side, no webhook" asks for. Cancelling on a known non-renewal keeps it from nagging someone who already cancelled.

**What else was considered.** A OneSignal push sent from the server off the webhook, which Xuan ruled out for Phase 1.

**What it touches.** The notification service, the paywall controller, the content system.

**Details.** Precisely:
1. When a purchase starts an introductory trial, the phone schedules a local notification through the existing notification service.
2. It fires at 10:00 local time two days before the trial ends: the trial ends in two days, the price after from the store, and they can cancel any time.
3. Tapping it opens the store's subscription page.
4. When the app opens and RevenueCat says the trial will not renew, the notification is cancelled.
5. The text lives in the content system.

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-457 · An account whose Pro ran out opens read-only; one that never had it stays on the paywall
- category: Spec
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption: The paywall as built on 09-15, before this spec
- svg2: docs/ssot/decisions/images/mealplanning/mp-457-2.svg
- screen: Paywall
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October, and the built gate blocks every screen for anyone without access. mp-429 clause 6 and the amended mp-280 give a lapsed account its data read-only with the paywall over it. This card is the "Three gate states" paragraph in the spec's Implementation Decisions.

**Question.** How does the app tell an account whose Pro ended from one that never had it, and what does read-only mean?

**Decision.** The Gate gives one of three answers: open (Pro is live, or the account is an Admin), lapsed (the account held `pro` once and it has run out) or never (it never held `pro`). Never lands on the paywall and stays there. Lapsed opens the app read-only: every screen carries a bar saying the plan has ended, with a Subscribe button, and any edit or AI action opens the paywall instead of running; one check says whether writes are allowed, every write asks it first, and the server refuses AI calls for such an account on its own. Example: an athlete's Trial ends on 8 October unpaid; on 9 October they can still read their plan, but tapping to change it or to ask Vana opens the paywall.

**Why.** A new account has no data to show, so read-only only means something for a lapsed one. One provider checked in the controllers keeps the rule in one place instead of on every button.

**What else was considered.** Disabling each edit control on each screen; a separate read-only viewer with its own routes.

**What it touches.** The gate, the router redirect, the app shell, every write controller.

**Details.** Precisely:
1. The gate answers open (the entitlement is active, or the account is an admin), lapsed (the customer held `pro` once and it has expired) or never (no `pro` ever).
2. Never lands on the paywall and stays there.
3. Lapsed opens the app read-only. Every screen carries a bar saying the plan has ended, with a Subscribe button. Any edit or AI action opens the paywall instead of running.
4. One write-access provider says whether writes are allowed, and every write controller checks it before writing.
5. The server refuses AI calls for a lapsed account on its own (mp-429 clause 11).

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-458 · Codes are ours: a coach's own Code gives 30 days, a giveaway Code a year, redeemed on our server
- category: Spec
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption: The paywall as built on 09-15, before this spec
- svg2: docs/ssot/decisions/images/mealplanning/mp-458-2.svg
- screen: Paywall
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October, and a coach has to pay today to see what their athletes see. mp-429 clauses 4 and 8 put coaches in through their own code and keep every code in our own table. This card is the Codes paragraph in the spec's Implementation Decisions.

**Question.** Where do Codes live, who can use one, and what does each kind do?

**Decision.** Codes are kept in our own table, each with its kind (coach, influencer or giveaway), its owner, the dates it is valid and what it gives, and only a signed-in account can redeem one, through a server function. A coach entering their own Code is marked as a coach and gets 30 days of `pro`; an athlete entering a coach or influencer Code has that Code recorded on their RevenueCat customer and gets a pending pairing with the coach; a giveaway Code gives 365 days of `pro`, once; a wrong, expired or used Code gets a plain reason back. Codes are entered from a "Have a code?" link on the Onboarding paywall and a row in Settings, and the 24-hour pairing codes stay as they are. Example: a coach enters her own Code and gets `pro` for 30 days; her athlete enters the same Code and a pending pairing with her appears; a giveaway winner gets 365 days, and entering that Code again gets a plain reason back.

**Why.** Xuan's spec: codes are ours, not the stores', and a coach is recognised by entering their own code. A server function keeps grants away from the client.

**What else was considered.** Apple and Google offer codes, which Xuan ruled out; reusing the 24-hour pairing codes, which expire too fast to print on a flyer.

**What it touches.** A `codes` table and migration, a `redeem-code` function, the paywall, Settings, the coach pairing service, RevenueCat.

**Details.** Precisely:
1. A `codes` table holds each code with its type (coach, influencer or giveaway), its owner, its validity window and its perk.
2. A `redeem-code` function takes a code from a signed-in caller only.
3. The owner of a coach code entering it marks the account as a coach and gets 30 days of `pro`.
4. An athlete entering a coach or influencer code gets `coach_code` or `influencer_code` set as a subscriber attribute and a pending pairing with the coach through the existing pairing path.
5. A giveaway code grants 365 days of `pro`, once.
6. A wrong, expired or used code gets a plain reason back.
7. The entry is a "Have a code?" link on the onboarding paywall and a row in Settings. The existing 24-hour pairing codes stay as they are.

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-459 · Onboarding keeps its answers on the phone until the account exists
- category: Spec
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-459.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-459-2.svg
- screen: none (flow)
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October. Today the welcome screen starts an anonymous session and onboarding saves its answers under it; Lee ruled on 2026-09-21 that there are no anonymous users any more (mp-417). This card is the onboarding paragraph in the spec's Implementation Decisions.

**Question.** Where do onboarding answers wait before the account exists?

**Decision.** On the phone. The welcome screen no longer starts an anonymous session (a sign-in with no account behind it); onboarding answers are held on the phone and written to the account when it is made. The anonymous-session code in sign-in, onboarding and settings is archived, except the link that lets an old install keep its data when it signs up (mp-455). Example: an athlete answers every onboarding question, then signs up, and only at that moment are her answers written, to her new account.

**Why.** With no anonymous session, the only place the answers can wait is the phone, and the account is made moments later.

**What else was considered.** Keeping the anonymous session as hidden plumbing, which Lee rejected.

**What it touches.** The welcome screen, the onboarding service and controller, the auth services, the post-onboarding account screen, settings.

**Details.** Precisely:
1. The welcome screen no longer starts an anonymous session.
2. Onboarding answers are held on the phone until the account exists and are written to it then.
3. The anonymous-session code in auth, onboarding and settings is archived, except the link for old installs (mp-455).

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-460 · The store build carries what cannot be cut; read-only mode, Codes and account-only onboarding follow before 8 October
- category: Spec
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-460.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-460-2.svg
- screen: none (release plan)
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October, and the store submission has to go in around 25 September to leave room for one rejection. The first trial can end on 8 October. This card is the "What ships when" paragraph in the spec's Implementation Decisions.

**Question.** What goes into the build sent on 25 September, and what can wait for an update?

**Decision.** The store build (the one sent to Apple and Google around 25 September) carries the new products, the paywall showing the Offering marked current with founding styling, the day-five reminder, the webhook fix and the server's subscription check on every AI function, and the Legacy grace script runs on 1 October. Read-only mode for an account whose Pro ended, Codes, and onboarding without an anonymous session follow in an update before 8 October; until then such an account meets the paywall as it does today. If time runs short, cut from the bottom of that update, never from the store build. Example: the first Trial, started on 1 October, cannot end before 8 October, and Legacy grace covers existing accounts to 31 October, so before the update only someone who cancels can lose Pro.

**Why.** Xuan's never-cut list is the store build. No one can be lapsed before 8 October except by cancelling, and the grace month covers existing accounts to 31 October.

**What else was considered.** One build with everything, which would not reach review by 25 September.

**What it touches.** The ticket order, the store submission, the release checklist.

**Details.** Precisely:
1. The store build carries the new products, the Current Offering paywall with founding styling, the day-five reminder, the webhook fix and the server check on every AI function.
2. The grace script runs on 1 October.
3. Read-only lapsed mode, codes and onboarding without an anonymous session follow in an update before 8 October. Until then a lapsed account meets the paywall as it does today.
4. If time runs short, cut from the bottom of that update, never from the store build.

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-461 · The server's functions are tested whole, through their real handlers, with fakes around them
- category: Spec
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-461.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-461-2.svg
- screen: none (tests)
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October, and anyone given free access by hand is still refused by the server today. This card is the server seam in the spec's Testing Decisions.

**Question.** Where are the webhook, Code redemption and the Legacy grace claim tested?

**Decision.** Through each function's real request handler, with fake RevenueCat events, a fake RevenueCat server and a fake database, the way the webhook's tests already feed it fake events. The cases: a promotional Grant opens the Entitlement row; a Trial started during Legacy grace keeps the grace end; a lapsed Trial leaves a live Grant open; each kind of Code and each refusal; and the grace claim grants once, and only for an account that predates the Flip. The grace script picks its accounts with the same function the claim uses, so it is tested there. Example: a fake event says a Trial ended on 12 October while a Grant runs to 31 October, and the test checks the row stays open to 31 October.

**Why.** The handler is the highest seam that runs without a network; each function already takes its dependencies as one object, so nothing lower needs its own test.

**What else was considered.** Testing each helper on its own, which tests how it is built rather than what it does.

**What it touches.** `revenuecat-webhook` tests, new function tests.

**Details.** Precisely:
1. Through their real handlers, with fake RevenueCat events, a fake RevenueCat REST client and a fake database, the way the webhook's tests feed fake events today.
2. Cases: a promotional grant opens the row; a trial started during grace keeps the grace end; a lapsed trial leaves a live grant open; each code type and each refusal; the grace claim grants once and only for an account that predates the flip.
3. The grace script's selection is the same function the claim uses, tested there.

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-462 · The Gate and the paywall are tested through the real code behind them, with a fake store and scheduler
- category: Spec
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-462.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-462-2.svg
- screen: none (tests)
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October at Xuan's prices, and the built gate knows only open and locked. This card is the client seam in the spec's Testing Decisions.

**Question.** Where are the Gate's answers, the founding prices and the reminder tested?

**Decision.** Through the real Gate and paywall notifiers (the code that holds each screen's state and rules), with a fake subscription service and a fake notification scheduler, as their tests work today. The cases: open, lapsed (held `pro` once, now ended) and never, from fake customer details; the founding Offering shows both prices and the regular one a single price; a purchase that starts a Trial schedules the reminder at the right time, and a Trial that will not renew cancels it; a write while lapsed opens the paywall instead of writing. Example: fake customer details describe an account that held `pro` once and lost it; the test checks the Gate answers lapsed, and that saving a change opens the paywall and writes nothing.

**Why.** The notifiers are where the rules live and the existing tests already drive them; a widget test would add the screen without adding a rule.

**What else was considered.** Golden tests of each paywall state, kept only for the founding look.

**What it touches.** Subscription feature tests, the notification service's scheduler interface.

**Details.** Precisely:
1. Through the real gate and paywall notifiers, with a fake subscription service and a fake notification scheduler, the way the gate and paywall controller tests work today.
2. Cases: open, lapsed and never from fake customer info; the founding offering shows both prices and the default offering one; a purchase that starts a trial schedules the reminder at the right time, and a trial that will not renew cancels it; a write while lapsed opens the paywall instead of writing.

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-463 · Claude checks the stores and RevenueCat through their APIs; a person runs only what needs a real phone
- category: Spec
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-463.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-463-2.svg
- screen: none (tests)
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October, and no agent can buy from a store. The sandbox run on both stores is already the release gate (mp-289). This card is the stores paragraph in the spec's Testing Decisions.

**Question.** What is checked on the real stores before the paywall ships, and by whom?

**Decision.** The Sandbox run on both stores stays the gate for every release. Claude checks everything that needs no phone, through the App Store Connect, Google Play and RevenueCat APIs and the signed-in browser: the products, prices and free-week offers on both stores, the founding Offering holding the founding products, a hand-granted account showing `pro` in RevenueCat, and the webhook having written that account's row. A person runs only what needs a real phone, and no CI job runs any of it. Example: Claude confirms the founding products sit in the founding Offering; then a person buys through that Offering in Sandbox, moves the phone's clock forward to see the day-five reminder arrive, and taps Restore purchases.

**Why.** Store prices, intro offers and grants only exist on the stores and in RevenueCat; the fakes in the other seams cannot prove them.

**What else was considered.** Leaving the run as it is, which would ship founding prices and grants untested.

**What it touches.** `scripts/sandbox-trial-wizard.sh`, `docs/release/sandbox-trial-runs/`.

**Details.** Precisely:
1. The sandbox run on both stores stays the release gate.
2. Claude runs every check that needs no phone, through the App Store Connect, Google Play and RevenueCat APIs and the signed-in browser: the products, prices and free-week offers exist on both stores; the founding offering holds the founding products; a hand-granted account shows `pro` in RevenueCat; the webhook wrote that account's row.
3. A person runs only what needs a real phone: the sandbox purchase through the founding offering, the day-five reminder arriving on a device with its clock moved on, and Restore.
4. No CI job runs any of it.

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 amended by Lee
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-464 · A chip with one fixed meaning acts at once, with no model turn
- category: Cutting costs
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-464.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-464-2.svg
- screen: none (algorithm/data)
- source: spec ai-cost 2026-09-21; Lee in the terminal 2026-09-21
- work: pending

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Every chip in a planning conversation is sent to Vana as a typed message today, so one tap costs a full planning turn of about 21,000 tokens. For many chips the next step is already fixed: the same tool, with arguments the app already holds. Several of these actions already exist on the endpoint that runs no model and are not wired to the chip. The spec first said to log taps for two weeks and then decide; Lee rejected the wait on 2026-09-21.

**Question.** Which chip taps skip the model, and what does the athlete see when one does?

**Decision.** Chips, the tappable answers under Vana's messages, whose next step is already fixed, such as "Other options", "Draft my whole week", "Same as last time" and "Open shopping list", now do that step straight away without calling the model; "I like these" and "Next: <meal type>" do so only when the next step is simply the next meal type's picker. The result appears with no line from Vana and nothing templated in her voice; the tap is stored in the conversation so she sees it on her next turn, and it draws nothing from the monthly budget. Chips Vana named herself, "Different protein", "Adjust", every opener and every typed message still go to her, and the call log records tap or typed for every turn. Example: an athlete taps "Other options" under a dinner picker; today that costs a full planning turn of about 21,000 tokens, now the next picker appears at once with no line from Vana and draws nothing from their monthly budget.

**Why.** "Other options" is the most tapped chip and its picker is fully decided by the tap; paying a planning turn for it buys one sentence. The athlete gets the picker faster.

**What else was considered.** Logging taps for two weeks before deciding, which Lee rejected. A short written line from a small model call after each of these taps, which still costs a call and can be added later if the silence reads as cold. A canned line in Vana's voice, ruled out by mp-007 and mp-008.

**What it touches.** The picker chips, the choice chips, the chat controller, the no-model action endpoint, the persona's chip instructions, the call log.

**Details.** Precisely:
1. These chips act at once with no model turn: "Other options", "Draft my whole week", "Same as last time", "No recipe only", "Under 20 min", the batch-cooking answer, the coverage answer ("Dinners only", "Dinners and lunches", "Every meal"), "Open shopping list", "Lay it across the week", "Use what I have", and "Use these" on the pantry card. [to build]
2. "I like these" and "Next: <meal type>" act at once when the next step is simply the next meal type's picker. When the next step is a question or the wrap-up, the tap goes to Vana as it does today. [to build]
3. The result arrives with no written line from Vana. Nothing is templated in her voice. She speaks again on the next turn that reaches her. [to build]
4. The tap and what it produced are stored in the conversation, so Vana sees them on her next turn. [to build]
5. These taps draw nothing from the monthly budget (mp-430). [to build]
6. Still Vana's: chips she named herself, "Different protein", "Adjust", every opener and every typed message. [no work]
7. The call log records tap or typed for every turn, so the saving is measured. [to build]

Already on the no-model endpoint today: picking a meal, Show more, Browse, accepting a rule, Undo, Confirm, the fridge scan. "Same as last time" and the two settings are implemented there and unused by the chips. "Different protein" stays with Vana because it needs a choice of which protein.

> 2026-09-21 proposed with Lee in the terminal, replacing the spec's two-week wait
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-465 · Which model does which job: chat on Haiku, meal logging on Sonnet, small jobs on the cheapest
- category: Cutting costs
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-465.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-465-2.svg
- screen: none (algorithm/data)
- source: spec ai-cost 2026-09-21; Lee in the terminal 2026-09-21
- work: pending
- linked: mp-432

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. mp-432 clause 1 (approved) ends its list with a 50-meal test that moves meal logging off Sonnet to the cheapest model that passes. Lee on 2026-09-21 rejected the model moves ("let's stay with haiku for now"), said meal logging stays on Sonnet, and asked which jobs could truly run on the cheapest model. This card reverses that last step of mp-432 clause 1; the rest of mp-432 stands.

**Question.** Which model runs which job, and which jobs move to the cheapest one?

**Decision.** Vana's conversation and openers stay on Haiku 4.5, and the described meal and the meal photo stay on Sonnet; the 50-meal test and the move of meal logging off Sonnet are not built now. Three background jobs move to the cheapest model in the gateway's catalogue that gives the same structured answer on 20 stored dev conversations, checked by hand: the Extraction when a conversation goes idle, the rolling conversation summary, and the ingredient list for a saved meal. Day notes stay on Haiku, the Formula Kit coach insight's route is removed because nothing in the app calls it, and no helper model is called from inside a Vana turn for now. Example: the Extraction averages 33 tokens out, so a cheaper model there changes nothing the athlete reads; the 50-meal test Lee put off was worth about 40 to 57 cents per athlete a month.

**Why.** The three background jobs return small structured answers (the extraction averages 33 tokens out), so a wrong word costs nothing the athlete sees. Together they are a few cents per athlete a month: worth one small ticket, not a project. The real money is in the chat turn's input, which the cache fix, the compact tool results and the chip taps (mp-464) cut.

**What else was considered.** The 50-meal truth set for meal logging, about 40 to 57 cents per athlete a month, which Lee put off. Helper models called by the chat model: the SDK allows a tool to call a second model, and nothing in the code does it today. It does not cut cost here, because a Vana turn costs what it reads (about 21,000 tokens a step), not what it does, and a helper adds a call on top. The pantry photo on a cheap vision model, left alone until the limiter covers it.

**What it touches.** The extraction, summary and saved-ingredients modules, the model settings, the coach insight function.

**Details.** Precisely:
1. Vana's conversation and openers stay on Haiku 4.5. [no work]
2. The described meal and the meal photo stay on Sonnet. The 50-meal test and the move off Sonnet are not built now. [no work]
3. Three background jobs that write no words the athlete reads move to the cheapest model in the gateway's catalogue that returns the same structured answer on 20 stored dev conversations, checked by hand: the memory extraction when a conversation goes idle, the rolling conversation summary, and the ingredient list for a saved meal. [to build]
4. The Formula Kit coach insight has no caller in the app. Its route is removed instead of moved to a cheaper model. [to build]
5. Day notes stay on Haiku. They are in Vana's voice, and the saving there is running them less often, which the spec already covers. [no work]
6. No helper model is called from inside a Vana turn for now. [no work]

Each of the three jobs already has a seam where the model is passed in, and one setting names their model today (Haiku 4.5). Embeddings are already the cheapest call in the system (about $0.0000003 each) and stay.

> 2026-09-21 proposed with Lee in the terminal; reverses the last step of mp-432 clause 1
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-466 · Ticket 01: No endpoint works without a signed-in caller
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-466.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 01
- depends: mp-432

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. First of 14. It has no blockers and runs beside tickets 02 and 03.

**Question.** Is closing the two open endpoints, and undeploying the parser nobody has source for, one slice with no blockers?

**Decision.** Nobody outside the app can send a plan email or write an athlete's data. The plan-email function refuses a caller who is not signed in. The bulk upload keeps working for released app versions but writes only to the signed-in athlete's own account. The meal-plan parser on dev, which has no source in the repo, is gone. Dev only; production waits for Lee's go.

**Why.** Three small fixes of the same kind in functions nothing else in this batch touches. One context window, checked with three requests.

**What else was considered.** One ticket per endpoint, too small to be worth a wave slot each. Deleting the bulk upload, not taken because released versions may still call it.

**What it touches.** supabase/functions/send-nutrition-plan-email, supabase/functions/upload-all-data, supabase/config.toml

**Details.** 
- [ ] An unsigned request to the plan-email function gets 401 and sends nothing (test through the handler); a signed-in request still sends.
- [ ] The bulk upload takes the user id from the token and ignores any user id in the body (handler test with a body naming another user).
- [ ] `parse-meal-plan` is undeployed from dev.
- [ ] The ticket lists every function under `supabase/functions/` that calls a model, sends mail or writes with the service role, with its auth check.
- [ ] Deployed to dev. Nothing is deployed to production.

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-467 · Ticket 02: A hard budget on every gateway key, and "unavailable" when the fault is ours
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-467.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 02
- depends: mp-437

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Second of 14. No blockers. It pins the AI SDK version for every function, so the server tickets after it (04 to 09, 11 to 14) wait for it.

**Question.** Is the gateway work (keys, budgets, the unavailable message) the right home for pinning the SDK, and should every later server ticket wait on it?

**Decision.** Three gateway keys exist (production, dev, evals and build agents) with monthly budgets of $150, $40 and $25 that hard-stop, each with an alert before the cap. When the gateway refuses us, the athlete sees "Vana is unavailable right now" and never the top-up sheet. Every function imports one exact version of the AI SDK.

**Why.** The pin is a one-line change per file that every later ticket builds on, so it goes first with the smallest ticket that already edits the model settings.

**What else was considered.** A separate pin-only ticket, which would hold the same wave slot for ten minutes of work. Lee creating the keys by hand, which he asked not to do.

**What it touches.** supabase/functions/_shared/vana/env.ts, supabase/functions/_shared/ai/model.ts, supabase/functions/_shared/vana/chat.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/extract.ts, supabase/functions/_shared/vana/daynotes.ts, supabase/functions/_shared/vana/pantry.ts, supabase/functions/_shared/vana/saved-ingredients.ts, supabase/functions/_shared/vana/embeddings.ts, supabase/functions/describe-meal/index.ts, supabase/functions/analyze-meal-photo/index.ts, lib/features/meal_planning/data/vana_exceptions.dart, lib/features/meal_planning/data/vana_transport.dart, lib/features/ai_credits/presentation/insufficient_credits_handler.dart, scripts/vana-eval

**Details.** 
- [ ] Three keys exist in Vercel with the three budgets and an alert each, created in Lee's signed-in session. If the permission check blocks creating a secret, the form is left filled in and Lee presses the button.
- [ ] The dev key is set as the dev function secret; the evals key is what `scripts/vana-eval` uses. The production key is created and not deployed.
- [ ] A gateway refusal (stubbed 402 from the gateway) surfaces as "Vana is unavailable right now" from the content system, never the top-up sheet and never a crash (handler test, and a widget test through the real chat controller).
- [ ] Every `npm:ai` import names one exact version.
- [ ] The default chat model id uses the gateway catalogue's spelling; one dev call confirms it resolves.

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-468 · Ticket 03: Nothing calls the server before the athlete opens the Food tab
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-468.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 03
- depends: mp-432

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Third of 14. Client only, no blockers, runs beside 01 and 02.

**Question.** Is the launch fix a slice of its own, apart from the wallet channel?

**Decision.** The app opens without building the Food tabs. The first Vana request happens when the athlete first opens Food. A tab that has been visited keeps its state.

**Why.** Two files, one widget test that counts calls. It touches nothing the server tickets touch, so it can land in the first wave.

**What else was considered.** Folding it into the budget screen ticket with the wallet channel, which would make it wait for the whole budget.

**What it touches.** lib/shared/widgets/tabs_screen.dart, lib/features/meal_planning/presentation/screens/food_screen.dart

**Details.** 
- [ ] No Vana request fires between launch and the first visit to the Food tab (widget test over a transport that counts calls).
- [ ] A visited tab keeps its scroll position and state when the athlete leaves and returns.
- [ ] Checked on a pool simulator: cold launch to Home shows no Vana call in the log.

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-469 · Ticket 04: Guardrails: no free turn, and a limiter that cannot be raced
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-469.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 04
- blocked: 02
- depends: mp-430, mp-432

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Fourth of 14, after the SDK pin. It is the first of the tickets that change the chat turn, which then run one after another (04, 05, 06, 07).

**Question.** Are the empty-message hole, the in-flight limiter and the token ceiling one slice?

**Decision.** A request with an empty message runs nothing and stores nothing. Five requests fired at once against a limit of four let four through. The pantry photo, the described meal and the meal photo share the same per-minute limiter as chat. A single turn cannot run past a token ceiling. There is no daily cap and no cap on turns.

**Why.** All four close a way to spend without limit and all sit on the same limiter module and the top of the chat handler.

**What else was considered.** Putting the limiter inside the budget ticket; the budget is already the largest ticket. The 09-20 draft's daily caps, which Lee ruled out.

**What it touches.** supabase/functions/_shared/vana/rate-limit.ts, supabase/functions/_shared/vana/chat.ts, supabase/functions/vana-chat/index.ts, supabase/functions/_shared/vana/actions.ts, supabase/functions/describe-meal/index.ts, supabase/functions/analyze-meal-photo/index.ts, assets/config/content_defaults.json

**Details.** 
- [ ] A chat request with a conversation id and an empty message returns 400, runs no model and stores no row (handler test).
- [ ] The limiter writes the call row before the model runs: five parallel calls against a limit of four let four through (test).
- [ ] The limiter stays in the shared Vana rate-limit module on the server; the pantry photo, the described meal and the meal photo call that module. Nothing moves to the phone.
- [ ] A turn stops at a per-turn token ceiling as well as its step limit.
- [ ] The refusal text comes from the content system.
- [ ] No daily cap and no turn counter is added (mp-430).

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-470 · Ticket 05: The call log can say what every athlete costs
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-470.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 05
- blocked: 02, 04
- depends: mp-420, mp-464

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Fifth of 14. The budget (09) needs the gateway's charge in the log, and the chip tickets (11, 12) need tap or typed on the wire.

**Question.** Is logging its own slice ahead of the budget, with the weekly view and the Sentry check inside it?

**Decision.** Lee can open one saved view and read, per week: cost per athlete by plan, the first-step cache hit rate, cost per confirmed plan, spend in conversations that never add a meal, and the share of turns that were fixed-label taps. An account that costs more than $1.50 in a day is reported to Sentry the same day. The app says whether each message was tapped or typed.

**Why.** Every later ticket records a before and after number, and the budget settles on the gateway's charge, so the columns have to exist first.

**What else was considered.** Adding each column in the ticket that first needs it, which would spread one migration across four tickets.

**What it touches.** supabase/migrations, supabase/functions/_shared/vana/log.ts, supabase/functions/_shared/vana/chat.ts, lib/features/meal_planning/data/vana_chat_repository.dart, lib/features/meal_planning/application/vana_chat_controller.dart, docs/database

**Details.** 
- [ ] The call log gains cache-write tokens, step count, the gateway's charge, whether the turn drew the budget, tap or typed, and the subscriber's plan and trial state. Idempotent migration, applied to dev.
- [ ] The app sends tap or typed with every message (test through the real chat controller).
- [ ] One saved weekly view gives the five figures above.
- [ ] A daily check reports any account over $1.50 in a day to Sentry and refuses nothing.
- [ ] Raw rows in the three AI log tables are swept after 90 days; weekly rollups are kept.
- [ ] A log test asserts every new column is written.

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-471 · Ticket 06: The model is sent only what it reads
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-471.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 06
- blocked: 02, 04, 05
- depends: mp-420, mp-432
- model: fable

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Sixth of 14, after logging so the saving is measured. The cache ticket (07) follows it because both change what the chat turn sends.

**Question.** Are compact tool results and the wasted opener step one slice?

**Decision.** Vana answers the same and the pickers look the same, and a planning conversation stops growing by about 10,000 tokens per picker. An opener arrives after one model step, not two.

**Why.** Both are changes to what a turn sends and when it stops, in the same two files, and they are the largest saving after the cache.

**What else was considered.** Splitting the stop conditions into their own ticket; they are a few lines and share the opener eval with the compaction.

**What it touches.** supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/chat.ts, supabase/functions/tests/vana, scripts/vana-eval

**Details.** 
- [ ] The meal picker returns a full form to the app and a compact form to the model: the meals shown plus a count of the rest. The app-facing part is unchanged against the frozen contract fixtures.
- [ ] Every other tool the audit lists as oversized has a model-facing form under a stated size budget (one test per tool).
- [ ] Replay uses the compact form, and the picker message is stored once.
- [ ] A turn ends when Vana asks a choice, hands off, or saves feedback silently; the stop conditions are checked against the pinned SDK version. The live opener eval asserts one model step.
- [ ] On dev, input tokens on the fourth planning turn of a scripted conversation are recorded in this ticket before and after (expect about 72k to fall under 35k).

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-472 · Ticket 07: The cache reads everything that repeats
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-472.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 07
- blocked: 02, 04, 05, 06
- depends: mp-420, mp-276, mp-290
- model: fable

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Seventh of 14, the last of the chat-turn chain. The chip tickets follow it because they edit the persona it splits.

**Question.** Is the cache fix (two system messages, byte-stable replay) one slice, with the meal-logging prompts left to ticket 08?

**Decision.** Nothing changes for the athlete. A planning turn reads 80% or more of its input from the cache, against 43% today, and costs about a cent.

**Why.** Byte-stable replay and the split prompt are one property: what is sent twice must be identical. Testing them apart would test half of it.

**What else was considered.** Including the meal-logging prompts, as the 09-20 draft did; they are different functions with a different test and fit ticket 08.

**What it touches.** supabase/functions/_shared/vana/chat.ts, supabase/functions/_shared/vana/context-cache.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/tests/vana/prompt_cache.test.ts

**Details.** 
- [ ] First, the one-line dev experiment with the gateway's automatic caching on ten planning turns; first-step cached tokens are recorded in this ticket.
- [ ] The system prompt is two system messages, persona then athlete context. A context rebuild leaves the first byte-identical (extends the prompt cache test). Each gets an explicit marker where automatic caching does not mark it.
- [ ] Calls are pinned to Anthropic and carry a session id per conversation. The tool list never varies per turn.
- [ ] The screen line and the opener's hidden first message are stored with the transcript; a stored conversation replays byte-for-byte as first sent (test).
- [ ] The shared prefix uses the one-hour lifetime if the setting survives the gateway; the dev result is recorded either way.
- [ ] The opener's start-time test stays at 3.5 seconds.
- [ ] Dev, after: the read share on ten planning turns is recorded in this ticket. Target 80% or better.

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-473 · Ticket 08: Meal logging: a cacheable prompt, totals we add up, and an answer for "not food"
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-473.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 08
- blocked: 02, 04
- depends: mp-465, mp-432

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Eighth of 14. It waits only for the pin and the limiter, which edit the same two functions, so it runs beside the chat-turn chain.

**Question.** Are the two meal-logging functions and the photo size one slice, separate from the chat cache?

**Decision.** A photo that is not food gets one short answer and no made-up macros. Totals always equal the sum of the items. Photos upload at 1,000 px on the long edge, so a portrait photo stops costing a third more. Both functions stay on Sonnet.

**Why.** Same two functions, same prompt shape, one client change. The athlete can see the not-food answer, so it is demoable alone.

**What else was considered.** Keeping it inside the cache ticket. Moving meal logging to a cheaper model, which Lee put off (mp-465).

**What it touches.** supabase/functions/describe-meal/index.ts, supabase/functions/analyze-meal-photo/index.ts, lib/features/meal_logging/application/meal_ai_service.dart, lib/features/meal_logging/presentation/screens/photo_capture_screen.dart

**Details.** 
- [ ] Both functions send their fixed instructions first with a one-hour cache marker and the athlete's text or photo last (prompt shape test in each function's own test file).
- [ ] The function adds up the totals; the model's totals are ignored (test with a mismatched model answer).
- [ ] The output has a "not food" answer and the log-meal screen shows one short line for it, from the content system.
- [ ] Photos are sent at 1,000 px on the long edge; a portrait and a landscape photo of the same scene bill within 10% of each other on dev.
- [ ] Both model settings still default to Sonnet.

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-474 · Ticket 09: The monthly budget, metered in real cost on the server
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-474.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 09
- blocked: 02, 04, 05, 08
- depends: mp-430, mp-436, mp-282
- model: fable

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Ninth of 14 and the largest. It needs the limiter's in-flight row (04), the gateway's charge in the log (05) and the meal-logging functions settled (08). Ticket 10 puts it on screen.

**Question.** Is the whole server side of the budget one slice, with the screen in the next ticket?

**Decision.** Every account has $4.00 of AI a month, the trial week $1.00, and the packs add $1.00 and $5.00 at today's prices. Every call draws it down, openers included. A conversation that crosses the line finishes; the next call is refused with the top-up response. Credits already in a wallet become budget at 2 cents each. The old free grant of 20 credits ends when the paywall opens.

**Why.** Reserve, settle and refund are one mechanism that is only correct when tested together as real SQL. Splitting the conversion or the packs off would leave a wallet in two units between tickets.

**What else was considered.** Server and screen in one ticket, too large for one context. A separate ticket for the credit conversion, which cannot land apart from the unit change.

**What it touches.** supabase/migrations, supabase/functions/_shared/ai/credits.ts, supabase/functions/_shared/ai/allowance.ts, supabase/functions/_shared/ai/usage.ts, supabase/functions/_shared/ai/wallet_rules.test.ts, supabase/functions/vana-chat/index.ts, supabase/functions/_shared/vana/actions.ts, supabase/functions/describe-meal/index.ts, supabase/functions/analyze-meal-photo/index.ts, supabase/functions/revenuecat-webhook

**Details.** 
- [ ] The wallet holds whole micro-dollars. A call reserves an estimate for its kind in one atomic statement that also checks the balance; on finish the reservation becomes the real cost; a failed call gets it back.
- [ ] Real cost is the gateway's own charge, or logged tokens priced from one table when the gateway reports none. No test asserts a price.
- [ ] Wallet seam, real SQL on dev in a rolled-back transaction: settle to real cost; two parallel reservations where one fits; a failed call refunded; a call that finishes over the budget and the next refused; monthly budget spent before bought budget; 50 old credits become $1.00.
- [ ] A database error refuses the call (shared credits test).
- [ ] Openers draw the budget. Every debiting call is covered: chat, openers, the pantry photo, the described meal, the meal photo.
- [ ] The monthly grant is $4.00, the trial week $1.00, the packs $1.00 and $5.00; a transferred subscription leaves the allowance where it was granted; the free grant of 20 credits ends at the paywall date.
- [ ] The client is sent a share, a refill date and bought extra, never a dollar figure.
- [ ] Open question carried from the spec, to answer in this ticket or raise on the page: a sandbox purchase reaching production must not grant a real budget.

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-475 · Ticket 10: The athlete sees a share of the month, never dollars
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-475.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 10
- blocked: 02, 04, 09
- depends: mp-430, mp-436, mp-282

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Tenth of 14. The screen half of the budget, straight after the server half.

**Question.** Is the budget's screen work one slice, with the wallet channel fix inside it?

**Decision.** Vana settings shows how much of this month's Vana is used, when it refills and any bought extra, as a bar and words, with no dollar figure anywhere. At 100% the athlete gets the top-up sheet, with the packs worded for the new unit. The wallet's live connection is open only while a budget screen is showing.

**Why.** Everything here is the credits feature folder and one settings screen, tested through the real controllers.

**What else was considered.** Leaving the wallet channel in the launch ticket (03); it edits the same controller this ticket rewrites.

**What it touches.** lib/features/ai_credits, lib/features/meal_planning/presentation/screens/vana_settings_screen.dart, assets/config/content_defaults.json

**Details.** 
- [ ] The Vana settings usage bar shows a share, a refill date and bought extra with no dollar figure (widget test through the real controller).
- [ ] At 100% the top-up sheet opens (mp-282); the pack wording names the new unit and no credit count.
- [ ] The wallet channel opens and closes with the budget screens (widget test over a transport that counts).
- [ ] A gateway refusal still shows "Vana is unavailable right now" and never the top-up sheet (ticket 02's test stays green).
- [ ] Every controller write path keeps its test through the real notifier.
- [ ] Checked on a pool simulator: the bar in Vana settings, and the sheet at 100% on a drained dev wallet.

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-476 · Ticket 11: Chips that settle or navigate act at once, with no model turn
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-476.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 11
- blocked: 04, 05, 07, 09
- depends: mp-464
- model: fable

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Eleventh of 14. The first of two chip tickets. It builds the way a tap is stored in the conversation, which ticket 12 reuses.

**Question.** Is this the right first half of the chips: the ones whose action already exists on the no-model endpoint?

**Decision.** Tapping "Draft my whole week", "Same as last time", the batch-cooking answer, a coverage answer, "Open shopping list", "Lay it across the week", "Use what I have" or the pantry card's "Use these" does the thing at once. No model runs, nothing is drawn from the budget, and Vana writes no line. On her next turn Vana knows what was tapped and what it produced.

**Why.** Most of these actions already exist on the no-model endpoint, so this ticket is mostly wiring plus the one new mechanism: a tap stored in the transcript without breaking byte-stable replay.

**What else was considered.** All chips in one ticket, too large with the picker chips' argument mapping. Logging taps for two weeks first, which Lee rejected.

**What it touches.** lib/features/meal_planning/presentation/widgets/choice_chips.dart, lib/features/meal_planning/presentation/widgets/picker_chips.dart, lib/features/meal_planning/presentation/widgets/pantry_card.dart, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_planning/application/vana_chat_controller.dart, lib/features/meal_planning/data/vana_action_client.dart, supabase/functions/_shared/vana/actions.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/_shared/vana/contracts.ts

**Details.** 
- [ ] Each chip named above runs its action on the no-model endpoint; a transport that counts shows no chat request for any of them (widget tests through the real chat controller).
- [ ] The result arrives with no written line from Vana and nothing templated in her voice.
- [ ] The tap and what it produced are stored in the conversation; Vana's next turn is sent them, and a stored conversation still replays byte-for-byte (extends ticket 07's test).
- [ ] These taps draw nothing from the monthly budget and are logged as taps.
- [ ] The persona's chip instructions shrink to the chips that still reach Vana.
- [ ] Chips Vana named herself, "Adjust", openers and typed messages still go to Vana (test).
- [ ] Checked on a pool simulator: a plan drafted, a coverage answer and "Open shopping list", each with no model call in the log.

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-477 · Ticket 12: Picker chips fetch the next picker with no model turn
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-477.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 12
- blocked: 02, 04, 05, 06, 07, 09, 11
- depends: mp-464
- model: fable

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Twelfth of 14. The second chip ticket, on the most tapped chip.

**Question.** Is this the right second half: the chips whose next picker is decided by the tap?

**Decision.** "Other options", "No recipe only" and "Under 20 min" bring the next picker at once with no model. "I like these" and "Next" do the same when the next step is simply the next meal type's picker; when the next step is a question or the wrap-up, the tap goes to Vana as today. "Different protein" stays with Vana.

**Why.** These need a new no-model action that reruns the picker with arguments taken from the tap and the conversation, which the first chip ticket does not. It is the larger saving and the riskier change, so it lands on its own.

**What else was considered.** Doing "Other options" alone first. Sending "I like these" always to Vana, which would keep the most common planning tap on a full turn.

**What it touches.** lib/features/meal_planning/presentation/widgets/picker_chips.dart, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_planning/application/vana_chat_controller.dart, supabase/functions/_shared/vana/actions.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/persona.ts

**Details.** 
- [ ] A no-model action returns the next picker for the same meal type with the same filters, leaving out meals already shown (server test against the picker's frozen contract fixture).
- [ ] "No recipe only" and "Under 20 min" map to fixed picker arguments in one table, tested.
- [ ] "I like these" and "Next" run the no-model action when the next step is the next meal type's picker, and go to Vana when it is a question or the wrap-up (tests for both).
- [ ] No written line; the tap and the picker are stored for Vana's next turn; nothing drawn from the budget; logged as taps.
- [ ] Checked on a pool simulator: a week planned with "Other options" and "I like these", with model calls in the log only where Vana asks or wraps up.
- [ ] On dev, the model calls and input tokens for a scripted five-picker conversation are recorded in this ticket before and after.

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-478 · Ticket 13: Day notes regenerate only when the plan changed
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-478.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 13
- blocked: 02
- depends: mp-432

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Thirteenth of 14. It waits only for the SDK pin and can run in the second wave.

**Question.** Is the day-notes fix one slice on its own?

**Decision.** The Plan tab's day notes are always current and are written again only for the days a plan edit touched. Opening the Plan tab on an unchanged plan calls no model.

**Why.** One function, one module and one client poll. Dev shows 3.7 generations per athlete a day against an expected two a week.

**What else was considered.** Folding it into the launch ticket (03), which is client only and has no blockers.

**What it touches.** supabase/functions/vana-day-notes, supabase/functions/_shared/vana/daynotes.ts, lib/features/meal_planning/data/meal_plan_repository.dart

**Details.** 
- [ ] A plan edit regenerates only the days it touched (server test).
- [ ] The endpoint returns the stored notes when the plan is unchanged and calls no model (test).
- [ ] A claim row makes two simultaneous requests share one model call (test with two parallel requests).
- [ ] The client's refresh cannot start a second generation.
- [ ] On dev, generations per athlete per day are recorded in this ticket before and after.

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-479 · Ticket 14: Three background jobs on the cheapest model, and the unused coach insight removed
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-479.svg
- screen: none (algorithm/data)
- source: tickets ai-cost 2026-09-21
- ticket: 14
- blocked: 02
- depends: mp-465

**Context.** A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part is our own code, not the model's price. Last of 14. It waits only for the SDK pin. Small, and the saving is a few cents per athlete a month.

**Question.** Is one small ticket the right size for the cheap-model work?

**Decision.** Nothing changes for the athlete. The memory extraction, the rolling summary and the saved-meal ingredient list run on the cheapest gateway model that gives the same structured answer. The Formula Kit coach insight, which nothing calls, is removed. Chat stays on Haiku and meal logging on Sonnet.

**Why.** Each job already has a seam where the model is passed in, so this is one new setting, a by-hand comparison and a deletion.

**What else was considered.** A full test harness per job, out of proportion to a few cents. Leaving the dead route on Sonnet behind a limiter.

**What it touches.** supabase/functions/_shared/vana/extract.ts, supabase/functions/_shared/vana/saved-ingredients.ts, supabase/functions/_shared/vana/env.ts, supabase/functions/ai-coach, supabase/functions/_shared/ai_coach, supabase/functions/_shared/ai/model.ts, lib/features/formula_kit/data/ai_coach_client.dart

**Details.** 
- [ ] The three jobs read their model from one new setting, apart from the chat model.
- [ ] On 20 stored dev conversations the candidate's answers are compared by hand with Haiku's; the comparison and the model chosen are recorded in this ticket. If none matches, the setting stays on Haiku.
- [ ] The existing extract and saved-ingredients tests stay green.
- [ ] The coach insight route, its dead shared tools and the app's unused client are removed; the function is undeployed from dev.
- [ ] No helper model is called from inside a Vana turn.

> 2026-09-21 proposed from the ai-cost ticket breakdown
> 2026-09-21 approved by Lee

## mp-480 · Ticket 01: Granted access reaches the server
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-480.svg
- screen: none (ticket)
- source: tickets paywall 2026-09-21
- ticket: 01
- depends: mp-454, mp-452, mp-317, mp-285

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. This is the first of thirteen, and part of the store build (01 to 05).

**Question.** Is this the right slice for a grant or purchase arriving at the webhook, with the right blockers?

**Decision.** A dev account given `pro` by hand in RevenueCat can call Vana: the webhook takes every `pro` event, including a promotional `NON_RENEWING_PURCHASE`, asks RevenueCat for the customer's current `pro` expiry and writes that as active until. A trial started during a live grant keeps the grant's end. The fallback product list knows the eight new ids, and the function's environment on dev holds the RevenueCat secret key.

**Why.** The server half of every grant (grace, coach, giveaway) depends on it, and it is testable end to end with fake events and a fake REST client.

**What else was considered.** Folding it into the grace ticket, which would hide a server fix inside a script.

**What it touches.** supabase/functions/revenuecat-webhook/handler.ts, supabase/functions/revenuecat-webhook/entitlements.ts, supabase/functions/revenuecat-webhook/index.test.ts, supabase/functions/_shared/revenuecat

**Details.** - [ ] A promotional grant event opens the row to the grant's end (handler test with a fake REST client).
- [ ] A trial started during a live grant leaves the row at the later end; a lapsed trial leaves a live grant open.
- [ ] The eight `me_pro_*` ids are in the fallback list.
- [ ] `REVENUECAT_SECRET_KEY` is set on the dev project and the function is deployed to dev.
- [ ] A hand grant on a dev account in RevenueCat shows up in its row.
- [ ] `_shared/revenuecat` holds the one REST client: current `pro` expiry, grant `pro` for N days, set subscriber attributes (tested with a fake fetch).

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee

## mp-481 · Ticket 02: Every AI function checks the subscription on the server
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-481.svg
- screen: none (ticket)
- source: tickets paywall 2026-09-21
- ticket: 02
- depends: mp-429, mp-285, mp-318

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. This is the second of thirteen, in the store build.

**Question.** Is this the right slice for the server-side subscription check, with the right blockers?

**Decision.** A lapsed dev account holding bought budget is refused by describe-meal, analyze-meal-photo, meal-photo, ai-coach and jade-chat, the same way Vana refuses it today. Each calls the shared check at the top.

**Why.** Small, server-only and independent; it closes the hole the audit found.

**What else was considered.** Leaving it in the ai-cost work, which Lee moved here on 09-21.

**What it touches.** supabase/functions/_shared/vana/entitlement.ts, supabase/functions/describe-meal, supabase/functions/analyze-meal-photo, supabase/functions/meal-photo, supabase/functions/ai-coach, supabase/functions/jade-chat

**Details.** - [ ] Each of the five functions returns the same refusal as vana-chat for an account with no active row (function tests).
- [ ] An active account still gets through.
- [ ] Deployed to dev.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee

## mp-482 · Ticket 03: The paywall shows this month's offering, founding prices included
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-482.svg
- screen: none (ticket)
- source: tickets paywall 2026-09-21
- ticket: 03
- depends: mp-453, mp-452, mp-279, mp-417

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. This is the third of thirteen, in the store build.

**Question.** Is this the right slice for the paywall's prices, with the right blockers?

**Decision.** A new dev athlete meets the paywall with $24.99 and $199.99 and the free week. With the `founding` offering made current in RevenueCat, the same screen shows $12.49 and $99.99 beside the normal prices struck through, with a "Founding member" line, and no release. The paywall carries the trial terms, the price after the trial and links to terms and privacy, all copy from the content system.

**Why.** One screen and its controller, demoable on the simulator by flipping the offering.

**What else was considered.** Splitting the founding styling from the Current Offering read, which would ship a paywall that cannot show October.

**What it touches.** lib/features/subscription/application/pro_paywall_controller.dart, lib/features/subscription/data/subscription_service.dart, lib/features/subscription/presentation/screens/paywall_screen.dart, lib/features/content/domain/content_keys.dart, test/features/subscription/application/pro_paywall_controller_test.dart, test/features/subscription/presentation/paywall_screen_test.dart

**Details.** - [ ] The paywall reads the Current Offering (controller test with fake offerings).
- [ ] With `founding` current, each plan shows the founding price and the `default` price struck through (controller test and a golden).
- [ ] Trial terms, price after, terms and privacy links are on screen from the content system.
- [ ] On the dev simulator the paywall shows the new store prices.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee

## mp-483 · Ticket 04: The day-five reminder
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-483.svg
- screen: none (ticket)
- source: tickets paywall 2026-09-21
- ticket: 04
- blocked: 03
- depends: mp-456

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. This is the fourth of thirteen, in the store build, after the paywall controller changes in 03.

**Question.** Is this the right slice for the trial reminder, with the right blockers?

**Decision.** A dev athlete who starts the free week gets a local notification at 10:00 two days before the trial ends: the trial ends in two days, the price after, and they can cancel any time; tapping it opens the store's subscription page. If they cancel, the next app open removes it.

**Why.** One behaviour through the paywall controller and the notification service, testable with a fake scheduler.

**What else was considered.** A server push off the webhook, ruled out for the store build.

**What it touches.** lib/shared/services/notification_service.dart, lib/features/subscription/application/pro_paywall_controller.dart, lib/features/subscription/application/subscription_status_provider.dart, lib/features/content/domain/content_keys.dart, test/features/subscription/application/pro_paywall_controller_test.dart, test/shared/services

**Details.** - [ ] A purchase that starts a trial schedules one notification at the right local time (controller test with a fake scheduler).
- [ ] A trial that will not renew cancels it on app open.
- [ ] A purchase with no trial schedules nothing.
- [ ] The text comes from the content system.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee

## mp-484 · Ticket 05: The production products
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-484.svg
- screen: none (ticket)
- source: tickets paywall 2026-09-21
- ticket: 05
- depends: mp-452, mp-429

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. This is the fifth of thirteen, in the store build; it waits for Lee's go.

**Question.** Is this the right slice for the production store setup, with the right blockers?

**Decision.** The four `_prod` products exist on the production App Store and Play apps with prices in every territory and the free week, registered in RevenueCat for the production apps, in `default` and `founding`. Nothing is submitted for review.

**Why.** Store setup is separate from code and permanent, so it is its own ticket behind Lee's go.

**What else was considered.** Doing it at release, which leaves no time for a pricing mistake.

**What it touches.** scripts/store/asc.mjs, scripts/store/play.mjs, docs/implement_mealplanning/04-entitlement.md

**Details.** - [ ] Lee has said go in the terminal before anything is created.
- [ ] `asc.mjs list` and `play.mjs list` against production show the four products, prices and free week.
- [ ] RevenueCat lists the production products on `pro` and in both offerings.
- [ ] The ids and states are recorded in docs/implement_mealplanning/04-entitlement.md.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee

## mp-485 · Ticket 06: The grace month, granted on flip day
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-485.svg
- screen: none (ticket)
- source: tickets paywall 2026-09-21
- ticket: 06
- blocked: 01
- depends: mp-455, mp-429

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. This is the sixth of thirteen, the first of the update before 8 October, after the webhook in 01.

**Question.** Is this the right slice for the flip-day grant, with the right blockers?

**Decision.** Lee runs one script on flip day. Its dry run prints every registered account created before the flip and the count; with the write flag it grants each 30 days of `pro` and sets `founding_member`, skipping anyone already granted. Run on dev first.

**Why.** Script plus the selection function the anonymous claim reuses; verifiable on dev by running it.

**What else was considered.** Granting from the app on first launch.

**What it touches.** scripts/grace-grant.mjs, supabase/functions/_shared/grace

**Details.** - [ ] The dry run lists accounts and a count and writes nothing.
- [ ] The write run grants 30 days and sets `founding_member`; a second run grants nobody (selection tested with a fake database).
- [ ] Run on dev; a granted dev account opens the app and its row is active.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee

## mp-486 · Ticket 07: Codes: the table and the redeem function
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-486.svg
- screen: none (ticket)
- source: tickets paywall 2026-09-21
- ticket: 07
- blocked: 01
- depends: mp-458, mp-429

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. This is the seventh of thirteen, in the update, after 01.

**Question.** Is this the right slice for the server side of codes, with the right blockers?

**Decision.** A signed-in caller posts a code to `redeem-code`. A coach entering their own code is marked coach and gets 30 days of `pro`. An athlete entering a coach or influencer code gets the attribute set and a pending pairing. A giveaway code grants 365 days once. A wrong, expired or used code gets a plain reason.

**Why.** Server-only and complete on its own; the app entry follows in 10.

**What else was considered.** One ticket for server and app, too big for one context.

**What it touches.** supabase/migrations, supabase/functions/redeem-code

**Details.** - [ ] The `codes` table exists on dev with type, owner, validity window and perk; only the service role writes it.
- [ ] Each code type and each refusal is covered by a handler test with a fake REST client and database.
- [ ] Deployed to dev and a coach code redeemed by curl grants `pro`.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee

## mp-487 · Ticket 08: Onboarding with no anonymous session
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-487.svg
- screen: none (ticket)
- source: tickets paywall 2026-09-21
- ticket: 08
- depends: mp-459, mp-417
- model: fable

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. This is the eighth of thirteen, in the update.

**Question.** Is this the right slice for onboarding without an anonymous session, with the right blockers?

**Decision.** A new install goes through onboarding with no anonymous session: answers wait on the phone, the account is made, the answers are written to it, and the paywall follows. The anonymous-session code is archived except the link for old installs.

**Why.** One flow end to end; the grace claim in 09 builds on it.

**What else was considered.** Keeping the anonymous session as hidden plumbing, which Lee rejected.

**What it touches.** lib/features/onboarding/presentation/screens/welcome_screen.dart, lib/features/onboarding/application/onboarding_service.dart, lib/features/onboarding/presentation/providers/onboarding_controller.dart, lib/features/auth/application, lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart, lib/features/settings/presentation/providers/settings_controller.dart, test/features/onboarding

**Details.** - [ ] A fresh install starts no anonymous session (test through the real onboarding controller).
- [ ] Answers given before sign-up are on the account after it (seam test).
- [ ] The removed anonymous paths are moved to an archive, not deleted.
- [ ] Walked on the dev simulator from a fresh install to the paywall.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee

## mp-488 · Ticket 09: Old anonymous installs claim their grace
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-488.svg
- screen: none (ticket)
- source: tickets paywall 2026-09-21
- ticket: 09
- blocked: 06, 08
- depends: mp-455, mp-417

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. This is the ninth of thirteen, in the update, after the grace selection (06) and the new onboarding (08).

**Question.** Is this the right slice for the anonymous-install claim, with the right blockers?

**Decision.** An install still anonymous from before the flip opens the new build, lands on the account screen, signs up onto its old user so the data stays, and gets the same 30 days, once.

**Why.** The one place the app still meets an anonymous user; small once 06 and 08 exist.

**What else was considered.** Leaving old anonymous installs to buy on the day, which punishes them for never registering.

**What it touches.** supabase/functions/grace-claim, supabase/functions/_shared/grace, lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart, lib/features/auth/application

**Details.** - [ ] The claim grants only to an anonymous user created before the flip with no grant (handler test).
- [ ] Sign-up links onto the old user and keeps its data (seam test).
- [ ] Checked on the dev simulator with an old anonymous session.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee

## mp-489 · Ticket 10: "Have a code?" on the paywall and in Settings
- category: Tickets
- status: withdrawn
- image: none
- caption:
- screen: none (ticket)
- source: tickets paywall 2026-09-21
- ticket: 10
- blocked: 03, 04, 07
- depends: mp-458

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. This is the tenth of thirteen, in the update, after the paywall (03) and the redeem function (07).

**Question.** Is this the right slice for the code entry, with the right blockers?

**Decision.** An athlete taps "Have a code?" on the onboarding paywall or the row in Settings, enters a code and sees what it did or why it failed; a coach entering their own code goes straight into the app.

**Why.** The app half of codes, demoable against the dev function.

**What else was considered.** Code entry only in Settings, which a coach would not find before the paywall.

**What it touches.** lib/features/subscription/presentation/screens/paywall_screen.dart, lib/features/subscription/application/code_entry_controller.dart, lib/features/settings/presentation/screens/settings_screen.dart, lib/features/content/domain/content_keys.dart, test/features/subscription/application/code_entry_controller_test.dart

**Details.** - [ ] The entry sends the code and shows each result (controller test with a fake function).
- [ ] A coach code opens the app without the paywall on the dev simulator.
- [ ] Copy from the content system.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee
> 2026-09-21 withdrawn by Lee

## mp-490 · Ticket 11: Open, lapsed or never, and the read-only shell
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-490.svg
- screen: none (ticket)
- source: tickets paywall 2026-09-21
- ticket: 11
- blocked: 04
- depends: mp-457, mp-280, mp-284, mp-335, mp-416

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. This is the eleventh of thirteen, in the update, after 04 (both change the status provider).

**Question.** Is this the right slice for the three gate states, with the right blockers?

**Decision.** A dev account whose `pro` has expired opens the app with a bar on every screen saying the plan has ended and a Subscribe button; the Vana launcher and every AI entry open the paywall. An account that never had `pro` meets the paywall and nothing else. The write-access provider exists and says no for a lapsed account.

**Why.** The gate, router and shell change together; writes follow in 12.

**What else was considered.** One ticket with the write guard, which is too wide for one context.

**What it touches.** lib/features/subscription/domain/entitlement.dart, lib/features/subscription/application/pro_gate.dart, lib/features/subscription/application/subscription_status_provider.dart, lib/features/subscription/presentation/pro_gate_redirect.dart, lib/shared/core/app_router.dart, lib/shared/widgets/tabs_screen.dart, test/features/subscription/application/pro_gate_test.dart, test/features/subscription/application/subscription_status_provider_test.dart, test/features/subscription/presentation/pro_gate_redirect_test.dart

**Details.** - [ ] The gate answers open, lapsed or never from fake customer info (through the real notifier).
- [ ] Lapsed reaches app routes with the bar; never is redirected to the paywall (redirect test).
- [ ] AI entry points open the paywall for a lapsed account.
- [ ] Checked on the dev simulator with an expired sandbox account.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee

## mp-491 · Ticket 12: A lapsed account cannot write
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-491.svg
- screen: none (ticket)
- source: tickets paywall 2026-09-21
- ticket: 12
- blocked: 03, 04, 08, 09, 11
- depends: mp-457, mp-280
- model: fable

**Original.** Every write controller checks the write-access provider before writing; for a lapsed account the edit opens the paywall and nothing is written or queued for sync.

**Lee said.** good to go (terminal 2026-09-21): narrow the touches to the application folders it edits, so it stops blocking the store-build tickets

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. This is the twelfth of thirteen, the last of the update.

**Question.** Is this the right slice for the write guard, with the right blockers?

**Decision.** Every write controller checks the write-access provider before writing; for a lapsed account the edit opens the paywall and nothing is written or queued for sync.

**Why.** Mechanical across many controllers once the provider exists; done in batches per feature if it runs long.

**What else was considered.** Disabling each edit control on each screen.

**What it touches.** lib/features/activities/application, lib/features/ai_credits/application, lib/features/app_startup/application, lib/features/auth/application, lib/features/barcode_scanning/application, lib/features/calendar/application, lib/features/carb_loading/application, lib/features/coach_mode/application, lib/features/content/application, lib/features/daily_macros/application, lib/features/education/application, lib/features/events/application, lib/features/formula_kit/application, lib/features/fuel_timeline/application, lib/features/home_shell/application, lib/features/integrations/application, lib/features/kroger/application, lib/features/macro_dashboard/application, lib/features/meal_logging/application, lib/features/meal_planning/application, lib/features/nutrition_plan/application, lib/features/onboarding/application, lib/features/personal_templates/application, lib/features/race_checklist/application, lib/features/recipes/application, lib/features/sharing/application, lib/features/weather/application, test/features/ai_credits/application, test/features/auth/application, test/features/coach_mode/application, test/features/integrations/application, test/features/macro_dashboard/application, test/features/meal_planning/application, test/features/nutrition_plan/application

**Details.** - [ ] Each write controller refuses while lapsed (one seam test per controller write path, through the real notifier).
- [ ] Nothing is written locally or queued while lapsed.
- [ ] An active account writes as before (the full suite stays green).

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee
> 2026-09-21 amended by Lee
> 2026-09-21 approved again by Lee

## mp-492 · Ticket 13: The store checks before release
- category: Tickets
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-492.svg
- screen: none (ticket)
- source: tickets paywall 2026-09-21
- ticket: 13
- blocked: 01, 02, 03, 04, 05
- depends: mp-463, mp-289

**Context.** The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store submission has to go in around 25 September. This is the last of thirteen; it closes the store build.

**Question.** Is this the right slice for the release check, with the right blockers?

**Decision.** Claude checks from the APIs and the signed-in browser that the products, prices, free weeks and offerings are right on both stores and RevenueCat, that a hand-granted account shows `pro` and has its row. Lee then does the phone part on both stores: the founding purchase, the day-five reminder with the clock moved on, and Restore.

**Why.** The release gate; it can only run once the store build is in.

**What else was considered.** Leaving the old wizard as it is.

**What it touches.** scripts/sandbox-trial-wizard.sh, docs/release/sandbox-trial-runs

**Details.** - [ ] The wizard carries the three new steps and marks which are Claude's and which need a phone.
- [ ] Claude's checks run and are logged under docs/release/sandbox-trial-runs.
- [ ] Lee's phone run is logged green on both stores.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee

## mp-493 · The paywall copies Bevel's layout in our branding and opens on a clip of our app
- category: Pro and paywall
- status: approved
- image: docs/ssot/decisions/images/mealplanning/bevel-paywall-hero.png
- caption: Bevel's paywall, the reference. Ours carries our branding and our widgets.
- svg2: docs/ssot/decisions/images/mealplanning/mp-493-2.svg
- screen: Paywall
- source: docs/research/paywall-bevel-teardown.md; Lee in the terminal 2026-09-21
- work: pending

**Context.** Xuan liked the paywall in the Bevel app and asked for something like it. Ours today is a price list with a stack of text buttons under it. mp-453 says what the paywall shows (the plans on sale, founding prices, trial terms, links) but not its shape. Bevel has a free tier, so its paywall can always be closed; ours cannot be closed by an account that never subscribed.

**Question.** What does the paywall look like, and does everyone see it the same way?

**Decision.** The paywall follows Bevel's layout but wears our colours, type and copy. It opens on a silent clip of about four seconds of our own app in a phone frame, then slides over to the features, with the two plan cards and one Continue button pinned at the bottom the whole time and everything else behind the ⋯ menu. An account that never subscribed sees it full screen with no close button; an account whose Pro has ended sees it as a sheet it can close over its read-only app. Example: on 1 October a new athlete signs up, watches the fuelling timeline, Vana and the meal plan play, and finds the annual plan already picked at the founding $99.99 a year, shown as $8.33 a month and 33% off.

**Why.** It sells the product by showing it, the price never scrolls away, and the one button to press is never in doubt. Building it in the shared library means the Subscription screen (mp-495) and later screens reuse it instead of copying it.

**What else was considered.** Keeping the current price-list layout and restyling it; one closable sheet for everyone (the gate requires a new account to stay).

**What it touches.** The paywall screen, the gate's presentation of it, `lib/shared/widgets/kyle_design/`, `docs/ssot/spec/design/components/`, the content system.

**Details.** Precisely:
1. It opens on a short clip of our own app playing inside a phone frame, about four seconds, silent: the fuelling timeline, then Vana answering, then the meal plan. The clip is recorded from the simulator, so it shows the real app. When it ends, the page slides over to the features and plans, and the close and ⋯ buttons appear with that second page. With Reduce Motion on, it shows a still frame of the first screen and goes straight to the features.
2. Scrolling shows four headline features, then an "also includes" divider and the rest. The AI features sit under one line (Vana), so a lapsed athlete reads one reason, not four refusals.
3. The two plan cards stay pinned above one Continue button through the whole scroll. The annual card is selected by default and carries a saving badge and a per-month price.
4. Everything secondary sits behind a ⋯ menu (mp-494).
5. One layout, two presentations. An account that never subscribed sees it full screen with no close button. A lapsed account sees it as a closable sheet over the read-only app, opened from the "plan ended" bar or any edit or AI tap (mp-457).
6. It follows Bevel's layout but wears our branding: our colours, type and copy from the token registry and the content system. It is built from the `kyle_design` widget library. Any new widget or animation it needs (the phone frame that plays the clip, the slide-over to the features, the pinned plan cards, the ⋯ menu, the sheet's entrance) is added to that library on the liquid glass materials, with a component spec, and the paywall composes it.
7. It ships in the 25 September store build, since Apple reviews the paywall.

Annual saving and per-month price, from store prices: $199.99 a year against $24.99 a month is 33% off and $16.67 a month; founding $99.99 against $12.49 is 33% off and $8.33 a month. The clip is a video file played with `video_player` (already a dependency); Xuan or Kyle can swap it without a code change. The component spec is written app-side, "PROPOSED, authored app-side, awaiting Xuan".

> 2026-09-21 proposed from Lee's terminal answers on the Bevel teardown; extends mp-453
> 2026-09-21 amended by Lee
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-494 · Restore, Redeem code, Manage, Sign out and Delete account all sit in one ⋯ menu
- category: Pro and paywall
- status: approved
- image: docs/ssot/decisions/images/mealplanning/bevel-paywall-menu.png
- caption: Bevel's ⋯ menu, the reference
- svg2: docs/ssot/decisions/images/mealplanning/mp-494-2.svg
- screen: Paywall
- source: docs/research/paywall-bevel-teardown.md; Lee in the terminal 2026-09-21
- work: pending

**Context.** mp-280 clause 2 puts Restore purchases, Manage subscription, Sign out and Delete account on the paywall as visible buttons, and mp-417 clause 3 keeps the onboarding shape to Restore only. mp-458 clause 7 puts code entry behind a "Have a code?" link on the paywall and a Settings row. Bevel puts all of this behind one ⋯ menu.

**Question.** Where do the paywall's secondary buttons go?

**Decision.** They all move into one ⋯ menu in the paywall's top corner: Restore purchases, Redeem code, Manage subscription (only when the account has a subscription to manage), Sign out and Delete account. The menu is the same for a new account and a Lapsed one, so a new account can also sign out or delete itself from the paywall. Redeem code opens our own Code entry only, never the App Store's offer-code sheet. Example: an athlete signs up on 3 October, decides not to start the trial, taps ⋯ and deletes the account without leaving the paywall.

**Why.** One clean screen with one button to press. Apple asks that account deletion can be found, and a labelled menu on the paywall meets that. Our codes work on both platforms and for lapsed athletes, and carry coach pairing and founding attribution; Apple's cannot be redeemed until the app is live and Play's only work for people who never subscribed.

**What else was considered.** Keeping Sign out and Delete account visible, as the teardown suggested; adding Apple's offer-code sheet as a second iOS entry.

**What it touches.** The paywall screen, the code entry, the account deletion flow.

**Details.** Precisely:
1. The paywall has one ⋯ button in its top corner. Its menu holds Restore purchases, Redeem code, Manage subscription (only when the account has a subscription to manage), Sign out and Delete account.
2. The same menu serves both presentations, so the onboarding paywall also offers Sign out and Delete account. This replaces mp-280 clause 2 and mp-417 clause 3.
3. Redeem code opens our own code entry (mp-458) only. There is no App Store offer-code sheet. This replaces the "Have a code?" link in mp-458 clause 7; the Settings entry moves to the Subscription screen (mp-495).

> 2026-09-21 proposed from Lee's terminal answers on the Bevel teardown; changes mp-280 clause 2, mp-417 clause 3, mp-458 clause 7
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-495 · Settings gets a Subscription screen that shows the plan and what Pro includes
- category: Pro and paywall
- status: approved
- image: docs/ssot/decisions/images/mealplanning/bevel-subscription.png
- caption: Bevel's subscription screen, the reference
- svg2: docs/ssot/decisions/images/mealplanning/mp-495-2.svg
- screen: Settings > Subscription (new)
- source: docs/research/paywall-bevel-teardown.md; Lee in the terminal 2026-09-21
- work: pending

**Context.** No subscription screen exists in Settings today. An athlete with access has nowhere to see their plan, and a lapsed one reaches the paywall only from the "plan ended" bar or a blocked tap. Bevel's subscription screen states the plan and lists what Pro includes.

**Question.** Where in the app does an athlete see and manage their plan?

**Decision.** Settings gets a Subscription row that opens a new Subscription screen. It says where the plan stands (a trial and when it ends, active and when it renews, founding member, or ended) and ticks off what Pro includes, with the AI features under one Vana line as on the paywall. It offers Upgrade when the plan has ended, Manage subscription when there is a subscription, and Redeem code. Example: an athlete whose trial started on 1 October opens Settings, taps Subscription and reads that the trial ends on 8 October.

**Why.** A lapsed athlete gets one calm place to see why things are locked and how to get them back, and an active one can find their plan without a trip to the App Store. It is also the Settings home for code entry.

**What else was considered.** A bare "Have a code?" row in Settings (mp-458 clause 7 as written); red crosses beside locked features as Bevel does (everything is locked for a lapsed account, so the list would read as a wall of refusals).

**What it touches.** Settings, a new Subscription screen, the paywall sheet, the code entry, the subscription service.

**Details.** Precisely:
1. Settings gets a Subscription row that opens a Subscription screen.
2. The screen shows the plan status (trial with its end date, active with its renewal date, founding member, or ended) and a tick list of what Pro includes, with the AI features grouped under one Vana line as on the paywall.
3. It carries Upgrade (opens the paywall sheet; shown when the plan has ended), Manage subscription (the store's own screen; shown when there is a subscription), and Redeem code (our code entry, mp-458).
4. It is built from the same `kyle_design` widgets as the paywall, in our branding.
5. It ships in the 25 September store build with the paywall.

> 2026-09-21 proposed from Lee's terminal answers on the Bevel teardown
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-496 · The store build carries the Bevel paywall and the Subscription screen; the Paywall sheet and Redeem code wait for the update
- category: Spec
- status: approved
- image: none
- svg: docs/ssot/decisions/images/mealplanning/mp-496.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-496-2.svg
- screen: none (algorithm/data)
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October, and the store submission goes in around 25 September. mp-460 put the paywall with founding styling in that store build, and read-only mode and Codes in an update before 8 October. Lee then put the paywall layout copied from the Bevel app (mp-493) and the Subscription screen (mp-495) in the store build as well. This card is the "What ships when" paragraph in the spec's Implementation Decisions.

**Question.** Which parts of the new paywall design go in the 25 September build, when read-only mode and Codes come a week later?

**Decision.** The store build (the one sent around 25 September) also carries the new paywall layout copied from the Bevel app (mp-493), with its opening clip, the plans pinned at the bottom and the ⋯ menu, and the Subscription screen in Settings. Until the update, an account whose Pro ended meets the paywall full screen, as one that never subscribed does; the Paywall sheet over the read-only app arrives with read-only mode. Redeem code appears in the ⋯ menu and on the Subscription screen only once Codes ship in the update, and if time runs short, the Subscription screen moves to the update before anything else in the store build is cut. Example: on 1 October a new athlete signs up, sees the clip and the pinned plans, and finds no Redeem code in the ⋯ menu; it appears with the update before 8 October.

**Why.** The sheet needs read-only mode behind it, and a Redeem code entry with no code system behind it would fail review. The Subscription screen is the one piece of the store build that Apple does not review, so it is the first to move.

**What else was considered.** Moving codes and read-only mode into the store build too (more work before the 25th than the week allows).

**What it touches.** The paywall, the Subscription screen, the ⋯ menu, the release plan.

**Details.** Precisely:
1. The store build carries the new paywall layout with the clip, the pinned plans and the ⋯ menu, and the Subscription screen in Settings, on top of what mp-460 already puts there.
2. Until the update, a lapsed account meets the paywall full screen, as a never-subscribed one does. The closable sheet over the read-only app arrives with read-only mode.
3. Redeem code appears in the ⋯ menu and on the Subscription screen only once codes ship in the update. The store build shows neither entry.
4. If time runs short, the Subscription screen moves to the update before anything else in the store build is cut.

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-497 · The paywall and Subscription screens are tested as screens
- category: Spec
- status: approved
- image: none
- svg: docs/ssot/decisions/images/mealplanning/mp-497.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-497-2.svg
- screen: none (algorithm/data)
- source: spec paywall 2026-09-21

**Context.** The paywall opens on 1 October in the layout copied from the Bevel app (mp-493), with a ⋯ menu (mp-494) and a Subscription screen (mp-495). The Gate and paywall tests (mp-462) drive the code behind the screens, which cannot see the clip, the menu or which buttons show. This card is the "screen seam" paragraph in the spec's Testing Decisions.

**Question.** Where are the paywall's look and the Subscription screen tested?

**Decision.** As widget tests (tests that draw a real screen with no device), on the real paywall and Subscription screens, fed by the same fake subscription service as the Gate and paywall tests (mp-462). They check the clip, Reduce Motion (the phone setting that cuts animation), which entries the ⋯ menu lists in each state, that an account that never subscribed has no close button, and what the Subscription screen shows for trial, active, founding and ended. Saved screenshots of both paywall forms and the Subscription screen, light and dark, replace the 15 September ones, and each new widget in the app's design library gets its own test. Example: with fake details for a trial started on 1 October, the test opens the Subscription screen and checks it shows the trial.

**Why.** What the athlete sees and can tap is the behaviour here, and a notifier test cannot see it. A screen test with a fake service is the lowest level that can, and it needs no device.

**What else was considered.** A Patrol flow on the simulator (slow, and Codemagic never runs it); checking the shape by hand in the store run only.

**What it touches.** The paywall and Subscription screen tests, the paywall goldens, the `kyle_design` widget tests.

**Details.** Precisely:
1. The paywall and the Subscription screen are tested as widget tests on the real screens, driven by the same fake subscription service the client seam uses.
2. The cases: the clip plays and the page moves on to the features and plans, with close and ⋯ appearing then; Reduce Motion shows the still frame and goes straight to the features; the ⋯ menu lists exactly the entries each state allows; a never-subscribed account gets no close button; the Subscription screen shows trial, active, founding and ended from fake customer info.
3. Goldens of both paywall presentations and the Subscription screen, light and dark, replace the 09-15 paywall goldens.
4. The new `kyle_design` widgets each get their own widget test in the library, as the library's widgets do today.

> 2026-09-21 proposed from the paywall spec
> 2026-09-21 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-498 · Ticket 14: The paywall opens on our app
- category: Tickets
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- screen: Paywall
- source: tickets paywall 2026-09-21
- ticket: 14
- blocked: 03
- depends: mp-493, mp-497, mp-453

**Context.** The paywall opens on 1 October at Xuan's prices, and the store submission has to go in around 25 September; the paywall today is a price list with a stack of text buttons that shows nothing of the app it sells, and Settings has nowhere to see or manage a plan. This is the first of five tickets that fold the Bevel layout into the existing thirteen. It builds on ticket 03's Current Offering paywall; 15 adds the pinned plans and the ⋯ menu on top.

**Question.** Is this the right slice, with the right blockers?

**Decision.** A new dev athlete meets a paywall that opens on about four seconds of the real app playing silently in a phone frame (timeline, Vana, meal plan), then slides over to four headline features, an "also includes" divider and the rest, with the AI features under one Vana line. With Reduce Motion on, it shows the clip's first frame and goes straight to the features. The phone frame, the slide-over and the feature list are new `kyle_design` widgets on the glass materials, each with a component spec awaiting Xuan.

**Why.** The clip and the hand-over are the one new behaviour in the layout and carry the video asset and three new library widgets; that is one context's worth. It is demoable on the simulator alone.

**What else was considered.** One ticket for the whole layout (too big for one context with five new widgets and goldens); building the widgets as a separate library-only ticket (a horizontal slice nothing can demo).

**What it touches.** assets/video/, pubspec.yaml, lib/shared/widgets/kyle_design/data/phone_clip_frame.dart, lib/shared/widgets/kyle_design/navigation/slide_over_pager.dart, lib/shared/widgets/kyle_design/cards/feature_list.dart, lib/shared/widgets/kyle_design/kyle_design.dart, docs/ssot/spec/design/components/phone-clip-frame.md, docs/ssot/spec/design/components/slide-over-pager.md, docs/ssot/spec/design/components/feature-list.md, lib/features/subscription/presentation/screens/paywall_screen.dart, test/shared/widgets/kyle_design/phone_clip_frame_test.dart, test/shared/widgets/kyle_design/slide_over_pager_test.dart, test/features/subscription/presentation/paywall_screen_test.dart

**Details.** 
- [ ] A clip of about four seconds (timeline, Vana answering, meal plan) is recorded from the dev simulator and bundled with the app.
- [ ] The paywall plays it silently in the phone frame, then slides to the features; close and ⋯ placeholders appear only on the second page (screen widget test).
- [ ] Reduce Motion shows the first frame and goes straight to the features (screen widget test).
- [ ] Four headline features, the "also includes" divider, and the AI features under one Vana line, copy from the content system.
- [ ] Each new widget has a widget test and a component spec marked "PROPOSED, authored app-side, awaiting Xuan"; no colour literals outside `lib/theme/`; `/design-sync` run.
- [ ] Checked on the dev simulator.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee
> 2026-09-21 picture reused from test/features/subscription/presentation/goldens/paywall_light.png

## mp-499 · Ticket 15: Plans pinned above one Continue, and the ⋯ menu
- category: Tickets
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- screen: Paywall
- source: tickets paywall 2026-09-21
- ticket: 15
- blocked: 03, 14
- depends: mp-493, mp-494, mp-496, mp-497, mp-453, mp-417

**Context.** The paywall opens on 1 October at Xuan's prices, and the store submission has to go in around 25 September; the paywall today is a price list with a stack of text buttons that shows nothing of the app it sells, and Settings has nowhere to see or manage a plan. Second of the five Bevel tickets: 14 gives the paywall its clip and features; this one finishes the store-build layout, and 16 reuses its widgets for the Subscription screen.

**Question.** Is this the right slice, with the right blockers?

**Decision.** The two plan cards stay pinned above one Continue button through the scroll; the annual card is selected and shows its saving and per-month price from store prices, with founding prices struck through as ticket 03 built them. One ⋯ button holds Restore purchases, Manage subscription (only with a subscription), Sign out and Delete account; the old stack of text buttons is gone. A never-subscribed account gets no close button. Redeem code is not in the menu yet (mp-496). Goldens of the full-screen paywall, light and dark, replace the 09-15 ones.

**Why.** Pinned plans and the menu are what Apple reviews next to the price, so they land together and finish the store-build paywall.

**What else was considered.** Folding it into 14 (too big); putting the ⋯ menu in the Subscription ticket (the paywall needs it first).

**What it touches.** lib/shared/widgets/kyle_design/cards/plan_card.dart, lib/shared/widgets/kyle_design/buttons/overflow_menu_button.dart, lib/shared/widgets/kyle_design/kyle_design.dart, docs/ssot/spec/design/components/plan-card.md, docs/ssot/spec/design/components/overflow-menu.md, lib/features/subscription/presentation/screens/paywall_screen.dart, lib/features/content/domain/content_keys.dart, test/shared/widgets/kyle_design/plan_card_test.dart, test/shared/widgets/kyle_design/overflow_menu_button_test.dart, test/features/subscription/presentation/paywall_screen_test.dart, test/features/subscription/presentation/goldens/

**Details.** 
- [ ] Plans and Continue stay on screen through the whole scroll (screen widget test).
- [ ] Annual shows "save 33%" and $16.67 a month on default, $8.33 a month on founding, computed from fake store prices (screen widget test).
- [ ] The ⋯ menu lists exactly Restore, Manage (only with a subscription), Sign out and Delete account; no Redeem code (screen widget test).
- [ ] No close button for a never-subscribed account.
- [ ] Goldens of the full-screen paywall, light and dark, replace paywall_light, paywall_dark and paywall_onboarding_dark.
- [ ] Checked on the dev simulator; Delete account still reachable for review.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee
> 2026-09-21 picture reused from test/features/subscription/presentation/goldens/paywall_light.png

## mp-500 · Ticket 16: The Subscription screen in Settings
- category: Tickets
- status: approved
- image: docs/ssot/decisions/images/mealplanning/settings.png
- screen: Settings > Subscription (new)
- source: tickets paywall 2026-09-21
- ticket: 16
- blocked: 15
- depends: mp-495, mp-496, mp-497, mp-493

**Context.** The paywall opens on 1 October at Xuan's prices, and the store submission has to go in around 25 September; the paywall today is a price list with a stack of text buttons that shows nothing of the app it sells, and Settings has nowhere to see or manage a plan. Third of the five Bevel tickets. It reuses the library widgets 14 and 15 build, and ships in the store build unless time runs short (mp-496).

**Question.** Is this the right slice, with the right blockers?

**Decision.** A Subscription row in Settings opens a screen with the plan status (trial with its end date, active with its renewal date, founding member, or ended), a tick list of what Pro includes with the AI features under one Vana line, Upgrade (opens the paywall, when the plan has ended) and Manage subscription (the store's page, when there is a subscription). No Redeem code yet (mp-496).

**Why.** A new screen with its own route and state; one context, demoable from Settings.

**What else was considered.** Adding it to 15 (too big); waiting for codes so Redeem ships with it (it would miss the store build).

**What it touches.** lib/features/subscription/presentation/screens/subscription_screen.dart, lib/features/subscription/application/subscription_screen_controller.dart, lib/features/settings/presentation/screens/settings_screen.dart, lib/features/content/domain/content_keys.dart, test/features/subscription/application/subscription_screen_controller_test.dart, test/features/subscription/presentation/subscription_screen_test.dart, test/features/subscription/presentation/goldens/

**Details.** 
- [ ] Trial, active, founding and ended each show the right status and date from fake customer info (screen widget test).
- [ ] Upgrade only when ended and opens the paywall; Manage only with a subscription.
- [ ] Built from the `kyle_design` widgets 14 and 15 added; copy from the content system.
- [ ] Goldens light and dark.
- [ ] Settings opens it as a named push (route settings carry its name), so the router file is left to ticket 11.
- [ ] Checked on the dev simulator from Settings.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee
> 2026-09-21 picture captured at 1.27.0+3, 18e21789

## mp-501 · Ticket 17: The lapsed paywall is a sheet over the read-only app
- category: Tickets
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- screen: Paywall
- source: tickets paywall 2026-09-21
- ticket: 17
- blocked: 11, 15
- depends: mp-493, mp-457, mp-280, mp-496, mp-497

**Context.** The paywall opens on 1 October at Xuan's prices, and the store submission has to go in around 25 September; the paywall today is a price list with a stack of text buttons that shows nothing of the app it sells, and Settings has nowhere to see or manage a plan. Fourth of the five Bevel tickets, in the update before 8 October: 11 makes lapsed a state and gives it the read-only shell; this ticket changes how the paywall appears over it.

**Question.** Is this the right slice, with the right blockers?

**Decision.** For a lapsed account, the "plan ended" bar's Subscribe button and any edit or AI tap open the paywall as a closable glass sheet over the read-only app instead of a full-screen route. Closing it returns to the screen they were on. A never-subscribed account still gets it full screen.

**Why.** Small, but it depends on both the lapsed state (11) and the finished layout (15), and it is the one presentation change.

**What else was considered.** Folding it into 11 (11 would then wait for the whole layout).

**What it touches.** lib/features/subscription/presentation/screens/paywall_screen.dart, lib/features/subscription/presentation/pro_gate_redirect.dart, lib/shared/widgets/kyle_design/sheets/, lib/shared/widgets/tabs_screen.dart, test/features/subscription/presentation/paywall_screen_test.dart, test/features/subscription/presentation/goldens/

**Details.** 
- [ ] Lapsed: the bar's Subscribe and an AI tap open the sheet; close returns to the same screen (screen widget test).
- [ ] Never: still full screen, no close (screen widget test).
- [ ] The sheet's entrance comes from the `kyle_design` glass sheet, extended there if it needs to be.
- [ ] Golden of the sheet presentation, light and dark.
- [ ] Checked on the dev simulator with an expired sandbox account.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee
> 2026-09-21 picture reused from test/features/subscription/presentation/goldens/paywall_light.png

## mp-502 · Ticket 18: Redeem code in the ⋯ menu and on the Subscription screen
- category: Tickets
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- screen: Paywall
- source: tickets paywall 2026-09-21
- ticket: 18
- blocked: 07, 15, 16
- depends: mp-458, mp-494, mp-495, mp-496

**Context.** The paywall opens on 1 October at Xuan's prices, and the store submission has to go in around 25 September; the paywall today is a price list with a stack of text buttons that shows nothing of the app it sells, and Settings has nowhere to see or manage a plan. Last of the five Bevel tickets, in the update with codes. It replaces ticket 10, whose "Have a code?" link and Settings row mp-494 moved.

**Question.** Is this the right slice, with the right blockers?

**Decision.** Redeem code appears in the paywall's ⋯ menu and on the Subscription screen. It opens our own code entry (no App Store sheet), sends the code to `redeem-code` and shows what it did or why it failed; a coach entering their own code goes straight into the app.

**Why.** Same work ticket 10 held, at the two new places; it needs the function (07) and both surfaces (15, 16).

**What else was considered.** Editing ticket 10 in place (its card is approved on a clause mp-494 replaced).

**What it touches.** lib/features/subscription/presentation/screens/paywall_screen.dart, lib/features/subscription/presentation/screens/subscription_screen.dart, lib/features/subscription/application/code_entry_controller.dart, lib/features/content/domain/content_keys.dart, test/features/subscription/application/code_entry_controller_test.dart, test/features/subscription/presentation/paywall_screen_test.dart

**Details.** 
- [ ] Redeem code in the ⋯ menu and on the Subscription screen (screen widget tests).
- [ ] The entry sends the code and shows each result (controller test with a fake function).
- [ ] A coach code opens the app without the paywall on the dev simulator.
- [ ] Copy from the content system.

> 2026-09-21 proposed from the paywall breakdown
> 2026-09-21 approved by Lee
> 2026-09-21 picture reused from test/features/subscription/presentation/goldens/paywall_light.png

## mp-503 · The server keeps RevenueCat's end date, not the event's
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-503.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-503-2.svg
- screen: none (algorithm/data)
- source: wave paywall 1 ticket 01

**Context.** RevenueCat is the subscription provider. It tracks one entitlement for us, `pro`, and for each customer it knows whether `pro` is live and when it ends. A trial, a paid subscription and a hand Grant all feed that one entitlement, and RevenueCat takes the latest end date among them. Our server keeps a copy of that date on the Entitlement row, written by the webhook. mp-454 said the webhook should copy RevenueCat's date; mp-317 clause 4 said an expiration event closes the row at the event time. With a Grant running under a trial, those two rules give different answers. Ticket 01 built the webhook.

**Question.** When RevenueCat sends an event, does the row keep the date inside the event, or the date RevenueCat gives when asked?

**Decision.** The date RevenueCat gives when asked, always. On every event about `pro` the webhook asks RevenueCat when `pro` ends for that customer and writes that date; when RevenueCat says `pro` is not live at all, the row closes at the event time. The date inside the event is never read. Example: a coach grants an athlete access to 31 October and the athlete's trial lapses on 12 October. The lapse event arrives, RevenueCat still answers 31 October, so the row stays open to 31 October and the athlete keeps access. If RevenueCat cannot be reached, the webhook answers 500 and writes nothing, so RevenueCat sends the event again later.

**Why.** RevenueCat already takes the later of a Grant and a subscription; copying its answer is the only way Grants reach the server. Falling back to the event's date would quietly bring back the bug mp-454 fixes.

**What else was considered.** Closing every expiration at the event time (that would close a live Grant), and falling back to the event's date when RevenueCat is down.

**What it touches.** revenuecat-webhook, `_shared/revenuecat`, mp-317, mp-454.

**Details.** Precisely: 
1. The row takes RevenueCat's current `pro` expiry on every `pro` event, whatever the event type; the payload's expiry is never read.
2. When RevenueCat reports no `pro`, the row closes at the event time. This replaces mp-317 clause 4, whose clock-skew case can no longer arise.
3. Every event that names `pro` takes this path, not a fixed list of types, so a promotional `NON_RENEWING_PURCHASE` opens the row. Test and transfer events keep their own rules (mp-317).
4. If RevenueCat cannot be asked (no key, or its API fails), the webhook answers 500 and writes nothing, so RevenueCat delivers the event again.

> 2026-09-21 proposed in wave 1 ticket 01
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words at Lee's ask; the precise clauses moved to Details

## mp-504 · A trial that lapses under a live Grant keeps its credits
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-504.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-504-2.svg
- screen: none (algorithm/data)
- source: wave paywall 1 ticket 01

**Context.** The Allowance is the batch of credits a subscription puts in the wallet each month. The webhook used to take it away on any expiration event and give it on any purchase or renewal event. Once Grants reach the server (mp-454), a trial can lapse while a Grant is still running, and no decision said what happens to the credits then (mp-281 set the Allowance itself).

**Question.** When a trial lapses but a Grant still runs, do the credits go too?

**Decision.** No. The credits are taken away only when RevenueCat says `pro` is no longer live, and given only when RevenueCat says `pro` is live; the kind of event alone decides nothing. Example: an athlete has a Grant to 31 October and a trial that lapses on 12 October. The lapse event arrives, RevenueCat still says `pro` is live, so the credits stay until the Grant ends on 31 October.

**Why.** A lapsed trial must not strip a granted athlete's credits while they still have access.

**What else was considered.** Leaving the forfeit unconditional, keyed on the event type as before.

**What it touches.** revenuecat-webhook `applyAllowance`, the credit wallet, mp-281.

**Details.** Precisely: an expiration forfeits the Allowance only when RevenueCat reports no live `pro`; a purchase or renewal grants it only when RevenueCat reports `pro` live.

> 2026-09-21 proposed in wave 1 ticket 01
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words at Lee's ask; the precise clause moved to Details

## mp-505 · All five AI functions refuse an unpaid account, even the ones that cost nothing
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-505.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-505-2.svg
- screen: none (algorithm/data)
- source: wave paywall 1 ticket 02

**Context.** mp-429 clause 11 has every AI function check the subscription on the server. Ticket 02 added the check to five functions: describing a meal, reading a meal photo, the testers' photo tool, the coach insight and the old chat. Two of them were not clearly paid AI: the testers' photo tool calls no model, and the coach insight answers from free rules before it ever calls one.

**Question.** Which AI calls does the server refuse when the account has not paid?

**Decision.** All five refuse an account with no live Entitlement row, the same way Vana does, even when it holds bought credits. That includes the testers' photo tool, where a Lapsed Tester is refused and a subscribed non-tester still gets the not-a-tester answer, and the coach insight's free rules answer. The check runs first, straight after sign-in, before the request is read, the wallet is touched or a model is called. Example: an athlete whose Trial ended on 7 October still holds bought credits on 8 October, but a coach insight is refused and costs nothing.

**Why.** The ticket named all five, and mp-318 says testers get in by subscribing. Checking first means a Lapsed caller costs nothing.

**What else was considered.** Leaving meal-photo ungated because it costs nothing; letting the free rules insight through.

**What it touches.** describe-meal, analyze-meal-photo, meal-photo, ai-coach, jade-chat, `_shared/vana/entitlement.ts`.

**Details.** Precisely:
1. All five functions refuse an account with no active row with the same answer as Vana (403 `pro_required`), even when the account holds bought credits.
2. meal-photo is covered: a lapsed tester is refused; a subscribed non-tester still gets the not-a-tester answer.
3. The coach's free rules insight is covered too, so a lapsed or never-subscribed athlete no longer gets it.
4. The check runs straight after sign-in, before the request is read, the wallet is touched or a model is called.

The five functions: describe-meal, analyze-meal-photo, meal-photo, ai-coach, jade-chat; the check lives in `_shared/vana/entitlement.ts`.

> 2026-09-21 proposed in wave 1 ticket 02
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-506 · A founding price strikes through the regular plan of the same length, only while founding is on sale
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-506-2.svg
- screen: Paywall
- source: wave paywall 1 ticket 03

**Context.** RevenueCat holds two Offerings for us: the regular one and the founding one. mp-453 has the paywall sell whichever Offering is marked current and, while it is the founding one, show each founding price with the regular price struck through beside it and a "Founding member" line. Ticket 03 built it. Product ids differ between the stores, so a founding plan cannot find its regular price by id.

**Question.** Which regular price does a founding price strike through, and when?

**Decision.** Each founding plan strikes through the regular plan of the same length: founding monthly against regular monthly, founding annual against regular annual. The struck price, and one "Founding member" line at the top of the pricing card, show only while the founding Offering is the one on sale; any other Offering shows plain prices. A struck price is hidden when there is no regular plan of that length or it is not higher. Example: from 1 October to 30 November the monthly plan reads $12.49 with $24.99 struck through; from 1 December it reads $24.99 alone.

**Why.** Both offerings use the same slots in RevenueCat, while ids do not line up across stores. A struck price that is not a discount would mislead.

**What else was considered.** Matching by product id or by price; striking through whenever any non-default offering is cheaper; a line under each plan.

**What it touches.** Paywall, `PaywallPlans`, pro paywall controller, subscription service.

**Details.** Precisely:
1. A founding plan's struck price is the `default` offering's package in the same slot (monthly with monthly, annual with annual).
2. The struck price and the "Founding member" line show only while the current offering's id is `founding`. Any other offering shows plain prices.
3. The struck price is hidden when `default` has no package in that slot or its price is not higher.
4. One "Founding member" line sits at the top of the pricing card, not one per plan.
5. With no offering marked current, the paywall sells `default`.

> 2026-09-21 proposed in wave 1 ticket 03
> 2026-09-21 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-507 · The trial terms and legal links show on the paywall a new account sees, too
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-507-2.svg
- screen: Paywall
- source: wave paywall 1 ticket 03

**Context.** mp-417 clause 3 says the onboarding shape of the paywall carries the app name, the two plans and Restore purchases only. mp-453 clause 4 says the paywall carries the trial terms, the price after the trial and links to terms and privacy. Ticket 03 renders the terms block in both shapes.

**Question.** Does the paywall a new account sees carry the trial terms and legal links?

**Decision.** Yes. The trial terms, the price after the trial, the renewal terms and the links to terms and privacy show on both the Onboarding paywall and the Paywall sheet. mp-417 clause 3, which gives the Onboarding paywall only the app name, the two plans and Restore purchases, is read as listing its buttons, not its legal text. Example: a new athlete who signs up on 1 December reads, beside the plans, that the first seven days are free and it then renews at $24.99 a month, with the terms and privacy links below.

**Why.** The onboarding paywall is where the trial is bought, and the stores require those terms beside a subscription offer.

**What else was considered.** Hiding the terms in the onboarding shape to keep mp-417 clause 3 literal.

**What it touches.** Paywall (both shapes), mp-417, mp-453.

**Details.** Precisely:
1. The trial terms, the price after the trial, the renewal terms and the terms and privacy links show in both the onboarding and the lapsed shape.
2. mp-417 clause 3 is read as listing the controls, not the legal text.

> 2026-09-21 proposed in wave 1 ticket 03
> 2026-09-21 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-508 · Settings has no guest account card, and signing out means signing in again
- category: Pro and paywall
- status: approved
- image: docs/ssot/decisions/images/mealplanning/settings.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-508-2.svg
- screen: Settings
- source: wave paywall 1 ticket 08

**Context.** mp-459 archives the anonymous-session code in auth, onboarding and settings. Settings used to show a guest card (Create Account, Log In, sign out without an account), and the sign-out dialog promised the athlete could go on as a guest. Ticket 08 removed the card; the wave's review changed the dialog.

**Question.** What does Settings offer about the account now that there are no guests?

**Decision.** Settings no longer shows the guest card, so there is no Create Account, Log In or sign-out-without-an-account there. The sign-out dialog now says the athlete will need to sign in again to use the app. An install still without an account from before the paywall reaches sign-up through ticket 09's redirect, not through Settings, and until ticket 09 lands it has no way to register. Example: an athlete signed in with Apple taps Sign out on 2 October; the dialog says they will need to sign in again, and nothing offers to carry on as a guest.

**Why.** mp-459 clause 3; a guest promise the app can no longer keep is worse than none.

**What else was considered.** Keeping the card for old anonymous installs until ticket 09.

**What it touches.** Settings account section, settings controller and state, ticket 09.

**Details.** Precisely:
1. The guest account card is gone from Settings: no Create Account, no Log In, no sign-out-without-account.
2. The sign-out dialog says the athlete will need to sign in again to use the app.
3. An install still anonymous from before the paywall reaches sign-up through ticket 09's redirect, not through Settings. Until 09 lands such an install has no way to register.

> 2026-09-21 proposed in wave 1 ticket 08
> 2026-09-21 picture captured at 1.27.0+3, 18e21789
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (decision, details)

## mp-509 · Signing in keeps what was answered before the account existed
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-509.svg
- screen: none (algorithm/data)
- source: wave paywall 1 ticket 08

**Context.** With no anonymous session (mp-459), onboarding keeps its answers on the phone under a temporary id, and a training platform connected during onboarding is stored under that id too. Before ticket 08, signing in with a previous id that had no profile returned early and cleared the temporary id, orphaning those rows.

**Question.** What happens to answers saved before the account exists when the athlete signs up or signs in?

**Decision.** Before the account exists, onboarding keeps its answers on the phone under a temporary id, along with any training platform connected during onboarding. A new account takes all of it. Signing in to an account that is already set up keeps that account's settings, and the draft answers do not overwrite them. The temporary id is cleared only once its data has moved. Example: an athlete answers onboarding and connects their training platform, then creates an account on 1 October, and the account opens with their answers and the platform connected; someone who signs in to an account they set up before keeps their saved settings.

**Why.** Answers given before sign-up must be on the account after it (mp-417 clause 1), and a connected platform must not be lost at sign-in.

**What else was considered.** Moving the data inside the migration service instead of at each sign-in path.

**What it touches.** Post-onboarding account screen, auth migration, email and OAuth sign-in, onboarding controller.

**Details.** Precisely:
1. A new account takes the answers and anything connected under the temporary id.
2. Signing in to an account that is already set up keeps that account's settings; the draft answers do not overwrite them.
3. The temporary id is cleared only once its data has moved.

> 2026-09-21 proposed in wave 1 ticket 08
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-528 · When the day-five reminder is set, what it says, and when it goes
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-528.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-528-2.svg
- screen: none (a local notification)
- source: wave paywall 2 ticket 04

**Context.** mp-456 sets the day-five reminder on the phone at purchase and cancels it when the trial will not renew. Ticket 04 built it. Building it raised cases mp-456 does not name: a purchase the store has not confirmed yet, a trial too short to remind about, which price to quote during the founding months, and what happens at sign-out.

**Question.** When is the day-five reminder set or cancelled, and what does it say?

**Decision.** The reminder is set only once RevenueCat confirms the trial and when it ends, for 10:00 two days before the end; a trial too short for that gets none. It quotes the price of the plan the athlete bought, and tapping it opens the page where they manage the subscription. It is cancelled when the trial will not renew, at sign-out and when the account is deleted, while an athlete who converts to paid before day five keeps it. Example: an athlete starts a trial of the founding monthly plan on 1 October that ends on 8 October; at 10:00 on 6 October they read "Your free week ends in two days" and "After that it's $12.49 a month. You can cancel any time. Tap to manage your subscription."

**Why.** A reminder with the wrong price, the wrong account or no trial behind it is worse than none. The store's own end date is the only one that is certain.

**What else was considered.** Scheduling from the intro offer's free days at purchase (wrong for a buyer who is not eligible), and firing a late reminder at once.

**What it touches.** `pro_paywall_controller.dart`, `subscription_status_provider.dart`, `trial_reminder_service.dart`, `notification_service.dart`, `root_app_widget.dart`, content keys `paywall.trial_reminder_*`.

**Details.** Precisely:
1. It is scheduled only once RevenueCat confirms the trial and its end date. A purchase still pending schedules nothing.
2. A trial that ends too soon for a 10:00 reminder two days before it ends schedules nothing, instead of firing at once.
3. The price is the one on the package the athlete bought, so during the founding months it quotes the founding price they will pay. It says "a month" or "a year" to match the plan.
4. Title: "Your free week ends in two days". Body: "After that it's {price} a month (a year). You can cancel any time. Tap to manage your subscription." Both live in the content system.
5. Tapping it opens RevenueCat's subscription management page, or the App Store or Google Play page when RevenueCat has none. This is the same page "Manage subscription" opens.
6. It is cancelled when RevenueCat says the trial will not renew, and also at sign-out and when the account is deleted, so it never reaches the next account on the phone.
7. An athlete who converts to paid before day five keeps the reminder. mp-456 §4 cancels it only for a trial that will not renew.
8. If scheduling fails, the purchase still counts, and the failure goes to Sentry.

Notification slot 4201, payload `trial_ending:subscription`. Clause 6's sign-out and deletion case was added by the wave's code review, which found the reminder surviving sign-out. A paid intro offer would also count as a trial here, which is harmless while every intro offer is the free week (mp-279).

> 2026-09-22 proposed in wave 2 ticket 04
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-530 · Who the grace month covers, and what counts as already granted
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-530.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-530-2.svg
- screen: none (a script Lee runs on flip day)
- source: wave paywall 2 ticket 06

**Context.** mp-455 gives 30 days of Pro and a founding-member mark in RevenueCat to every registered account created before the flip, through a script Lee runs that only lists what it would do unless told to write, and that skips anyone already granted. Ticket 06 built the script and a shared part ticket 09 will reuse. "Registered", "already granted" and the flip time each needed a rule.

**Question.** Which accounts get the grace month, and when is an account skipped?

**Decision.** Legacy grace goes to every account that is not anonymous, not deleted and was created before the flip, paid subscribers included. An account whose Grant already runs at least 30 days past the flip only gets the founding-member mark; one whose Grant ends sooner gets the full 30 days. "Already granted" is read from RevenueCat itself, so a second run grants nobody twice and a run that stops halfway is finished by running it again. Example: with the flip on 1 October, a coach comp that ends on 10 October is topped up to 31 October, while a Grant that already runs to 31 December is left alone and only marked.

**Why.** Clause 3 keeps a comp from being cut short and makes sure nobody gets fewer than 30 days. Reading RevenueCat means there is no second record to drift out of step.

**What else was considered.** A marker of our own in a table (needs a migration and can drift), skipping any account with any live grant (a short comp would lose days), and leaving paid subscribers out.

**What it touches.** `scripts/grace-grant.mjs`, `supabase/functions/_shared/grace`, `_shared/revenuecat/client.ts`, ticket 09.

**Details.** Precisely:
1. An account qualifies when it is not anonymous, not deleted, and was created before the flip. Paid subscribers qualify too, since mp-429 says every account.
2. An account RevenueCat has never seen is created there, then granted.
3. An account holding a grant that already runs to at least 30 days past the flip is not granted again and is only marked `founding_member`. An account whose grant ends sooner, a short coach comp for example, gets the full 30 days.
4. "Already granted" is read from RevenueCat itself: a live promotional `pro` grant to at least flip + 30 days, plus the attribute. A run that stops halfway is finished by running it again.
5. The flip must be given as an exact time with a time zone, and the script refuses to write before it.
6. The grant is written first and the attribute second, so a failure costs a missing attribute, which the next run fixes, never missing days.
7. A write needs a named account (`--user`) or `--all`, and the key must belong to the project named, so a write can never run unfiltered or on the wrong project by mistake.

The script is `scripts/grace-grant.mjs`; the founding-member mark is the `founding_member` subscriber attribute.

Dry run on dev, 22 September, flip 2026-09-21T00:00Z: 968 accounts listed, 76 selected, 75 would be granted, 1 marked only. One filtered write on `test01@test.com` granted 30 days. A second run granted nobody. After the dev webhook change (mp-533) the account's row reads `PROMOTIONAL`, active until 2026-10-22. RevenueCat calls are retried three times on 429, 5xx and network errors. A lost response on a grant that did go through would grant again, and whether RevenueCat de-duplicates that has not been checked.

> 2026-09-22 proposed in wave 2 ticket 06
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-533 · The dev webhook takes events from every environment
- category: Pro and paywall
- status: rejected
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-533.svg
- screen: none (RevenueCat configuration)
- source: wave paywall 2 ticket 06
- linked: mp-510

**Context.** mp-510 asked how a hand grant reaches the dev webhook. RevenueCat logs every grant as a production event, and the dev integration only took sandbox events, so no grant reached a dev row. Tickets 06 and 07 both grant. The webhook's header already says a delivery for a user the project does not have fails its foreign key and is acknowledged as a no-op, and the prod integration has taken every environment since August on that basis.

**Question.** Should the dev integration take every environment?

**Decision.** Yes. On 22 September the dev integration's environment filter was removed, so it takes sandbox and production events, the same as prod. Real prod purchases now also reach dev and are dropped there because dev has no such user.

**Why.** It is the only way a grant (coach code, grace month, giveaway) can be tried on dev end to end, and it matches the rule that a webhook never filters by environment.

**What else was considered.** Testing grants another way, for example by writing the row by hand, which tests nothing.

**What it touches.** RevenueCat integration `whintgre4c0c2670c` (dev), revenuecat-webhook on dev.

**Details.** Checked the same day: a coach-code redeem on test@test.com and the grace grant on test01 both reached their dev rows within a second. Undo: set the integration's environment back to sandbox.

> 2026-09-22 proposed in wave 2 ticket 06
> 2026-09-22 rejected by Lee: wait we keep this separate.  so if something else cleared the filter then that's wrong.  testers on dev should test in sandbox but yes prod testers on release should test on sandbox but i don't know why dev should receive and handle prod stuff that seems off

## mp-535 · Each code works once per account, and only a coach code pairs an athlete
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-535.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-535-2.svg
- screen: none (algorithm/data)
- source: wave paywall 2 ticket 07

**Context.** mp-458 keeps coach, influencer and giveaway Codes in our own table, redeemed through one server function. Ticket 07 built both, on dev since 22 September. How many times a Code works, who it pairs with and what a refusal says each needed a rule.

**Question.** How many times does a code work, what does each kind do, and what does a refused caller hear?

**Decision.** Every Code works once per account, and a giveaway works once in total unless its row allows more; the days a Code grants are set on its row. A coach entering their own Code becomes a coach, and an athlete entering it gets a pending pairing with that coach; an influencer Code records who referred the account but never pairs, since an influencer is not a coach. A Code that is wrong, expired or already used gets a plain reason, and a Code is never spent when RevenueCat cannot be reached, so trying again works. Example: on dev on 22 September the coach Code DEVCOACH30 gave its owner exactly 30 days of Pro; a giveaway row grants 365.

**Why.** A Code must never be spent on nothing, and two people must not both win a single-use giveaway.

**What else was considered.** Pairing influencer codes with their owner, which is how the ticket's build first did it (it would let a non-coach see athlete data), fixed days in the function, and answering refusals with an error status.

**What it touches.** `supabase/migrations/20260921140000_codes.sql`, `redeem-code`, `coaches`, `coach_athlete_relationships`, ticket 18.

**Details.** Precisely:
1. A code is stored upper case with spaces removed, 3 to 32 characters. What the caller types is read the same way.
2. Every code works once per account. A giveaway works once in total unless its row sets a higher limit.
3. The days a code grants are on its row: 30 on a coach code for its owner, 365 on a giveaway. They are not fixed in the function.
4. The owner of a coach code entering it becomes a coach (an approved coach record, which is what the app reads). This includes a coach whose application was rejected, since Lee issues the codes.
5. An athlete entering a coach code gets `coach_code` set and a pending pairing with the coach through the existing pairing path. A pairing that is pending or active is left alone; a declined or archived one goes back to pending.
6. An influencer code sets `influencer_code` and never pairs, since an influencer is not a coach. It may have no owner, and an influencer entering their own code is refused.
7. A wrong, not yet valid, expired, used or already-redeemed code gets a reason and a plain sentence. The app can map the reason to its own copy (ticket 18).
8. An account RevenueCat has never seen, such as a coach who signed up on the web, is created there first. If RevenueCat still fails, the caller gets "store unavailable" and the code is not spent, so a retry works.
9. Only a signed-in account can redeem. An anonymous session is refused.

The table is `codes` and the function `redeem-code`.

The code review changed clauses 6 and 8: influencer codes stopped pairing, and unknown customers are now created. A SQL function (`code_claim`) locks the code row so a giveaway cannot be claimed twice at once. Checked on dev 22 September: `DEVCOACH30` redeemed by curl answered `{"ok":true,"kind":"coach","pro_days":30}`, and RevenueCat shows a new promotional grant of exactly 30 days. The second 30 days when a coach's first athlete pairs, and "free while five are active", stay by hand in the RevenueCat dashboard through November (mp-429 §4).

> 2026-09-22 proposed in wave 2 ticket 07
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-537 · The opening clip runs four seconds, can be tapped past, and never holds the paywall up
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-537-2.svg
- screen: Paywall
- source: wave paywall 2 ticket 14

**Context.** mp-493 §1 opens the paywall on about four seconds of our own app in a phone frame, then slides over to the features, with a still frame under Reduce Motion. Ticket 14 recorded the clip on a dev simulator and built the phone frame and slide-over as `kyle_design` widgets. What the clip shows, and what happens when it is skipped or fails, needed rules.

**Question.** What does the opening clip show, and what if it is skipped or fails?

**Decision.** The clip runs 4.0 seconds, silent: the fuelling timeline, Vana's answer arriving, then a week's meal plan, ending on that plan held still. A tap moves straight on to the features, and a clip that fails or never starts moves on by itself after 3 seconds, so the paywall never hangs. With Reduce Motion on, the paywall opens on the features with a small still of the clip's first frame at the top. Example: on a phone where the video fails to play, the athlete sees the phone frame for 3 seconds and then the page slides over to the features.

**Why.** Nobody should have to wait for a clip, and a paywall that hangs on a broken video is a store rejection. Clause 5 is what "shows a still frame and goes straight to the features" means once both have to be on screen.

**What else was considered.** One uncut take (Vana and the plan take longer than four seconds to appear live), showing the still frame alone first, and no skip.

**What it touches.** `paywall_screen.dart`, `kyle_design` `phone_clip_frame.dart` and `slide_over_pager.dart`, `assets/video/`.

**Details.** Precisely:
1. The clip is 4.0 seconds, silent: the fuelling timeline, Vana's answer arriving, then a week's meal plan. It is cut from one recording with short crossfades, and it ends on the settled plan held still.
2. It shows a past confirmed plan, since the dev account has no current plan and making one would change Lee's dev data.
3. A tap on the clip moves on to the features at once.
4. A clip that fails or never starts moves on after 3 seconds, so the paywall never hangs.
5. With Reduce Motion on, the paywall opens on the features page with a small still of the clip's first frame at its head. It reads the iOS Reduce Motion switch as well as Flutter's animations setting, since on iOS the switch reaches the app only through the first.
6. The slide to the features takes 480 ms with ease-out, and the first page recedes a third as far under a dim.

540×1174 H.264, 116 KB, plus a 53 KB first-frame JPEG. The device check found clause 5's bug (the switch was ignored) and it was fixed. `vana_moment_controller.dart` reads only Flutter's setting and probably has the same bug. The component specs for the frame and the slide-over are in `docs/ssot/spec/design/components/`, awaiting Xuan, with her open questions on the bezel and the motion curve.

> 2026-09-22 proposed in wave 2 ticket 14
> 2026-09-22 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-538 · The paywall leads with four features and puts the rest under "also includes"
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-538-2.svg
- screen: Paywall
- source: wave paywall 2 ticket 14

**Context.** mp-493 §2 shows four headline features, an "also includes" divider and the rest, with the AI features under one Vana line. Ticket 14 wrote the copy into the content system's defaults. Apple reviews this page, so the copy is a product decision.

**Question.** Which features does the paywall list, and in what order?

**Decision.** Four headlines lead: a fuel plan for every session, Vana as your nutrition coach, shopping lists from your plan, and your training already there from Garmin, TrainingPeaks and FinalSurge. Below an "also includes" divider come recipes with a cooking mode, brick and multi-leg workouts, hydration checks, your own fuel formulas, and daily calorie and macro targets. Kroger delivery is left off because it does not reach every athlete. Example: a Lapsed athlete opening the paywall reads "Vana, your nutrition coach" once, covering meal plans, questions and logging a meal from a photo, not four separate AI lines.

**Why.** The four headlines are the reasons to pay. Grouping the AI under Vana means a lapsed athlete reads one reason, not four refusals.

**What else was considered.** Listing Kroger, and giving each AI feature its own line.

**What it touches.** `content_defaults.json` `paywall.feature_*`, the content system (entries not yet created there), `feature_list.dart`.

**Details.** Precisely:
1. Headline: "A fuel plan for every session"; "Vana, your nutrition coach" (plans the week's meals, answers questions, logs a meal from a photo or a sentence); "Shopping lists from your plan"; "Your training, already there" (workouts from Garmin, TrainingPeaks and FinalSurge).
2. Also includes: recipes with a step-by-step cooking mode, brick and multi-leg workouts, hydration checks for long sessions, your own fuel formulas, daily calorie and macro targets.
3. Kroger delivery is not listed, because it does not reach every athlete.

Until the content system has these entries, the bundled defaults show. The keys are `paywall.features_divider`, `paywall.feature_fuel_title`/`_body`, `feature_vana_title`/`_body`, `feature_shopping_title`/`_body`, `feature_sync_title`/`_body`, `feature_recipes`, `feature_brick`, `feature_hydration`, `feature_formulas`, `feature_targets`, plus `clip_label`, `close_label`, `more_label`.

> 2026-09-22 proposed in wave 2 ticket 14
> 2026-09-22 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-540 · Once the free week starts, an athlete with notifications off gets one line asking to turn them on
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-540-2.svg
- screen: Paywall
- work: pending
- source: Lee in the terminal 2026-09-22
- linked: mp-529

**Context.** mp-529 asked whether the purchase should ask for notification permission. The app shows iOS's notification prompt at first launch, and iOS never shows it again, so an athlete who said no then never gets the day-five reminder (mp-528).

**Question.** What does the athlete see at purchase if notifications are off?

**Decision.** Once the trial has started, an athlete whose notifications are off sees one line with a button to iOS Settings: "Turn on notifications to get a reminder before your free week ends." An athlete with notifications on sees nothing extra. Example: an athlete who said no at first launch starts the trial on 1 October, sees the line, turns notifications on, and gets the reminder at 10:00 on 6 October, two days before the free week ends on 8 October.

**Why.** It reaches only the athletes the reminder would otherwise miss, at the one moment it matters, for the cost of one line.

**What else was considered.** Relying on the launch prompt alone, and a day-five banner inside the app as well as the notification.

**What it touches.** The paywall's purchase flow, `notification_service.dart`, content keys.

**Details.** Precisely:
1. Once the trial has started, if notifications are off, the app shows one line with a button to iOS Settings: "Turn on notifications to get a reminder before your free week ends."
2. If notifications are on, nothing is shown.

> 2026-09-22 proposed from Lee in the terminal
> 2026-09-22 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, decision, details)

## mp-541 · The flip is the moment the paywall is switched on
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-541.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-541-2.svg
- screen: none (a script Lee runs on flip day)
- source: Lee in the terminal 2026-09-22
- linked: mp-531

**Context.** mp-531 asked for the exact flip time. The grace script (mp-530) and ticket 09's claim for old anonymous installs both need one fixed instant: accounts created before it get Legacy grace.

**Question.** When exactly is the flip?

**Decision.** The flip is the moment Lee actually switches the paywall on, not a date fixed in advance. Lee notes that moment, and the same instant goes to the grace script and to the claim old anonymous installs make, so every account made before the paywall appeared gets the grace month. Example: if Lee switches it on at 9:00 Central on 1 October, an account made at 8:00 pm Central on 30 September gets the 30 days, and one made at 9:15 that morning meets the paywall and its seven-day trial.

**Why.** Everyone who had an account before the paywall appeared gets the grace month, whatever time of day the switch happens.

**What else was considered.** 1 October 00:00 Central, and 1 October 00:00 UTC (7 pm Central the day before).

**What it touches.** `scripts/grace-grant.mjs`, ticket 09's claim function and its setting.

**Details.** Precisely:
1. The flip is the moment Lee actually switches the paywall on, not a date fixed in advance.
2. Lee notes that moment, and it is passed to the grace script as `--flip` and set as a fixed value for ticket 09's claim function.

> 2026-09-22 proposed from Lee in the terminal
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-542 · The grace run includes our own accounts
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-542.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-542-2.svg
- screen: none (a script Lee runs on flip day)
- source: Lee in the terminal 2026-09-22
- linked: mp-532

**Context.** mp-532 asked whether the prod grace run should skip the team's own test and demo accounts. The grace run is the script Lee runs on flip day to give Legacy grace (mp-530), and it also marks each account it covers as a founding member in RevenueCat.

**Question.** Does the grace run skip our own accounts?

**Decision.** No. Every registered account created before the flip gets the grace month and the founding-member mark, the team's own accounts included. The selection stays as mp-530 built it, with no rule for internal accounts or test email addresses. Example: Lee flips on 1 October and runs the prod grace script. A team demo account made in August is selected like any athlete's account and gets 30 days of Pro, to 31 October, and the founding-member mark.

**Why.** A Grant on a test account costs nothing, internal accounts get past the paywall anyway, and a few extra founding members barely move the count.

**What else was considered.** Skipping accounts flagged internal, and skipping test email domains.

**What it touches.** Nothing; the selection stays as built (mp-530).

**Details.** Precisely:
1. The grace run does not skip our own accounts: every registered account created before the flip gets the grace month and `founding_member`, ours included.
2. The selection stays as built (mp-530): nothing skips accounts flagged internal or test email domains.

> 2026-09-22 proposed from Lee in the terminal
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (context, decision, why, details)

## mp-543 · Prod's webhook takes every event type from the cutover
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-543.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-543-2.svg
- screen: none (RevenueCat configuration)
- work: pending
- source: Lee in the terminal 2026-09-22
- linked: mp-534

**Context.** mp-534 asked about prod's RevenueCat webhook, which fires only on purchases, renewals and one-off purchases. That is right today: prod has no Entitlement rows yet (checked 22 September), and its webhook only adds bought credits. After the cutover the server decides AI access from the Entitlement row's end date. A row still lapses on its own date, but a refund or a plan change only reaches the server through the event types prod does not hear.

**Question.** When does prod's webhook start hearing every kind of event?

**Decision.** At the prod cutover, the step that puts the new meal-planning server on production, in the same step that deploys the new webhook. Nothing changes on prod before then. Example: after the cutover an athlete on the $24.99 plan who renewed on 1 November is refunded on 5 November; prod hears the refund, and their AI access ends that day instead of on 1 December.

**Why.** Without it, a refunded athlete keeps AI access on the server until the old end date, and the monthly allowance is not forfeited when Pro ends.

**What else was considered.** Switching it on now, while the old credits-only webhook is still on prod, and keeping three event types.

**What it touches.** RevenueCat integration `whintgraa6c9e50e5`, step 6b of `supabase/migrations/cutover/meal_planning/README.md`.

**Details.** Precisely: At the prod cutover, in the same step that deploys the new `revenuecat-webhook`. Nothing changes on prod before then.

Prod has no `user_entitlements` table yet (checked 2026-09-22); after the cutover the server decides AI access from `active_until` in that table.

> 2026-09-22 proposed from Lee in the terminal
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, why, details)

## mp-544 · A giveaway code tags the account
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-544.svg
- svg2: docs/ssot/decisions/images/mealplanning/mp-544-2.svg
- screen: none (algorithm/data)
- work: pending
- source: Lee in the terminal 2026-09-22
- linked: mp-536

**Context.** mp-536 asked whether giveaway Codes should leave a mark. Coach and influencer Codes each record the Code on the account in RevenueCat (mp-535). A giveaway grants 365 days and records nothing.

**Question.** Does a giveaway Code leave a mark on the account?

**Decision.** Yes. Redeeming a giveaway Code records the Code on the account in RevenueCat, the same way coach and influencer Codes do. That lets us count giveaway winners and see whether they later pay. Example: a winner who enters a giveaway Code on 1 October gets 365 days of Pro and carries that Code, so when the year ends we can see whether they subscribe.

**Why.** It makes it possible to count giveaway winners and see whether they later pay.

**What else was considered.** No tag, so winners look like any other promotional grant.

**What it touches.** `redeem-code` handler and its tests.

**Details.** Precisely: Redeeming a giveaway sets `giveaway_code` to the code, the same way the other two work.

Coach and influencer codes set `coach_code` and `influencer_code` on the RevenueCat customer (mp-535).

> 2026-09-22 proposed from Lee in the terminal
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

## mp-545 · The 25 September build ships with the close and ⋯ buttons doing nothing yet
- category: Pro and paywall
- status: approved
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- svg2: docs/ssot/decisions/images/mealplanning/mp-545-2.svg
- screen: Paywall
- source: Lee in the terminal 2026-09-22
- linked: mp-539

**Context.** mp-539 asked what the 25 September store build shows while the close and ⋯ buttons do nothing yet; tickets 16 and 17 give them their behaviour. The close button also shows on the Onboarding paywall, which must not close (mp-493 clause 5).

**Question.** Does the 25 September store build wait until the close and ⋯ buttons work?

**Decision.** No. The build goes to the stores on 25 September as it is, with both buttons showing but doing nothing, and it is not held for tickets 16 and 17. We accept the risk that Apple rejects it for a button that does nothing on a paywall that cannot close. Example: Apple's reviewer taps ⋯ in the 25 September build and nothing opens; the menu works once tickets 16 and 17 land.

**Why.** Lee's call: the submission date matters more, and the buttons get their behaviour when the tickets land.

**What else was considered.** Hiding both until their tickets land, and holding the submission for tickets 15 to 17. The risk taken is an Apple rejection for a button that does nothing on a paywall that cannot close.

**What it touches.** The 25 September store build, `paywall_screen.dart`.

**Details.** Precisely:
1. It ships as it is, with both placeholders showing, and is not held for tickets 16 and 17.

> 2026-09-22 proposed from Lee in the terminal
> 2026-09-22 picture reused from test/features/subscription/presentation/goldens/paywall_light.png
> 2026-09-22 approved by Lee
> 2026-09-22 rewritten in plain words (question, context, decision, details)

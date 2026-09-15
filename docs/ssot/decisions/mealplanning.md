# Decisions: Meal planning and Vana

Feature: mealplanning
Feature name: Meal planning and Vana

## mp-001 · The assistant is called Vana
- category: Vana's voice and openers
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption: The Vana sheet open with her first message and two quick replies.
- screen: Vana chat
- source: synthesis-and-recommendations.md; memory 08-26

**Context.** The app's assistant had gone by three placeholder names. Sage was the early canvas, MealBuddy the Figma concept, Jade the shipped general chat. More screens were about to be drawn and each one needed a name on it.

**Question.** What to call her, once, everywhere.

**Decision.** The assistant is named Vana, taken from Meal-vana, with no "AI" in the name. The one name is used across the app and the prototype.

**Why.** The placeholders were never meant to ship. One name was needed before more screens were drawn against the wrong one.

**What else was considered.** Mel, Endy, or keeping "Mealvana AI". None tied to the brand as directly, and "AI" in the name was unwanted.

**What it touches.** Every Vana surface, persona prompt, content keys.

> 2026-09-14 approved

## mp-002 · One Vana answers everything and picks an intent per exchange
- category: Vana's voice and openers
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_thread_light.png
- caption: The Vana sheet mid-conversation. The same Vana answers whatever the athlete asks.
- screen: Vana chat
- source: spec.md; CONTEXT.md; memory 09-09; Lee on the page 2026-09-13

**Context.** The app once had two assistants. Jade answered general questions from the coach and formula screens, and a separate planner was going to build meal plans. Vana replaced both in name, but the code, the prompts, and some coach-facing copy still carry Jade.

**Question.** Whether there is one assistant or several, and what "one" means when she is reached from different screens.

**Decision.** There is one Vana and no Jade. Every entry point, whether the sheet, the Plan tab, a formula's coach feedback, or the events page, talks to the same Vana with the same tools. She picks an intent per exchange from the prompt, and no classifier call runs before a turn. What differs by entry point is the context she is handed, never who she is. Every context always includes the athlete's full Doll.

**Why.** Two characters would split what the athlete has told the app. A classifier is another model call and another thing to be wrong. Lee, on the page on 2026-09-13: one Vana, Jade retired everywhere, and every context carries the Doll.

**What else was considered.** Keep Jade for general chat and a separate planner for meals, with a classifier routing between them. It lost because the athlete would have to know which assistant to ask, and each would forget what the other was told.

**What it touches.** vana-chat function, chat screen, sheet, persona prompt, tool set, coach formula feedback.

> 2026-09-13 amended by Lee
> 2026-09-14 approved

## mp-003 · The two conversation kinds survive only as a tag
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-003.svg
- screen: none (algorithm/data)
- source: spec.md

**Context.** Vana has two kinds of conversation. A general one opens from the sheet or the Plan tab's note and can be about anything. A meal-planning one starts when the athlete taps New meal plan and builds a week. Once there was one Vana, the two kinds stopped being separate products.

**Question.** Whether the kind should still mean anything at all.

**Decision.** General and meal-planning stay as a tag on each conversation, read by the history list and the opener. Tapping New meal plan, or asking Vana cold from a button, always starts a new conversation rather than continuing an old one. Every past conversation stays listed in history so the athlete can return to it.

**Why.** The opener and the history list need the tag. Lee on 2026-09-13: a cold question or a new plan should feel like a fresh start, not a continuation.

**What else was considered.** Merge the kinds entirely. It lost because the opener and the history list still needed to tell them apart.

**What it touches.** Conversation history, opener selection.

> 2026-09-14 amended by Lee
> 2026-09-14 approved

## mp-004 · The word is "meal" and the week is a "batch"
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: The Plan tab listing this week's meals.
- screen: Plan tab
- source: synthesis-and-recommendations.md

**Context.** The Sage canvas called a library entry a "plate" and the week a plan of plates. The meal library, then about 400 rows, already typed each entry by meal type. Copy for the Plan tab, the pickers and the shopping list was about to be written.

**Question.** Which words the whole feature would use.

**Decision.** A library or user entry is a "meal", never a "plate". The week is a "batch". "Cooking session" appears only when batch cooking is on.

**Why.** The library already used meal types, so "meal" matched the data. One vocabulary keeps copy and code aligned.

**What else was considered.** "Plate", the wording of the earlier Sage canvas. It lost because the data never used it.

**What it touches.** All meal-planning copy and content keys.

> 2026-09-14 approved
> 2026-09-14 picture refreshed at 1.26.0+1, 469da691, replacing test/features/meal_planning/presentation/goldens/plan_confirmed_light.png

## mp-005 · Race fuelling never comes from the model
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-005.svg
- screen: none (algorithm/data)
- source: synthesis-and-recommendations.md

**Context.** Race-day fuelling is the app's core. A deterministic module computes pre, during and post targets from the ratified nutrition specs. Xuan's AI Scenarios document had used race fuelling as the assistant's domain. Trials in June 2025 showed the model calling tools wrongly and passing wrong parameters.

**Question.** What Vana may say about fuelling numbers.

**Decision.** Race-day fuelling numbers come from the deterministic module, never from the model. Vana reaches that module and the athlete's own records through tools: upcoming events, activity history, macro targets, and food suggestions for a session. She presents what a tool returns and never invents a number or a meal.

**Why.** Safety on the numbers, and usefulness on the questions. Lee on 2026-09-13: if an athlete asks what races are coming up, Vana must be able to look at the event list.

**What else was considered.** Xuan's AI Scenarios used race fuelling as the domain. That was rejected on 2026-06-17 on the same safety grounds.

**What it touches.** Persona guardrails, tool set.

> 2026-09-14 amended by Lee
> 2026-09-14 approved

## mp-006 · Vana diagnoses and adds, never runs a questionnaire
- category: Vana's voice and openers
- status: approved
- image: docs/new_mealplanning/figma/05-meal-prep-style.png
- caption: The MealBuddy interview step that was rejected.
- screen: Vana chat
- source: vana-chatbot-update-plan.md

**Context.** The MealBuddy Figma concept opened with a six-step interview. It asked for training schedule, goal, diet and allergies before showing anything. The app already holds all of that from onboarding, the calendar and the integrations.

**Question.** Whether Vana asks any of it again when a plan starts.

**Decision.** Vana never asks for what the app already knows. Before asking anything she uses the context block and her tools. She may ask about things the app cannot know when they matter to the plan, such as who is eating this week or what is in the fridge.

**Why.** Asking for what is on file undoes the feeling that she knows the athlete. Lee on 2026-09-13: use context and tools first, and ask only what they cannot answer.

**What else was considered.** MealBuddy's six-step wizard. It lost because every answer was already on file.

**What it touches.** Persona prompt, opener.

> 2026-09-14 amended by Lee
> 2026-09-14 approved

## mp-007 · The planning opener asks one question first and stays fluid after it
- category: Vana's voice and openers
- status: approved
- image: docs/_archived/mealplanning_prototype/screenshots/figma/02_active_chat.png
- caption: The earlier chat concept the opener grew out of.
- screen: Vana chat
- source: vana-chatbot-update-plan.md; memory 09-03

**Context.** The planning opener is Vana's first turn after the athlete taps New meal plan. The 2026-08-31 version put a week frame and three dinners on screen before the athlete had said anything. Xuan's scenario and her v5 prototype opened with a short read of the week and one question instead.

**Question.** What the first turn shows.

**Decision.** The planning opener writes two or three context sentences and asks one question with label-only chips. No meals appear on the opener turn. The first picker follows whatever the athlete answered, so it need not be dinners. If the athlete asks something unrelated to planning, Vana answers it without recommending meals, and once that thread is done she offers to start picking.

**Why.** Lee ruled the question-first shape on 2026-09-03 and added the fluidity on 2026-09-13: no forced dinner-first, and a side question deserves an answer, not a meal carousel.

**What else was considered.** The 2026-08-31 opener that put a week frame and three dinners on screen. Withdrawn because it decided for the athlete before asking.

**What it touches.** Opener prompts, lifecycle, the presenting eval check.

> 2026-09-14 amended by Lee
> 2026-09-14 approved

## mp-008 · Every opener says the most relevant thing Vana knows
- category: Vana's voice and openers
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption: The sheet at rest on an opener.
- screen: Vana chat
- source: CONTEXT.md; memory 09-11; commit 1dedc493

**Context.** An opener is any first turn Vana writes. The planning opener, the sheet's general opener, and the moment openers before a workout or after one. The memory work gave Vana a full picture of the athlete, but it showed only in replies. First turns still read like a greeting from a bot.

**Question.** What every opener owes the person reading it.

**Decision.** Every opener picks the most relevant thing to say from everything Vana holds: the weather, the race schedule, holidays, what is on screen, and what the athlete has said before. A personal reference is welcome when it is the most relevant thing, not required. An opener never greets.

**Why.** Lee on 2026-09-13: something personal is nice to have, not a must. The opener should weigh all the islands of information and lead with what matters most today.

**What else was considered.** none recorded

**What it touches.** Opener prompt in vana-chat, context builder.

> 2026-09-14 amended by Lee
> 2026-09-14 approved

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

## mp-010 · The intro card was removed
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: DEVIATIONS.md

**Context.** MealBuddy opened with a welcome screen of goal buttons. The plan adapted that into a one-time card at the top of the planning chat saying Vana had already done the homework, with three example chips. It was built the same day the question-first opener landed.

**Question.** Whether both belonged on the first screen.

**Decision.** The one-time "Vana already did the homework" card was built and removed the same evening. The opener does that job.

**Why.** Lee said "we don't need that block". The question-first opener already proves what Vana knows.

**What else was considered.** A dismissible card with three example chips. It lost because the opener already said the same thing.

**What it touches.** Planning chat screen.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

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

## mp-012 · Brevity lives in the prompt, not in a server clamp
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-012.svg
- screen: none (algorithm/data)
- source: memory 09-03

**Context.** To keep planning turns short, the server used to cut each one to two sentences after the model had written it. The trimmed text was what the athlete saw and what was stored. Meanwhile the persona prompt was being rewritten with the per-moment rules above.

**Question.** Where brevity should be enforced.

**Decision.** The server no longer trims planning turns to two sentences. Only an eight-sentence runaway guard remains. The output cap went from 400 to 700 to 900 tokens so the longer moments have room.

**Why.** A clamp trims text after the tokens were paid for, so it saved nothing. The clamped text was also what got stored, so the transcript lost what she said.

**What else was considered.** Keep the clamp and rewrite the persona. It lost because the prompt work would have been invisible on screen.

**What it touches.** chat.ts partsFromSteps, persona.

> 2026-09-14 approved

## mp-013 · Planning turns take six tool steps, general turns eight, four sends per ten seconds
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-013.svg
- screen: none (algorithm/data)
- source: 02-contract.md; walkthrough.md

**Context.** Each Vana turn can call several tools in a row before it answers. Each step is another model call and more tokens. The athlete can also send faster than the server should answer. A planning chat is mostly pickers and chips rather than prose.

**Question.** What budget each turn and each athlete gets.

**Decision.** A planning turn may run six tool steps and a general turn eight. Chat is rate-limited to four requests per ten seconds per athlete. The system prompt is about 900 tokens and tool outputs are kept compact.

**Why.** Cost and brevity in a chat that is mostly widgets.

**What else was considered.** none recorded

**What it touches.** vana-chat.

> 2026-09-14 approved

## mp-014 · Every picker comes with a sentence and no narration before a tool call
- category: Vana's voice and openers
- status: approved
- image: test/features/meal_planning/presentation/goldens/meal_picker_light.png
- caption: A meal picker in chat, always introduced by text.
- screen: Vana chat
- source: 05-flutter-feature.md

**Context.** A meal picker is the carousel of meals Vana puts in the chat. The day-guidance tool is a deterministic server function: given a date, it reads that day's workouts, the macro budget, and the library's rest-day and race-week rules, and returns what to eat and why as data. Vana phrases that data and never computes it. In the walkthrough some pickers arrived with no text, "Other options" came back bare, Vana wrote "I need to check" before calling tools, and day questions sometimes got a guess instead of the tool.

**Question.** What a turn with a tool must look like.

**Decision.** A meal picker is never sent bare and "Other options" always carries text. For a question about a specific day, Vana calls the day-guidance tool rather than guessing. She never narrates before a tool call.

**Why.** Bare widgets and "I need to check…" narration read badly in the walkthrough.

**What else was considered.** none recorded

**What it touches.** Persona prompt on server and prototype.

> 2026-09-14 amended by Lee
> 2026-09-14 approved

## mp-015 · Status lines replace narration and there is no fake progress
- category: Vana's voice and openers
- status: approved
- image: docs/new_mealplanning/figma/14-generating.png
- caption: MealBuddy's progress ring, which was rejected.
- screen: Vana chat
- source: vana-chatbot-update-plan.md

**Context.** While a tool runs the athlete waits a few seconds and sees nothing. MealBuddy filled that gap with a progress ring showing a percentage. Early Vana filled it with prose narrating what she was about to do.

**Question.** What the athlete sees during a tool call.

**Decision.** While a tool runs, a short content line per tool sits beside a mini avatar, such as "Finding options that fit your week…". Pre-tool narration is dropped from the transcript. There is no percentage ring.

**Why.** MealBuddy's ten percent ring was fake. Narrating tool calls wastes tokens.

**What else was considered.** A generic thinking line, which lost as less informative. A progress ring, which lost because it had no real number behind it.

**What it touches.** Message card status row, status content keys.

> 2026-09-14 approved

## mp-016 · A choice-only step keeps its sentence in the stored transcript
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: ticket 09; memory 09-11

**Context.** The rule above drops text written before a tool call when the transcript is stored. An opener is a sentence or two followed by a choice question, and the choice question is itself a tool. So on reload the opener's prose vanished while the live stream had shown it. Found while building the moments.

**Question.** How the rule treats a step whose only tool is a question.

**Decision.** A step whose only tool is a choice question keeps its text when the transcript is stored.

**Why.** The no-narration rule dropped the opener's prose on reload while the live stream had shown it.

**What else was considered.** none recorded

**What it touches.** chat.ts partsFromSteps.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-017 · Unknown part kinds are dropped, not errors
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: 02-contract.md

**Context.** The server streams a conversation to the app as message parts. Text, a picker, a choice question, a receipt, and so on. New part kinds get added on the server as features land, and older app versions stay in the field for months. The coach chat had already met this problem.

**Question.** What an older app does with a part it has never seen.

**Decision.** The app ignores any message part kind it does not know and renders the rest of the message. This is the same rule the coach chat uses.

**Why.** A newer server must never break an older app.

**What else was considered.** Fail the message on an unknown kind. It lost because every server release would break shipped clients.

**What it touches.** Part parser, shipped clients.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-018 · The chat model is Haiku, with cost recorded per eval case
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-018.svg
- screen: none (algorithm/data)
- source: 03-backend.md; walkthrough.md; spec.md

**Context.** Every Vana turn is a model call, and a planning conversation is many turns. The prototype defaulted to Sonnet, the larger and dearer model. The personalisation evals run by hand against dev and report pass or fail.

**Question.** Which model runs the chat and how a later change would be argued.

**Decision.** The default chat model is Claude Haiku 4.5 through the AI Gateway, and embeddings use text-embedding-3-small. Sonnet is only an environment override. Every eval case records its input and output tokens.

**Why.** Cost per turn. A later model decision should be made with numbers rather than a feeling.

**What else was considered.** Sonnet by default, as the prototype did. It lost on cost per turn.

**What it touches.** All Vana model calls, eval scripts.

> 2026-09-14 approved

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

## mp-020 · The Doll is a view, not a copy
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-020.svg
- screen: none (algorithm/data)
- source: spec.md; memory 09-09

**Context.** The Doll is the name for everything Vana knows about a person. Most of it already lives somewhere. The user record, the calendar, the events, the meal votes, the onboarding survey. One option was a separate profile table for Vana with those fields copied in.

**Question.** Whether Vana keeps her own copy.

**Decision.** Everything Vana knows about a person is assembled on the server at request time from the records that already own it. Only the memory table belongs to the Doll. The assembled block is short: the most relevant facts for this turn, nothing the prompt does not use. Anything deeper is reached through tools, not carried in the block.

**Why.** No profile field is stored twice, so nothing drifts. Lee on 2026-09-14: the view must not be too large or carry extraneous data, and a full set of tools covers the rest.

**What else was considered.** A separate profile or preferences store copied from the source records. It lost because a copy drifts.

**What it touches.** vana-chat context builder.

> 2026-09-14 rewritten from Lee's words
> 2026-09-14 approved

## mp-021 · Both conversation modes read the full Doll
- category: Vana's memory
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: spec.md; archive ticket 03

**Context.** Planning conversations got the full context block. General conversations got a first name and today's date, and the prompt opened by saying nothing was preloaded. So "what's my workout tomorrow" in the sheet needed a tool call the model might not make. That was the real "she doesn't know me".

**Question.** Whether general mode gets the same picture.

**Decision.** General mode gets the same context block planning mode gets, plus LIKES from meal votes, GOALS from the onboarding survey and SITUATION for what is on screen. The general prompt's "nothing is preloaded" opening was removed.

**Why.** General mode carried only a first name and today's date, so Vana answered as a stranger. "What's my workout tomorrow" should answer without a tool call.

**What else was considered.** Leave general mode relying on tool calls the model may or may not make. It lost because the model often did not make them.

**What it touches.** systemPrompt, buildAthleteContext.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-022 · A Memory is one margin-note sentence
- category: Vana's memory
- status: approved
- image: test/features/meal_planning/presentation/goldens/memory_list_light.png
- caption: The "What Vana knows" list, one sentence per row with source and date.
- screen: Vana settings
- source: spec.md; CONTEXT.md

**Context.** Vana's store held mixed records. Settings, summaries, preferences and meal feedback sat together with no rule about what belonged. Two writers were about to be added, the model on its own and a background extractor. Both needed the same test for what to keep.

**Question.** What qualifies as a Memory.

**Decision.** A Memory is one sentence a good dietitian would write in the margin of the person's file, and only if it changes how Vana plans next time. Not what was asked, not this week's plan, not anything already a Fact.

**Why.** One literal rule keeps the store small and useful. The extractor and the model share it.

**What else was considered.** Store preferences, summaries and meal feedback as one mixed record. It lost because nothing then had a clear owner or a limit.

**What it touches.** Extractor prompt, persona prompt, user_memories.

> 2026-09-14 approved

## mp-023 · Meal votes are Facts read in place, never moved into Memory
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-023.svg
- screen: none (algorithm/data)
- source: spec.md; memory 09-09

**Context.** Meal detail has thumbs up and down. Those votes already live in the meal feedback table and drive search. Lee had earlier floated a new meal preferences table for Vana. The Formula Kit already has its own fuelling-product preferences with screens.

**Question.** Where votes live and how Vana reads them.

**Decision.** Thumbs votes on meals are Facts, read every turn as a LIKES line from the existing meal feedback table. There is no new preferences table. The fuelling-product preferences and their screens are untouched.

**Why.** Formula Kit keeps working and nothing is stored twice. Lee reversed his own earlier idea of a meal preferences table.

**What else was considered.** A new meal preferences table. It lost because the votes already existed and a second copy would drift.

**What it touches.** Context builder, meal feedback table.

> 2026-09-14 approved

## mp-024 · Memory has three writers
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-024.svg
- screen: none (algorithm/data)
- source: spec.md

**Context.** Vana had a remember tool she could call when the athlete said something worth keeping. In practice she never called it. The only thing writing Memories was the weekly debrief. So the store stayed empty for most people.

**Question.** Who writes Memories, and when.

**Decision.** Memories are written three ways. By an explicit "remember this" from the athlete, by the model on its own when the margin-note rule is met, and by a background extraction after a conversation ends.

**Why.** The remember tool alone was never called. Only the weekly debrief wrote anything.

**What else was considered.** A scheduler that extracts on a timer, which lost as needing a cron. Extraction on every turn, which lost on cost.

**What it touches.** vana-chat, extractor, memory table.

> 2026-09-14 approved

## mp-025 · An explicit "remember" always calls the tool
- category: Vana's memory
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: archive ticket 05

**Context.** The margin-note rule tells Vana to skip a note that is already known. In testing the athlete said "remember Wednesdays are long days" and a Wednesday note was already in her context. So she skipped the request and said nothing was saved.

**Question.** Whether the rule applies when the athlete asks outright.

**Decision.** When the athlete asks, Vana calls remember every time and lets the server decide whether it is new or a refresh. The margin-note rule applies only to notes she takes on her own.

**Why.** A Wednesday note already in the context made her skip an explicit request.

**What else was considered.** One rule for both triggers. It lost because it made her ignore the athlete.

**What it touches.** Persona, remember tool description.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

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
- screen: Vana settings
- source: spec.md

**Context.** When the athlete says "remember this", a small card in the chat confirms it. The background extraction now learns things nobody asked her to keep. Vana settings has a list of everything she holds.

**Question.** Whether learning something quietly should be shown in the chat.

**Decision.** Extraction produces no card and no mention in the conversation. The in-chat "remembered" card stays only for the explicit remember tool. The flat list in settings is the audit trail.

**Why.** Vana should read as attentive, not surveilling.

**What else was considered.** Show a card each time something is learned. It lost because it reads as being watched.

**What it touches.** Vana chat, Vana settings.

> 2026-09-14 approved

## mp-028 · Memories are deduped on write at 0.95 similarity
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-028.svg
- screen: none (algorithm/data)
- source: spec.md; archive ticket 05

**Context.** With three writers, the same note can arrive more than once in slightly different words. On dev the debrief learning had been written twice. Each Memory is stored with an embedding, a numeric fingerprint of its meaning.

**Question.** How to stop the list filling with repeats.

**Decision.** A new sentence within 0.95 embedding similarity of an existing Memory refreshes that row's confirmed date instead of inserting. If the embedding call fails the note is written anyway. Settings keep one row per key and episodes one row per conversation.

**Why.** The store must not fill with the same note. A duplicate beats a lost note.

**What else was considered.** Exact-text dedupe. It lost because the same fact rarely arrives in the same words.

**What it touches.** memory.ts rememberFact, recall.

> 2026-09-14 approved

## mp-029 · Conflicting Memories both stay
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-029.svg
- screen: none (algorithm/data)
- source: spec.md

**Context.** People change. An athlete may say they are vegetarian and months later say they eat fish. Both sentences can end up in the store. A full answer would detect the contradiction and mark the older note as superseded.

**Question.** Whether to build that now.

**Decision.** There is no contradiction handling. Conflicting Memories both stay, each with its date, and the model weighs recency when it reads them.

**Why.** A supersedes chain waits until a real user hits a real contradiction.

**What else was considered.** Contradiction detection and a supersedes mechanism. It lost as work for a problem nobody had yet.

**What it touches.** memory.ts.

> 2026-09-14 approved

## mp-030 · Behaviour never writes a Memory
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-030.svg
- screen: none (algorithm/data)
- source: spec.md; memory 09-09

**Context.** The app sees what the athlete does with a plan. Meals swapped out, meals skipped, the same meal logged again and again. Those patterns could be turned into preferences without anyone saying a word. The weekly debrief already asks how the week went and writes from the answers.

**Question.** Whether silent behaviour should write Memories too.

**Decision.** Swaps, skips and repeated logs never write Memories. The weekly debrief is the only behaviour-derived writer.

**Why.** The debrief keeps the person in the loop. Silent inference would not.

**What else was considered.** Infer preferences from logging patterns. It lost because the athlete would never know why Vana changed.

**What it touches.** Memory writers.

> 2026-09-14 approved

## mp-031 · Debrief learnings feed the next plan
- category: Vana's memory
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: DEVIATIONS.md

**Context.** After a plan week ends, Vana's next opener asks how it went. The answers are recorded as a debrief. Xuan's spec asks that the app learn from outcomes, not just collect them.

**Question.** Whether the next plan reacts to what the athlete said.

**Decision.** Recording a debrief writes a debrief row plus one to three Memories marked as from the debrief. A LAST WEEK line in the context makes the next first proposal react, for example "kept the two you repeated, dropped the salmon".

**Why.** Xuan's spec asks for learning from outcomes.

**What else was considered.** none recorded

**What it touches.** recordDebrief, context builder.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-037 · "What Vana knows" is one flat list and memory kinds stay in code
- category: Vana's memory
- status: approved
- image: test/features/meal_planning/presentation/goldens/memory_list_light.png
- caption: The flat list, newest first, no kind tags.
- screen: Vana settings
- source: spec.md; archive ticket 08

**Context.** Vana settings has a screen listing what she holds about the athlete. In code, Memories come in kinds. Plain notes, keyed settings such as batch cooking and coverage, and episodes. The glossary had also called some of them "Decisions". Facts such as allergies live in their own screens.

**Question.** How much of that structure the athlete should see.

**Decision.** Settings shows every Memory newest first as a sentence with its source and date, with no kind tag, and any row can be deleted. Keyed settings appear as sentences. Episodes are excluded. Facts are edited where they live. The glossary word "Decision" is retired.

**Why.** The athlete should see and remove anything Vana holds without learning the internal kinds.

**What else was considered.** Group by kind, which lost as exposing internals. List Facts too, which lost because Facts already have their own screens.

**What it touches.** Vana settings screen, watchMemories.

> 2026-09-14 approved

## mp-039 · A season line and a budget clause exist, grocery deals do not
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-039.svg
- screen: none (algorithm/data)
- source: vana-chatbot-update-plan.md

**Context.** The spec's marquee moment was Vana planning around this week's grocery deals. MealBuddy showed a "gathering coupons" step. There is no pricing data source, and at the time no home location on the profile either. Season and budget could be done from what the app has.

**Question.** Which of these context lines to build without data.

**Decision.** The context carries a SEASON line from a static month table and a BUDGET clause if the athlete ever said "keep it under N dollars". Grocery deals, coupons and a list cost estimate are not built.

**Why.** There is no pricing data source. Revisit if a static price table lands.

**What else was considered.** MealBuddy's "gathering coupons" and recipe prices. They lost because there was nothing to gather.

**What it touches.** season.ts, context.ts.

> 2026-09-14 approved

## mp-040 · No new machine learning
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-040.svg
- screen: none (algorithm/data)
- source: spec.md; memory 09-09

**Context.** The Voodoo Doll grilling on 09-09 asked how far personalisation should go. Memories are found by embedding similarity, which already works. A trained model of each athlete's preferences would need many weeks of data per person.

**Question.** Whether "she knows me" needs anything more than what is in place.

**Decision.** Embedding recall stays the only retrieval pattern. No trained preference model and no change to how the model is orchestrated.

**Why.** The pattern in place already works, and a trained user model needs data no user has.

**What else was considered.** A trained preference model. It lost for lack of training data.

**What it touches.** Memory recall.

> 2026-09-14 approved

## mp-041 · Coach mode never reads an athlete's Doll
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-041.svg
- screen: none (algorithm/data)
- source: spec.md

**Context.** Coaches use the app too, with their own portal and a chat with each athlete. A coach could in principle ask Vana about an athlete and get answers built from that athlete's Facts and Memories.

**Question.** Whether the Doll extends to coaches in this work.

**Decision.** Coach mode is out of scope. A coach's Vana does not see the athlete's Facts or Memories.

**Why.** Scope and privacy.

**What else was considered.** Extend the Doll to coaches. It lost on privacy and on scope.

**What it touches.** Coach portal.

> 2026-09-14 approved

## mp-042 · Onboarding is untouched, with no likes step
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-042.svg
- screen: none (algorithm/data)
- source: spec.md

**Context.** Onboarding already asks the survey questions that give Vana her GOALS line. One idea was a new onboarding step asking what foods the athlete likes so the first plan lands better. Meal votes already give a LIKES line.

**Question.** Whether onboarding changes for Vana.

**Decision.** Onboarding does not change. LIKES come from meal votes and GOALS from the existing survey. Vana never asks for likes.

**Why.** The app already holds the data.

**What else was considered.** Add a likes step to onboarding. It lost because votes already carry the same signal.

**What it touches.** Onboarding.

> 2026-09-14 approved

## mp-043 · The Situation travels with each message and is never stored
- category: Situation awareness
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-043.svg
- screen: none (algorithm/data)
- source: spec.md; archive ticket 04

**Context.** When the athlete opens Vana from a screen and asks "is this enough", "this" means whatever is on that screen. A ride, a meal, a day. The server has to learn that somehow. It could be stored as the athlete moves, or the client could write a sentence, or the client could send only ids.

**Question.** How the server learns what is on screen.

**Decision.** The client sends the route plus the primary entity id, date and slot with each message. The server resolves those ids into one sentence. Clients never send names or free text and nothing is written to any table.

**Why.** Vana answers about what is in front of the athlete without the client leaking or persisting screen state.

**What else was considered.** Store the current screen server-side, which lost as state that goes stale. Let the client compose the text, which lost because the client would be sending names.

**What it touches.** Every screen with a situation scope, situation.ts resolver.

> 2026-09-14 approved

## mp-044 · Fifteen screens name what is in view, the rest send only their route
- category: Situation awareness
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-044.svg
- screen: none (algorithm/data)
- source: spec.md; archive ticket 04

**Context.** Not every screen has a thing in view worth naming. The Plan tab has a plan and a date. Meal detail has a meal. The fuel log has an activity. Settings has nothing.

**Question.** Which screens report an entity and which report only where the athlete is.

**Decision.** The Plan tab sends date and plan, meal detail sends the meal, fuel log and session plan send the activity, event screens send the event, meal-log screens send date and slot, and the main tabs send the date. Every other screen sends its route alone.

**Why.** Fifteen screens have something in view worth naming. The rest only need their route.

**What else was considered.** none recorded

**What it touches.** Fifteen wired screens.

> 2026-09-14 approved

## mp-045 · The session screen is the activity and the Plan tab is the meal plan
- category: Situation awareness
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-045.svg
- screen: none (algorithm/data)
- source: archive ticket 04; memory 09-09

**Context.** Two things are called a plan. The session screen shows an activity's fuel plan and its route is named plan. The meal-planning Plan tab is a segment of the Food tab. The spec's screen table had the two the wrong way round, so the fuel plan would have reported a meal plan.

**Question.** Which route means which.

**Decision.** The routes named plan and current plan resolve to an activity's fuel plan. The meal-planning Plan tab is the food route with the plan tab selected.

**Why.** The spec's screen table had the two routes the wrong way round.

**What else was considered.** none recorded

**What it touches.** Situation table.

> 2026-09-14 approved

## mp-046 · A scoped report counts only while its route is on top
- category: Situation awareness
- status: approved
- image: docs/ssot/decisions/images/mealplanning/settings.png
- caption:
- screen: Settings
- source: ticket 06

**Context.** A screen with something in view reports it when it appears. Most screens, settings among them, report nothing. So the last report stood until another screen replaced it. From settings, Vana went on speaking about the fuel log the athlete had left.

**Question.** How long a screen's report should count.

**Decision.** The host tells the controller which route is on top. A scoped report is used only while that route is on top. Anywhere else the Situation is the route alone. A scope reports again when its route comes back, so meal A to meal B and back reads as A again.

**Why.** Without it, settings kept speaking for the last scoped screen, such as the fuel log.

**What else was considered.** Let the last report stand until replaced. It lost because unscoped screens never replace it.

**What it touches.** Companion host, situation controller.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-047 · The tab shell speaks for every main tab, and a tab's own scope wins
- category: Situation awareness
- status: approved
- image: docs/ssot/decisions/images/mealplanning/timeline-launcher.png
- caption: The Timeline tab, one of the main tabs the shell reports for.
- screen: Main tabs
- source: ticket 06

**Context.** Timeline, Food, Learn and the other main tabs all share one route. Switching tabs does not change it. So the rule above could not tell Food from Learn, and moving from Food to Learn left Food speaking.

**Question.** Who reports for a tab.

**Decision.** The tab shell reports for each main tab as the athlete switches. A tab with its own scope, such as the Plan tab, reports after the shell and wins.

**Why.** Moving from Food to Learn no longer leaves Food speaking.

**What else was considered.** none recorded

**What it touches.** Main tab shell, Timeline, Learn.

> 2026-09-14 approved

## mp-048 · The last screen keeps speaking for 30 minutes and Vana routes say nothing
- category: Situation awareness
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-048.svg
- screen: none (algorithm/data)
- source: archive ticket 04

**Context.** Opening Vana means leaving the screen you want to ask about. The sheet and the full-screen chat are routes of their own. If a Vana route reported itself, every question would be about Vana. If a report lived forever, an hour-old screen could answer a question about today.

**Question.** What opening Vana does to the Situation.

**Decision.** Opening a Vana route does not clear the Situation, and Vana routes report nothing. A 30-minute staleness cut-off stops an hour-old screen answering.

**Why.** The sheet and chat open over the screen the athlete cares about.

**What else was considered.** Clear on every route change. It lost because opening Vana is itself a route change.

**What it touches.** Situation controller.

> 2026-09-14 approved

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
- screen: Calendar sheet over the Plan tab
- source: ticket 06

**Context.** Screens open dialogs and bottom sheets over themselves. The calendar sheet over the Plan tab is one. The launcher floats above the screen, so it floated above those modals too, and above Vana's own sheet.

**Question.** What the launcher does while a modal is up.

**Decision.** A navigator observer hides the launcher under any dialog or bottom sheet, Vana's own sheet included.

**Why.** The launcher should not float over a modal.

**What else was considered.** none recorded

**What it touches.** VanaCompanionObserver.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

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

## mp-058 · One ambient conversation per person per day, per device
- category: The sheet and launcher
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_thread_light.png
- caption: The day's conversation continuing in the sheet.
- screen: Vana sheet
- source: spec.md; ticket 06

**Context.** The sheet opens a general conversation. The athlete may open it in the morning, close it, and open it again at lunch. Each open could start fresh or continue. The pointer to the current conversation could live on the phone or on the server. And a sheet closed before the first message arrives could lose its conversation.

**Question.** What one open of the sheet continues.

**Decision.** The sheet continues the same general conversation all day and starts a new one the next day. The pointer is stored on the device, so a second phone opens its own conversation. The host adopts the server's id for the day's first conversation, so closing the sheet before the first event still keeps it.

**Why.** A follow-up an hour later should carry the morning's context. A fast close should not orphan the conversation.

**What else was considered.** A new conversation per open, which lost the morning's context. A server-held pointer shared across devices, which lost as more machinery than the case needed.

**What it touches.** Ambient conversation controller, companion host.

> 2026-09-14 approved

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

## mp-061 · The sheet is a popup route and the page underneath keeps its state
- category: The sheet and launcher
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption: The sheet raised over the home screen, which stays legible.
- screen: Vana sheet over any screen
- source: ticket 06; vana-sheet.md

**Context.** The sheet rises over whatever screen the athlete was on. It could be drawn as an overlay inside each screen, or as a route of its own on top of the app. The screen underneath has scroll position, a half-filled form, an open tab.

**Question.** How the sheet is hosted so closing it returns the athlete exactly where they were.

**Decision.** The sheet is a popup route on the root navigator. The page underneath keeps its state and scroll. A tap on the scrim and the system back gesture both pop the sheet.

**Why.** Closing must return the athlete exactly where they were.

**What else was considered.** An overlay drawn inside each screen. It lost because every screen would have to host it.

**What it touches.** VanaSheetRoute.

> 2026-09-14 approved

## mp-062 · Every dismissal condenses into the launcher's centre over about 470 ms
- category: The sheet and launcher
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_closed_light.png
- caption: The launcher the sheet condenses back into.
- screen: Vana sheet mid-dismiss
- source: tickets 06, 08; vana-sheet.md

**Context.** The sheet can be closed four ways. Dragging the grabber down, the close button, tapping the scrim, and the system back gesture. A bottom sheet usually slides off the bottom of the screen. The spec said the sheet condenses into "the launcher's corner", and the export's transform origin sits at the launcher's centre.

**Question.** What every close looks like.

**Decision.** Grabber, close button, scrim and system back all condense the sheet into the launcher over about 470 ms, with the origin at the launcher's centre. The rise on open is 360 ms. The sheet never slides off-screen.

**Why.** The sheet is the launcher opened up, and what the athlete was reading ends where the thing that brings it back lives.

**What else was considered.** Slide down off-screen on some paths, which lost because the motion would say the sheet went somewhere else. Condense to the screen corner, which lost to the export's numbers.

**What it touches.** VanaSheetRoute.

> 2026-09-14 approved

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
- screen: Vana chat
- source: vana-chatbot-update-plan.md

**Context.** MealBuddy lets the athlete edit an earlier message and rerun from there. Conversation history is stored on the server. Picks made after the edited turn would be orphaned.

**Question.** Whether to adopt the edit and how the draft follows it.

**Decision.** Every assistant row stores a plan snapshot. Editing an athlete turn deletes messages from that turn on, restores the draft from the snapshot, and resends. A rewind past the first turn empties the draft. The endpoint is server-side.

**Why.** MealBuddy's single best interaction idea. History is server-owned.

**What else was considered.** Client-side truncation, which fights the server-owned history, or leaving orphaned picks, which desyncs the draft.

**What it touches.** Rewind action, message metadata.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-139 · Day notes are precomputed in one call for seven days and refreshed in the background
- category: Plan tab
- status: approved
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: The day note card at the top of the Plan tab.
- screen: Plan tab
- source: plan-tab-v2.md; 03-backend.md

**Context.** The Plan tab opens with a day note from Vana at the top. Generating it while the page loaded cost about five second page loads. Notes go stale when the plan is edited.

**Question.** When notes are generated and who waits for them.

**Decision.** One Haiku call writes all seven day notes on confirm. A plan edit marks them stale and regenerates them in the background, never awaited. A stale note is served instantly and the Plan tab re-polls after 7 seconds. If a day has no note at all it is generated inline. Numbers come from context and the model only phrases.

**Why.** Awaiting it inline cost about five second page loads.

**What else was considered.** Per-visit generation, which pays the five seconds every time, or generating on the client, which makes the client pay for a model call it cannot see.

**What it touches.** daynotes.ts, vana-day-notes, Plan tab day note card.

> 2026-09-14 approved
> 2026-09-14 picture refreshed at 1.26.0+1, 469da691, replacing test/features/meal_planning/presentation/goldens/plan_confirmed_light.png

## mp-144 · One thumb per person per meal, and a thumbs down means Vana will not suggest it again
- category: Meals tab and library
- status: approved
- image: docs/ssot/decisions/images/mealplanning/meal-detail.png
- caption:
- screen: Meal detail
- source: recipe-directions-and-cooking-mode.md; 05-flutter-feature.md
- work: pending

**Context.** Opening a meal from the Meals tab or a plan tile shows the meal detail screen. The app already had a favourite flag on saved recipes, which marks a meal the athlete wants to keep. Vana's planner needed a separate signal for meals the athlete does not want offered again.

**Question.** How a thumb vote should be stored and what it should do to future suggestions.

**Decision.** 1. Meal feedback holds one vote per person per meal. Tapping the same vote twice clears it. The detail screen shows the thumbs optimistically, and a thumbs down shows a note that Vana will not suggest that meal again.
2. A disliked meal is filtered out of suggestions but still visible when browsing. A thumbs up adds 0.10 to the meal's search score.
3. A signed-in admin sees a comment box on every meal page. They can say whether it is a good recipe and why, and each comment lands in a table for the team to review. Athletes never see the box.

**Why.** A quality signal distinct from the saved-meal favourite, and the one structured meal preference the planner honours. Lee on 2026-09-14: admins need to comment on recipes from the page and have it reach the database.

**What else was considered.** Reusing the recipe favourite flag. It lost because a favourite says "keep this" and cannot say "never again".

**What it touches.** set_meal_feedback, search_meals, meal detail controller. Admin flag, meal_reviews table, meal detail screen.

> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee

## mp-145 · Meal icons are classified and stored, but not drawn
- category: Meals tab and library
- status: approved
- image: test/features/meal_planning/presentation/goldens/meal_icon_glyphs_grid.png
- caption: The 23 meal icon glyphs.
- screen: Meals tab
- source: plan-tab-v2.md; 02-contract.md
- work: pending

**Context.** Every meal card and plan tile shows a small glyph beside the name, and the glyph stands in when a meal has no photo. The fuel log already had a set of 12 food icons. The meal library needed finer distinctions, and many meals have no photo at all.

**Question.** How each meal gets its glyph without a model call and without blank cards.

**Decision.** 1. The 23-key classifier stays and the key is stored on library, saved and plan meals, copied along on add and swap, so the data is there when it is wanted.
2. Icons are not drawn on tiles, cards, the plan bar or the review sheet. Tiles keep their shape without the glyph.
3. A meal with no photo shows a plain placeholder, not an icon.

**Why.** Lee on 2026-09-14: the icons clutter the UI. The classification is cheap to keep and costs nothing unseen.

**What else was considered.** Model-chosen icons, which would cost a call per meal and could drift. Extending the 12 food icons, which lost because the fuel-log set was built for logged foods rather than dishes.

**What it touches.** MealIconClassifier, KyleFoodIcon, meal cards. Meal card, plan tile, plan bar, review sheet.

> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-15 approved by Lee

## mp-146 · Directions carry a recorded origin and a badge
- category: Recipes and cooking
- status: approved
- image: docs/ssot/decisions/images/mealplanning/meal-detail.png
- caption:
- screen: Meal detail
- source: memory 09-01; 05-flutter-feature.md

**Context.** The meal library cites a source page for most meals, but that citation is attribution, not a recipe. Only 14 of the 247 cited pages had steps a machine could read. The rest of the cooking steps had to come from somewhere else, and some are AI-generated.

**Question.** How the meal detail screen should tell the athlete where the steps came from.

**Decision.** Every library row records where its steps came from: the source verbatim, an alternate source, a simple assembly, or AI-generated. The detail screen labels steps by origin. AI-generated steps carry a sparkle with a tooltip. Verbatim steps read "as published by X" with a link to the original. Macros sit in a disclosure marked approximate.

**Why.** Honesty about where cooking instructions came from.

**What else was considered.** Paraphrased directions with no record of origin. It lost because the athlete could not tell a publisher's method from a model's guess.

**What it touches.** meal_library, meal detail screen, cooking mode.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-165 · The What's New sheet is gated by a content key
- category: Feedback loop
- status: approved
- image: docs/ssot/decisions/images/mealplanning/timeline.png
- caption:
- screen: Home shell
- source: memory 09-08

**Context.** The app needed a way to tell athletes what changed. The app already has a content system whose strings can be updated on the server without a release.

**Question.** How a What's New announcement should be triggered and whether it needs a new build each time.

**Decision.** A glass What's New sheet shows when the content system's version number is higher than the one stored on the device. It shows on phones only, when the main tabs screen first builds. Announcing again means bumping the content version, not shipping a release.

**Why.** Announce changes without shipping.

**What else was considered.** none recorded

**What it touches.** WhatsNewSheet, app content.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-197 · MealBuddy's skin is rejected, only its interactions are adopted
- category: Design system
- status: approved
- image: docs/new_mealplanning/figma/16-plan-detail-modal.png
- caption: A MealBuddy frame, whose look was not adopted.
- screen: Vana chat
- source: vana-chatbot-update-plan.md

**Context.** MealBuddy is a Figma concept file that explored a meal-planning assistant with a mascot, a cream and navy palette, coloured chip outlines and iOS-style chrome. The app already has the Kyle design system and a working prototype with Kyle styling.

**Question.** How much of MealBuddy should come into the app.

**Decision.** No mascot, no cream and navy palette, no coloured chip outlines, no iOS-only chrome. Kyle tokens are the only registry. New design-bearing widgets are built once in the shared library with a spec written first. When MealBuddy and the Kyle prototype disagree visually, the prototype wins.

**Why.** The Figma is a concept file, not a skin. This ships on iOS, Android and Web.

**What else was considered.** Adopting the MealBuddy look. It lost because it is a concept, not a system, and its chrome is iOS-only.

**What it touches.** lib/shared/widgets/kyle_design/, design component specs.

> 2026-09-14 approved

## mp-209 · Jade is retired everywhere, including coach formula feedback
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Coach formula feedback, Vana chat
- source: Lee on the page 2026-09-13, amending mp-002

**Context.** Jade was the earlier name for the assistant. Her name survives in a compatibility route the shipped app still calls, in database views, in some prompts, and in the copy the coach sees when giving feedback on a formula. The one-Vana decision made her redundant, but nothing said when the last traces go.

**Decision.** Every mention of Jade goes: the route, the functions, the prompts, the database names once the shipped app no longer needs them, and the coach-facing copy in formula feedback. The coach formula feedback is a Vana conversation like any other entry point.

**Why.** Lee ruled it on the page on 2026-09-13. One assistant with two names reads as two assistants.

**What else was considered.** Leave the compatibility route and copy in place until a later cleanup. It lost because the copy is athlete-facing and coach-facing today.

**What it touches.** jade-chat route and alias, jade_* views, persona prompts, coach formula feedback copy, content keys.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-212 · Vana has tools for the athlete's own records
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: Lee on the page 2026-09-13, amending mp-005

**Context.** The app holds the athlete's events, activity history, macro targets, logged food, and the deterministic fuelling module. Some of that is written into every turn's context block. The rest can only reach Vana if a tool exposes it. Today the tool set covers meal search, memory, settings, weather and the day-guidance function.

**Question.** How much of the athlete's record Vana can look at on request.

**Decision.** Vana gets a tool for each of the athlete's records that a question could need: the upcoming event list, activity history, macro targets, and food suggestions for a given session such as a long run. The deterministic functions behind the app are exposed as tools rather than rebuilt in the prompt. She calls a tool before answering a question those records can settle.

**Why.** Lee on 2026-09-13: if an athlete asks what races are coming up, Vana should have access to the event list. Asking the athlete for what the app already stores reads as not knowing them.

**What else was considered.** Put more of the record into the per-turn context block. It lost because the block already costs about 1.5k tokens and most questions never need most of it.

**What it touches.** vana-chat tool set, context builder, event and activity queries.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-213 · A side question gets an answer, then an offer to resume planning
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: Lee on the page 2026-09-13, amending mp-007

**Context.** During a planning conversation the athlete may ask something unrelated, such as what the weather will be for Saturday's ride. The shipped prompt treated every turn in a planning conversation as a planning turn, so the answer came with a meal carousel attached.

**Question.** What happens when the athlete steps off the planning path.

**Decision.** When the athlete asks something unrelated to planning, Vana answers it fully and shows no meals. When that thread is done, she asks whether they are ready to pick meals. The plan bar keeps the draft as it was.

**Why.** Lee on 2026-09-13: there should be some fluidity. A question deserves an answer, not a redirect.

**What else was considered.** Keep every turn in a planning conversation on the planning rails. It lost because it made Vana ignore the question.

**What it touches.** Persona prompt, planning intent rules, picker chips.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-214 · Vana is short and to the point, without a sentence count
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: Lee on the page 2026-09-13, rejecting mp-011

**Context.** The shipped persona once capped every turn at two sentences and read as clipped. A later contract set a length per moment: two sentences when picking, four when presenting with one athlete fact, uncapped when explaining. Lee rejected that contract as too rigid.

**Question.** How to keep Vana brief without counting sentences.

**Decision.** Vana gets to the point and leaves out anything that does not help. No sentence counts and no required athlete fact per turn. A milestone may carry one exclamation. Emoji are banned everywhere. Minimums framing, no weight talk, and medical referrals stay.

**Why.** Lee on 2026-09-13: convey short and to the point without strict guidelines, and ban emoji.

**What else was considered.** The per-moment sentence caps. They lost because a number in the prompt made her count instead of think.

**What it touches.** Persona prompt core.

> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-218 · The context block has a token budget and a test that enforces it
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-218.svg
- screen: none (algorithm/data)
- source: Lee on the page 2026-09-14, amending mp-020

**Context.** The context block is assembled on every turn from the athlete's records. Nothing today measures how large it is or whether every field in it is used by a prompt. It has grown as features were added, and it is the main cost of a turn.

**Question.** How to keep it short on purpose rather than by accident.

**Decision.** The context block has a token budget. A test builds the block for representative athletes, counts the tokens, and fails when the count passes the budget or when the block carries a field no prompt reads. The budget number is set when the test lands and recorded here.

**Why.** Lee on 2026-09-14: test that this view is not too large and is not sending extraneous data. It should be short and compact, giving the most relevant information.

**What else was considered.** Trust the builder and review it by eye. It lost because the block already grew unnoticed.

**What it touches.** Context builder tests, the eval scripts.

> 2026-09-14 approved

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

## mp-220 · Quick replies under the opener
- category: The sheet and launcher
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption: Two quick replies under the opener.
- screen: Vana sheet on open
- source: ticket 07; memory 09-10

**Context.** Quick replies are the tappable answers under Vana's opening line in the sheet. The server's opener ends in a choice question and its prompt asks for two to three options. The export draws exactly two chips.

**Question.** How many quick replies the opener shows, and when they go.

**Decision.** 1. The opening's choice part becomes the quick replies. The first two options show, the first filled and the second outline. A third option is dropped.
2. The replies vanish the moment the thread has anything in it, not when the athlete types a draft, and they stay gone for the sheet's life even if that first send fails.
3. The opening's choices are drawn only as quick replies, never also inline. A choice part later in the thread renders as ordinary chips.

**Why.** The export shows two chips, and drawing the opening's choices twice would bring the replies back.

**What else was considered.** Asking the prompt for exactly two, which costs a server deploy for the same result. Hiding the replies on typing a draft, which the spec prose said but the spec table and export did not.

**What it touches.** Sheet conversation, VanaExchange, persona.

> 2026-09-14 folded from mp-076, mp-077
> 2026-09-14 approved

## mp-221 · How the sheet's messages and composer look
- category: The sheet and launcher
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_thread_light.png
- caption: Vana's row and the athlete's bubble in the sheet.
- screen: Vana sheet
- source: ticket 07

**Context.** The full-screen Vana chat draws her turns in an existing message card. The sheet is a new, smaller surface with its own design export, its own typing indicator, and a composer with a send button and placeholder text.

**Question.** Whether the sheet reuses the full-screen chat's message card and composer, or follows its own export.

**Decision.** 1. Vana's messages sit flush left with a small filled orange sparkle avatar and no bubble. The athlete's turns are right-aligned in a soft cream bubble.
2. The typing indicator is the in-flight turn with no prose yet, drawn in Vana's row. It never shows beside quick replies.
3. Send is grey with an empty draft and grey while a turn is in flight, orange otherwise. Lee has not ruled on the in-flight grey.
4. The composer keeps the general placeholder, not the export's "Ask about your fueling".

**Why.** The export draws the sheet this way, and the sheet is a general conversation rather than a fuelling one.

**What else was considered.** Reusing the existing Vana message card, which does not match the export. Orange send on any draft, as the export keys it, which lights a button the controller ignores mid-stream. The export's fuelling placeholder, which narrows the sheet.

**What it touches.** Sheet conversation, sheet composer.

> 2026-09-14 folded from mp-078, mp-079, mp-080, mp-081
> 2026-09-14 approved

## mp-222 · The launcher is its own accessibility node
- category: The sheet and launcher
- status: approved
- image: docs/ssot/decisions/images/mealplanning/timeline-launcher.png
- caption:
- screen: Any screen with the launcher
- source: ticket 06
- detail: yes

**Context.** The launcher floats above every screen at the app's root. On the device its label merged into the root, so VoiceOver read the entire screen as one button called "Ask Vana".

**Question.** How the launcher presents itself to a screen reader.

**Decision.** The launcher is its own accessibility node with its own label. Its semantics no longer merge into the app root.

**Why.** VoiceOver read the whole screen as one "Ask Vana" button.

**What else was considered.** none recorded

**What it touches.** VanaLauncher.

> 2026-09-14 folded from mp-070
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-14 picture reused from docs/ssot/decisions/images/mealplanning/timeline-launcher.png
> 2026-09-15 approved by Lee

## mp-223 · Two fuelling windows make Vana speak first: before a workout and after one
- category: Moments: Vana speaks first
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_moment_pill_light.png
- caption: The launcher's moment pill asking "Fuel tonight's run?".
- screen: Any screen with the launcher
- source: ticket 09; vana-moment.md; archive ticket 13; ticket 10; memory 09-11

**Context.** A moment is Vana speaking first: the launcher rings, a pill shows a question, and the sheet opens on her already talking. Three candidate trigger sets were on the table, and meal-plan beats such as a cook check-in are decided on the server.

**Question.** What makes Vana speak first, and where that is decided.

**Decision.** 1. Only two windows raise a moment: the pre-workout window and the recovery window. Both are resolved on the device from local rows. Meal-plan beats and informational moments are deferred and the "planning…" pill is not built.
2. Pre-workout raises for a planned, not-completed workout today whose window has opened and whose start has not passed, with no meal logged at or after the window opened. Import-only workouts raise nothing.
3. Recovery raises for a completed endurance session of 60 minutes or more with nothing logged since. Strength and import-only sessions never do. The pill says "Recovery fuel?".
4. The recovery moment stays live 4 hours when the next fuel-demanding session is under 8 hours away, else 2 hours. This is a reading of the SSOT's urgent and relaxed branches, not a ruling. Lee and Xuan have not ruled.

**Why.** A companion that interrupts on the wrong trigger is worse than one that waits. The server decides plan beats and the launcher cannot know them without a call. The SSOT names the 60 minute endurance clause and no single recovery window.

**What else was considered.** Windows plus existing plan beats, or a server moment endpoint, both needing a server call the launcher cannot afford. Any session the during-workout spec fuels, which made the 60 minute clause meaningless. Stopping to ask for a recovery window, which would have blocked the ticket.

**What it touches.** Moment resolver, launcher, recovery_window_authority.dart.

> 2026-09-14 folded from mp-082, mp-083, mp-091, mp-092
> 2026-09-14 approved

## mp-224 · Where the window numbers come from
- category: Moments: Vana speaks first
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-224.svg
- screen: none (algorithm/data)
- source: ticket 09; memory 09-11; ticket 10
- detail: yes

**Context.** The pre-workout window length varies by workout and the app already has a fuelling window authority that owns it. A session's end has to be computed from a row where mark-done and Garmin write different things into the completed field.

**Question.** Where the resolver gets a workout's window length and a session's end time.

**Decision.** 1. The resolver reads the workout's stored pre-workout minutes and falls back to the authority's default from duration and intensity. A workout created close to its start is clamped so its window opens the minute it is created. The device sends the window to the server so Vana names the same one.
2. A session's end is the actual start, else the scheduled start, plus the actual duration, else the planned duration. The completed timestamp is never read.

**Why.** The fuelling window authority already owns the number, and two writers fill the completed field with different meanings.

**What else was considered.** A fixed window in the resolver, which would put a second window number outside the authority. Reading the completed time, which mark-done and Garmin fill differently.

**What it touches.** fueling_window_authority.dart, moment resolver, moment.ts, chat body.

> 2026-09-14 folded from mp-084, mp-093
> 2026-09-15 approved by Lee

## mp-225 · What the athlete sees when a moment raises
- category: Moments: Vana speaks first
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_moment_tinted_light.png
- caption: The launcher tinted orange after the pill has gone.
- screen: Any screen with the launcher
- source: ticket 09; vana-moment.md

**Context.** A moment has three visible pieces on the launcher: a ring animation, a pill carrying the question, and a tinted resting state. The spec table lists all three and the export overlaps the first two. The pill sits beside the tab bar.

**Question.** The order and timing of the ring, the pill and the tinted launcher.

**Decision.** 1. The launcher rings, then the pill shows for a few seconds, then the launcher stays tinted until the moment retires. The pill never opens during the ring. Reduced motion skips straight to tinted with the pill.
2. While the pill shows, the tab bar collapses to its home button, and the two must not overlap at iPhone SE width.

**Why.** The spec's table reads as a sequence, and the export collapses the bar while the pill is open.

**What else was considered.** The pill during the ring, as the export does, which the spec table contradicts.

**What it touches.** VanaLauncher states, tab bar, home shell.

**Details.** Ring about 2 s, pill 240 px for 4 s, then orange with a cream top highlight and the mark in blackberry.

> 2026-09-14 folded from mp-085, mp-086
> 2026-09-14 approved

## mp-226 · How often Vana speaks first
- category: Moments: Vana speaks first
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-226.svg
- screen: none (algorithm/data)
- source: ticket 09; vana-moment.md; ticket 10

**Context.** A moment rings when it first raises. The athlete may switch screens, or kill and reopen the app, while a window is still open. With two moment kinds, a day with a morning and an evening session could raise four moments, and two windows can be open at once.

**Question.** How many times a day a moment may ring, and what remembers that it already did.

**Decision.** 1. "Rang for this workout and window" is stored on the device per user per day, so a restart does not ring again. A raised moment waits for a launcher on screen before ringing.
2. A recovery moment is keyed on the activity alone, with no time in it, so Garmin refining a marked-done session's start does not ring it again.
3. At most two rings a day. Once two have rung, an unrung moment is not raised at all. A moment that already rang stays live.
4. When a pre-workout and a recovery window overlap, the one that closes sooner speaks.
5. The controller re-resolves every minute while either window is open, because a window can close with no row changing.

**Why.** An athlete with a morning and an evening session hears from Vana at most twice, and never twice for the same thing.

**What else was considered.** In-memory only, which rings again after every restart. No cap, which nags, or a cap of one, which silences the evening session. Pre-workout always wins, which can let a closing recovery window pass unspoken.

**What it touches.** Moment controller, moment resolver, rung record.

> 2026-09-14 folded from mp-087, mp-094, mp-095, mp-096, mp-097
> 2026-09-14 approved

## mp-227 · Tapping a moment, and what ends it
- category: Moments: Vana speaks first
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_moment_tinted_light.png
- caption: The launcher staying tinted after a dismissed sheet.
- screen: Vana sheet on a moment
- source: ticket 09; vana-moment.md

**Context.** Tapping the pill or the tinted launcher opens the sheet. Each day has one ambient conversation that may already hold turns. Once a moment has raised the athlete can dismiss the sheet, reply, log a meal, or start the workout.

**Question.** What tapping the pill writes into the conversation, and which actions retire the moment.

**Decision.** 1. The client sends the moment kind and activity id as an opener into the existing conversation, even mid-thread. The opener names the session, its time and the window, and ends in a choice with two options. Landing mid-thread is not a first turn, so there is no second feedback tip and no read-back.
2. A moment starts a new exchange explicitly, so its quick replies show and the chip reads "Fuel plan · to do" even mid-thread.
3. Dismissing the sheet leaves the launcher tinted with no second ring. Any send in the moment's exchange answers it. A meal logged in the window or the workout starting retires it on the next resolve.
4. A retired, unanswered moment leaves its turn in the thread with its options drawn inline.

**Why.** The sheet should open on Vana already naming the run. The nudge persists quietly but never nags, and the history stays honest.

**What else was considered.** A new conversation per moment, which breaks one conversation per day. Special-casing the moment in the exchange logic, which scatters the rule. Retiring on dismiss, which loses the nudge, or removing the turn on retire, which rewrites history.

**What it touches.** chat.ts runChat, companion host, VanaExchange, moment controller, sheet transcript.

> 2026-09-14 folded from mp-088, mp-089, mp-090
> 2026-09-14 approved

## mp-228 · What the recovery opener says, and its tone
- category: Moments: Vana speaks first
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_moment_tinted_light.png
- caption:
- screen: Vana sheet on a recovery moment
- source: ticket 10; memory 09-11

**Context.** The SSOT post-workout spec has urgent and relaxed branches and forbids presenting the 2 hour protein anchor as a window. The component spec assigns the recovery moment the orange to-do, while the SSOT's relaxed badge reads "with your next meal".

**Question.** What Vana says when the athlete taps a recovery moment, and whether a relaxed recovery deserves orange.

**Decision.** 1. Urgent names the next session and says to keep carbs coming through the next 4 hours. Relaxed says there is no rush and gives no deadline; with a session 8 to 24 hours away it leans "earlier rather than later today". Both mention 20 to 30 g protein within a couple of hours.
2. Relaxed recovery uses the same orange to-do and "Recovery fuel?" pill as urgent. This is the current reading, not a ruling. It could raise nothing, or raise a calmer news tone.

**Why.** The SSOT forbids presenting the 2 hour anchor as a window, and the component spec assigns recovery the orange tone.

**What else was considered.** Naming the window in every recovery opener, which the SSOT forbids for the relaxed branch. Raising nothing for relaxed, or a news tone, both open for a ruling.

**What it touches.** chat.ts recovery opener, launcher, moment resolver.

> 2026-09-14 folded from mp-098, mp-099
> 2026-09-14 approved
> 2026-09-14 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_moment_tinted_light.png

## mp-229 · Meal-plan moments are deferred, and the proactive loop runs through the opener
- category: Moments: Vana speaks first
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: ticket 12; vana-chatbot-update-plan.md

**Context.** Beyond fuelling, the plan has beats where Vana could speak first: a cook check-in before a cooking session and a debrief after the week. Those are decided on the server. Push notifications and a cron job were on the table.

**Question.** Whether Vana speaks first about the plan itself, and how those touchpoints reach the athlete.

**Decision.** 1. Cook check-in and week debrief moments wait until the fuelling moments have been lived with. Open: how often to ask the server, what happens offline, and whether a plan moment may take one of the day's two rings.
2. Meanwhile the two touchpoints arrive as the opener of the next app open, stamped so they never repeat: a prep-day check-in when a cook session is today or tomorrow, and a debrief for a finished undebriefed week up to 14 days old.
3. Local notifications at 18:00 exist but default off.

**Why.** Proactive must not mean naggy. An opener on open has zero spam risk, and the server-decided beats need a cadence decision first.

**What else was considered.** Building plan moments alongside the fuelling ones before the cadence and offline questions were answered. Cron or push through OneSignal, which can interrupt an athlete who did not open the app.

**What it touches.** opener.ts pickOpener, plan_debriefs, reminder service, moment controller.

> 2026-09-14 folded from mp-100, mp-101
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-230 · Pickers, and the chips around them
- category: The planning conversation
- status: approved
- image: test/features/meal_planning/presentation/goldens/picker_chips_complete_light.png
- caption: Compact chips under a picker in the planning chat.
- screen: Vana chat
- source: memory 09-04; memory 09-03; 02-contract.md; plan-tab-v2.md
- work: pending

**Context.** In the planning chat Vana asks choice questions drawn as chips, and shows pickers: carousels of suggested meals. Lee's walkthroughs on 09-03 and 09-04 found accidental picks and chip rows that did not earn their space. The wire contract has no field saying which slot comes next.

**Question.** How a picker and its chips look and behave, and who draws the chips.

**Decision.** 1. A choice question takes two to four options as plain strings, drawn as compact pills. Bigger sets go through the selectable chip grid.
2. A picker shows a handful of meals from the semantic search over the library, with saved meals boosted. A "Show more" raises a sheet with many more options from the same search. The count is not fixed.
3. Tapping a picker tile opens meal detail. Only the tick adds it to the draft. Picked tiles get a swap circle. Chat tiles have no overflow menu, title, "tap to add" or why blurb.
4. The chips under a picker are widgets the app draws. Their labels come from the model when its turn names the choices it expects next (mp-272). When the turn names none, the app shows its own set: "I like these", then "Next: type" or "That's my week" by coverage, plus "Other options" and "Something else…". Filter chips appear once the plan has a meal. Tapping a chip sends its label.
5. "Other options" never repeats a meal already in the draft or already shown in the conversation.

**Why.** Whole-card adding caused accidental picks, three meals felt thin, the model kept naming the wrong next type, and repeats read as not listening. Lee on 2026-09-14: the picker should be flexible, with a show-more sheet, and fed by the semantic search over the embedded library. Lee on 2026-09-15: the chip text can come from the model, which may say what buttons it expects next; when it says nothing the app shows its own; the widgets are always the app's.

**What else was considered.** Two-line label and detail rows, stripped as not earning their space. MealBuddy's five to seven option groups. A fixed three meals. Model-authored chips, or a next-slot hint on the wire the contract does not carry.

**What it touches.** askChoice schema, choice chips, suggestMeals tool, picker carousel, PickerChips, persona rule 3.

**Details.** The tick sits top-left and the swap circle top-right on picked tiles. The shown set is parsed from stored picker and staples parts.

> 2026-09-14 folded from mp-102, mp-103, mp-104, mp-105, mp-108
> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-15 amended by Lee
> 2026-09-15 rewritten from Lee's words
> 2026-09-15 approved by Lee

## mp-231 · How a cooking period fills up
- category: The planning conversation
- status: approved
- image: test/features/meal_planning/presentation/goldens/plan_bar_expanded_light.png
- caption: The plan bar with its coverage count.
- screen: Vana chat
- source: memory 08-31; 02-contract.md; memory 09-03; vana-chatbot-update-plan.md
- work: pending

**Context.** A week's plan covers several meal types and the plan bar shows how much of the week is covered. Breakfast and snacks are staples. Not every athlete wants lunches planned, and Xuan's scenario has an athlete who trusts Vana to decide for them.

**Question.** Which meals get planned, over what span, and what gets suggested first.

**Decision.** 1. The order of meal types is not fixed. A person may skip breakfast, snacks or any type, and the walk only covers the types they plan.
2. The plan spans a cooking period. A week is the default and the athlete can change it, so several days is fine.
3. In batch mode the athlete cooks a few meals at one sitting and eats them across the period. Servings scale so the batch covers the days, and coverage counts servings against the period, not a fixed 14 slots.
4. People who do not batch plan per day instead, and the walk, coverage and review follow that mode.
5. Suggestions give the highest weight to meals the athlete has liked or already cooked. One tap drafts the period from what they ate last time.
6. "Draft it for me" runs deterministically. The model selects nothing and only presents the result.

**Why.** Lee on 2026-09-14: the order is not fixed, the span is not a set week, batch cooking is cooking a few meals and eating them through the period, so servings must scale, non-batchers plan differently, and already-cooked or liked meals must come first.

**What else was considered.** A fixed dinner-lunch-breakfast-snack walk over 14 slots (the earlier reading), rejected as too rigid.

**What it touches.** Chip logic, planning prompt, coverage service, plan bar denominator, batch setting, suggestMeals ranking, draftWeek tool, settings.

> 2026-09-14 folded from mp-106, mp-107, mp-111
> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-15 approved by Lee

## mp-232 · Batch cooking is asked once
- category: The planning conversation
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: prototype-rebuild-spec.md; 05-flutter-feature.md

**Context.** Batch cooking groups the week's meals into cooking sessions. The prototype defaulted it to true, so its ask-when-unknown rule never fired, and it went straight to rebuild-or-keep when the athlete switched it off.

**Question.** When Vana asks about batch cooking, and whether a mid-plan change sticks.

**Decision.** 1. Batch cooking is a keyed setting. When it has never been chosen, Vana asks before showing lunches and saves the answer. Settings has the same switch. Off means no cooking sessions and meals are "make the night of".
2. Switching it off during a plan first asks whether the change is for good or just this week, then asks rebuild-or-keep.

**Why.** It only changes grouping, so asking every plan is noise, and a one-week change should not overwrite the setting.

**What else was considered.** A per-plan question, which is noise. Asking rebuild-or-keep straight away, as the prototype did, which silently overwrote the setting.

**What it touches.** user_memories, Vana settings, review sheet sessions, persona, set_setting.

> 2026-09-14 folded from mp-109, mp-110
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-233 · What Vana suggests, and what she never invents
- category: The planning conversation
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: memory 08-31; README; prototype-rebuild-spec.md; 05-flutter-feature.md

**Context.** The standing rule is that numbers and meals never come from the model. The search tool feeds pickers from the library and the athlete's saved meals. A 2026-08-28 design auto-added staples under "act, don't ask". Rest days were the biggest gap the research found unaddressed.

**Question.** Where suggestions, staples and day guidance come from, and what the model is allowed to make up.

**Decision.** 1. Staples are suggested from the athlete's own logs and nothing enters the plan until the athlete ticks. The staples card is a chat part only.
2. Day guidance for rest days, carb-load days and race week is computed from the budget, the workouts and the library's picks. The model only phrases it. A race-week rule can be a specific meal and is only proposed when a race exists. Race day carries no carb number.
3. Search applies allergies and dietary preference as a hard filter in the database, returns saved and library rows together with saved boosted, nudges common assemblies up, and rejects pairs no athlete has been documented eating.

**Why.** Lee ruled twice that auto-adding surprised users. Numbers never come from the model, and the model may never emit a meal a tool did not vet.

**What else was considered.** The "act, don't ask" auto-add. Model-generated day advice. Model-side filtering, which lets the model emit a meal the tool did not vet.

**What it touches.** diagnoseStaples, Plan tab, dayGuidance, day cards, rule chip, search_meals, meal library pairs.

> 2026-09-14 folded from mp-112, mp-113, mp-114
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-234 · The plan bar
- category: The planning conversation
- status: approved
- image: test/features/meal_planning/presentation/goldens/plan_bar_minimized_light.png
- caption: The plan bar minimized above the composer.
- screen: Vana chat plan bar
- source: 02-contract.md; plan-tab-v2.md; 05-flutter-feature.md; memory 09-03

**Context.** The plan bar is pinned above the composer in the planning chat and grows as meals are picked. The server sends a plan snapshot whenever the draft changes. The 2026-08-28 design kept Confirm always visible, and "New meal plan" was opening on the confirmed plan with meals already in it.

**Question.** What the pinned plan bar shows, where Confirm lives, and which plan it reads.

**Decision.** 1. A plan snapshot is never a message bubble. It updates the draft and the bar, and history rows have snapshots stripped on load.
2. The bar opens as "Your plan · 0 meals" and collapses on every turn. Tiles carry remove with Undo, a slot chip and a servings stepper. "Review plan" is secondary until three meals, then primary.
3. Confirm lives only in the Review sheet, grouped by cooking session when batch cooking is on. It is not in the bar or in Vana's chips.
4. The bar and picks in chat read and write the conversation's draft, never the device's active week plan.

**Why.** The plan is state, not a message. Nothing commits without an explicit review, and the bar must not crowd the transcript.

**What else was considered.** Rendering each snapshot as a card, which fills the transcript with state. Confirm always visible in the bar, which let a plan commit without a review.

**What it touches.** Chat controller, PlanBar, ReviewSheet, applyDraftPlan.

> 2026-09-14 folded from mp-115, mp-116, mp-117
> 2026-09-14 approved

## mp-235 · Confirm, and what comes after
- category: The planning conversation
- status: approved
- image: docs/new_mealplanning/figma/18-all-days-collapsed-confirm.png
- caption: MealBuddy's day slotting, which was rejected as the default.
- screen: Vana chat
- source: vana-chatbot-update-plan.md; OPEN-QUESTIONS.md; memory 09-07

**Context.** Confirm is the moment of value. A confirmed plan is a collection of meals with servings. MealBuddy assigns every meal to a day at generation. Calendar, email and PDF integrations were candidates, and the first build landed on a bare route with no tab bar.

**Question.** What confirming a plan hands the athlete, where it lands them, and whether meals are laid across days.

**Decision.** 1. Confirm shows a "you're set" card with the week, the sessions, the list size and where things live. It offers an OS share sheet for plain text and a "remind me the night before cook day" chip. No calendar, email or PDF in the first version.
2. Confirm lands on the main shell with the Food tab's Shopping segment selected, so the tab bar is present.
3. The chips after confirm are Open shopping list, Lay it across the week, and Adjust. Laying it across renders read-only day cards. Athletes who ignore it keep the collection-only plan.

**Why.** Most of the felt value at a fraction of the cost. The shopping list is the moment of value and the athlete should not be stranded off the shell. Research on batch cooks says collections, not day grids.

**What else was considered.** Calendar and email APIs. A bare food route. MealBuddy's Day 1 to Day 6 slotting up front, which the research argues against.

**What it touches.** ConfirmedCard, share service, reminder service, router food parameter, planWeek, week part.

> 2026-09-14 folded from mp-118, mp-119, mp-120
> 2026-09-14 approved

## mp-236 · The composer's plus menu: pantry, fridge photo and browse
- category: The planning conversation
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: memory 09-07; vana-chatbot-update-plan.md; memory 09-03

**Context.** The composer is the input row at the bottom of the planning chat. It takes text, voice, photos and a way into the catalog. Lee reviewed the layout on the simulator on 2026-09-07. The prototype offered a generic pantry list, and other AI surfaces charge credits.

**Question.** How the composer is arranged, and what the plus menu offers.

**Decision.** 1. One pill with a flat plus on the left, a mic while empty and an up-arrow send when there is text. Web gets no camera and no mic.
2. The plus sheet offers Snap my fridge, Choose a photo, Use what I have and Browse meals.
3. The pantry question seeds a chip grid from the athlete's own 30-day logs, saved-meal components and the last plan's have or checked items, top 8. "Use these" writes pantry items and marks shopping rows as had.
4. Snap my fridge reuses the meal-logging upload path and vision model. It is metered with no credit charge. Pro is the price.
5. Browse meals opens the catalog tied to the conversation. Every card carries a tick that picks into the draft, and the chat refreshes its draft on return.

**Why.** Lee's 2026-09-07 simulator pass. Personalisation only reads as personal when shown. AI surfaces stay on and meal planning is already paid for. Lee wanted the v5 browse-sheet pattern inside the app's own catalog.

**What else was considered.** Separate composer buttons, rejected on the simulator. A hardcoded staples list, or a top 14. Charging credits per photo, which double-charges a Pro feature. Look-only browsing from chat.

**What it touches.** Chat composer, speech to text, askPantry, set_pantry, grocery.ts, pantry_photo action, ai_usage, MealCatalogBrowser, MealAddButton, refreshDraft.

> 2026-09-14 folded from mp-122, mp-123, mp-124, mp-125
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

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

## mp-238 · Meal planning lives under Food, and the plan is the landing
- category: Plan tab
- status: approved
- image: docs/_archived/uiux/alex_screens/Plan.png
- caption: An early concept of the Plan tab.
- screen: Food tab
- source: synthesis-and-recommendations.md; 05-flutter-feature.md

**Context.** The Food tab holds Meals, Formulas and Shopping. The Sage canvas concept was chat-first. Six live tests were run with real users, and research finding 6 says users land on a structured surface with the assistant embedded.

**Question.** Where meal planning lives in the app, and whether the athlete lands on chat or on the plan.

**Decision.** 1. Meal planning is a segment of the Food tab beside Meals, Formulas and Shopping. It is not its own tab.
2. The Plan tab is the plan and Vana is reached from it. Chat is escalation, not the landing.
3. The Vana message card at the top of the Plan tab opens the general conversation, not a planning one.

**Why.** Nobody opened with chat in six live tests. Users skim chat. The day note is about the day, not the plan.

**What else was considered.** A separate Plan tab, or a chat-first tab. The Sage canvas.

**What it touches.** Tabs screen, food routes, Plan tab, Vana entry points, router.

> 2026-09-14 folded from mp-128, mp-129, mp-140
> 2026-09-14 approved

## mp-239 · The Plan tab is a tile list
- category: Plan tab
- status: approved
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: A confirmed plan as a tile list.
- screen: Plan tab
- source: plan-tab-v2.md; 05-flutter-feature.md; 07-verification-release.md; synthesis-and-recommendations.md; 03-backend.md

**Context.** The Plan tab shows the confirmed week. The prototype drew a "Your day" grid, plan detail routes, a plans history and a gear in the header. The app's other lists already use swipe rows. The dietitian will not recommend daily logging.

**Question.** What the Plan tab shows, and what tap, swipe, Swap and "Ate it" do on a tile.

**Decision.** 1. A message from Vana, then every meal as a tile with icon, name, slot chip and servings. The buttons are Add meal and New meal plan. No day grid, chevron, detail route, swipe hint, status tag, Edit button or gear.
2. Tap opens a sheet with a servings stepper, Swap, Remove and Ate it. Swipe right removes with Undo. Swipe left swaps.
3. A swap keeps the same plan-meal id, so a servings edit after a swap is exact.
4. "Ate it" waits for the server, hides when no servings are left, writes a meal log with source plan and decrements servings. There are no daily logging reminders.
5. Plan meal macros are stored per serving.

**Why.** Lee wanted the plan list without a brief or shopping there. Name matching was ambiguous with two same-named meals. A servings-left count does the logging job without a loop the dietitian will not recommend.

**What else was considered.** A "Your day" grid, detail routes and a plans history, which Lee cut. Delete-and-insert on swap, which loses the id. A logging loop. Storing macro totals and dividing at log time.

**What it touches.** Plan tab, plan tile sheet, Swap screen, PlanList, logFromPlan, meal_logs, log_from_plan RPC, coverage service.

> 2026-09-14 folded from mp-130, mp-135, mp-136, mp-137, mp-138
> 2026-09-14 approved
> 2026-09-14 picture refreshed at 1.26.0+1, 469da691, replacing test/features/meal_planning/presentation/goldens/plan_confirmed_light.png

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
- screen: Plan tab
- source: plan-tab-v2.md; 03-backend.md

**Context.** Plans were keyed by week start, so a new conversation reopened the confirmed plan with three meals already in it. The Plan tab expects exactly one active plan for the week.

**Question.** How plans, drafts and conversations relate, and what "New meal plan" does.

**Decision.** 1. Each conversation keys its own draft. A partial unique index allows one confirmed plan per athlete-week and any number of drafts.
2. Confirming archives every other non-archived plan for that week, drafts from other conversations included. The Plan tab keeps the confirmed plan until a new one is confirmed.
3. "New meal plan" archives the scope's plan and returns a fresh empty draft.

**Why.** Keying plans by week made a new conversation reopen the confirmed plan with meals in it.

**What else was considered.** One plan per week shared by all conversations. Archiving only the previous confirmed plan as the prototype did, which left stray drafts.

**What it touches.** plan.ts resolvePlan, confirm_meal_plan RPC, vana-action, Plan tab button.

> 2026-09-14 folded from mp-133, mp-134
> 2026-09-14 approved

## mp-242 · The Meals tab is for looking
- category: Meals tab and library
- status: approved
- image: docs/ssot/decisions/images/mealplanning/meals-tab.png
- caption:
- screen: Meals tab
- source: memory 08-31; 05-flutter-feature.md

**Context.** Meals is the catalog: the library of about 1,900 meals plus the athlete's own saved foods. Meals reach a plan through Vana's pickers or a swap on a plan tile. The app keeps a local fuel log, but many entries are just a typed name.

**Question.** What the catalog is for on its own, how search results look, and where Recents come from.

**Decision.** 1. Four rails in this order: Recents, My Foods, Assemblies and Recipes. A search icon reveals a search bar and a filter popover narrows by meal type and by recipe or no-recipe. Add and Swap buttons appear only in swap mode from a plan tile.
2. Search results reuse the rail card. Meals excluded by the athlete's allergens are greyed, not hidden. A Vana row at the bottom offers "Want me to build the week instead?".
3. Offline, Recents come from local logs and skip name-only entries. Online, the server's recent meals list replaces the local one.

**Why.** The catalog is for looking. Adding belongs to the plan flows. One card, one look across the tab. Only the server can resolve a logged name to a library meal.

**What else was considered.** An Add button on every card, which gives plain browsing two ways to change the plan. A dedicated dense row for results.

**What it touches.** Meal catalog, search_meals, MealCatalog, catalog controller, Recents screen.

**Details.** Semantic search runs once a query reaches three characters, and the type filter is dropped while a query is active.

> 2026-09-14 folded from mp-141, mp-142, mp-143
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-243 · Cooking mode
- category: Recipes and cooking
- status: approved
- image: docs/ssot/decisions/images/mealplanning/cooking-mode.png
- caption:
- screen: Cooking mode
- source: 05-flutter-feature.md; recipe-directions-and-cooking-mode.md; README

**Context.** From a meal's detail screen the athlete can start cooking mode, a hands-busy view read from across a counter. Steps come from many origins and are not structured. The shared notification service only talks to OneSignal.

**Question.** How cooking mode is laid out on the phone, how timers are made, and how one alerts.

**Decision.** 1. Three phases: an overview, one big step per screen, then a done screen that asks for a thumb vote. Steps move by swipe, oversized tap zones, and Back and Next. The wake lock is held only during the cooking phase.
2. Timer chips are parsed from each step's text, at most three per step. Timers run at the same time and keep running when the athlete moves on.
3. A finished timer fires a local notification and a vibration. The ringing chip on screen is the fallback. No audio.
4. Wave-to-advance over the proximity sensor exists only on phones.

**Why.** A screen that stays on only when needed. Deterministic timers with no model call. The shared notification service has no immediate-show call. Browsers expose no proximity API.

**What else was considered.** In-app audio, which would need an asset and a sound session for a case the notification already covers.

**What it touches.** CookingSessionController, CookingModeScreen, cooking timers, cooking mode route.

**Details.** A duration must be between 5 seconds and 12 hours. A range takes its upper bound. Timers tick once a second.

> 2026-09-14 folded from mp-147, mp-148, mp-149, mp-150
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-244 · The shopping list
- category: Shopping list
- status: approved
- image: test/features/meal_planning/presentation/goldens/shopping_list_light.png
- caption: The shopping list grouped by aisle.
- screen: Shopping tab
- source: plan-tab-v2.md; 05-flutter-feature.md; memory 09-07; memory 09-02
- work: pending

**Context.** When the athlete confirms a plan they land on the Shopping tab. Building the list means adding up ingredients across every meal and serving. Most plan edits write locally first. The prototype had aisle groups, a pickup placeholder, and filtered out items the athlete already has.

**Question.** Where the list is built, what the tab shows, and which unit system it uses.

**Decision.** 1. The list is aggregated deterministically on the server at confirm, and confirm waits for the server's acknowledgement. It is rebuilt after every plan edit. The device never computes it.
2. Nine aisle groups. Each row has a checkbox and a quantity. A row from more than one meal carries a count badge that opens a sheet listing those meals. Share sends plain text. No pickup button.
3. Quantities render imperial unless Settings says metric, on screen and in the shared text.
4. Items marked as had are filtered out and only Vana's "Add back" restores them. There is no per-row "have it" toggle. That toggle is logged as an open question.
5. Each row can tap back to the recipe or recipes it came from, through the count-badge sheet every multi-meal row already has, so no new control is added.

**Why.** The list is the moment of value and must exist before the athlete lands on it. Kroger and other surfaces read it too, so there is one builder. US users read imperial. Lee on 2026-09-14: a tap back to the original recipe, through minimal UI.

**What else was considered.** Computing on the device, which gives two builders that disagree. A metric default. Keeping the unwired per-row toggle.

**What it touches.** grocery.ts, confirm_meal_plan, Shopping tab, ShoppingListController, quantity formatter.

**Details.** Plans confirmed before a change keep their old quantities until reconfirmed. Always-have items match on whole phrases, and catalog rows with a blank quantity get a default.

> 2026-09-14 folded from mp-151, mp-152, mp-153, mp-154
> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-15 approved by Lee

## mp-245 · Typing feedback to Vana is the feedback system
- category: Feedback loop
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: spec.md; ticket 01; 02-contract.md; archive ticket 01
- work: pending

**Context.** The only existing channel was a Wiredash form buried in Settings that nobody used. Vana is already the surface athletes talk to. In testing Vana apologised instead of filing about half the time, filed feature requests under the wrong heading, and twice said "saved" without calling the tool.

**Question.** Whether talking to Vana is the feedback channel, what counts as feedback, and how it is filed.

**Decision.** 1. A complaint, praise or suggestion typed to Vana files a row in the athlete's own words, with a sentiment, an about-field and the conversation id. Taste comments such as "not those" write no row. The Wiredash card stays for anything that needs a screenshot.
2. A message that is both a complaint and a question keeps Vana's answer. A pure vent gets the acknowledgement alone.
3. "I have told you" and "you keep getting this wrong" count as feedback. The feedback rule sits at the top of the prompt's rules.
4. A request for something new is filed as a suggestion. Praise or a complaint about Vana's meal ideas is about Vana, even when the athlete says "the app".
5. Vana must call the tool before claiming feedback is saved, and the conversation id travels apart from the plan scope so general mode keeps it.
6. Vana's feedback tool also files a Wiredash entry, so typed feedback and shaken reports land in one place. Wiredash entries are created on the device, so the server tool hands the row to the app to file. This is the reading; the device hand-off is the open detail.

**Why.** The athlete should not have to find a form. Position beat wording. Feature requests were going to the wrong pile. Lee on 2026-09-14: one uniform Wiredash entry for everything, if possible.

**What else was considered.** A feedback form or screen. Silence on every feedback message, which leaves a question unanswered.

**What it touches.** save-feedback tool, user_feedback table, chat.ts, general prompt.

> 2026-09-14 folded from mp-155, mp-157, mp-158, mp-159, mp-162
> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee

## mp-246 · What Vana says after feedback, and the one-time prompt
- category: Feedback loop
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat after feedback
- source: ticket 01; memory 09-10; 02-contract.md

**Context.** When Vana saves feedback a "Saved for the team" row appears. On the Haiku model her own reply after it tended to apologise and start troubleshooting, and three prompt rewrites failed. Athletes will not know they can type feedback unless something tells them, and Vana's prose can be paraphrased away.

**Question.** What Vana says once feedback is saved, and how a new athlete learns they can type it.

**Decision.** 1. The "Saved for the team" row is the whole acknowledgement. Every later text delta from the model is dropped from the stream and the transcript.
2. After the opener of a brand-new athlete's first conversation, the server appends a fixed "Have feedback for me? Just type it here." part. The model never sees it. It never appears again.

**Why.** Lee ruled that the athlete should not be troubleshot when venting. One nudge is enough, and server-authored text cannot be paraphrased away.

**What else was considered.** Clamping Vana to one sentence, which kept the apology. A stronger model for that turn. Putting the line in the persona prompt, or repeating it.

**What it touches.** chat.ts silenceAfterFeedback, feedback_saved part, feedback_prompt part, FeedbackPromptRow.

> 2026-09-14 folded from mp-156, mp-161
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-247 · Praise asserts sentiment only, not the about-field
- category: Feedback loop
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-247.svg
- screen: none (algorithm/data)
- source: ticket 01
- detail: yes

**Context.** Live evals send test messages to Vana on dev and inspect the row she files. Praise such as "this app planned my week perfectly" names the app while describing Vana's planning.

**Question.** How strict the praise eval is about the about-field.

**Decision.** The praise eval checks for positive sentiment and rating. It logs the about-field but does not assert on it.

**Why.** Praise naming "this app" while describing Vana's planning is genuinely either.

**What else was considered.** none recorded

**What it touches.** Personalisation eval.

> 2026-09-14 folded from mp-160
> 2026-09-15 approved by Lee

## mp-248 · Problem reports go through Wiredash, from a card or a shake
- category: Feedback loop
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat, shake sheet
- source: memory 09-08

**Context.** Some problems need a screenshot, which typed feedback cannot carry. Wiredash exists but its full flow asks for an email and several steps.

**Question.** How a problem that needs a screenshot reaches the team.

**Decision.** 1. A problem report produces a card in the chat with a "Send to the team" button that opens Wiredash. Vana never claims to have sent anything and no longer mentions shaking.
2. Two shakes open a Kyle sheet, then Wiredash cut down to two steps with no email prompt and an optional screenshot. The text also lands in the app's own feedback table.

**Why.** The card sends, not Vana. A two-step Wiredash is one people will finish.

**What else was considered.** none recorded

**What it touches.** Problem report card, shake detector, Wiredash config, feedback table.

**Details.** Shake threshold 3.2 g or more, twice.

> 2026-09-14 folded from mp-163, mp-164
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

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

## mp-252 · Vana runs as edge functions on the existing wire
- category: Data, sync and backend
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-252.svg
- screen: none (algorithm/data)
- source: README; 02-contract.md; 03-backend.md
- detail: yes

**Context.** The prototype ran on Vercel. The app already parses an NDJSON envelope, and the prototype's fixtures define the contract.

**Question.** Where Vana runs, what shape the wire is, and whose credentials the functions use.

**Decision.** 1. Vana runs as three Supabase edge functions: chat, action and day notes. There is no Vercel service.
2. The wire is the existing NDJSON envelope extended with status lines. The prototype speaks the same transport.
3. The wire shape is camelCase and the frozen fixture files are the truth for both clients.
4. The functions read as the caller so row-level security filters. The service key is kept only for call logs, pair refresh and macro fills.

**Why.** One backend, one contract, and the database does the authorisation.

**What else was considered.** none recorded

**What it touches.** vana-chat, vana-action, vana-day-notes, contracts file, fixtures.

> 2026-09-14 folded from mp-175, mp-176, mp-177, mp-178
> 2026-09-15 approved by Lee

## mp-253 · Openers live in the chat function, and the old chat route survives one release
- category: Data, sync and backend
- status: approved
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: 03-backend.md; memory 08-26
- detail: yes

**Context.** Clients already shipped call the old chat route. General openers used to be synthetic and unstored.

**Question.** Whether the opener is its own function, and what happens to the old chat route and tables.

**Decision.** 1. There is no separate opener function. An opener flag on the chat call runs it. General openers are persisted. The old chat route keeps its unstored opener for shipped clients.
2. The old chat function becomes Vana in general mode under the old route, and the app's old chat path redirects there. The route stays until the minimum app version passes 1.24. The old tables are renamed to Vana names with compatibility views under the old names.

**Why.** Shipped clients keep working while the app moves.

**What else was considered.** none recorded

**What it touches.** vana-chat opener flag, old chat function, table renames and views.

> 2026-09-14 folded from mp-179, mp-180
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee

## mp-254 · Which writes wait for the server
- category: Data, sync and backend
- status: approved
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption:
- screen: Plan tab
- source: 05-flutter-feature.md; plan-tab-v2.md; memory 09-01

**Context.** The app is offline-first, but shopping lists, day notes and coverage are computed on the server, and a coach may act on an athlete's plan.

**Question.** Which meal-planning writes are local-first and which must wait for the server.

**Decision.** 1. Servings, remove, session, shopping ticks, day slots, settings, comments, memory delete and saved-meal notes write locally first and upload later, last writer wins.
2. Pick, swap, plan day, new plan, log-from-plan and confirm wait for the server.
3. A failed server write restores the previous plan and throws a needs-connection or Pro-required error the screen catches with a snackbar. Offline is caught before any request is made.

**Why.** Anything the server computes from must reach it, and a failure must never leave a half-applied plan.

**What else was considered.** none recorded

**What it touches.** Meal plan repository, plan controller, screens.

> 2026-09-14 folded from mp-181, mp-182
> 2026-09-14 approved
> 2026-09-14 picture reused from test/features/meal_planning/presentation/goldens/plan_confirmed_light.png
> 2026-09-14 picture refreshed at 1.26.0+1, 469da691, replacing test/features/meal_planning/presentation/goldens/plan_confirmed_light.png

## mp-255 · What syncs and what does not
- category: Data, sync and backend
- status: approved
- image: docs/ssot/decisions/images/mealplanning/meals-tab.png
- caption:
- screen: Meals tab
- source: 05-flutter-feature.md; plan-tab-v2.md; 06-sync-schema-envs.md
- work: pending

**Context.** The meal library is about 1,900 rows with embeddings. The app's rule is repository-level sync on demand, never a startup sync-all. Entitlements are written only by the webhook.

**Question.** Which meal-planning tables are mirrored to the device and when they sync.

**Decision.** 1. The meal library is never mirrored. Search and detail hit the server, with an in-memory cache for the session and a local text search as fallback.
2. Plans and memories sync when their controller first builds and on pull-to-refresh on the Plan tab. Nothing syncs from startup.
3. There is no entitlements table. Whether a person is in trial or paid is read from the store subscription state, and nothing about it is mirrored or synced.

**Why.** The library is too big and too alive to mirror, and startup sync-all is banned. Lee on 2026-09-14: the entitlements table is not needed under the trial model.

**What else was considered.** none recorded

**What it touches.** Catalog repository, plan and memory repositories, entitlements table.

> 2026-09-14 folded from mp-183, mp-184, mp-185
> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee

## mp-256 · An action targets the plan id, else the conversation's draft, else the week
- category: Data, sync and backend
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-256.svg
- screen: none (algorithm/data)
- source: 02-contract.md
- detail: yes

**Context.** Actions arrive from chat parts, the Plan tab and the Review sheet, not all of which know a plan id.

**Question.** Which plan an action hits when it does not name one.

**Decision.** An action that names a plan id hits that plan. Otherwise it hits the conversation's draft. Otherwise it hits the week's active plan.

**Why.** One resolution order, so every caller gets the plan it means.

**What else was considered.** none recorded

**What it touches.** vana-action plan resolution.

> 2026-09-14 folded from mp-186
> 2026-09-15 approved by Lee

## mp-257 · Home location is a Fact set in conversation
- category: Data, sync and backend
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-257.svg
- screen: none (algorithm/data)
- source: spec.md; ticket 02; memory 09-10

**Context.** Weather and Kroger coverage keyed off the race venue because the app had no home. There is no settings screen for it.

**Question.** Where the athlete's home lives, how it is set, and what reads it.

**Decision.** 1. Home is four nullable columns on the user record: city, latitude, longitude and timezone. A profile tool geocodes what the athlete says in conversation and sets them. No settings screen edits home.
2. When home is set, weather and Kroger coverage use it. When it is null they fall back to the race venue.
3. Clearing nutrition overrides is one flag on the profile copy, not a field-by-field rebuild.

**Why.** Home is something the athlete tells Vana once, and the rest of the app should read it from the one place it lives.

**What else was considered.** none recorded

**What it touches.** users table, profile tool, weather, Kroger coverage, settings controller.

**Details.** Device schema version 21.

> 2026-09-14 folded from mp-187, mp-188, mp-189
> 2026-09-14 approved

## mp-258 · Everything is dev-only until the cutover
- category: Data, sync and backend
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-258.svg
- screen: none (algorithm/data)
- source: spec.md; ticket 02; README; 06-sync-schema-envs.md

**Context.** Prod has no pgvector. The home-location migration adds columns the users upsert needs. Bundled content defaults were losing to a stale cache.

**Question.** What reaches prod before the cutover, and what the cutover must do.

**Decision.** 1. Nothing is pushed to the develop or release branches. The home-location migration rides the cutover, whose schema target reads 21. A build that reaches prod before the columns exist fails every users upsert.
2. The prod seed re-embeds the library. The verify step requires every row embedded before the seed counts as done.
3. Bundled content defaults load before the first frame and win over a stale cache.

**Why.** A half-migrated prod breaks sign-in for everyone.

**What else was considered.** none recorded

**What it touches.** Cutover runbook, seed script, content service.

**Details.** About 1,922 embedding calls at seed time.

> 2026-09-14 folded from mp-190, mp-191, mp-192
> 2026-09-14 approved

## mp-259 · The sheet and launcher are design-bearing widgets
- category: Design system
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption: The glass sheet built once from the shared tokens.
- screen: Any screen with the launcher
- source: spec.md; tickets 05, 06; ticket 06; ticket 05; memory 09-11; archive ticket 09

**Context.** Design-bearing widgets are implemented once under their spec name with one token registry. The design export drew its own radius and scrim, and the tab bar spec reserved a bottom-right slot for the AI companion.

**Question.** How the sheet and launcher enter the design system, and which numbers win when the export disagrees with the tokens.

**Decision.** 1. A component spec is written from the existing glass surface and tab-bar tokens. The widget is implemented once under that spec name in the shared library and the app shell composes it.
2. Token values beat the export where they disagree.
3. The launcher mark is a speech-bubble outline drawn as a path, the first branded glyph on the shell.
4. The launcher takes the tab bar's reserved utility slot and inherits the old floating button's clearance rule. The scrim comes from the calendar sheet.

**Why.** One registry, one implementation, and the tab bar spec needs no re-ratification.

**What else was considered.** none recorded

**What it touches.** kyle_design navigation widgets, vana-sheet.md spec, tab bar spec.

**Details.** Radius token 24 not the export's 26. Scrim token 60 percent not 45. Launcher 52 px.

> 2026-09-14 folded from mp-193, mp-194, mp-195, mp-196
> 2026-09-14 approved

## mp-260 · Feature widgets and slot colours
- category: Design system
- status: approved
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: Slot chips on plan tiles.
- screen: Food tab, meal cards
- source: 05-flutter-feature.md; 02-contract.md; plan-tab-v2.md; memory 09-11

**Context.** The shared segmented control renders enum names and the shared plus-minus control is full width. The prototype fixed a colour per meal type and always tinted icons electrolyte. An agent later proposed an ink tint on cards.

**Question.** Which meal-planning widgets are custom, what colour each slot is, and how meal icons are tinted.

**Decision.** 1. The Plan, Meals, Shopping selector and the servings stepper are custom feature widgets.
2. Breakfast is orange, lunch electrolyte dark, dinner purple and snack dragonfruit, as ported from the prototype.
3. Meal icons on cards are ink-tinted in the current code, against the prototype's electrolyte rule. Lee has not ruled and is to see it on a device.

**Why.** Labels must come from content keys, and the shared controls did not fit.

**What else was considered.** none recorded

**What it touches.** Food tab segments, servings stepper, slot chip colours, meal icon tint.

> 2026-09-14 folded from mp-198, mp-199, mp-200
> 2026-09-14 approved
> 2026-09-14 picture refreshed at 1.26.0+1, 469da691, replacing test/features/meal_planning/presentation/goldens/plan_confirmed_light.png

## mp-261 · How the planning chat and plan present themselves
- category: Design system
- status: approved
- image: test/features/meal_planning/presentation/goldens/plan_bar_expanded_light.png
- caption: Plan tiles with their macro pills.
- screen: Vana chat, Plan tab
- source: memory 09-07; memory 09-04; OPEN-QUESTIONS.md

**Context.** Widgets arriving mid-stream jumped. The planning chat's app bar had a subtitle. Meal cards, tiles, the bar and the review sheet all show macro pills.

**Question.** How planning parts arrive, what the app bar says, and which macros show.

**Decision.** 1. Planning parts wait behind the typing dots until prose arrives, then grow and fade in with a soft stagger. The plan bar fades and slides in.
2. The planning app bar reads "New meal plan" only.
3. Macros are on by default and show kcal, carbs, protein and fat only. The picker carousel tile stays kcal-only.

**Why.** Parts should land, not jump, and the pills should carry only what an athlete reads at a glance.

**What else was considered.** none recorded

**What it touches.** Chat part animation, planning app bar, macro pills, show-macros setting.

**Details.** Stagger over 520 ms.

> 2026-09-14 folded from mp-201, mp-202, mp-203
> 2026-09-14 approved

## mp-262 · Lee and Xuan both ratify, and the record must be portable
- category: Design system
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-262.svg
- screen: none (algorithm/data)
- source: tickets 04, 05; memory 09-09; ticket 05; README
- work: pending

**Context.** The QA repo is Xuan's. The app authored three component specs it needed before Xuan could ratify them. The TanStack prototype is the living reference and source of fixtures.

**Question.** Who ratifies, where the specs and decisions live, and who else must be able to run the page.

**Decision.** 1. Lee and Xuan both ratify. A spec or decision is settled when either has approved it on the page.
2. Specs and the decision record stay in the app repo under docs/ssot for now. The QA repo is not touched.
3. The decisions page, its files and its tooling are portable. Another person on another laptop can open the page, see the same record, and run the skills. Nothing depends on one machine.
4. The prototype stays in its own repo. No TypeScript is copied into the app. SQL migrations live in the app repo.

**Why.** Lee on 2026-09-14: both ratify, keep things in docs/ssot for now, and Xuan must be able to run this from another laptop.

**What else was considered.** Ratification only in the QA repo and only by Xuan (the earlier reading).

**What it touches.** docs/ssot/decisions, the page artifact and its sharing, the skills, the QA repo boundary.

> 2026-09-14 folded from mp-204, mp-205, mp-206
> 2026-09-14 amended by Lee
> 2026-09-14 rewritten from Lee's words
> 2026-09-15 approved by Lee

## mp-263 · Seams, and what never runs in CI
- category: Process and scope
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-263.svg
- screen: none (algorithm/data)
- source: spec.md; 07-verification-release.md; memory 09-02
- detail: yes

**Context.** Server pure functions, live model evals and client controllers each need a different kind of test. Live evals cost money and the plan-build flow talks to a real model.

**Question.** Where the tests sit and which ones run by hand only.

**Decision.** 1. Three seams: server pure functions with a fake database, live personalisation evals by hand against dev, and client controller tests through the real notifier plus goldens. A test feeds producer-shaped rows and never asserts on prompt wording.
2. The eval, lifecycle and personalisation scripts and the end-to-end plan-build test never run in CI. The Pro-gate flow that does run asserts that the tab and the routes agree.

**Why.** Tests that cost money or depend on a live model are run on purpose, not on every push.

**What else was considered.** none recorded

**What it touches.** test/, scripts/vana-eval, CI lists.

> 2026-09-14 folded from mp-207, mp-208
> 2026-09-14 approved

## mp-264 · Vana lives on three screens for now
- category: The sheet and launcher
- status: approved
- image: docs/ssot/decisions/images/mealplanning/timeline.png
- caption:
- screen: Main tabs, Plan tab, coach formulas
- source: Lee on the page 2026-09-14, on mp-049, mp-050, mp-053 to mp-057
- work: pending

**Context.** The launcher was built to appear on every ordinary screen, with one list of exclusions for auth, onboarding, paywall and Vana routes and a second list of flow screens whose bottom button it covered. Lee rejected that shape: it is a list nobody can maintain, and Vana is meant to be on a few screens for now.

**Question.** Where the launcher appears.

**Decision.** 1. The launcher appears on three screens: the main tabs screen, the meal-planning screen and coach formulas. Every other screen has no launcher node at all.
2. There is no everywhere rule, no flow-screen list and no auth-or-onboarding exclusion list. The rule is an allow-list of three routes.
3. Any page pushed over one of the three hides the launcher, so a pushed form never needs to name itself.
4. Widening to more screens is a later decision.

**Why.** Lee on 2026-09-14: we only show Vana on a select number of screens right now and cannot maintain a list of exclusions.

**What else was considered.** Everywhere with exclusion lists (mp-049, mp-050, mp-053 to mp-056), rejected as unmaintainable. Naming pushed pages so the rule can see them (mp-057), unnecessary once any pushed page hides the launcher.

**What it touches.** vana_launcher_rule.dart, VanaCompanionObserver, root app widget.

> 2026-09-14 folded from mp-057
> 2026-09-14 approved
> 2026-09-14 picture captured at 1.26.0+1, 43496fed

## mp-265 · One sheet height, and full screen only when its button is pressed
- category: The sheet and launcher
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: Vana sheet, full-screen Vana chat
- source: Lee on the page 2026-09-14, on mp-059, mp-060, mp-063 to mp-066
- work: pending

**Context.** The sheet was built with three heights, an auto height that grew on the first send, drag thresholds in pixels, a flick rule, and a grabber that toggled height. Planning actions left the sheet for full screen. Lee rejected all of it as over-designed and janky.

**Question.** How tall the sheet is, how it moves, and when the athlete goes to full screen.

**Decision.** 1. The sheet has one standard height. Contents scroll within it.
2. The close button or a normal drag down dismisses it. There is no auto height, no growth on send, no resize while Vana streams, and no custom thresholds.
3. Full screen happens only when the athlete presses the full-screen button. It opens the full-screen chat on the same conversation and is only a bigger view of the same thing. Nothing changes for Vana.
4. Every deterministic action is a hand-off, not a chat. When Vana sees the athlete is trying to do something the app already has a screen for, she offers a button that takes them there instead of doing it in the sheet: a meal plan to the meal-planning page, fuelling an upcoming workout to the new-activity screen, planning an event to the event screen, carb loading to the carb-loading picks, and so on for every flow the app owns.
5. Collapsing or dismissing the sheet drops the composer's focus so the keyboard never outlives it. The sheet keeps one widget tree shape so a change of height never remounts it.

**Why.** Lee on 2026-09-14: one height and make things standardised; going back and forth to full screen seems janky; only the full-screen button should go to full screen. Lee on 2026-09-14: all deterministic actions direct the athlete to the appropriate place in the app.

**What else was considered.** Three heights with auto, 75 and 100 percent (mp-063 to mp-065), export drag thresholds plus a flick (mp-066), and planning actions leaving for full screen (mp-059, mp-060), all rejected.

**What it touches.** VanaSheet, VanaSheetRoute, sheet chrome, part actions, chat route. Intent detection in vana-chat, hand-off buttons per flow.

> 2026-09-14 folded from mp-067, mp-068, mp-069
> 2026-09-14 amended by Lee
> 2026-09-14 clause 4 rewritten from Lee's words
> 2026-09-14 approved
> 2026-09-14 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png

## mp-266 · A seven-day trial, then purchase: no free tier and no Pro tier
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-266.svg
- screen: Paywall
- source: Lee on the page 2026-09-14, on mp-052
- work: pending

**Context.** The app was freemium: a free tier with AI credits, and Pro for meal planning. The launcher without Pro opened the paywall. Lee is moving the app to a trial model.

**Question.** What a person gets before they pay, and what tapping the launcher does once that runs out.

**Decision.** 1. Every new account gets a seven-day free trial of the whole app, then must buy. There is no free tier and no Pro tier, only trial and paid.
2. Tapping the launcher after the trial has ended opens the paywall. Gating follows the one app gate. There is no Vana-specific gate.
3. The move away from freemium is its own piece of work; see the open question beside this card.

**Why.** Lee on 2026-09-14: we are swapping from a freemium model to a seven-day free trial and then you must buy, so we do not have free and Pro any more.

**What else was considered.** Keeping free and Pro with meal planning behind Pro (mp-052 as first written, and the three Pro cards in this category, which still describe the old model).

**What it touches.** Paywall, entitlements, RevenueCat products, credits system.

> 2026-09-14 folded from mp-052
> 2026-09-14 approved

## mp-268 · The general conversation opens on the screen underneath
- status: approved
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- work: pending
- category: The planning conversation
- screen: Vana sheet
- source: Lee on the page 2026-09-14, on mp-237

**Context.** The general conversation used to open with three example chips. Vana lives on three screens and knows what is in view on each.

**Question.** What the general conversation says first.

**Decision.** 1. No example chips. The general conversation opens with a line that reads the screen underneath, such as "I see you are planning an event" or "I see you are carb loading".
2. When the screen underneath says nothing useful, the opener falls back to the personal opener that every conversation already carries.
3. Offline, rate limit and out-of-trial failures keep their one visible outcome each.

**Why.** Lee on 2026-09-14: the general conversation does not need example chips; open from the route they are on.

**What else was considered.** Three example chips and a "Start a meal plan" offer (mp-237), rejected.

**What it touches.** vana-chat opener, situation resolver, sheet conversation.

> 2026-09-14 from Lee's rejection of undefined
> 2026-09-14 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
> 2026-09-15 approved by Lee

## mp-269 · Week start and period length are settings
- status: approved
- image: docs/ssot/decisions/images/mealplanning/settings.png
- caption:
- work: pending
- category: Plan tab
- screen: Settings, Plan tab
- source: Lee on the page 2026-09-14, on mp-240

**Context.** The plan week was fixed to Sunday and cook days to fixed offsets. Athletes cook on different days and for different spans.

**Question.** Which day a plan period starts and how long it runs.

**Decision.** 1. The start day and the length of a plan period are settings the athlete can change. Sunday and seven days are the defaults.
2. Cook days derive from those settings, not from fixed offsets.
3. The Plan tab, coverage, the review sheet and the check-in opener all read the settings.

**Why.** Lee on 2026-09-14: it is variable; a user can change which day the week starts and how many days.

**What else was considered.** Sunday start with cook days at plus three and plus five (mp-240), rejected.

**What it touches.** Settings, week start, plan queries, session dates, review sheet, check-in opener.

> 2026-09-14 from Lee's rejection of undefined
> 2026-09-14 picture captured at 1.26.0+1, 43496fed
> 2026-09-15 approved by Lee

## mp-270 · Meal planning ships only with the trial and purchase model
- status: approved
- image: none
- caption:
- work: pending
- category: Pro and paywall
- screen: Paywall
- source: Lee on the page 2026-09-14, on mp-250

**Context.** The earlier plan shipped meal planning dark behind a gate flag and opened it later by granting entitlements or enabling purchase.

**Question.** Whether meal planning can reach prod before the trial exists.

**Decision.** 1. Meal planning does not ship until the seven-day trial and purchase model is live. No dark launch and no gate flag as the release plan.
2. The trial move (see the open question beside the trial card) is therefore on the critical path for the meal-planning release.

**Why.** Lee on 2026-09-14: we will not ship without the purchase and seven-day trial, so no meal planning without it.

**What else was considered.** Shipping dark with a gate flag and a Buy button behind a purchase flag (mp-250), rejected.

**What it touches.** Release plan, gate flag, Pro screen, RevenueCat products.

> 2026-09-14 from Lee's rejection of undefined
> 2026-09-15 approved by Lee

## mp-271 · Testers can switch the dev accessibility buttons off in Settings
- category: Process and scope
- status: approved
- image: docs/ssot/decisions/images/mealplanning/settings.png
- caption:
- screen: Settings
- source: Lee on the page 2026-09-15
- work: pending

**Context.** The dev build shows two floating buttons in the bottom right of every screen: the blue wrench (debug tools) and the red accessibility figure. They are always on. On the simulator they cover the Vana launcher and the tab bar, and they appear in every screenshot the record captures. Nothing is hidden behind a build flag: dev ships visible.

**Question.** Whether a tester can turn the dev accessibility buttons off, and where.

**Decision.** 1. The dev build ships the buttons on, with no build-time flag.
2. Settings gets a switch, shown in dev mode only, that turns the accessibility buttons off and on for that tester on that device.
3. The switch defaults to on and is remembered across launches.

**Why.** Lee on 2026-09-15: no hide-flags; ship without flags, and let a tester in dev mode toggle the accessibility settings on or off in Settings.

**What else was considered.** A build-time hide-flag, ruled out by the repo rule that dev ships visible. Leaving the buttons always on, which blocks the launcher on the simulator.

**What it touches.** Settings screen, the dev button overlay, the capture drives in screens.json.

> 2026-09-15 proposed from Lee's words on mp-222
> 2026-09-15 approved by Lee

## mp-272 · A turn may name the chips it expects next
- category: The planning conversation
- status: approved
- image: test/features/meal_planning/presentation/goldens/picker_chips_complete_light.png
- caption: The chips under a picker; the labels may now come from the turn.
- screen: Vana chat
- source: Lee on the page 2026-09-15; 02-contract.md
- work: pending

**Context.** The chips under a picker were app-drawn with app-chosen labels (mp-230 clause 4 as first written). Lee ruled on 2026-09-15 that the model should be able to say which buttons it is thinking about next, with the app's own set as the fallback. The wire contract carries no such field today.

**Question.** How the model tells the app which chips to show under a picker.

**Decision.** 1. A Vana turn may carry an optional list of suggested chip labels: two to four plain strings.
2. The app draws them as the chips under the picker, in the app's own widget and style. The model never draws or styles a chip.
3. When the list is absent or empty, the app's own set applies (mp-230 clause 4).
4. Tapping a suggested chip sends its label, the same as an app chip.

**Why.** Lee on 2026-09-15: the text can sometimes come from the model, so the model should be able to indicate what buttons it is thinking about next; if there is no model indicator we show our buttons; the widgets are drawn by the app.

**What else was considered.** Model-authored chips as markup, rejected: the widgets stay the app's. A next-slot hint alone, which names a slot but not the labels.

**What it touches.** Turn contract (chat.ts, 02-contract.md), PickerChips, stored turn parts, persona rule 3.

> 2026-09-15 proposed from Lee's words on mp-230
> 2026-09-15 approved by Lee

## mp-273 · Every entry point sends the same Doll, plus one section for what is in view
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-273.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15
- linked: mp-210

**Context.** Vana is reached from the sheet, the Plan tab, the full-screen chat, the history list, and later the formula editor and the events screens. Today the sheet and Plan tab send the Doll plus a Situation naming the screen; the coach insight is a one-shot call with no Doll at all. The Doll block is already a digest of about 250 to 500 tokens, one capped line per fact family, and is under a tenth of the prompt; the persona and the 32 tool schemas are four fifths of it. Lee's worry was overloading the model and paying for it on every turn. Answers mp-210.

**Question.** What context each Vana entry point gets.

**Decision.** 
1. The Doll is a fixed-shape digest: the same lines in the same order for everyone, every list capped, nothing free-form. It is the constant, sent by every entry point. mp-218's budget test guards its size.
2. The Situation is the only variable. The client sends a route and an id; the server adds one capped section for the entity in view, only while it is in view: a FORMULA section on the formula screens, an EVENTS AHEAD list on the events screens, the day's plan on the Plan tab. A section is a few lines, never a dump of the record.
3. Anything deeper is a tool, never a line. The block says what exists; the tools (mp-212) give detail on demand.
4. The Doll never grows to hold what one entry point might want. New entry points add a row to the server's screen table and nothing else.

**Why.** Cost is not in the Doll but in the unchanged prefix, which caching makes nearly free (mp-274); what would overload the model and break the cache is a Doll that grows or churns. Keeping the constant constant and the variable small is the guard.

**What else was considered.** Each screen declaring its own context in the client (breaks mp-043); growing the Doll so every entry point's needs are always present (fights mp-020 and mp-218).

**What it touches.** Situation resolver, context builder, coach formula feedback, events page, sheet.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee

## mp-274 · The formula editor sends its draft as structured fields
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/formula-editor.png
- caption:
- screen: Formula editor
- source: grill 2026-09-15

**Context.** A saved personal formula is on the server and a Situation with its id resolves like any other entity. The formula editor is different: the draft may not exist on the server, and edits since the last save never do. Today's coach insight sends the draft itself (phase, sub-phase, durations, activities, name, per-component macros and quantity). mp-043 says clients send ids and dates, never names or free text. mp-209 makes coach formula feedback a Vana conversation. Follows from mp-273.

**Question.** How the formula editor hands Vana the draft it is showing.

**Decision.** 
1. The Situation for the formula editor carries the draft as structured fields: phase, sub-phase, durations, activities, component ids with quantities, and a name capped at 40 characters. The server builds the FORMULA section from that.
2. This is the one named exception to mp-043, for one screen, and the server validates the shape as it validates routes. No other free text travels with a message.

**Why.** The draft is what the athlete is asking about, so Vana must see it as it is on screen, unsaved edits included. Saving first would write drafts behind their back and show stale data offline.

**What else was considered.** Save first and send the id (drafts saved behind their back, stale offline); keep the one-shot insight and make only saved formulas a conversation (contradicts mp-209).

**What it touches.** Situation resolver, the formula editor, the ai-coach call it replaces.

> 2026-09-15 proposed in the grill
> 2026-09-15 picture captured at 1.26.0+1, f84827b9
> 2026-09-15 approved by Lee

## mp-275 · What continues the day's conversation and what starts a new one
- category: Vana's voice and openers
- status: approved
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption:
- screen: Plan tab
- source: grill 2026-09-15
- linked: mp-211

**Context.** The launcher sheet continues the day's ambient conversation (mp-058), the full-screen button carries it over (mp-265), a moment tap opens into it (mp-227), New meal plan starts a new planning conversation (mp-003). The Plan tab's Vana note card was meant to open the general conversation (mp-238) but opens the chat route with no id, which starts a second general conversation with no opener. There is no other "cold button" in the app: the formula editor has the one-shot insight, the events screens have no launcher (mp-264). Answers mp-211.

**Question.** Which entry points continue a conversation and which start a new one.

**Decision.** 
1. The launcher, its full-screen button, the Plan tab's note card, and a moment tap all open the day's ambient conversation. The note card stops starting its own.
2. New meal plan and the chat app bar's plus button start a new conversation. A future entry from the formula editor does the same.
3. A conversation started that way never moves the launcher's pointer. Close it and tap the launcher, and the day's ambient conversation is back. The new one stays in history.

**Why.** Two entry points that disagree about continuing or starting fresh land the athlete somewhere they did not expect; the note card was doing exactly that. The launcher's promise of "where you left off" is worth more than one saved tap.

**What else was considered.** The newest conversation becomes the launcher's for the rest of the day; it lost to the side-trip reading and to leaving mp-058 untouched.

**What it touches.** Ambient conversation controller, chat route, Plan tab note card, history list, opener.

> 2026-09-15 proposed in the grill
> 2026-09-15 picture captured at 1.26.0+1, f84827b9
> 2026-09-15 approved by Lee

## mp-276 · The repeated prefix is cached, and the context block does not churn
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-276.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15
- linked: mp-215

**Context.** The whole prompt goes every turn and the model keeps nothing between calls; that is how every chat model works. Anthropic bills an unchanged prefix at a tenth of the price once caching is on, in the order tools, persona, context, messages; anything that changes invalidates everything after it. Nothing under the Vana functions sets a cache marker, so every turn pays full price for about 8,800 tokens. Two things defeat the cache as built: the context block is rebuilt every turn (LOGGED TODAY and per-message memory recall change it) and the 20-message sliding window shifts the first replayed message every turn. Answers mp-215.

**Question.** Whether sending the whole context every turn is wasteful, and what to do about it.

**Decision.** 
1. Caching is on, through the gateway's automatic mode, and the cache-read token count is logged per call so a zero is visible.
2. The context block is assembled once when a conversation opens and reused for its turns. It is refreshed only when a tool writes (plan, memory, pantry, home) or the day changes. Per-message memory recall leaves the block; the memories and last talks in it cover the person, and recall stays available as a tool.
3. The prompt order is fixed: tools, persona, context, messages. The mp-218 budget test also asserts the block is byte-identical across two turns with no writes between them.

**Why.** The sending is unavoidable; the paying is not. A mid-conversation turn drops from about a cent to about a quarter of a cent, and the rest of the design stops fighting for tokens.

**What else was considered.** Leaving the context out and fetching by tool (Vana forgets unless she asks; mp-019's reason); shrinking the Doll (it is under a tenth of the prompt).

**What it touches.** vana-chat model call options, context builder, vana_calls log, mp-218's test.

**Details.** Today about 8,800 input tokens a turn at full price, about $0.010 a turn; cached with a stable block about $0.0023. A 40-turn planning session from about $0.40 to about $0.11. Cache entries live five minutes; a reply after a longer gap pays one 1.25x write.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee

## mp-277 · How Vana remembers: chunked history, notes as they happen, an episode when the conversation goes idle
- category: Vana's memory
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-277.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15
- linked: mp-217

**Context.** Everything that looked like memory was plumbing: a 20-message sliding window, a mid-conversation episode written from the opening half when the window first bit, a read-back of the previous conversation when the next one opened, a 3.5 second wait for it, an "athlete's last words" fallback, and a race between two episode writers. Lee held mp-032 to mp-036 and mp-038 and rejected mp-009 and mp-026 pending a rethink. The research (docs/research/conversation-memory-strategies.md) found nobody ships "summarise when the next one opens": LangChain keeps the last 20 verbatim and folds the rest into a rolling summary in chunks, Claude and Character.AI save notes during the chat, OpenAI and Anthropic compact server-side at a threshold. This card replaces mp-032, mp-033, mp-034, mp-035 and mp-036; mp-038 stands. Answers mp-217.

**Question.** How Vana remembers, within and across conversations.

**Decision.** 
1. Within a conversation the history is chunked, never sliding. Every message stays verbatim up to 40. At 40 the oldest 20 become one summary message and the last 20 stay verbatim; at 60 the same again, rolling the previous summary in. The summary is written in the background when the count reaches 30 and applied at 40, so no turn waits and the cached prefix changes once per 20 turns. It lives on the conversation row, keyed by the message index it covers; no new table and no two-writer race.
2. During the conversation the remember tool is the memory writer, as mp-024's second writer. The prompt is sharpened so a durable thing the athlete says is saved the moment they say it, and the eval tests that.
3. At the end the client says when: when the sheet closes, the app goes to the background, or a new conversation starts, the client tells the server the conversation is idle, and the server writes its episode and any margin notes the tool missed, once. The summary exists before the next conversation opens.
4. The opener reads what exists and never waits. No read-back on open, no wait, no last-words fallback, no mid-conversation episode from the opening half. Episodes and the LAST TALKS line stay (mp-038).

**Why.** Lee: "If there is a new conversation, we should have summarised the earlier one sometime before that", and plumbing that exists only to cover a late summary should go. Chunking is what keeps the cache (mp-276) and the opening of the conversation at once.

**What else was considered.** A scheduled server sweep every 15 minutes for conversations idle 30 minutes, as the safety net for an app killed mid-conversation; deferred (mp-026 rejected cron as plumbing) until the miss shows up. That conversation's margin notes were already written by clause 2; only its episode waits until it is next opened.

**What it touches.** vana-chat replayHistory, extract.ts, the episode row, the conversation row, the opener path, the client's idle signal from the sheet and the chat route.

**Details.** HISTORY_CAP 20 becomes verbatim to 40, chunk 20, summary at 30. OPENER_READ_BACK_MS, readBackWithin, athleteWordsFrom and writeOpenEpisode are removed.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee

## mp-278 · The opener never waits
- category: Vana's voice and openers
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-278.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15
- linked: mp-216

**Context.** The shipped opener waited up to 3.5 seconds for the previous conversation's read-back and fell back to the athlete's last words when it was late (mp-009, rejected as too deterministic). Under mp-277 there is no read-back at open, so there is nothing to wait for. Answers mp-216.

**Question.** How long the opener waits for the read-back.

**Decision.** The opener never waits on anything. It says the most relevant thing Vana already holds (mp-008) from the memory table and the newest episodes as they stand, and when the previous conversation's episode does not exist yet she leaves it out rather than stretch.

**Why.** It removes the constant, the wait and the fallback in one stroke, and nothing else about the opener changes.

**What else was considered.** A shorter wait, or an adaptive one; both keep the plumbing mp-217 asked to remove.

**What it touches.** Opener path in vana-chat.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee

## mp-279 · The store runs the seven-day trial, and RevenueCat is the only gate
- category: Pro and paywall
- status: approved
- image: none
- caption:
- screen: Paywall
- source: grill 2026-09-15
- linked: mp-267

**Context.** Monthly and annual subscriptions exist on both stores at $9.99 and $69.99, attached to one RevenueCat entitlement in the default offering, with no introductory offer. mp-266 rules a seven-day trial of the whole app, then purchase, with one app gate. A trial can be run by the store (an introductory free offer, card on file, charged on day eight) or by the app (a server clock from signup, paywall on day eight, a rule for second accounts). Answers mp-267.

**Question.** Who runs the trial and what the store products are.

**Decision.** 
1. The store runs it. The existing monthly and annual subscriptions each get a seven-day free introductory offer on both stores. No new product ids.
2. The athlete subscribes at the end of onboarding with a payment method on file, pays nothing for seven days, and is charged on day eight unless they cancel. The store's own eligibility rule applies: one introductory offer per person per subscription group, so a cancelled trial is not repeated.
3. RevenueCat's entitlement is the gate, active from day one. There is no trial clock and no trial state in the app or the server.

**Why.** It is the model that lets the app stop keeping its own entitlement logic rather than rebuild it, and it makes RevenueCat the single truth for "may this person use the app". A card-up-front trial converts fewer signups and more payers, and payers are the number the business runs on.

**What else was considered.** An app-run trial from account creation (needs a server clock, a combined gate, and a second-account rule).

**What it touches.** App Store Connect and Play subscription offers, the RevenueCat offering, onboarding's last step, the paywall.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee

## mp-280 · Everything is behind the one gate
- category: Pro and paywall
- status: approved
- image: none
- caption:
- screen: Paywall
- source: grill 2026-09-15

**Context.** Under mp-279 an expired trial and a cancelled subscription are the same state: the entitlement is inactive. mp-266 says one app gate and that the launcher after the trial opens the paywall, but not what else is reachable. Follows from mp-267.

**Question.** What a lapsed account can still open.

**Decision.** 
1. After sign-in an inactive account lands on the paywall and stays there. No screen of the app renders.
2. The paywall carries Restore purchases, Manage subscription, Sign out and Delete account.
3. Their data is untouched and returns the moment they subscribe or restore.

**Why.** One gate, one rule, nothing to audit per screen. The trial is seven days of the whole app; when it ends, the whole app is what they are buying back.

**What else was considered.** A read-only mode for their own data (every screen needs a locked variant and the server must decide per endpoint what read-only means).

**What it touches.** The app gate, the paywall, the router's redirect.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee

## mp-281 · Credits stay as a top-up over a monthly allowance
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-281.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15

**Context.** Credits are debited one per call by six functions: general chat, planning chat, the coach insight, describe-meal, photo analysis, and the webhook that grants purchases. Two packs are on sale, 50 and 250. mp-249 (rejected) had meal planning never debiting and general chat costing free users a credit; under one subscription there is no free user. Follows from mp-267.

**Question.** What happens to the credits system under the subscription.

**Decision.** 
1. Credits stay. The subscription carries a monthly allowance of credits, granted into the same wallet the packs fill. Packs are spent only when the allowance is empty. The six functions keep debiting one credit per call.
2. The grant lands on each RevenueCat renewal event (initial purchase, renewal), so the reset follows the billing date. An annual subscription gets the same grant monthly, on the anniversary day, from the webhook.
3. The trial week gets the full monthly grant on day one. A cancelled trial forfeits what is left of it; purchased pack credits are never forfeited.
4. Unused allowance does not roll over. Pack credits never expire.
5. The number is set when the paywall copy is written and recorded here, with the per-call cost log deciding it: enough that a person who plans a week and asks a few questions a day never sees the top-up.

**Why.** Lee chose the top-up model over removing credits; the allowance is what makes "a trial of the whole app" not say "out of credits" on day three, and the packs stay for heavy use.

**What else was considered.** Removing credits entirely (every AI feature included, rate limits as the only bound); keeping credits exactly as now beside the subscription.

**What it touches.** revenuecat-webhook, credits wallet, the six debiting functions, the packs screen.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee

## mp-282 · An empty wallet shows the top-up sheet, never the gate
- category: Pro and paywall
- status: approved
- image: none
- caption:
- screen: Credits paywall
- source: grill 2026-09-15

**Context.** Today an empty wallet is a 402 from the function, and each feature catches it its own way: a snackbar with a Buy Credits action on the formula screen, a paywall push elsewhere. mp-237, which carried "out of credits opens the credits paywall" inside a card about empty-state chips, was rejected with the card. Follows from mp-281.

**Question.** What running out of credits looks like.

**Decision.** 
1. An empty wallet is never the app gate. The person stays in the app with everything that does not debit.
2. The button that would debit shows the top-up sheet: what the allowance is, when it renews, and the two packs. In Vana the composer's send shows it, with one line above the composer saying so; Vana never says "out of credits" mid-thread.
3. The server keeps returning 402 and the client keeps one handler for it, in the shared layer, so a new debiting feature gets the sheet for free.

**Why.** The wallet and the gate answer different questions; one handler keeps the six features from each inventing a path.

**What else was considered.** none recorded

**What it touches.** Shared 402 handler, the composer, the coach insight panel, the photo and describe flows, the credits sheet.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee

## mp-283 · Existing accounts get no grace period
- category: Pro and paywall
- status: approved
- image: none
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

## mp-284 · An unknown entitlement is locked, and the cache wins when it exists
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-284.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15

**Context.** The app is offline-first and the gate is a RevenueCat entitlement. The SDK caches the last customer info on the device, so a subscriber offline still has an active entitlement in the cache. The case with no answer is a fresh install or a cleared cache with no network. Follows from mp-279.

**Question.** What the gate does when the status is unknown.

**Decision.** 
1. The cached entitlement is the answer whenever there is one, online or not. RevenueCat refreshes it in the background and the gate reacts when it changes.
2. No cache and no answer within a couple of seconds counts as locked: the paywall, with Restore purchases, which succeeds as soon as the network is back.
3. The server checks every debiting or Vana call itself against its own record of RevenueCat's status (mp-285), so a device that lies about its cache buys nothing.

**Why.** Locked-when-unknown is the only safe default for a paid app, and the cache means the honest case never feels it.

**What else was considered.** Open-when-unknown for a short grace; it lost as a free path for a cleared cache.

**What it touches.** The app gate, subscription status provider, the paywall, the server's entitlement check.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee

## mp-285 · The entitlements table stays as a two-field cache of RevenueCat
- category: Pro and paywall
- status: approved
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-285.svg
- screen: none (algorithm/data)
- source: grill 2026-09-15

**Context.** Lee said on the page that the app-side entitlements table goes away under the trial model. The server still needs its own check on paid calls; a client's word cannot be the last word. Asking RevenueCat's REST API on every call adds a network hop to every Vana turn, is not reliably cacheable in stateless edge functions, and fails every subscriber closed when RevenueCat is down. The webhook already writes the table, the server already reads it, and the monthly allowance (mp-281) needs the webhook anyway. Follows from mp-284.

**Question.** Whether the server needs an entitlements table, and what it holds.

**Decision.** 
1. The table stays, shrunk to a cache of RevenueCat: the two fields the gate reads, active until and period type, written only by the webhook.
2. On any disagreement RevenueCat wins: Restore or a purchase tells the client to refetch, and the next webhook corrects the row. An event older than the row's event time is ignored.
3. Nothing grants an entitlement from the app side, ever.

**Why.** Working plumbing beats a new hop per turn and a third-party outage that stops every subscriber; what Lee's remark was against was the app being a second entitlement system, and a webhook-only cache is not one.

**What else was considered.** Fetch from RevenueCat's REST API per call with an in-memory cache (recommended first in the grill, withdrawn for the reasons above).

**What it touches.** user_entitlements table, revenuecat-webhook, the vana functions' requirePro, the entitlement repository.

> 2026-09-15 proposed in the grill
> 2026-09-15 approved by Lee

## mp-286 · Coaches get nothing special until Xuan's paywall document
- category: Pro and paywall
- status: approved
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

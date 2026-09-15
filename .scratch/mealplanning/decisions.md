# Proposed decisions: Meal planning and Vana

Feature: mealplanning
Feature name: Meal planning and Vana
Last extracted: 1dedc493

## mp-032 · Each turn replays at most the last 20 messages, with the episode prepended
- category: Vana's memory
- status: open
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-032.svg
- screen: none (algorithm/data)
- source: spec.md; ticket 03

**Context.** Every turn sends the conversation so far back to the model. A long planning conversation can run to dozens of messages, and replaying all of them costs tokens and time. Each conversation also gets an episode, a one-sentence summary stored as a Memory.

**Question.** How much history a turn carries.

**Decision.** Each turn replays at most the last twenty messages. When the cap bites, the conversation's episode sentence is prepended once so the model still knows how it started.

**Why.** Long conversations must stay fast and coherent without replaying everything.

**What else was considered.** A larger cap, or no cap. Both lost on cost and speed.

**What it touches.** vana-chat replayHistory.

> 2026-09-14 held for review under mp-217 (Lee: "let's do some research on how other chatbots approach this and if they summarize and when and how many messages they keep, etc. while keeping costs los")

## mp-033 · A mid-conversation episode is written in the background when the cap first bites
- category: Vana's memory
- status: open
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-033.svg
- screen: none (algorithm/data)
- source: ticket 03; memory 09-10

**Context.** The prepend above needs an episode to exist. Episodes were only written by the read-back of a finished conversation. So a conversation still open at twenty messages had no episode and the front of it was simply dropped. The prepend had never fired.

**Question.** When to write an episode for a conversation that is still going.

**Decision.** When a conversation crosses twenty messages with no episode, the episode half of the extractor runs after the reply is sent and the next turn picks it up. One Haiku call per conversation.

**Why.** The prepend had never fired because episodes were only written for finished conversations.

**What else was considered.** Write the episode synchronously and delay the reply. It lost because the athlete would wait on a call they cannot see.

**What it touches.** chat.ts replayHistory, extract.ts writeOpenEpisode.

> 2026-09-14 held for review under mp-217 (Lee: "again, is this the best we can do?  is there another way of handling all of this?")

## mp-034 · The open episode reads the opening half of the transcript
- category: Vana's memory
- status: open
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-034.svg
- screen: none (algorithm/data)
- source: ticket 03; memory 09-10

**Context.** The mid-conversation episode has to summarise what the model is about to lose, which is the start of the conversation. Feeding the whole transcript produced a list of recent topics with the opening gone, and the eval failed. There is one call to spend per conversation.

**Question.** Which part of the transcript the episode reads.

**Decision.** The episode is written from the first half of the transcript, with a prompt that asks for names and numbers. Past about forty messages the front is lost again, which the one-call budget accepts.

**Why.** The whole transcript produced a list of recent topics with the opening gone, and the eval failed.

**What else was considered.** Read only the dropped rows, which lost as too thin. Read the whole transcript, which lost the opening.

**What it touches.** extract.ts.

> 2026-09-14 held for review under mp-217 (Lee: "ahh I think this should be rethought alongside everything else")

## mp-035 · The open episode never stamps read-back and never overwrites
- category: Vana's memory
- status: open
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-035.svg
- screen: none (algorithm/data)
- source: ticket 03

**Context.** The read-back of a finished conversation stamps it as read so it is never mined twice. The mid-conversation episode is only half of that job. The margin notes are still owed once the conversation ends. Two writers can also reach the same conversation.

**Question.** How the open episode fits beside the full read-back.

**Decision.** The open episode does not mark the conversation as read back, because margin notes are still owed later. If the read-back or a concurrent turn already wrote an episode, that one stands.

**Why.** One keyed row, one recall mechanism, no lost notes.

**What else was considered.** none recorded

**What it touches.** extract.ts.

> 2026-09-14 held for review under mp-217 (Lee: "again we need to rethink what we're doing here")

## mp-036 · Episode reads take the newest row and there is no unique index yet
- category: Vana's memory
- status: open
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-036.svg
- screen: none (algorithm/data)
- source: ticket 03

**Context.** Two writers can race and each insert an episode row for the same conversation. The read expected exactly one row, errored on two, and the episode was lost for good. A database rule allowing one episode per conversation would close the race. That is a schema change on a table already on dev.

**Question.** Whether to change the schema now or make the read tolerant.

**Decision.** Reads take the newest episode row when there is more than one. A partial unique index would close the race but was left out as a schema change.

**Why.** A single-row read used to error on two rows and lose the episode for good.

**What else was considered.** Add the partial unique index now. It lost as a schema change outside the ticket.

**What it touches.** memory.ts.

> 2026-09-14 held for review under mp-217 (Lee: "again we need to rethink this episode part and what we are doing")

## mp-038 · The context says what they said last, not their schedule
- category: Vana's memory
- status: open
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-038.svg
- screen: none (algorithm/data)
- source: memory 09-11; commit 1dedc493

**Context.** The context block has a MEMORIES section. Episodes were listed there beside the margin notes. An episode is a summary of a conversation, so the opener read it back as "last time we planned Tuesday's ride and Thursday's swim". That is a schedule, not a memory of the person.

**Question.** How the context presents past conversations.

**Decision.** The context gains a LAST TALKS line holding what the athlete said in recent conversations. The MEMORIES block holds only non-episode notes.

**Why.** Episodes in the memories block read as a schedule read-out instead of a memory of the person.

**What else was considered.** none recorded

**What it touches.** context.ts.

> 2026-09-14 held for review under mp-217 (Lee: "again, we need to discuss this episode thing again")

## mp-210 · What context each Vana entry point gets
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-002
- image: none
- caption:
- screen: Vana chat, events page, coach formula feedback
- source: Lee on the page 2026-09-13, amending mp-002

**Context.** Vana is reached from several places: the sheet over any screen, the Plan tab, the full-screen chat, a formula's coach feedback, and the events page. Today the sheet and Plan tab hand her the Doll plus a one-line Situation naming the screen. The formula and events entry points were built earlier and hand her something different, or less. The question is what each entry point owes her.

**Question.** Vana has different entry points. Coach formulas will have different conversations to meal planning to general chat. Each entry point needs different context. The formulas conversation needs formula context, and the events page needs the upcoming events. We have not figured this out enough and need to think it through. All contexts should have the Voodoo Doll of the given user.

**Why.** Without a rule per entry point, each screen invents its own context and Vana knows different things depending on where she was opened.

**What it touches.** Situation resolver, context builder, coach formula feedback, events page, sheet.

> 2026-09-15 answered by mp-273

## mp-211 · Which entry points continue a conversation and which start a new one
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-003
- image: none
- caption:
- screen: Vana chat, Vana sheet, Plan tab
- source: Lee on the page 2026-09-13, amending mp-003

**Context.** Vana can be reached from the sheet over any screen, the Plan tab's note, the New meal plan button, the full-screen chat, and the history list. Today the sheet continues one conversation per day, and New meal plan opens a fresh planning conversation. The rules for the other entry points were never written down together.

**Question.** We need to figure out conversation histories. When we press New meal plan, or ask a question cold by pressing a button somewhere, the expectation is that this is a new conversation and not an existing one. We should still be able to list and see prior questions we have asked.

**Why.** If two entry points disagree about whether they continue or start fresh, the athlete lands in a conversation they did not expect.

**What it touches.** Ambient conversation controller, chat route, history list, opener.

> 2026-09-15 answered by mp-275

## mp-215 · Is sending the whole context every turn wasteful
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-019
- image: none
- caption:
- screen: none (algorithm/data)
- source: Lee on the page 2026-09-13, rejecting mp-019

**Context.** The model keeps nothing between calls. Every turn is a fresh request that carries the persona, the athlete context block, and the recent history, so the model reads the context again each time. That is how every chat model works, including the one behind this page. Provider prompt caching can make a repeated prefix much cheaper without changing what is sent. The alternative is to leave the context out and fetch pieces by tool when the model asks, which saves tokens but makes Vana forget things unless she remembers to ask.

**Question.** Do we send the entire context each time? Is this not wasteful? Does Claude not remember this context within a conversation?

**Why.** The decision on cost per turn depends on whether the repeated block can be cached and on how often a turn actually needs it.

**What it touches.** vana-chat context builder, model call options.

> 2026-09-15 answered by mp-276

## mp-216 · How long the opener waits for the read-back
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-009
- image: none
- caption:
- screen: none (algorithm/data)
- source: Lee on the page 2026-09-13, rejecting mp-009

**Context.** When a conversation opens, the previous one is read back in the background to pull out new notes. The opener wants those notes. The shipped rule waited up to 3.5 seconds, then went ahead with the athlete's last words in place of the notes. Lee rejected the fixed wait as too deterministic and asked for a revisit.

**Question.** This is too deterministic. Why are we doing this? We need to revisit it.

**Why.** The opener is the first thing the athlete reads. A wrong wait either delays it or makes it forget last time.

**What it touches.** Opener path in vana-chat, read-back extraction.

> 2026-09-15 answered by mp-278

## mp-217 · How Vana remembers, within and across conversations
- category: Vana's memory
- kind: question
- status: answered
- linked: mp-032
- image: none
- caption:
- screen: none (algorithm/data)
- source: Lee on the page 2026-09-14, on mp-009, mp-026, mp-032 to mp-036, mp-038

**Context.** The model remembers nothing between turns. Every turn is a fresh request carrying the persona, the athlete context, and whatever history the app chooses to resend. Everything that looks like memory is plumbing the app built: a 20-message replay window, a one-sentence episode written mid-conversation and again at the end, a read-back of the previous conversation when the next one opens, a 3.5 second wait for that read-back, and a LAST TALKS line in the context. Seven decisions describe those pieces: mp-009 (rejected), mp-026 (rejected), and mp-032 to mp-036 and mp-038, now held. Lee reviewed them together and asked for a rethink and research before any of them is treated as settled.

**Question.** Do we need previous-conversation extraction like this? We need to remove plumbing like this if it exists. If there is a new conversation, we should have summarised the earlier one sometime before that. Research how other chatbots approach this: whether they summarise, when, how many messages they keep, and how they keep costs low. Is this the best we can do, or is there another way of handling all of this?

**Why.** These pieces decide what Vana knows on any given turn and what each turn costs. A wrong strategy either makes her forget or makes every turn expensive.

**What it touches.** vana-chat history replay, extract.ts, the episode row, the opener path, the context builder. Research: docs/research/conversation-memory-strategies.md (2026-09-14).

> 2026-09-15 answered by mp-277

## mp-267 · What moving from freemium to a trial requires
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-266
- image: none
- caption:
- screen: Paywall
- source: Lee on the page 2026-09-14, on mp-052

**Context.** The app sells AI credit bundles and a Pro subscription, with meal planning behind Pro and general chat costing a credit for free users. Lee is replacing that with a seven-day trial of the whole app followed by purchase. The store products, the RevenueCat offering, the gate flag and the entitlements table were all built for free and Pro. Lee added on 2026-09-14: the app-side entitlements table goes away under the trial model, and meal planning does not ship until the trial exists.

**Question.** We need to discuss what we need to do in order to move away from a freemium to a purchase model. What are the store products and introductory offers, how does RevenueCat run the trial, what can an expired trial still open, what happens to the credits system, and what happens to accounts that exist today?

**Why.** Every paywall decision on this page was written for free and Pro. Until this is answered the three Pro cards cannot be approved as written.

**What it touches.** Store products, RevenueCat offering, entitlements table, gate flag, credits system, Pro screen, mp-254 to mp-256.

> 2026-09-14 opened from Lee's amendment of mp-052
> 2026-09-14 context extended from Lee's verdicts on mp-250 and mp-255
> 2026-09-15 answered by mp-279

## mp-287 · What the coach rule is, once the paywall document arrives
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-286
- image: none
- caption:
- screen: none (algorithm/data)
- source: grill 2026-09-15

**Context.** mp-286 gives coaches nothing special for now. Lee has a rule for coaches in mind that depends on a paywall document Xuan is providing.

**Question.** We have something to say about coaches, but that will rely on a paywall document that Xuan will provide. What do coaches pay, and what does the paywall say to them?

**Why.** Coaches bring athletes in; whether the gate stands between a coach and their athletes decides how the app is sold to teams.

**What it touches.** Coach registration, the app gate, the paywall, mp-286.

> 2026-09-15 opened in the grill, waiting on Xuan's paywall document

## mp-291 · Ticket 13: Every turn after the first is cached
- category: Tickets
- status: proposed
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

## mp-292 · Ticket 14: A long conversation keeps its opening
- category: Tickets
- status: proposed
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

## mp-293 · Ticket 15: The next conversation knows the last one, and never waits
- category: Tickets
- status: proposed
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

## mp-294 · Ticket 16: Every entry point gets the Doll plus what is in view
- category: Tickets
- status: proposed
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

## mp-295 · Ticket 17: Ask Vana about the formula on screen
- category: Tickets
- status: proposed
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

## mp-296 · Ticket 18: The server gates on a two-field RevenueCat cache
- category: Tickets
- status: proposed
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

## mp-297 · Ticket 19: Seven free days, then the paywall, and nothing else
- category: Tickets
- status: proposed
- ticket: 19
- blocked: 18
- depends: mp-279, mp-280, mp-283, mp-284, mp-286, mp-266, mp-270
- image: none
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

## mp-298 · Ticket 20: The monthly Allowance and the top-up sheet
- category: Tickets
- status: proposed
- ticket: 20
- blocked: 18
- depends: mp-281, mp-282
- image: none
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

## mp-299 · Ticket 21: The sandbox run and the release gate
- category: Tickets
- status: proposed
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

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

## mp-311 · How the cached prefix is switched on and where the block lives
- category: Vana's voice and openers
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-311.svg
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 13

**Context.** mp-276 says the repeated prefix is cached and the context block is built once per conversation, refreshed only on a tool write or a new day. The edge functions keep nothing between requests, so "once per conversation" needs a home, and the gateway offers more than one way to ask for caching. Ticket 13 chose both.

**Question.** How is caching switched on, and where does the block wait between turns?

**Decision.** 
1. Caching is a call-level option. Every gateway call carries the Anthropic cache-control setting in automatic mode. Nothing marks individual blocks of the prompt.
2. The block is stored on the conversation row, with the day it was built for. A turn reads it back. A missing block or a different day rebuilds it.
3. A tool write clears the stored block on every conversation of the athlete, not only the one that wrote, because the block describes the athlete, not the conversation.
4. The cache-read count on the call log is null when the provider reported nothing and 0 when it reported zero, so a real zero stays visible.
5. Every function that imports the changed shared modules deploys together (chat, action, Jade, day notes), so a Plan-tab write clears the block on dev too.

**Why.** The call-level option is the only path to Anthropic's automatic mode through the AI SDK and the gateway; per-block markers would need bookkeeping the decision does not ask for. The conversation row is the one place both chat and action functions already read and write.

**What else was considered.** A per-turn fingerprint of the plan, memory and pantry timestamps instead of a stored block (four extra queries a turn, and fragile). Clearing the block for one conversation only (a Plan-tab write from the action function would then miss the chat's block).

**What it touches.** vana-chat, vana-action, jade-chat, vana-day-notes; the conversation and call tables; the plan, memory and tool write paths.

**Details.** On the dev account, conversation 614dbee6: turn 1 input 10886, cache read 4980; turn 2 input 6075, cache read 4980; turn 3 input 6123, cache read 6072. Migration 20260915120000 adds the context and context_day columns and cache_read_tokens.

> 2026-09-15 proposed from wave 1 ticket 13

## mp-312 · The Situation rides on the last user message, not the system prompt
- category: Situation awareness
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-312.svg
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 13

**Context.** The Situation (where the athlete is right now, what they are doing) changes every message. Before ticket 13 it sat inside the system prompt, after the context block. A cached prefix ends at the first byte that differs, so a changing Situation there would break the cache every turn.

**Question.** Where does the Situation go once the prefix is cached?

**Decision.** The Situation leaves the system prompt and is appended to the last user message as a bracketed line. The system prompt is persona then context block and nothing after, so it is identical turn to turn.

**Why.** mp-276 fixes the order tools, persona, context, messages. Anything that changes per message belongs in the messages.

**What else was considered.** Keeping the Situation in the system text and accepting a cache miss on every turn.

**What it touches.** vana-chat prompt assembly; the Situation tests.

> 2026-09-15 proposed from wave 1 ticket 13

## mp-313 · The server's own bookkeeping writes do not rebuild the block
- category: Vana's memory
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-313.svg
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 13

**Context.** mp-276 names the writes that refresh the block: a tool write (plan, memory, pantry, home) or a new day. The server also writes memories on its own: the lazy read-back of the previous conversation, and the episode it writes when a conversation crosses the cap. On dev the read-back landed seconds after turn one and cleared the block, so turn two rebuilt it and read nothing from the cache.

**Question.** Does a memory the server writes for itself count as a tool write?

**Decision.** No. The read-back and the episode write are quiet: they add memories without clearing the stored block. The next tool write or the next day picks them up.

**Why.** mp-276 names tool writes and the day. The read-back is the server tidying up after the last conversation, not the athlete changing something.

**What else was considered.** Treating every memory write alike, which is what broke the cache on dev.

**What it touches.** The memory and extraction modules on the server.

> 2026-09-15 proposed from wave 1 ticket 13

## mp-314 · The context block's budget is 1500 estimated tokens
- category: Vana's memory
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-314.svg
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 13

**Context.** mp-218 says the block has a token budget, enforced by a test, and that the number is set when the test lands and recorded on the record. Ticket 13 landed the test.

**Question.** What is the budget number, and how is it counted?

**Decision.** The test builds the block for the representative fixture athlete and fails when its estimated token count passes 1500. The estimate is characters divided by four; no tokenizer runs in the test.

**Why.** The fixture block sits well under the number today, and an estimate keeps the test free of a model dependency.

**What else was considered.** A real tokenizer count (exact, but a dependency in the test lane).

**What it touches.** The context block test on the server.

**Details.** Constant CONTEXT_BLOCK_TOKEN_BUDGET = 1500 in the test.

> 2026-09-15 proposed from wave 1 ticket 13

## mp-315 · Which writes outside Vana's tools should clear the block
- category: Vana's memory
- kind: question
- status: open
- linked: mp-311
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 13

**Context.** mp-311 clears the stored block on a tool write. Some writes the block reads from do not go through a Vana tool: the home location saved from the app's own screen (ticket 02), a thumbs vote on a meal (the LIKES line), and edits to the users row. After any of them the block stays as it was until the next tool write or the next day.

**Question.** Does a home location, a thumbs vote or a profile edit made outside Vana need to reach the block at once, or is "next tool write or next day" enough?

**Why.** Each path added to the invalidation set is a query on a write path that today knows nothing about Vana.

**What it touches.** The home-location write in the app, meal feedback, the users row, mp-311.

> 2026-09-15 opened in wave 1 ticket 13

## mp-316 · Whether the tools and persona are cached across conversations
- category: Vana's voice and openers
- kind: question
- status: open
- linked: mp-311
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 13

**Context.** In automatic mode the cache breakpoint sits at the end of the prompt, so a brand-new conversation's first turn reads zero: its prefix ends in a message no earlier call has seen. The tools and persona, identical for every athlete, could be reused across conversations with an explicit breakpoint on the system prompt in addition to automatic mode.

**Question.** Should the first turn of a new conversation read the tools and persona from the cache, at the cost of one explicit breakpoint?

**Why.** The first turn is the biggest call of a conversation (dev: 10886 input tokens on turn one against about 6000 after).

**What it touches.** vana-chat prompt assembly, the call log.

> 2026-09-15 opened in wave 1 ticket 13

## mp-317 · The entitlement row's shape and how events land on it
- category: Pro and paywall
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-317.svg
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 18

**Context.** mp-285 shrinks the entitlements table to a cache of RevenueCat: active until and period type, written only by the webhook, with an event older than the row ignored. Ticket 18 wrote the migration and the handler and had to settle what "older than the row" is stored as and what each event kind does to the row.

**Question.** What exactly is on the row, and what does each event do to it?

**Decision.** 
1. The row holds the user id, active until, period type and the event time. Every other column is dropped. The event time is what "older than the row" compares against.
2. A transfer closes the old owner's row at the transfer time and writes the new owner's, so a late event for the old owner is stale and ignored.
3. A test event writes nothing: a ping has no expiry and must not touch the cache.
4. An expiration whose payload names a later expiry closes the row at the event time, so a clock-skewed payload cannot keep a lapsed subscriber active.
5. Signed-in users may only read the table. No app-side insert or update is granted.

**Why.** Each clause is what mp-285's "RevenueCat wins" and "nothing app-side grants" need once real event shapes are in front of the writer.

**What else was considered.** Keeping the old column names (expires at, updated at). Deleting the old owner's row on transfer instead of closing it.

**What it touches.** The webhook handler, the entitlements table, the migration, the server gate.

**Details.** Migration 20260916110000, applied to dev (11 columns and 0 rows before; 4 columns after). An insert as the authenticated role fails with 42501. Thirty handler test steps run against RevenueCat-shaped events.

> 2026-09-15 proposed from wave 1 ticket 18

## mp-318 · The internal-device flag no longer opens the gate
- category: Pro and paywall
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-318.svg
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 18

**Context.** The server's Pro check used to pass anyone whose users row said internal, a flag the app itself writes when a tester marks the device. mp-285 clause 3 says nothing grants an entitlement from the app side, ever.

**Question.** Do testers keep a bypass on the server?

**Decision.** 
1. The internal flag no longer opens the server gate. The gate reads active until and period type and nothing else.
2. A tester who needs access gets a promotional entitlement from RevenueCat, which arrives on the row through the webhook like any purchase.
3. The users column stays; the app still writes it for its own dev features.
4. The four Vana functions that call the gate were not redeployed in ticket 18. The new gate goes live on dev with their next deploy; until then dev Vana calls pass on the old code.

**Why.** An app-written flag is an app-side grant. Clause 4 kept the wave's other simulators working: the dev table had zero rows.

**What else was considered.** Keeping the bypass for dev builds only.

**What it touches.** The server gate, RevenueCat promotional grants, the dev deploy order.

> 2026-09-15 proposed from wave 1 ticket 18

## mp-319 · The store offers are written by script, on the dev apps, per territory
- category: Pro and paywall
- status: proposed
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

## mp-320 · Which debiting calls the gate covers
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-296
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 18

**Context.** Ticket 18 says every Vana or debiting call is gated on the two fields. The gate has four callers, all Vana functions. The functions that debit AI credits (describe, photo, the coach chat) check the wallet and not the entitlement.

**Question.** Does a credit-debiting call need the entitlement too, or is a paid credit its own permission?

**Why.** A lapsed subscriber with credits left can still spend them today. Whether that is a feature or a hole decides whether ticket 20 adds the check.

**What it touches.** The credit-debiting functions, the server gate, ticket 20.

> 2026-09-15 opened in wave 1 ticket 18

## mp-321 · When production gets the two-field table, the wider webhook and the offers
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-319
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 18

**Context.** Ticket 18 changed dev only: the migration, the webhook deploy, the RevenueCat integration's event list and the store offers. Production still has the old table, the old webhook, an integration that delivers three event types and no introductory offers. The webhook is env-unfiltered, so a production event reaching the new handler after the migration would be handled correctly; before it, the old handler keeps writing the old columns.

**Question.** Which release carries the production migration, the webhook deploy, the integration change and the store offers, and in what order?

**Why.** The playbook orders schema before functions; the offers can go first since nothing reads them until a purchase.

**What it touches.** The cutover runbook, production RevenueCat, the production store listings.

> 2026-09-15 opened in wave 1 ticket 18

## mp-322 · Who runs the checks a wave cannot run on a simulator
- category: Process and scope
- kind: question
- status: open
- linked: mp-296
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 18

**Context.** Two of the wave's criteria need a hand on a device: a sandbox purchase on the dev app (ticket 18; a simulator cannot sign into a sandbox App Store account, and a StoreKit-configuration purchase never reaches RevenueCat) and a second dev account seeing no review box (ticket 25; the agent proved it with the policy test and a widget test instead of signing the simulator into another account). Both tickets were merged with those lines unticked.

**Question.** Does a criterion only a person on a device can verify count as done when its tests pass, or does it stay open until Lee runs it, and where is that recorded?

**Why.** The wave rule says an unfinished criterion fails the ticket. Applied literally, ticket 18 and 25 could never pass, and tickets 19, 20, 21, 28 and 32 wait on them.

**What it touches.** The wave rule in the implement skill, tickets 18 and 25.

> 2026-09-15 opened in wave 1

## mp-324 · Whether plan rows should ever show photos
- category: Plan tab
- kind: question
- status: open
- linked: mp-323
- image: none
- caption:
- screen: Plan tab
- source: wave mealplanning 1 ticket 22

**Context.** The plan tile, the plan bar and the review sheet carry no image data: a plan meal stores its name, slot and icon key, no picture. With the icons gone, every meal on those surfaces shows the placeholder, not only meals without a photo. The Meals tab, which has the library's picture data, shows mosaics where they exist.

**Question.** Should plan rows carry the meal's picture, or is the plain box the intended look for the plan?

**Why.** Carrying the picture means the plan meal row grows picture fields and the add and swap paths copy them, the same shape as the icon key today.

**What it touches.** Plan tab tiles, the plan bar, the review sheet, the plan meal row.

> 2026-09-15 opened in wave 1 ticket 22

## mp-325 · Which specs the wave left describing the old behaviour
- category: Design system
- kind: question
- status: open
- linked: mp-323
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 tickets 22 and 23

**Context.** Two specs under docs/ssot/spec now describe what the build no longer does. The mosaic component spec (meal-image-mosaic.md v1.1, MIM-9) and the widget's header comment describe an icon state that ticket 22 removed. The Vana sheet spec's "Where the launcher does not appear" describes the flow-screen and exclusion lists ticket 23 deleted. Both files are QA-owned and were not edited.

**Question.** Who amends MIM-9 and the launcher section in the QA repo, and should the placeholder get a design spec of its own?

**Why.** The next design sync would report the widgets as drifting from their specs.

**What it touches.** docs/ssot/spec/design/components/meal-image-mosaic.md, the Vana sheet spec, the QA repo.

> 2026-09-15 opened in wave 1

## mp-326 · A pushed page is detected by its route kind, not its name
- category: The sheet and launcher
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/timeline-launcher.png
- caption:
- screen: Any screen with the launcher
- source: wave mealplanning 1 ticket 23

**Context.** mp-264 makes the launcher an allow-list of three routes and says any page pushed over one of them hides it without naming itself. Ticket 11 had made pushed forms name themselves through route settings, because a plain page push is invisible to the router. Ticket 23 needed a way to see the push without the page's help.

**Question.** How does the launcher know a page was pushed over one of its three screens?

**Decision.** 
1. The root navigator observer already watches the stack. It now reports whether the top non-popup route is a router page or a plain push: a router page carries a page object, a plain push carries only route settings.
2. The launcher shows when the current location is one of the three and nothing is pushed and no popup is open. A dialog over a pushed page changes nothing.
3. Coach formulas means the formula library route exactly. The system formula detail and the personal editor are pushes under it and hide the launcher.
4. The meal-planning screen is the food route. The Food tab on the main tabs screen is covered by the main route. Matching is on the path; query strings never matter.
5. Four route-settings workarounds were removed, not three: the log-scanned-food screen had the same one.
6. The route check that keeps a Vana screen from becoming the Situation's screen stays; it no longer has a say in the launcher.

**Why.** The observer was already the thing that extracted a name from a push; testing the route's kind instead costs nothing and needs no page to cooperate. A router push is covered separately because it changes the location.

**What else was considered.** Keeping a name and matching it (rejected by mp-264 clause 3). Probing the modal route from the host (the host sits above the navigator and cannot).

**What it touches.** The launcher rule, the companion host and its observer, ten push sites that passed route settings.

**Details.** Rule test walks every route the router declares. Simulator: launcher on the Timeline, the Food tab and the formula library; none on Settings, the Diet screen, the formula editor, Log a Meal, Event Details or the New Event form; it returns on swipe back.

> 2026-09-15 proposed from wave 1 ticket 23
> 2026-09-15 picture reused from docs/ssot/decisions/images/mealplanning/timeline-launcher.png

## mp-327 · How the dev-tools switch is stored and applied
- category: Process and scope
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/settings.png
- caption:
- screen: Settings
- source: wave mealplanning 1 ticket 24

**Context.** mp-271 gives dev builds a Settings switch that turns the accessibility and wrench buttons off and on per tester per device, default on, remembered across launches, no build flag. Ticket 24 built it and settled where it is stored, where it sits and how the buttons go.

**Question.** Where is the switch kept, and how do the buttons leave and return?

**Decision.** 
1. The value is a shared-preferences key on the device, default on. A keep-alive controller owns it, since the app shell watches it for the app's lifetime.
2. The app shell is a widget of its own that watches the controller, so a flip rebuilds the shell and not the whole app.
3. Off unmounts the tools wrapper entirely. The navigator keeps its state through the remount because it carries a global key; Settings stayed at its scroll position on the device.
4. The switch sits in its own "Dev build" card at the bottom of Settings, visible in every dev build with no seven taps, because mp-271 says it is shown in dev mode.
5. Its two strings are hardcoded like the neighbouring tester card; the content system has no keys for dev-only copy.
6. The environment indicator file the ticket named is mounted nowhere and was left alone. The buttons live in the app shell.

**Why.** Per device and across launches is what shared preferences already give the app's other device settings. The accessibility package has no option to hide its button, so the wrapper has to go.

**What else was considered.** The keychain store the internal-device flag uses (survives reinstall, which the decision does not ask for). Watching the controller from the root widget (a whole-app rebuild). Hiding the buttons inside the wrapper (impossible without forking the package's overlay).

**What it touches.** Settings, the app shell, the dev accessibility and testing tools.

**Details.** Key dev.tools_visible. Simulator: off removed both buttons live, on restored them, the value held across terminate and relaunch.

> 2026-09-15 proposed from wave 1 ticket 24
> 2026-09-15 picture captured at 1.26.0+1, f30e3897

## mp-328 · Where the Dev build card sits on Settings
- category: Design system
- kind: question
- status: open
- linked: mp-327
- image: none
- caption:
- screen: Settings
- source: wave mealplanning 1 ticket 24

**Context.** The floating dev buttons sit over every screen. When Settings is scrolled to the bottom they cover the right edge of the new switch; its left half is still tappable.

**Question.** Should the Dev build card sit higher on Settings, or the buttons leave room for it?

**Why.** The switch that hides the buttons is the one control they overlap.

**What it touches.** Settings, the dev buttons.

> 2026-09-15 opened in wave 1 ticket 24

## mp-329 · How a review is written and who may read it
- category: Meals tab and library
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/meal-detail.png
- caption:
- screen: Meal detail
- source: wave mealplanning 1 ticket 25

**Context.** mp-144 clause 3 gives a signed-in admin a comment box on every meal page, each comment landing in a table for the team. Admin is a boolean on the user record, set by hand. Ticket 25 built the box and had to settle how the client learns the flag, what the row holds and who reads the table.

**Question.** How does the client learn it is an admin, what does a review write, and who can read reviews?

**Decision.** 
1. The client reads the admin flag once per session with one select on its own users row. Any failure reads as not admin.
2. The insert policy trusts the users row whose id is the signed-in user, the same match the existing users policies use.
3. A review is one remote insert that waits for the returned id. No local row, no upload state.
4. The row holds the meal's source and id, the meal's name, the verdict, the reason (capped at 2000 characters) and the reviewer. The app version column exists and is left empty.
5. Admins may read every review. Athletes read none.
6. The box is two chips (Good recipe, Not good), a reason field and a send button, disabled until both are set. Sending clears the box for the next comment. Offline shows the needs-connection warning; any other failure, a refused insert included, shows the server error.

**Why.** The team reads reviews across users, so the write waits for the remote ack (the coach-on-athlete rule). Denormalising the name lets the team read the table without a join.

**What else was considered.** Adding the flag to the Drift profile mirror (a schema bump for a read-only boolean). Writing through an action function or an RPC (no server logic needed; the policy is the gate).

**What it touches.** Meal detail, the meal detail controller, the review repository, the users and meal_reviews tables.

**Details.** Migration 20260916120000, applied to dev. The dev capture account is admin on dev; a second dev account reads false. First review row 45557810 on dev, library AD-101, good, 2026-09-15 14:59 UTC.

> 2026-09-15 proposed from wave 1 ticket 25
> 2026-09-15 picture captured at 1.26.0+1, f30e3897

## mp-330 · How the team reads reviews, and when production gets the table
- category: Meals tab and library
- kind: question
- status: open
- linked: mp-329
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 25

**Context.** Reviews land in a table only admins can read, through the database. Nothing in the app or elsewhere lists them. The app version column is empty. Production has neither the flag nor the table, and someone must hand-set the flag for the team's production accounts.

**Question.** Does the team need a read surface for reviews (a screen, an export), should the app version be stamped on each row, and which release carries the migration and the hand-set flags?

**Why.** A table nobody reads collects nothing useful.

**What it touches.** meal_reviews, the cutover runbook, the team's production accounts.

> 2026-09-15 opened in wave 1 ticket 25

## mp-331 · Typed feedback files through the SDK's own service graph on the device
- category: Feedback loop
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: wave mealplanning 1 ticket 26

**Context.** mp-245 clause 6 says Vana's feedback tool also files a Wiredash entry, the entry is created on the device, and the device hand-off is the open detail. Ticket 26's first step was to find the ingest path or stop.

**Question.** How does a typed complaint reach the Wiredash inbox?

**Decision.** 
1. Wiredash has no server API. The SDK posts to a private endpoint with the project secret and device metadata, and nothing documents it for server use. The server is untouched.
2. The SDK has no public headless submit either. The app builds the SDK's own service graph for one entry (same project, secret, install id, device metadata and offline retry queue as a shaken report), submits, and disposes it.
3. When the chat receives the feedback-saved part, the controller files the entry with the athlete's words and custom metadata: source vana_chat, sentiment, about, conversation id, plus the signed-in user's id and email. No console label is attached.
4. Filing is awaited inside the turn, one attempt, then the SDK's queue takes over. A failure is logged and never shown; the row already acknowledged the feedback.
5. The Wiredash package is pinned to one exact version, and one file imports its internals.

**Why.** The SDK's graph produces an entry indistinguishable from a shaken report. A hand-rolled post would fabricate device metadata and duplicate install ids.

**What else was considered.** A server-side post to the private endpoint. Fire-and-forget filing (kept awaited so the seam test is deterministic). A cached SDK instance next to the root widget's.

**What it touches.** The feedback filer, the chat controller, the pubspec pin.

**Details.** wiredash 2.6.0. On the simulator the SDK logged a submitted entry for "You keep suggesting fish on weeknights and I never make it"; the inbox entry (custom source vana_chat, dev environment, 2026-09-15 about 09:54) is for Lee to confirm.

> 2026-09-15 proposed from wave 1 ticket 26
> 2026-09-15 picture captured at 1.26.0+1, f30e3897

## mp-332 · Whether the implementation import stands, and how the inbox tells typed feedback apart
- category: Feedback loop
- kind: question
- status: open
- linked: mp-331
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 26

**Context.** The filer reaches into the Wiredash package's internals and pins its version, so every upgrade needs the filer re-checked. Typed entries carry custom metadata but no console label, and they follow the build's environment (a debug build files as dev) like shaken reports do.

**Question.** Is an internal import with a version pin acceptable here, or should Wiredash be asked for a public headless API? Should typed feedback carry a console label so the inbox can filter it, and which one?

**Why.** A silent break on upgrade would drop typed feedback without anyone noticing.

**What it touches.** The feedback filer, the Wiredash console, the pubspec.

> 2026-09-15 opened in wave 1 ticket 26

## mp-333 · How the rolling summary is stored and replayed
- category: Vana's memory
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-333.svg
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 14

**Context.** mp-277 chunks a conversation's history at forty messages, writes the summary at thirty in the background and keeps it on the conversation row keyed by the message index it covers. The lead write at fifty produces the summary for forty while the summary for twenty is still the one applied until sixty, so one text column has to hold two summaries for ten turns. Ticket 14 settled how.

**Question.** How does one column hold the applied summary and the one waiting, and what does the replay look like between boundaries?

**Decision.** 
1. The `summary` column holds up to two parts, each opening with `Through message N:`; `summary_index` is the newest part's index. The replay applies the newest part at or under the applied boundary.
2. Boundaries are fixed multiples of twenty, so the cached prefix changes once per chunk. Between them the verbatim run grows: sixty-one messages replay one rolled summary plus twenty-one verbatim, exactly twenty at forty and sixty.
3. When nothing was stored by forty (a failed or rate-limited lead write), every message replays verbatim and the turn writes the missing summary as a catch-up. A write re-reads the row first, so a slow write never rolls a newer one back.
4. The summariser reads picker meal names as well as words, so a meal picked by tap survives the chunk.
5. The end-of-conversation episode no longer writes the `summary` column; the column belongs to the compaction alone.

**Why.** Two summaries in one column keeps the migration to the index column the ticket allowed; fixed boundaries keep the cache stable; the catch-up makes a missed write cost tokens and never content.

**What else was considered.** Re-summarising into one paragraph at fifty (loses the applied summary for ten turns); a second column (the ticket allowed only the index column); an exact twenty verbatim on every turn (moves the boundary each turn and churns the cache).

**What it touches.** vana-chat and jade-chat (`_shared/vana/chat.ts`, `extract.ts`), the conversation row, the conversation list's preview text.

**Details.** Rate bucket `vana.episode` is now `vana.summary` at 3 a minute. Migration 20260916100000 adds `summary_index integer`. Eval: a 45-message conversation answered "which dinner did I pick for Tuesday, and who is coming over?" from messages 1 to 20 outside the window.

> 2026-09-15 proposed from wave 2 ticket 14

## mp-334 · What the conversation list shows now the episode does not write the summary
- category: Vana's memory
- kind: question
- status: open
- linked: mp-333
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 14

**Context.** The conversation list reads `vana_conversations.summary` as each row's preview. Under mp-333 that column is the compaction's, holding "Through message 20: …" text for long conversations and nothing for a conversation under thirty messages, since the episode writer no longer fills it.

**Question.** Should the list preview read the episode sentence instead, and may the "Through message N" form ever show on screen?

**Why.** Today a short conversation's preview goes blank and a long one shows the lead-in string.

**What it touches.** The conversation list screen and its repository read.

> 2026-09-15 opened in wave 2 ticket 14

## mp-335 · How the one gate is wired in the client
- category: Pro and paywall
- status: proposed
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- screen: Paywall
- source: wave mealplanning 2 ticket 19

**Context.** mp-279, mp-280 and mp-284 make RevenueCat's cached entitlement the only gate, lock an unknown answer after a couple of seconds, and put the whole app behind the paywall. Ticket 19 built the client side and made the choices the record left open.

**Question.** What does the client read, when, and how does an unlocked account leave the paywall?

**Decision.** 
1. The client reads RevenueCat only. The server's entitlement table is never read by the app; the repository that used to read it is now the auth-identity seam alone.
2. Startup resolves the gate on the critical path, bounded by the two-second cap, so a subscriber's cold start never flashes the paywall.
3. Before trusting the cache the app checks the SDK's identity: a different app user id logs in first, and if that cannot happen offline the answer is locked.
4. The paywall route redirects to the app whenever the gate is unlocked, so a purchase, a restore or a background refresh moves the person in without the screen navigating. An entitled account can never view the paywall.
5. The tester tap-grant, the `users.is_internal` mirror in the gate, the purchase-enabled flag and the gate flag are gone. Testers need a real entitlement: a Test Store purchase or a RevenueCat grant.
6. The introductory offer shows unless the store says the person is ineligible. "Manage subscription" opens RevenueCat's management URL, else the platform's subscriptions page.
7. A Pro-required answer from a Vana call warns and refreshes the status; the router alone moves onto the paywall.

**Why.** Each clause follows from "RevenueCat is the only gate": no second source of truth, no bypass, and the router as the one place the gate is enforced.

**What else was considered.** Keeping the tester grant for debug builds (a second gate, and the server dropped its own bypass in ticket 18); letting the paywall pop itself on success (two owners of navigation).

**What it touches.** `lib/features/subscription/`, the router, app startup, the Vana chat screen, the main tabs shell, `codemagic.yaml` (the removed flags and the removed Patrol paywall flow).

**Details.** Seam tests: 17 through the status controller, 9 through the paywall controller, a router redirect test, light and dark goldens of the paywall. The Drift `user_entitlements` table stays in the schema unused until a schema bump.

> 2026-09-15 proposed from wave 2 ticket 19
> 2026-09-15 picture reused from test/features/subscription/presentation/goldens/paywall_light.png

## mp-336 · The purchase half of the paywall check is done by a person on TestFlight
- category: Pro and paywall
- status: proposed
- image: test/features/subscription/presentation/goldens/paywall_light.png
- caption:
- screen: Paywall
- source: wave mealplanning 2 ticket 19

**Context.** Ticket 19's last criterion asks that a sandbox account without an entitlement sees the paywall on launch, and that Restore after a sandbox purchase reopens the app. The first half ran on a pool simulator (the paywall with Test Store prices, Restore leaving it locked). A simulator cannot sign into a sandbox account, so the second half cannot be observed by any wave agent, on this wave or a later one.

**Question.** Who verifies that Restore after a sandbox purchase reopens the app?

**Decision.** The purchase-then-Restore check is the ratifier's, on a TestFlight build with a sandbox account. The ticket is done on the code and the first half of the check; the wave does not rebuild it for a criterion no agent can meet.

**Why.** Rebuilding the ticket against the same impossibility produces the same result; the person with a device and a sandbox account is the one who can see it.

**What else was considered.** Failing the ticket and re-queueing it (no path to the observation); a RevenueCat promotional grant as a stand-in (it proves the gate reacts, not that a store purchase restores).

**What it touches.** The paywall, the release checklist.

> 2026-09-15 proposed from wave 2 ticket 19
> 2026-09-15 picture reused from test/features/subscription/presentation/goldens/paywall_light.png

## mp-337 · What the web build does behind the one gate
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-335
- image: none
- caption:
- screen: Paywall
- source: wave mealplanning 2 ticket 19

**Context.** The web build has no RevenueCat key, so under the one gate every web user, coaches included, meets the paywall with no store to buy from. Nothing was bypassed, as mp-286 asks; the coach portal is therefore unusable on the web until a rule exists.

**Question.** Does the web build get a RevenueCat web key, a coach grant, or stay closed until Xuan's paywall document?

**Why.** The web coach test login and every coach on the web are locked out today.

**What it touches.** The web build, the coach portal, the gate.

> 2026-09-15 opened in wave 2 ticket 19

## mp-338 · How test accounts hold an entitlement
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-335
- image: none
- caption:
- screen: Paywall
- source: wave mealplanning 2 ticket 19

**Context.** With the tester grant gone, a debug build opens on the paywall for any account without a RevenueCat entitlement. The dev account had none, so the wave granted it the `pro` entitlement in RevenueCat (promotional, until 2027-09-15, revocable) so the dev simulator can reach the screens behind the gate. The server's dev entitlement table also had no rows until the wave's agents inserted two by hand for the eval user and the dev account.

**Question.** Is a RevenueCat promotional grant the standing way every test account gets in, and who holds the list of grants?

**Why.** Every dev account and every tester on TestFlight is locked out until someone grants or buys.

**What it touches.** RevenueCat customers, the dev entitlement table, the dev simulator login script.

> 2026-09-15 opened in wave 2 ticket 19

## mp-339 · Who writes the internal-device flag now
- category: Data, sync and backend
- kind: question
- status: open
- linked: mp-335
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 19

**Context.** The app no longer writes `users.is_internal`; the gate stopped reading it and the tester grant that set it is gone. The analytics module on the server still reads the column to exclude internal devices from Mixpanel.

**Question.** Does Mixpanel exclusion need another writer for `is_internal`, or does the column retire?

**Why.** Without a writer, new internal devices count as athletes in analytics.

**What it touches.** The users row, the analytics edge module, Settings' internal-device flag.

> 2026-09-15 opened in wave 2 ticket 19

## mp-340 · The monthly Allowance is 300 credits
- category: Pro and paywall
- status: proposed
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

## mp-341 · How the Allowance lives in the wallet and rolls
- category: Pro and paywall
- status: proposed
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

## mp-342 · The top-up sheet and the composer strip
- category: Pro and paywall
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: wave mealplanning 2 ticket 20

**Context.** mp-282 puts the top-up sheet on the button that would debit, with one line above Vana's composer and one 402 handler in the shared layer. Ticket 20 built the sheet's allowance lines, the strip and the handler.

**Question.** What does the sheet say, where does the handler live, and when does the strip come down?

**Decision.** 
1. The sheet keeps the word "tokens" and adds "Your plan includes 300 tokens a month · N left · renews <date>" above the two packs, reading the wallet row live rather than the 402 body.
2. The one handler lives in the credits feature's presentation folder and every debiting call site imports it; a second sheet never stacks on the first.
3. The strip above Vana's composer reads "Out of tokens for now — top up to keep chatting · Top up", the typed text goes back into the field, and the strip comes down on its own when the wallet rises or a turn goes through.
4. The AI coach chat rolls a 402 turn back with no line in the thread, as Vana does.

**Why.** One handler keeps a new debiting feature covered for free; the wallet row is one source the sheet already watches; moving the sheet into `lib/shared/` would pull RevenueCat into shared code.

**What else was considered.** A handler under `lib/shared/` (drags purchase controllers into shared); reading the sheet's numbers from the 402 body (a second source).

**What it touches.** The Vana chat screen, the top-up sheet, the describe, log-meal, edit-log, photo-capture, coach insight and AI coach call sites.

**Details.** The sheet's allowance lines render only when `allowance_monthly` is above zero, so a subscriber whose grant has not landed sees the packs alone.

> 2026-09-15 proposed from wave 2 ticket 20
> 2026-09-15 picture captured at 1.26.0+1, 2656d4b8

## mp-343 · Whether the free monthly grant retires
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-341
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 20

**Context.** Every wallet still receives 20 free credits a month (50 on dev) from the old free tier, non-expiring, subscriber or not. Under mp-266 there is no free tier; the allowance is the subscriber's grant.

**Question.** Does the free monthly grant retire now, and what happens to the free credits already in wallets?

**Why.** Two grants a month blur what the allowance is, and the free one never expires.

**What it touches.** `ensure-credits`, the client's monthly stamp, the wallet SQL.

> 2026-09-15 opened in wave 2 ticket 20

## mp-344 · What a transfer or a plan change does to the allowance
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-341
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 20

**Context.** A RevenueCat TRANSFER moves the entitlement row to another user; the wallet's allowance and packs stay with the old one, as packs did before. A PRODUCT_CHANGE between monthly and annual grants nothing itself; the next window comes from the roll.

**Question.** Should the allowance follow a transfer, and should a plan change open a new window at once?

**Why.** Both are rare, and both leave a subscriber with a wallet that does not match their entitlement for up to a month.

**What it touches.** The webhook, the wallet roll.

> 2026-09-15 opened in wave 2 ticket 20

## mp-345 · Where the origin label sits and what it says
- category: Recipes and cooking
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/meal-detail.png
- caption:
- screen: Meal detail
- source: wave mealplanning 2 ticket 32

**Context.** mp-146 labels a recipe's steps by origin: verbatim with "as published by X" and a link, an alternate source named, a simple assembly said, AI-generated with the sparkle. Ticket 32 chose the placement, the copy and the fallbacks.

**Question.** Where does each origin's label render, and what does it say when the row lacks a name or a link?

**Decision.** 
1. AI-generated keeps its sparkle badge on the DIRECTIONS row with the unchanged tooltip. The other three origins render as one line under the row: "As published by {name}" linked to the original, "Steps from {name}" (linked when a url exists), "A simple assembly, no recipe needed".
2. A verbatim row with no publisher name falls back to the link's host; with neither, nothing renders. No recorded origin renders nothing.
3. The label is one widget with an open-link callback, so a test records the tap without the url launcher; the screen passes the app's external launcher.

**Why.** A full sentence does not fit beside "DIRECTIONS" at phone width; the fallbacks keep a partial row honest instead of blank or wrong.

**What else was considered.** A badge for every origin (too little room for a name and a link); adding publisher fields to the domain (the row already carried origin, source url and source name).

**What it touches.** The meal detail screen, the directions origin label widget, three content keys.

**Details.** Goldens per origin, light and dark, at 390 px: the existing "See the original recipe" row overflows at 320 and 360 px on the base commit. The Sanity content was not touched; the strings are defaults.

> 2026-09-15 proposed from wave 2 ticket 32
> 2026-09-15 picture captured at 1.26.0+1, 2656d4b8

## mp-346 · The origin copy, the doubled link and the narrow-width overflow
- category: Recipes and cooking
- kind: question
- status: open
- linked: mp-345
- image: none
- caption:
- screen: Meal detail
- source: wave mealplanning 2 ticket 32

**Context.** The wave wrote the alternate-source and assembly wording itself. A verbatim row now links the original twice: from the new label and from the existing "See the original recipe" row. That row overflows by 47 px at 320 and 7 px at 360 on the base commit, outside the ticket.

**Question.** Is "Steps from X" the wording for an alternate source and a sentence right for an assembly, does the verbatim row keep both links, and is the overflow fixed now?

**Why.** Copy is Xuan's to rule; two links to one page and an overflow on small phones are visible to athletes.

**What it touches.** The meal detail screen, the content defaults.

> 2026-09-15 opened in wave 2 ticket 32

## mp-347 · The idle signal is answered at once and written in the background
- category: Vana's memory
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-347.svg
- screen: none (algorithm/data)
- source: wave mealplanning 3 ticket 15
- detail: yes

**Context.** mp-288 puts the idle signal on the chat call and makes the server idempotent. Ticket 15 had to choose how the server answers, what makes a repeat write nothing, and which calls the flag rides on.

**Question.** How the server takes an idle signal.

**Decision.** 
1. An idle call is answered 202 with the conversation id straight away; the episode and missed notes are written in the background (waitUntil), so a dropped connection cannot cut the write off.
2. A repeat writes nothing because of the existing read_back_at claim on the conversation. The claim is released when the write fails, is rate limited, or the conversation is too short to extract.
3. Idle is handled at the top of the chat run for persisted conversations only, on vana-chat and jade-chat, and is never charged a credit. It skips the per-call chat rate limit; the extractor's own limit and the claim bound the model cost.

**Why.** Nothing on the client waits on the reply (mp-288 clause 2), and the claim already stopped double extraction, so no new column was needed.

**What else was considered.** Answering after the write finished; checking whether an episode row exists instead of the claim.

**What it touches.** supabase/functions/_shared/vana/chat.ts, extract.ts, schemas.ts (IdleAckZ), vana-chat.

**Details.** Seam: 5 idle tests in personal_openers.test.ts; vana Deno tests 134 passed. Eval opener-never-waits: headers in 2863 ms with the previous conversation never signalled. The contract doc docs/implement_mealplanning/02-contract.md does not yet list the idle field or the 202 reply.

> 2026-09-15 proposed in wave 3 ticket 15

## mp-348 · When the app tells the server a conversation is idle
- category: The sheet and launcher
- status: proposed
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: Vana sheet
- source: wave mealplanning 3 ticket 15

**Context.** mp-288 clause 2 says the client signals idle when the sheet closes, the app goes to the background, or a new conversation starts. The sheet holds one conversation per day, and it can hand a conversation over to the full-screen chat.

**Question.** Exactly which moments in the app send idle, and how often.

**Decision.** 
1. The ambient conversation controller owns the signal and stays alive with the app, listening for the app being hidden, so the background signal fires with no sheet open.
2. "A new conversation starts" means the held conversation is replaced: a new day, or the server naming a different conversation.
3. A conversation is signalled at most once until the sheet opens it again.
4. Handing the sheet over to the full-screen chat is not idle; the conversation carries on there.
5. The signal is fire-and-forget; the repository logs a failure and never throws.

**Why.** All three moments are testable through one notifier, and signalling once per opening avoids a function call on every app hide.

**What else was considered.** A lifecycle listener in the host widget; signalling on every hide; treating every sheet pop, hand-off included, as idle.

**What it touches.** Vana sheet (vana_companion.dart), vana_ambient_conversation_controller.dart, vana_chat_repository.dart.

**Details.** 13 notifier tests in vana_ambient_conversation_test.dart. Device check on a pool simulator: told Vana a sister visiting is allergic to sesame, closed the sheet, the episode landed on DEV; a new conversation's opener offered "Ready for Saturday's dinner (Ingrid's visit)".

> 2026-09-15 proposed in wave 3 ticket 15
> 2026-09-15 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png

## mp-349 · Does a day's conversation get one episode, or one per close?
- category: Vana's memory
- kind: question
- status: open
- linked: mp-288
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 3 ticket 15

**Context.** The sheet keeps one conversation for the whole day. The first close writes its episode and stamps the claim, and mp-288 clause 3 says a second signal writes nothing. So an athlete who talks in the morning, closes, and talks again at night gets an episode of the morning only; the client signals again after the sheet reopens, and the server discards it. The code follows the record; the wave's spec review flagged it against the ticket's story (the opener knows what last night established).

**Question.** Should a later close re-extract a conversation that has gained turns since its episode (for example, keyed by message count), or does one episode per day's conversation stand and the client stop re-signalling?

**Why.** Evening planning is the ticket's own example, and today it would not reach the next morning's opener.

**What it touches.** extract.ts claim, the ambient conversation controller, mp-288 clause 3.

> 2026-09-15 opened in wave 3 ticket 15

## mp-350 · Should leaving the full-screen chat signal idle?
- category: The sheet and launcher
- kind: question
- status: open
- linked: mp-288
- image: none
- caption:
- screen: Vana chat
- source: wave mealplanning 3 ticket 15

**Context.** Idle is sent from the sheet and on app background. The full-screen chat's New conversation button and leaving the chat route send nothing, so those conversations get their episode only when the app goes to the background.

**Question.** Should the full-screen chat's New conversation and leaving the chat screen also signal idle?

**Why.** A conversation left in the chat screen while the app stays open has no episode for the next opener.

**What it touches.** vana_chat_screen.dart, the chat controller.

> 2026-09-15 opened in wave 3 ticket 15

## mp-351 · Is the "Remembered" card right now that Vana saves more on her own?
- category: Vana's memory
- kind: question
- status: open
- linked: mp-277
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 3 ticket 15

**Context.** When the model saves a note it shows a "Remembered: …" card in the sheet. The sharpened remember rule (mp-277 clause 2) makes self-initiated saves more frequent, so the card appears more often.

**Question.** Is the card acceptable for every save, or should saves Vana makes on her own stay silent?

**Why.** It is the athlete-visible cost of saving things as they are said.

**What it touches.** Vana sheet, persona remember rule.

> 2026-09-15 opened in wave 3 ticket 15

## mp-352 · Does picking up last time in an offer count?
- category: Vana's voice and openers
- kind: question
- status: open
- linked: mp-278
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 3 ticket 15

**Context.** On the device the next opener picked up the previous conversation in one of its offers ("Ready for Saturday's dinner (Ingrid's visit)"), not in its sentence.

**Question.** Is an offer chip that names last time enough, or should the opener's prose say it?

**Why.** The ticket's check was "the opener mentions last time", and this reads it loosely.

**What it touches.** opener prompt, Vana sheet.

> 2026-09-15 opened in wave 3 ticket 15

## mp-353 · How strict is the opener's start-time check?
- category: Vana's voice and openers
- kind: question
- status: open
- linked: mp-278
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 3 ticket 15

**Context.** The eval fails the opener at 3500 ms to headers. It started in 2863 ms, almost all of it building the context block, so a cold start could trip it; it proves the old wait is gone rather than that the opener starts at once.

**Question.** Should the limit be looser, or should the context build get faster so the limit can be tighter?

**Why.** A flaky eval gets ignored.

**What it touches.** scripts/vana-eval/personalization.ts, context build.

> 2026-09-15 opened in wave 3 ticket 15

## mp-354 · How Restore is tested when a store won't resubscribe outside the app
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-289
- image: none
- caption:
- screen: Paywall
- source: wave mealplanning 3 ticket 21

**Context.** The sandbox wizard (ticket 21, not merged this wave) tests Restore by resubscribing in the store's own settings after the trial ends, then tapping Restore purchases. Some sandbox stores may offer no resubscribe outside the app.

**Question.** If a store has no way to resubscribe outside the app, how is Restore proven: a second Mealvana account on the same device (which also exercises the transfer path), or something else?

**Why.** Without it the last step of mp-289 cannot go green on that store.

**What it touches.** scripts/sandbox-trial-wizard.sh step 8, the release gate.

> 2026-09-15 opened in wave 3 ticket 21

## mp-355 · How fresh a green sandbox run must be for a release
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-270
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 3 ticket 21

**Context.** The wizard's README proposes that a green log counts when its commit is in the release candidate's history and nothing since touched the paywall, the gate, the webhook or the Allowance.

**Question.** Is that the rule, or must the run be on the release candidate itself?

**Why.** The gate in the deploy playbook is only as strong as its freshness rule.

**What it touches.** docs/release/sandbox-trial-runs/README.md, playbook §8 P3c.

> 2026-09-15 opened in wave 3 ticket 21

## mp-356 · The release doc still plans a dark launch
- category: Process and scope
- kind: question
- status: open
- linked: mp-270
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 3 ticket 21

**Context.** docs/implement_mealplanning/07-verification-release.md step 3 still ships the feature dark behind PRO_GATE_ENABLED. mp-270 says no dark launch and no gate flag as the release plan.

**Question.** Should step 3 be rewritten to the trial-and-purchase release, and who owns that doc now?

**Why.** Someone following the doc would release against the record.

**What it touches.** docs/implement_mealplanning/07-verification-release.md.

> 2026-09-15 opened in wave 3 ticket 21

## mp-357 · Something other than the webhook wrote an entitlement row on DEV
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-296
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 3 ticket 21

**Context.** DEV user_entitlements has a row with period_type 'eval' (user 37129f7e…, written 2026-09-15 19:05Z). The RevenueCat webhook never writes that value, and the table is meant to have the webhook as its only writer.

**Question.** What wrote it (an eval script, a test fixture, a hand edit), and should the table refuse writers other than the webhook?

**Why.** The server gates on this cache; a stray writer can grant or deny access.

**What it touches.** user_entitlements on DEV, whatever wrote the row.

> 2026-09-15 opened in wave 3 ticket 21

## mp-358 · Every plan read goes through the athlete's own period
- category: Data, sync and backend
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-358.svg
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 16
- detail: yes

**Context.** mp-269 made the week's start day and the period's length settings. Tickets 16 and 29 were built in parallel from the same base, so the Plan tab's in-view section still resolved the week with the Sunday default and derived cook days from seven-day offsets. Both review axes found it; the wave fixed it before closing.

**Question.** Which reads have to go through the athlete's period, not the defaults.

**Decision.** 
1. Every read that resolves a week or a cook day takes the athlete's period: the in-view section on the Plan tab as well as the context block, the opener and coverage.
2. Stepping back to the period before this one steps back by the period's length, not by seven days. The debrief opener and the debrief tool both do.
3. A seam test covers a Monday, ten-day athlete at the place the two tickets meet.

**Why.** A Monday athlete was shown "no plan this week" over a real plan, and a ten-day athlete's debrief never found the plan it was asking about.

**What else was considered.** Threading the period from the chat call instead of reading it where it is used; that call has no period in scope and would have fetched one anyway.

**What it touches.** situation.ts, chat.ts, tools.ts, the Plan tab's section, the debrief.

> 2026-09-15 proposed in wave 4 ticket 16

## mp-359 · How a screen declares the one section it adds
- category: Situation awareness
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-359.svg
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 16
- detail: yes

**Context.** mp-273 says the Doll is constant and the Situation is the only variable: one capped section for the entity in view. Ticket 16 had to choose where that section rides and how a route earns one.

**Question.** Where the in-view section lives and how a new entry point gets one.

**Decision.** 
1. The section rides on the user message, under the Situation note, never in the context block, so the cached prefix stays byte-identical across turns (mp-276).
2. A route declares its section with one column on the server's existing screen table, so a new entry point adds a row and nothing else (mp-273 clause 4).
3. Each list is capped at six with "and more"; a day note is clipped at 240 characters.
4. A plan id that does not resolve falls back to the athlete's own plan for that week rather than erroring.

**Why.** The block is what the cache holds, so anything that changes per message belongs on the message.

**What else was considered.** Putting the section in the block (breaks the cache every turn); a separate table or a branch in the chat path.

**What it touches.** situation.ts, chat.ts, the events screens, the Plan tab.

> 2026-09-15 proposed in wave 4 ticket 16

## mp-360 · One place decides which conversation the day's is
- category: The sheet and launcher
- status: proposed
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 16

**Context.** mp-275 says the launcher, its full-screen button, the Plan tab's note card and a moment tap all open the day's ambient conversation, and that New meal plan and the plus button start a new one without moving the launcher's pointer. The note card used to start its own conversation.

**Question.** Who owns the day's pointer, and how a new conversation is kept off it.

**Decision.** 
1. The ambient conversation controller owns opening the day's conversation. The note card and the launcher both go through it, so the rule lives in one place.
2. A conversation started new gets its own controller key, so only the day's unnamed general conversation can adopt the server's id. The pointer never moves for a new one.

**Why.** The note card needed the same behaviour as the launcher, and a listener could not otherwise tell the two apart.

**What else was considered.** Repeating the host's naming watch in the Plan tab; a flag on the chat controller.

**What it touches.** Vana sheet, the Plan tab's note card, the ambient conversation controller.

> 2026-09-15 proposed in wave 4 ticket 16
> 2026-09-16 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png

## mp-361 · What one sheet height means in practice
- category: The sheet and launcher
- status: proposed
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 27

**Context.** mp-265 asks for one standard height, no auto height, no growth on send, no resize while Vana streams and no custom thresholds. The sheet had three heights, a grabber that toggled them and its own dismissal thresholds.

**Question.** What the one height is, and what dismisses the sheet now.

**Decision.** 
1. The height is three quarters of the screen, the rest height the sheet already used, and its contents scroll.
2. Dismissal is the platform's own rule: past half the sheet, or a flick. The custom pixel thresholds are gone.
3. The grabber stays as the drag handle and no longer toggles anything.
4. The height enum, the size reporter and the one-message exchange helper are removed; the tree keeps one shape so a height change never remounts it (mp-265 clause 5).

**Why.** "No custom thresholds" means the standard rule, and the goldens did not move, so this is the height Lee already saw.

**What else was considered.** A full-screen sheet; an absolute pixel height; dropping the grabber for a close button alone.

**What it touches.** The Kyle sheet widget and its spec (v2, app-authored, awaiting Xuan), the Vana sheet, the goldens.

> 2026-09-15 proposed in wave 4 ticket 27
> 2026-09-16 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png

## mp-362 · What the hand-off button is made of
- category: The sheet and launcher
- status: proposed
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 27

**Context.** mp-265 clause 4 says every deterministic action is a hand-off: Vana offers a button to the screen that owns the flow instead of doing it in the sheet.

**Question.** What the hand-off is on the wire and where each target lands.

**Decision.** 
1. A new part in the contract carrying the target screen, a label and an optional entity id, rendered as the existing primary button, not a new design widget.
2. The model writes the label per call in the athlete's own words, capped at sixty characters.
3. The tool is offered in general conversations only; the planning conversation is the meal-planning flow already.
4. Meal plan lands on the meal-planning page, fuelling on the new-activity screen, an event on the event screen, which becomes routable for the first time; carb loading also lands on the event screen, where its action lives.
5. The full-screen chat renders hand-offs too, since the parts persist in the transcript.

**Why.** A fixed label cannot read as the athlete's own ask, and the four destinations are screens the app already owns.

**What else was considered.** Content-managed labels; a new Kyle component; a sheet-only button.

**What it touches.** The wire contract and its fixtures, the part renderer, the router, the Vana sheet and the full-screen chat.

> 2026-09-15 proposed in wave 4 ticket 27
> 2026-09-16 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png

## mp-363 · A plan request with a constraint is still a plan request
- category: Vana's voice and openers
- status: proposed
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 27

**Context.** The eval asks for a plan twice. The plain ask was answered with the hand-off button; "Plan my dinners for the week, I want quick ones" was answered in the sheet with a list of meals, because the rule named the plain phrasings only.

**Question.** Whether a plan request carrying a constraint hands off or is answered in the sheet.

**Decision.** A plan request is still a plan request when it names a meal type, a stretch of days or a constraint ("quick ones", "cheap lunches", "vegetarian dinners"). Vana hands off and the constraint is said on that screen, rather than searching meals or listing them in the sheet.

**Why.** mp-265 clause 4 is about what the athlete is trying to do, not how they phrase it; the screen is where a constraint can be seen and changed.

**What else was considered.** Accepting the list for constrained asks; teaching the meal-planning screen to take the constraint from the conversation.

**What it touches.** The persona's hand-off rule, the Vana sheet, the eval.

**Details.** Deployed to dev; the sheet-plan-handoff eval is 3 turns, 0 failures, both phrasings answered with the button.

> 2026-09-15 proposed in wave 4 ticket 27
> 2026-09-16 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png

## mp-364 · What the general opener reads, and in what order
- category: Vana's voice and openers
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-364.svg
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 28
- detail: yes

**Context.** mp-268 says the general conversation opens on the screen underneath, and falls back to the personal opener when the screen says nothing useful. The opener already had a moment path.

**Question.** How the opener decides the screen says something useful, and what wins when several do.

**Decision.** 
1. The order is a moment that resolves, then the screen underneath, then the personal opener.
2. "Says something useful" is decided by resolving the Situation twice, once with the entity id and once without: a different sentence means the athlete's own row was read. No sentence is parsed and no query is copied.
3. Event, meal and session screens count; a bare route, an id that belongs to someone else, and an id that is gone all fall back.
4. The opener's own variant is logged, so the logs say which of the three fired.

**Why.** A moment is a contract the device raised with fixed times; the screen is the next best thing, and neither should be guessed at from the sentence's words.

**What else was considered.** Reading the screen before a moment; copying the row reads into the opener; matching on the sentence text.

**What it touches.** moment.ts, the chat path's logging, the Vana sheet's first line.

> 2026-09-15 proposed in wave 4 ticket 28

## mp-365 · How a period of other than seven days behaves
- category: Plan tab
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-365.svg
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 29

**Context.** mp-269 makes the start day and the period length settings, with cook days derived from them. Seven days and Sunday were the only shape the code knew.

**Question.** What a ten-day period means for when periods start and when the cooking happens.

**Decision.** 
1. Period starts keep a weekly cadence on the athlete's start weekday; the length drives the span, the cook offsets, the coverage denominator and when the debrief is due.
2. The three cooking sessions scale with the length rather than sitting at fixed offsets, and stay inside the period.
3. The period length travels on the coverage wire and on the week part, so a card built by the server says how long the period is.
4. The length is limited to between three and fourteen days: below three the three sessions collapse onto one day, and a fortnight is as long as a batch plausibly holds.

**Why.** The weekly cadence keeps the stored week start meaning what it always meant, needs no anchor row, and is exact at the default.

**What else was considered.** Chaining periods from an epoch anchor, which drifts off the start weekday; deriving the anchor from the last plan, which belongs to a later ticket.

**What it touches.** The plan maths on both sides, coverage, the review sheet, the week card, the Plan tab.

> 2026-09-15 proposed in wave 4 ticket 29

## mp-366 · Where the athlete changes the two settings
- category: Plan tab
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/settings.png
- caption:
- screen: Vana settings
- source: wave mealplanning 4 ticket 29

**Context.** mp-269 says the two settings are the athlete's to change. Vana settings already holds keyed settings like batch cooking, each on a standard row.

**Question.** What the two settings look like, and how the days they name are written.

**Decision.** 
1. The start day is a popup of the seven days and the length is the existing stepper, both on the rows the screen already uses, with no new design component.
2. The session labels become content-managed with the weekday filled in ("Cook Monday"), so no day name is hardcoded and the old fixed-day keys keep working.
3. The settings are written to the device first with upload tracking, like every other setting.

**Why.** Both fit the existing row, and a localized weekday cannot come from a fixed string.

**What else was considered.** A new Kyle picker component; rewriting the existing day-named content values.

**What it touches.** Vana settings, the review sheet, the week card, the session chips.

> 2026-09-15 proposed in wave 4 ticket 29
> 2026-09-16 picture captured at 1.26.0+1, c4f78733

## mp-367 · Should the Plan tab open on the plan rather than the personal opener?
- category: Vana's voice and openers
- kind: question
- status: open
- linked: mp-268
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 28

**Context.** The screens that open on what is in view are event, meal and session screens. The Plan tab with a plan in view ("the week of the 7th is draft") falls back to the personal opener.

**Question.** Should the Plan tab with a plan in view open on that plan?

**Why.** It is the screen an athlete is most often on when they open the sheet.

**What it touches.** The general opener, the Plan tab.

> 2026-09-15 opened in wave 4 ticket 28

## mp-368 · Should a live moment outrank the screen underneath?
- category: Moments: Vana speaks first
- kind: question
- status: open
- linked: mp-268
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 28

**Context.** The opener takes a moment that resolves before the screen underneath. mp-268 says the general conversation "opens with a line that reads the screen underneath".

**Question.** When an athlete opens the sheet on an event screen while a moment is live, which should Vana speak to?

**Why.** They are two different readings of what "reads the screen" means, and only one can be first.

**What it touches.** The general opener, moments.

> 2026-09-15 opened in wave 4 ticket 28

## mp-369 · Should the full-screen general chat open on the screen underneath too?
- category: Vana's voice and openers
- kind: question
- status: open
- linked: mp-268
- image: none
- caption:
- screen: Vana chat
- source: wave mealplanning 4 ticket 28

**Context.** The example chips were removed from the full-screen general chat's empty state, but that screen never asks for an opener; only the sheet does. It now opens on an empty state with no line at all.

**Question.** Should the full-screen general chat ask for an opener the way the sheet does?

**Why.** An empty screen with no chips and no line says nothing.

**What it touches.** The full-screen Vana chat.

> 2026-09-15 opened in wave 4 ticket 28

## mp-370 · Should the persona name the in-view section?
- category: Situation awareness
- kind: question
- status: open
- linked: mp-273
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 16

**Context.** The persona tells Vana what the Situation note is, but nothing tells her what an EVENTS AHEAD or DAY PLAN line under it is. She reads it as context either way.

**Question.** Should the persona name the section the way it names the Situation?

**Why.** What the prompt does not name, the model interprets.

**What it touches.** The persona, the in-view section.

> 2026-09-15 opened in wave 4 ticket 16

## mp-371 · Should the Plan tab's section speak for the day or the week?
- category: Situation awareness
- kind: question
- status: open
- linked: mp-273
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 16

**Context.** The Plan tab's section carries the day's note and slots and also the week's meals with servings left, because the tab itself shows the week. mp-273 says a section is a few lines, never a dump of the record.

**Question.** Should the section be narrowed to the day on screen, or does the week belong there?

**Why.** It is the longest section, and the cap is the only thing holding it down.

**What it touches.** The in-view section, the Plan tab.

> 2026-09-15 opened in wave 4 ticket 16

## mp-372 · Two new conversations in a row share one screen
- category: The sheet and launcher
- kind: question
- status: open
- linked: mp-275
- image: none
- caption:
- screen: Vana chat
- source: wave mealplanning 4 ticket 16

**Context.** Every conversation started new shares one controller key, which is what keeps the launcher's pointer still. Pressing the plus button from inside a new conversation therefore pushes a second screen showing the first one's transcript. It was true before this ticket as well.

**Question.** Should a second new conversation get its own key, and is that reachable in practice?

**Why.** mp-275 clause 2 says the plus button starts a new conversation, and here the second press does not.

**What it touches.** The full-screen chat's key, the ambient conversation controller.

> 2026-09-15 opened in wave 4 ticket 16

## mp-373 · Carb loading lands on the event screen, not on the picks
- category: The sheet and launcher
- kind: question
- status: open
- linked: mp-265
- image: none
- caption:
- screen: Vana chat
- source: wave mealplanning 4 ticket 27

**Context.** mp-265 clause 4 sends carb loading to the carb-loading picks. The picks screen takes a loaded event, has no route of its own, and hands a protocol back to whoever opened it, so the hand-off lands on the event screen where the carb-loading action lives.

**Question.** Should the picks become a route that takes an event id, so the hand-off can open them directly?

**Why.** As built, the carb-loading hand-off and the event hand-off do the same thing.

**What it touches.** The carb-loading picks, the router, the hand-off targets.

> 2026-09-15 opened in wave 4 ticket 27

## mp-374 · What a hand-off with no entity should do
- category: The sheet and launcher
- kind: question
- status: open
- linked: mp-265
- image: none
- caption:
- screen: Vana chat
- source: wave mealplanning 4 ticket 27

**Context.** When Vana cannot name the event, "plan an event" lands on the blank new-event form and carb loading lands on the events list.

**Question.** Is a blank form or a bare list the right landing, or should Vana be required to name the entity before she offers the button?

**Why.** A button that lands nowhere in particular is worse than a sentence.

**What it touches.** The hand-off tool, the events screens.

> 2026-09-15 opened in wave 4 ticket 27

## mp-375 · Does the fuelling hand-off edit the workout or add one?
- category: The sheet and launcher
- kind: question
- status: open
- linked: mp-265
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 27

**Context.** The fuelling hand-off passes the workout's id to the new-activity screen, which prefills from an existing activity. Nobody has watched what saving there does.

**Question.** Does that screen edit the workout Vana named, or create a second one beside it?

**Why.** A duplicated workout would quietly double an athlete's week.

**What it touches.** The new-activity screen, the fuelling hand-off.

> 2026-09-15 opened in wave 4 ticket 27

## mp-376 · Which status chip a hand-off turn shows
- category: The sheet and launcher
- kind: question
- status: open
- linked: mp-265
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 27

**Context.** A turn answered with a hand-off button is treated as an update, so it shows the ordinary chip rather than the one that marks something to do.

**Question.** Is a hand-off an update, or a to-do until they tap it?

**Why.** The chip is how the sheet says whether anything is waiting on the athlete.

**What it touches.** The Vana sheet's status chip.

> 2026-09-15 opened in wave 4 ticket 27

## mp-377 · The opener still offers a chip the hand-off now answers
- category: Vana's voice and openers
- kind: question
- status: open
- linked: mp-268
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 27

**Context.** The general opener still offers "Start a meal plan" as a quick reply. Tapping it now produces a hand-off button, so the athlete taps twice to get to the same screen.

**Question.** Should the opener offer that reply at all, or should it be the hand-off itself?

**Why.** Two taps for one intent.

**What it touches.** The general opener, the Vana sheet's quick replies.

> 2026-09-15 opened in wave 4 ticket 27

## mp-378 · What happens to the plan when the start day changes mid-period
- category: Plan tab
- kind: question
- status: open
- linked: mp-269
- image: none
- caption:
- screen: Plan tab
- source: wave mealplanning 4 ticket 29

**Context.** Changing the start day moves which week the Plan tab binds to. A draft built on the old week stops being this week's plan and the tab shows an empty week.

**Question.** Should the active plan's week move with the setting, should the old plan stay visible until it ends, or is an empty new week right?

**Why.** An athlete who changes a setting should not appear to lose a plan.

**What it touches.** The Plan tab, the plan's stored week start.

> 2026-09-15 opened in wave 4 ticket 29

## mp-379 · Periods longer than a week overlap
- category: Plan tab
- kind: question
- status: open
- linked: mp-269
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 29

**Context.** Period starts keep a weekly cadence, so a ten-day period beginning Monday is followed by another start the next Monday: the periods overlap by three days. The ticket that fills a cooking period rather than fourteen slots is still ahead.

**Question.** Does the next ticket need chained, non-overlapping periods, and if so what anchors the chain?

**Why.** Counting meals against a period that overlaps the next one double-counts the shared days.

**What it touches.** The plan maths, the next meal-planning ticket.

> 2026-09-15 opened in wave 4 ticket 29

## mp-380 · Should a plan carry the period it was built for?
- category: Plan tab
- kind: question
- status: open
- linked: mp-269
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 29

**Context.** A plan stores no period of its own; every screen reads the athlete's current setting. Changing the setting therefore re-reads old plans under the new period. Storing it is a schema change, and none was written or applied.

**Question.** Should a plan record the period it was built for?

**Why.** Otherwise last month's plan is described by this month's setting.

**What it touches.** The meal plans table, coverage, the review sheet.

> 2026-09-15 opened in wave 4 ticket 29

## mp-381 · The reminder text still names fixed days
- category: Plan tab
- kind: question
- status: open
- linked: mp-269
- image: none
- caption:
- screen: Vana settings
- source: wave mealplanning 4 ticket 29

**Context.** The reminders row still reads "The night before cook day and Sunday evening", whatever the athlete's start day is.

**Question.** Should it name the athlete's own days?

**Why.** mp-269 clause 3 has every surface read the settings, and this one still speaks for Sunday.

**What it touches.** Vana settings, the reminder copy.

> 2026-09-15 opened in wave 4 ticket 29

## mp-382 · Can Vana change the two new settings in conversation?
- category: Plan tab
- kind: question
- status: open
- linked: mp-269
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 29

**Context.** Vana's setting tool still accepts the four older keys only. The start day and the period length can be changed on the settings screen alone.

**Question.** Should Vana be able to set them mid-conversation when an athlete says "my week starts Monday"?

**Why.** Every other setting she can hear, she can save.

**What it touches.** The setting tool, Vana settings.

> 2026-09-15 opened in wave 4 ticket 29

## mp-383 · A design spec was edited in the app repo
- category: Design system
- kind: question
- status: open
- linked: mp-265
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 4 ticket 27

**Context.** The sheet's component spec was raised to v2 in this repo, marked app-authored and awaiting Xuan, because the sheet changed. The rule here says the design specs are a verbatim mirror of the QA repo and are never edited in this repo, with only the decision records carved out. The design sync that the rule asks for after such a change has not been run.

**Question.** Is an app-authored spec revision awaiting ratification the accepted practice, and who runs the design sync?

**Why.** The spec and the widget now disagree with the QA repo, and a blind mirror sync would delete the revision.

**What it touches.** The sheet's component spec, the QA mirror, the design sync.

> 2026-09-15 opened in wave 4 ticket 27

## mp-384 · The opener's own example sits on a screen the launcher never reaches
- category: The sheet and launcher
- kind: question
- status: open
- linked: mp-268
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 28

**Context.** mp-268 illustrates the general opener with "I see you are planning an event", and ticket 28's own check was to open the sheet on an event and hear about that event. mp-264 puts the launcher on exactly three routes — the main tabs screen, the meal-planning screen and the formula library — and anything pushed over them hides it. The event screen is none of those, so on a device there is no way to open the sheet there: the check could not be run. The server side is built and tested; an event, meal or session screen does produce an opener about the thing in view when a Situation naming it arrives.

**Question.** Should the launcher widen to the screens whose Situation the opener can already speak for (the event, meal and session screens), or should mp-268's example be rewritten to the screens the launcher actually reaches?

**Why.** As it stands the opener's best behaviour is unreachable by hand, and the ticket carries a check nobody can perform.

**What it touches.** The launcher's allow-list, the general opener, the event, meal and session screens.

> 2026-09-15 opened in wave 4 ticket 28

## mp-385 · What the formula editor puts on the wire, and how it is refused
- category: Situation awareness
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-385.svg
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 17

**Context.** mp-274 makes the formula editor the one named exception to mp-043: its draft travels as structured fields. Ticket 17 had to decide what "validates the shape as it validates routes" means in practice.

**Question.** What the editor sends, and what happens to a draft that does not belong.

**Decision.** 
1. The draft carries phase, sub-phase, durations, activities, component ids with quantities, and a name capped at forty characters. Nothing else free-form travels.
2. Only a route whose screen-table row declares the formula section may carry a draft. Any other route's draft is dropped whole: no section, no text in the prompt, and the rest of the Situation still resolves. It is not an error.
3. Phases and sub-phases are closed sets, ids and tags are shape-checked, and the component list is capped like every other section.
4. Component names are resolved server-side from the athlete's own foods under their own access, so the client sends ids rather than names.

**Why.** A dropped draft cannot break a legitimate screen report, and resolving names server-side keeps free text off the wire while still letting Vana name the food.

**What else was considered.** Refusing the whole request; sending the snapshot names the components already carry.

**What it touches.** situation.ts, schemas.ts, the formula editor.

> 2026-09-16 proposed in wave 5 ticket 17

## mp-386 · What the FORMULA section tells Vana
- category: Situation awareness
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-386.svg
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 17
- detail: yes

**Context.** mp-273 says a section is a few lines, never a dump of the record. The formula editor's section had to choose what counts as the draft's "targets".

**Question.** What the section says about a draft.

**Decision.** The section carries the draft's scope — phase, sub-phase, activities and durations — with its components and their quantities, and a one-line form when the draft is empty. It does not compute fuelling targets or macro totals.

**Why.** mp-274 names those fields; a computed target would be a second engine nobody asked for.

**What else was considered.** Sending macro totals, which would put numbers on the wire that mp-274 does not list.

**What it touches.** situation.ts, the formula editor's conversation.

> 2026-09-16 proposed in wave 5 ticket 17

## mp-387 · Ask Vana sits in the editor and starts a new conversation
- category: The sheet and launcher
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/formula-editor.png
- caption:
- screen: Formula editor
- source: wave mealplanning 5 ticket 17

**Context.** mp-275 clause 2 says a future entry from the formula editor starts a new conversation and never moves the launcher's pointer. The one-shot insight panel used to sit in that spot.

**Question.** Where the entry lives and what it opens.

**Decision.** 
1. The button stands where the insight panel was, always visible, and opens a new general conversation through the key ticket 16 built, so the day's ambient conversation keeps the pointer.
2. It is offered even when the draft is empty, because an empty draft has its own one-line section.

**Why.** An athlete building their first formula is exactly who wants to ask about it.

**What else was considered.** Gating the button until the draft has a component, as the old panel did; opening a planning-kind conversation.

**What it touches.** The formula editor, the ambient conversation controller.

> 2026-09-16 proposed in wave 5 ticket 17
> 2026-09-16 picture captured at 1.26.0+1, 308d2c0f

## mp-388 · How far the coach-feedback retirement goes
- category: Process and scope
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-388.svg
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 17

**Context.** mp-209 retires Jade everywhere, including coach formula feedback. Ticket 17 replaced the one-shot insight with a conversation.

**Question.** What is deleted now and what is left standing.

**Decision.** 
1. The insight panel and its controller are deleted, and saving a formula no longer writes an insight.
2. The ai-coach function and its client stay for their other callers, and an insight already stored on a formula is left as it is.

**Why.** The ticket retires the coach-facing surface, not the function other callers still use.

**What else was considered.** Deleting the client too, which cascades into its tests and other callers.

**What it touches.** The formula editor, the formulas repository, ai-coach.

> 2026-09-16 proposed in wave 5 ticket 17

## mp-389 · How big a batch is, and where a pick's servings come from
- category: Plan tab
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-389.svg
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** mp-231 clause 3 says the athlete cooks a few meals at one sitting and the servings scale so the batch covers the period. "A few" needed a number, and every pick that named no servings used to default to four — the fourteen-slot assumption in disguise.

**Question.** How many meals a batch holds, and what servings a pick gets when nobody says.

**Decision.** 
1. A batch is three meals per meal type, so servings are the period divided by three, rounded up: seven days gives three, ten gives four, fourteen gives five.
2. A pick's servings are computed from the period and the mode rather than defaulting to a fixed number. In per-day mode a pick is one serving.

**Why.** A period carries three cooking sessions, so three meals per type is the batch that matches it.

**What else was considered.** Asking the athlete each time; keeping a fixed four; leaving the model to pass servings.

**What it touches.** plan-math.ts, plan.ts, the planning tools.

> 2026-09-16 proposed in wave 5 ticket 30

## mp-390 · Coverage counts the walk, not a fixed fourteen
- category: Plan tab
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-390.svg
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** mp-231 clauses 1, 3 and 4 make the walk the athlete's own and the period the span. Coverage counted against a fixed fourteen slots.

**Question.** What coverage counts against, and what changes it.

**Decision.** 
1. The denominator is the period's days times the meal types the athlete plans. In batch mode the numerator counts servings; in per-day mode it counts the nights a meal covers.
2. Only an explicit walk setting changes which types are counted. An athlete who has never set one keeps today's dinner-and-lunch reading, so existing plans' numbers do not move under them.
3. The walk travels on the coverage wire, because slots divided by days cannot say which types they were.

**Why.** Silently widening "every meal" to four slots a day would rewrite the numbers on plans nobody re-planned.

**What else was considered.** Making "every meal" mean four slots a day; leaving coverage scope-only; inferring the types from the denominator.

**What it touches.** plan-math.ts, the coverage wire, plan_coverage.dart, the review sheet.

> 2026-09-16 proposed in wave 5 ticket 30

## mp-391 · "Same as last time" copies at the servings they were cooked at
- category: The planning conversation
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-391.svg
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** mp-231 clause 5 gives one tap that drafts the period from what they ate last time, and clause 6 says it runs deterministically with the model only presenting it.

**Question.** What the copy does with servings and with a draft already in progress.

**Decision.** 
1. Meals come across at the servings they were cooked at. They are not rescaled to the current period, because a plan records no period of its own and any rescale would be invented. In per-day mode each meal comes across as one night.
2. It skips meals already in the draft and never doubles them; a second tap changes nothing.
3. Vana's description of the tool says exactly this, so she never claims a rescale that did not happen.

**Why.** Rescaling on a guess produces numbers no one can explain; the honest copy is the old servings.

**What else was considered.** Scaling by the ratio of the periods, written and then removed; replacing the draft outright.

**What it touches.** plan.ts, the planning tools, the one-tap draft.

**Details.** The tool's description promised a rescale in the merged code and was corrected during the wave's review; mp-380 asks whether a plan should record its own period, which would make an honest rescale possible.

> 2026-09-16 proposed in wave 5 ticket 30

## mp-392 · A plan payload without a mode means batch
- category: Data, sync and backend
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-392.svg
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30
- detail: yes

**Context.** The server reads a missing batch-cooking flag as batch; the app read it as per-day. The same payload therefore counted servings on one side and nights on the other, which turned a seam test red during the wave.

**Question.** What an absent mode means.

**Decision.** An absent mode means batch, on both sides. The app reads the wire the way the server writes it.

**Why.** Two readings of one payload is a bug generator; the server's reading is the one the stored column already defaults to.

**What else was considered.** Making the server default to per-day; requiring the flag on every payload.

**What it touches.** meal_plan.dart, plan-math.ts, coverage on both sides.

> 2026-09-16 proposed in wave 5 ticket 30

## mp-393 · Vana's carb total disagreed with the editor's
- category: Situation awareness
- kind: question
- status: open
- linked: mp-274
- image: none
- caption:
- screen: Formula editor
- source: wave mealplanning 5 ticket 17

**Context.** On the simulator, a saved formula was edited from two bagels to two and a half without saving. The editor's strip read 133g carbs. Ask Vana opened a new conversation whose opener offered "Adjust this bagel formula", so the draft reached her, but asked for the total she answered "Does 142g carbs work for you, or adjust it?".

**Question.** Why the two totals differ, and which one an athlete should be shown — is the section built from different quantities, or is the editor's strip rounding differently?

**Why.** The point of the draft on the wire is that Vana sees what is on screen; two totals for one screen undoes that.

**What it touches.** situation.ts, the formula editor's macro strip.

> 2026-09-16 opened in wave 5 ticket 17

## mp-394 · Should the editor's conversation open on the formula?
- category: Vana's voice and openers
- kind: question
- status: open
- linked: mp-268
- image: none
- caption:
- screen: Formula editor
- source: wave mealplanning 5 ticket 17

**Context.** Ask Vana from the editor opens a new general conversation, so she greets with the general opener and offers chips, one of which names the formula.

**Question.** Should the editor's entry open on the formula itself, the way the sheet opens on the screen underneath?

**Why.** The athlete pressed a button on a formula; the first line could say so.

**What it touches.** The general opener, the formula editor's entry.

> 2026-09-16 opened in wave 5 ticket 17

## mp-395 · The stored coach insight is never refreshed again
- category: Process and scope
- kind: question
- status: open
- linked: mp-209
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 17

**Context.** The insight panel is gone and nothing writes a new insight, but the columns, their readers and the flag that used to gate the feature are still in the code and on the rows.

**Question.** Should the columns and their readers be retired, or do they stay as a fading record?

**Why.** A column nothing writes still shows old text to whoever reads it.

**What it touches.** The formulas repository, the insight columns, the old feature flag.

> 2026-09-16 opened in wave 5 ticket 17

## mp-396 · Is a forty-character name cap the right shape?
- category: Situation awareness
- kind: question
- status: open
- linked: mp-274
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 17

**Context.** The draft's name is the only free text that travels with a message, capped at forty characters and otherwise unshaped, because it is whatever the athlete typed.

**Question.** Is the cap enough, or should the name be shaped further before it reaches the prompt?

**Why.** mp-043 keeps free text off the wire; this is its one exception.

**What it touches.** situation.ts, the draft on the wire.

> 2026-09-16 opened in wave 5 ticket 17

## mp-397 · Nothing in the app lets an athlete choose their walk
- category: Plan tab
- kind: question
- status: open
- linked: mp-231
- image: none
- caption:
- screen: Vana settings
- source: wave mealplanning 5 ticket 30

**Context.** mp-231 clause 1 says the walk covers only the types the athlete plans, in their order. The walk is a keyed setting Vana can write, but the settings screen has no control for it, so it is reachable only through conversation.

**Question.** Does the settings screen get a meal-type picker, and is that its own ticket?

**Why.** A setting only a conversation can change is invisible to most people.

**What it touches.** Vana settings, the walk setting.

> 2026-09-16 opened in wave 5 ticket 30

## mp-398 · Should "every meal" count four slots a day?
- category: Plan tab
- kind: question
- status: open
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** Coverage widens only when the athlete sets an explicit walk. An athlete whose scope is "every meal" still has lunch and dinner counted, with breakfast and snacks left as macros.

**Question.** Should choosing "every meal" widen the denominator to four slots a day?

**Why.** It is the one place the old scope and the new walk disagree.

**What it touches.** Coverage on both sides, the review sheet.

> 2026-09-16 opened in wave 5 ticket 30

## mp-399 · Per-day coverage counts a night, whatever the servings
- category: Plan tab
- kind: question
- status: open
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** In per-day mode a meal covers one night however many servings it makes, so an athlete cooking two servings for a partner reads as one night covered.

**Question.** Is that the right reading of "people who do not batch plan per day"?

**Why.** It decides what the review sheet tells a couple who cook together.

**What it touches.** Coverage on both sides, the review sheet.

> 2026-09-16 opened in wave 5 ticket 30

## mp-400 · The one-tap draft has no tap yet
- category: The planning conversation
- kind: question
- status: open
- linked: mp-231
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 5 ticket 30

**Context.** mp-231 clause 5 says one tap drafts the period from what they ate last time. The server has the tool and the action, but no screen sends it: today it is a sentence to Vana.

**Question.** Where does the tap live — a quick reply, a button on the Plan tab, or the plan bar?

**Why.** The decision says one tap, and there is not one.

**What it touches.** The Plan tab, the Vana sheet, the one-tap draft.

> 2026-09-16 opened in wave 5 ticket 30

## mp-401 · Suggestions do not yet favour what they have cooked
- category: Meals tab and library
- kind: question
- status: open
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** mp-231 clause 5 opens with "suggestions give the highest weight to meals the athlete has liked or already cooked". The ticket built the one-tap draft but left the suggestion ranking untouched, and its acceptance criteria never named it.

**Question.** Does the ranking change now, and under which ticket?

**Why.** Half a clause of an approved decision is unbuilt and nothing tracks it.

**What it touches.** The meal search ranking.

> 2026-09-16 opened in wave 5 ticket 30

## mp-402 · A staples fallback still assumes fourteen slots
- category: Plan tab
- kind: question
- status: open
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** The staples diagnosis still falls back to fourteen slots when it has no coverage to read — the fixed number this ticket exists to remove.

**Question.** Should it fall back to the athlete's period, or say nothing when it has no coverage?

**Why.** It is the last fourteen left in the planning path.

**What it touches.** The planning tools, the staples diagnosis.

> 2026-09-16 opened in wave 5 ticket 30

## mp-403 · A scope-only draft reads as empty
- category: Situation awareness
- kind: question
- status: open
- linked: mp-274
- image: none
- caption:
- screen: Formula editor
- source: wave mealplanning 5 ticket 17

**Context.** The section calls a draft empty when it has no name, no phase and no components, even when the athlete has already chosen a sub-phase, a duration or an activity. Vana is then told there is nothing in it yet, while the screen shows the scope.

**Question.** Should a draft carrying only its scope be described by that scope rather than called empty?

**Why.** It is the first thing an athlete sets, and Vana is told it is not there.

**What it touches.** situation.ts, the formula editor's conversation.

> 2026-09-16 opened in wave 5 ticket 17

## mp-404 · The shared coverage fixture does not test the part that must agree
- category: Plan tab
- kind: question
- status: open
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** The server and the app now read one fixture so their coverage agrees. For the cases with no explicit walk, the fixture hands the app the list of types the server derives, so the derivation itself — the thing most likely to drift — is compared only in hand-written cases on one side.

**Question.** Should the fixture carry the inputs and let each side derive the walk, so the seam tests the derivation and not the answer?

**Why.** A shared fixture that hands over the answer proves less than it looks.

**What it touches.** The coverage fixture, both coverage seams.

> 2026-09-16 opened in wave 5 ticket 30

## mp-405 · A fuelling conformance test is red before this wave
- category: Process and scope
- kind: question
- status: open
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 5 ticket 30

**Context.** The suite carries a failing case in the create-flow fuelling controls: the clamp-bound stepper is expected to carry a "Capped: session in …" caption and shows "1 h — early start" instead. It fails the same way at this wave's base commit, so it is not this wave's doing, and it sits beside the two failures already known to be environmental.

**Question.** Is the caption's precedence wrong, or is the test's expectation out of date — and who owns fixing it?

**Why.** A red test nobody owns trains everyone to read red as normal.

**What it touches.** The fuelling window authority, the create-flow conformance test.

> 2026-09-16 opened in wave 5 ticket 30

## mp-406 · Named chips replace the replies, nothing else
- category: The planning conversation
- status: proposed
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: vana-sheet
- source: wave mealplanning 6 ticket 31
- detail: yes
- linked: mp-272

**Context.** mp-272 lets a turn name the chips it expects next. The strip under a picker holds more than replies: two doors out ("Something else…", "Browse meals"), the propose-first door on the first picker ("Draft my whole week"), and the filters once the plan has a meal.

**Question.** Which chips a named list stands in for.

**Decision.** Only the two replies ("I like these" / "Next: …" and "Other options"). The doors and the filters stay whatever the turn named, and the persona is told not to re-say them.

**Why.** Removing the doors strands the athlete with no way to the composer or the catalog; mp-230 clause 4 shows the filters once the plan has a meal without condition.

**What else was considered.** Replacing the whole strip (the wave's first build did, and the review reversed it).

**What it touches.** picker_chips.dart, persona.ts.

> 2026-09-16 proposed in wave 6 ticket 31
> 2026-09-16 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png

## mp-407 · Show more is the tail of the same search, carried on the part
- category: The planning conversation
- status: proposed
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: vana-sheet
- source: wave mealplanning 6 ticket 31
- detail: yes
- linked: mp-230

**Context.** mp-230 clause 2 says Show more raises a sheet with many more options from the same search. The ticket named the catalog browser among its files, but the catalog runs its own query.

**Question.** Where the meals behind Show more come from.

**Decision.** The server sends the rest of the picker's own search as an optional list on the picker part, up to twenty-four past the tiles, and the sheet opens over it with no new query. The tiles and their ranking are unchanged. The catalog browser is untouched.

**Why.** Re-querying would not be "the same search"; carrying the tail keeps the sheet honest and instant.

**What else was considered.** Opening the catalog browser filtered by the picker's query.

**What it touches.** contracts.ts, schemas.ts, tools.ts, picker_more_sheet.dart.

> 2026-09-16 proposed in wave 6 ticket 31
> 2026-09-16 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png

## mp-408 · Both sides clamp the chip list, and a broken list means the app's set
- category: Data, sync and backend
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-408.svg
- screen: none (contract)
- source: wave mealplanning 6 ticket 31
- detail: yes
- linked: mp-272

**Context.** mp-272 clause 1 allows two to four plain strings. The model may name five, or one, or blanks.

**Question.** Where a list outside the rule is fixed, and what the app does with one that still arrives broken.

**Decision.** The producer trims, dedupes, caps at four and drops a list under two before it reaches the wire, and the wire schema refuses anything else. The app's parser applies the same rule again rather than trust the wire; a list that fails it is treated as absent, so the app's own set shows and the strip is never malformed.

**Why.** A chip strip is user-facing; a defensive parser costs nothing and a broken strip costs trust. The model's tool input accepts up to eight so a five-label call is clamped, not rejected.

**What else was considered.** Clamping on one side only.

**What it touches.** schemas.ts, tools.ts, vana_part.dart, the frozen meal_picker fixture's contract tests.

> 2026-09-16 proposed in wave 6 ticket 31

## mp-409 · The named chips ride on the picker part, not on every turn
- category: The planning conversation
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-409.svg
- screen: none (contract)
- source: wave mealplanning 6 ticket 31
- detail: yes
- linked: mp-272

**Context.** mp-272 clause 1 says "a Vana turn may carry" the list; clause 2 draws them "as the chips under the picker". A turn without a picker (a pantry question, a batch card, a rule) has no chip strip under it today.

**Question.** Whether the list belongs to the turn or to the picker part.

**Decision.** To the picker part. A turn without a picker cannot name chips in this build.

**Why.** The only strip the app draws is the picker's; a turn-level list would need a strip under every part kind, which no decision asks for.

**What else was considered.** A turn-level field the renderer attaches to whatever part is last.

**What it touches.** contracts.ts, vana_part.dart, vana_part_renderer.dart.

> 2026-09-16 proposed in wave 6 ticket 31

## mp-410 · Do the meals behind Show more count as shown?
- category: The planning conversation
- kind: question
- status: open
- image: none
- caption:
- screen: none (contract)
- source: wave mealplanning 6 ticket 31
- linked: mp-230

**Context.** mp-230 clause 5 says "Other options" never repeats a meal already shown in the conversation. The tail behind Show more is not marked shown, because the server cannot know whether the sheet was ever opened, and marking twenty-four meals per picker would starve later suggestions fast. An athlete who read the sheet may see one of its meals offered again.

**Question.** Should the tail count as shown, only when the sheet is opened, or not at all?

**Why.** It is a one-line change either way, and only a device pass will say which feels wrong.

**What it touches.** tools.ts.

> 2026-09-16 opened in wave 6 ticket 31

## mp-411 · A fixed tail of twenty-four, and no chip when the tail is empty
- category: The planning conversation
- kind: question
- status: open
- image: none
- caption:
- screen: vana-sheet
- source: wave mealplanning 6 ticket 31
- linked: mp-230

**Context.** mp-230 clause 2 reads Show more as always present and says the count is not fixed. The build carries at most twenty-four meals past the tiles, and when a filtered search leaves nothing past them the chip is not drawn at all.

**Question.** Is a fixed cap acceptable, and should Show more appear over an empty tail (as a door that says so) or vanish?

**Why.** The review read the clause as unconditional; the build read an empty sheet as not a door.

**What it touches.** tools.ts, picker_chips.dart, vana_part_renderer.dart.

> 2026-09-16 opened in wave 6 ticket 31

## mp-412 · A tick in the More sheet does not reach the picker's swap circles
- category: The planning conversation
- kind: question
- status: open
- image: none
- caption:
- screen: vana-sheet
- source: wave mealplanning 6 ticket 31
- linked: mp-230

**Context.** The sheet copies the set of picked ids when it opens. A meal ticked in the sheet is added to the draft, but the tiles behind it do not show the swap circle until the next part arrives, and a meal added on the tiles while the sheet is open shows unticked in the sheet.

**Question.** Should the two surfaces share one live picked set, or is a refresh on the next part enough?

**Why.** mp-230 clause 3 gives picked tiles a swap circle; across the two surfaces that is only half honoured.

**What it touches.** picker_more_sheet.dart, vana_part_renderer.dart.

> 2026-09-16 opened in wave 6 ticket 31

## mp-413 · The persona text is edited here and not in the prototype
- category: Process and scope
- kind: question
- status: open
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 6 ticket 31

**Context.** persona.ts carries a note that its text is verbatim from the prototype repo and must be edited in both places. Wave 6 edited it here only; the prototype is outside the worktree.

**Question.** Is the prototype's copy still a source of truth, or can the note go?

**Why.** A note that says "edit both" and is obeyed by nobody is a trap.

**What it touches.** persona.ts.

> 2026-09-16 opened in wave 6 ticket 31

## mp-414 · The More sheet is a plain modal, not a glass sheet
- category: Design system
- kind: question
- status: open
- image: none
- caption:
- screen: vana-sheet
- source: wave mealplanning 6 ticket 31

**Context.** The vana-sheet spec records that every future summoned glass surface inherits the glass-sheet material and its scrim. The More sheet composes MealCard and the browse Add button over the app's adaptive modal, with no material token cited.

**Question.** Does the More sheet inherit the glass-sheet material, or is a summoned list sheet exempt?

**Why.** The standards review flagged it as a check for design-sync, not a breach of the current text.

**What it touches.** picker_more_sheet.dart, the vana-sheet spec.

> 2026-09-16 opened in wave 6 ticket 31

## mp-415 · A cloned wave simulator lands on the paywall
- category: Process and scope
- kind: question
- status: open
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 6 ticket 31

**Context.** The ticket's device check claimed a pool simulator, built and launched the branch on it, and sat on the Pro paywall: a freshly cloned simulator has no StoreKit receipt, Restore purchases finds nothing, and the debug wrench does not get past it. Meal-planning surfaces were unreachable, so the check was not run. Both halves of the ticket also arrive on the wire from vana-chat, which no wave deploys.

**Question.** How a wave agent reaches a Pro surface on a pool device: copy the dev simulator's receipt state, a dev-only bypass, or accept that Pro surfaces are checked on the dev simulator after the wave.

**Why.** Every remaining meal-planning ticket sits behind the paywall.

**What it touches.** sync.mjs simulator claim, the dev paywall gate.

> 2026-09-16 opened in wave 6 ticket 31

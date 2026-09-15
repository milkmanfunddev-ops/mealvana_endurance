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

## mp-323 · The plain placeholder is a tinted rounded square
- category: Meals tab and library
- status: proposed
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

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

## mp-273 · Every entry point sends the same Doll, plus one section for what is in view
- category: Vana's voice and openers
- status: proposed
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

## mp-274 · The formula editor sends its draft as structured fields
- category: Vana's voice and openers
- status: proposed
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

## mp-275 · What continues the day's conversation and what starts a new one
- category: Vana's voice and openers
- status: proposed
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

## mp-276 · The repeated prefix is cached, and the context block does not churn
- category: Vana's voice and openers
- status: proposed
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

## mp-277 · How Vana remembers: chunked history, notes as they happen, an episode when the conversation goes idle
- category: Vana's memory
- status: proposed
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

## mp-278 · The opener never waits
- category: Vana's voice and openers
- status: proposed
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

## mp-279 · The store runs the seven-day trial, and RevenueCat is the only gate
- category: Pro and paywall
- status: proposed
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

## mp-280 · Everything is behind the one gate
- category: Pro and paywall
- status: proposed
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

## mp-281 · Credits stay as a top-up over a monthly allowance
- category: Pro and paywall
- status: proposed
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

## mp-282 · An empty wallet shows the top-up sheet, never the gate
- category: Pro and paywall
- status: proposed
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

## mp-283 · Existing accounts get no grace period
- category: Pro and paywall
- status: proposed
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

## mp-284 · An unknown entitlement is locked, and the cache wins when it exists
- category: Pro and paywall
- status: proposed
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

## mp-285 · The entitlements table stays as a two-field cache of RevenueCat
- category: Pro and paywall
- status: proposed
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

## mp-286 · Coaches get nothing special until Xuan's paywall document
- category: Pro and paywall
- status: proposed
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

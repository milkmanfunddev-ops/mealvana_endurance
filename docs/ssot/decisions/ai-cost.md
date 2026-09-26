# Decisions: Cost cutting

Feature: ai-cost
Feature name: Cost cutting

## mp-465 · Vana runs on Haiku, and meal logging runs on Sonnet
- category: Models
- status: approved
- folded: mp-018, mp-432, mp-517, mp-525
- image: none
- screen: none (algorithm/data)
- source: spec ai-cost 2026-09-21; Lee in the terminal 2026-09-21; wave ai-cost 2 ticket 14

**Context.** Every AI feature in the app is a call to a Claude model, and the model chosen sets most of the cost. A typical athlete cost about $2.86 a month in AI before the cost work.

**Question.** Which model does each AI job use?

**Decision.** Vana's chat and openers run on Claude Haiku 4.5, the smaller and cheaper model. Logging a meal from a description or a photo runs on Sonnet, the larger model, and photos are shrunk to 1,000 px before they are sent. The background jobs (writing Memories after a chat, summarising a long chat, listing a saved meal's ingredients) also stay on Haiku, because no cheaper model gave the same answers when tested on 20 real conversations.

**Why.** Haiku is good enough for chat at a fraction of Sonnet's price. The cheaper models tried for the background jobs invented Memories that Haiku correctly left out.

**What else was considered.** Moving meal logging to a cheaper model after a 50-meal test, Apple's on-device model, and the batch API. All three are put off for now.

> 2026-09-26 overhaul: rewritten from mp-465, mp-018, mp-432, mp-517, mp-525

## mp-464 · A tap with a fixed next step skips the model
- category: Models
- status: approved
- image: none
- screen: none (algorithm/data)
- source: spec ai-cost 2026-09-21; Lee in the terminal 2026-09-21

**Context.** Chips are the tappable answers under Vana's messages. Every tap used to go to Vana as a typed message, which costs a full planning turn of about 21,000 tokens even when the next step was already obvious.

**Question.** Does every chip tap need a Vana turn?

**Decision.** No. A chip whose next step is already fixed, such as "Other options", "Draft my whole week", "Same as last time" or "Open shopping list", does that step straight away without calling the model and without using the athlete's budget. Chips Vana wrote herself, and anything the athlete types, still go to Vana.

**Why.** "Other options" is the most tapped chip, and paying a full turn for it buys one sentence. The athlete also gets the result faster.

**What else was considered.** Logging taps for two weeks before deciding, which Lee turned down. A canned line in Vana's voice after each tap, which goes against Vana never speaking from a template.

> 2026-09-26 overhaul: rewritten from mp-464

## mp-276 · We use Claude's prompt cache to cut costs
- category: Caching
- status: approved
- folded: mp-420, mp-568, mp-570
- image: none
- screen: none (algorithm/data)
- source: grill 2026-09-15; wave ai-cost 5 ticket 07

**Context.** Every Vana turn resends the whole prompt, because the model remembers nothing between calls. Anthropic charges a tenth of the price for the part of a prompt it has already seen, but only when that part is exactly the same as last time.

**Question.** How do we stop paying full price for the same prompt every turn?

**Decision.** Every Vana call and every meal-logging call uses the prompt cache. The prompt is kept identical from turn to turn: what Vana knows about the athlete is built once per conversation and only rebuilt on a new day or after a change, and past turns are resent exactly as they were first sent. The cache is kept warm for an hour, so an athlete who comes back 40 minutes later still gets the cheap price.

**Why.** On dev, 85% of a planning turn's input now comes from the cache, against 43% before, and a turn costs about 0.8 cents instead of about 3.2.

**What else was considered.** Sending less of the athlete's context and letting Vana fetch it with tools, which makes her forget what she wasn't told. Keeping the cache for five minutes, which is cheaper to write but goes cold during a normal pause.

> 2026-09-26 overhaul: rewritten from mp-276, mp-420, mp-525, mp-568, mp-570

## mp-569 · Vana's calls go to Anthropic only
- category: Caching
- status: approved
- image: none
- screen: none (the Vana server)
- source: wave ai-cost 5 ticket 07

**Context.** Our AI calls pass through a gateway that could send a Claude call to Anthropic, Amazon Bedrock or Google Vertex. Each keeps its own cache, so a call sent somewhere new pays full price.

**Question.** Where do Vana's calls go, and what happens when Anthropic is down?

**Decision.** Every Vana call goes to Anthropic and nowhere else. When Anthropic is down, the athlete sees "Vana is unavailable right now" and is charged nothing.

**Why.** One provider means one cache. With a fallback, the cheap turn would become the exception.

**What else was considered.** Keeping Bedrock and Vertex as fallbacks, where every fallback turn would be a full-price one.

> 2026-09-26 overhaul: rewritten from mp-569

## mp-430 · We track usage, not credits: every account gets $4.00 of AI a month
- category: Usage budget
- status: approved
- folded: mp-281, mp-436, mp-504, mp-515
- image: none
- screen: none (algorithm/data)
- source: docs/research/vana-cost-and-pricing.md; Lee on the page 2026-09-17; Lee in the terminal 2026-09-21

**Context.** Before the subscription, every AI call took one credit from a wallet filled by credit packs. A credit per call counts how many times the athlete spoke, not what it cost us, so a heavy athlete could cost far more than they pay.

**Question.** How much AI does a subscriber get, and how is it counted?

**Decision.** Every account gets the same budget of $4.00 a month, and each AI call uses it up by what that call really cost us. Nothing counts messages, and there is no daily cap. The trial week starts with $1.00. Unused budget does not carry over to the next month. Credits already in wallets were converted once at 2 cents each. Per-minute limits exist only to stop a runaway loop or script, set well above what a person does.

**Why.** Lee on 21 September: cap what the account costs, not how often it speaks; one cap for the month, the same for everyone. No subscriber can cost more than $4.00 a month, against the $7.08 to $10.62 we keep from a founding subscription.

**What else was considered.** 300 or 600 credits a month with one credit per action. Daily caps on openers and turns. A hidden dollar ceiling behind visible credits.

> 2026-09-26 overhaul: rewritten from mp-430, mp-281, mp-436, mp-515

## mp-551 · Top-up packs add a share of a month and never expire
- category: Usage budget
- status: approved
- image: none
- screen: none (algorithm/data)
- source: mp-430; mp-281; wave ai-cost 4 ticket 09

**Context.** Heavy users can run out of the monthly budget before it refills. The credit packs they could already buy had to keep working once credits were gone.

**Question.** What does a top-up pack buy?

**Decision.** Packs keep their prices and add budget: $4.99 adds a quarter of a month ($1.00) and $19.99 adds a month and a quarter ($5.00). The month's own budget is spent first and bought budget after it. Bought budget never expires.

**Why.** Packs stay for heavy use without changing what people already paid for, and a month is the unit the athlete sees everywhere else.

**What else was considered.** Removing packs and relying on the monthly budget alone.

> 2026-09-26 overhaul: rewritten from mp-551, mp-430, mp-281

## mp-282 · Running out of budget opens the top-up sheet and never locks the app
- category: Usage budget
- status: approved
- folded: mp-342, mp-437, mp-549, mp-550, mp-573, mp-574
- image: none
- screen: Vana chat
- source: grill 2026-09-15; spec ai-cost 2026-09-21; wave ai-cost 4 ticket 09; wave ai-cost 5 ticket 10

**Context.** Before the budget, an empty wallet came back as an error that each feature handled in its own way. Some locked the athlete out; some showed a buy-credits message.

**Question.** What happens when an athlete uses up the month?

**Decision.** A call that starts with any budget left always finishes, even if it ends a few cents over. The next AI action opens the top-up sheet with how much is used, the refill date and the two packs. Above Vana's message box one line says "You've used this month's Vana — top up to keep chatting". Everything that uses no AI keeps working. If the fault is ours (the database can't be read, or our own monthly spending limit with the AI provider is hit), the athlete sees "Vana is unavailable right now" and never the top-up sheet.

**Why.** Cutting Vana off mid-answer costs more goodwill than the few cents it saves. Our own faults must never be blamed on the athlete's budget.

**What else was considered.** Refusing a call whose estimated cost doesn't fit what is left.

> 2026-09-26 overhaul: rewritten from mp-282, mp-342, mp-437, mp-436, mp-549, mp-550, mp-573, mp-574

## mp-572 · The athlete sees a share of the month, never dollars
- category: Usage budget
- status: approved
- folded: mp-571
- image: docs/ssot/decisions/images/mealplanning/vana-settings.png
- screen: Vana settings
- source: wave ai-cost 5 ticket 10

**Context.** The budget is counted in dollars on the server. Before the change, AI buttons carried credit price tags.

**Question.** How does the athlete see their usage?

**Decision.** Vana settings shows how much of this month is used and the refill date. The budget pill shows how much is left as a percentage, this month's remainder plus anything bought. The app never shows a dollar figure or a credit count, and AI buttons carry no price tags.

**Why.** A Vana turn has no fixed price, so a tag could only be wrong. A percentage is simple and never shows our costs.

**What else was considered.** Showing dollars to the athlete.

> 2026-09-26 overhaul: rewritten from mp-572, mp-571, mp-430

## mp-521 · Every AI call's real cost is logged per athlete
- category: Usage budget
- status: approved
- folded: mp-519
- image: none
- screen: none (algorithm/data)
- source: wave ai-cost 3 ticket 05

**Context.** To set the budget and prices from facts, we need to know what each athlete actually costs, how much the cache saves and which plan they are on.

**Question.** What do we record about each AI call?

**Decision.** Every Vana turn records what the gateway charged, how much of the prompt came from the cache, whether the athlete tapped or typed, and their subscription state at that moment. A weekly view adds this up per athlete and per plan. Raw rows are kept for 90 days; weekly totals are kept.

**Why.** Every later cost or pricing decision, like the one that set Haiku for chat, is argued from these numbers.

**What else was considered.** Keeping our own price table instead of the gateway's charge, which would give two answers to one question.

> 2026-09-26 overhaul: rewritten from mp-521, mp-519

# Cutting what Vana costs to run

**Status:** ready-for-agent

Written by `/to-spec-lee ai-cost` on 2026-09-21 from the 09-20 draft, Lee's rulings of 2026-09-21 and the
research below. The product decisions live in the mealplanning record (`mp-` ids) and are cited here. Build order, mechanics and
test seams are this spec's own and are not cards (Lee, 2026-09-21).
`draft-tickets/` is raw material for `/to-tickets-lee ai-cost`.

**Research:** `docs/research/vana-cost-and-pricing.md` (09-17), and from 09-20:
`ai-cost-internal-audit.md`, `ai-cost-claude-platform.md`, `ai-cost-vercel-and-services.md`,
`ai-cost-fees-credits-and-no-model-paths.md`, `running-cost-model.md`, `ai-cost-model-bakeoff.md`,
`ai-metering-market-survey.md`.

## Problem Statement

A typical athlete costs about $2.86 a month in AI today and a heavy one $6.85, against $7.08 a month
kept from a founding annual subscriber. Most of that cost is avoidable, and most of the avoidable part
is our own code, not the model's price.

The paywall opens on 2026-10-01 at $24.99 a month and $199.99 a year, with founding prices of $12.49
and $99.99 (mp-429). What the 09-20 audit found on dev:

- A planning turn reads only 43% of its input from Claude's cache, because tools, persona and athlete
  context sit in one block that every plan change discards.
- Since commit `2f619269` (09-16) every meal picker sends the model 24 extra meals it never uses,
  about 10,000 tokens, replayed on every later turn. Planning input climbs 31k, 38k, 54k, 72k.
- Every opener pays for a second model step that writes nothing (201 of 202).
- Openers are free and have no working rate limit. An empty-message request runs a free turn. The
  rate limiter counts only finished calls, so parallel requests pass.
- One credit buys any call, whatever it cost. 600 credits spent on planning turns cost $19.20.
- Two functions take requests with no sign-in check, on production and dev. A third runs on dev with
  no source in the repo.
- 55% of planning spend is in conversations that never add a meal. 45% of planning openers get no
  reply.
- Outside AI: production runs on Supabase's Free plan (no backups, 500 MB cap). Garmin pushes are 97%
  of edge function calls, and 61,000 of 65,000 Garmin rows are data no code reads.

## Solution

1. Close the holes that let someone spend our money without paying, and put a hard ceiling on every
   gateway key.
2. Replace credits per action with one monthly budget per account, measured in what its calls cost.
   The athlete sees a share of the month in Vana settings, never dollars.
3. Stop sending tokens nobody reads: compact tool results, no wasted opener step, a cache that
   survives a plan change, replay that is byte-stable.
4. Stop calling the model when nothing changed or nothing needs deciding: day notes, app-launch
   fetches, chip taps with one fixed meaning.
5. Measure, and move only the small background jobs to the cheapest model.

Expected result for the typical athlete: $2.86 a month today, about $1.64 after the cache fix alone,
about $1.10 to $1.30 after step 3 in full. No account can cost
more than $4.00 a month plus what it bought. Every figure is an estimate from 3 to 8 dev users; the
logging work replaces them with October's numbers.

## User Stories

1. As the owner, I want no endpoint that can call a model, send an email or write data without a
   signed-in caller, so that nobody can spend my money from outside the app.
2. As the owner, I want a monthly budget on each gateway key that hard-stops at the cap, so that a
   runaway script, eval or build agent cannot run up a bill.
3. As the owner, I want one monthly budget per account measured in real cost, so that no subscriber
   can cost more than the figure I set.
4. As the owner, I want openers to draw the budget down like any other call, so that no AI call is
   free.
5. As the owner, I want parallel requests counted when they start, so that a burst cannot pass the
   budget or the rate limit.
6. As an athlete, I want to see how much of this month's Vana I have used and when it refills, so
   that running out is never a surprise.
7. As an athlete, I want that shown as a share of the month, so that I never have to think in
   dollars or tokens.
8. As an athlete, I want the conversation that crosses my budget to finish, so that Vana never stops
   mid-answer.
9. As an athlete with credits in my wallet, I want them carried over at a fair rate, so that I lose
   nothing when the unit changes.
10. As an athlete, I want the top-up packs to add to my budget at the same prices, so that buying
    more still works.
11. As an athlete, I want Vana to answer as fast and as well as today, so that cost work never shows
    up as a worse assistant.
12. As an athlete, I want openers to arrive faster, so that the sheet feels instant.
13. As an athlete, I want "Vana is unavailable right now" when the fault is ours, so that I am never
    asked to pay for our outage.
14. As the owner, I want a planning turn to cost about a cent, so that the founding plans keep their
    margin.
15. As the owner, I want to see cost per athlete by plan, cost per confirmed plan and the cache hit
    rate each week, so that the budget is set from real traffic in October.
16. As the owner, I want to hear the same day when an account costs more than $1.50, so that I find
    out from Sentry and not from an invoice.
17. As an athlete, I want day notes that are current, so that they regenerate when my plan changes,
    and only then.
18. As an athlete, I want the app to open without fetching screens I have not visited, so that launch
    is faster.
19. As an athlete who taps a chip with one fixed meaning, I want the result at once, so that I am not
    waiting on a model for a step that was already decided.
20. As the owner, I want the small background jobs on the cheapest model that gives the same answer,
    so that nothing the athlete never reads costs more than it must.
21. As an athlete, I want a photo that is not food to get one short answer, so that I am not shown
    made-up macros.
22. As the owner, I want production on a Supabase plan with backups before anyone pays, so that a
    paying customer's data can be restored.
23. As the owner, I want the Garmin tables and the AI logs to stop growing with data nothing reads,
    so that the database stays inside its plan.
24. As the owner, I want the ideas we dropped written down with the reason, so that nobody researches
    them twice.

## Implementation Decisions

**Order.** One batch, with no split around 1 October. `/to-tickets-lee` derives the order, blockers
first and then by what each ticket touches. Everything deploys to dev, and the build starts there
before the cards are ruled; production follows separately with Lee's go. Device checks use the
simulator pool, three at most.

**The cost work and its order.** Log what is missing, the cache fix, the monthly budget, byte-stable
replay, openers without the wasted step. The 50-meal test that closed this list is put off (mp-465).
(mp-432)

**Open endpoints.** The plan-email function requires a signed-in caller, checked in its own code; the
app already sends the token. The bulk upload function stays deployed for released app versions and
takes the user id from the token, never from the body. The meal-plan parser that runs on dev with no
source in the repo is undeployed. The ticket lists every function that calls a model, sends mail or
writes with the service role, with its auth check. Dev now, production later with Lee's go.

**Guardrails.** A chat request with a conversation id and an empty message returns 400, runs no model
and stores no row. The rate limiter counts calls in flight by writing the call row before the model
runs. The pantry photo, the described meal and the meal photo use the same
limiter. The limiter stays where it is, on the server in the shared Vana rate-limit module; the
other functions call that one module and nothing moves to the phone (Lee, 2026-09-21). A turn stops
at a per-turn token ceiling as well as its step limit. The refusal text comes
from the content system.

**The monthly budget.** Every account gets the same monthly budget, measured in what its AI calls cost
us: $4.00 a month, the trial week a quarter of it, the packs adding $1.00 and $5.00 at today's prices.
Every call draws it down, openers included. There is no daily cap and no cap on turns. At 100% the
athlete gets the top-up sheet (mp-282). Vana settings shows the share of the month used, the refill
date and any bought extra, never dollars. The old free grant of 20 credits ends when the paywall
opens, a transferred subscription leaves the allowance where it was granted, and every debiting call
is covered. (mp-430)

**How the budget is metered.** The wallet holds whole micro-dollars. A call reserves an estimate for
its kind when it starts, in one atomic statement that also checks the balance; when it finishes the
reservation becomes the real cost, and a failed call gets its reservation back. The real cost is the
gateway's own charge, or the logged tokens priced from one table when the gateway reports none. A
call that starts inside the budget finishes; the next one gets the 402. A database error refuses the
call. Credits already in wallets convert once at 2 cents each, the rate the packs imply. The client
receives a share, a refill date and bought extra, never a dollar figure. (mp-436)

**Gateway keys and budgets.** Three gateway keys (production, dev, evals and build agents), each with
a monthly budget that hard-stops and an alert before it, created by Claude in Lee's signed-in Vercel
session: $150, $40 and $25 to start. A gateway refusal shows "Vana is unavailable right now", never
the top-up sheet. The AI SDK import is pinned to an exact version and the chat model id uses the
catalogue's spelling. Per-athlete cost comes from our own log, not the gateway's paid reporting.
(mp-437)

**The model gets only what it reads.** A tool whose result is larger than the model needs returns a
full form for the app and a compact form for the model; the meal picker's compact form is the meals
shown plus a count of the rest. Replay uses the compact form too, and the picker message is stored
once. A turn ends when Vana asks a choice, hands off, or saves feedback silently, so no opener pays
for a second step. The stop conditions are checked against the pinned SDK version.

**What is cached.** Caching is on for every Vana call and the log records cached tokens, and the athlete
context is built once per conversation (mp-276). The tools and
persona get their own cache breakpoint and the athlete context a second one. A replayed conversation
is byte-for-byte what was sent the first time: the screen line and the opener's hidden first message
are stored with the transcript. The opener's start-time test stays at 3.5 seconds. (mp-420)

**How the cache fix is built.** The system prompt becomes two system messages, persona then athlete
context. The first step is a one-line dev experiment with the gateway's automatic caching, measured on
ten planning turns; if it does not mark both messages, each gets an explicit marker. Calls are pinned
to Anthropic and carry a session id per conversation. The tool list never varies per turn. The shared
prefix uses the one-hour lifetime if the setting survives the gateway, which the ticket tests.

**The meal-logging prompts.** The described meal and the meal photo put their fixed instructions first
with a one-hour cache marker and the athlete's text or photo last. The function adds up the totals,
not the model. The output gains a "not food" answer. Photos are sent at 1,000 px on the long edge and
portrait stops billing a third more.

**Logging.** The call log gains cache-write tokens, step count, the gateway's charge and whether the
turn drew the budget (mp-420 clause 6), plus tap-or-typed, which the app sends, and the subscriber's
plan and trial state. One saved weekly view gives cost per athlete by plan, first-step cache hit rate,
cost per confirmed plan, spend in conversations that never add a meal, and the share of fixed-label
taps. A daily check reports any account over $1.50 in a day to Sentry and refuses nothing. Raw rows
in the three AI log tables are kept 90 days; weekly rollups are kept.

**Fewer needless calls.** Day notes regenerate only the days a plan edit touched, return the stored
notes when the plan is unchanged, and a claim row makes two simultaneous requests share one model
call. The Food tabs build on first visit, not at launch, and keep their state once visited. The
wallet's realtime channel is open only while a budget screen is showing.

**Openers and conversations.** Opening a conversation that exists shows it as it was, with no model
call; a new conversation always gets a new opener, and "New meal plan" always starts one. The app
already works this way and nothing is built. No opener is stored for reuse and none is templated
(mp-007, mp-008). (mp-443)

**Chip taps without a model.** Built now. A chip with one fixed meaning runs its action on the no-model
endpoint: "Other options", "Draft my whole week", "Same as last time", "No recipe only", "Under 20
min", the batch-cooking and coverage answers, "Open shopping list", "Lay it across the week", "Use what
I have" and the pantry card's "Use these". "I like these" and "Next" act at once when the next step is
the next meal type's picker. The result arrives with no written line, the tap and its result are
stored in the transcript for Vana's next turn, and the budget is not drawn. Chips Vana named,
"Different protein", "Adjust", openers and typed messages stay with Vana. The persona's chip
instructions shrink to match. (mp-464)

**Which model does which job.** Conversation and openers stay on Haiku 4.5; the described meal and
the meal photo stay on Sonnet, and the 50-meal test is not built now. The memory extraction, the
rolling summary and the saved-meal ingredient list get their own model setting and move to the
cheapest gateway model that returns the same structured answer on 20 stored dev conversations,
checked by hand. The coach insight route has no caller and is removed. No helper model runs inside a
Vana turn. (mp-465)

**Ruled out, with the reason recorded.** The on-device model, the batch API and routing before a
voice test (mp-432 clause 2). Context editing, tool search, trimming tools per turn, programmatic
tool calling, semantic and cross-athlete caching, a food database in front of the model, app
attestation, web checkout for 1 October, and skipping extraction on short conversations.

## Testing Decisions

A good test here asserts what the model is sent, what is written and what the athlete is charged,
never how the function builds it. Seam tests feed producer-shaped data (`docs/test/README.md`). No
test asserts a price.

**Server seam.** The shared Vana modules, called with the existing test context over the in-memory
fake database, with no faked model; tests feed the stream parts the SDK produces. Prompt shape extends
the prompt cache test (mp-290): persona then context, a context rebuild leaves the first message
byte-identical, a stored conversation replays as first sent. Each compacted tool is tested for a size
budget on the model-facing form and an unchanged app-facing part against the frozen contract
fixtures. The limiter is tested with five parallel calls against a limit of four, the empty message
for storing nothing, the turn loop for ending on a choice, a hand-off and a silent save, and the log
for every new column. The open endpoints, the meal-logging prompts and the Garmin push are tested in
each function's own test file.

**Wallet seam.** The budget's reserve, settle and refund run as real SQL on dev inside a rolled-back
transaction, as the wallet rules test does today: settle to real cost, two parallel reservations
where one fits, a failed call refunded, a call that finishes over the budget and the next refused,
monthly budget spent before bought budget, 50 old credits becoming $1.00. The shared credits test
covers the database error that refuses the call.

**Client seam.** Real controllers in widget tests over a transport that counts calls: no Vana call
before the Food tab is opened and a visited tab keeps its state; the wallet channel opens and closes
with the budget screens; a gateway refusal shows "Vana is unavailable right now" and never the top-up
sheet; the Vana settings usage bar shows a share, a refill date and bought extra with no dollar
figure. Every controller write path keeps its test through the real notifier.

**Measured on dev, not in CI.** Cache reads on ten planning turns before and after, recorded in the
ticket. The live opener eval asserts one model step when a turn ends on a choice, beside its check
that a second turn reads from the cache (mp-290 clause 3). The model tests run by hand from the eval
scripts on the evals key. Device checks run on the simulator pool.

Prior art: the prompt cache, contract and compaction tests under the Vana test folder; the wallet
rules test; the credits controller test and the Vana chat screen credits test.

## Out of Scope

- The server subscription check on the other AI functions and the lapsed read-only mode. That is
  paywall work (mp-429 clauses 6 and 11).
- Prices and the founding annual price. mp-429 and Xuan.
- The Apple Small Business Program enrolment and the AWS Activate application. Lee, by hand.
- Web checkout. Revisit when Apple's link-out rate is settled in court.
- Replacing OneSignal, Mixpanel or RevenueCat. None of their bills matters before about 670
  subscribers.
- The meal-logging truth set, the voice test and any model move for chat or meal logging. Not now
  (Lee, 2026-09-21; mp-465).
- A fallback model at 100% of the budget (mp-430 clause 6). It follows the voice test.
- Platform housekeeping, not right now (Lee, 2026-09-21): the Garmin rows nothing reads, recipe image
  resizing, production's Supabase plan, Codemagic on Linux, the Resend plan, the LocationIQ credit
  link. User stories 22 and 23 wait with it.
- Any production deploy. Each needs Lee's go under the deploy playbook.

## Further Notes

- Open question for Lee: can a sandbox purchase event reaching production grant a real budget? The
  production webhook is env-unfiltered by an earlier ruling, so the grant needs its own guard.
- Two research files disagree on the one-hour cache lifetime saving ($0.15 to $0.25 against $0.40 to
  $0.75 per athlete). Both agree it matters only at low traffic; the cache ticket measures it.
- The audit looked at dev. Production's function list got a read-only pass on 09-21 (the endpoints ticket).
- Market survey (09-20): no fitness or nutrition app publishes an AI cap for paying subscribers and
  none sells top-ups, so the packs are untested in this category. Suggestions for the decisions page,
  not tickets here: Family Sharing off; never the word "unlimited"; no silent limit cuts. AI cost
  target: 15% of net revenue blended, alarm at 20%. Founding annual sits near 19% even after the
  cache fix.
- Correction to `vana-cost-and-pricing.md`: "55% cancel on day 0" is the three-day-trial figure. For
  a seven-day trial it is about 40% on day 0 and 64% within 24 hours.
- Store rules: bought budget never expires (Apple 3.1.1); consumables cannot be restored, so the
  bought balance stays server-side; contesting a refund on a spent pack needs consent wording at
  purchase. The store text that names credits changes with the unit.

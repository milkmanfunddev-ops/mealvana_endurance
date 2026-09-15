# Vana knows you: the Voodoo Doll

Status: ready-for-agent
Created: 2026-09-09
Revised: 2026-09-15, after the grill that closed mp-210, mp-211, mp-215, mp-216, mp-217 and mp-267
Glossary: CONTEXT.md § Vana and what she knows, § Paying for the app

## Problem Statement

Vana does not know the person she is talking to. An athlete opens her from the Plan tab, asks
what to eat before tomorrow's ride, and she answers as if she had never met them: no idea what
tomorrow's ride is, no idea they are vegetarian, no idea they told her last week that Wednesday
nights are hopeless for cooking. She has to be told the same things every conversation, and even
then she forgets them by the next one.

The odd part is that the app already holds almost everything she would need. It knows the
training schedule, the diet, the allergies, the macro targets, the race, what was logged today,
what was thumbed up in the meal library, and what the onboarding survey said the goals were. A
memory table exists with vector recall behind it. Across the whole dev database it holds ten
rows, none of them from an ordinary conversation, and one of them twice.

Three specific gaps produce the experience:

- In general mode, the mode the Plan tab opens and the mode any everywhere-chat would use, the
  prompt carries a first name and today's date and nothing else. Everything must be fetched by a
  tool call the model may or may not make. Meal-planning mode gets a rich context block every
  turn; general mode gets a business card.
- Nothing writes Memories systematically. The model has a remember tool it never calls on its own;
  only the weekly debrief writes anything. Meal thumbs, likes, and survey goals are never read.
- Vana lives on one screen. She has no idea what the person is looking at, and the person has to
  leave what they were doing to ask her anything.

The first build closed those gaps and opened two more, which the grill of 2026-09-15 settled:

- What looked like memory was plumbing. A sliding window forgot the start of a long conversation,
  an episode was written from the wrong half of it, the next conversation waited three and a half
  seconds for a read-back of the last one, and every turn paid full price for a prompt that was
  four fifths identical to the turn before.
- Vana cannot ship. Meal planning is not released until the seven-day trial exists (mp-270), and
  every paywall decision was written for a free tier and a Pro tier that no longer exist.

## Solution

Vana gets a Voodoo Doll: everything she knows about one person, compiled at the moment she needs
it, in two parts. Facts are read from the records that already own them. Memories are one-line
margin notes she keeps between conversations, written when the person tells her something, when
she judges it worth keeping, and once per conversation when it goes idle and she reads back over
it. The person sees every Memory as a flat list and can delete any of them.

Every entry point sends the same Doll, plus one section for whatever is in view: the formula being
edited, the events ahead, the day's plan. Vana also reads the Situation: which screen the person
is on and what is in view, so "what should I eat before this" means the ride on screen. She comes
to the screens that have her as a glass sheet in the bottom corner, one running conversation per
day, without taking the person away from what they were doing.

She stays one persona. Whether the person wants a week planned, a question answered, or to tell
the team something, it is the same Vana recognising the Intent, and feedback already lands as a
row the team reads.

Within a conversation she keeps everything verbatim until it is long, then folds the oldest part
into one summary and keeps going. Between conversations she keeps what the person said, not their
schedule, and never waits for it. The unchanged part of every prompt is cached, so a turn costs a
quarter of what it did.

The app sells one thing: seven free days, then a subscription. RevenueCat is the gate, credits
stay as a monthly Allowance with Top-ups for heavy use, and nothing in the app decides who is
entitled.

## User Stories

1. As an athlete, I want Vana to know tomorrow's workout without being told, so that "what do I eat before it" gets a real answer.
2. As an athlete, I want Vana to know my diet and allergies in every conversation, so that I never see a suggestion I cannot eat.
3. As an athlete, I want Vana to know my macro targets for the day, so that her portion advice matches the plan the app already made.
4. As an athlete, I want Vana to know my upcoming race, so that race-week advice arrives without me announcing the race.
5. As an athlete, I want Vana to know what I logged today, so that "what's left for dinner" accounts for lunch.
6. As an athlete, I want Vana to know the goals I gave at onboarding, so that she plans toward them rather than asking again.
7. As an athlete, I want Vana to know which meals I thumbed up and down, so that she suggests more of the first and none of the second.
8. As an athlete, I want Vana to remember what I tell her ("no cilantro", "Wednesdays are chaos"), so that the next conversation starts where the last one ended.
9. As an athlete, I want to say "remember this" and have it stick, so that I can shape what she knows deliberately.
10. As an athlete, I want Vana to pick up durable things I said in passing, so that I do not have to flag every fact.
11. As an athlete, I want Vana to learn from a finished conversation without interrupting it, so that the chat stays about my question.
12. As an athlete, I want to see everything Vana remembers about me in one place, so that I know what she is working from.
13. As an athlete, I want to delete any Memory, so that a wrong or stale note stops shaping my plans.
14. As an athlete, I want Vana to hold to choices I made once (batch cooking, coverage, budget), so that she never re-asks them.
15. As an athlete, I want Vana not to announce what she learned about me, so that she reads as attentive rather than surveilling.
16. As an athlete, I want Vana to know where I live, so that weather and shopping advice apply to my town and not my race venue.
17. As an athlete, I want to tell Vana where I live in conversation and have it stored, so that I do not hunt for a settings field.
18. As an athlete, I want Vana to know which screen I am on and what it shows, so that "this" means the ride or meal in front of me.
19. As an athlete, I want to open Vana from the screens where she lives, so that a question does not cost me my place in the app.
20. As an athlete, I want Vana to open as a sheet over the current screen, so that what I was looking at stays visible.
21. As an athlete, I want the sheet to look like the rest of the app's glass surfaces, so that it feels native rather than bolted on.
22. As an athlete, I want the everyday conversation to carry through the day, so that a follow-up an hour later has the context of the morning.
23. As an athlete, I want a full-screen route from the sheet, so that planning a week has room.
24. As an athlete, I want the Plan tab's Vana card to open the same conversation the launcher does, so that I am never in two "today" conversations at once.
25. As an athlete, I want New meal plan to start fresh and leave my day's conversation where it was, so that a side trip does not lose my place.
26. As an athlete editing a formula, I want to ask Vana about the draft in front of me, unsaved edits included, so that her answer is about what I am looking at.
27. As an athlete on the events screens, I want Vana to know every event ahead, not just the next one, so that "how do I fuel the second race" makes sense to her.
28. As an athlete, I want one Vana whatever I ask, so that I never wonder which assistant to talk to.
29. As an athlete, I want to give feedback in Vana's chat in my own words, so that I do not have to find a form.
30. As an athlete, I want Vana to acknowledge feedback in one line and stop, so that I am not troubleshot when I was venting.
31. As a long conversation's participant, I want Vana to remember how the conversation started after forty turns, so that the plan we made in the first ten is not lost.
32. As an athlete, I want the next conversation to know what the last one established without a pause, so that Vana's first line arrives at once and is still about me.
33. As a new athlete, I want seven free days of the whole app, so that I can judge it before paying.
34. As a lapsed athlete, I want my data untouched and back the moment I subscribe or restore, so that a gap costs me nothing.
35. As a subscriber, I want a monthly Allowance of credits that covers a normal week, so that I never see a top-up unless I am unusual.
36. As a heavy user, I want to buy a Top-up when the Allowance is gone, so that a busy month does not stop me.
37. As a subscriber offline, I want the app to open on my cached entitlement, so that a plane does not lock me out.
38. As a product owner, I want feedback rows to carry sentiment, what they are about, and the conversation, so that the team can act on them.
39. As a product owner, I want the cost of a turn to drop to about a quarter without changing what Vana knows, so that the model bill scales with users, not with chattiness.
40. As a product owner, I want cache reads logged per call, so that a silent cache miss is visible the day it happens.
41. As a product owner, I want personalization proven by evals, so that "she knows me" is a test and not a feeling.
42. As a product owner, I want the gate to be RevenueCat and nothing else, so that entitlement bugs are one system's bugs.
43. As a product owner, I want existing accounts to meet the same paywall as new ones, so that there is one model from launch day.
44. As a developer, I want the Doll built in one place on the server, so that every entry point reads the same thing.
45. As a developer, I want the Situation resolved on the server from ids, so that the client never sends names or text, with the formula draft as the one named exception.
46. As a developer, I want near-duplicate Memories rejected at write time, so that the store does not fill with the same note.
47. As a developer, I want the conversation summary to live on the conversation row, so that there is no second table and no writer race.
48. As a developer, I want the old fuelling-product preferences untouched, so that Formula Kit keeps working.
49. As a developer, I want the entitlement table to be a cache of RevenueCat and nothing more, so that nothing in the app can grant access.

## Implementation Decisions

**The Doll is a view, never a copy.** A single server-side builder assembles it per request from
the canonical records. The only persistence it owns is the existing memory table. No profile
field is stored twice. (mp-020)

**Both modes read the full Doll.** The context block meal-planning mode already injects every
turn is injected in general mode too, extended with three lines: LIKES from Meal feedback, GOALS
from the onboarding survey, and SITUATION. (mp-021)

**Every entry point sends the same Doll, plus one section for what is in view.** The Doll is a
fixed-shape digest, the same lines in the same order for everyone, every list capped, under the
token budget of mp-218. The Situation is the only variable: the client sends a route and an id,
and the server adds one capped section for the entity in view, only while it is in view (a
FORMULA section on the formula screens, an EVENTS AHEAD list on the events screens, the day's plan
on the Plan tab). Anything deeper is a tool, never a line. The Doll never grows to hold what one
entry point might want. (mp-273, mp-218)

**The formula editor sends its draft as structured fields.** The draft may not exist on the
server, so the editor's Situation carries phase, sub-phase, durations, activities, component ids
with quantities and a name capped at forty characters, and the server builds the FORMULA section
from that. It is the one named exception to the ids-only rule, validated like a route. The
one-shot coach insight call is replaced by this conversation. (mp-274, mp-209)

**One persona, Intent per exchange, no classifier.** The two conversation kinds remain as a tag
for history and for the opener logic. All tools are available in both kinds; the prompt carries
Intent-specific sections. No pre-turn classification call. (mp-002, mp-003)

**What continues and what starts fresh.** The launcher, its full-screen button, the Plan tab's
Vana note card and a moment tap all open the day's ambient conversation; the note card stops
starting its own. New meal plan and the chat app bar's plus button start a new conversation, and
so will a formula-editor entry. A conversation started that way never moves the launcher's
pointer. (mp-275, mp-058)

**Vana lives on three screens.** The launcher appears on the main tabs screen, the meal-planning
screen and coach formulas, and nowhere else. (mp-264)

**The repeated prefix is cached, and the context block does not churn.** Caching is on through
the gateway's automatic mode with cache-read tokens logged per call. The context block is
assembled once when a conversation opens and reused for its turns, refreshed only when a tool
writes (plan, memory, pantry, home) or the day changes; per-message memory recall leaves the block
and stays available as a tool. The prompt order is fixed: tools, persona, context, messages.
(mp-276)

**History is chunked, never sliding.** Every message stays verbatim up to forty. At forty the
oldest twenty become one summary message and the last twenty stay verbatim; at sixty the same
again, rolling the previous summary in. The summary is written in the background when the count
reaches thirty and applied at forty, so no turn waits and the cached prefix changes once per
twenty turns. It lives on the conversation row, keyed by the message index it covers. (mp-277)

**Memory has three writers.** (1) The person says "remember this" and the existing remember tool
fires; the prompt is sharpened so this is reliable. (2) The model calls the remember tool on its
own the moment the athlete says something durable; this is the writer in the hot path. (3) When
the conversation goes idle, the server writes its episode and any margin notes the tool missed,
once. (mp-024, mp-025, mp-277)

**The client says when a conversation is idle.** When the sheet closes, the app goes to the
background, or a new conversation starts, the client sends the idle signal as a flag on the
existing chat call, the way the opener flag rides it. The server treats it as fire-and-forget
and idempotent: a second signal for the same conversation writes nothing. Offline, the signal is
dropped and the conversation is read back the next time it is opened; its margin notes were
already written by the hot path. No scheduled sweep yet. (mp-288, mp-253)

**The opener never waits.** No read-back on open, no fixed wait, no last-words fallback, no
mid-conversation episode from the opening half. The opener says the most relevant thing Vana
already holds from the memory table and the newest episodes as they stand, and leaves last time
out when its episode does not exist yet. Episodes and the LAST TALKS line stay. (mp-278, mp-008,
mp-038)

**The margin-note rule is the definition of a Memory** and the literal instruction to the
extractor: one sentence a good dietitian would write in the margin of the person's file, only
if it changes how Vana plans for them next time. Not what was asked, not this week's plan, not
anything already a Fact. (mp-022)

**Dedupe on write, no contradiction handling.** Before inserting, the new sentence's embedding
is compared with the person's existing Memories; above a near-identical threshold the write is
skipped and the existing row's confirmed date is refreshed. Conflicting Memories both stay;
each carries its date in the prompt and the model weighs recency. A supersedes mechanism is
deferred until a real user hits a real contradiction. (mp-028, mp-029)

**Nothing is announced.** Extracted Memories produce no card and no mention. The in-chat
"remembered" card stays for the explicit tool. The flat list in Vana settings is the audit
trail. (mp-027)

**Kinds stay in code, not in the product.** The memory table's kinds remain for the keyed
setting mechanism (batch cooking, coverage scope, budget, pantry) and for the episode summary.
The person sees one flat list of sentences with source and date. The glossary word "Decision"
is retired; a keyed Memory is simply a Memory Vana honours without asking. (mp-037)

**Meal feedback is read, not moved.** The existing thumbs table is the LIKES source. No new
preferences table. Anything the person says about food in words is a Memory. The fuelling-product
preferences table and its screens are untouched. (mp-023)

**No inference from behaviour.** Swaps, skips, and repeated logs do not write Memories. The
weekly debrief, which already distils learnings with the person in the loop, is the only
behaviour-derived writer. (mp-030)

**Home location becomes a Fact.** Three fields on the user record: home city, coordinates,
timezone. A profile tool lets Vana set them when the person mentions where they live. Weather
and Kroger coverage key off home location when present and fall back to race location. (mp-257)

**Situation travels with each message and is never stored.** The client sends the route and the
primary entity id and date for that screen. The server resolves ids into one sentence. The
screen-to-entity table is: Plan tab (date, plan), meal detail (meal), fuel log and current plan
(activity), event screens (event), meal-log screens (date, slot), main tabs (date); every other
screen sends route only. (mp-043, mp-044)

**The sheet is a design-bearing widget.** A component spec is drafted in the QA repo from the
existing glass surface and tab-bar tokens, synced with the design-sync process, then implemented
once under its spec name and composed by the shell. It opens over the current screen, keeps one
ambient general conversation per person per day, and offers a full-screen affordance that opens
the existing chat route. (mp-259, mp-058, mp-265)

**Seven free days, then a subscription, and the store runs the trial.** The existing monthly and
annual subscriptions each get a seven-day free introductory offer on both stores; no new product
ids. The athlete subscribes at the end of onboarding with a payment method on file and is
charged on day eight unless they cancel; the store's one-offer-per-person rule means a cancelled
trial is not repeated. RevenueCat's entitlement is the gate from day one. There is no free tier,
no Pro tier, no trial clock and no trial state in the app. Meal planning ships only once this is
live. (mp-279, mp-266, mp-270)

**Everything is behind the one gate.** An inactive account lands on the paywall after sign-in
and stays there. The paywall carries Restore purchases, Manage subscription, Sign out and Delete
account. No Vana-specific gate. Their data is untouched and returns the moment they subscribe or
restore. (mp-280, mp-266)

**Credits stay as a Top-up over a monthly Allowance.** The subscription grants a monthly
Allowance into the same wallet the packs fill, on each RevenueCat renewal event, so the reset
follows the billing date (an annual subscription is granted monthly on the anniversary day). The
trial week gets the full grant on day one; a cancelled trial forfeits what is left. Packs are
spent only when the Allowance is empty and never expire. The six debiting functions keep debiting
one credit per call. The number is set with the paywall copy and recorded on the card. (mp-281)

**An empty wallet shows the top-up sheet, never the gate.** The button that would debit shows
the sheet: what the Allowance is, when it renews, and the two packs. In Vana the composer's send
shows it, with one line above the composer; Vana never says "out of credits" mid-thread. The
server keeps returning 402 and the client keeps one handler for it in the shared layer. (mp-282)

**Existing accounts get no grace period.** They meet the paywall and the store trial on first
launch of the new build. Paid pack credits stay in the wallet. (mp-283)

**An unknown entitlement is locked, and the cache wins when it exists.** The SDK's cached
entitlement is the answer whenever there is one, online or not, and the gate reacts when it
changes. No cache and no answer within a couple of seconds is locked, with Restore purchases on
the paywall. (mp-284)

**The entitlements table is a two-field cache of RevenueCat.** The webhook alone writes active
until and period type; the server gates every debiting or Vana call on them. On any disagreement
RevenueCat wins, an event older than the row's event time is ignored, and nothing grants an
entitlement from the app side. (mp-285)

**Coaches get nothing special yet.** One gate, one trial, the same subscription, no coach branch
in the code. The coach rule is an open question waiting on Xuan's paywall document; when it is
written the adaptation path is a RevenueCat grant on the coach role. (mp-286)

**Feedback is already a tool.** The save-feedback tool writes sentiment, an about-field, the
message, and the conversation to the feedback table. This spec's only feedback work is verifying
it live on dev and fixing what that finds. The bug-report card into Wiredash stays for anything
needing a screenshot. (mp-248)

**Model stays Haiku.** Every eval case records input and output tokens so a model comparison can
be made later with numbers. (mp-018)

**No new machine learning.** Embedding recall is the retrieval pattern already in place. No
trained preference model, no orchestration framework change. (mp-040)

## Testing Decisions

A good test feeds producer-shaped rows in and asserts what comes out: the lines of a context
block, the rows written to the memory table, the sentence a Situation resolves to, the shape of
the messages a turn replays. It never asserts on prompt wording, tool-call order, or private
helpers. Seam tests never feed the local engine's own output back in.

**Three seams, and what never runs in CI.** Server pure functions with a fake database, live
personalisation evals by hand against dev, and client controller tests through the real notifier
plus goldens. (mp-263)

**Seam 1: server pure functions**, Deno tests beside the Vana modules over the in-memory
database stand-in that ticket 02 built. Already covered: the context builder, the extractor, the
dedupe check, the Situation resolver, the profile tool, moments, feedback acknowledgement. Added
by this revision: the per-entry-point section (a formula draft in, a FORMULA section out; events
in view, an EVENTS AHEAD list out; nothing in view, no section), the idle signal (first signal
writes the episode and notes, second writes nothing, no signal writes nothing), and the
entitlement webhook (a renewal event grants the Allowance and writes the two fields, an older
event is ignored, a transfer moves the row). Prior art: the existing Vana seam tests, the
daily-macros edge-function tests. (mp-263)

**The cache and the compaction are tested by shape, not by price.** The token-budget test
(mp-218) also builds the block twice for the same athlete with no writes between and asserts the
two are byte-identical, and that a tool write or a day change produces a different block. The
compaction test feeds a conversation of thirty-nine, forty, and sixty-one messages and asserts the
replayed shape (all verbatim; one summary plus twenty; one rolled summary plus twenty), that the
summary is keyed to the index it covers, and that the turn returns before the summary call does.
The eval seam records cache-read tokens per case and fails a case whose second turn reads zero.
(mp-290)

**Seam 2: live personalization evals** added to the existing vana-eval scripts against dev. Real
model, real rows, run by hand, never in CI. Cases: a Memory saved in one conversation is used
unprompted in the next; general mode answers "what's my workout tomorrow" and "what did I log
today" without a tool failure; a keyed Memory is not re-asked; "you keep suggesting fish" lands a
feedback row with negative sentiment about Vana; a first conversation with an empty Doll still
opens sensibly; the opener of a conversation whose predecessor was never signalled idle still
opens at once; token cost and cache reads per case are recorded. Prior art: the lifecycle eval. (mp-263)

**Seam 3: client controller and goldens.** One test through the real notifier for each write
path: the Memory list's delete, the Situation provider's output per route including the formula
draft, the sheet's open and full-screen actions, the note card and New meal plan routing (day's
conversation versus fresh), the idle signal on sheet close, app background and new conversation,
the gate provider (cached entitlement opens, no cache and a timeout locks, a later refresh
reopens), and the shared 402 handler raising the top-up sheet from a Vana send and from the
coach insight. Goldens for the sheet on the glass shell and for the paywall with its four
actions. Prior art: the meal-planning application tests and the existing Vana goldens. (mp-263)

**The store trial is verified by hand in sandbox, never in CI.** A fresh sandbox account on each
store subscribes through the introductory offer, the entitlement is active on day one, the
webhook lands the Allowance, the subscription is cancelled and the account meets the paywall, and
Restore reopens it. The run is written up with the release. (mp-289)

## Out of Scope

- Any onboarding change beyond the paywall at its end, including a likes step.
- A new preferences table. Meal feedback stays where it is; fuelling-product preferences stay
  where they are.
- Inferred Memories from swaps, skips, or logs.
- Contradiction detection or a supersedes chain.
- Coach mode: a coach's Vana never reads an athlete's Doll. The coach paywall rule waits on
  Xuan's document (mp-287).
- A model change, a classifier, embeddings beyond what exists, or any trained model.
- A scheduled server sweep for conversations never signalled idle; added only if the miss shows.
- A monthly fair-use cap beyond the Allowance; rate limits and the cost log bound abuse.
- Retiring the legacy jade-chat route (it stays the general-mode alias while shipped clients use it).
- Meal-plan moments (cook check-in, week debrief): ticket 12 waits for its own grill.
- Prod deployment: pgvector is not on prod and the meal-planning cutover runbook installs it.

## Further Notes

- Dev holds ten memory rows in total; the person who tested most has one keyed row and three
  debrief learnings, one duplicated. That duplicate is the dedupe test's fixture.
- The opener's synthetic user message is never stored; extraction must not depend on it.
- The conversation summary column was read by client and server and written by nothing. Under
  mp-277 it carries the rolling summary, keyed by the message index it covers; the list preview
  may show the episode sentence instead.
- Research behind the memory shape and the cost sketch: docs/research/conversation-memory-strategies.md.
- Store products already exist (monthly and annual on both stores, one RevenueCat entitlement in
  the default offering); the trial is an introductory offer added to them, not a new product.
- The remove list for mp-277 and mp-278: the read-back wait constant, the read-back-within and
  athlete-words helpers, the mid-conversation episode writer and its opening-half prompt.

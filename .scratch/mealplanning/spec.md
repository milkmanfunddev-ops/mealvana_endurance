# Vana knows you: the Voodoo Doll

Status: ready-for-agent
Created: 2026-09-09
Glossary: CONTEXT.md § Vana and what she knows

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

## Solution

Vana gets a Voodoo Doll: everything she knows about one person, compiled at the moment she needs
it, in two parts. Facts are read from the records that already own them. Memories are one-line
margin notes she keeps between conversations, written when the person tells her something, when
she judges it worth keeping, and once per conversation when she reads back over it after the
fact. The person sees every Memory as a flat list and can delete any of them.

Both modes read the same Doll. Vana also reads the Situation: which screen the person is on and
what is in view, so "what should I eat before this" means the ride on screen. She then comes to
every screen as a glass sheet in the bottom corner, one running conversation per day, without
taking the person away from what they were doing.

She stays one persona. Whether the person wants a week planned, a question answered, or to tell
the team something, it is the same Vana recognising the Intent, and feedback already lands as a
row the team reads.

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
19. As an athlete, I want to open Vana from any screen, so that a question does not cost me my place in the app.
20. As an athlete, I want Vana to open as a sheet over the current screen, so that what I was looking at stays visible.
21. As an athlete, I want the sheet to look like the rest of the app's glass surfaces, so that it feels native rather than bolted on.
22. As an athlete, I want the everyday conversation to carry through the day, so that a follow-up an hour later has the context of the morning.
23. As an athlete, I want a full-screen route from the sheet, so that planning a week has room.
24. As an athlete, I want Vana absent on sign-in, onboarding, and paywall screens, so that she does not appear before there is anything to talk about.
25. As an athlete, I want one Vana whatever I ask, so that I never wonder which assistant to talk to.
26. As an athlete, I want to give feedback in Vana's chat in my own words, so that I do not have to find a form.
27. As an athlete, I want Vana to acknowledge feedback in one line and stop, so that I am not troubleshot when I was venting.
28. As a long conversation's participant, I want Vana to stay coherent after many turns, so that the chat does not slow down or lose the thread.
29. As an athlete on a trial, I want Vana available under the same gate as the rest of the app, so that there is no second paywall inside it.
30. As a product owner, I want feedback rows to carry sentiment, what they are about, and the conversation, so that the team can act on them.
31. As a product owner, I want Vana's per-turn cost recorded per eval case, so that a later model decision is made with numbers.
32. As a product owner, I want personalization proven by evals, so that "she knows me" is a test and not a feeling.
33. As a developer, I want the Doll built in one place on the server, so that both modes and any future surface read the same thing.
34. As a developer, I want the Situation resolved on the server from ids, so that the client never sends names or text.
35. As a developer, I want near-duplicate Memories rejected at write time, so that the store does not fill with the same note.
36. As a developer, I want conversation summaries to be episode Memories, so that there is one recall mechanism, not two.
37. As a developer, I want the old fuelling-product preferences untouched, so that Formula Kit keeps working.

## Implementation Decisions

**The Doll is a view, never a copy.** A single server-side builder assembles it per request from
the canonical records. The only persistence it owns is the existing memory table. No profile
field is stored twice.

**Both modes read the full Doll.** The context block meal-planning mode already injects every
turn is injected in general mode too, extended with three lines: LIKES from Meal feedback, GOALS
from the onboarding survey, and SITUATION. Cost is roughly 1.5k input tokens per turn on Haiku
and is accepted.

**One persona, Intent per exchange, no classifier.** The two conversation kinds remain as a tag
for history and for the opener logic. All tools are available in both kinds; the prompt carries
Intent-specific sections. No pre-turn classification call.

**History is capped.** Each turn replays at most the last 20 messages. When the cap bites, the
conversation's episode Memory is prepended once so earlier context survives in one sentence.

**Memory has three writers.** (1) The person says "remember this" and the existing remember tool
fires; the prompt is sharpened so this is reliable. (2) The model calls the remember tool on its
own when the margin-note rule is met. (3) Lazy extraction: when a conversation opens, the
previous conversation of that person that has not yet been read back is fed to one Haiku call
with the margin-note rule and a strict schema of zero to three sentences plus one episode
sentence; the sentences are written as Memories and the episode as an episode Memory. A
conversation is marked as read back so it is never extracted twice. No scheduler.

**The margin-note rule is the definition of a Memory** and the literal instruction to the
extractor: one sentence a good dietitian would write in the margin of the person's file, only
if it changes how Vana plans for them next time. Not what was asked, not this week's plan, not
anything already a Fact.

**Dedupe on write, no contradiction handling.** Before inserting, the new sentence's embedding
is compared with the person's existing Memories; above a near-identical threshold the write is
skipped and the existing row's confirmed date is refreshed. Conflicting Memories both stay;
each carries its date in the prompt and the model weighs recency. A supersedes mechanism is
deferred until a real user hits a real contradiction.

**Nothing is announced.** Extracted Memories produce no card and no mention. The in-chat
"remembered" card stays for the explicit tool. The flat list in Vana settings is the audit
trail.

**Kinds stay in code, not in the product.** The memory table's kinds remain for the keyed
setting mechanism (batch cooking, coverage scope, budget, pantry) and for the episode summary.
The person sees one flat list of sentences with source and date. The glossary word "Decision"
is retired; a keyed Memory is simply a Memory Vana honours without asking.

**Meal feedback is read, not moved.** The existing thumbs table is the LIKES source. No new
preferences table. Anything the person says about food in words is a Memory. The fuelling-product
preferences table and its screens are untouched.

**No inference from behaviour.** Swaps, skips, and repeated logs do not write Memories. The
weekly debrief, which already distils learnings with the person in the loop, is the only
behaviour-derived writer.

**Home location becomes a Fact.** Three fields on the user record: home city, coordinates,
timezone. A profile tool lets Vana set them when the person mentions where they live. Weather
and Kroger coverage key off home location when present and fall back to race location.

**Situation travels with each message and is never stored.** The client sends the route and the
primary entity id and date for that screen. The server resolves ids into one sentence. The
screen-to-entity table is: Plan tab (date, plan), meal detail (meal), fuel log and current plan
(activity), event screens (event), meal-log screens (date, slot), main tabs (date); every other
screen sends route only.

**The sheet is a design-bearing widget.** A component spec is drafted in the QA repo from the
existing glass surface and tab-bar tokens, synced with the design-sync process, then implemented
once under its spec name and composed by the shell. It opens over the current screen, keeps one
ambient general conversation per person per day, and offers a full-screen affordance that opens
the existing chat route. It is hidden on auth, onboarding, privacy consent, paywall, force
upgrade, and all Vana routes.

**Gating follows the app.** No Vana-specific gate. The free-trial change is a separate effort;
until it lands the existing Pro gate applies to the sheet as it does to the chat routes.

**Feedback is already a tool.** The save-feedback tool writes sentiment, an about-field, the
message, and the conversation to the feedback table. This spec's only feedback work is verifying
it live on dev and fixing what that finds. The bug-report card into Wiredash stays for anything
needing a screenshot.

**Model stays Haiku.** Every eval case records input and output tokens so a model comparison can
be made later with numbers.

**No new machine learning.** Embedding recall is the retrieval pattern already in place. No
trained preference model, no orchestration framework change.

## Testing Decisions

A good test feeds producer-shaped rows in and asserts what comes out: the lines of a context
block, the rows written to the memory table, the sentence a Situation resolves to. It never
asserts on prompt wording, tool-call order, or private helpers. Seam tests never feed the local
engine's own output back in.

**Seam 1: server pure functions**, Deno tests beside the Vana modules, with a fake database.
Covers the context builder (LIKES, GOALS, SITUATION lines; general and planning modes produce the
same block), the history cap (20 messages, episode prepended when it bites), the extractor
(transcript plus existing Memories in, zero to three sentences and one episode out, conversation
marked read back, second run writes nothing), the dedupe check (near-identical skipped and
refreshed, distinct written), the Situation resolver (each screen in the table to its sentence,
unknown route to route only), and the profile tool (home fields written, weather keyed off them).
Prior art: the daily-macros edge-function tests and the algorithm test runner.

**Seam 2: live personalization evals** added to the existing vana-eval scripts against dev. Real
model, real rows, run by hand, never in CI. Cases: a Memory saved in one conversation is used
unprompted in the next; general mode answers "what's my workout tomorrow" and "what did I log
today" without a tool failure; a keyed Memory is not re-asked; "you keep suggesting fish" lands a
feedback row with negative sentiment about Vana; a first conversation with an empty Doll still
opens sensibly; token cost per case is recorded. Prior art: the lifecycle eval.

**Seam 3: client controller and goldens.** One test through the real notifier for each new write
path: the Memory list's delete, the Situation provider's output per route, the sheet's open and
full-screen actions. Goldens for the sheet on the glass shell. Prior art: the meal-planning
application tests and the existing Vana goldens.

## Out of Scope

- Any onboarding change, including a likes step.
- A new preferences table. Meal feedback stays where it is; fuelling-product preferences stay
  where they are.
- Inferred Memories from swaps, skips, or logs.
- Contradiction detection or a supersedes chain.
- Coach mode: a coach's Vana never reads an athlete's Doll.
- A model change, a classifier, embeddings beyond what exists, or any trained model.
- The free-trial paywall change.
- Retiring the legacy jade-chat credit route (follows the trial change).
- Prod deployment: pgvector is not on prod and the meal-planning cutover runbook installs it.

## Further Notes

- Dev holds ten memory rows in total; the person who tested most has one keyed row and three
  debrief learnings, one duplicated. That duplicate is the dedupe test's fixture.
- The save-feedback tool and the first-conversation feedback prompt were deployed to dev
  uncommitted and never verified live. Ticket zero is that verification.
- The opener's synthetic user message is never stored; extraction must not depend on it.
- The conversation summary column is read by client and server and written by nothing. Episode
  Memories replace its intended use; the column may carry the episode sentence for list previews.
- The Vana shared modules currently have no unit tests, so Seam 1 creates the harness the first
  time it is used.

# Vana is traced, prompted and judged in Langfuse

**Status:** ready-for-agent

Written by `/to-spec` on 2026-09-30 from the same day's `/grill-with-docs` session. Lee's decisions
are recorded in `docs/langfuse/pivot/REPORT.md` under "Decisions"; the research behind them is in
`docs/langfuse/pivot/01` to `06`. Words follow `CONTEXT.md`, section "Judging Vana". This spec
covers two repos: this one and `../mealvana_eval`.

## Problem Statement

Lee and Xuan cannot see what Vana did in a Turn. When an athlete gets a poor answer there is
nothing to open: no record of the Context block Vana read, which Tools she called, what they
returned, or what the Turn cost. The only tracing seam is used by a dev-only function.

Vana's wording lives in the edge functions' source. Changing one sentence of her persona is a code
change and a deploy, and Xuan, whose nutrition judgement the wording depends on, cannot change it
at all.

Judging was built twice as bespoke systems and neither is what Lee wants to keep. The eval web app
has its own screens, Judge, Mark and Rubric, several tickets still unbuilt, and no place for Xuan
to review conversations or record what Vana should have said. Its Judge defaulted to Opus, the
most expensive model available.

Feedback from athletes is a shake gesture that files a bug report unattached to any reply, plus a
tool Vana calls when an athlete volunteers an opinion. Neither tells anyone which conversations
went badly.

## Solution

Langfuse becomes the one place where Vana's work is seen, worded and judged.

Every AI call the app makes sends a Trace to Langfuse Cloud, first from dev and then from prod.
Lee or Xuan can open any Turn and see each Step, each Tool call, the prompt version that produced
it and the Gateway's true charge, grouped by Conversation and by athlete.

Vana's prompts and each call's model are stored in Langfuse. Saving an edit makes it live on dev.
Moving the `production` label publishes it to real athletes, and moving it back undoes it, with no
deploy.

Evaluators in Langfuse score conversations: ready-made ones that flag pushback and complaints, a
Dietitian evaluator tuned to agree with Xuan, and a check for robotic conversation. Xuan reviews
flagged conversations in a queue, marks them and writes corrections.

Saved test conversations live in a Langfuse dataset. Clicking Run in Langfuse plays each one
against Vana with a Simulated athlete and puts the judged results beside earlier Experiments. The
eval web app is reduced to the one endpoint that Run button calls.

The spending controls do not change. The Call log, Wallet and Monthly budget still decide whether
a call may run.

## User Stories

Seeing what Vana did

1. As Lee, I want every chat Turn on dev to appear in Langfuse as a Trace, so that I can open a
   Turn and see what happened inside it.
2. As Lee, I want each Step of a Turn shown as its own Generation with its tokens, so that I can
   tell which Step was slow or expensive.
3. As Lee, I want each Tool call shown with what Vana sent and what came back, so that I can tell a
   wrong tool choice from a wrong answer.
4. As Lee, I want the Context block and persona that Vana read to be visible on the Trace, so that
   I can see whether she was given the right facts.
5. As Lee, I want the Traces of one Conversation grouped as a Session, so that I can read the
   whole conversation in order.
6. As Lee, I want each Trace tied to the athlete, so that I can list one athlete's conversations.
7. As Lee, I want dev, prod and experiment traffic kept apart by environment, so that test runs
   never mix with real athletes' Turns.
8. As Lee, I want describe-meal and meal photo analysis traced, with the photo visible, so that I
   can see why a meal was read wrongly.
9. As Lee, I want the background calls (memory extraction, summaries, day notes, pantry photo,
   saved-meal ingredients) traced, so that I can see what Vana remembered and why.
10. As Lee, I want embeddings left out of tracing, so that the monthly allowance is spent on calls
    worth reading.
11. As Lee, I want a failed Turn to show as an error on its Trace, so that failures can be found
    by filter.
12. As Lee, I want each Trace to carry the app release it came from, so that a regression can be
    tied to a deploy.
13. As an athlete, I want Vana's reply to arrive exactly as before whether or not Langfuse is
    reachable, so that tracing never costs me an answer.
14. As an athlete, I want Vana to reply as quickly as before, so that tracing adds no wait.
15. As Lee, I want real athletes' Turns traced once dev tracing is proven, so that a complaint
    from prod can be opened and read.
16. As an athlete, I want the privacy documents to name Langfuse before my conversations are sent
    there, so that I know who holds my data.

Seeing what Vana costs

17. As Lee, I want each Generation to show the Gateway's exact charge, so that Langfuse and the
    Call log agree.
18. As Lee, I want cost per athlete visible in Langfuse, so that I can see who costs the most
    without querying the database.
19. As Lee, I want cost broken down by model and by prompt version, so that I can see what a
    wording or model change did to spend.
20. As Lee, I want the Monthly budget and Wallet to keep working exactly as they do, so that a
    paying athlete's limit never depends on a third party.
21. As Lee, I want evaluators and experiments to draw on a Gateway key with its own monthly
    budget, so that a runaway evaluator cannot drain the credits prod runs on.
22. As Lee, I want no call anywhere to use an Opus model, so that judging and testing stay cheap.

Wording Vana

23. As Xuan, I want to edit Vana's persona in Langfuse, so that I can change her wording without
    asking for a deploy.
24. As Xuan, I want a saved edit to be live on the dev app at once, so that I can try it on my
    phone.
25. As Xuan, I want to publish a version to real athletes by moving the `production` label, so
    that publishing is one deliberate act.
26. As Xuan, I want to undo a publish by moving the label back, so that a bad wording can be
    reverted in seconds.
27. As Lee, I want every prompt's history and diffs kept in Langfuse, so that I can see who
    changed what and when.
28. As Lee, I want the openers and the system prompts for extraction, summary, day notes, pantry
    photo, describe-meal, meal photo and saved-meal ingredients stored in Langfuse too, so that
    all of Vana's wording is in one place.
29. As Lee, I want the model for each call stored with its prompt, so that changing a model is a
    setting and not a deploy.
30. As Lee, I want each Trace linked to the prompt version that produced it, so that I can compare
    versions by their Scores and cost.
31. As an athlete, I want Vana to keep working from a built-in copy of her prompts when Langfuse
    cannot be reached, so that an outage there never stops her.
32. As Lee, I want a Turn that ran on the built-in copy to say so on its Trace, so that I know
    when the fallback was used.
33. As Lee, I want the Context block to stay built by code from the athlete's data, so that what
    Vana knows about an athlete is never edited by hand.
34. As Lee, I want prompt caching to keep working after the move, so that moving prompts does not
    raise what a Turn costs.

Judging Vana

35. As Lee, I want Langfuse's ready-made evaluators to flag conversations where the athlete pushes
    back, complains or asks for something out of scope, so that the conversations worth reading
    find us.
36. As Xuan, I want a Dietitian evaluator that answers whether a sports dietitian would say this
    to this athlete, so that nutrition quality is judged on every conversation.
37. As Xuan, I want to label 20 to 30 conversations pass or fail with a note, so that the
    Dietitian evaluator can be tuned to agree with me.
38. As Lee, I want to see how often the Dietitian evaluator agrees with Xuan, so that I know
    whether to trust it.
39. As Lee, I want a robotic check that flags a conversation reading like a state machine, so that
    the thing I care most about is measured.
40. As Lee, I want each evaluator to answer one yes-or-no question with its reason, so that a
    Score says what went wrong.
41. As Lee, I want Tool expectations checked by code, so that "must call this tool" is never left
    to a model's opinion.
42. As Lee, I want evaluators to run on Haiku 4.5, moving to Sonnet 5.5 only if agreement with
    Xuan is poor, so that judging costs as little as it can.
43. As Lee, I want evaluators to reach models through our Gateway, so that their spend is on the
    same bill and under the evals budget.
44. As Lee, I want new evaluators added only when review finds a failure worth measuring, so that
    we do not judge against guesses.

Reviewing with Xuan

45. As Xuan, I want a queue of flagged conversations in Langfuse, so that I review what matters
    without searching.
46. As Xuan, I want to see the whole conversation on the item I open, so that I can judge it
    without clicking through Steps.
47. As Xuan, I want to mark each one pass or fail and note the first thing that went wrong, so
    that failures can be grouped and named.
48. As Xuan, I want to write what Vana should have said, so that my correction is kept beside her
    reply.
49. As Lee, I want a reviewed failure added to the dataset from the Trace, so that it becomes a
    permanent test.
50. As Lee, I want the single queue Hobby allows to be deleted and remade between review passes
    with its Scores kept, so that we stay on the free plan until a limit truly blocks us.

Running experiments

51. As Lee, I want the 22 existing Scenarios carried into a Langfuse dataset, so that the first
    Experiment has something to run on.
52. As Xuan, I want to start an Experiment from Langfuse's Run button, so that I never open
    another app.
53. As Xuan, I want to choose the prompt version and the model in the Run settings, so that I can
    test a wording before I publish it.
54. As Lee, I want each Dataset item to start from a fresh copy of its Eval athlete, so that one
    run's writes never affect another's.
55. As Lee, I want the Simulated athlete to play its persona and goal against Vana for up to the
    item's turn limit, so that multi-turn behaviour is tested.
56. As Lee, I want each item's result to hold the transcript, the Tool calls and what Vana wrote
    to the athlete's data, so that evaluators judge what she did and not only what she said.
57. As Lee, I want Experiments compared side by side in Langfuse, so that I can see which
    conversations got better or worse after a change.
58. As Lee, I want the same Experiment startable from a terminal, so that a run does not depend
    on the hosted endpoint.
59. As Lee, I want the eval web app's screens, Judge, Mark, Rubric and Scenario store removed, so
    that there is one system and not two.
60. As Lee, I want describe-meal and meal photo compared on Sonnet 4.6 and Sonnet 5.5 in one
    Experiment before they switch, so that the cheaper model is adopted on evidence.

Hearing from athletes

61. As Lee, I want an evaluator to mark Turns where the athlete corrects Vana, repeats themselves
    or shows frustration, so that dissatisfaction is caught without any new button.
62. As Lee, I want a Score recorded when a plan is confirmed and when a Draft is abandoned, so
    that each planning conversation carries its outcome.
63. As Lee, I want Vana's existing feedback tool to record a Score on the conversation, so that
    volunteered opinions are visible beside the Trace.

Working with agents

64. As Lee, I want coding agents to read Traces and Scores through the Langfuse skill, CLI and
    MCP server, so that an agent can investigate a bad conversation itself.
65. As Lee, I want agents able to create and change prompts, datasets and evaluators, so that
    setup work is not done by hand in the UI.

## Implementation Decisions

Hosting and accounts

- Langfuse Cloud, US region, Hobby plan, one project. Environments separate dev, prod and
  experiment traffic inside it.
- Hobby's limits are accepted until one blocks work: 50k units a month with no overage, 30 days
  of history, two users (Lee and Xuan), one annotation queue, two alerts.
- Xuan has the Member role.
- Langfuse keys are function secrets on the dev and prod Supabase projects and environment
  variables on the eval repo's Vercel project. The secret key never ships in the Flutter app.
- A self-hosted Langfuse in Docker on Lee's Mac is a later sandbox and is not built here.

Runtime

- Vana stays on Supabase Edge Functions and on AI SDK 6.
- One shared tracing module is used by every AI call site. It owns the Langfuse span processor on
  an isolated tracer provider, a context manager so spans nest across awaits, immediate export,
  and a flush handed to the runtime's background-work hook after the response.
- The keys are passed to the module explicitly, because the SDK does not read Deno's environment.
- Sentry keeps the global telemetry setup it has today. The tracing module must not depend on it.
- If the SDK does not export from the deployed Edge runtime, the same module sends OTLP JSON by
  hand from the existing per-Turn finish hook, with the v4 ingestion header. Call sites do not
  change between the two routes.
- A tracing failure is caught and logged. It never changes a response, the Call log or the budget
  settlement.

Trace shape

- One Trace per Turn. The Conversation's id is the Session. The athlete's auth id is the user.
- One Generation per Step, one tool observation per Tool call, under one root observation per
  Turn named for the entry point.
- User, session, environment, release, conversation kind and tags are propagated to every
  observation, since Langfuse filters and evaluators match on observations.
- The root observation of a Turn carries what a reviewer or evaluator needs in one place: the
  athlete's message, Vana's reply, and the Tool calls in order.
- Background calls are their own Traces, tied to the same Session where a Conversation exists.
- Embedding calls are not exported.
- Meal photos are sent as image data so Langfuse stores them; expiring signed URLs are not used.
- The existing per-Turn trace callback remains the way the dev-only eval function receives a
  Turn's full detail.

Cost

- A small span hook copies the Gateway's reported charge for each model call onto that
  Generation's cost details before the span ends. Langfuse then skips its own price inference,
  so nothing is counted twice.
- The Call log remains the record that spend is enforced from. The Langfuse figure is for reading.
- The evals Gateway key gets a $20 monthly budget. Langfuse's evaluator connection and the
  experiment runner use that key. The Gateway's prepaid credit balance remains the overall stop.

Prompts

- Stored in Langfuse, one prompt each: the persona's sections, the openers, and the system prompts
  for extraction, summary, day notes, pantry photo, describe-meal, meal photo and saved-meal
  ingredients. Each prompt's config holds the model for that call.
- Not stored in Langfuse: the Context block builder, the screen line, Tool definitions and Tool
  descriptions, and the output schemas.
- One prompt-source module resolves a prompt by name. The dev project asks for the `latest`
  label and the prod project for `production`. There is no `staging` label and no gate before
  publishing.
- A copy of every prompt is bundled in code and used when the fetch fails or times out. The Trace
  records that the fallback ran.
- Fetched prompts are cached in the function instance for a short time, so most Turns make no
  fetch.
- Each Generation is linked to the prompt name and version it used.
- The order that prompt caching depends on (Tools, persona, Context block, messages) and the
  cache markers do not change.
- The environment variables that pick models today become the bundled defaults only.
- The dev-only eval function's persona and model overrides are replaced by choosing a prompt
  label or version and a model in the Run settings.

Models

- No Opus model is used by any call, evaluator or experiment.
- Vana chat, background calls, the Simulated athlete and evaluators use Haiku 4.5.
- Evaluators move to Sonnet 5.5 only if their agreement with Xuan's labels is poor.
- Describe-meal and meal photo move from Sonnet 4.6 to Sonnet 5.5 after one Experiment shows
  quality holds.

Evaluators and review

- Langfuse's LLM connection points at the Gateway's OpenAI-compatible endpoint with the evals
  key.
- Evaluators target observations, never whole traces; trace-level evaluators stop on Cloud on
  2026-11-16.
- Live traffic: the ready-made user-signal evaluators, plus one conversation-signal evaluator
  for corrections, repeats and frustration, run on the Turn's root observation.
- Custom evaluators from day one: the Dietitian evaluator and the robotic check. Each returns
  yes or no with its reason. Their prompts are kept in Langfuse.
- The Dietitian evaluator is tuned against 20 to 30 conversations Xuan labels pass or fail, and
  is accepted when Langfuse's agreement report shows it matches her.
- Tool expectations are code evaluators reading the Tool calls on the experiment item's output.
- The old Rubric, its ten dimensions, the 0 to 100 Mark and the round pass bar are not carried
  over.
- One annotation queue at a time. Its score configs are a free-text note on what went wrong and a
  pass or fail. It is deleted before the next is made; its Scores remain.

Datasets and the Run endpoint

- The 22 Scenarios become items in one Langfuse dataset. An item's input holds the Eval athlete
  it starts from (by reference), the Simulated athlete's persona and goal, the opening turn, any
  scripted turns and the turn limit. Its expected output holds the Tool expectations.
- `../mealvana_eval` is reduced to one endpoint on Vercel that Langfuse's Custom Experiment
  button calls, plus the same runner startable from a terminal.
- The endpoint checks the request's signature, answers at once, and keeps working in the
  background. Langfuse waits 20 seconds and does not retry.
- For each item the runner copies the Eval athlete, plays the Simulated athlete against Vana
  through the dev-only eval function, and returns the transcript, the Tool calls and a summary of
  what Vana wrote as the item's output.
- The Run settings carry the prompt label or version and the model. Run overrides from the
  uncommitted eval-v2 work are kept only where those settings need them; the rest is discarded.
- Each item is one Trace in the experiment environment. Evaluators targeting Experiments score
  it.
- Eval athletes and the dev-only eval function stay in this repo's dev project.
- Removed from the eval repo: its screens, the Judge, the Rubric, Marks, the Scenario store, and
  unbuilt tickets 09 to 11.

Athlete signals

- A Score is written server-side when a plan is confirmed and when a Draft is abandoned, against
  the planning Conversation's Session.
- The existing feedback tool also writes a Score against its Conversation.
- The Flutter app does not talk to Langfuse.

Privacy

- Before prod tracing is turned on, the privacy policy and the App Store privacy details name
  Langfuse as a processor of conversation content, profile data, food logs and meal photos.

Order of work

1. One dev function traced; the Trace arrives and its cost equals the Call log's.
2. Every call site on dev traced, with user, session and true cost.
3. Prompts moved into Langfuse.
4. The eval repo reduced to the Run endpoint; the Scenarios carried into a dataset.
5. Flag evaluators, Dietitian evaluator, robotic check, plan-outcome Scores, first queue.
6. Privacy documents updated; prod tracing on.

## Testing Decisions

A good test here drives a whole Turn or a whole Run through the real entry point and asserts on
what leaves the system: the spans handed to the exporter, the prompt requested, the response the
athlete gets, the rows written. It does not assert on how the tracing module is built.

Seam 1: `runChat` with the AI SDK's mock model and the fake database (this repo). Two new fakes
sit at the edges: a span collector in place of Langfuse's exporter and a fake prompt source in
place of its prompt API. Tests assert that:

- a Turn yields one Trace carrying the athlete, the Conversation as Session, one Generation per
  Step and one observation per Tool call;
- each Generation's cost equals the Gateway charge the mock reported, the same number the Call
  log stores;
- persona text and model come from the prompt source, asked for by `latest` on dev and
  `production` on prod;
- a failing prompt source still produces a complete Turn on the bundled copy, marked as fallback;
- a failing exporter changes neither the reply nor the Call log nor the budget settlement;
- embeddings produce no exported span;
- the cache markers and prompt order are unchanged.

Describe-meal, meal photo, day notes, extraction and saved-meal ingredients get the tracing, cost
and prompt assertions through their existing handler tests. Prior art: `run_overrides`,
`prompt_cache`, `call_log`, `extract` and `day_notes` tests, and the in-process serve harness.

Seam 2: the Run endpoint (eval repo), with Langfuse's client and Vana faked. Tests assert that:

- a correctly signed request is accepted at once and a bad signature refused;
- each Dataset item gets a fresh Eval athlete copy;
- the Simulated athlete stops at the item's turn limit;
- the item's output holds the transcript, the Tool calls and what Vana wrote;
- the Run settings' prompt version and model reach Vana.

Prior art: the eval repo's run-engine tests.

Deployed check on dev, by hand at the end of each step of the order of work: one real Turn from
the dev app appears in Langfuse, its cost equals that Turn's Call log row, and its prompt version
is linked. Local function serving drops the background flush, so only the deployed function
proves it. Before prod is turned on, the same check is repeated with a meal photo.

Evaluators are not tested in code. An evaluator is accepted on its agreement with Xuan's labels,
which Langfuse reports.

## Out of Scope

- Moving Vana to Vercel Functions or to AI SDK 7.
- An orchestrator with subagents. It gets its own grilling once tracing exists, then an
  Experiment compares it with today's single Vana.
- A self-hosted Langfuse, in Docker or elsewhere, and any syncing between it and Cloud.
- Thumbs up or down on Vana's replies and a "report this reply" control. Thumbs down with a
  reason picker is a later ticket.
- Scores for planned meals being logged later, or for swapping a meal.
- Changes to Wiredash or shake-to-report.
- Any change to the Call log, Wallet, Monthly budget or the daily cost alert.
- Moving Tool descriptions or output schemas into Langfuse.
- Experiments gating merges or deploys in CI.
- A `staging` label, protected labels, or any approval step before publishing a prompt.
- Dr. Mitchell's review of the dietitian criteria.
- Tracing the changelog script.
- Upgrading from Hobby. It happens when a limit blocks work, not before.

## Further Notes

- Langfuse Cloud accepts only its v4 ingestion from 2026-11-16. Everything here already targets
  it; nothing should be built on the legacy ingestion API or on trace-level evaluators.
- Langfuse does not officially support Supabase Edge Functions. In a local Deno probe the SDK
  loaded, nested spans and propagated user and session. The deployed runtime is the unproven
  part, which is why step 1 is a single function.
- In probe calls the Gateway's charge equalled Langfuse's list-price estimate to 8 decimals, so
  if the cost hook proves fragile, inferred cost is an acceptable stand-in.
- The span hook that sets cost uses an OpenTelemetry callback marked experimental; pin the
  OpenTelemetry version.
- A Turn is roughly 10 to 15 units against 50k a month. Evaluator runs and experiments use units
  too. If the cap gets close, the first lever is what is traced, the second is Core at $29.
- Langfuse shows no progress and no cancel for a Custom Experiment, and the data summary appears
  as raw JSON on the item.
- The Langfuse skill, CLI and MCP server are installed; keys are in `secrets/langfuse.env`.
- The eval repo's own `CONTEXT.md` still holds the retired words and is rewritten in step 4. The
  eval-v2 spec's "Langfuse optional later" line is superseded by this spec.
- The earlier notes in `docs/langfuse/` (README, research, alternatives-and-costs) argued for
  keeping the bespoke system. Lee overruled them on 2026-09-30.

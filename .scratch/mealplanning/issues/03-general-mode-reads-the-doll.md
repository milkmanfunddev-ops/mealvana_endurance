# 03: General mode reads the Doll

**What to build:** An athlete opens Vana from the Plan tab avatar and asks "what's my workout tomorrow" or "what did I log today". She answers from what she already knows, without a tool call failing or a guess. Both conversation kinds receive the same context block every turn, extended with a LIKES line from Meal feedback (thumbed-up and thumbed-down Meals by name) and a GOALS line from the onboarding survey. Long conversations stay coherent: each turn replays at most the last 20 messages, and when the cap bites the conversation's episode sentence is prepended once. This ticket also creates the personalization eval runner beside the existing vana-eval scripts, with these as its first cases and token cost recorded per case.

**Blocked by:** 02 Vana test harness

**Status:** built, live evals not run (2026-09-09)

- [x] General and planning kinds produce the same context block for the same fixture rows, proven at the server seam
- [x] LIKES line lists thumbed Meals by name and stance; absent thumbs reads "none"
- [x] GOALS line carries the onboarding survey's goals; absent survey reads "none"
- [x] History cap: 21 messages in, 20 replayed; 10 messages in, nothing prepended. **The episode prepend is built and tested but cannot fire yet — see below.**
- [x] Personalization eval runner exists, refuses to run against anything but dev, records input and output tokens per case
- [ ] Live eval: "what's my workout tomorrow" and "what did I log today" answer correctly in general mode for the eval user
- [ ] Live eval: a fresh user with an empty Doll still gets a sensible opener

**Notes (2026-09-09).** `systemPrompt` in chat.ts now builds one block for both kinds; only the
persona above it differs. `buildAthleteContext` reads `meal_feedback` (resolved to names through
`meal_library` and `saved_meals`, two follow-up reads rather than a PostgREST embed) and
`onboarding_surveys.goals`. `capHistory` and `HISTORY_CAP` are pure and exported;
`episodeFor(v, conversationId)` reads the episode Memory ticket 06 will write, and returns null
until then. Seam tests: `tests/vana/doll.test.ts`.

`GENERAL_PROMPT` had to be rewritten — it opened with "NOTHING IS PRELOADED. You start with only
the athlete's name and today's date", which is now false and would have had the model re-fetch
lines it can read. The prototype's copy of persona.ts still carries the old text on purpose: that
repo has no Doll, so the two prompts are deliberately apart until it gets one.

Not done: the two live eval lines. The runner is `scripts/vana-eval/personalization.ts` (dev-only
by project ref, `--list` / `--only`, per-case input and output tokens), with cases for this ticket
and for 01, 05, 06 and 07. Running it bills real model spend against dev and writes real rows, so
it is a by-hand step.

**Known gap found in review (2026-09-09): the episode prepend never fires.** `capHistory` asks for
the episode of the conversation it is capping, but an episode is only written by lazy extraction,
and extraction only ever reads a conversation the athlete is *not* in (`pendingReadBack` excludes
the one being opened). A conversation still in progress therefore never has an episode, so past
twenty messages the front is dropped with nothing put in its place — the outcome the mechanism
exists to prevent. `capHistory` itself is correct and tested; what is missing is a writer.

Closing it means writing an episode for a long, still-open conversation. The cheapest shape: when
the cap first bites, run the existing extractor's episode half over the messages about to be
dropped, in the background, and let the next turn pick it up. That is one Haiku call per
conversation that crosses twenty messages. It is a real addition rather than a fix, so it is Lee's
call, and the code carries a comment pointing here.


# 02: Vana's persona and openers come from Langfuse

**What to build:** Vana's persona sections and openers are stored in Langfuse, and a chat Turn is worded from them. This builds the one prompt source every later prompt uses. The dev project asks for the `latest` label and the prod project for `production`; there is no `staging` label and no gate. A copy of each prompt is bundled in code and used when the fetch fails or times out. A repeatable script creates the prompts in Langfuse from the current text and puts `production` on the first version.

**Blocked by:** None (can start immediately)

**Owner:** `mealvana_endurance` agent.

**Status:** done

- [x] The persona sections and openers exist in Langfuse with the text the code has today, each with a `production` label
- [x] A Turn through the real `runChat` with a fake prompt source uses the source's text, asked for by `latest` on dev and `production` on prod
- [x] When the prompt source fails or times out the Turn completes on the bundled copy and records that the fallback ran
- [x] Fetched prompts are cached in the function instance so most Turns make no fetch
- [x] The prompt order (Tools, persona, Context block, messages) and the cache markers are unchanged; the prompt-cache tests still pass
- [x] Chip labels and any other values the persona interpolates still arrive
- [x] Deployed check on dev: editing the persona in Langfuse changes Vana's next reply on the dev app with no deploy

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

## Comments

2026-09-30. Prompt source: `supabase/functions/_shared/langfuse/prompts.ts`. Bundled copy and the wording builder:
`_shared/vana/persona.ts` (`PROMPT_TEMPLATES`, `wordingFrom`). Tests: `tests/vana/langfuse_prompts.test.ts`. Seed:
`scripts/langfuse/seed_prompts.ts`; it only creates a prompt that does not exist, so a second run never overwrites an
edit made in Langfuse.

Twelve text prompts, each created as version 1 with `production` and `latest`: `vana/persona/core`, `write-rules`,
`planning`, `general`, `general-after-writes`; `vana/opener/make-it-theirs`, `meal-planning`, `general`, `new-plan`,
`check-in`, `debrief`, `situation`.

Prompts are templates. Chip labels are `{{chip_…}}` variables filled from `chip-labels.ts`, so a label changed in code
reaches the prompt whichever copy runs. Openers take `{{make_it_theirs}}`; the new-plan opener takes `{{plan_opener}}`;
check-in, debrief and situation take the athlete's values (`{{plan_id}}`, `{{meals}}`, `{{said}}` and so on). Deleting a
variable from a prompt in Langfuse drops that value from what Vana reads.

Left in code, deliberately: the two moment openers (pre-workout, recovery). Their sentences branch on the session's
timing; they take only `make-it-theirs` from Langfuse. `NEW_PLAN_STANDING` also stays: it is part of the Context
message. Say if either should move.

A Turn resolves all twelve by name: a cold instance makes twelve parallel fetches (1.5 s timeout), then holds them for
60 s and refreshes in the background, so a saved edit reaches a warm instance on the second Turn after a minute. The
Trace carries `promptSource`: `langfuse`, `fallback` (a fetch failed and the bundled copy ran) or `bundled` (no keys).

Deployed check on dev: version 2 of `vana/persona/general-after-writes` added a line; with no deploy the next two
replies ended in the word it asked for. Version 3 restores the text of version 1. `production` is still on version 1.

Not done here: the chat model is still `VANA_CHAT_MODEL`. The spec puts each call's model in its prompt's config, but a
chat Turn is built from several prompts and no ticket says which one carries the model. Needs a ruling.

`jade-chat` and `vana-eval` run the old bundle on dev until they are next deployed (ticket 08).

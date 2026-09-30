# 02: Vana's persona and openers come from Langfuse

**What to build:** Vana's persona sections and openers are stored in Langfuse, and a chat Turn is worded from them. This builds the one prompt source every later prompt uses. The dev project asks for the `latest` label and the prod project for `production`; there is no `staging` label and no gate. A copy of each prompt is bundled in code and used when the fetch fails or times out. A repeatable script creates the prompts in Langfuse from the current text and puts `production` on the first version.

**Blocked by:** None (can start immediately)

**Owner:** `mealvana_endurance` agent.

**Status:** ready-for-agent

- [ ] The persona sections and openers exist in Langfuse with the text the code has today, each with a `production` label
- [ ] A Turn through the real `runChat` with a fake prompt source uses the source's text, asked for by `latest` on dev and `production` on prod
- [ ] When the prompt source fails or times out the Turn completes on the bundled copy and records that the fallback ran
- [ ] Fetched prompts are cached in the function instance so most Turns make no fetch
- [ ] The prompt order (Tools, persona, Context block, messages) and the cache markers are unchanged; the prompt-cache tests still pass
- [ ] Chip labels and any other values the persona interpolates still arrive
- [ ] Deployed check on dev: editing the persona in Langfuse changes Vana's next reply on the dev app with no deploy

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

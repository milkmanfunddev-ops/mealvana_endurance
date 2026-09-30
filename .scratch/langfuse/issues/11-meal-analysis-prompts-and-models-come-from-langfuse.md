# 11: Meal analysis prompts and models come from Langfuse

**What to build:** The describe-meal and meal photo system prompts are stored in Langfuse with their model in the prompt's config, resolved through the prompt source with the bundled fallback.

**Blocked by:** 02

**Owner:** `mealvana_endurance` agent.

**Status:** done (2026-09-30)

- [x] Both prompts exist in Langfuse with today's text and a `production` label
- [x] Each prompt's config names its model; the environment variables become the bundled default only
- [x] A fake prompt source's text and model are what the call uses
- [x] The output schemas stay in code
- [x] The bundled copy is used when the source fails

2026-09-30. `vana/meal/describe` and `vana/meal/photo` are in Langfuse, version 1, `production` and `latest`, text equal to the bundled copy, config model `anthropic/claude-sonnet-4.6`. On dev both calls ran with `promptSource: langfuse`. A config naming an Opus model is refused and the bundled model runs.

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

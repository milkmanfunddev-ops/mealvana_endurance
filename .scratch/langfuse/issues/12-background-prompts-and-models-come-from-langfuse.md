# 12: Background prompts and models come from Langfuse

**What to build:** The system prompts for extraction, summary, day notes, pantry photo and saved-meal ingredients are stored in Langfuse with their model in each prompt's config.

**Blocked by:** 02

**Owner:** `mealvana_endurance` agent.

**Status:** done (2026-09-30)

- [x] All five prompts exist in Langfuse with today's text and a `production` label
- [x] Each prompt's config names its model; the environment variables become the bundled default only
- [x] A fake prompt source's text and model are what each call uses
- [x] The Context block builder and the output schemas stay in code
- [x] The bundled copy is used when the source fails

2026-09-30. `vana/background/extraction`, `summary`, `day-notes`, `pantry-photo` and `saved-meal-ingredients` are in Langfuse, version 1, `production` and `latest`, text equal to the bundled copy, config model `anthropic/claude-haiku-4.5`. The pantry photo's instruction is a text part after the photo, not a system message; it stays there. `scripts/langfuse/seed_prompts.ts` creates all seven call prompts and leaves existing ones alone.

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

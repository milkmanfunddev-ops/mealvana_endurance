# 12: Background prompts and models come from Langfuse

**What to build:** The system prompts for extraction, summary, day notes, pantry photo and saved-meal ingredients are stored in Langfuse with their model in each prompt's config.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] All five prompts exist in Langfuse with today's text and a `production` label
- [ ] Each prompt's config names its model; the environment variables become the bundled default only
- [ ] A fake prompt source's text and model are what each call uses
- [ ] The Context block builder and the output schemas stay in code
- [ ] The bundled copy is used when the source fails

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

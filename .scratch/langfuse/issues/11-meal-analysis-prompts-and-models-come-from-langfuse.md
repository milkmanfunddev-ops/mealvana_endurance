# 11: Meal analysis prompts and models come from Langfuse

**What to build:** The describe-meal and meal photo system prompts are stored in Langfuse with their model in the prompt's config, resolved through the prompt source with the bundled fallback.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Both prompts exist in Langfuse with today's text and a `production` label
- [ ] Each prompt's config names its model; the environment variables become the bundled default only
- [ ] A fake prompt source's text and model are what the call uses
- [ ] The output schemas stay in code
- [ ] The bundled copy is used when the source fails

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

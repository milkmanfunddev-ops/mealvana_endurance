# 17: The Run settings choose a prompt version

**What to build:** When starting an Experiment, the Run settings name a prompt label or version, and Vana runs the items on that wording, so an edit can be tested before it is published. This replaces the dev-only eval function's persona overrides.

**Blocked by:** 02, 04

**Owner:** `../mealvana_eval` agent. The Run settings half is built there. The dev-only eval function's half (accepting a prompt label or version in place of the persona override) lives in `mealvana_endurance` and is done by that repo's agent, as the last step of this ticket.

**Status:** ready-for-agent

- [ ] A label or version in the Run settings is the persona Vana runs on for every item
- [ ] With none given, the run uses `latest`
- [ ] The old persona override is removed
- [ ] The Experiment records which prompt version it ran

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

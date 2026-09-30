# 06: The privacy documents name Langfuse

**What to build:** The privacy policy and the App Store privacy details say that Langfuse processes conversation content, profile data, food logs and meal photos, so that prod tracing can be turned on. An agent drafts the wording; Lee approves it before anything is published.

**Blocked by:** None (can start immediately)

**Owner:** `mealvana_endurance` agent.

**Status:** ready-for-agent

- [ ] The privacy documents in the repo name Langfuse, what it receives and why
- [ ] The App Store privacy details are checked against what is sent and any change needed is listed
- [ ] Lee has approved the wording
- [ ] Onboarding body copy is not edited

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

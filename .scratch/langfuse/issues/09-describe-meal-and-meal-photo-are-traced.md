# 09: Describe-meal and meal photo are traced

**What to build:** Describing a meal or photographing one on the dev app sends a Trace with its true cost, and the photo is visible on the Trace.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Each call sends one Trace named for its entry point, with the athlete as user
- [ ] Cost equals the Call log's figure for that call
- [ ] The meal photo is stored by Langfuse and visible on the Trace; no expiring signed URL is sent
- [ ] A tracing failure does not change the response or the budget settlement
- [ ] Assertions are added to the existing handler tests
- [ ] Deployed check on dev with a real photo, staying under Langfuse's 5 MB request limit

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

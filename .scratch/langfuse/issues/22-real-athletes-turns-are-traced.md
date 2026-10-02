# 22: Real athletes' Turns are traced

**What to build:** Turns from real athletes appear in Langfuse in the `production` environment. Lead-run, on Lee's go, following the deploy playbook.

**Blocked by:** 06, 08, 09, 10, 11, 12, 18

**Owner:** `mealvana_endurance` lead, on Lee's go.

**Status:** lead-run, waits for Lee's go

- [x] The privacy documents from ticket 06 are published (website policy, 2026-10-02; App Store label waits for the next release)
- [ ] Every prompt has a `production` label on the intended version
- [ ] Langfuse keys are function secrets on the prod project
- [ ] Deployed check on prod: one real Turn and one meal photo appear in Langfuse, and each cost equals its Call log row
- [ ] Replies are no slower than before
- [ ] Embeddings are absent; the ticket records units used per Turn against the 50k monthly allowance

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

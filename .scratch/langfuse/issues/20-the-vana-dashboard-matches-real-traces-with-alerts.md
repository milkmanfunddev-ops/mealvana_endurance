# 20: The Vana dashboard matches real traces, with alerts

**What to build:** The "Vana" dashboard made on 2026-09-30 shows real numbers, and two alerts warn about spend and errors. The dashboard and its ten widgets were created before any trace existed, so each is checked against real data and corrected.

**Blocked by:** 08, 09, 10

**Owner:** `mealvana_endurance` agent.

**Status:** ready-for-agent

- [ ] Every widget shows data from dev traces and its breakdown reads sensibly
- [ ] Spend by entry point uses the real Trace names
- [ ] Top athletes by spend shows athletes, not blanks
- [ ] The two Hobby alerts are set: daily spend and error rate
- [ ] Widgets and dashboard are changed through the API or CLI so the setup is repeatable

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

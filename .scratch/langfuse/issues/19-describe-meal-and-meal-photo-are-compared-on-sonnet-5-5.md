# 19: Describe-meal and meal photo are compared on Sonnet 5.5

**What to build:** One Experiment runs describe-meal and meal photo over a set of real meals on Sonnet 4.6 and on Sonnet 5.5, so the cheaper model is adopted on evidence. The switch is Lee's call on the result.

**Blocked by:** 11

**Owner:** `../mealvana_eval` agent. Touches no app code until Lee rules: a dataset and an Experiment in Langfuse.

**Status:** ready-for-agent

- [ ] A dataset of real meal descriptions and photos from dev exists, with the macros a person accepts as right
- [ ] Both models are run over it and compared side by side in Langfuse
- [ ] The comparison reports accuracy against the accepted macros and cost per call
- [ ] Lee has ruled; if yes, the model in each prompt's config is changed to Sonnet 5.5

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

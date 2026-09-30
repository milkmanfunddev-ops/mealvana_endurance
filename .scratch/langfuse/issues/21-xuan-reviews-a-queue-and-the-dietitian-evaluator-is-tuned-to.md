# 21: Xuan reviews a queue and the Dietitian evaluator is tuned to her

**What to build:** Xuan opens one queue of flagged conversations in Langfuse, marks each pass or fail and notes the first thing that went wrong. Her labels are then used to tune the Dietitian evaluator until it agrees with her.

**Blocked by:** 07, 15, 16

**Owner:** Lee (with Xuan where named).

**Status:** for Lee and Xuan

- [ ] One annotation queue exists with the `review_pass_fail` and `review_note` score configs
- [ ] The whole conversation is readable on the item Xuan opens
- [ ] Xuan has labelled 20 to 30 conversations
- [ ] The Dietitian evaluator's prompt is adjusted until Langfuse's agreement report shows it matches her labels; the agreement figure is recorded under Comments
- [ ] If agreement stays poor on Haiku 4.5 the evaluator moves to Sonnet 5.5
- [ ] Failures Xuan found are added to the dataset
- [ ] Hobby allows one queue: it is deleted before another is made, and its Scores remain

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

# 16: Flag evaluators run on dev conversations

**What to build:** Each new chat Turn on dev is scored by Langfuse's ready-made user-signal evaluators and by one conversation-signal evaluator that catches the athlete correcting Vana, repeating themselves or showing frustration, so the conversations worth reading can be found by filter.

**Blocked by:** 05, 08

**Owner:** `mealvana_endurance` agent.

**Status:** done (2026-09-30)

- [x] The evaluators target the `vana-turn` root observation in the `dev` environment, never whole traces
- [x] Experiment and evaluator traffic is excluded
- [x] A dev Turn where the athlete pushes back is flagged; an ordinary one is not
- [x] Evaluators run on Haiku 4.5 through the evals key
- [x] The ticket records the units one scored Turn uses

**Shared contracts** (fixed so tickets can be built in parallel; change one only by changing every ticket that cites it):

- *Turn root.* A chat Turn's root observation is named `vana-turn`. Its input is the athlete's message (or the opener's hidden prompt), its output is Vana's reply, and its metadata lists the Tool calls in order. It carries the athlete as user, the Conversation as Session, the environment (`dev`, `production` or `experiment`), the release and the conversation kind.
- *Dataset item.* Input: `evalAthlete` (a reference, never the data), `persona`, `goal`, `openingTurn`, `scriptedTurns` (may be empty), `maxTurns`. Expected output: `toolExpectations`.
- *Experiment item output.* `transcript` (every turn in order), `toolCalls` (name and arguments, in order), `writes` (a summary of what Vana changed in the Eval athlete copy).

2026-09-30. Set up by `scripts/langfuse/setup_flag_evaluators.ts` (repeatable; leaves what exists alone) and checked on dev:
- Four evaluators under one rule, "Flag dev chat Turns": `user_disagreement`, `user_distress` and `all_caps` (Langfuse's ready-made ones, copied unedited into `scripts/langfuse/managed_flag_templates.json`) and `conversation_signal` (ours: correction, repeat or frustration). The score `all_caps` writes is named `All CAPS` by its own code.
- The rule matches the root observation of a `vana-turn` Trace, environment `dev`, tag `message`. Openers are left out: their input is a hidden prompt, not the athlete's words. Experiments are in `experiment` and the evaluators' own calls in `langfuse-llm-as-a-judge` and `langfuse-code-eval`, so neither matches.
- The root's input is the athlete's message alone, so a Turn's root now lists the six messages before it (about three exchanges) as `history` metadata (each cut at 600 characters). The evaluators read that as the conversation history. `vana-chat`, `jade-chat` and `vana-eval` are deployed to dev with it.
- Checked: "No, that's not what I asked. I said quick... You keep getting this wrong." scored `user_disagreement` true and `conversation_signal` true ("Correction: ..."); the ordinary messages before and after it scored false on all four. `user_distress` was false on all of them, by its own rule that annoyance is not distress.
- Model: `vercel-ai-gateway / anthropic/claude-haiku-4.5`, set on each evaluator, which is the connection holding the evals key.
- Units for one scored Turn: 11. Seven observations (three judge calls at two each, one code run) and four Scores. The three judge calls read about 2,700 tokens together, roughly $0.003 on Haiku 4.5 (an estimate: Langfuse shows no cost for them because the dotted model name matches none of its prices).

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

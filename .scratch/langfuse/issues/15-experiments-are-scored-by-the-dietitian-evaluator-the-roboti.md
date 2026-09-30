# 15: Experiments are scored by the Dietitian evaluator, the robotic check and Tool expectations

**What to build:** Every item in an Experiment gets a yes-or-no answer with its reason from the Dietitian evaluator and from the robotic check, and a code check for each Tool expectation. The Dietitian evaluator starts from a first-draft prompt; ticket 21 tunes it to Xuan.

**Blocked by:** 03, 04, 05

**Owner:** `../mealvana_eval` agent. Touches no app code: evaluators live in Langfuse.

**Status:** owned by the `../mealvana_eval` agent (it marks this `done` when finished)

- [ ] The Dietitian evaluator and the robotic check exist in Langfuse, target Experiments, run on Haiku 4.5 and return yes or no with a reason
- [ ] Their Scores use the `dietitian` and `robotic` score configs
- [ ] Tool expectations are code evaluators reading `toolCalls` on the item's output against the item's expected output
- [ ] An Experiment on the real dataset shows all three kinds of Score on every item
- [ ] The old Rubric's other dimensions are not carried over

**Shared contracts** (fixed so tickets can be built in parallel; change one only by changing every ticket that cites it):

- *Turn root.* A chat Turn's root observation is named `vana-turn`. Its input is the athlete's message (or the opener's hidden prompt), its output is Vana's reply, and its metadata lists the Tool calls in order. It carries the athlete as user, the Conversation as Session, the environment (`dev`, `production` or `experiment`), the release and the conversation kind.
- *Dataset item.* Input: `evalAthlete` (a reference, never the data), `persona`, `goal`, `openingTurn`, `scriptedTurns` (may be empty), `maxTurns`. Expected output: `toolExpectations`.
- *Experiment item output.* `transcript` (every turn in order), `toolCalls` (name and arguments, in order), `writes` (a summary of what Vana changed in the Eval athlete copy).

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

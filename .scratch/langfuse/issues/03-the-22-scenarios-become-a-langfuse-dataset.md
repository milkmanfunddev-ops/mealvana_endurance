# 03: The 22 Scenarios become a Langfuse dataset

**What to build:** The Scenarios written for the earlier judging work become items in one Langfuse dataset, so the first Experiment has something to run on. A repeatable script reads them and creates or updates the items by a stable id.

**Blocked by:** None (can start immediately)

**Owner:** `../mealvana_eval` agent. Touches no app code: a script plus Langfuse. The Scenario files it reads are in `mealvana_endurance/eval/scenarios`.

**Status:** owned by the `../mealvana_eval` agent (it marks this `done` when finished)

- [ ] One dataset exists in Langfuse holding all 22 Scenarios as Dataset items in the contract shape
- [ ] Each item's `evalAthlete` names an Eval athlete that exists in the dev project
- [ ] Tool expectations are carried into the item's expected output
- [ ] Running the script twice changes nothing the second time
- [ ] Scenarios that also exist in the eval app's database are not duplicated

**Shared contracts** (fixed so tickets can be built in parallel; change one only by changing every ticket that cites it):

- *Turn root.* A chat Turn's root observation is named `vana-turn`. Its input is the athlete's message (or the opener's hidden prompt), its output is Vana's reply, and its metadata lists the Tool calls in order. It carries the athlete as user, the Conversation as Session, the environment (`dev`, `production` or `experiment`), the release and the conversation kind.
- *Dataset item.* Input: `evalAthlete` (a reference, never the data), `persona`, `goal`, `openingTurn`, `scriptedTurns` (may be empty), `maxTurns`. Expected output: `toolExpectations`.
- *Experiment item output.* `transcript` (every turn in order), `toolCalls` (name and arguments, in order), `writes` (a summary of what Vana changed in the Eval athlete copy).

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

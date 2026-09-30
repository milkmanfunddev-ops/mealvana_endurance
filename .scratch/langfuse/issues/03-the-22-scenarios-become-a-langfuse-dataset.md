# 03: The 22 Scenarios become a Langfuse dataset

**What to build:** The Scenarios written for the earlier judging work become items in one Langfuse dataset, so the first Experiment has something to run on. A repeatable script reads them and creates or updates the items by a stable id.

**Blocked by:** None (can start immediately)

**Owner:** `../mealvana_eval` agent. Touches no app code: a script plus Langfuse. The Scenario files it reads are in `mealvana_endurance/eval/scenarios`.

**Status:** done (eval agent, 2026-09-30)

- [x] One dataset exists in Langfuse holding all 22 Scenarios as Dataset items in the contract shape
- [x] Each item's `evalAthlete` names an Eval athlete that exists in the dev project
- [x] Tool expectations are carried into the item's expected output
- [x] Running the script twice changes nothing the second time
- [x] Scenarios that also exist in the eval app's database are not duplicated

**Shared contracts** (fixed so tickets can be built in parallel; change one only by changing every ticket that cites it):

- *Turn root.* A chat Turn's root observation is named `vana-turn`. Its input is the athlete's message (or the opener's hidden prompt), its output is Vana's reply, and its metadata lists the Tool calls in order. It carries the athlete as user, the Conversation as Session, the environment (`dev`, `production` or `experiment`), the release and the conversation kind.
- *Dataset item.* Input: `evalAthlete` (a reference, never the data), `persona`, `goal`, `openingTurn`, `scriptedTurns` (may be empty), `maxTurns`. Expected output: `toolExpectations`.
- *Experiment item output.* `transcript` (every turn in order), `toolCalls` (name and arguments, in order), `writes` (a summary of what Vana changed in the Eval athlete copy).

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

## Comments

2026-09-30, eval agent. Script: `mealvana_eval/scripts/langfuse-dataset.ts` (commit in that repo). Dataset `vana-scenarios` (id `cmuo3vdvc01x6ad0c0mg659ju`), 22 items `vana-scenario-s01` to `s22`.

- Item shape: `input` = `{evalAthlete, persona, goal, openingTurn, scriptedTurns, maxTurns}`. `openingTurn` is null only for S22, meaning Vana speaks first. `scriptedTurns` holds the pinned follow-ups (only S08 has one). `maxTurns` is 8, the eval app's default, because the files leave it open. `expectedOutput` = `{toolExpectations}`. Nothing else goes in `input`; the chat kind (`meal_planning` or `general`), the Scenario title, its source file and the old Judge notes (required beats, Examiner notes) go in `metadata` as `chatKind`, `scenario`, `source` and `notes`. Evaluators can read those through `experiment_item_metadata`.
- `evalAthlete` is an Eval athlete id, `69e42ac6-8578-48d3-9890-ddbec82e0b24`, "Dev login (tracer)". Every file names `judging-1` as its account, that account is the eval admin login, and this Eval athlete is its snapshot from 2026-09-28. The script reads it back from dev's `eval.athletes` before it writes anything.
- Tool expectations: only the eval app's scripted tracer copy of S06 had any (must call `suggestMeals`, must not call `recordDebrief`, at most one `suggestMeals`). They are on item `s06`'s expected output. The other 21 carry an empty list.
- No duplicates: the eval app's database held these 22 plus that tracer copy of S06. The copy did not become a 23rd item.
- Twice: the first run created the dataset and 22 items. The second printed `0 written, 22 unchanged`: items whose content already matches are not posted. Read back `vana-scenario-s06` with the CLI and got status ACTIVE, the input above and the three expectations.

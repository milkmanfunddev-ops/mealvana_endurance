# Drawing brief (ticket 07, 2026-09-14)

You draw one small diagram per decision card named in your list. Repo root: /Users/leemartin/development/mealvana_endurance. Use absolute paths.

1. Read the spec format at the top of `docs/ssot/decisions/_page/diagram.mjs` (flow and timeline).
2. For each id, read its card: `grep -n -A30 "^## <id> " .scratch/mealplanning/decisions.md docs/ssot/decisions/mealplanning.md`. Read Question, Decision, Details, Why.
3. Write `.scratch/ssot/diagrams/<id>.json`: a diagram of the MECHANISM the decision describes (what feeds what, what happens when, which path is taken), not a restatement of the title. Then exactly one worked example with real numbers taken from the card (`example`: one to three lines, each under 60 characters). If the card has no numbers, use a concrete instance (a named athlete, a date, a count) that follows from the decision.
4. Draw it: `node docs/ssot/decisions/_page/sync.mjs draw .scratch/ssot/diagrams/<id>.json docs/ssot/decisions/images/mealplanning/<id>.svg`. A non-zero exit means fix the spec.
5. Rules: `flow` rows hold at most three boxes; a label line is at most 26 characters (use `\n` for a second or third line); `timeline` labels at most 40 characters per line; a title of at most 40 characters; tones only where they mean something (ok = allowed/kept, no = refused/never, pending = waits, accent = the chosen path, muted = the thing not taken). Plain words, no jargon the card does not use. The picture is about 320 px wide on the page.
6. Do NOT edit any `.md` file, do not run git, do not touch files outside `.scratch/ssot/diagrams/` and `docs/ssot/decisions/images/mealplanning/`.
7. Report: for each id, one line: `<id>: <what the picture shows>`.

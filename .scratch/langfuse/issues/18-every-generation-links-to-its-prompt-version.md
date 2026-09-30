# 18: Every Generation links to its prompt version

**What to build:** Each Generation in Langfuse links to the prompt name and version that produced it, so spend and Scores can be compared between versions.

**Blocked by:** 08, 09, 10, 11, 12

**Owner:** `mealvana_endurance` agent.

**Status:** done (2026-09-30), one box left for a look in the browser: the prompt page

- [x] A chat Turn's Generations link to the persona version used
- [x] Meal analysis and background Generations link to their prompt versions
- [x] A call that ran on the bundled copy shows no link and is marked as fallback
- [ ] Langfuse's prompt page shows usage and cost for a version after a few dev Turns

2026-09-30. Built, deployed to dev (all seven traced functions) and checked on real dev calls:
- A Turn names its prompt (`prompt` on `tracing.turn` / `tracing.call`) and the span hook links each Generation to that name and version. Three chat Generations read back from Langfuse as `vana/persona/general` version 1, and a described meal as `vana/meal/describe` version 1, each with Langfuse's own prompt id resolved. That resolved id is what the prompt page's usage and cost read; the page itself was not opened in a browser.
- A chat Turn is built from up to twelve prompts and a Generation links to one. It links to the persona section its kind leads with: `vana/persona/core` for a planning conversation, `vana/persona/general` for a general one. Every prompt's version is listed on the root as `promptVersions` metadata, so a Turn can still be traced to an edit of any other section. Open for Lee: whether that choice of link is the one he wants.
- A bundled copy links to nothing, and the Trace's `promptSource` says `fallback` (or `bundled` with no Langfuse keys). A Run that replaces any persona section (vana-eval) links to nothing either, since its text is no version's.
- The linked name and version also ride on every observation as `promptName` / `promptVersion` metadata, which is how the hook finds them.

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

# 09: Describe-meal and meal photo are traced

**What to build:** Describing a meal or photographing one on the dev app sends a Trace with its true cost, and the photo is visible on the Trace.

**Blocked by:** 01

**Owner:** `mealvana_endurance` agent.

**Status:** done (2026-09-30)

- [x] Each call sends one Trace named for its entry point, with the athlete as user
- [x] Cost equals the Call log's figure for that call
- [x] The meal photo is stored by Langfuse and visible on the Trace; no expiring signed URL is sent
- [x] A tracing failure does not change the response or the budget settlement
- [x] Assertions are added to the existing handler tests
- [x] Deployed check on dev with a real photo, staying under Langfuse's 5 MB request limit

2026-09-30. Built and checked on dev with a real 213 KB photo:
- `describe-meal`: Langfuse 0.010689, Call log 0.010689. `analyze-meal-photo`: Langfuse 0.01374, Call log 0.01374.
- The photo is in Langfuse's media store (212,996 bytes, the whole file) and shows on the root and on the Generation through a media reference. No span carries the bytes or a signed URL: the SDK's outer span held them inline as base64, so a span hook takes them off.
- Both handlers are tested through their own `index.ts` (`tests/meal_analysis_trace.ts`).
- Known: when the model's bare not-food answer fails the parse in `analyze-meal-photo`, the Trace is marked as an error although the athlete gets the normal 422.

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

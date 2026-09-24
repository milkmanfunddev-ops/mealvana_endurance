# 21: Kroger connects through its sign-in sheet

**Status:** in-progress (wave 17, 2026-09-24)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete connects Kroger with Lee's shopper login through the system sign-in sheet against Kroger's certification environment. The agent drives the sheet with the mobile MCP, then idb if the MCP cannot reach it, and records exactly where it stops if it stops.

**Decisions:** none.

**Touches:** the dev test account's Kroger connection

- [x] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [x] Uses the entitled dev test account from the credentials file; no new account.
- [x] Uses Lee's Kroger login from the credentials file.
- [x] Every step of the sheet is screenshotted into the run folder.
- [x] The stored Kroger connection is checked by SQL after connecting.
- [x] If both the MCP and idb fail, the Finding says where, and Lee finishes by hand. (Did not arise: the mobile MCP drove the whole sheet, by coordinates on the web page; see runs/21/notes.md.)

Next: /implement-lee testing-wave

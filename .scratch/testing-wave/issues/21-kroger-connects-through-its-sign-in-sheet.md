# 21: Kroger connects through its sign-in sheet

**Status:** in-progress (wave 17, 2026-09-24)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete connects Kroger with Lee's shopper login through the system sign-in sheet against Kroger's certification environment. The agent drives the sheet with the mobile MCP, then idb if the MCP cannot reach it, and records exactly where it stops if it stops.

**Decisions:** none.

**Touches:** the dev test account's Kroger connection

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] Uses Lee's Kroger login from the credentials file.
- [ ] Every step of the sheet is screenshotted into the run folder.
- [ ] The stored Kroger connection is checked by SQL after connecting.
- [ ] If both the MCP and idb fail, the Finding says where, and Lee finishes by hand.

Next: /implement-lee testing-wave

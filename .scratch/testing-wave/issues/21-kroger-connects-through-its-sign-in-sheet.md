# 21: Kroger connects through its sign-in sheet

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/kroger_connect_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete connects Kroger with Lee's shopper login through the system sign-in sheet against Kroger's certification environment. The agent tries the sheet with the mobile MCP and then with Patrol's native layer, and records exactly where it stops if it stops.

**Decisions:** approved as mp-641.

**Touches:** integration_test/flows/kroger_connect_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] Uses Lee's Kroger login from the credentials file.
- [ ] Every step of the sheet is screenshotted into the run folder.
- [ ] The stored Kroger connection is checked by SQL after connecting.
- [ ] If both the MCP and Patrol fail, the Finding says where, and Lee finishes by hand.

Next: /implement-lee testing-wave

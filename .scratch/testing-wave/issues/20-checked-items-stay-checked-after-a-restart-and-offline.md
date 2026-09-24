# 20: Checked items stay checked after a restart and offline

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete checks items off, restarts the app and goes offline, and the items stay checked; when the network comes back the dev database agrees.

**Decisions:** mp-244.

**Touches:** the dev test account's shopping list items

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] Network is cut on the simulator for the offline part; the method is written in the run notes.
- [ ] SQL shows the checked state once back online; nothing is lost or doubled.

Next: /implement-lee testing-wave

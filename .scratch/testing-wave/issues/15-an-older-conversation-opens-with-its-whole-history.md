# 15: An older conversation opens with its whole history

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete opens the conversation list, picks an older conversation, and sees every turn it had, in order, with its Draft.

**Decisions:** mp-241.

**Touches:** the dev test account's Vana conversations (read only)

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] No new plan is generated.
- [ ] The turns on screen equal the stored messages for that conversation by SQL (count and order).

Next: /implement-lee testing-wave
